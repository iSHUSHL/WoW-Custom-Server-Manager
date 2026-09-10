import Foundation
import SwiftUI
import AppKit

@MainActor
final class ServerModel: ObservableObject {
    @Published var selectedExpansion: ExpansionID = .wotlk {
        didSet {
            guard selectedExpansion != oldValue else { return }
            saveExpansion()
            stopAll()
            loadProfileSettings()
            lanAccessEnabled = UserDefaults.standard.bool(forKey: profileKey("lanAccess"))
            detectedLANIP = UserDefaults.standard.string(forKey: profileKey("lastLANIP")) ?? "Not detected"
            updateNetworkStatusFromCachedAddress()
            resetCollectionStateForExpansionChange()
            rebuildProcesses()
            refresh()
            DispatchQueue.main.async {
                self.catalogKind = .all
                self.loadCatalogPage(reset: true)
                self.loadGearSets()
            }
        }
    }
    @Published var mysqlRunning = false
    @Published var authRunning = false
    @Published var worldRunning = false
    @Published var realmDatabaseReady = false
    @Published var statusMessage = "Ready"
    @Published var operationActive = false
    @Published var operationName = "Idle"
    struct LogChoice: Identifiable {
        let id: String
        let title: String
        let url: URL
    }

    @Published var selectedLog = "worldserver.log"
    @Published var logText = ""

    var availableLogs: [LogChoice] {
        var result: [LogChoice] = [
            LogChoice(id: "worldserver.log", title: "World", url: logs.appendingPathComponent("worldserver.log")),
            LogChoice(id: "world-crash.log", title: "Crash / macOS Report", url: logs.appendingPathComponent("world-crash.log")),
            LogChoice(id: "authserver.log", title: "Auth", url: logs.appendingPathComponent("authserver.log")),
            LogChoice(id: "mysql.log", title: "MySQL", url: logs.appendingPathComponent("mysql.log")),
            LogChoice(id: "installer.log", title: "Installer", url: dataRoot.appendingPathComponent("runtime/installer.log")),
            LogChoice(id: "core-build.log", title: "Core Build", url: dataRoot.appendingPathComponent("runtime/\(selectedExpansion.rawValue)-core-build.log")),
            LogChoice(id: "cmake-configure.log", title: "CMake Configure", url: logs.appendingPathComponent("cmake-\(selectedExpansion.rawValue)-configure.log"))
        ]

        // Also expose any additional .log files created by current/future scripts
        // in the profile log folder or runtime root without requiring another UI change.
        let knownPaths = Set(result.map { $0.url.standardizedFileURL.path })
        var discovered: [LogChoice] = []
        let folders = [logs, dataRoot.appendingPathComponent("runtime")]
        for folder in folders {
            guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for file in files where file.pathExtension.lowercased() == "log" {
                guard !knownPaths.contains(file.standardizedFileURL.path) else { continue }
                let relativeID = "auto:" + file.standardizedFileURL.path
                discovered.append(LogChoice(id: relativeID, title: file.lastPathComponent, url: file))
            }
        }
        result.append(contentsOf: discovered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
        return result
    }
    @Published var searchText = ""
    @Published var catalogKind: CatalogKind = .raidSet
    @Published var itemQualityFilter: ItemQualityFilter = .all
    @Published var equipSlotFilter: EquipSlotFilter = .all
    @Published var playerClassFilter: PlayerClassFilter = .all
    @Published var gearSetClassFilter: PlayerClassFilter = .all
    @Published var minimumItemLevel = ""
    @Published var selectedCharacter: CharacterSummary?
    @Published var characters: [CharacterSummary] = []
    @Published var accounts: [AccountSummary] = []

    // Character creator. Character records are intentionally created by the
    // selected WoW client/core rather than direct SQL so every expansion gets
    // its correct starting spells, items, homebind and expansion-specific rows.
    @Published var creatorAccountID: Int?
    @Published var creatorName = ""
    @Published var creatorRace = "Human"
    @Published var creatorClass = "Warrior"
    @Published var creatorGender = "Male"
    @Published var inventory: [InventoryEntry] = []
    @Published var serverCatalog: [CatalogEntry] = []
    @Published var catalogStatus = "Choose a collection to load every matching item from the selected realm database"
    @Published var catalogLoading = false
    @Published var catalogPage = 0
    @Published var catalogHasMore = false
    @Published var itemIconURLs: [Int: URL] = [:]
    @Published var iconLoadingIDs: Set<Int> = []
    @Published var itemTooltipTexts: [Int: String] = [:]
    @Published var tooltipLoadingIDs: Set<Int> = []
    @Published var failedIconIDs: Set<Int> = []
    @Published var failedTooltipIDs: Set<Int> = []

    private let iconQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "WoWCC.ItemIconQueue"
        q.qualityOfService = .utility
        q.maxConcurrentOperationCount = 6
        return q
    }()

    private let tooltipQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "WoWCC.ItemTooltipQueue"
        q.qualityOfService = .utility
        q.maxConcurrentOperationCount = 4
        return q
    }()

    let catalogPageSize = 250
    @Published var gearSets: [GearSetSummary] = []
    @Published var gearSetsLoading = false
    @Published var gearSetCategory: GearSetCategory = .all
    @Published var selectedGearSet: GearSetSummary?
    @Published var gearSetStatus = "Load sets from the selected realm database"
    @Published var clientPath = ""
    @Published var customCorePath = ""
    @Published var newAccountName = ""
    @Published var newAccountPassword = ""
    @Published var gmLevel = 3
    @Published var healthChecks: [HealthCheckResult] = []
    @Published var healthCheckRunning = false
    @Published var lastHealthCheck: Date?
    @Published var lanAccessEnabled = false
    @Published var detectedLANIP = "Not detected"
    @Published var networkStatus = "Local access only"
    @Published var networkApplyInProgress = false
    @Published var playerBotPopulation = 150
    @Published var playerBotsEnabled = true
    @Published var playerBotsBattlegrounds = true
    @Published var playerBotsQuesting = true
    @Published var playerBotCreationSpeed = "Fast"
    @Published var playerBotAccountsLive = 0
    @Published var playerBotCharactersLive = 0
    @Published var playerBotsOnlineLive = 0
    @Published var playerBotStatsStatus = "Not checked"
    @Published var playerBotRuntimeConfigOK = false
    @Published var playerBotModuleSQLCount = 0

    let dataRoot: URL
    let assetsRoot: URL
    let mysqlPort = 3307
    let authPort: Int32 = 3724
    let worldPort: Int32 = 8085
    var compatibilityRoot: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".wowcc", isDirectory: true) }
    var profileRoot: URL { dataRoot.appendingPathComponent("runtime/profiles/\(selectedExpansion.rawValue)") }
    var profileDBRoot: URL { dataRoot.appendingPathComponent("runtime/mysql/\(selectedExpansion.rawValue)") }
    var itemIconCacheRoot: URL { dataRoot.appendingPathComponent("cache/item-icons", isDirectory: true) }
    var logs: URL { profileRoot.appendingPathComponent("logs") }
    private var mysql: ManagedProcess!
    private var auth: ManagedProcess!
    private var world: ManagedProcess!
    private var refreshTimer: Timer?
    private var lastRealmDBProbe = Date.distantPast
    private var statusProbeInProgress = false

    // User intent is tracked separately from a transient port probe.
    // If World was explicitly started, a momentary failed TCP probe must never
    // be interpreted as "stop it". If mangosd truly exits unexpectedly, the
    // watchdog can recover it without touching Auth/MySQL.
    private var desiredWorldRunning = false
    private var worldWatchdogRestartInProgress = false
    private var worldUnexpectedRestartCount = 0
    private var worldWatchdogWindowStarted = Date.distantPast

    init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dataRoot = appSupport.appendingPathComponent("WoWServerControlCenter", isDirectory: true)
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("WoWCC"), fm.fileExists(atPath: bundled.path) { assetsRoot = bundled }
        else { assetsRoot = URL(fileURLWithPath: fm.currentDirectoryPath) }
        try? fm.createDirectory(at: dataRoot.appendingPathComponent("runtime/profiles"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: dataRoot.appendingPathComponent("runtime/mysql"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: dataRoot.appendingPathComponent("runtime/backups"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: itemIconCacheRoot, withIntermediateDirectories: true)
        try? ensureCompatibilityAlias()
        if let raw = UserDefaults.standard.string(forKey: "expansion"), let e = ExpansionID(rawValue: raw) { selectedExpansion = e }
        loadProfileSettings()
        lanAccessEnabled = UserDefaults.standard.bool(forKey: profileKey("lanAccess"))
        detectedLANIP = UserDefaults.standard.string(forKey: profileKey("lastLANIP")) ?? "Not detected"
        updateNetworkStatusFromCachedAddress()
        rebuildProcesses()

        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refresh()
                await self.keepWorldAliveIfRequested()
            }
        }
    }

    var mysqlRuntimeInstalled: Bool { locateMySQL("mysqld") != nil && locateMySQL("mysql") != nil }
    var profileInstalled: Bool { FileManager.default.isExecutableFile(atPath: worldBinary.path) }
    var playerBotsReady: Bool { selectedExpansion == .tbc && FileManager.default.fileExists(atPath: profileRoot.appendingPathComponent(".playerbots-ready").path) && FileManager.default.fileExists(atPath: profileRoot.appendingPathComponent("configs/aiplayerbot.conf").path) }
    var clientConfigured: Bool { !clientPath.isEmpty && FileManager.default.fileExists(atPath: clientPath) }
    var runtimeDependenciesReady: Bool {
        let baseReady = locateMySQL("mysqld") != nil && locateMySQL("mysql") != nil && locateCommand("git") != nil && locateCommand("cmake") != nil && locateCommand("make") != nil
        if selectedExpansion == .cataclysm || selectedExpansion == .mop { return baseReady && locateCommand("7z") != nil }
        return baseReady
    }
    var requiredClientDataDirectories: [String] {
        switch selectedExpansion {
        case .wotlk: return ["dbc","maps","vmaps","mmaps"]
        case .vanilla, .tbc, .cataclysm, .mop: return ["dbc","maps","vmaps"]
        default: return []
        }
    }
    var clientDataReady: Bool {
        let dirs = requiredClientDataDirectories
        guard !dirs.isEmpty else { return selectedExpansion.maturity == .experimental }
        return dirs.allSatisfy { dir in
            dataDirectoryHasFiles(dir)
        }
    }

    private func dataDirectoryHasFiles(_ dir: String, minimum: Int = 1) -> Bool {
        let fm = FileManager.default
        let candidates = [
            profileRoot.appendingPathComponent("data/\(dir)"),
            profileRoot.appendingPathComponent("bin/\(dir)"),
            profileRoot.appendingPathComponent(dir)
        ]
        for candidate in candidates {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if let enumerator = fm.enumerator(at: candidate, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                var count = 0
                for case let url as URL in enumerator {
                    if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                        count += 1
                        if count >= minimum { return true }
                    }
                }
            }
        }
        return false
    }

    private func validateClientDataForStart() throws {
        guard !requiredClientDataDirectories.isEmpty else { return }

        let minimums: [String:Int] = selectedExpansion == .wotlk
            ? ["dbc":100, "maps":100, "vmaps":10, "mmaps":10]
            : ["dbc":1, "maps":1, "vmaps":1]

        var missing: [String] = []
        for dir in requiredClientDataDirectories {
            if !dataDirectoryHasFiles(dir, minimum: minimums[dir] ?? 1) {
                missing.append(dir)
            }
        }

        if !missing.isEmpty {
            throw err("Client/server data is incomplete: \(missing.joined(separator: ", ")). Run Prepare Client Data again and let every extractor finish successfully.")
        }
    }
    var sourceRoot: URL { dataRoot.appendingPathComponent("sources/\(selectedExpansion.rawValue)", isDirectory: true) }
    var catalog: [CatalogEntry] {
        let source = serverCatalog.isEmpty ? BuiltInCatalog.entries(for: selectedExpansion) : serverCatalog
        return source.filter { entry in
            let typeMatch: Bool
            if !serverCatalog.isEmpty {
                // Server queries are already scoped to the selected category.
                typeMatch = true
            } else if catalogKind == .weapon {
                typeMatch = entry.kind == .weapon || entry.kind == .legendary
            } else if catalogKind == .bis {
                typeMatch = entry.kind == .weapon || entry.kind == .armor || entry.kind == .legendary
            } else {
                typeMatch = entry.kind == catalogKind
            }
            return typeMatch && (searchText.isEmpty || entry.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var authBinaryName: String { selectedExpansion.serverFamily == .cmangos ? "realmd" : "authserver" }
    private var worldBinaryName: String { selectedExpansion.serverFamily == .cmangos ? "mangosd" : "worldserver" }
    private var authBinary: URL { profileRoot.appendingPathComponent("bin/\(authBinaryName)") }
    private var worldBinary: URL { profileRoot.appendingPathComponent("bin/\(worldBinaryName)") }
    private var authConfName: String { selectedExpansion.serverFamily == .cmangos ? "realmd.conf" : "authserver.conf" }
    private var worldConfName: String { selectedExpansion.serverFamily == .cmangos ? "mangosd.conf" : "worldserver.conf" }
    private var authDatabaseName: String {
        switch selectedExpansion {
        case .wotlk: return "acore_auth"
        case .vanilla, .tbc: return "realmd"
        case .cataclysm, .mop: return "auth"
        default: return "auth"
        }
    }
    private var characterDatabaseName: String { selectedExpansion == .wotlk ? "acore_characters" : "characters" }
    private var worldDatabaseName: String {
        switch selectedExpansion {
        case .wotlk: return "acore_world"
        case .vanilla, .tbc: return "mangos"
        default: return "world"
        }
    }

    func rebuildProcesses() {
        loadProfileSettings()
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: profileDBRoot, withIntermediateDirectories: true)
        mysql = ManagedProcess(logURL: logs.appendingPathComponent("mysql.log"))
        auth = ManagedProcess(logURL: logs.appendingPathComponent("authserver.log"))
        world = ManagedProcess(logURL: logs.appendingPathComponent("worldserver.log"))
    }

    func copyStatusToClipboard() {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(statusMessage, forType: .string)
    }

    func forgetClientLink() {
        clientPath = ""
        UserDefaults.standard.removeObject(forKey: profileKey("client"))
        statusMessage = "Client link removed. The original WoW client was not deleted."
    }

    func cleanBuildCache() { cleanPath(sourceRoot.appendingPathComponent("build"), label: "Build cache") }

    func removeDownloadedCore() {
        stopAll()
        let fm = FileManager.default
        for url in [sourceRoot.appendingPathComponent("core"), sourceRoot.appendingPathComponent("build"), profileRoot.appendingPathComponent("bin"), profileRoot.appendingPathComponent("configs")] {
            try? safeRemove(url)
        }
        try? safeRemove(profileRoot.appendingPathComponent(".core-installed"))
        try? safeRemove(profileRoot.appendingPathComponent(".realm-db-ready"))
        try? fm.createDirectory(at: profileRoot.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: profileRoot.appendingPathComponent("configs"), withIntermediateDirectories: true)
        realmDatabaseReady = false
        statusMessage = "Downloaded source/build and installed core removed for \(selectedExpansion.shortTitle). Realm database and extracted client data were kept."
        refresh()
    }

    func removeClientData() {
        stopAll()
        let data = profileRoot.appendingPathComponent("data")
        do {
            try safeRemove(data)
            try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
            statusMessage = "Extracted client/server data removed for \(selectedExpansion.shortTitle). The original WoW client was not deleted."
        } catch { statusMessage = "Client data cleanup failed: \(error.localizedDescription)" }
    }

    func removeDatabaseDownloadCache() {
        let targets = [sourceRoot.appendingPathComponent("database-release"), sourceRoot.appendingPathComponent("contentdb")]
        do {
            for url in targets { try safeRemove(url) }
            statusMessage = "Downloaded database/content cache removed for \(selectedExpansion.shortTitle). Live realm databases were kept."
        } catch { statusMessage = "Database cache cleanup failed: \(error.localizedDescription)" }
    }

    func clearLogs() {
        stopAll()
        do {
            try safeRemove(logs)
            try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
            for file in [dataRoot.appendingPathComponent("runtime/installer.log"), dataRoot.appendingPathComponent("runtime/\(selectedExpansion.rawValue)-core-build.log")] {
                try safeRemove(file)
            }
            rebuildProcesses()
            logText = ""
            statusMessage = "Logs cleared for \(selectedExpansion.shortTitle)"
        } catch { statusMessage = "Log cleanup failed: \(error.localizedDescription)" }
    }

    func clearBackupsForSelectedExpansion() {
        let fm = FileManager.default
        let root = dataRoot.appendingPathComponent("runtime/backups")
        do {
            let files = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("\(selectedExpansion.rawValue)-") { try safeRemove(file) }
            statusMessage = "Backups removed for \(selectedExpansion.shortTitle)"
        } catch { statusMessage = "Backup cleanup failed: \(error.localizedDescription)" }
    }

    func deleteRealmDatabase() {
        stopAll()
        do {
            try safeRemove(profileDBRoot)
            try FileManager.default.createDirectory(at: profileDBRoot, withIntermediateDirectories: true)
            try? safeRemove(profileRoot.appendingPathComponent(".realm-db-ready"))
            realmDatabaseReady = false
            characters = []; accounts = []; inventory = []
            statusMessage = "Realm database deleted for \(selectedExpansion.shortTitle). Accounts, characters and world DB state for this era are gone."
        } catch { statusMessage = "Realm database deletion failed: \(error.localizedDescription)" }
        rebuildProcesses(); refresh()
    }

    func cleanAllDownloadsForSelectedExpansion() {
        stopAll()
        do {
            try safeRemove(sourceRoot)
            for url in [profileRoot.appendingPathComponent("bin"), profileRoot.appendingPathComponent("configs"), profileRoot.appendingPathComponent("data")] { try safeRemove(url) }
            for dir in [profileRoot.appendingPathComponent("bin"), profileRoot.appendingPathComponent("configs"), profileRoot.appendingPathComponent("data")] {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try? safeRemove(profileRoot.appendingPathComponent(".core-installed"))
            try? safeRemove(profileRoot.appendingPathComponent(".realm-db-ready"))
            realmDatabaseReady = false
            statusMessage = "All app-downloaded core/source/build/database-cache and extracted client data removed for \(selectedExpansion.shortTitle). Realm DB, backups and original client were kept."
        } catch { statusMessage = "Download cleanup failed: \(error.localizedDescription)" }
        rebuildProcesses(); refresh()
    }

    func factoryResetSelectedExpansion() {
        stopAll()
        do {
            try safeRemove(sourceRoot)
            try safeRemove(profileRoot)
            try safeRemove(profileDBRoot)
            let backupRoot = dataRoot.appendingPathComponent("runtime/backups")
            let files = (try? FileManager.default.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.hasPrefix("\(selectedExpansion.rawValue)-") { try safeRemove(file) }
            UserDefaults.standard.removeObject(forKey: profileKey("client"))
            UserDefaults.standard.removeObject(forKey: profileKey("core"))
            clientPath = ""; customCorePath = ""
            characters = []; accounts = []; inventory = []; serverCatalog = []; gearSets = []; selectedGearSet = nil; selectedCharacter = nil
            realmDatabaseReady = false
            try FileManager.default.createDirectory(at: profileRoot, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: profileDBRoot, withIntermediateDirectories: true)
            statusMessage = "Factory reset complete for \(selectedExpansion.shortTitle). The original external WoW client was not deleted."
        } catch { statusMessage = "Factory reset failed: \(error.localizedDescription)" }
        rebuildProcesses(); refresh()
    }

    func openApplicationDataFolder() { NSWorkspace.shared.open(dataRoot) }

    private func cleanPath(_ url: URL, label: String) {
        do { try safeRemove(url); statusMessage = "\(label) removed for \(selectedExpansion.shortTitle)" }
        catch { statusMessage = "\(label) cleanup failed: \(error.localizedDescription)" }
    }

    private func safeRemove(_ url: URL) throws {
        let fm = FileManager.default
        let rootPath = dataRoot.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        guard targetPath == rootPath || targetPath.hasPrefix(rootPath + "/") else { throw err("Refusing to delete anything outside Control Center application data") }
        if fm.fileExists(atPath: targetPath) { try fm.removeItem(at: url) }
    }

    func saveExpansion() { UserDefaults.standard.set(selectedExpansion.rawValue, forKey: "expansion") }
    func refresh() {
        // Promote app-owned processes immediately, but never synchronously probe
        // ports or MySQL from the MainActor/SwiftUI render path.
        if mysql?.isRunning == true && !mysqlRunning { mysqlRunning = true }
        if auth?.isRunning == true && !authRunning { authRunning = true }
        if world?.isRunning == true && !worldRunning { worldRunning = true }

        refreshServiceStatusInBackground()
    }

    private func refreshServiceStatusInBackground() {
        guard !statusProbeInProgress else { return }

        let expansion = selectedExpansion
        let mysqlPortValue = Int32(mysqlPort)
        let authPortValue = authPort
        let worldPortValue = worldPort
        let mysqlExecutable = locateMySQL("mysql")
        let shouldProbeRealmDB = Date().timeIntervalSince(lastRealmDBProbe) >= 15
        let currentRealmReady = realmDatabaseReady

        let requiredTables: [(String, String)]
        switch expansion {
        case .wotlk:
            requiredTables = [
                ("acore_auth","account"),
                ("acore_auth","realmlist"),
                ("acore_characters","characters"),
                ("acore_characters","item_instance"),
                ("acore_characters","character_inventory"),
                ("acore_world","item_template"),
                ("acore_world","creature_template")
            ]
        case .vanilla, .tbc:
            requiredTables = [
                ("realmd","account"),
                ("realmd","realmlist"),
                ("characters","characters"),
                ("mangos","item_template"),
                ("mangos","creature_template")
            ]
        case .cataclysm, .mop:
            requiredTables = [
                ("auth","account"),
                ("auth","realmlist"),
                ("characters","characters"),
                ("world","item_template"),
                ("world","creature_template")
            ]
        default:
            requiredTables = []
        }

        statusProbeInProgress = true
        if shouldProbeRealmDB { lastRealmDBProbe = Date() }

        DispatchQueue.global(qos: .utility).async {
            let mysqlOpen = Self.backgroundPortOpen(mysqlPortValue)
            let authOpen = Self.backgroundPortOpen(authPortValue)
            let worldOpen = Self.backgroundPortOpen(worldPortValue)

            var dbReady = currentRealmReady
            if !mysqlOpen {
                dbReady = false
            } else if shouldProbeRealmDB {
                if let mysqlExecutable, !requiredTables.isEmpty {
                    dbReady = Self.backgroundRealmDatabaseReady(
                        mysqlExecutable: mysqlExecutable,
                        port: Int(mysqlPortValue),
                        requiredTables: requiredTables
                    )
                } else {
                    dbReady = false
                }
            }

            DispatchQueue.main.async {
                guard self.selectedExpansion == expansion else {
                    self.statusProbeInProgress = false
                    self.refresh()
                    return
                }

                if self.mysqlRunning != mysqlOpen { self.mysqlRunning = mysqlOpen }
                if self.authRunning != authOpen { self.authRunning = authOpen }

                // A heavily loaded PlayerBots world can briefly fail a TCP status probe
                // while mangosd itself is perfectly healthy. Process liveness wins for
                // app-owned World processes; an open port also covers already-running
                // servers discovered after app launch.
                let ownedWorldAlive = self.world?.isRunning == true
                let effectiveWorldUp = worldOpen || ownedWorldAlive
                if self.worldRunning != effectiveWorldUp { self.worldRunning = effectiveWorldUp }

                if self.realmDatabaseReady != dbReady { self.realmDatabaseReady = dbReady }

                self.statusProbeInProgress = false
            }
        }
    }

    nonisolated private static func backgroundPortOpen(_ port: Int32) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        p.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN"]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }

    nonisolated private static func backgroundRealmDatabaseReady(
        mysqlExecutable: String,
        port: Int,
        requiredTables: [(String, String)]
    ) -> Bool {
        let dbc = DatabaseClient(executable: mysqlExecutable, port: port)
        do {
            for (database, table) in requiredTables {
                let sql = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\(database)' AND table_name='\(table)';"
                let result = try dbc.query(database: "mysql", sql: sql)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if result != "1" { return false }
            }
            return true
        } catch {
            return false
        }
    }

    func refreshLogNow() {
        loadLog()
    }

    func bootstrapMac() { runScript("bootstrap-macos.sh", args: []) }
    func installMySQLRuntime() { runScript("mysql-manager.sh", args: ["install"]) }
    func repairMySQLRuntime() {
        stopAll()
        runScript("mysql-manager.sh", args: ["repair"])
    }
    func uninstallMySQLRuntime() {
        stopAll()
        runScript("mysql-manager.sh", args: ["uninstall"])
    }
    func restartManagedMySQL() {
        Task {
            do {
                mysql?.stop(); try await Task.sleep(for: .milliseconds(500))
                try await startMySQL(); try configureDatabaseAccess()
                statusMessage = "Managed MySQL restarted successfully"; refresh()
            } catch { statusMessage = "MySQL restart failed: \(error.localizedDescription)" }
        }
    }
    func installSelectedProfile() { runScript("install-profile.sh", args: [selectedExpansion.rawValue]) }
    func installOrRepairPlayerBots() {
        guard selectedExpansion == .tbc else { statusMessage = "PlayerBots world population is currently wired for TBC only"; return }
        guard profileInstalled else { statusMessage = "Build the TBC core first. Rebuild Core + PlayerBots compiles the module."; return }
        stopAll()
        Task {
            do {
                statusMessage = "Starting database for PlayerBots setup…"
                try await startMySQL()
                try configureDatabaseAccess()
                savePlayerBotSettings()
                let requestedBots = playerBotPopulation
                let stableBots = requestedBots
                if requestedBots > stableBots {
                    statusMessage = "Applying PlayerBots stability cap: \(requestedBots) requested → \(stableBots) simultaneous. Existing bot characters are preserved."
                }
                runScript("setup-playerbots.sh", args: ["tbc", "\(stableBots)", playerBotsEnabled ? "1" : "0", playerBotsBattlegrounds ? "1" : "0", playerBotsQuesting ? "1" : "0", playerBotCreationSpeed.lowercased()])
            } catch { statusMessage = "PlayerBots setup failed: \(error.localizedDescription)" }
        }
    }
    func applyPlayerBotSettings() { installOrRepairPlayerBots() }
    func setPlayerBotPreset(_ count: Int) { playerBotPopulation = min(5000,max(10,count)); savePlayerBotSettings() }
    private func savePlayerBotSettings() {
        UserDefaults.standard.set(playerBotPopulation, forKey: profileKey("playerBots.population"))
        UserDefaults.standard.set(playerBotsEnabled, forKey: profileKey("playerBots.enabled"))
        UserDefaults.standard.set(playerBotsBattlegrounds, forKey: profileKey("playerBots.battlegrounds"))
        UserDefaults.standard.set(playerBotsQuesting, forKey: profileKey("playerBots.questing"))
        UserDefaults.standard.set(playerBotCreationSpeed, forKey: profileKey("playerBots.creationSpeed"))
    }
    func setupSelectedProfile() {
        Task {
            do {
                statusMessage = "Starting database for realm setup…"
                try await startMySQL()
                try configureDatabaseAccess()
                runScript("setup-profile.sh", args: [selectedExpansion.rawValue, clientPath])
            } catch { statusMessage = "Setup failed: \(error.localizedDescription)" }
        }
    }

    func findClientOnline() {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: selectedExpansion.clientSearchQuery)]
        guard let url = components.url else {
            statusMessage = "Could not create client search URL"
            return
        }
        NSWorkspace.shared.open(url)
        statusMessage = "Searching the web for \(selectedExpansion.clientHint)"
    }

    func chooseClient() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.prompt = "Select WoW Client"
        if panel.runModal() == .OK, let url = panel.url { clientPath = url.path; saveProfileSettings(); statusMessage = "Client linked to \(selectedExpansion.shortTitle)" }
    }

    func chooseCustomCore() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.prompt = "Select Core Folder"
        if panel.runModal() == .OK, let url = panel.url { customCorePath = url.path; saveProfileSettings(); runScript("import-core.sh", args: [selectedExpansion.rawValue, url.path]) }
    }

    func play() {
        guard clientConfigured else { statusMessage = "Select a compatible WoW client first"; return }
        if !worldRunning { startAll() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let u = URL(fileURLWithPath: self.clientPath)
            if u.pathExtension.lowercased() == "app" {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: u, configuration: config) { _, error in Task { @MainActor in self.statusMessage = error == nil ? "Launching \(self.selectedExpansion.shortTitle)" : "Client launch failed: \(error!.localizedDescription)" } }
            } else if u.pathExtension.lowercased() == "exe" {
                let runners = ["/opt/homebrew/bin/wine64", "/opt/homebrew/bin/wine", "/usr/local/bin/wine64", "/usr/local/bin/wine"]
                if let runner = runners.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                    let p = Process(); p.executableURL = URL(fileURLWithPath: runner); p.arguments = [u.path]; p.currentDirectoryURL = u.deletingLastPathComponent()
                    do { try p.run(); self.statusMessage = "Launching Windows WoW client" } catch { self.statusMessage = "Wine launch failed: \(error.localizedDescription)" }
                } else { self.statusMessage = "Windows client selected. Install/configure a compatible Wine/CrossOver runner, or select a macOS .app client." }
            } else { NSWorkspace.shared.open(u); self.statusMessage = "Launching \(self.selectedExpansion.shortTitle) client" }
        }
    }

    private func repairCMaNGOSDatabaseConfigIfNeeded() throws {
        guard selectedExpansion.serverFamily == .cmangos else { return }

        let fm = FileManager.default
        let realmdURL = profileRoot.appendingPathComponent("configs/realmd.conf")
        let mangosdURL = profileRoot.appendingPathComponent("configs/mangosd.conf")

        guard fm.fileExists(atPath: realmdURL.path), fm.fileExists(atPath: mangosdURL.path) else {
            throw err("CMaNGOS config files are missing. Run Setup / Repair Realm.")
        }

        func forcing(_ text: String, key: String, value: String) -> String {
            var lines = text.components(separatedBy: .newlines)
            let prefix = key + " "
            var replaced = false

            for index in lines.indices {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(prefix) && trimmed.contains("=") {
                    lines[index] = "\(key) = \"\(value)\""
                    replaced = true
                    break
                }
            }

            if !replaced {
                lines.append("\(key) = \"\(value)\"")
            }
            return lines.joined(separator: "\n")
        }

        let port = "\(mysqlPort)"
        var realmdText = try String(contentsOf: realmdURL, encoding: .utf8)
        realmdText = forcing(
            realmdText,
            key: "LoginDatabaseInfo",
            value: "127.0.0.1;\(port);wowcc;wowcc;realmd"
        )
        try realmdText.write(to: realmdURL, atomically: true, encoding: .utf8)

        var mangosdText = try String(contentsOf: mangosdURL, encoding: .utf8)
        mangosdText = forcing(
            mangosdText,
            key: "LoginDatabaseInfo",
            value: "127.0.0.1;\(port);wowcc;wowcc;realmd"
        )
        mangosdText = forcing(
            mangosdText,
            key: "WorldDatabaseInfo",
            value: "127.0.0.1;\(port);wowcc;wowcc;mangos"
        )
        mangosdText = forcing(
            mangosdText,
            key: "CharacterDatabaseInfo",
            value: "127.0.0.1;\(port);wowcc;wowcc;characters"
        )
        mangosdText = forcing(
            mangosdText,
            key: "LogsDatabaseInfo",
            value: "127.0.0.1;\(port);wowcc;wowcc;logs"
        )
        mangosdText = forcing(
            mangosdText,
            key: "DataDir",
            value: profileRoot.appendingPathComponent("data").path
        )
        try mangosdText.write(to: mangosdURL, atomically: true, encoding: .utf8)

        let staleNames = ["tbcrealmd", "tbcmangos", "tbccharacters", "tbclogs"]
        let combined = realmdText + "\n" + mangosdText
        if let stale = staleNames.first(where: { combined.contains($0) }) {
            throw err("CMaNGOS config still contains stale database name '\(stale)'. Run Setup / Repair Realm.")
        }
    }

    private func ensurePlayerBotRuntimeConfig() throws {
        guard selectedExpansion == .tbc else { return }
        let fm = FileManager.default
        let configDir = profileRoot.appendingPathComponent("configs", isDirectory: true)
        let etcDir = profileRoot.appendingPathComponent("etc", isDirectory: true)
        try fm.createDirectory(at: etcDir, withIntermediateDirectories: true)
        let configured = configDir.appendingPathComponent("aiplayerbot.conf")
        let runtime = etcDir.appendingPathComponent("aiplayerbot.conf")

        if fm.fileExists(atPath: configured.path) {
            // SYSCONFDIR is ../etc/ for CMaNGOS when mangosd runs from profile/bin.
            // Always synchronize before launch so GUI settings and runtime cannot diverge.
            if fm.fileExists(atPath: runtime.path) { try fm.removeItem(at: runtime) }
            try fm.copyItem(at: configured, to: runtime)
        } else if !fm.fileExists(atPath: runtime.path) {
            throw err("PlayerBots runtime config is missing. Run PlayerBots → Populate / Repair World once.")
        }
    }

    private func waitForWorldReadyPlayerBotsAware() async throws {
        // First PlayerBots launch builds large item/equipment caches before opening 8085.
        // Official PlayerBots documentation explicitly warns first startup takes time.
        let timeoutSeconds = selectedExpansion == .tbc ? 900 : 30
        let iterations = max(1, timeoutSeconds * 4)
        for tick in 0..<iterations {
            if portOpen(worldPort) { return }
            if world.process != nil && !world.isRunning {
                let tail = lastLogLines("worldserver.log", count: 20)
                throw err("\(worldBinaryName) exited during startup. \(tail)")
            }

            if selectedExpansion == .tbc && tick % 4 == 0 {
                let tail = lastLogLines("worldserver.log", count: 8)
                if let range = tail.range(of: #"\[[* ]+\]\s*([0-9]{1,3})%"#, options: .regularExpression) {
                    let progress = String(tail[range])
                    statusMessage = "World Server starting — PlayerBots cache building \(progress)"
                } else {
                    statusMessage = "World Server starting — PlayerBots initialization in progress…"
                }
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        let tail = lastLogLines("worldserver.log", count: 20)
        throw err("\(worldBinaryName) is still running but did not open port \(worldPort) within \(timeoutSeconds / 60) minutes. \(tail)")
    }

    private func keepWorldAliveIfRequested() async {
        guard desiredWorldRunning,
              !worldWatchdogRestartInProgress else { return }

        // PlayerBots has substantial startup state. Automatically relaunching
        // mangosd after a genuine TBC crash creates a cache/init/relogin loop.
        // Never auto-restart TBC World; keep it stopped and surface the failure.
        if selectedExpansion == .tbc {
            if world?.isRunning == true || portOpen(worldPort) {
                worldRunning = true
            } else if worldRunning {
                worldRunning = false
                desiredWorldRunning = false
                if let termination = world?.lastTerminationSummary {
                    statusMessage = "World Server exited unexpectedly — \(termination)"
                } else {
                    statusMessage = "World Server exited unexpectedly — auto-restart disabled for PlayerBots. See world-crash.log."
                }
            }
            return
        }

        // If either the owned process is alive or the service is listening,
        // World is healthy. Never restart/kill it because of a single probe.
        if world?.isRunning == true || portOpen(worldPort) {
            worldRunning = true
            if Date().timeIntervalSince(worldWatchdogWindowStarted) > 120 {
                worldUnexpectedRestartCount = 0
            }
            return
        }

        // Do not thrash if dependencies are intentionally down.
        guard portOpen(Int32(mysqlPort)), portOpen(authPort) else { return }

        let now = Date()
        if now.timeIntervalSince(worldWatchdogWindowStarted) > 120 {
            worldWatchdogWindowStarted = now
            worldUnexpectedRestartCount = 0
        }

        guard worldUnexpectedRestartCount < 3 else {
            desiredWorldRunning = false
            statusMessage = "World stopped unexpectedly 3 times in 2 minutes — auto-restart paused. Check World log."
            return
        }

        worldUnexpectedRestartCount += 1
        worldWatchdogRestartInProgress = true
        statusMessage = "World Server exited unexpectedly — auto-restarting (\(worldUnexpectedRestartCount)/3)…"

        do {
            try ensureCompatibilityAlias()
            try ensurePlayerBotRuntimeConfig()
            try startWorld()
            try await waitForWorldReadyPlayerBotsAware()
            worldRunning = true
            statusMessage = "World Server recovered automatically"
            refreshPlayerBotStats()
        } catch {
            statusMessage = "World auto-restart failed: \(error.localizedDescription)"
        }

        worldWatchdogRestartInProgress = false
        refresh()
    }

    func startAll() {
        desiredWorldRunning = true
        Task {
            do {
                try ensureCompatibilityAlias()
                try repairCMaNGOSDatabaseConfigIfNeeded()

                statusMessage = "1/3 Starting managed MySQL 8.4…"
                try await startMySQL()
                try configureDatabaseAccess()
                guard portOpen(Int32(mysqlPort)) else { throw err("MySQL started but port \(mysqlPort) is not listening.") }

                realmDatabaseReady = probeRealmDatabaseReady()
                guard realmDatabaseReady else {
                    throw err("Realm database is not ready. Run Setup / Repair Realm first and wait for REALM DATABASE READY.")
                }

                statusMessage = "Checking DBC/maps/vmaps/mmaps…"
                try validateClientDataForStart()

                statusMessage = "2/3 Starting \(authBinaryName)…"
                if !portOpen(authPort) {
                    try startAuth()
                    try await waitForService(port: authPort, process: auth, label: authBinaryName, timeoutSeconds: 20, logName: "authserver.log")
                }
                authRunning = true

                statusMessage = "3/3 Starting \(worldBinaryName)…"
                if !portOpen(worldPort) {
                    try ensurePlayerBotRuntimeConfig()
                    try startWorld()
                    try await waitForWorldReadyPlayerBotsAware()
                }
                worldRunning = true

                statusMessage = "ONLINE — MySQL, Auth and World Server are running"
                refreshPlayerBotStats()
                loadCharacters()
                loadAccounts()
            } catch {
                refresh()
                if world?.isRunning == true {
                    worldRunning = true
                    statusMessage = "World Server is still initializing — process is alive"
                } else {
                    statusMessage = "Start failed: \(error.localizedDescription)"
                }
            }
            refresh()
        }
    }

    func stopAll() {
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = false
        world?.stop(); auth?.stop(); mysql?.stop()
        statusMessage = "Server stopped"
        refresh()
    }
    func restartAll() {
        stopAll()
        DispatchQueue.main.asyncAfter(deadline: .now()+1) { self.startAll() }
    }

    func stopWorldServer() {
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = false
        world?.stop()
        worldRunning = false
        statusMessage = "World Server stopped"
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { self.refresh() }
    }

    func startWorldServer() {
        desiredWorldRunning = true
        Task {
            do {
                try ensureCompatibilityAlias()
                try repairCMaNGOSDatabaseConfigIfNeeded()
                guard portOpen(Int32(mysqlPort)) else { throw err("MySQL must be running before World Server.") }
                guard realmDatabaseReady || probeRealmDatabaseReady() else { throw err("Realm database is not ready.") }
                try validateClientDataForStart()
                if !portOpen(worldPort) {
                    try ensurePlayerBotRuntimeConfig()
                    try startWorld()
                    try await waitForWorldReadyPlayerBotsAware()
                }
                worldRunning = true
                statusMessage = "World Server running"
                refreshPlayerBotStats()
            } catch {
                if world?.isRunning == true {
                    worldRunning = true
                    statusMessage = "World Server is still initializing — process is alive"
                } else {
                    statusMessage = "World start failed: \(error.localizedDescription)"
                }
            }
            refresh()
        }
    }

    func restartWorldServer() {
        // Intentional restart: suppress watchdog while old mangosd shuts down.
        desiredWorldRunning = false
        worldWatchdogRestartInProgress = true
        world?.stop()
        worldRunning = false
        statusMessage = "Restarting World Server…"
        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
            self.worldWatchdogRestartInProgress = false
            self.startWorldServer()
        }
    }

    func stopRealmServer() {
        auth?.stop()
        authRunning = false
        statusMessage = "Realm Server stopped"
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { self.refresh() }
    }

    func startRealmServer() {
        Task {
            do {
                try ensureCompatibilityAlias()
                try repairCMaNGOSDatabaseConfigIfNeeded()
                guard portOpen(Int32(mysqlPort)) else { throw err("MySQL must be running before Realm Server.") }
                guard realmDatabaseReady || probeRealmDatabaseReady() else { throw err("Realm database is not ready.") }
                if !portOpen(authPort) {
                    try startAuth()
                    try await waitForService(port: authPort, process: auth, label: authBinaryName, timeoutSeconds: 20, logName: "authserver.log")
                }
                authRunning = true
                statusMessage = "Realm Server running"
            } catch {
                statusMessage = "Realm start failed: \(error.localizedDescription)"
            }
            refresh()
        }
    }

    func restartRealmServer() {
        auth?.stop()
        authRunning = false
        statusMessage = "Restarting Realm Server…"
        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) { self.startRealmServer() }
    }

    func stopMySQLServer() {
        guard !worldRunning && !authRunning else {
            statusMessage = "Stop World and Realm before stopping MySQL."
            return
        }
        mysql?.stop()
        mysqlRunning = false
        statusMessage = "MySQL stopped"
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { self.refresh() }
    }

    func startMySQLServer() {
        Task {
            do {
                statusMessage = "Starting managed MySQL 8.4…"
                try await startMySQL()
                try configureDatabaseAccess()
                mysqlRunning = true
                realmDatabaseReady = probeRealmDatabaseReady()
                statusMessage = "MySQL running"
            } catch {
                statusMessage = "MySQL start failed: \(error.localizedDescription)"
            }
            refresh()
        }
    }

    func restartMySQLServer() {
        guard !worldRunning && !authRunning else {
            statusMessage = "Stop World and Realm before restarting MySQL."
            return
        }
        mysql?.stop()
        mysqlRunning = false
        statusMessage = "Restarting MySQL…"
        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) { self.startMySQLServer() }
    }

    func startMySQL() async throws {
        if portOpen(Int32(mysqlPort)) {
            mysqlRunning = true
            return
        }
        guard let mysqld = locateMySQL("mysqld") else { throw err("MySQL 8.4 is not installed yet. Click Install Runtime Dependencies once; Control Center will manage it afterwards.") }
        let datadir = profileDBRoot.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: datadir, withIntermediateDirectories: true)
        let marker = datadir.appendingPathComponent("mysql")
        if !FileManager.default.fileExists(atPath: marker.path) {
            statusMessage = "Initializing local database…"
            try runSync(mysqld, ["--no-defaults", "--initialize-insecure", "--datadir=\(datadir.path)"])
        }
        let socket = profileDBRoot.appendingPathComponent("mysql.sock").path
        try mysql.start(executable: URL(fileURLWithPath: mysqld), arguments: ["--no-defaults", "--datadir=\(datadir.path)", "--port=\(mysqlPort)", "--bind-address=127.0.0.1", "--socket=\(socket)", "--mysqlx=0"])
        for _ in 0..<30 {
            if portOpen(Int32(mysqlPort)) {
                mysqlRunning = true
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw err("Managed MySQL did not become ready")
    }

    private func configureDatabaseAccess() throws {
        guard let mysqlExe = locateMySQL("mysql") else { throw err("mysql client not found") }
        let p = Process(); p.executableURL = URL(fileURLWithPath: mysqlExe)
        p.arguments = ["--protocol=TCP", "-h", "127.0.0.1", "-P", "\(mysqlPort)", "-u", "root", "-e", "CREATE USER IF NOT EXISTS 'wowcc'@'127.0.0.1' IDENTIFIED BY 'wowcc'; CREATE USER IF NOT EXISTS 'wowcc'@'localhost' IDENTIFIED BY 'wowcc'; GRANT ALL PRIVILEGES ON *.* TO 'wowcc'@'127.0.0.1'; GRANT ALL PRIVILEGES ON *.* TO 'wowcc'@'localhost'; FLUSH PRIVILEGES;"]
        let errPipe = Pipe(); p.standardError = errPipe; try p.run(); p.waitUntilExit()
        if p.terminationStatus != 0 { throw err(String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unable to configure DB user") }
    }

    func startAuth() throws { try startBinary(authBinaryName, process: auth, interactive: false, confName: authConfName) }
    func startWorld() throws { try startBinary(worldBinaryName, process: world, interactive: true, confName: worldConfName) }

    private func startBinary(_ name: String, process: ManagedProcess, interactive: Bool, confName: String) throws {
        try ensureCompatibilityAlias()

        let realBin = profileRoot.appendingPathComponent("bin/\(name)")
        guard FileManager.default.isExecutableFile(atPath: realBin.path) else {
            throw err("\(selectedExpansion.title) core is not installed/imported.")
        }

        // Launch through ~/.wowcc so AzerothCore/CMaNGOS never receive an
        // Application Support path containing spaces.
        let aliasProfile = compatibilityRoot.appendingPathComponent("runtime/profiles/\(selectedExpansion.rawValue)")
        let aliasBin = aliasProfile.appendingPathComponent("bin/\(name)")
        let aliasConf = aliasProfile.appendingPathComponent("configs/\(confName)")
        let realConf = profileRoot.appendingPathComponent("configs/\(confName)")

        var arguments: [String] = []
        if FileManager.default.fileExists(atPath: realConf.path) {
            arguments = ["-c", aliasConf.path]
        }

        try process.start(
            executable: aliasBin,
            arguments: arguments,
            currentDirectory: aliasProfile.appendingPathComponent("bin"),
            interactive: interactive
        )
    }

    private func waitForService(port: Int32, process: ManagedProcess, label: String, timeoutSeconds: Int, logName: String) async throws {
        let iterations = max(1, timeoutSeconds * 4)
        for _ in 0..<iterations {
            if portOpen(port) { return }
            if process.process != nil && !process.isRunning {
                let tail = lastLogLines(logName, count: 12)
                throw err("\(label) exited before opening port \(port). \(tail)")
            }
            try await Task.sleep(for: .milliseconds(250))
        }

        let tail = lastLogLines(logName, count: 12)
        throw err("\(label) did not open port \(port) within \(timeoutSeconds)s. \(tail)")
    }

    private func lastLogLines(_ name: String, count: Int) -> String {
        let url = logs.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else {
            return "No log output was captured."
        }
        let ansiPattern = "\\u{001B}\\[[0-9;]*[A-Za-z]"
        let cleaned: String
        if let regex = try? NSRegularExpression(pattern: ansiPattern) {
            let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
            cleaned = regex.stringByReplacingMatches(in: contents, range: range, withTemplate: "")
        } else {
            cleaned = contents
        }
        let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: true)
        let tail = lines.suffix(count).joined(separator: " | ")
        return tail.isEmpty ? "No log output was captured." : String(tail.suffix(1800))
    }

    private func ensureCompatibilityAlias() throws {
        let fm = FileManager.default
        let alias = compatibilityRoot
        let aliasPath = alias.path
        let targetPath = dataRoot.standardizedFileURL.path

        if let values = try? alias.resourceValues(forKeys: [.isSymbolicLinkKey]),
           values.isSymbolicLink == true {
            let destination = try fm.destinationOfSymbolicLink(atPath: aliasPath)
            let resolved: String
            if destination.hasPrefix("/") {
                resolved = URL(fileURLWithPath: destination).standardizedFileURL.path
            } else {
                resolved = alias.deletingLastPathComponent().appendingPathComponent(destination).standardizedFileURL.path
            }
            if resolved == targetPath { return }
            try fm.removeItem(at: alias)
        } else if fm.fileExists(atPath: aliasPath) {
            throw err("\(aliasPath) exists but is not the Control Center compatibility symlink. Rename or remove it, then retry.")
        }

        try fm.createSymbolicLink(at: alias, withDestinationURL: dataRoot)
    }

    private func cmangosMailItemCommand(characterName: String, itemID: Int, count: Int, subject: String = "WoWCC Item") -> String {
        let safeSubject = subject.replacingOccurrences(of: "\"", with: "'")
        return "send items \(characterName) \"\(safeSubject)\" \"Delivered by WoW Control Center\" \(itemID):\(max(1, count))"
    }

    func give(_ entry: CatalogEntry) {
        guard let character = selectedCharacter else {
            statusMessage = "Select a character first"
            return
        }
        guard worldRunning || world?.isRunning == true else {
            statusMessage = "Start World Server first"
            return
        }

        switch selectedExpansion.serverFamily {
        case .azerothCore:
            if entry.kind == .mount, let spell = entry.spellID {
                sendAdminCommand(
                    "player learn \(character.name) \(spell)",
                    success: "Learned \(entry.name) on \(character.name)"
                )
            } else {
                sendAdminCommand(
                    "additem \(character.name) \(entry.id) 1",
                    success: "Gave \(entry.name) to \(character.name)"
                )
            }

        case .cmangos:
            // CMaNGOS .additem/.learn operate on an in-game selected target and
            // are not the right commands for our server-console adapter.
            // `send items` is console-safe, supports an explicit character name,
            // works for offline characters, and also works for TBC mount-teaching
            // items: the player learns the mount by using the delivered item.
            sendAdminCommand(
                cmangosMailItemCommand(
                    characterName: character.name,
                    itemID: entry.id,
                    count: 1,
                    subject: entry.kind == .mount ? "WoWCC Mount" : "WoWCC Item"
                ),
                success: entry.kind == .mount
                    ? "TBC mount item mailed to \(character.name)"
                    : "Item \(entry.name) mailed to \(character.name)"
            )

        case .custom:
            statusMessage = "Give/Learn is not configured for this custom core."
        }
    }

    func giveCustomItem(id: Int, count: Int) {
        guard let c = selectedCharacter else {
            statusMessage = "Select a character first"
            return
        }
        guard worldRunning || world?.isRunning == true else {
            statusMessage = "Start World Server first"
            return
        }

        switch selectedExpansion.serverFamily {
        case .azerothCore:
            sendAdminCommand(
                "additem \(c.name) \(id) \(max(1,count))",
                success: "Item \(id) sent to \(c.name)"
            )
        case .cmangos:
            sendAdminCommand(
                cmangosMailItemCommand(
                    characterName: c.name,
                    itemID: id,
                    count: count,
                    subject: "WoWCC Custom Item"
                ),
                success: "Item \(id) mailed to \(c.name)"
            )
        case .custom:
            statusMessage = "Give Item is not configured for this custom core."
        }
    }

    func learnCustomSpell(id: Int) {
        guard let c = selectedCharacter else {
            statusMessage = "Select a character first"
            return
        }

        switch selectedExpansion.serverFamily {
        case .azerothCore:
            guard worldRunning || world?.isRunning == true else {
                statusMessage = "Start World Server first"
                return
            }
            sendAdminCommand(
                "player learn \(c.name) \(id)",
                success: "Spell \(id) learned by \(c.name)"
            )

        case .cmangos:
            // CMaNGOS `learn` requires an in-game selected unit and is not
            // console-safe. For an OFFLINE character the canonical character
            // table can be updated safely and the spell is loaded at next login.
            guard !c.online else {
                statusMessage = "CMaNGOS direct spell learn requires \(c.name) to be offline. Log the character out and click Learn again."
                return
            }
            do {
                let client = try dbClient()
                try client.execute(
                    database: characterDatabaseName,
                    sql: "INSERT INTO character_spell (guid,spell,active,disabled) VALUES (\(c.id),\(id),1,0) ON DUPLICATE KEY UPDATE active=1,disabled=0;"
                )
                statusMessage = "Spell \(id) learned by \(c.name) — available at next login."
            } catch {
                statusMessage = "CMaNGOS spell learn failed: \(error.localizedDescription)"
            }

        case .custom:
            statusMessage = "Learn Spell is not configured for this custom core."
        }
    }

    func setLevel(_ level: Int) {
        guard let c = selectedCharacter else {
            statusMessage = "Select a character first"
            return
        }
        guard worldRunning || world?.isRunning == true else {
            statusMessage = "Start World Server first"
            return
        }

        switch selectedExpansion.serverFamily {
        case .azerothCore:
            let delta = level - c.level
            if delta == 0 {
                statusMessage = "\(c.name) is already level \(level)"
                return
            }
            sendAdminCommand(
                "levelup \(c.name) \(delta)",
                success: "Set-level command sent to \(c.name): \(level)"
            )

        case .cmangos:
            let maxLevel = selectedExpansion == .tbc ? 70 : 60
            let target = min(max(1, level), maxLevel)
            // `character level` is explicitly console-capable in CMaNGOS and
            // supports a named/offline character.
            sendAdminCommand(
                "character level \(c.name) \(target)",
                success: "\(c.name) level set to \(target)"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.loadCharacters()
            }

        case .custom:
            statusMessage = "Set Level is not configured for this custom core."
        }
    }

    var characterCreatorRaces: [String] {
        switch selectedExpansion {
        case .vanilla:
            return ["Human","Dwarf","Night Elf","Gnome","Orc","Undead","Tauren","Troll"]
        case .tbc:
            return ["Human","Dwarf","Night Elf","Gnome","Draenei","Orc","Undead","Tauren","Troll","Blood Elf"]
        case .wotlk, .cataclysm:
            return ["Human","Dwarf","Night Elf","Gnome","Draenei","Worgen","Orc","Undead","Tauren","Troll","Blood Elf","Goblin"]
                .filter { selectedExpansion == .cataclysm || !["Worgen","Goblin"].contains($0) }
        case .mop:
            return ["Human","Dwarf","Night Elf","Gnome","Draenei","Worgen","Pandaren","Orc","Undead","Tauren","Troll","Blood Elf","Goblin"]
        default:
            // Later profiles are custom/experimental. Keep the modern common
            // races visible without pretending the app can validate every
            // custom core's allied-race implementation.
            return ["Human","Dwarf","Night Elf","Gnome","Draenei","Worgen","Pandaren","Orc","Undead","Tauren","Troll","Blood Elf","Goblin"]
        }
    }

    var characterCreatorClasses: [String] {
        switch selectedExpansion {
        case .vanilla:
            return ["Warrior","Paladin","Hunter","Rogue","Priest","Shaman","Mage","Warlock","Druid"]
        case .tbc:
            return ["Warrior","Paladin","Hunter","Rogue","Priest","Shaman","Mage","Warlock","Druid"]
        case .wotlk, .cataclysm:
            return ["Warrior","Paladin","Hunter","Rogue","Priest","Death Knight","Shaman","Mage","Warlock","Druid"]
        case .mop:
            return ["Warrior","Paladin","Hunter","Rogue","Priest","Death Knight","Shaman","Mage","Warlock","Monk","Druid"]
        case .wod:
            return ["Warrior","Paladin","Hunter","Rogue","Priest","Death Knight","Shaman","Mage","Warlock","Monk","Druid"]
        case .legion, .bfa, .shadowlands, .dragonflight, .warWithin:
            return ["Warrior","Paladin","Hunter","Rogue","Priest","Death Knight","Shaman","Mage","Warlock","Monk","Druid","Demon Hunter"]
        }
    }

    func normalizeCharacterCreatorSelection() {
        if !characterCreatorRaces.contains(creatorRace) {
            creatorRace = characterCreatorRaces.first ?? "Human"
        }
        if !characterCreatorClasses.contains(creatorClass) {
            creatorClass = characterCreatorClasses.first ?? "Warrior"
        }
        if creatorAccountID == nil || !accounts.contains(where: { $0.id == creatorAccountID }) {
            creatorAccountID = accounts.first?.id
        }
    }

    func openCharacterCreator() {
        let trimmed = creatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clientConfigured else {
            statusMessage = "Select the \(selectedExpansion.shortTitle) WoW client first."
            return
        }
        guard let accountID = creatorAccountID,
              let account = accounts.first(where: { $0.id == accountID }) else {
            statusMessage = "Create or select an account first."
            return
        }

        // Character creation is performed by the client/core handshake. This is
        // deliberate: direct INSERTs are not portable across CMaNGOS,
        // AzerothCore and the Cata/MoP Trinity-family schemas.
        let plan = trimmed.isEmpty
            ? "\(creatorRace) \(creatorClass), \(creatorGender)"
            : "\(trimmed) — \(creatorRace) \(creatorClass), \(creatorGender)"

        statusMessage = "Opening \(selectedExpansion.shortTitle) character creator for \(account.username): \(plan)"
        play()
    }

    func loadCharacters() {
        do {
            let client = try dbClient()
            let db = characterDatabaseName
            let authDB = authDatabaseName
            let sql: String
            if selectedExpansion.serverFamily == .cmangos {
                // Show real/player-created characters in the admin page; random bot
                // accounts are reported separately on PlayerBots.
                sql = """
                SELECT c.guid,c.name,c.level,c.race,c.class,c.online
                FROM characters c
                LEFT JOIN \(authDB).account a ON a.id=c.account
                WHERE a.username IS NULL OR UPPER(a.username) NOT LIKE 'RNDBOT%'
                ORDER BY c.name;
                """
            } else {
                sql = "SELECT guid,name,level,race,class,online FROM characters ORDER BY name;"
            }
            let text = try client.query(database: db, sql: sql)
            characters = text.split(separator: "\n").compactMap { line in
                let f = line.split(separator: "\t", omittingEmptySubsequences: false); guard f.count >= 6 else { return nil }
                return CharacterSummary(id: Int(f[0]) ?? 0, name: String(f[1]), level: Int(f[2]) ?? 0, race: raceName(Int(f[3]) ?? 0), playerClass: className(Int(f[4]) ?? 0), online: f[5] == "1")
            }
            if selectedCharacter == nil || !characters.contains(where: { $0.id == selectedCharacter?.id }) { selectedCharacter = characters.first }
            loadInventory()
            mysqlRunning = true
            statusMessage = "Loaded \(characters.count) player character(s)"
        } catch { statusMessage = "Character DB: \(error.localizedDescription)" }
    }

    func refreshPlayerBotStats() {
        guard selectedExpansion == .tbc else {
            playerBotAccountsLive = 0; playerBotCharactersLive = 0; playerBotsOnlineLive = 0
            playerBotStatsStatus = "TBC only"
            return
        }
        do {
            let client = try dbClient()
            let accountsText = try client.query(database: authDatabaseName, sql: "SELECT COUNT(*) FROM account WHERE UPPER(username) LIKE 'RNDBOT%';")
            let charsText = try client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM characters c JOIN \(authDatabaseName).account a ON a.id=c.account WHERE UPPER(a.username) LIKE 'RNDBOT%';")
            let onlineText = try client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM characters c JOIN \(authDatabaseName).account a ON a.id=c.account WHERE UPPER(a.username) LIKE 'RNDBOT%' AND c.online=1;")
            playerBotAccountsLive = Int(accountsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            playerBotCharactersLive = Int(charsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            playerBotsOnlineLive = Int(onlineText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let runtimeConf = profileRoot.appendingPathComponent("etc/aiplayerbot.conf")
            let configuredConf = profileRoot.appendingPathComponent("configs/aiplayerbot.conf")
            let runtimeText = try? String(contentsOf: runtimeConf, encoding: .utf8)
            let configuredText = try? String(contentsOf: configuredConf, encoding: .utf8)
            let enabledPattern = #"(?m)^\s*AiPlayerbot\.Enabled\s*=\s*1\s*$"#
            playerBotRuntimeConfigOK =
                runtimeText?.range(of: enabledPattern, options: .regularExpression) != nil ||
                configuredText?.range(of: enabledPattern, options: .regularExpression) != nil
            let migrationText = try? client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM wowcc_playerbots_migrations;")
            playerBotModuleSQLCount = Int(migrationText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
            if !playerBotRuntimeConfigOK {
                playerBotStatsStatus = "Runtime config missing"
            } else if playerBotModuleSQLCount == 0 {
                playerBotStatsStatus = "PlayerBots SQL missing"
            } else if worldRunning && playerBotsOnlineLive == 0 {
                playerBotStatsStatus = "Ready, but 0 online — initialize bots"
            } else {
                playerBotStatsStatus = worldRunning ? "LIVE" : "World stopped"
            }
        } catch {
            playerBotStatsStatus = "Stats unavailable"
        }
    }

    func initializePlayerBots() {
        guard selectedExpansion == .tbc else { statusMessage = "PlayerBots initialization is TBC only."; return }
        guard worldRunning || world?.isRunning == true else { statusMessage = "Start World Server first."; return }

        // One-shot initialization only. Do NOT immediately issue rndbot update:
        // the random-bot manager already performs its own scheduled updates and
        // forcing an update after init can cause unnecessary population churn.
        statusMessage = "Initializing random PlayerBots once…"
        sendAdminCommand("rndbot init", success: "PlayerBots one-time initialization requested")
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { self.refreshPlayerBotStats() }
    }


    func loadInventory() {
        guard mysqlRunning, let c = selectedCharacter else { inventory = []; return }
        do {
            let client = try dbClient()
            let charDB = characterDatabaseName
            let worldDB = worldDatabaseName
            let rows = try client.query(database: charDB, sql: "SELECT ci.item, ii.itemEntry, ci.bag, ci.slot FROM character_inventory ci JOIN item_instance ii ON ii.guid=ci.item WHERE ci.guid=\(c.id) ORDER BY ci.bag,ci.slot;")
            let ids = rows.split(separator: "\n").compactMap { Int($0.split(separator: "\t").dropFirst().first ?? "") }
            var names: [Int:String] = [:]
            if !ids.isEmpty {
                let list = Array(Set(ids)).map(String.init).joined(separator: ",")
                let nr = try client.query(database: worldDB, sql: "SELECT entry,name FROM item_template WHERE entry IN (\(list));")
                for line in nr.split(separator: "\n") { let f=line.split(separator:"\t",omittingEmptySubsequences:false); if f.count >= 2, let id=Int(f[0]) { names[id]=String(f[1]) } }
            }
            inventory = rows.split(separator: "\n").compactMap { line in
                let f=line.split(separator:"\t",omittingEmptySubsequences:false); guard f.count >= 4, let guid=Int(f[0]), let entry=Int(f[1]) else { return nil }
                return InventoryEntry(id: guid, itemEntry: entry, name: names[entry] ?? "Item #\(entry)", bag: Int(f[2]) ?? 0, slot: Int(f[3]) ?? 0)
            }
        } catch { statusMessage = "Inventory DB: \(error.localizedDescription)" }
    }

    func basicTooltip(for item: CatalogEntry) -> String {
        var lines = [item.name]
        lines.append(item.quality)
        lines.append(item.subtitle)
        if let ilvl=item.itemLevel { lines.append("Item Level \(ilvl)") }
        if let setID=item.itemSetID { lines.append("Item Set #\(setID)") }
        lines.append("Item ID \(item.id)")
        return lines.joined(separator:"\n")
    }

    func tooltipText(for item: CatalogEntry) -> String {
        itemTooltipTexts[item.id] ?? basicTooltip(for:item)
    }

    func resolveTooltip(for item: CatalogEntry) {
        let id=item.id
        guard id > 0 else { return }
        guard itemTooltipTexts[id] == nil else { return }
        guard !tooltipLoadingIDs.contains(id) else { return }
        guard !failedTooltipIDs.contains(id) else { return }

        tooltipLoadingIDs.insert(id)
        let expansion=selectedExpansion

        tooltipQueue.addOperation {
            func finishFailure() {
                DispatchQueue.main.async {
                    self.tooltipLoadingIDs.remove(id)
                    self.failedTooltipIDs.insert(id)
                }
            }

            let endpoint: String
            switch expansion {
            case .tbc: endpoint="https://www.wowhead.com/tbc/item=\(id)&xml"
            case .wotlk: endpoint="https://www.wowhead.com/wotlk/item=\(id)&xml"
            default: endpoint="https://www.wowhead.com/item=\(id)&xml"
            }
            guard let url=URL(string:endpoint) else { finishFailure(); return }

            var req=URLRequest(url:url)
            req.timeoutInterval=7
            req.cachePolicy = .returnCacheDataElseLoad
            req.setValue("WoWServerControlCenter/1.5",forHTTPHeaderField:"User-Agent")

            let sem=DispatchSemaphore(value:0)
            var data:Data?
            var status=0
            URLSession.shared.dataTask(with:req) { d,response,_ in
                data=d
                status=(response as? HTTPURLResponse)?.statusCode ?? 0
                sem.signal()
            }.resume()

            guard sem.wait(timeout:.now()+8) == .success,
                  (200..<300).contains(status),
                  let data,
                  let xml=String(data:data,encoding:.utf8) else {
                finishFailure()
                return
            }

            guard let a=xml.range(of:"<htmlTooltip>"),
                  let b=xml.range(of:"</htmlTooltip>",range:a.upperBound..<xml.endIndex) else {
                finishFailure()
                return
            }

            var html=String(xml[a.upperBound..<b.lowerBound])
            html=html.replacingOccurrences(of:"<![CDATA[",with:"")
                     .replacingOccurrences(of:"]]>",with:"")

            let breaks=["<br />","<br/>","<br>","</tr>","</table>","</div>"]
            for br in breaks {
                html=html.replacingOccurrences(of:br,with:"\n",options:.caseInsensitive)
            }
            html=html.replacingOccurrences(of:"</td>",with:"    ",options:.caseInsensitive)
            html=html.replacingOccurrences(of:"</th>",with:"    ",options:.caseInsensitive)
            html=html.replacingOccurrences(of:"<[^>]+>",with:"",options:.regularExpression)

            let entities=[
                "&nbsp;":" ", "&#160;":" ", "&amp;":"&", "&lt;":"<", "&gt;":">",
                "&quot;":"\"", "&#39;":"'"
            ]
            for (e,v) in entities { html=html.replacingOccurrences(of:e,with:v) }

            html=html.replacingOccurrences(of:"[ \\t]+\\n",with:"\n",options:.regularExpression)
            html=html.replacingOccurrences(of:"\\n{3,}",with:"\n\n",options:.regularExpression)
            html=html.trimmingCharacters(in:.whitespacesAndNewlines)

            guard !html.isEmpty else { finishFailure(); return }

            DispatchQueue.main.async {
                self.itemTooltipTexts[id]=html
                self.tooltipLoadingIDs.remove(id)
                self.failedTooltipIDs.remove(id)
            }
        }
    }

    func iconURL(for item: CatalogEntry) -> URL? {
        if let known = item.iconURL { return known }
        if let cached = itemIconURLs[item.id] { return cached }

        let local = itemIconCacheRoot.appendingPathComponent("\(item.id).jpg")
        if FileManager.default.fileExists(atPath: local.path) {
            itemIconURLs[item.id] = local
            return local
        }

        resolveItemIcon(itemID: item.id)
        return nil
    }

    func resolveIconsForVisibleItems() {
        // Resolve only the visible page and never block catalog rendering.
        // Failed IDs stay on the fallback icon until the user explicitly retries.
        for item in serverCatalog.prefix(catalogPageSize) {
            if item.iconURL == nil,
               itemIconURLs[item.id] == nil,
               !failedIconIDs.contains(item.id) {
                resolveItemIcon(itemID:item.id)
            }
        }
    }

    func retryFailedIcons() {
        failedIconIDs.removeAll()
        iconQueue.cancelAllOperations()
        iconLoadingIDs.removeAll()
        resolveIconsForVisibleItems()
    }

    func cancelPendingIconLoads() {
        iconQueue.cancelAllOperations()
        iconLoadingIDs.removeAll()
    }

    private func resolveItemIcon(itemID: Int) {
        guard itemID > 0 else { return }
        guard itemIconURLs[itemID] == nil else { return }
        guard !iconLoadingIDs.contains(itemID) else { return }
        guard !failedIconIDs.contains(itemID) else { return }

        let local=itemIconCacheRoot.appendingPathComponent("\(itemID).jpg")
        if FileManager.default.fileExists(atPath:local.path) {
            itemIconURLs[itemID]=local
            return
        }

        iconLoadingIDs.insert(itemID)
        let expansion=selectedExpansion
        let cacheRoot=itemIconCacheRoot

        iconQueue.addOperation {
            if OperationQueue.current?.operations.first?.isCancelled == true { return }

            func finishFailure() {
                DispatchQueue.main.async {
                    self.iconLoadingIDs.remove(itemID)
                    self.failedIconIDs.insert(itemID)
                }
            }

            let endpoint: String
            switch expansion {
            case .tbc: endpoint="https://www.wowhead.com/tbc/item=\(itemID)&xml"
            case .wotlk: endpoint="https://www.wowhead.com/wotlk/item=\(itemID)&xml"
            default: endpoint="https://www.wowhead.com/item=\(itemID)&xml"
            }

            guard let xmlURL=URL(string:endpoint) else { finishFailure(); return }

            var req=URLRequest(url:xmlURL)
            req.timeoutInterval=7
            req.cachePolicy = .returnCacheDataElseLoad
            req.setValue("WoWServerControlCenter/1.5",forHTTPHeaderField:"User-Agent")
            req.setValue("application/xml,text/xml;q=0.9,*/*;q=0.8",forHTTPHeaderField:"Accept")

            let sem=DispatchSemaphore(value:0)
            var xmlData:Data?
            var status=0
            URLSession.shared.dataTask(with:req) { data,response,_ in
                xmlData=data
                status=(response as? HTTPURLResponse)?.statusCode ?? 0
                sem.signal()
            }.resume()

            guard sem.wait(timeout:.now()+8) == .success,
                  (200..<300).contains(status),
                  let data=xmlData,
                  let xml=String(data:data,encoding:.utf8),
                  xml.contains("<item") else {
                finishFailure()
                return
            }

            guard let a=xml.range(of:"<icon"),
                  let gt=xml.range(of:">",range:a.lowerBound..<xml.endIndex),
                  let close=xml.range(of:"</icon>",range:gt.upperBound..<xml.endIndex) else {
                finishFailure()
                return
            }

            var iconName=String(xml[gt.upperBound..<close.lowerBound])
                .trimmingCharacters(in:.whitespacesAndNewlines)
                .lowercased()

            iconName=iconName
                .replacingOccurrences(of:"&amp;",with:"&")
                .replacingOccurrences(of:" ",with:"_")

            guard !iconName.isEmpty else { finishFailure(); return }

            let candidates=[
                "https://wow.zamimg.com/images/wow/icons/large/\(iconName).jpg",
                "https://wow.zamimg.com/images/wow/icons/medium/\(iconName).jpg"
            ]

            for imageString in candidates {
                if self.iconQueue.operations.first(where:{$0.isCancelled}) != nil { break }
                guard let imageURL=URL(string:imageString) else { continue }

                var imageReq=URLRequest(url:imageURL)
                imageReq.timeoutInterval=7
                imageReq.cachePolicy = .returnCacheDataElseLoad
                imageReq.setValue("WoWServerControlCenter/1.5",forHTTPHeaderField:"User-Agent")

                let imageSem=DispatchSemaphore(value:0)
                var imageData:Data?
                var imageStatus=0
                URLSession.shared.dataTask(with:imageReq) { data,response,_ in
                    imageData=data
                    imageStatus=(response as? HTTPURLResponse)?.statusCode ?? 0
                    imageSem.signal()
                }.resume()

                guard imageSem.wait(timeout:.now()+8) == .success else { continue }
                guard (200..<300).contains(imageStatus),
                      let bytes=imageData,
                      bytes.count > 500 else { continue }

                do {
                    try FileManager.default.createDirectory(at:cacheRoot,withIntermediateDirectories:true)
                    try bytes.write(to:local,options:.atomic)
                    DispatchQueue.main.async {
                        self.itemIconURLs[itemID]=local
                        self.iconLoadingIDs.remove(itemID)
                        self.failedIconIDs.remove(itemID)
                    }
                    return
                } catch {
                    continue
                }
            }

            finishFailure()
        }
    }

    func retryFailedTooltips() {
        failedTooltipIDs.removeAll()
        tooltipQueue.cancelAllOperations()
        tooltipLoadingIDs.removeAll()
    }


    private var expansionItemEntryClause: String {
        switch selectedExpansion {
        case .vanilla: return "entry BETWEEN 1 AND 24282"
        case .tbc: return "entry BETWEEN 24283 AND 35599"
        case .wotlk: return "entry BETWEEN 35600 AND 56805"
        case .cataclysm: return "entry BETWEEN 56806 AND 79999"
        case .mop: return "entry BETWEEN 80000 AND 109999"
        default: return "1=1"
        }
    }

    private func catalogWhereClause(kind: CatalogKind, search: String) -> String {
        let escaped = search
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        var clauses: [String] = [expansionItemEntryClause]

        switch kind {
        case .raidSet:
            clauses.append("itemset > 0")
            clauses.append("InventoryType > 0")
        case .weapon:
            clauses.append("class = 2")
            clauses.append("InventoryType > 0")
        case .armor:
            clauses.append("class = 4")
            clauses.append("InventoryType > 0")
        case .legendary:
            clauses.append("Quality = 5")
        case .bis:
            // "BiS / Endgame" is the complete high-end candidate pool from the
            // selected expansion DB, not a hand-maintained short list.
            let floor: Int
            switch selectedExpansion {
            case .vanilla: floor = 65
            case .tbc: floor = 105
            case .wotlk: floor = 200
            case .cataclysm: floor = 333
            case .mop: floor = 450
            default: floor = 0
            }
            clauses.append("class IN (2,4)")
            clauses.append("Quality >= 4")
            clauses.append("InventoryType > 0")
            if floor > 0 { clauses.append("ItemLevel >= \(floor)") }
        case .bag:
            clauses.append("class = 1")
        case .mount:
            clauses.append("""
            (
              InventoryType = 0
              AND class <> 2
              AND class <> 4
              AND (
                    (class = 15 AND subclass = 5)
                 OR name LIKE 'Reins of %'
                 OR name LIKE 'Horn of %'
                 OR name LIKE '%Whistle%'
                 OR name LIKE '%Mount%'
                 OR name LIKE '%Warhorse%'
                 OR name LIKE '%Charger%'
                 OR name LIKE '%Steed%'
                 OR name LIKE '%Raptor%'
                 OR name LIKE '%Kodo%'
                 OR name LIKE '%Hawkstrider%'
                 OR name LIKE '%Elekk%'
                 OR name LIKE '%Talbuk%'
                 OR name LIKE '%Nether Ray%'
                 OR name LIKE '%Netherwing%'
                 OR name LIKE '%Drake%'
                 OR name LIKE '%Proto-Drake%'
                 OR name LIKE '%Gryphon%'
                 OR name LIKE '%Wind Rider%'
                 OR name LIKE '%Mechanostrider%'
                 OR name LIKE '%Mammoth%'
                 OR name LIKE '%Frostsaber%'
                 OR name LIKE '%Nightsaber%'
              )
            )
            """)
        case .all:
            break
        }

        let qmin = itemQualityFilter.minimum
        if qmin > 0 {
            if itemQualityFilter == .legendary { clauses.append("Quality = 5") }
            else { clauses.append("Quality >= \(qmin)") }
        }

        let slots = equipSlotFilter.inventoryTypes
        if !slots.isEmpty {
            clauses.append("InventoryType IN (\(slots.map(String.init).joined(separator: ",")))")
        }

        if let classMask=playerClassFilter.mask {
            clauses.append("(AllowableClass = -1 OR AllowableClass = 4294967295 OR (AllowableClass & \(classMask)) <> 0)")
        }

        if let floor = Int(minimumItemLevel.trimmingCharacters(in: .whitespacesAndNewlines)), floor > 0 {
            clauses.append("ItemLevel >= \(floor)")
        }

        if !escaped.isEmpty {
            if let id = Int(escaped), id > 0 {
                clauses.append("entry = \(id)")
            } else {
                clauses.append("name LIKE '%\(escaped)%'")
            }
        }
        return clauses.joined(separator: " AND ")
    }

    func loadCatalogPage(reset: Bool = false, pageDelta: Int = 0) {
        guard !catalogLoading else { return }

        if !portOpen(Int32(mysqlPort)) {
            catalogLoading = true
            catalogStatus = "Starting \(selectedExpansion.shortTitle) database for collections…"
            Task {
                do {
                    try await startMySQL()
                    try configureDatabaseAccess()
                    mysqlRunning = true
                    catalogLoading = false
                    loadCatalogPage(reset: reset, pageDelta: pageDelta)
                } catch {
                    catalogLoading = false
                    serverCatalog = BuiltInCatalog.entries(for: selectedExpansion)
                    catalogHasMore = false
                    catalogStatus = "Realm DB unavailable — showing same-expansion examples only. \(error.localizedDescription)"
                    statusMessage = catalogStatus
                }
            }
            return
        }

        if reset { catalogPage = 0 }
        else { catalogPage = max(0, catalogPage + pageDelta) }

        let page = catalogPage
        let pageSize = catalogPageSize
        let kind = catalogKind
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let db = worldDatabaseName
        guard let mysqlExecutable = locateMySQL("mysql") else {
            statusMessage = "MySQL client not found"
            return
        }
        let port = mysqlPort
        let whereClause = catalogWhereClause(kind: kind, search: q)
        let offset = page * pageSize
        let countSQL = "SELECT COUNT(*) FROM item_template WHERE \(whereClause);"
        let sql = """
        SELECT entry,name,Quality,class,subclass,InventoryType,ItemLevel,itemset,AllowableClass
        FROM item_template
        WHERE \(whereClause)
        ORDER BY ItemLevel DESC, Quality DESC, name, entry
        LIMIT \(pageSize) OFFSET \(offset);
        """

        catalogLoading = true
        catalogStatus = "Loading \(kind.rawValue) — page \(page + 1)…"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let client = DatabaseClient(executable: mysqlExecutable, port: port)
                let totalRaw = try client.query(database: db, sql: countSQL)
                let total = Int(totalRaw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                let raw = try client.query(database: db, sql: sql)
                let parsed: [CatalogEntry] = raw.split(separator:"\n").compactMap { line in
                    let f=line.split(separator:"\t",omittingEmptySubsequences:false)
                    guard f.count >= 9, let id=Int(f[0]) else { return nil }
                    let quality=Int(f[2]) ?? 1
                    let cls=Int(f[3]) ?? 0
                    let sub=Int(f[4]) ?? 0
                    let inv=Int(f[5]) ?? 0
                    let ilvl=Int(f[6]) ?? 0
                    let setID=Int(f[7]) ?? 0
                    let allowableClass=Int(f[8]) ?? -1
                    let actualKind: CatalogKind
                    if kind == .raidSet { actualKind = .raidSet }
                    else if kind == .bis { actualKind = .bis }
                    else if kind == .mount { actualKind = .mount }
                    else if kind == .all { actualKind = CatalogFormatting.kind(itemClass:cls,inventoryType:inv,quality:quality) }
                    else { actualKind = kind }
                    let subtitleBase = CatalogFormatting.subtitle(itemClass:cls,subclass:sub,inventoryType:inv)
                    let subtitle = "\(subtitleBase) • iLvl \(ilvl)"
                    return CatalogEntry(
                        id:id,
                        name:String(f[1]),
                        kind:actualKind,
                        quality:CatalogFormatting.qualityName(quality),
                        subtitle:subtitle,
                        iconURL:BuiltInCatalog.iconForKnownItem(id),
                        spellID:nil,
                        itemLevel:ilvl,
                        itemSetID:setID == 0 ? nil : setID,
                        allowableClass:allowableClass
                    )
                }
                let hasMore = offset + parsed.count < total

                DispatchQueue.main.async {
                    self.serverCatalog = parsed
                    self.catalogHasMore = hasMore
                    self.mysqlRunning = true
                    self.catalogLoading = false
                    self.resolveIconsForVisibleItems()
                    let first = parsed.isEmpty ? 0 : offset + 1
                    let last = offset + parsed.count
                    self.catalogStatus = parsed.isEmpty
                        ? "No \(kind.rawValue) found in \(self.selectedExpansion.title)"
                        : "\(kind.rawValue): showing \(first)–\(last) of \(total) from \(self.selectedExpansion.title) realm DB"
                    self.statusMessage = self.catalogStatus
                }
            } catch {
                DispatchQueue.main.async {
                    self.catalogLoading = false
                    self.serverCatalog = BuiltInCatalog.entries(for: self.selectedExpansion)
                    self.catalogHasMore = false
                    self.catalogStatus = "Could not read selected realm DB — showing same-expansion examples only. \(error.localizedDescription)"
                    self.statusMessage = self.catalogStatus
                }
            }
        }
    }

    func loadMountCollection(resetFilters: Bool = false) {
        catalogKind = .mount

        // Mounts hides class/slot/min-iLvl controls, so those filters must
        // never silently carry over from another collection or expansion.
        equipSlotFilter = .all
        playerClassFilter = .all
        minimumItemLevel = ""

        if resetFilters {
            searchText = ""
            itemQualityFilter = .all
        }

        loadCatalogPage(reset:true)
    }

    private func resetCollectionStateForExpansionChange() {
        cancelPendingIconLoads()
        tooltipQueue.cancelAllOperations()
        tooltipLoadingIDs.removeAll()

        searchText = ""
        itemQualityFilter = .all
        equipSlotFilter = .all
        playerClassFilter = .all
        gearSetClassFilter = .all
        minimumItemLevel = ""
        catalogKind = .all
        catalogPage = 0
        catalogHasMore = false
        serverCatalog = []
        gearSets = []
        selectedGearSet = nil
        catalogStatus = "Choose a collection and click Load"
        gearSetStatus = "Load / Refresh Gear Sets"
    }

    func resetCollectionFilters() {
        searchText = ""
        itemQualityFilter = .all
        equipSlotFilter = .all
        playerClassFilter = .all
        minimumItemLevel = ""
        catalogPage = 0
        catalogHasMore = false
        serverCatalog = []
        catalogStatus = "Filters reset"
    }

    func catalogSelectionChanged() {
        cancelPendingIconLoads()
        tooltipQueue.cancelAllOperations()
        tooltipLoadingIDs.removeAll()
        catalogPage = 0
        catalogHasMore = false
        serverCatalog = []

        searchText = ""
        itemQualityFilter = .all
        equipSlotFilter = .all
        playerClassFilter = .all
        minimumItemLevel = ""

        loadCatalogPage(reset: true)
    }

    func searchServerCatalog() { loadCatalogPage(reset: true) }
    func loadAllCurrentCategory() { loadCatalogPage(reset: true) }
    func nextCatalogPage() { guard catalogHasMore else { return }; loadCatalogPage(pageDelta: 1) }
    func previousCatalogPage() { guard catalogPage > 0 else { return }; loadCatalogPage(pageDelta: -1) }

    func clearServerCatalog() {
        cancelPendingIconLoads()
        tooltipQueue.cancelAllOperations()
        tooltipLoadingIDs.removeAll()
        serverCatalog = []
        catalogPage = 0
        catalogHasMore = false
        catalogStatus = "Choose a collection and click Load"
    }



    var filteredGearSets: [GearSetSummary] {
        gearSets.filter { set in
            let categoryOK = gearSetCategory == .all || set.category == gearSetCategory
            let classOK: Bool
            if let mask=gearSetClassFilter.mask {
                classOK=set.items.contains { item in
                    item.allowableClass == -1 || item.allowableClass == 4294967295 || (item.allowableClass & mask) != 0
                }
            } else {
                classOK=true
            }
            return categoryOK && classOK
        }
    }

    func loadGearSets() {
        // Query MySQL directly instead of trusting the cached mysqlRunning
        // presentation flag.
        guard !gearSetsLoading else { return }
        guard let mysqlExecutable = locateMySQL("mysql") else {
            gearSetStatus = "MySQL client not found"
            statusMessage = gearSetStatus
            return
        }

        let db = worldDatabaseName
        let port = mysqlPort
        let expansion = selectedExpansion
        let expansionClause = expansionItemEntryClause

        gearSetsLoading = true
        gearSetStatus = "Loading realm item sets…"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let client = DatabaseClient(executable: mysqlExecutable, port: port)

                // Gear Sets deliberately loads ONLY actual DB-defined item sets.
                // BiS/endgame candidates are browsed separately through the paged
                // Items & Gear catalog so opening Gear Sets never scans the whole
                // high-end item_template table.
                let sql = """
                SELECT entry,name,Quality,class,subclass,InventoryType,ItemLevel,itemset,AllowableClass
                FROM item_template
                WHERE itemset > 0 AND \(expansionClause)
                ORDER BY itemset,InventoryType,ItemLevel DESC,entry;
                """

                let raw = try client.query(database: db, sql: sql)

                var grouped: [Int:[CatalogEntry]] = [:]
                for line in raw.split(separator:"\n") {
                    let f = line.split(separator:"\t", omittingEmptySubsequences:false)
                    guard f.count >= 9,
                          let id = Int(f[0]),
                          let setID = Int(f[7]),
                          setID > 0 else { continue }

                    let quality = Int(f[2]) ?? 1
                    let cls = Int(f[3]) ?? 0
                    let sub = Int(f[4]) ?? 0
                    let inv = Int(f[5]) ?? 0
                    let ilvl = Int(f[6]) ?? 0
                    let allowableClass = Int(f[8]) ?? -1

                    let entry = CatalogEntry(
                        id:id,
                        name:String(f[1]),
                        kind:CatalogFormatting.kind(itemClass:cls, inventoryType:inv, quality:quality),
                        quality:CatalogFormatting.qualityName(quality),
                        subtitle:CatalogFormatting.subtitle(itemClass:cls, subclass:sub, inventoryType:inv),
                        iconURL:BuiltInCatalog.iconForKnownItem(id),
                        spellID:nil,
                        itemLevel:ilvl,
                        itemSetID:setID,
                        allowableClass:allowableClass
                    )
                    grouped[setID, default:[]].append(entry)
                }

                var result: [GearSetSummary] = grouped.compactMap { setID, items in
                    guard !items.isEmpty else { return nil }
                    let maxLevel = items.map { $0.itemLevel ?? 0 }.max() ?? 0
                    let name = Self.deriveSetNameStatic(items: items, setID: setID)
                    let category = Self.classifySetStatic(expansion: expansion, name: name, items: items)
                    return GearSetSummary(
                        id:setID,
                        name:name,
                        category:category,
                        itemLevel:maxLevel,
                        items:items.sorted { Self.slotRankStatic($0.subtitle) < Self.slotRankStatic($1.subtitle) }
                    )
                }

                result.sort { lhs, rhs in
                    if lhs.itemLevel != rhs.itemLevel { return lhs.itemLevel > rhs.itemLevel }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                DispatchQueue.main.async {
                    self.gearSets = result
                    self.selectedGearSet = self.filteredGearSets.first
                    self.mysqlRunning = true
                    self.gearSetsLoading = false
                    self.gearSetStatus = "Loaded \(result.count) complete realm item sets"
                    self.statusMessage = self.gearSetStatus
                }
            } catch {
                DispatchQueue.main.async {
                    self.gearSetsLoading = false
                    self.gearSetStatus = "Set database error: \(error.localizedDescription)"
                    self.statusMessage = self.gearSetStatus
                }
            }
        }
    }


    func giveGearSet(_ set: GearSetSummary) {
        guard let c = selectedCharacter else {
            statusMessage = "Select a character first"
            return
        }
        guard worldRunning || world?.isRunning == true else {
            statusMessage = "Start World Server first"
            return
        }
        guard !set.items.isEmpty else {
            statusMessage = "This gear set contains no items."
            return
        }

        switch selectedExpansion.serverFamily {
        case .azerothCore:
            for (idx,item) in set.items.enumerated() {
                DispatchQueue.main.asyncAfter(deadline:.now()+Double(idx)*0.08) {
                    self.sendAdminCommand(
                        "additem \(c.name) \(item.id) 1",
                        success: "Giving \(set.name) to \(c.name)…"
                    )
                }
            }
            DispatchQueue.main.asyncAfter(deadline:.now()+Double(set.items.count)*0.08+0.15) {
                self.statusMessage = "Full set sent: \(set.name) → \(c.name)"
            }

        case .cmangos:
            // CMaNGOS server console cannot use `.additem` on a GUI-selected
            // character. `send items` accepts an explicit player name and up to
            // 12 mailed item stacks. Chunk larger/custom sets defensively.
            let chunks = stride(from: 0, to: set.items.count, by: 12).map {
                Array(set.items[$0..<min($0 + 12, set.items.count)])
            }
            let safeName = set.name.replacingOccurrences(of: "\"", with: "'")

            for (index, chunk) in chunks.enumerated() {
                let itemArgs = chunk.map { "\($0.id):1" }.joined(separator: " ")
                let part = chunks.count > 1 ? " \(index + 1)/\(chunks.count)" : ""
                let command = "send items \(c.name) \"WoWCC Gear Set\(part)\" \"\(safeName)\" \(itemArgs)"
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.35) {
                    self.sendAdminCommand(
                        command,
                        success: "Sending \(set.name) to \(c.name)…"
                    )
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(chunks.count) * 0.35 + 0.2) {
                self.statusMessage = "Full TBC set mailed: \(set.name) → \(c.name)"
            }

        case .custom:
            statusMessage = "Full-set Give is not configured for this custom core."
        }
    }

    func loadMountItems() {
        catalogKind = .mount
        searchText = ""
        loadCatalogPage(reset: true)
    }


    nonisolated private static func classifySetStatic(expansion: ExpansionID, name: String, items: [CatalogEntry]) -> GearSetCategory {
        let n=name.lowercased()
        let pvpWords=[
            "gladiator","merciless","vengeful","brutal","furious","relentless","wrathful",
            "warlord","marshal","champion","lieutenant commander","commander","blood guard",
            "knight-captain","knight-lieutenant","field marshal","grand marshal","high warlord",
            "arena","honor"
        ]
        if pvpWords.contains(where:n.contains) { return .pvp }
        return .raid
    }

    nonisolated private static func deriveSetNameStatic(items: [CatalogEntry], setID: Int) -> String {
        guard !items.isEmpty else { return "Item Set #\(setID)" }
        let slotWords:Set<String>=["helm","helmet","headguard","headpiece","crown","hood","shoulders","shoulderguards","pauldrons","spaulders","chestguard","chestpiece","breastplate","robe","robes","tunic","vest","handguards","gloves","gauntlets","grips","leggings","legguards","legplates","pants","kilt","boots","sabatons","greaves","footguards"]
        let tokenLists=items.map { $0.name.split(separator:" ").map(String.init) }
        var counts:[String:Int]=[:]
        for tokens in tokenLists { for t in Set(tokens) where !slotWords.contains(t.lowercased()) { counts[t,default:0]+=1 } }
        let threshold=max(2, Int(Double(items.count)*0.55))
        let common=tokenLists[0].filter { (counts[$0] ?? 0) >= threshold && !slotWords.contains($0.lowercased()) }
        let name=common.joined(separator:" ").trimmingCharacters(in:.whitespaces)
        return name.isEmpty ? "Item Set #\(setID)" : name
    }

    nonisolated private static func slotRankStatic(_ subtitle:String)->Int {
        let order=["Head","Neck","Shoulders","Back","Chest","Wrists","Hands","Waist","Legs","Feet","Finger","Trinket","Main Hand","Off Hand","One-Hand","Two-Hand","Ranged"]
        return order.firstIndex(where:{subtitle.contains($0)}) ?? 99
    }




    func removeInventoryItem(_ item: InventoryEntry) {
        guard let c = selectedCharacter else { return }
        guard selectedExpansion.serverFamily == .azerothCore else { statusMessage = "Remove adapter is turnkey for WotLK/AzerothCore."; return }
        sendAdminCommand("additem \(c.name) \(item.itemEntry) -1", success: "Removed one \(item.name) from \(c.name)")
        DispatchQueue.main.asyncAfter(deadline:.now()+0.5) { self.loadInventory() }
    }

    func loadAccounts() {
        guard mysqlRunning else { return }
        do {
            let client = try dbClient(); let db = authDatabaseName
            let sql = selectedExpansion.serverFamily == .azerothCore ? "SELECT id,username,0 FROM account ORDER BY id DESC LIMIT 200;" : "SELECT id,username,gmlevel FROM account ORDER BY id DESC LIMIT 200;"
            let text = try client.query(database: db, sql: sql)
            accounts = text.split(separator: "\n").compactMap { line in let f=line.split(separator:"\t", omittingEmptySubsequences:false); guard f.count >= 3 else { return nil }; return AccountSummary(id:Int(f[0]) ?? 0, username:String(f[1]), gmLevel:Int(f[2]) ?? 0) }
            normalizeCharacterCreatorSelection()
} catch { statusMessage = "Account DB: \(error.localizedDescription)" }
    }

    func createAccount() {
        let username = newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = newAccountPassword

        guard !username.isEmpty, !password.isEmpty else {
            statusMessage = "Enter account name and password"
            return
        }

        // Console account commands are token based. Reject whitespace/control
        // characters so a GUI field can never accidentally become multiple
        // server-console commands.
        let usernameAllowed = username.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).contains($0)
        }
        guard usernameAllowed else {
            statusMessage = "Account name may contain only letters, numbers, _ and -."
            return
        }
        guard !password.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            statusMessage = "Password cannot contain spaces or line breaks when using the server console adapter."
            return
        }

        guard worldRunning || world?.isRunning == true else {
            statusMessage = "Start the World Server first. Account creation uses the selected core's live server console."
            return
        }

        switch selectedExpansion.serverFamily {
        case .azerothCore:
            // AzerothCore accepts a realm selector for gmlevel.
            sendAdminCommand("account create \(username) \(password)", success: "Created account \(username)")
            if gmLevel > 0 {
                let level = gmLevel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    self.sendAdminCommand(
                        "account set gmlevel \(username) \(level) -1",
                        success: "Created GM account \(username)"
                    )
                    self.loadAccounts()
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.loadAccounts() }
            }

        case .cmangos:
            // CMaNGOS uses the same create command, but gmlevel has NO realm-id
            // argument. TBC accounts must additionally receive addon level 1 or
            // they remain Classic-only.
            sendAdminCommand("account create \(username) \(password)", success: "Created CMaNGOS account \(username)")

            var delay = 0.45
            if selectedExpansion == .tbc {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.sendAdminCommand(
                        "account set addon \(username) 1",
                        success: "Enabled TBC access for \(username)"
                    )
                }
                delay += 0.45
            }

            if gmLevel > 0 {
                let level = gmLevel
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.sendAdminCommand(
                        "account set gmlevel \(username) \(level)",
                        success: "Created CMaNGOS GM account \(username)"
                    )
                }
                delay += 0.45
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.loadAccounts()
            }

        case .custom:
            statusMessage = "Account creation is not configured for this experimental/custom core."
            return
        }

        newAccountPassword = ""
    }

    func sendAdminCommand(_ command: String, success: String) {
        do { try world.send(command); statusMessage = success } catch { statusMessage = "Admin command unavailable: \(error.localizedDescription)" }
    }

    var healthPassCount: Int { healthChecks.filter { $0.state == .pass }.count }
    var healthWarningCount: Int { healthChecks.filter { $0.state == .warning }.count }
    var healthFailCount: Int { healthChecks.filter { $0.state == .fail }.count }
    var launchReady: Bool { !healthChecks.isEmpty && healthFailCount == 0 }

    func runAllChecks() {
        healthCheckRunning = true
        operationActive = true
        operationName = "Running full health check"
        statusMessage = "Checking dependencies, runtime, client, database and realm…"

        Task { @MainActor in
            var results: [HealthCheckResult] = []
            let fm = FileManager.default
            func add(_ id:String,_ category:String,_ title:String,_ detail:String,_ state:HealthCheckState,_ fix:HealthFixAction = .none) {
                results.append(HealthCheckResult(id:id,category:category,title:title,detail:detail,state:state,fix:fix))
            }

            // Host / build runtime
            let arch = machineArchitecture()
            add("host.arch","Host","Mac architecture",arch,.pass)
            add("host.write","Host","Application data folder writable",fm.isWritableFile(atPath:dataRoot.path) ? dataRoot.path : "Cannot write to \(dataRoot.path)",fm.isWritableFile(atPath:dataRoot.path) ? .pass : .fail)
            let freeBytes = (try? dataRoot.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
            let freeGB = Double(freeBytes) / 1_073_741_824.0
            add("host.disk","Host","Free disk space",String(format:"%.1f GB available",freeGB),freeGB >= 20 ? .pass : (freeGB >= 8 ? .warning : .fail))

            // Dependencies
            let mysqlServer = locateMySQL("mysqld")
            let mysqlClient = locateMySQL("mysql")
            add("dep.mysqld","Dependencies","MySQL 8.4 server",mysqlServer ?? "mysqld not found",mysqlServer == nil ? .fail : .pass,.installDependencies)
            add("dep.mysql","Dependencies","MySQL client",mysqlClient ?? "mysql client not found",mysqlClient == nil ? .fail : .pass,.installDependencies)
            for tool in ["git","cmake","make"] {
                let found = locateCommand(tool)
                add("dep.\(tool)","Dependencies",tool.uppercased(),found ?? "\(tool) not found",found == nil ? .fail : .pass,.installDependencies)
            }
            if selectedExpansion == .cataclysm || selectedExpansion == .mop {
                let sevenZip = locateCommand("7z")
                add("dep.7z","Dependencies","7-Zip",sevenZip ?? "7z not found (needed when the community DB release is a .7z archive)",sevenZip == nil ? .fail : .pass,.installDependencies)
            }

            // Core
            add("core.world","Core","World server binary",worldBinary.path,profileInstalled ? .pass : .fail,.installCore)
            add("core.auth","Core","Auth server binary",authBinary.path,fm.isExecutableFile(atPath:authBinary.path) ? .pass : .fail,.installCore)
            if selectedExpansion.serverFamily == .azerothCore {
                let dbimport = profileRoot.appendingPathComponent("bin/dbimport")
                add("core.dbimport","Core","AzerothCore DB importer",dbimport.path,fm.isExecutableFile(atPath:dbimport.path) ? .pass : .fail,.installCore)
            }
            let authConf = profileRoot.appendingPathComponent("configs/\(authConfName)")
            let worldConf = profileRoot.appendingPathComponent("configs/\(worldConfName)")
            add("core.authconf","Core","Auth configuration",authConf.path,fm.fileExists(atPath:authConf.path) ? .pass : .fail,.setupRealm)
            add("core.worldconf","Core","World configuration",worldConf.path,fm.fileExists(atPath:worldConf.path) ? .pass : .fail,.setupRealm)

            // Client
            add("client.path","Client","Compatible client linked",clientConfigured ? clientPath : selectedExpansion.clientHint,clientConfigured ? .pass : .fail,.selectClient)
            if clientConfigured {
                let clientURL = URL(fileURLWithPath:clientPath)
                add("client.exists","Client","Client path exists",clientPath,fm.fileExists(atPath:clientURL.path) ? .pass : .fail,.selectClient)
            }

            // Required extracted client data. Custom profiles vary, so warn rather than hard-fail.
            let dataDirs: [String]
            switch selectedExpansion {
            case .wotlk: dataDirs = ["dbc","maps","vmaps","mmaps"]
            case .vanilla, .tbc: dataDirs = ["dbc","maps","vmaps"]
            case .cataclysm, .mop: dataDirs = ["dbc","maps","vmaps"]
            default: dataDirs = []
            }
            if dataDirs.isEmpty {
                add("data.custom","Client Data","Extracted game data","Custom profile: verify data requirements for the imported core",.warning,.prepareClient)
            } else {
                for dir in dataDirs {
                    let minimum: Int
                    if selectedExpansion == .wotlk {
                        minimum = ["dbc":100, "maps":100, "vmaps":10, "mmaps":10][dir] ?? 1
                    } else {
                        minimum = 1
                    }
                    let ok = dataDirectoryHasFiles(dir, minimum: minimum)
                    add("data.\(dir)","Client Data",dir.uppercased(),ok ? "Ready" : "Missing or incomplete \(dir) data",ok ? .pass : .fail,.prepareClient)
                }
            }

            // Database runtime
            let mysqlListening = portOpen(Int32(mysqlPort))
            add("db.port","Database","Managed MySQL port \(mysqlPort)",mysqlListening ? "Listening on 127.0.0.1:\(mysqlPort)" : "Not listening",mysqlListening ? .pass : .fail,.startDatabase)
            let dbData = profileDBRoot.appendingPathComponent("data")
            add("db.datadir","Database","Per-era database data",dbData.path,fm.fileExists(atPath:dbData.path) ? .pass : .warning,.setupRealm)
            add("db.write","Database","Database folder writable",profileDBRoot.path,fm.isWritableFile(atPath:profileDBRoot.path) ? .pass : .fail)

            if mysqlListening, mysqlClient != nil {
                do {
                    let dbc = try dbClient()
                    let dbNames: [String]
                    switch selectedExpansion {
                    case .wotlk: dbNames = ["acore_auth","acore_characters","acore_world"]
                    case .vanilla, .tbc: dbNames = ["realmd","characters","mangos"]
                    case .cataclysm, .mop: dbNames = ["auth","characters","world"]
                    default: dbNames = []
                    }
                    if dbNames.isEmpty {
                        add("db.schemas","Database","Realm schemas","Custom profile schemas are core-specific",.warning,.setupRealm)
                    } else {
                        let existing = try dbc.query(database:"mysql",sql:"SHOW DATABASES;")
                        for name in dbNames {
                            let ok = existing.split(separator:"\n").contains { String($0) == name }
                            add("db.schema.\(name)","Database","Schema: \(name)",ok ? "Exists" : "Missing",ok ? .pass : .fail,.setupRealm)
                        }
                        let required: [(String,String)]
                        switch selectedExpansion {
                        case .wotlk:
                            required = [("acore_auth","account"),("acore_auth","realmlist"),("acore_characters","characters"),("acore_characters","item_instance"),("acore_characters","character_inventory"),("acore_world","item_template"),("acore_world","creature_template")]
                        case .vanilla, .tbc:
                            required = [("realmd","account"),("realmd","realmlist"),("characters","characters"),("mangos","item_template"),("mangos","creature_template")]
                        case .cataclysm, .mop:
                            required = [("auth","account"),("auth","realmlist"),("characters","characters"),("world","item_template"),("world","creature_template")]
                        default:
                            required = []
                        }
                        var allTables = !required.isEmpty
                        for (db, table) in required {
                            let q = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\(db)' AND table_name='\(table)';"
                            let value = try dbc.query(database:"mysql",sql:q).trimmingCharacters(in:.whitespacesAndNewlines)
                            let ok = value == "1"
                            allTables = allTables && ok
                            add("db.table.\(db).\(table)","Database","Table: \(db).\(table)",ok ? "Ready" : "Missing",ok ? .pass : .fail,.setupRealm)
                        }
                        if !required.isEmpty {
                            add("db.realmready","Database","Realm database readiness",allTables ? "All required tables verified" : "Database exists but required tables are incomplete",allTables ? .pass : .fail,.setupRealm)
                        }
                    }
                } catch {
                    add("db.query","Database","Database connectivity",error.localizedDescription,.fail,.startDatabase)
                }
            }

            if selectedExpansion == .cataclysm {
                add("compat.cata","Core","Cataclysm target","TrinityCore 4.3.4 / client build 15595",.pass)
            }
            if selectedExpansion == .mop {
                #if arch(arm64)
                add("compat.mop.arm","Core","MoP Apple Silicon compatibility","SkyFire 5.4.8 is community-maintained and its current documented tested platforms focus on x86_64 Linux/Windows. Control Center will attempt a native macOS build; if it fails, installer.log will contain the exact toolchain error.",.warning)
                #else
                add("compat.mop.arch","Core","MoP architecture","x86_64 host detected",.pass)
                #endif
            }

            // Services / ports
            add("svc.auth","Services","Auth service",authRunning ? "Process running" : "Stopped",authRunning ? .pass : .warning,.startRealm)
            add("svc.world","Services","World service",worldRunning ? "Process running" : "Stopped",worldRunning ? .pass : .warning,.startRealm)
            add("port.auth","Network","Realm/Auth port 3724",portOpen(authPort) ? "Listening" : "Closed until realm starts",portOpen(authPort) ? .pass : .warning,.startRealm)
            add("port.world","Network","World port 8085",portOpen(worldPort) ? "Listening" : "Closed until realm starts",portOpen(worldPort) ? .pass : .warning,.startRealm)

            // Logs / backups / admin
            let backupRoot = dataRoot.appendingPathComponent("runtime/backups")
            add("ops.logs","Operations","Log folder writable",logs.path,fm.isWritableFile(atPath:logs.path) ? .pass : .fail)
            add("ops.backups","Operations","Backup folder writable",backupRoot.path,fm.isWritableFile(atPath:backupRoot.path) ? .pass : .fail,.createBackupFolder)
            if mysqlListening {
                do {
                    _ = try dbClient()
                    add("admin.db","Admin Center","Admin database adapter","Connected",.pass)
                } catch { add("admin.db","Admin Center","Admin database adapter",error.localizedDescription,.fail,.startDatabase) }
            } else {
                add("admin.db","Admin Center","Admin database adapter","Database is offline",.warning,.startDatabase)
            }
            if selectedExpansion.serverFamily == .azerothCore {
                add("admin.console","Admin Center","Live GM command adapter",worldRunning ? "Ready" : "Starts with worldserver",worldRunning ? .pass : .warning,.startRealm)
            } else {
                add("admin.console","Admin Center","Live GM command adapter","Some admin actions depend on the selected core family",.warning)
            }

            self.healthChecks = results
            self.lastHealthCheck = Date()
            self.healthCheckRunning = false
            self.operationActive = false
            self.operationName = self.healthFailCount == 0 ? "Checks passed" : "Checks found issues"
            self.statusMessage = self.healthFailCount == 0 ? "Health check complete — launch ready" : "Health check complete — \(self.healthFailCount) issue(s) need attention"
        }
    }

    func fixHealthCheck(_ check: HealthCheckResult) {
        switch check.fix {
        case .none: statusMessage = "No automatic fix is available for this check"
        case .installDependencies: bootstrapMac()
        case .installCore: installSelectedProfile()
        case .selectClient: chooseClient()
        case .prepareClient: prepareClient()
        case .setupRealm: setupSelectedProfile()
        case .startDatabase:
            Task { do { try await startMySQL(); try configureDatabaseAccess(); statusMessage = "Database started"; refresh(); runAllChecks() } catch { statusMessage = "Database start failed: \(error.localizedDescription)" } }
        case .startRealm: startAll()
        case .createBackupFolder:
            do { try FileManager.default.createDirectory(at:dataRoot.appendingPathComponent("runtime/backups"),withIntermediateDirectories:true); statusMessage="Backup folder ready"; runAllChecks() }
            catch { statusMessage="Could not create backup folder: \(error.localizedDescription)" }
        }
    }

    private func machineArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let bytes = mirror.children.compactMap { $0.value as? Int8 }.prefix { $0 != 0 }.map { UInt8(bitPattern:$0) }
        return String(bytes:bytes,encoding:.utf8) ?? "macOS"
    }

    private func locateCommand(_ tool: String) -> String? {
        ["/opt/homebrew/bin/\(tool)","/usr/local/bin/\(tool)","/usr/bin/\(tool)","/bin/\(tool)"].first { FileManager.default.isExecutableFile(atPath:$0) }
    }

    func runBackup() { runScript("backup.sh", args: [selectedExpansion.rawValue, "\(mysqlPort)"]) }
    func prepareClient() { guard clientConfigured else { statusMessage = "Select client first"; return }; runScript("prepare-client.sh", args: [selectedExpansion.rawValue, clientPath]) }
    func installTBCExtractorEngine() {
        guard selectedExpansion == .tbc || selectedExpansion == .vanilla else {
            statusMessage = "Local CMaNGOS extractor engine is only needed for TBC/Vanilla."
            return
        }
        runScript("setup-tbc-extractor-engine.sh", args: [])
    }



    func importExtractedTBCData() {
        guard selectedExpansion == .tbc else {
            statusMessage = "Extracted TBC data import is available only for the TBC profile."
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Import TBC Data"
        panel.message = "Choose the folder that contains extracted dbc, maps and vmaps folders."

        guard panel.runModal() == .OK, let source = panel.url else { return }

        let fm = FileManager.default
        let required = ["dbc", "maps", "vmaps"]
        let missing = required.filter {
            !fm.fileExists(atPath: source.appendingPathComponent($0, isDirectory: true).path)
        }
        guard missing.isEmpty else {
            statusMessage = "Selected folder is missing: \(missing.joined(separator: ", ")). Choose the parent folder containing dbc, maps and vmaps."
            return
        }

        let sourcePath = source.path
        let destinationPath = profileRoot.appendingPathComponent("data", isDirectory: true).path
        let expansionAtStart = selectedExpansion

        operationActive = true
        operationName = "Importing extracted TBC data"
        statusMessage = "Importing dbc/maps/vmaps…"

        DispatchQueue.global(qos: .userInitiated).async {
            let workerFM = FileManager.default
            do {
                try workerFM.createDirectory(
                    at: URL(fileURLWithPath: destinationPath, isDirectory: true),
                    withIntermediateDirectories: true
                )

                for name in ["dbc", "maps", "vmaps", "mmaps"] {
                    let src = URL(fileURLWithPath: sourcePath, isDirectory: true)
                        .appendingPathComponent(name, isDirectory: true)
                    guard workerFM.fileExists(atPath: src.path) else { continue }

                    let dst = URL(fileURLWithPath: destinationPath, isDirectory: true)
                        .appendingPathComponent(name, isDirectory: true)
                    if workerFM.fileExists(atPath: dst.path) {
                        try workerFM.removeItem(at: dst)
                    }
                    try workerFM.copyItem(at: src, to: dst)
                }

                var invalid: [String] = []
                for name in required {
                    let dir = URL(fileURLWithPath: destinationPath, isDirectory: true)
                        .appendingPathComponent(name, isDirectory: true)
                    let enumerator = workerFM.enumerator(
                        at: dir,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    )
                    var hasFile = false
                    while let item = enumerator?.nextObject() as? URL {
                        if (try? item.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                            hasFile = true
                            break
                        }
                    }
                    if !hasFile { invalid.append(name) }
                }

                DispatchQueue.main.async {
                    guard self.selectedExpansion == expansionAtStart else {
                        self.operationActive = false
                        self.operationName = "Idle"
                        return
                    }
                    self.operationActive = false
                    self.operationName = "Idle"
                    if invalid.isEmpty {
                        self.statusMessage = "TBC client/server data READY — imported dbc, maps and vmaps."
                    } else {
                        self.statusMessage = "TBC data import incomplete. Empty/missing after copy: \(invalid.joined(separator: ", "))."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.operationActive = false
                    self.operationName = "Idle"
                    self.statusMessage = "TBC data import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func runScript(_ name: String, args: [String]) {
        let script = assetsRoot.appendingPathComponent("Scripts/\(name)")
        guard FileManager.default.fileExists(atPath: script.path) else { statusMessage = "Missing script: \(name)"; operationActive = false; operationName = "Failed"; return }

        operationActive = true
        operationName = operationTitle(for: name)
        statusMessage = "Starting \(operationName)…"

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script.path] + args
        p.currentDirectoryURL = dataRoot
        var env = ProcessInfo.processInfo.environment
        env["WOWCC_DATA_ROOT"] = dataRoot.path
        env["WOWCC_ASSETS_ROOT"] = assetsRoot.path
        env["WOWCC_MYSQL_PORT"] = "\(mysqlPort)"
        // GUI apps do not inherit the interactive shell PATH on macOS.
        env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
        p.environment = env

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        let installLog = dataRoot.appendingPathComponent("runtime/installer.log")
        try? FileManager.default.createDirectory(at: installLog.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: installLog.path, contents: nil)
        let logHandle = try? FileHandle(forWritingTo: installLog)

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            try? logHandle?.write(contentsOf: data)
            if let chunk = String(data: data, encoding: .utf8) {
                let lastLine = chunk.split(separator: "\n").last.map(String.init) ?? chunk
                Task { @MainActor in
                    let line = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.statusMessage = line.isEmpty ? "Running: \(name)" : line
                }
            }
        }

        p.terminationHandler = { proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            try? logHandle?.close()
            let tail: String = {
                guard let data = try? Data(contentsOf: installLog), let text = String(data: data, encoding: .utf8) else { return "" }
                return String(text.suffix(12000)).trimmingCharacters(in: .whitespacesAndNewlines)
            }()
            Task { @MainActor in
                self.operationActive = false
                if proc.terminationStatus == 0 {
                    self.operationName = "Completed"
                    if name == "setup-profile.sh" {
                        self.realmDatabaseReady = self.probeRealmDatabaseReady()
                        self.statusMessage = self.realmDatabaseReady ? "Realm database ready: required tables verified" : "Setup finished, but realm database verification failed"
                    } else {
                        self.statusMessage = "Completed: \(self.operationTitle(for: name))"
                    }
                } else {
                    self.operationName = "Failed"
                    if let begin = tail.range(of: "BUILD_DIAGNOSTIC_BEGIN"),
                       let end = tail.range(of: "BUILD_DIAGNOSTIC_END", range: begin.upperBound..<tail.endIndex) {
                        let diagnostic = tail[begin.upperBound..<end.lowerBound]
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        self.statusMessage = diagnostic.isEmpty
                            ? "Core build failed — open installer log"
                            : "Core build failed: \(String(diagnostic.suffix(1100)))"
                    } else {
                        let useful = tail
                            .split(separator: "\n")
                            .map(String.init)
                            .filter { line in
                                let l = line.lowercased()
                                return l.contains("error:") || l.contains("fatal error") || l.contains("undefined symbols") || l.contains("cmake error") || l.contains("the argument (") || l.contains("invalid value") || l.contains("unknown option") || l.contains("failed open file") || l.contains("config::loadfile")
                            }
                            .suffix(6)
                            .joined(separator: " | ")
                        self.statusMessage = !useful.isEmpty
                            ? "Failed: \(useful)"
                            : (tail.isEmpty ? "Failed: \(name) (exit \(proc.terminationStatus))" : "Failed: \(String(tail.suffix(900)))")
                    }
                }
                self.refresh()
            }
        }

        do {
            try p.run()
            statusMessage = "Running: \(operationName)"
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            try? logHandle?.close()
            operationActive = false
            operationName = "Failed"
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }

    private func operationTitle(for script: String) -> String {
        switch script {
        case "bootstrap-macos.sh": return "Installing runtime dependencies"
        case "install-profile.sh": return "Installing \(selectedExpansion.shortTitle) core"
        case "setup-profile.sh": return "Setting up \(selectedExpansion.shortTitle) realm"
        case "prepare-client.sh": return "Preparing client data"
        case "import-core.sh": return "Importing custom core"
        case "backup.sh": return "Creating realm backup"
        case "setup-tbc-extractor-engine.sh": return "Setting up local TBC extractor engine"
        case "setup-playerbots.sh": return "Populating TBC world with PlayerBots"
        default: return script
        }
    }

    var advertisedRealmAddress: String {
        if lanAccessEnabled, isUsableLANIPv4(detectedLANIP) { return detectedLANIP }
        return "127.0.0.1"
    }

    var windowsRealmlistLine: String {
        "set realmlist \(advertisedRealmAddress)"
    }

    var lanAuthListening: Bool { authRunning }
    var lanWorldListening: Bool { worldRunning }

    private func updateNetworkStatusFromCachedAddress() {
        if lanAccessEnabled {
            networkStatus = isUsableLANIPv4(detectedLANIP)
                ? "Home Network ready to configure at \(detectedLANIP)"
                : "Home Network selected — click Refresh IP once before Apply."
        } else {
            networkStatus = "This Mac Only — realm advertises 127.0.0.1"
        }
    }

    func refreshLANAddress() {
        detectedLANIP = detectPrimaryLANIPv4() ?? "Not detected"
        if isUsableLANIPv4(detectedLANIP) {
            UserDefaults.standard.set(detectedLANIP, forKey: profileKey("lastLANIP"))
        }
        updateNetworkStatusFromCachedAddress()
    }

    func setLANAccess(_ enabled: Bool) {
        lanAccessEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: profileKey("lanAccess"))
        updateNetworkStatusFromCachedAddress()
    }

    func copyWindowsRealmlist() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(windowsRealmlistLine, forType:.string)
        statusMessage = "Copied: \(windowsRealmlistLine)"
    }

    func applyNetworkSettings() {
        guard !networkApplyInProgress else { return }

        let enabled = lanAccessEnabled
        let address = advertisedRealmAddress
        let expansion = selectedExpansion
        let currentMySQLPort = mysqlPort

        if enabled && !isUsableLANIPv4(address) {
            statusMessage = "Home Network needs a LAN address. Click Refresh IP, then Apply Network Settings."
            return
        }

        // Do not probe MySQL with a blocking subprocess from Settings.
        // The background mysql command below will return a normal error if
        // Managed MySQL is not available.
        let dbName: String
        switch expansion {
        case .wotlk: dbName = "acore_auth"
        case .vanilla, .tbc: dbName = "realmd"
        case .cataclysm, .mop: dbName = "auth"
        default:
            statusMessage = "LAN realm-address automation is not configured for \(expansion.shortTitle) yet."
            return
        }

        // Resolve every MainActor-owned value before leaving the MainActor.
        // The background worker below must never call methods on ServerModel.
        guard let mysqlExecutable = locateMySQL("mysql") else {
            statusMessage = "Network settings failed: mysql client not found."
            return
        }

        let lanDefaultsKey = profileKey("lanAccess")

        networkApplyInProgress = true
        networkStatus = "Applying network settings…"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Construct DatabaseClient entirely from captured immutable
                // values. No ServerModel/MainActor access occurs on this queue.
                let dbc = DatabaseClient(
                    executable: mysqlExecutable,
                    port: currentMySQLPort
                )

                let tableCount = try dbc.query(
                    database: "mysql",
                    sql: "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\(dbName)' AND table_name='realmlist';"
                ).trimmingCharacters(in: .whitespacesAndNewlines)

                guard tableCount == "1" else {
                    throw NSError(
                        domain: "WoWCC.Network",
                        code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Database \(dbName).realmlist was not found."
                        ]
                    )
                }

                let columnsRaw = try dbc.query(
                    database: "mysql",
                    sql: "SELECT COLUMN_NAME FROM information_schema.columns WHERE table_schema='\(dbName)' AND table_name='realmlist';"
                )

                let columns = Set(
                    columnsRaw
                        .split(separator: "\n")
                        .map {
                            String($0).trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                        }
                )

                guard columns.contains("address") else {
                    throw NSError(
                        domain: "WoWCC.Network",
                        code: 2,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "\(dbName).realmlist does not contain an address column."
                        ]
                    )
                }

                let safeAddress = address.replacingOccurrences(
                    of: "'",
                    with: "''"
                )

                var assignments = ["address='\(safeAddress)'"]

                if columns.contains("localAddress") {
                    assignments.append("localAddress='\(safeAddress)'")
                } else if columns.contains("localaddress") {
                    assignments.append("localaddress='\(safeAddress)'")
                }

                let updateSQL: String
                if columns.contains("id") {
                    updateSQL =
                        "UPDATE realmlist SET \(assignments.joined(separator: ", ")) ORDER BY id LIMIT 1;"
                } else {
                    updateSQL =
                        "UPDATE realmlist SET \(assignments.joined(separator: ", ")) LIMIT 1;"
                }

                try dbc.execute(
                    database: dbName,
                    sql: updateSQL
                )

                let verifySQL = columns.contains("id")
                    ? "SELECT address FROM realmlist ORDER BY id LIMIT 1;"
                    : "SELECT address FROM realmlist LIMIT 1;"

                let verify = try dbc.query(
                    database: dbName,
                    sql: verifySQL
                ).trimmingCharacters(in: .whitespacesAndNewlines)

                guard verify == address else {
                    throw NSError(
                        domain: "WoWCC.Network",
                        code: 3,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Realm address verification failed. Database returned '\(verify)'."
                        ]
                    )
                }

                DispatchQueue.main.async {
                    UserDefaults.standard.set(
                        enabled,
                        forKey: lanDefaultsKey
                    )

                    self.networkStatus = enabled
                        ? "Home Network enabled — realm advertises \(address)"
                        : "This Mac Only enabled — realm advertises 127.0.0.1"

                    self.statusMessage =
                        "\(self.networkStatus). Restart Auth/World if they are already running."

                    self.networkApplyInProgress = false
                }
            } catch {
                let message = error.localizedDescription

                DispatchQueue.main.async {
                    self.networkStatus = "Network settings were not changed."
                    self.statusMessage =
                        "Network settings failed: \(message)"
                    self.networkApplyInProgress = false
                }
            }
        }
    }

    private func detectPrimaryLANIPv4() -> String? {
        let addresses = Host.current().addresses

        if let privateAddress = addresses.first(where: { address in
            isPrivateLANIPv4(address)
        }) {
            return privateAddress
        }

        return addresses.first(where: { address in
            isUsableLANIPv4(address)
        })
    }

    private func isPrivateLANIPv4(_ value:String) -> Bool {
        guard isUsableLANIPv4(value) else { return false }

        if value.hasPrefix("10.") { return true }
        if value.hasPrefix("192.168.") { return true }

        let parts=value.split(separator:".")
        if parts.count == 4,
           parts[0] == "172",
           let second=Int(parts[1]),
           (16...31).contains(second) {
            return true
        }
        return false
    }

    private func isUsableLANIPv4(_ value:String) -> Bool {
        let parts=value.split(separator:".",omittingEmptySubsequences:false)
        guard parts.count == 4 else { return false }

        for part in parts {
            guard let number=Int(part), (0...255).contains(number) else {
                return false
            }
        }

        guard !value.hasPrefix("127."),
              value != "0.0.0.0",
              !value.hasPrefix("169.254.") else {
            return false
        }

        return true
    }

    func loadLog() {
        guard let choice = availableLogs.first(where: { $0.id == selectedLog }) else {
            logText = "Log is not available."
            return
        }
        guard let data = try? Data(contentsOf: choice.url),
              let text = String(data: data, encoding: .utf8) else {
            logText = selectedLog == "world-crash.log"
                ? "No World crash has been recorded yet."
                : "No log output yet at \(choice.url.path)"
            return
        }
        logText = String(text.suffix(120_000))
    }

    private func profileKey(_ suffix: String) -> String { "profile.\(selectedExpansion.rawValue).\(suffix)" }
    private func loadProfileSettings() {
        clientPath=UserDefaults.standard.string(forKey:profileKey("client")) ?? ""
        customCorePath=UserDefaults.standard.string(forKey:profileKey("core")) ?? ""
        let d=UserDefaults.standard
        let population=d.integer(forKey:profileKey("playerBots.population"))
        playerBotPopulation = population == 0 ? 250 : min(5000,max(10,population))
        playerBotsEnabled = d.object(forKey:profileKey("playerBots.enabled")) == nil ? true : d.bool(forKey:profileKey("playerBots.enabled"))
        playerBotsBattlegrounds = d.object(forKey:profileKey("playerBots.battlegrounds")) == nil ? true : d.bool(forKey:profileKey("playerBots.battlegrounds"))
        playerBotsQuesting = d.object(forKey:profileKey("playerBots.questing")) == nil ? true : d.bool(forKey:profileKey("playerBots.questing"))
        playerBotCreationSpeed = d.string(forKey: profileKey("playerBots.creationSpeed")) ?? "Fast"
    }
    private func saveProfileSettings() { UserDefaults.standard.set(clientPath,forKey:profileKey("client")); UserDefaults.standard.set(customCorePath,forKey:profileKey("core")) }

    private func probeRealmDatabaseReady() -> Bool {
        do {
            let dbc = try dbClient()
            let required: [(String,String)]
            switch selectedExpansion {
            case .wotlk:
                required = [("acore_auth","account"),("acore_auth","realmlist"),("acore_characters","characters"),("acore_characters","item_instance"),("acore_characters","character_inventory"),("acore_world","item_template"),("acore_world","creature_template")]
            case .vanilla, .tbc:
                required = [("realmd","account"),("realmd","realmlist"),("characters","characters"),("mangos","item_template"),("mangos","creature_template")]
            case .cataclysm, .mop:
                required = [("auth","account"),("auth","realmlist"),("characters","characters"),("world","item_template"),("world","creature_template")]
            default:
                return false
            }
            for (db, table) in required {
                let q = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\(db)' AND table_name='\(table)';"
                if try dbc.query(database:"mysql",sql:q).trimmingCharacters(in:.whitespacesAndNewlines) != "1" { return false }
            }
            mysqlRunning = true
            return true
        } catch { return false }
    }

    private func locateMySQL(_ tool: String) -> String? {
        ["/opt/homebrew/opt/mysql@8.4/bin/\(tool)", "/usr/local/opt/mysql@8.4/bin/\(tool)", "/opt/homebrew/bin/\(tool)", "/usr/local/bin/\(tool)"].first { FileManager.default.isExecutableFile(atPath:$0) }
    }
    private func dbClient() throws -> DatabaseClient { guard let e=locateMySQL("mysql") else { throw err("mysql client not found") }; return DatabaseClient(executable:e,port:mysqlPort) }
    private func runSync(_ executable: String, _ args: [String]) throws { let p=Process(); p.executableURL=URL(fileURLWithPath:executable); p.arguments=args; let er=Pipe(); p.standardError=er; try p.run(); p.waitUntilExit(); if p.terminationStatus != 0 { throw err(String(data:er.fileHandleForReading.readDataToEndOfFile(),encoding:.utf8) ?? "Command failed") } }
    private func portOpen(_ port: Int32) -> Bool { let p=Process(); p.executableURL=URL(fileURLWithPath:"/usr/sbin/lsof"); p.arguments=["-nP","-iTCP:\(port)","-sTCP:LISTEN"]; p.standardOutput=Pipe(); p.standardError=Pipe(); do { try p.run(); p.waitUntilExit(); return p.terminationStatus == 0 } catch { return false } }
    private func err(_ s:String)->NSError { NSError(domain:"WoWCC",code:1,userInfo:[NSLocalizedDescriptionKey:s]) }
    private func raceName(_ id:Int)->String { [1:"Human",2:"Orc",3:"Dwarf",4:"Night Elf",5:"Undead",6:"Tauren",7:"Gnome",8:"Troll",10:"Blood Elf",11:"Draenei"][id] ?? "Race \(id)" }
    private func className(_ id:Int)->String { [1:"Warrior",2:"Paladin",3:"Hunter",4:"Rogue",5:"Priest",6:"Death Knight",7:"Shaman",8:"Mage",9:"Warlock",11:"Druid"][id] ?? "Class \(id)" }
}
