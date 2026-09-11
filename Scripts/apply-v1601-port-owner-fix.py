from pathlib import Path

p=Path('Sources/WoWServerControlCenter/ServerModel.swift')
s=p.read_text()

anchor='''    private func waitForService(port: Int32, process: ManagedProcess, label: String, timeoutSeconds: Int, logName: String) async throws {\n'''
if 'private func ensureSelectedServerOwnsPort' not in s:
    helper=r'''    private func ensureSelectedServerOwnsPort(_ port: Int32, expectedBinary: String) throws {
        guard portOpen(port) else { return }

        func capture(_ executable: String, _ arguments: [String]) -> String {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8) ?? ""
            } catch {
                return ""
            }
        }

        let pidText = capture("/usr/sbin/lsof", ["-nP", "-t", "-iTCP:\(port)", "-sTCP:LISTEN"])
        let pids = pidText.split(whereSeparator: { $0.isWhitespace }).compactMap { Int32($0) }
        guard !pids.isEmpty else { return }

        let selectedToken = "/runtime/profiles/\(selectedExpansion.rawValue)/bin/\(expectedBinary)"
        let knownBinaries = ["/authserver", "/worldserver", "/realmd", "/mangosd"]

        for pid in pids {
            let command = capture("/bin/ps", ["-p", "\(pid)", "-o", "command="])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if command.contains(selectedToken) || (command.contains("/\(expectedBinary)") && command.contains("/runtime/profiles/\(selectedExpansion.rawValue)/")) {
                continue
            }

            let managedByWoWCC = command.contains("/.wowcc/runtime/profiles/") || command.contains("WoWServerControlCenter/runtime/profiles/")
            let knownServer = knownBinaries.contains(where: command.contains)
            guard managedByWoWCC && knownServer else {
                throw err("Port \(port) is already owned by another process: \(command.isEmpty ? \"PID \\(pid)\" : command). Stop it before starting \(selectedExpansion.shortTitle).")
            }

            let killer = Process()
            killer.executableURL = URL(fileURLWithPath: "/bin/kill")
            killer.arguments = ["-TERM", "\(pid)"]
            killer.standardOutput = FileHandle.nullDevice
            killer.standardError = FileHandle.nullDevice
            try killer.run()
            killer.waitUntilExit()

            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline && portOpen(port) {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if portOpen(port) {
                throw err("Old WoWCC server process on port \(port) did not stop. Stop the previous realm and retry.")
            }

            let logURL = logs.appendingPathComponent("port-ownership.log")
            let stamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(stamp)] Stopped stale WoWCC listener PID \(pid) on port \(port): \(command)\n"
            if FileManager.default.fileExists(atPath: logURL.path), let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            } else {
                try? line.write(to: logURL, atomically: true, encoding: .utf8)
            }
        }
    }

'''
    if anchor not in s: raise SystemExit('waitForService anchor missing')
    s=s.replace(anchor,helper+anchor,1)

# Start All: validate ownership immediately before auth/world decisions.
s=s.replace('''                statusMessage = "2/3 Starting \\(authBinaryName)…"\n                if !portOpen(authPort) {\n''','''                statusMessage = "2/3 Starting \\(authBinaryName)…"\n                try ensureSelectedServerOwnsPort(authPort, expectedBinary: authBinaryName)\n                if !portOpen(authPort) {\n''',1)
s=s.replace('''                statusMessage = "3/3 Starting \\(worldBinaryName)…"\n                if !portOpen(worldPort) {\n''','''                statusMessage = "3/3 Starting \\(worldBinaryName)…"\n                try ensureSelectedServerOwnsPort(worldPort, expectedBinary: worldBinaryName)\n                if !portOpen(worldPort) {\n''',1)

# Direct Realm start.
s=s.replace('''                guard realmDatabaseReady || probeRealmDatabaseReady() else { throw err("Realm database is not ready.") }\n                if !portOpen(authPort) {\n''','''                guard realmDatabaseReady || probeRealmDatabaseReady() else { throw err("Realm database is not ready.") }\n                try ensureSelectedServerOwnsPort(authPort, expectedBinary: authBinaryName)\n                if !portOpen(authPort) {\n''',1)

# Direct World start: target the occurrence inside startWorldServer.
marker='''    func startWorldServer() {'''
pos=s.find(marker)
if pos!=-1:
    tail=s[pos:]
    old='''                try validateClientDataForStart()\n                if !portOpen(worldPort) {\n'''
    new='''                try validateClientDataForStart()\n                try ensureSelectedServerOwnsPort(worldPort, expectedBinary: worldBinaryName)\n                if !portOpen(worldPort) {\n'''
    if old in tail:
        tail=tail.replace(old,new,1)
        s=s[:pos]+tail

p.write_text(s)

# bump version
b=Path('Build.command')
t=b.read_text().replace('<string>1.6.0</string>','<string>1.6.1</string>').replace('<string>1600</string>','<string>1601</string>')
b.write_text(t)

notes=Path('RELEASE-NOTES.md')
n=notes.read_text()
header='''# v1.6.1 — Realm Port Ownership Fix\n\n- Fixes WotLK accidentally reusing a stale CMaNGOS `realmd` on port 3724 and showing the MaNGOS realm.\n- Verifies the actual listener owner for auth port 3724 and world port 8085 before treating a service as already running.\n- Stops only stale WoWCC-managed realm/world processes from another expansion; unrelated processes are never killed.\n- Logs stale listener cleanup to `port-ownership.log` in WoWCC Logs.\n- Preserves WotLK realm registration, PlayerBots DB bootstrap, DB port, and absolute DataDir fixes.\n\n'''
if not n.startswith('# v1.6.1'):
    notes.write_text(header+n)
print('Applied 1.6.1 port ownership fix')
