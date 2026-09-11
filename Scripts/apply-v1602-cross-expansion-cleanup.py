from pathlib import Path

p = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = p.read_text()

anchor = '''    private func ensureSelectedServerOwnsPort(_ port: Int32, expectedBinary: String) throws {\n'''
if anchor not in s:
    raise SystemExit('ownership helper anchor not found')

if 'private func stopStaleServersFromOtherExpansions() throws' not in s:
    helper = r'''    private func stopStaleServersFromOtherExpansions() throws {
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
        let selectedProfileToken = "/runtime/profiles/\(selectedExpansion.rawValue)/bin/"
        let serverNames = ["realmd", "mangosd", "authserver", "worldserver"]
        var stopped: [String] = []

        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let parts = line.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let command = String(parts[1])

            // Only processes launched from WoWCC managed profile paths qualify.
            let managed = command.contains("/.wowcc/runtime/profiles/") ||
                          command.contains("/WoWServerControlCenter/runtime/profiles/")
            guard managed else { continue }
            guard !command.contains(selectedProfileToken) else { continue }
            guard serverNames.contains(where: { command.contains("/bin/\($0)") }) else { continue }

            let killer = Process()
            killer.executableURL = URL(fileURLWithPath: "/bin/kill")
            killer.arguments = ["-TERM", "\(pid)"]
            killer.standardOutput = FileHandle.nullDevice
            killer.standardError = FileHandle.nullDevice
            try killer.run()
            killer.waitUntilExit()
            stopped.append("PID \(pid): \(command)")
        }

        if !stopped.isEmpty {
            let deadline = Date().addingTimeInterval(4)
            while Date() < deadline && (portOpen(authPort) || portOpen(worldPort)) {
                Thread.sleep(forTimeInterval: 0.1)
            }

            try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
            let logURL = logs.appendingPathComponent("cross-expansion-cleanup.log")
            let stamp = ISO8601DateFormatter().string(from: Date())
            let text = "[\(stamp)] Selected \(selectedExpansion.rawValue). Stopped stale servers from other WoWCC profiles:\n" + stopped.joined(separator: "\n") + "\n"
            if FileManager.default.fileExists(atPath: logURL.path), let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(text.utf8))
            } else {
                try? text.write(to: logURL, atomically: true, encoding: .utf8)
            }
        }
    }

'''
    s = s.replace(anchor, helper + anchor, 1)

# Start All: clean other profiles before any port ownership checks.
needle = '''                try ensureCompatibilityAlias()\n                try repairCMaNGOSDatabaseConfigIfNeeded()\n\n                statusMessage = "1/3 Starting managed MySQL 8.4…"\n'''
repl = '''                try ensureCompatibilityAlias()\n                try stopStaleServersFromOtherExpansions()\n                try repairCMaNGOSDatabaseConfigIfNeeded()\n\n                statusMessage = "1/3 Starting managed MySQL 8.4…"\n'''
if needle not in s:
    raise SystemExit('startAll anchor not found')
s = s.replace(needle, repl, 1)

# Direct World start.
marker = '    func startWorldServer() {'
pos = s.find(marker)
if pos < 0:
    raise SystemExit('startWorldServer not found')
tail = s[pos:]
old = '''                try ensureCompatibilityAlias()\n                try repairCMaNGOSDatabaseConfigIfNeeded()\n'''
new = '''                try ensureCompatibilityAlias()\n                try stopStaleServersFromOtherExpansions()\n                try repairCMaNGOSDatabaseConfigIfNeeded()\n'''
if old in tail:
    tail = tail.replace(old, new, 1)
    s = s[:pos] + tail
else:
    raise SystemExit('startWorldServer anchor not found')

# Direct Realm start.
marker = '    func startRealmServer() {'
pos = s.find(marker)
if pos < 0:
    raise SystemExit('startRealmServer not found')
tail = s[pos:]
if old in tail:
    tail = tail.replace(old, new, 1)
    s = s[:pos] + tail
else:
    raise SystemExit('startRealmServer anchor not found')

p.write_text(s)

b = Path('Build.command')
t = b.read_text().replace('<string>1.6.1</string>', '<string>1.6.2</string>').replace('<string>1601</string>', '<string>1602</string>')
b.write_text(t)

notes = Path('RELEASE-NOTES.md')
n = notes.read_text()
header = '''# v1.6.2 — Cross-Expansion Server Cleanup\n\n- Fixes stale TBC/Vanilla `realmd` and `mangosd` processes surviving while WotLK is selected.\n- Before Start All, Start Realm, or Start World, WoWCC stops server processes belonging only to other WoWCC-managed expansion profiles.\n- Prevents WotLK clients using `127.0.0.1` from accidentally reaching an old CMaNGOS listener on port 3724.\n- Never terminates unrelated third-party processes.\n- Cleanup details are written to `cross-expansion-cleanup.log` and are visible in WoWCC Logs.\n- Keeps the WotLK realm registration, port ownership, PlayerBots DB, DB port, and DataDir repairs.\n\n'''
if not n.startswith('# v1.6.2'):
    notes.write_text(header + n)

print('Applied 1.6.2 cross-expansion cleanup fix')
