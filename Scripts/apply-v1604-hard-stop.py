from pathlib import Path

p=Path('Sources/WoWServerControlCenter/ServerModel.swift')
s=p.read_text()

anchor='''    private func stopStaleServersFromOtherExpansions() throws {\n'''
helper=r'''    private func hardStopManagedServersForProfile(_ expansion: ExpansionID) throws {
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
        let profileToken = "/runtime/profiles/\(expansion.rawValue)/bin/"
        let serverNames = ["realmd", "mangosd", "authserver", "worldserver"]
        var targets: [(Int32, String)] = []

        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = line.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let command = String(parts[1])
            guard command.contains(profileToken) else { continue }
            guard serverNames.contains(where: { command.contains("/bin/\($0)") || command.hasSuffix("/\($0)") }) else { continue }
            targets.append((pid, command))
        }

        guard !targets.isEmpty else { return }

        func signal(_ name: String, pids: [Int32]) {
            for pid in pids {
                let killer = Process()
                killer.executableURL = URL(fileURLWithPath: "/bin/kill")
                killer.arguments = [name, "\(pid)"]
                killer.standardOutput = FileHandle.nullDevice
                killer.standardError = FileHandle.nullDevice
                try? killer.run()
                killer.waitUntilExit()
            }
        }

        signal("-TERM", pids: targets.map { $0.0 })
        let termDeadline = Date().addingTimeInterval(3.0)
        while Date() < termDeadline {
            let alive = targets.contains { kill($0.0, 0) == 0 }
            if !alive { break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        let survivors = targets.filter { kill($0.0, 0) == 0 }
        if !survivors.isEmpty {
            signal("-KILL", pids: survivors.map { $0.0 })
            let killDeadline = Date().addingTimeInterval(2.0)
            while Date() < killDeadline {
                if !survivors.contains(where: { kill($0.0, 0) == 0 }) { break }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        let stillAlive = targets.filter { kill($0.0, 0) == 0 }
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let logURL = logs.appendingPathComponent("hard-stop.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        var text = "[\(stamp)] Hard stop profile=\(expansion.rawValue)\n"
        text += targets.map { "target PID \($0.0): \($0.1)" }.joined(separator: "\n") + "\n"
        if !survivors.isEmpty { text += "Escalated to SIGKILL: " + survivors.map { String($0.0) }.joined(separator: ",") + "\n" }
        if !stillAlive.isEmpty { text += "STILL ALIVE: " + stillAlive.map { String($0.0) }.joined(separator: ",") + "\n" }
        if FileManager.default.fileExists(atPath: logURL.path), let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(text.utf8))
        } else {
            try? text.write(to: logURL, atomically: true, encoding: .utf8)
        }
        if !stillAlive.isEmpty {
            throw err("Could not stop all \(expansion.shortTitle) server processes. See hard-stop.log.")
        }
    }

'''
if 'private func hardStopManagedServersForProfile' not in s:
    if anchor not in s: raise SystemExit('stopStale anchor missing')
    s=s.replace(anchor, helper+anchor, 1)

old='''    func stopAll() {
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = false
        releaseActiveRealmLockIfOwned()
        world?.stop(); auth?.stop(); mysql?.stop()
        statusMessage = "Server stopped"
        refresh()
    }
'''
new='''    func stopAll() {
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = false
        releaseActiveRealmLockIfOwned()
        world?.stop(); auth?.stop(); mysql?.stop()
        do {
            try hardStopManagedServersForProfile(selectedExpansion)
            worldRunning = false
            authRunning = false
            mysqlRunning = portOpen(Int32(mysqlPort))
            statusMessage = "Server stopped — \(selectedExpansion.shortTitle) processes are fully terminated"
        } catch {
            statusMessage = "Stop failed: \(error.localizedDescription)"
        }
        refresh()
    }
'''
if old not in s: raise SystemExit('stopAll block not found')
s=s.replace(old,new,1)

old='''    func stopWorldServer() {
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = false
        if !authRunning { releaseActiveRealmLockIfOwned() }
        world?.stop()
        worldRunning = false
        statusMessage = "World Server stopped"
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { self.refresh() }
    }
'''
new='''    func stopWorldServer() {
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = false
        if !authRunning { releaseActiveRealmLockIfOwned() }
        world?.stop()
        do {
            try hardStopManagedServerBinaryForCurrentProfile(worldBinaryName)
            worldRunning = false
            statusMessage = "World Server stopped"
        } catch {
            statusMessage = "World stop failed: \(error.localizedDescription)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { self.refresh() }
    }
'''
# Instead of adding another binary-specific helper, keep direct World Stop using hard profile would also stop auth, not desired.
# Leave stopWorldServer unchanged for now if exact block exists; Stop All is the user's failing path and must be authoritative.

p.write_text(s)

b=Path('Build.command')
t=b.read_text().replace('<string>1.6.3</string>','<string>1.6.4</string>').replace('<string>1603</string>','<string>1604</string>')
b.write_text(t)

notes=Path('RELEASE-NOTES.md')
n=notes.read_text()
header='''# v1.6.4 — Hard Profile Stop\n\n- Fixes Stop All doing nothing when an expansion server became orphaned from WoWCC's in-memory ManagedProcess object.\n- Stop All now performs a PID sweep for the selected expansion profile and terminates its managed `realmd`, `mangosd`, `authserver`, and `worldserver` processes.\n- Uses SIGTERM first, then SIGKILL only for surviving WoWCC-managed processes in that exact profile.\n- Verifies no selected-profile server processes remain before reporting success.\n- Writes all hard-stop actions to `hard-stop.log`, visible in WoWCC Logs.\n- Preserves the single Active Realm Lock: stopped profiles cannot be resurrected by the watchdog.\n\n'''
if not n.startswith('# v1.6.4'):
    notes.write_text(header+n)
print('Applied 1.6.4 hard profile stop')
