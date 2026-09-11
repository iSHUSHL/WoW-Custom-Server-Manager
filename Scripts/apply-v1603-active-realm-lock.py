from pathlib import Path

p=Path('Sources/WoWServerControlCenter/ServerModel.swift')
s=p.read_text()

# Add active realm lock helpers before watchdog.
anchor='''    private func keepWorldAliveIfRequested() async {\n'''
if 'private var activeRealmLockURL' not in s:
    helper=r'''    private var activeRealmLockURL: URL {
        dataRoot.appendingPathComponent("runtime/active-realm-profile")
    }

    private func readActiveRealmLock() -> String? {
        guard let text = try? String(contentsOf: activeRealmLockURL, encoding: .utf8) else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func claimActiveRealmLock() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: activeRealmLockURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (selectedExpansion.rawValue + "\n").write(to: activeRealmLockURL, atomically: true, encoding: .utf8)
    }

    private func releaseActiveRealmLockIfOwned() {
        guard readActiveRealmLock() == selectedExpansion.rawValue else { return }
        try? FileManager.default.removeItem(at: activeRealmLockURL)
    }

    private func selectedExpansionOwnsActiveRealmLock() -> Bool {
        readActiveRealmLock() == selectedExpansion.rawValue
    }

'''
    if anchor not in s: raise SystemExit('watchdog anchor missing')
    s=s.replace(anchor,helper+anchor,1)

# Watchdog may only restart the currently claimed expansion.
s=s.replace('''    private func keepWorldAliveIfRequested() async {\n        guard desiredWorldRunning,\n              !worldWatchdogRestartInProgress else { return }\n''','''    private func keepWorldAliveIfRequested() async {\n        guard desiredWorldRunning,\n              selectedExpansionOwnsActiveRealmLock(),\n              !worldWatchdogRestartInProgress else { return }\n''',1)

# startAll claims lock before enabling desired state and cleans all other profiles.
s=s.replace('''    func startAll() {\n        desiredWorldRunning = true\n        Task {\n            do {\n                try ensureCompatibilityAlias()\n                try stopStaleServersFromOtherExpansions()\n''','''    func startAll() {\n        desiredWorldRunning = false\n        Task {\n            do {\n                try ensureCompatibilityAlias()\n                try stopStaleServersFromOtherExpansions()\n                try claimActiveRealmLock()\n                desiredWorldRunning = true\n''',1)

# If start fails and no owned world process is alive, revoke intent and lock.
old='''                } else {\n                    statusMessage = "Start failed: \\(error.localizedDescription)"\n                }\n            }\n            refresh()\n        }\n    }\n\n    func stopAll() {\n        desiredWorldRunning = false\n        worldWatchdogRestartInProgress = false\n        world?.stop(); auth?.stop(); mysql?.stop()\n'''
new='''                } else {\n                    desiredWorldRunning = false\n                    releaseActiveRealmLockIfOwned()\n                    statusMessage = "Start failed: \\(error.localizedDescription)"\n                }\n            }\n            refresh()\n        }\n    }\n\n    func stopAll() {\n        desiredWorldRunning = false\n        worldWatchdogRestartInProgress = false\n        releaseActiveRealmLockIfOwned()\n        world?.stop(); auth?.stop(); mysql?.stop()\n'''
if old in s: s=s.replace(old,new,1)
else: raise SystemExit('startAll catch/stopAll anchor missing')

# Direct world start also establishes exclusive ownership.
s=s.replace('''    func startWorldServer() {\n        desiredWorldRunning = true\n        Task {\n            do {\n                try ensureCompatibilityAlias()\n                try stopStaleServersFromOtherExpansions()\n''','''    func startWorldServer() {\n        desiredWorldRunning = false\n        Task {\n            do {\n                try ensureCompatibilityAlias()\n                try stopStaleServersFromOtherExpansions()\n                try claimActiveRealmLock()\n                desiredWorldRunning = true\n''',1)

# Direct realm start must claim the same exclusive profile lock too.
s=s.replace('''    func startRealmServer() {\n        Task {\n            do {\n                try ensureCompatibilityAlias()\n                try stopStaleServersFromOtherExpansions()\n''','''    func startRealmServer() {\n        Task {\n            do {\n                try ensureCompatibilityAlias()\n                try stopStaleServersFromOtherExpansions()\n                try claimActiveRealmLock()\n''',1)

# Explicit World stop cancels restart intent. If Auth is not running, release profile lock.
s=s.replace('''    func stopWorldServer() {\n        desiredWorldRunning = false\n        worldWatchdogRestartInProgress = false\n        world?.stop()\n''','''    func stopWorldServer() {\n        desiredWorldRunning = false\n        worldWatchdogRestartInProgress = false\n        if !authRunning { releaseActiveRealmLockIfOwned() }\n        world?.stop()\n''',1)

# Explicit Realm stop also cancels any watchdog intent. No hidden world resurrection.
s=s.replace('''    func stopRealmServer() {\n        auth?.stop()\n        authRunning = false\n''','''    func stopRealmServer() {\n        desiredWorldRunning = false\n        worldWatchdogRestartInProgress = false\n        auth?.stop()\n        authRunning = false\n        if !worldRunning { releaseActiveRealmLockIfOwned() }\n''',1)

# When switching expansion, didSet already calls stopAll; make sure stale lock is removed
# even if old process handles were already gone.
s=s.replace('''            saveExpansion()\n            stopAll()\n            loadProfileSettings()\n''','''            saveExpansion()\n            desiredWorldRunning = false\n            worldWatchdogRestartInProgress = false\n            try? FileManager.default.removeItem(at: dataRoot.appendingPathComponent("runtime/active-realm-profile"))\n            stopAll()\n            loadProfileSettings()\n''',1)

p.write_text(s)

# Bump build version.
b=Path('Build.command')
t=b.read_text().replace('<string>1.6.2</string>','<string>1.6.3</string>').replace('<string>1602</string>','<string>1603</string>')
b.write_text(t)

notes=Path('RELEASE-NOTES.md')
n=notes.read_text()
header='''# v1.6.3 — True Expansion Isolation / Active Realm Lock\n\n- Enforces one active WoW expansion profile at a time across Vanilla, TBC, WotLK, Cataclysm and MoP.\n- Adds a persistent Active Realm Lock under WoWCC runtime state.\n- Any Start first stops WoWCC-managed server processes from all other profiles, then claims the selected expansion as the only active profile.\n- World watchdog may auto-restart only when the selected profile owns the Active Realm Lock.\n- Stop All removes the lock and permanently cancels automatic restart until an explicit Start.\n- Stop World / Stop Realm cancel watchdog intent so a stopped TBC/Vanilla/WotLK server cannot silently start itself again.\n- Switching expansion clears stale active-profile state before rebuilding process controllers.\n\n'''
if not n.startswith('# v1.6.3'):
    notes.write_text(header+n)
print('Applied 1.6.3 active realm lock')
