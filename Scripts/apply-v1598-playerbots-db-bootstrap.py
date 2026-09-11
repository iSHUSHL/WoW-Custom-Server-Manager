from pathlib import Path

server = Path('Sources/WoWServerControlCenter/ServerModel.swift')
text = server.read_text()

anchor = '    private func waitForWorldReadyPlayerBotsAware() async throws {\n'
if anchor not in text:
    raise SystemExit('waitForWorldReadyPlayerBotsAware anchor not found')

helper = r'''    private func ensureWotLKPlayerBotsDatabaseReady() async throws {
        guard selectedExpansion == .wotlk else { return }

        let client = try dbClient()
        let tableCountSQL = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='acore_playerbots';"
        let currentCount = Int(try client.query(database: "mysql", sql: tableCountSQL)
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        // A stale .playerbots-ready marker is not enough. The database itself is
        // authoritative. If it is missing/empty, run the same repeatable bootstrap
        // used by PlayerBots → Populate / Repair before worldserver is allowed to start.
        if currentCount > 0 {
            let marker = profileRoot.appendingPathComponent(".playerbots-ready")
            if !FileManager.default.fileExists(atPath: marker.path) {
                try? ISO8601DateFormatter().string(from: Date()).appending("\n")
                    .write(to: marker, atomically: true, encoding: .utf8)
            }
            return
        }

        let script = assetsRoot.appendingPathComponent("Scripts/setup-playerbots-wotlk.sh")
        guard FileManager.default.fileExists(atPath: script.path) else {
            throw err("WotLK PlayerBots setup script is missing from the app bundle.")
        }

        statusMessage = "Preparing WotLK PlayerBots database…"
        let scriptPath = script.path
        let dataRootPath = dataRoot.path
        let mysqlPortValue = mysqlPort
        let bots = min(5000, max(10, playerBotPopulation))
        let enabled = playerBotsEnabled ? "1" : "0"
        let battlegrounds = playerBotsBattlegrounds ? "1" : "0"
        let quests = playerBotsQuesting ? "1" : "0"
        let speed = playerBotCreationSpeed.lowercased()

        let result = await Task.detached(priority: .utility) { () -> (Int32, String?) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath, "wotlk", "\(bots)", enabled, battlegrounds, quests, speed]
            process.environment = ProcessInfo.processInfo.environment.merging([
                "WOWCC_DATA_ROOT": dataRootPath,
                "WOWCC_MYSQL_PORT": "\(mysqlPortValue)"
            ]) { _, new in new }
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                return (process.terminationStatus, nil)
            } catch {
                return (-1, error.localizedDescription)
            }
        }.value

        if let launchError = result.1 {
            throw err("Could not launch WotLK PlayerBots database bootstrap: \(launchError)")
        }
        guard result.0 == 0 else {
            let tail = lastLogLines("playerbots-setup.log", count: 30)
            throw err("WotLK PlayerBots database bootstrap failed (exit \(result.0)). \(tail)")
        }

        let verifiedCount = Int(try client.query(database: "mysql", sql: tableCountSQL)
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard verifiedCount > 0 else {
            throw err("WotLK PlayerBots bootstrap completed but acore_playerbots still contains no tables. Check PlayerBots Setup log.")
        }

        statusMessage = "WotLK PlayerBots database ready — \(verifiedCount) tables"
    }

'''
text = text.replace(anchor, helper + anchor, 1)

text = text.replace('''                statusMessage = "3/3 Starting \\(worldBinaryName)…"
                if !portOpen(worldPort) {
                    try ensurePlayerBotRuntimeConfig()
''', '''                statusMessage = "3/3 Starting \\(worldBinaryName)…"
                if !portOpen(worldPort) {
                    try await ensureWotLKPlayerBotsDatabaseReady()
                    try ensurePlayerBotRuntimeConfig()
''', 1)

text = text.replace('''                try validateClientDataForStart()
                if !portOpen(worldPort) {
                    try ensurePlayerBotRuntimeConfig()
''', '''                try validateClientDataForStart()
                if !portOpen(worldPort) {
                    try await ensureWotLKPlayerBotsDatabaseReady()
                    try ensurePlayerBotRuntimeConfig()
''', 1)

# Defensive watchdog path for any future non-ready PlayerBots state.
text = text.replace('''            try ensureCompatibilityAlias()
            try ensurePlayerBotRuntimeConfig()
            try startWorld()
''', '''            try ensureCompatibilityAlias()
            try await ensureWotLKPlayerBotsDatabaseReady()
            try ensurePlayerBotRuntimeConfig()
            try startWorld()
''', 1)

server.write_text(text)

build = Path('Build.command')
b = build.read_text()
b = b.replace('<string>1.5.97</string>', '<string>1.5.98</string>', 1)
b = b.replace('<string>1597</string>', '<string>1598</string>', 1)
build.write_text(b)

notes = Path('RELEASE-NOTES.md')
n = notes.read_text()
header = '''# v1.5.98 — WotLK PlayerBots Database Bootstrap\n\n- Fixes WotLK World hanging at `Database "acore_playerbots" does not exist` / `Do you want to create it?`.\n- Before worldserver starts, WoWCC verifies the real PlayerBots database contains tables, not just a stale ready marker.\n- Missing/empty `acore_playerbots` automatically runs the repeatable WotLK PlayerBots bootstrap, imports module SQL/migrations, validates tables, and creates the ready marker.\n- PlayerBots startup then uses the 15-minute initialization timeout instead of falling back to the normal 30-second timeout.\n- Keeps the forced `AC_PLAYERBOTS_DATABASE_INFO` managed-MySQL 3307 override and clean in-app titlebar.\n\n'''
notes.write_text(header + n)

print('Applied 1.5.98 PlayerBots database bootstrap fix')
