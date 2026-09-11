from pathlib import Path

sm=Path('Sources/WoWServerControlCenter/ServerModel.swift')
s=sm.read_text()

# Add service state type before model.
if 'struct ExpansionServiceState' not in s:
    s=s.replace('''@MainActor\nfinal class ServerModel: ObservableObject {\n''','''struct ExpansionServiceState: Equatable {\n    var database = false\n    var auth = false\n    var world = false\n    var anyRunning: Bool { database || auth || world }\n    var fullyRunning: Bool { database && auth && world }\n}\n\n@MainActor\nfinal class ServerModel: ObservableObject {\n''',1)

# Fix expansion switching: stop the OLD profile, never call stopAll after selectedExpansion already changed.
old='''    @Published var selectedExpansion: ExpansionID = .wotlk {
        didSet {
            guard selectedExpansion != oldValue else { return }
            saveExpansion()
            desiredWorldRunning = false
            worldWatchdogRestartInProgress = false
            try? FileManager.default.removeItem(at: dataRoot.appendingPathComponent("runtime/active-realm-profile"))
            stopAll()
            loadProfileSettings()
'''
new='''    @Published var selectedExpansion: ExpansionID = .wotlk {
        didSet {
            guard selectedExpansion != oldValue else { return }
            let previousExpansion = oldValue
            desiredWorldRunning = false
            worldWatchdogRestartInProgress = false
            world?.stop()
            auth?.stop()
            mysql?.stop()
            try? hardStopManagedServersForProfile(previousExpansion)
            try? hardStopManagedDatabaseForProfile(previousExpansion)
            try? FileManager.default.removeItem(at: dataRoot.appendingPathComponent("runtime/active-realm-profile"))
            saveExpansion()
            loadProfileSettings()
'''
if old not in s:
    raise SystemExit('selectedExpansion didSet block not found')
s=s.replace(old,new,1)

# Published matrix.
marker='''    @Published var mysqlRunning = false\n'''
if '@Published var expansionServiceStates' not in s:
    s=s.replace(marker,'''    @Published var expansionServiceStates: [String: ExpansionServiceState] = [:]\n'''+marker,1)

# Refresh state every timer tick.
oldtimer='''                self.refresh()
                await self.keepWorldAliveIfRequested()
'''
newtimer='''                self.refresh()
                self.refreshExpansionServiceStates()
                await self.keepWorldAliveIfRequested()
'''
if oldtimer in s:
    s=s.replace(oldtimer,newtimer,1)

# Initial state after rebuild.
init_anchor='''        rebuildProcesses()\n\n        refresh()\n'''
if init_anchor in s:
    s=s.replace(init_anchor,'''        rebuildProcesses()\n\n        refresh()\n        refreshExpansionServiceStates()\n''',1)

# Add public service manager methods before startAll.
anchor='''    func startAll() {\n'''
helper=r'''    func serviceState(for expansion: ExpansionID) -> ExpansionServiceState {
        expansionServiceStates[expansion.rawValue] ?? ExpansionServiceState()
    }

    func refreshExpansionServiceStates() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,command="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var next: [String: ExpansionServiceState] = [:]
        for expansion in ExpansionID.allCases {
            let profileToken = "/runtime/profiles/\(expansion.rawValue)/bin/"
            let dbToken = "/runtime/mysql/\(expansion.rawValue)/data"
            var state = ExpansionServiceState()
            for rawLine in output.split(separator: "\n") {
                let command = String(rawLine)
                if command.contains(dbToken) && command.contains("mysqld") {
                    state.database = true
                }
                if command.contains(profileToken) {
                    if command.contains("/bin/realmd") || command.contains("/bin/authserver") {
                        state.auth = true
                    }
                    if command.contains("/bin/mangosd") || command.contains("/bin/worldserver") {
                        state.world = true
                    }
                }
            }
            next[expansion.rawValue] = state
        }
        expansionServiceStates = next
    }

    func startExpansion(_ expansion: ExpansionID) {
        if selectedExpansion != expansion {
            selectedExpansion = expansion
        }
        startAll()
    }

    func stopExpansion(_ expansion: ExpansionID) {
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = false
        if readActiveRealmLock() == expansion.rawValue {
            try? FileManager.default.removeItem(at: activeRealmLockURL)
        }

        if selectedExpansion == expansion {
            world?.stop()
            auth?.stop()
            mysql?.stop()
        }

        do {
            try hardStopManagedServersForProfile(expansion)
            try hardStopManagedDatabaseForProfile(expansion)
            if selectedExpansion == expansion {
                worldRunning = false
                authRunning = false
                mysqlRunning = false
            }
            statusMessage = "\(expansion.shortTitle) stopped — DB, Auth and World are off"
        } catch {
            statusMessage = "Could not fully stop \(expansion.shortTitle): \(error.localizedDescription)"
        }
        refreshExpansionServiceStates()
        refresh()
    }

    private func hardStopManagedDatabaseForProfile(_ expansion: ExpansionID) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,command="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let dbToken = "/runtime/mysql/\(expansion.rawValue)/data"
        var targets: [Int32] = []
        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = line.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let command = String(parts[1])
            if command.contains("mysqld") && command.contains(dbToken) {
                targets.append(pid)
            }
        }
        guard !targets.isEmpty else { return }

        for pid in targets {
            let killer = Process()
            killer.executableURL = URL(fileURLWithPath: "/bin/kill")
            killer.arguments = ["-TERM", "\(pid)"]
            killer.standardOutput = FileHandle.nullDevice
            killer.standardError = FileHandle.nullDevice
            try? killer.run()
            killer.waitUntilExit()
        }
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline && targets.contains(where: { kill($0, 0) == 0 }) {
            Thread.sleep(forTimeInterval: 0.1)
        }
        let survivors = targets.filter { kill($0, 0) == 0 }
        for pid in survivors {
            let killer = Process()
            killer.executableURL = URL(fileURLWithPath: "/bin/kill")
            killer.arguments = ["-KILL", "\(pid)"]
            killer.standardOutput = FileHandle.nullDevice
            killer.standardError = FileHandle.nullDevice
            try? killer.run()
            killer.waitUntilExit()
        }
    }

'''
if 'func refreshExpansionServiceStates()' not in s:
    if anchor not in s: raise SystemExit('startAll anchor not found')
    s=s.replace(anchor,helper+anchor,1)

# Make Stop All authoritative including orphan DB and update matrix.
oldstop='''        world?.stop(); auth?.stop(); mysql?.stop()
        do {
            try hardStopManagedServersForProfile(selectedExpansion)
            worldRunning = false
            authRunning = false
            mysqlRunning = portOpen(Int32(mysqlPort))
            statusMessage = "Server stopped — \(selectedExpansion.shortTitle) processes are fully terminated"
'''
newstop='''        world?.stop(); auth?.stop(); mysql?.stop()
        do {
            try hardStopManagedServersForProfile(selectedExpansion)
            try hardStopManagedDatabaseForProfile(selectedExpansion)
            worldRunning = false
            authRunning = false
            mysqlRunning = false
            refreshExpansionServiceStates()
            statusMessage = "Server stopped — \(selectedExpansion.shortTitle) DB, Auth and World are fully terminated"
'''
if oldstop in s:
    s=s.replace(oldstop,newstop,1)

# Refresh matrix after successful start.
s=s.replace('''                statusMessage = "ONLINE — MySQL, Auth and World Server are running"\n                refreshPlayerBotStats()\n''','''                statusMessage = "ONLINE — MySQL, Auth and World Server are running"\n                refreshExpansionServiceStates()\n                refreshPlayerBotStats()\n''',1)

sm.write_text(s)

# UI expansion cards with service states and explicit controls.
cv=Path('Sources/WoWServerControlCenter/ContentView.swift')
c=cv.read_text()
oldcards='''                    ForEach(ExpansionID.allCases) { e in
                        Button { model.selectedExpansion=e } label:{
                            VStack(alignment:.leading,spacing:8) {
                                HStack { Text(e.shortTitle).font(.title2.bold()); Spacer(); maturityBadge(e.maturity) }
                                Text(e.title).font(.headline).multilineTextAlignment(.leading)
                                Text(e.recommendedCore).font(.caption).foregroundStyle(.secondary)
                                Text(e.clientHint).font(.caption2).foregroundStyle(.secondary)
                            }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.thinMaterial,in:RoundedRectangle(cornerRadius:16))
                        }.buttonStyle(.plain)
                    }
'''
newcards='''                    ForEach(ExpansionID.allCases) { e in
                        let state = model.serviceState(for: e)
                        VStack(alignment:.leading,spacing:10) {
                            HStack {
                                Text(e.shortTitle).font(.title2.bold())
                                Spacer()
                                if model.selectedExpansion == e {
                                    Text("SELECTED").font(.caption2.bold()).foregroundStyle(.blue)
                                }
                                maturityBadge(e.maturity)
                            }
                            Text(e.title).font(.headline)
                            Text(e.recommendedCore).font(.caption).foregroundStyle(.secondary)

                            HStack(spacing:12) {
                                expansionServiceDot("DB", state.database)
                                expansionServiceDot("Auth", state.auth)
                                expansionServiceDot("World", state.world)
                                Spacer()
                                Text(state.fullyRunning ? "ONLINE" : (state.anyRunning ? "PARTIAL" : "OFFLINE"))
                                    .font(.caption2.bold())
                                    .foregroundStyle(state.fullyRunning ? .green : (state.anyRunning ? .orange : .secondary))
                            }

                            HStack(spacing:8) {
                                Button("Select") { model.selectedExpansion = e }
                                    .buttonStyle(.bordered)
                                    .disabled(model.selectedExpansion == e)
                                Button { model.startExpansion(e) } label: { Label("Start", systemImage:"play.fill") }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(model.operationActive || state.fullyRunning)
                                Button { model.stopExpansion(e) } label: { Label("Stop", systemImage:"stop.fill") }
                                    .buttonStyle(.bordered)
                                    .disabled(!state.anyRunning)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth:.infinity,alignment:.leading)
                        .background(model.selectedExpansion == e ? Color.accentColor.opacity(0.10) : Color.clear)
                        .background(.thinMaterial,in:RoundedRectangle(cornerRadius:16))
                    }
'''
if oldcards not in c: raise SystemExit('expansion card block not found')
c=c.replace(oldcards,newcards,1)

# Add helper near statusDot.
status_anchor='''    private func statusDot(_ title: String, _ ready: Bool) -> some View {\n'''
if 'private func expansionServiceDot' not in c:
    helperui='''    private func expansionServiceDot(_ title: String, _ running: Bool) -> some View {\n        HStack(spacing:5) {\n            Circle().fill(running ? Color.green : Color.secondary).frame(width:8,height:8)\n            Text(title).font(.caption2.bold()).foregroundStyle(running ? .primary : .secondary)\n        }\n    }\n\n'''
    c=c.replace(status_anchor,helperui+status_anchor,1)
cv.write_text(c)

# Version bump.
b=Path('Build.command')
t=b.read_text().replace('<string>1.6.4</string>','<string>1.6.5</string>').replace('<string>1604</string>','<string>1605</string>')
b.write_text(t)

notes=Path('RELEASE-NOTES.md')
n=notes.read_text()
header='''# v1.6.5 — Expansion Service Manager\n\n- Fixes the root expansion-switch bug: changing TBC → WotLK (or any era) now stops the OLD profile, not the newly selected profile.\n- Adds live per-expansion DB / Auth / World status indicators to Expansion Manager.\n- Adds explicit Select / Start / Stop controls on every Vanilla, TBC, WotLK, Cata and MoP card.\n- Status is process/profile-specific instead of inferred from shared ports.\n- Stop terminates both remembered and orphaned server processes plus that expansion's managed MySQL process.\n- Only the explicitly started expansion can own the Active Realm Lock and watchdog.\n\n'''
if not n.startswith('# v1.6.5'):
    notes.write_text(header+n)
print('Applied 1.6.5 expansion service manager')
