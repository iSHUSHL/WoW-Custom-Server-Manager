from pathlib import Path
import re

# --- ServerModel: patch every runtime playerbots.conf, not just one guessed path.
p = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = p.read_text()
start = s.index('    private func ensurePlayerBotRuntimeConfig() throws {')
end = s.index('\n    private func waitForWorldReadyPlayerBotsAware()', start)
new = r'''    private func ensurePlayerBotRuntimeConfig() throws {
        guard playerBotsSupported && playerBotsReady else { return }
        let fm = FileManager.default
        let configDir = profileRoot.appendingPathComponent("configs", isDirectory: true)
        let configured: URL
        let runtime: URL
        if selectedExpansion == .wotlk {
            let modulesDir = profileRoot.appendingPathComponent("etc/modules", isDirectory: true)
            try fm.createDirectory(at: modulesDir, withIntermediateDirectories: true)
            configured = configDir.appendingPathComponent("playerbots.conf")
            runtime = modulesDir.appendingPathComponent("playerbots.conf")
        } else {
            let etcDir = profileRoot.appendingPathComponent("etc", isDirectory: true)
            try fm.createDirectory(at: etcDir, withIntermediateDirectories: true)
            configured = configDir.appendingPathComponent("aiplayerbot.conf")
            runtime = etcDir.appendingPathComponent("aiplayerbot.conf")
        }

        if fm.fileExists(atPath: configured.path) {
            if fm.fileExists(atPath: runtime.path) { try fm.removeItem(at: runtime) }
            try fm.copyItem(at: configured, to: runtime)
        } else if !fm.fileExists(atPath: runtime.path) {
            throw err("PlayerBots runtime config is missing. Run PlayerBots → Populate / Repair World once.")
        }

        guard selectedExpansion == .wotlk else { return }

        let expected = "PlayerbotsDatabaseInfo = \"127.0.0.1;\(mysqlPort);wowcc;wowcc;acore_playerbots\""
        let pattern = #"(?m)^\s*#?\s*PlayerbotsDatabaseInfo\s*=.*$"#
        let regex = try NSRegularExpression(pattern: pattern)
        var candidates = Set<URL>()
        candidates.insert(configured)
        candidates.insert(runtime)

        // The Playerbot fork can load module configs from different install/layout
        // directories. Repair every real playerbots.conf inside this managed profile
        // so a stale 3306 copy can never win at startup.
        if let enumerator = fm.enumerator(at: profileRoot, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let url as URL in enumerator where url.lastPathComponent.lowercased() == "playerbots.conf" {
                candidates.insert(url)
            }
        }

        var repaired: [String] = []
        for url in candidates where fm.fileExists(atPath: url.path) {
            var text = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: expected)
            } else {
                if !text.hasSuffix("\n") { text += "\n" }
                text += expected + "\n"
            }
            try text.write(to: url, atomically: true, encoding: .utf8)
            repaired.append(url.path)
        }

        guard !repaired.isEmpty else {
            throw err("No WotLK playerbots.conf could be repaired. Run PlayerBots → Populate / Repair World once.")
        }

        let logURL = logs.appendingPathComponent("playerbots-config.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(stamp)] Forced PlayerbotsDatabaseInfo to 127.0.0.1:\(mysqlPort) in:\n" + repaired.sorted().joined(separator: "\n") + "\n"
        if fm.fileExists(atPath: logURL.path), let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(entry.utf8))
        } else {
            try? entry.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
'''
s = s[:start] + new + s[end:]
p.write_text(s)

# --- Remove the custom icon/title brand from the app window, keep Dock/Finder icon.
p = Path('Sources/WoWServerControlCenter/PremiumTheme.swift')
s = p.read_text()
s = s.replace('        installPremiumTitleBrand(in: window)\n', '''        // Keep the native traffic-light titlebar clean. Remove any legacy\n        // WoWCC title accessory that may already be attached to this window.\n        for controller in window.titlebarAccessoryViewControllers.reversed() {\n            if controller.view.identifier?.rawValue == WoWCCTitlebarAccessoryController.identifierString,\n               let index = window.titlebarAccessoryViewControllers.firstIndex(of: controller) {\n                window.removeTitlebarAccessoryViewController(at: index)\n            }\n        }\n''', 1)
p.write_text(s)

# --- Version bump.
p = Path('Build.command')
s = p.read_text().replace('<string>1.5.94</string>', '<string>1.5.95</string>').replace('<string>1594</string>', '<string>1595</string>')
p.write_text(s)

p = Path('RELEASE-NOTES.md')
s = p.read_text()
s = '''# v1.5.95 — PlayerBots Runtime Config Sweep + Clean Titlebar\n\n- Fixes persistent WotLK PlayerBots startup attempts on MySQL 3306 by repairing every runtime playerbots.conf inside the managed WotLK profile before World starts.\n- Logs every repaired PlayerBots config path to playerbots-config.log, visible in WoWCC Logs.\n- Removes the custom WoW icon/title/subtitle from the app window titlebar while keeping the Dock/Finder app icon.\n- Keeps all 1.5.94, SDK 27, and WotLK database fixes.\n\n''' + s
p.write_text(s)
