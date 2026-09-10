import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var model: ServerModel
    @State private var section = "Dashboard"
    @State private var customItemID = "49623"
    @State private var customItemCount = "1"
    @State private var customSpellID = "72286"
    @State private var levelTarget = "80"
    @State private var pendingCleanup: CleanupAction?

    private let sections = ["Dashboard","Setup Guide","Health Checks","Expansions","Characters","Gear Sets","Collection Browser","Mounts","PlayerBots","Accounts","Database","Logs","Backups","Storage & Cleanup","Settings"]

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("WOW CONTROL CENTER").font(.headline.bold())
                        Text(model.selectedExpansion.title).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(sections, id: \.self) { item in
                                Button {
                                    section = item
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: icon(item))
                                            .frame(width: 20)
                                        Text(item)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                    .background(section == item ? Color.accentColor.opacity(0.16) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                    }
                    .frame(maxHeight: .infinity)

                    Divider()
                    HStack(spacing: 7) {
                        Circle().fill(model.worldRunning ? Color.green : Color.secondary).frame(width: 8, height: 8)
                        Text(model.worldRunning ? "Realm Online" : "Realm Offline")
                            .font(.caption)
                        Spacer()
                    }
                    .padding(12)
                }
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
            } detail: {
                Group {
                    switch section {
                    case "Dashboard": dashboard
                    case "Setup Guide": setupGuide
                    case "Health Checks": healthChecks
                    case "Expansions": expansions
                    case "Characters": characters
                    case "Gear Sets": gearSets
                    case "Collection Browser": catalog(mountOnly:false)
                    case "Mounts": catalog(mountOnly:true)
                    case "PlayerBots": playerBots
                    case "Accounts": accounts
                    case "Database": database
                    case "Logs": logs
                    case "Backups": backups
                    case "Storage & Cleanup": cleanupCenter
                    default: settings
                    }
                }
                .padding(20)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Divider()
            bottomStatusBar
        }
        .frame(minWidth: 960, minHeight: 600)
        .alert("Confirm Cleanup", isPresented: Binding(get: { pendingCleanup != nil }, set: { if !$0 { pendingCleanup = nil } }), presenting: pendingCleanup) { action in
            Button("Cancel", role: .cancel) { pendingCleanup = nil }
            Button(action.buttonTitle, role: .destructive) { performCleanup(action); pendingCleanup = nil }
        } message: { action in
            Text(action.warning)
        }
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 10) {
            if model.operationActive {
                ProgressView().controlSize(.small)
            } else {
                let bad = ["fail","error","missing","not initialized","incomplete"].contains { model.statusMessage.lowercased().contains($0) }
                Image(systemName: bad ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(bad ? .orange : .green)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(model.operationActive ? model.operationName : "Status")
                    .font(.caption.bold())
                Text(model.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .help(model.statusMessage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { model.copyStatusToClipboard() } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless)
                .help("Copy full status message")

            statusDot("Core", model.profileInstalled)
            statusDot("MySQL", model.mysqlRunning)
            statusDot("Realm DB", model.realmDatabaseReady)
            statusDot("Auth", model.authRunning)
            statusDot("World", model.worldRunning)

            Divider().frame(height: 18)
            Text(model.selectedExpansion.shortTitle)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .background(.bar)
    }

    private func statusDot(_ title: String, _ ready: Bool) -> some View {
        HStack(spacing: 4) {
            Circle().fill(ready ? Color.green : Color.secondary).frame(width: 7, height: 7)
            Text(title).font(.caption2)
        }
    }

    private var topBar: some View {
        HStack(spacing:10) {
            Picker("Expansion",selection:$model.selectedExpansion) { ForEach(ExpansionID.allCases) { Text($0.title).tag($0) } }.frame(width:310)
            maturityBadge(model.selectedExpansion.maturity)
            Spacer()
            Button { model.setupSelectedProfile() } label:{ Label("Repair Realm",systemImage:"wrench.and.screwdriver.fill") }
                .buttonStyle(.bordered)
                .disabled(model.operationActive || !model.mysqlRuntimeInstalled)
                .help("Initialize or repair the selected realm database. TBC also validates and repairs the full world item catalog.")
            Button { model.startAll() } label:{ Label("Start",systemImage:"play.fill") }.buttonStyle(.borderedProminent)
            Button { model.play() } label:{ Label("Start & Play",systemImage:"gamecontroller.fill") }.buttonStyle(.borderedProminent)
            Button("Stop") { model.stopAll() }
        }
    }

    private var dashboard: some View {
        VStack(alignment:.leading,spacing:18) {
            topBar
            Text("Server Control Center").font(.system(size:34,weight:.bold))
            Text(model.statusMessage).foregroundStyle(.secondary)
            HStack(spacing:12) {
                statusCard("Core",model.profileInstalled,model.selectedExpansion.recommendedCore)
                statusCard("Client",model.clientConfigured,model.clientConfigured ? "Linked" : model.selectedExpansion.clientHint)
                statusCard("MySQL",model.mysqlRunning,"Managed MySQL 8.4 :3307")
                statusCard("Realm DB",model.realmDatabaseReady,model.realmDatabaseReady ? "Schema + required tables ready" : "Run Setup Realm")
                statusCard("World",model.worldRunning,"Game service")
            }
            Text("Server Controls").font(.title2.bold())
            VStack(spacing:10) {
                HStack {
                    Label("World Server", systemImage: "globe")
                        .frame(width:150,alignment:.leading)
                    Spacer()
                    Text(model.worldRunning ? "Running" : "Stopped")
                        .foregroundStyle(model.worldRunning ? .green : .secondary)
                        .frame(width:70,alignment:.trailing)
                    Button("Start") { model.startWorldServer() }.disabled(model.worldRunning)
                    Button("Stop") { model.stopWorldServer() }.disabled(!model.worldRunning)
                    Button("Restart") { model.restartWorldServer() }.disabled(!model.worldRunning)
                }
                HStack {
                    Label("Realm Server", systemImage: "network")
                        .frame(width:150,alignment:.leading)
                    Spacer()
                    Text(model.authRunning ? "Running" : "Stopped")
                        .foregroundStyle(model.authRunning ? .green : .secondary)
                        .frame(width:70,alignment:.trailing)
                    Button("Start") { model.startRealmServer() }.disabled(model.authRunning)
                    Button("Stop") { model.stopRealmServer() }.disabled(!model.authRunning)
                    Button("Restart") { model.restartRealmServer() }.disabled(!model.authRunning)
                }
                HStack {
                    Label("MySQL", systemImage: "cylinder")
                        .frame(width:150,alignment:.leading)
                    Spacer()
                    Text(model.mysqlRunning ? "Running" : "Stopped")
                        .foregroundStyle(model.mysqlRunning ? .green : .secondary)
                        .frame(width:70,alignment:.trailing)
                    Button("Start") { model.startMySQLServer() }.disabled(model.mysqlRunning)
                    Button("Stop") { model.stopMySQLServer() }.disabled(!model.mysqlRunning || model.worldRunning || model.authRunning)
                    Button("Restart") { model.restartMySQLServer() }.disabled(!model.mysqlRunning || model.worldRunning || model.authRunning)
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius:12))

            Text("Quick Administration").font(.title2.bold())
            LazyVGrid(columns:[GridItem(.adaptive(minimum:220))],spacing:12) {
                quick("Setup Guide","list.number") { section="Setup Guide" }
                quick("Health Checks","checkmark.shield.fill") { section="Health Checks" }
                quick("Characters","person.3.fill") { section="Characters" }
                quick("Gear Sets","square.grid.3x3.fill") { section="Gear Sets" }
                quick("Give Gear","shield.lefthalf.filled") { section="Collection Browser" }
                quick("Legendary","sparkles") { model.catalogKind = .legendary; section="Collection Browser" }
                quick("Mounts","figure.equestrian.sports") { model.catalogKind = .mount; section="Mounts" }
                quick("Accounts","person.crop.circle.badge.checkmark") { section="Accounts" }
                quick("Backup Now","externaldrive.fill") { model.runBackup() }
            }
            Spacer()
        }
    }

    private var setupGuide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Guided Setup").font(.largeTitle.bold())
                        Text("Follow these steps in order. Control Center marks each completed step and tells you exactly what to do next.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("NEXT: \(nextSetupStepTitle)")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                }

                setupStep(1, "Install / Verify MySQL 8.4", "Installs the MySQL 8.4 runtime used by Control Center. The database itself remains isolated per era and is not installed as a macOS login service.", model.mysqlRuntimeInstalled, "Install MySQL") { model.installMySQLRuntime() }

                setupStep(2, "Install Build Dependencies", "Installs/validates CMake, Git, Boost, OpenSSL, Ninja and the remaining tools required to build and manage cores.", model.runtimeDependenciesReady, "Install Dependencies") { model.bootstrapMac() }

                let importOnly = model.selectedExpansion.maturity == .experimental
                setupStep(3, importOnly ? "Import Compatible Core" : "Install \(model.selectedExpansion.shortTitle) Core", importOnly ? "No maintained one-click core is assigned to this experimental profile. Select a compatible core that you built or obtained separately." : "Downloads and builds \(model.selectedExpansion.recommendedCore) into this era's isolated runtime.", model.profileInstalled, importOnly ? "Import Core…" : "Install Core") {
                    if importOnly { model.chooseCustomCore() } else { model.installSelectedProfile() }
                }

                setupStep(4, "Select Game Client", "Link the compatible client for this era: \(model.selectedExpansion.clientHint). Control Center remembers the path; it never deletes the original client.", model.clientConfigured, "Select Client…") { model.chooseClient() }

                if model.selectedExpansion.maturity != .experimental {
                    setupStep(5, "Prepare Client / Server Data", "Configures the local realm and extracts/copies the maps, DBC/DB2, vmaps and other data required by this core.", model.clientDataReady, "Prepare Client Data") { model.prepareClient() }

                    if model.selectedExpansion == .tbc {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "shippingbox.fill")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Apple Silicon TBC Extractor").font(.headline)
                                    Text("CMaNGOS disables native extractors on ARM. Control Center can run the official amd64 extraction workflow locally through Docker/Colima emulation — no Windows PC required.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            HStack {
                                Button("Install Local TBC Extractor Engine") { model.installTBCExtractorEngine() }
                                    .buttonStyle(.borderedProminent)
                                Button("Prepare Client Data") { model.prepareClient() }
                                    .buttonStyle(.bordered)
                                Spacer()
                                Button("Import Extracted TBC Data…") { model.importExtractedTBCData() }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    setupStep(5, "Prepare Client / Server Data", "Core-specific for this experimental profile. Use this only when your imported core provides compatible extractors/data requirements.", true, "Prepare If Needed") { model.prepareClient() }
                }

                setupStep(6, "Initialize / Repair Realm Database", "Starts the managed per-era MySQL instance, imports the correct auth/characters/world schema, writes local configs and verifies required tables.", model.realmDatabaseReady, "Setup / Repair Realm") { model.setupSelectedProfile() }

                let checksGood = !model.healthChecks.isEmpty && model.healthFailCount == 0
                setupStep(7, "Run Full Health Checks", "Validates core binaries, client data, MySQL schemas/tables, configuration, ports and Admin Center access before launch.", checksGood, "Run All Checks") { model.runAllChecks() }

                setupStep(8, "Start Realm", "Starts managed MySQL, authentication and world services only after the realm database passes readiness checks.", model.worldRunning, "Start Realm") { model.startAll() }

                GroupBox {
                    HStack(spacing: 14) {
                        Image(systemName: model.worldRunning && model.clientConfigured ? "gamecontroller.fill" : "gamecontroller")
                            .font(.system(size: 30)).foregroundStyle(model.worldRunning && model.clientConfigured ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ready to Play").font(.title3.bold())
                            Text(model.worldRunning && model.clientConfigured ? "Realm is online and the client is linked. Start & Play will launch the selected client." : "Complete the steps above, then launch the realm and matching client from one button.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.play() } label: { Label("Start & Play", systemImage: "play.fill") }
                            .buttonStyle(.borderedProminent)
                            .disabled(!model.clientConfigured || model.operationActive)
                    }.padding(6)
                }

                Text("Current status: \(model.statusMessage)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var nextSetupStepTitle: String {
        if !model.mysqlRuntimeInstalled { return "Install MySQL 8.4" }
        if !model.runtimeDependenciesReady { return "Install Build Dependencies" }
        if !model.profileInstalled { return model.selectedExpansion.maturity == .experimental ? "Import Core" : "Install Core" }
        if !model.clientConfigured { return "Select Client" }
        if model.selectedExpansion.maturity != .experimental && !model.clientDataReady { return "Prepare Client Data" }
        if !model.realmDatabaseReady { return "Setup / Repair Realm" }
        if model.healthChecks.isEmpty || model.healthFailCount > 0 { return "Run Health Checks" }
        if !model.worldRunning { return "Start Realm" }
        return "Start & Play"
    }

    @ViewBuilder
    private func setupStep(_ number: Int, _ title: String, _ detail: String, _ done: Bool, _ actionTitle: String, action: @escaping () -> Void) -> some View {
        GroupBox {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(done ? Color.green.opacity(0.18) : Color.secondary.opacity(0.12)).frame(width: 38, height: 38)
                    if done { Image(systemName: "checkmark").foregroundStyle(.green).font(.headline.bold()) }
                    else { Text("\(number)").font(.headline.bold()) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)
                if done {
                    HStack(spacing: 10) {
                        Label("Done", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption.bold())
                        if number == 3 && model.selectedExpansion.maturity != .experimental {
                            Button(model.selectedExpansion == .tbc ? "Rebuild / Apply Patches" : "Repair / Rebuild Core", action: action)
                                .buttonStyle(.borderedProminent)
                                .disabled(model.operationActive)
                        }
                        if number == 6 {
                            Button("Repair Realm", action: action)
                                .buttonStyle(.borderedProminent)
                                .disabled(model.operationActive || !model.mysqlRuntimeInstalled)
                                .help("Run realm database validation and repair again even when the Realm DB status is already green.")
                        }
                    }
                } else {
                    Button(actionTitle, action: action).buttonStyle(.borderedProminent).disabled(model.operationActive)
                }
            }.padding(6)
        }
    }

    private var healthChecks: some View {
        VStack(alignment:.leading,spacing:14) {
            topBar
            HStack {
                VStack(alignment:.leading,spacing:3) {
                    Text("Health Check Center").font(.largeTitle.bold())
                    Text("Full preflight validation for the selected era before you install, start or play.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.runAllChecks() } label:{ Label(model.healthCheckRunning ? "Checking…" : "Run All Checks",systemImage:"checkmark.shield.fill") }
                    .buttonStyle(.borderedProminent).disabled(model.healthCheckRunning)
            }

            HStack(spacing:10) {
                checkSummary("Passed",model.healthPassCount,.green,"checkmark.circle.fill")
                checkSummary("Warnings",model.healthWarningCount,.orange,"exclamationmark.triangle.fill")
                checkSummary("Failed",model.healthFailCount,.red,"xmark.octagon.fill")
                checkSummary("Launch",model.launchReady ? 1 : 0,model.launchReady ? .green : .secondary,model.launchReady ? "play.circle.fill" : "pause.circle")
            }

            if model.healthChecks.isEmpty {
                ContentUnavailableView("No checks run yet", systemImage:"checkmark.shield", description:Text("Run All Checks to validate dependencies, core, database, client data, services, network ports and Admin Center readiness."))
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:12) {
                        ForEach(Array(Dictionary(grouping:model.healthChecks,by:{$0.category}).keys.sorted()),id:\.self) { category in
                            GroupBox(category) {
                                VStack(spacing:0) {
                                    ForEach(model.healthChecks.filter{$0.category == category}) { check in
                                        HStack(alignment:.top,spacing:10) {
                                            Image(systemName:checkIcon(check.state)).foregroundStyle(checkColor(check.state)).frame(width:18)
                                            VStack(alignment:.leading,spacing:2) {
                                                Text(check.title).font(.headline)
                                                Text(check.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                            }
                                            Spacer()
                                            Text(check.state.rawValue.uppercased()).font(.caption2.bold()).foregroundStyle(checkColor(check.state))
                                                .padding(.horizontal,7).padding(.vertical,3).background(checkColor(check.state).opacity(0.12),in:Capsule())
                                            if check.fix != .none { Button("Fix") { model.fixHealthCheck(check) }.buttonStyle(.bordered) }
                                        }.padding(.vertical,7)
                                        if check.id != model.healthChecks.filter({$0.category == category}).last?.id { Divider() }
                                    }
                                }.padding(4)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { if model.healthChecks.isEmpty { model.runAllChecks() } }
    }

    private func checkSummary(_ title:String,_ count:Int,_ color:Color,_ icon:String)->some View {
        HStack(spacing:8) { Image(systemName:icon).foregroundStyle(color); VStack(alignment:.leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text("\(count)").font(.title2.bold()) } }
            .padding(10).frame(minWidth:120,alignment:.leading).background(.thinMaterial,in:RoundedRectangle(cornerRadius:12))
    }
    private func checkIcon(_ state:HealthCheckState)->String { switch state { case .pass:return "checkmark.circle.fill"; case .warning:return "exclamationmark.triangle.fill"; case .fail:return "xmark.octagon.fill" } }
    private func checkColor(_ state:HealthCheckState)->Color { switch state { case .pass:return .green; case .warning:return .orange; case .fail:return .red } }

    private var expansions: some View {
        VStack(alignment:.leading,spacing:16) {
            topBar
            Text("Expansion Manager").font(.largeTitle.bold())
            Text("One app; isolated runtime, database and client link per expansion.").foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:255))],spacing:12) {
                    ForEach(ExpansionID.allCases) { e in
                        Button { model.selectedExpansion=e } label:{
                            VStack(alignment:.leading,spacing:8) {
                                HStack { Text(e.shortTitle).font(.title2.bold()); Spacer(); maturityBadge(e.maturity) }
                                Text(e.title).font(.headline).multilineTextAlignment(.leading)
                                Text(e.recommendedCore).font(.caption).foregroundStyle(.secondary)
                                Text(e.clientHint).font(.caption2).foregroundStyle(.secondary)
                            }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.thinMaterial,in:RoundedRectangle(cornerRadius:16))
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Button("Install Runtime Dependencies") { model.bootstrapMac() }
                Button(model.profileInstalled ? (model.selectedExpansion == .tbc ? "Rebuild / Apply Patches" : "Repair / Rebuild Core") : "Install Selected Core") { model.installSelectedProfile() }.buttonStyle(.borderedProminent)
                Button("Select Client…") { model.chooseClient() }
                Button("Find Client Online") { model.findClientOnline() }
                Button("Prepare Client Data") { model.prepareClient() }
                Button("Setup / Repair Realm") { model.setupSelectedProfile() }.buttonStyle(.borderedProminent)
                Button("Import Custom Core…") { model.chooseCustomCore() }
            }
        }
    }

    private var playerBots: some View {
        VStack(alignment:.leading,spacing:16) {
            topBar
            HStack {
                VStack(alignment:.leading,spacing:5) {
                    Text("PlayerBots").font(.largeTitle.bold())
                    Text("Populate TBC with AI adventurers that quest, group, form guilds and join PvP.").foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.playerBotsReady ? "WORLD POPULATION READY" : "SETUP REQUIRED").font(.caption.bold())
                    .padding(.horizontal,10).padding(.vertical,6)
                    .background((model.playerBotsReady ? Color.green : Color.orange).opacity(0.15),in:Capsule())
            }
            if model.selectedExpansion != .tbc {
                GroupBox("TBC PlayerBots") { Text("Select The Burning Crusade in Expansion Manager. WoWCC currently enables the official CMaNGOS PlayerBots module for TBC.").foregroundStyle(.secondary).padding(8) }
            } else {
                HStack(spacing:12) {
                    statusCard("Core Module",model.profileInstalled,"BUILD_PLAYERBOTS=ON")
                    statusCard("Bot Database",model.playerBotsReady,model.playerBotsReady ? "PlayerBots database/config installed" : "Click Populate / Repair World")
                    statusCard("Target Population",model.playerBotsEnabled,"\(model.playerBotPopulation) AI players")
                }
                GroupBox("Live Bot Status") {
                    HStack(spacing:18) {
                        VStack(alignment:.leading) { Text("Accounts").font(.caption).foregroundStyle(.secondary); Text("\(model.playerBotAccountsLive)").font(.title2.bold()) }
                        VStack(alignment:.leading) { Text("Bot Characters").font(.caption).foregroundStyle(.secondary); Text("\(model.playerBotCharactersLive)").font(.title2.bold()) }
                        VStack(alignment:.leading) { Text("ONLINE NOW").font(.caption.bold()).foregroundStyle(.secondary); Text("\(model.playerBotsOnlineLive)").font(.title.bold()).foregroundStyle(model.playerBotsOnlineLive > 0 ? .green : .orange) }
                        VStack(alignment:.leading) { Text("Runtime Config").font(.caption).foregroundStyle(.secondary); Text(model.playerBotRuntimeConfigOK ? "LOADED" : "MISSING").font(.caption.bold()).foregroundStyle(model.playerBotRuntimeConfigOK ? .green : .orange) }
                        VStack(alignment:.leading) { Text("Bot SQL").font(.caption).foregroundStyle(.secondary); Text("\(model.playerBotModuleSQLCount) migrations").font(.caption.bold()).foregroundStyle(model.playerBotModuleSQLCount > 0 ? .green : .orange) }
                        Spacer()
                        Text(model.playerBotStatsStatus).font(.caption.bold())
                        Button("Refresh Live") { model.refreshPlayerBotStats() }
                    }.padding(8)
                }
                GroupBox("World Population") {
                    VStack(alignment:.leading,spacing:12) {
                        HStack { Toggle("Enable PlayerBots",isOn:$model.playerBotsEnabled); Toggle("Battlegrounds & Arenas",isOn:$model.playerBotsBattlegrounds); Toggle("Questing",isOn:$model.playerBotsQuesting) }
                        HStack {
                            Text("Online bots").frame(width:90,alignment:.leading)
                            Stepper(value:$model.playerBotPopulation,in:10...5000,step:50) { Text("\(model.playerBotPopulation)").font(.title3.bold()).frame(width:70,alignment:.leading) }
                            ForEach([250,500,1000,2000,5000], id: \.self) { count in
                                if model.playerBotPopulation == count {
                                    Button("\(count)") { model.setPlayerBotPreset(count) }
                                        .buttonStyle(.borderedProminent)
                                } else {
                                    Button("\(count)") { model.setPlayerBotPreset(count) }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                        Text("Supports up to 5,000 configured bots. Start lower and increase gradually; large populations use substantially more CPU, RAM and database I/O.").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text("Creation speed").frame(width:90, alignment:.leading)
                            Picker("", selection:$model.playerBotCreationSpeed) {
                                Text("Safe").tag("Safe")
                                Text("Normal").tag("Normal")
                                Text("Fast").tag("Fast")
                                Text("Maximum").tag("Maximum")
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth:420)
                        }
                        Text("Fast = 10 logins/sec. Maximum = 20 logins per 0.5 sec update cycle. Use Maximum only when you want the population filled as quickly as possible.").font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
                GroupBox("Make The World Alive") {
                    VStack(alignment:.leading,spacing:10) {
                        Text("Rebuild the TBC core once to compile the official PlayerBots module, then populate the existing realm database and config.").foregroundStyle(.secondary)
                        HStack {
                            Button(model.profileInstalled ? "Rebuild Core + PlayerBots" : "Install Core + PlayerBots") { model.installSelectedProfile() }.buttonStyle(.bordered).disabled(model.operationActive)
                            Button("Populate / Repair World") { model.installOrRepairPlayerBots() }.buttonStyle(.borderedProminent).disabled(model.operationActive || !model.profileInstalled)
                            Button("Apply Bot Settings") { model.applyPlayerBotSettings() }.disabled(model.operationActive || !model.profileInstalled)
                            Button("Initialize Bots") { model.initializePlayerBots() }.disabled(model.operationActive || !model.worldRunning)
                        }
                        Text("After Populate / Repair World, restart World Server. First PlayerBots startup can be heavy; WoWCC keeps mangosd alive, treats the process itself as authoritative during load, and automatically restarts World up to 3 times if it truly exits unexpectedly. Existing accounts and characters are preserved.").font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
            }
            Spacer()
        }
    }

    private var characters: some View {
        VStack(alignment:.leading,spacing:14) {
            topBar
            HStack { Text("Characters").font(.largeTitle.bold()); Spacer(); Button("Reload") { model.loadAccounts(); model.loadCharacters() } }

            GroupBox("Character Creation") {
                VStack(alignment:.leading, spacing:10) {
                    HStack(spacing:10) {
                        Picker("Account", selection: Binding(
                            get: { model.creatorAccountID ?? -1 },
                            set: { model.creatorAccountID = $0 == -1 ? nil : $0 }
                        )) {
                            if model.accounts.isEmpty {
                                Text("No accounts").tag(-1)
                            } else {
                                ForEach(model.accounts) { account in
                                    Text(account.username).tag(account.id)
                                }
                            }
                        }
                        .frame(width:220)

                        TextField("Character name", text:$model.creatorName)
                            .frame(width:180)

                        Picker("Gender", selection:$model.creatorGender) {
                            Text("Male").tag("Male")
                            Text("Female").tag("Female")
                        }
                        .frame(width:125)
                    }

                    HStack(spacing:10) {
                        Picker("Race", selection:$model.creatorRace) {
                            ForEach(model.characterCreatorRaces, id:\.self) { Text($0).tag($0) }
                        }
                        .frame(width:220)

                        Picker("Class", selection:$model.creatorClass) {
                            ForEach(model.characterCreatorClasses, id:\.self) { Text($0).tag($0) }
                        }
                        .frame(width:220)

                        Button {
                            model.openCharacterCreator()
                        } label: {
                            Label("Open Character Creator", systemImage:"person.crop.circle.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Accounts") { section = "Accounts" }
                    }

                    Text("Uses the selected \(model.selectedExpansion.shortTitle) game client to create the character correctly for that expansion. Direct SQL character creation is intentionally avoided because each core requires different starting data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
            .onAppear {
                model.loadAccounts()
                model.normalizeCharacterCreatorSelection()
            }
            .onChange(of:model.selectedExpansion) { _ in
                model.normalizeCharacterCreatorSelection()
            }

            HStack(alignment:.top,spacing:16) {
                List(model.characters,selection:$model.selectedCharacter) { c in
                    HStack {
                        Circle().fill(c.online ? .green : .secondary).frame(width:9,height:9)
                        VStack(alignment:.leading) { Text(c.name).font(.headline); Text("Level \(c.level) • \(c.race) \(c.playerClass)").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Text(c.online ? "ONLINE":"OFFLINE").font(.caption2.bold())
                    }.tag(c)
                }.frame(minWidth:520)
                GroupBox("Selected Character") {
                    VStack(alignment:.leading,spacing:12) {
                        if let c=model.selectedCharacter {
                            Text(c.name).font(.title2.bold())
                            Text("Level \(c.level) • \(c.race) \(c.playerClass)")
                            HStack { TextField("Level",text:$levelTarget).frame(width:80); Button("Set Level") { if let n=Int(levelTarget) { model.setLevel(n) } } }
                            Button("Open Gear Catalog") { section="Collection Browser" }
                            Button("Open Mount Catalog") { section="Mounts" }
                            Divider()
                            HStack { Text("Inventory").font(.headline); Spacer(); Button("Reload") { model.loadInventory() } }
                            if model.inventory.isEmpty { Text("No inventory rows loaded").font(.caption).foregroundStyle(.secondary) }
                            else {
                                ScrollView {
                                    LazyVStack(alignment:.leading,spacing:6) {
                                        ForEach(model.inventory.prefix(80)) { it in
                                            HStack {
                                                VStack(alignment:.leading) { Text(it.name).font(.caption.bold()); Text("#\(it.itemEntry) • bag \(it.bag) slot \(it.slot)").font(.caption2).foregroundStyle(.secondary) }
                                                Spacer()
                                                Button(role:.destructive) { model.removeInventoryItem(it) } label:{ Image(systemName:"trash") }.buttonStyle(.borderless)
                                            }.padding(.vertical,2)
                                        }
                                    }
                                }.frame(maxHeight:250)
                            }
                        } else { Text("Select a character") }
                    }.padding(8).frame(width:300,alignment:.leading)
                }
            }
        }
    }


    private var gearSets: some View {
        VStack(alignment:.leading,spacing:14) {
            topBar
            HStack {
                VStack(alignment:.leading,spacing:3) {
                    Text("Raid & PvP Sets").font(.largeTitle.bold())
                    Text("Full database-backed TBC / WotLK Raid-PvE and PvP set collections. Filter by class, inspect every piece, or give the full set to a character.").foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.selectedCharacter.map{"Target: \($0.name)"} ?? "Select a character first").foregroundStyle(.secondary)
            }
            HStack {
                Picker("Sets",selection:$model.gearSetCategory) {
                    ForEach(GearSetCategory.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)

                Picker("Class",selection:$model.gearSetClassFilter) {
                    ForEach(PlayerClassFilter.allCases.filter { cls in
                        (model.selectedExpansion != .tbc && model.selectedExpansion != .vanilla) || cls != .deathKnight
                    }) { Text($0.rawValue).tag($0) }
                }
                .frame(width:160)

                Button {
                    model.loadGearSets()
                } label: {
                    if model.gearSetsLoading {
                        HStack(spacing:6) { ProgressView().controlSize(.small); Text("Loading…") }
                    } else {
                        Text("Load / Refresh Gear Sets")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.gearSetsLoading)

                Button("Open Complete Collection") {
                    model.catalogKind = .raidSet
                    model.searchText = ""
                    model.clearServerCatalog()
                    section = "Collection Browser"
                }
            }
            Text(model.gearSetStatus).font(.caption).foregroundStyle(.secondary)
            HSplitView {
                List(selection:$model.selectedGearSet) {
                    ForEach(model.filteredGearSets) { set in
                        VStack(alignment:.leading,spacing:3) {
                            HStack { Text(set.name).font(.headline); Spacer(); Text("iLvl \(set.itemLevel)").font(.caption.bold()).foregroundStyle(.secondary) }
                            Text("\(set.category.rawValue) • \(set.items.count) pieces • Set ID \(set.id)").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical,4).tag(set)
                    }
                }.frame(minWidth:300,idealWidth:380)

                ScrollView {
                    if let set=model.selectedGearSet {
                        VStack(alignment:.leading,spacing:14) {
                            HStack(alignment:.top) {
                                VStack(alignment:.leading,spacing:3) {
                                    Text(set.name).font(.title2.bold())
                                    Text("\(set.category.rawValue) • Set #\(set.id) • highest iLvl \(set.itemLevel)").foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Give Full Set") { model.giveGearSet(set) }.buttonStyle(.borderedProminent)
                            }
                            LazyVGrid(columns:[GridItem(.adaptive(minimum:235))],spacing:10) {
                                ForEach(set.items) { item in
                                    VStack(alignment:.leading,spacing:6) {
                                        HStack(spacing:10) {
                                            Group {
                                                if let u=model.iconURL(for:item) { AsyncImage(url:u) { img in img.resizable().scaledToFill() } placeholder:{ Image(systemName:"shield.fill") } }
                                                else { Image(systemName:item.kind == .weapon ? "bolt.horizontal.fill":"shield.fill").foregroundStyle(.secondary) }
                                            }.frame(width:42,height:42).background(.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:8)).clipShape(RoundedRectangle(cornerRadius:8))
                                            VStack(alignment:.leading,spacing:2) {
                                                Text(item.name).font(.headline).lineLimit(2)
                                                Text("\(item.subtitle) • iLvl \(item.itemLevel ?? 0)").font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        HStack { Text("#\(item.id)").font(.caption.monospaced()).foregroundStyle(.secondary); Spacer(); Button("Give") { model.give(item) }.buttonStyle(.bordered) }
                                    }
                                    .padding(10)
                                    .background(.thinMaterial,in:RoundedRectangle(cornerRadius:12))
                                }
                            }
                        }.padding(6)
                    } else {
                        ContentUnavailableView("No gear set selected", systemImage:"square.grid.3x3", description:Text("Start the database, choose Load / Refresh Gear Sets, then select any raid/PvP/PvE set."))
                    }
                }.frame(minWidth:450)
            }
        }
    }

    private func catalog(mountOnly:Bool)->some View {
        VStack(alignment:.leading,spacing:14) {
            topBar
            HStack {
                VStack(alignment:.leading,spacing:3) {
                    Text(mountOnly ? "Mount Collection" : "Complete Item Collection").font(.largeTitle.bold())
                    Text(mountOnly
                         ? "All mount teaching items found in the selected realm database."
                         : "Era-isolated catalog: only items introduced in the selected expansion are shown. Switching expansion automatically loads that expansion.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let target=model.selectedCharacter {
                    Label("Target: \(target.name)",systemImage:"person.crop.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        WoWTooltipPanel.shared.hide()
                        section = "Characters"
                    } label: {
                        Label("No character selected — Create Character",systemImage:"exclamationmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !mountOnly {
                Picker("Collection",selection:$model.catalogKind) {
                    ForEach(CatalogKind.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220, alignment: .leading)
                .onChange(of:model.catalogKind) { _ in
                    model.catalogSelectionChanged()
                }
                .onAppear {
                    if model.serverCatalog.isEmpty && !model.catalogLoading {
                        model.loadCatalogPage(reset: true)
                    }
                }
            } else {
                Color.clear.frame(height:0).onAppear {
                    model.loadMountCollection()
                }
            }

            GroupBox("Filters") {
                HStack(spacing:10) {
                    TextField("Name or item ID",text:$model.searchText)
                        .frame(minWidth:180)

                    if !mountOnly {
                        Picker("Class",selection:$model.playerClassFilter) {
                            ForEach(PlayerClassFilter.allCases.filter { cls in
                                (model.selectedExpansion != .tbc && model.selectedExpansion != .vanilla) || cls != .deathKnight
                            }) { Text($0.rawValue).tag($0) }
                        }
                        .frame(width:145)
                    }

                    Picker("Quality",selection:$model.itemQualityFilter) {
                        ForEach(ItemQualityFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .frame(width:145)

                    if !mountOnly {
                        Picker("Slot",selection:$model.equipSlotFilter) {
                            ForEach(EquipSlotFilter.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .frame(width:145)

                        TextField("Min iLvl",text:$model.minimumItemLevel)
                            .frame(width:80)
                    }

                    Button("Load") {
                        if mountOnly { model.loadMountCollection() }
                        else { model.loadCatalogPage(reset:true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.catalogLoading)

                    Button("Reset") {
                        if mountOnly { model.loadMountCollection(resetFilters:true) }
                        else { model.resetCollectionFilters() }
                    }

                    if model.catalogLoading { ProgressView().controlSize(.small) }
                }
                .textFieldStyle(.roundedBorder)
                .padding(6)
            }

            HStack {
                Text(model.catalogStatus).font(.caption).foregroundStyle(.secondary)

                if !model.iconLoadingIDs.isEmpty {
                    Text("Icons: \(model.iconLoadingIDs.count) loading")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if !model.failedIconIDs.isEmpty {
                    Text("\(model.failedIconIDs.count) icon(s) need retry")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Button("Reload Missing Icons") { model.retryFailedIcons() }
                    .help("Retry every missing icon on the current catalog page using era-specific sources and local cache.")

                Spacer()
                if model.catalogPage > 0 {
                    Button("Previous") { model.previousCatalogPage() }
                }
                Text("Page \(model.catalogPage + 1)").font(.caption.monospacedDigit())
                Button("Next") { model.nextCatalogPage() }
                    .disabled(!model.catalogHasMore || model.catalogLoading)
            }

            ScrollView {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:255),spacing:10)],spacing:10) {
                    ForEach(model.serverCatalog) { item in
                        VStack(alignment:.leading,spacing:8) {
                            HStack(alignment:.top,spacing:10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius:10)
                                        .fill(.secondary.opacity(0.10))
                                    if let u=model.iconURL(for:item) {
                                        AsyncImage(url:u) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Image(systemName:item.kind == .weapon ? "bolt.horizontal.fill" : item.kind == .mount ? "hare.fill" : "shield.fill")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        if model.iconLoadingIDs.contains(item.id) {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName:item.kind == .weapon ? "bolt.horizontal.fill" : item.kind == .mount ? "hare.fill" : item.kind == .legendary ? "sparkles" : "shield.fill")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .frame(width:52,height:52)
                                .clipShape(RoundedRectangle(cornerRadius:10))

                                VStack(alignment:.leading,spacing:3) {
                                    Text(item.name).font(.headline).lineLimit(2)
                                    Text(item.quality).font(.caption.bold())
                                    Text(item.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                if hovering {
                                    model.resolveTooltip(for:item)
                                } else {
                                    WoWTooltipPanel.shared.hide()
                                }
                            }
                            .modifier(WoWItemTooltipModifier(
                                text:model.tooltipText(for:item),
                                quality:item.quality,
                                loading:model.tooltipLoadingIDs.contains(item.id)
                            ))

                            HStack {
                                Text("#\(item.id)").font(.caption.monospaced()).foregroundStyle(.secondary)
                                if let sid=item.itemSetID { Text("Set \(sid)").font(.caption2).foregroundStyle(.secondary) }
                                Spacer()

                                if model.selectedCharacter == nil {
                                    Button {
                                        WoWTooltipPanel.shared.hide()
                                        section = "Characters"
                                    } label: {
                                        Label("Create Character",systemImage:"person.crop.circle.badge.plus")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .help("Create a character before giving items.")
                                } else {
                                    Button {
                                        WoWTooltipPanel.shared.hide()
                                        model.give(item)
                                    } label: {
                                        Label("Give",systemImage:"shippingbox.and.arrow.backward")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .onHover { hovering in
                                if hovering { WoWTooltipPanel.shared.hide() }
                            }
                        }
                        .padding(11)
                        .background(.thinMaterial,in:RoundedRectangle(cornerRadius:12))
                    }
                }
                .padding(.vertical,4)

                if model.serverCatalog.isEmpty && !model.catalogLoading {
                    ContentUnavailableView(
                        mountOnly ? "Mount collection not loaded" : "Collection not loaded",
                        systemImage: mountOnly ? "hare.fill" : "square.grid.3x3.fill",
                        description: Text("Choose a collection and press Load. Results come directly from the selected realm database.")
                    )
                    .padding(.top,30)
                }
            }
        }
    }


    private var accounts: some View {
        VStack(alignment:.leading,spacing:14) {
            topBar
            HStack { Text("Accounts").font(.largeTitle.bold()); Spacer(); Button("Reload") { model.loadAccounts() } }
            GroupBox("Create GM / Player Account") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Username",text:$model.newAccountName).frame(width:180)
                        SecureField("Password",text:$model.newAccountPassword).frame(width:180)
                        Stepper("GM \(model.gmLevel)",value:$model.gmLevel,in:0...3).frame(width:110)
                        Button("Create") { model.createAccount() }.buttonStyle(.borderedProminent)
                    }
                    Text(model.selectedExpansion.serverFamily == .cmangos
                         ? (model.selectedExpansion == .tbc
                            ? "CMaNGOS adapter • creates the account, enables TBC addon level 1, then applies GM level 0–3."
                            : "CMaNGOS adapter • creates the account and applies GM level 0–3.")
                         : (model.selectedExpansion.serverFamily == .azerothCore
                            ? "AzerothCore adapter • creates the account and applies GM level to all realms."
                            : "Account creation is unavailable for this custom profile."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
            List(model.accounts) { a in HStack { Text("#\(a.id)").font(.caption.monospaced()).foregroundStyle(.secondary); Text(a.username).font(.headline); Spacer(); Text(a.gmLevel > 0 ? "GM \(a.gmLevel)":"PLAYER").font(.caption.bold()) } }
        }
    }

    private var database: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                topBar
                Text("Database").font(.largeTitle.bold())
                HStack(spacing:12) {
                    statusCard("MySQL Runtime", model.mysqlRuntimeInstalled, model.mysqlRuntimeInstalled ? "MySQL 8.4 binaries installed" : "MySQL 8.4 runtime missing")
                    statusCard("Managed MySQL",model.mysqlRunning,"Isolated data directory for \(model.selectedExpansion.shortTitle) • port 3307")
                    statusCard("Realm DB",model.realmDatabaseReady,model.realmDatabaseReady ? "Required realm tables verified" : "Not initialized / needs repair")
                }
                Text("Control Center initializes, starts and stops its own isolated MySQL instance. It is not registered as a macOS login service.").foregroundStyle(.secondary).textSelection(.enabled)
                GroupBox("MySQL Management") {
                    VStack(alignment:.leading, spacing:12) {
                        HStack { Button("Install MySQL 8.4") { model.installMySQLRuntime() }.disabled(model.operationActive); Button("Repair / Reinstall MySQL") { model.repairMySQLRuntime() }.disabled(model.operationActive); Button("Restart Managed MySQL") { model.restartManagedMySQL() }.disabled(model.operationActive || !model.mysqlRuntimeInstalled) }
                        Divider()
                        Text("Repair / Reinstall replaces the Homebrew MySQL 8.4 program files but keeps all Control Center realm databases and characters.").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        HStack { Button("Setup / Repair Realm DB") { model.setupSelectedProfile() }.disabled(model.operationActive || !model.mysqlRuntimeInstalled); Button("Health Checks") { section = "Health Checks" } }
                    }.padding(6)
                }
                Spacer(minLength:20)
            }
        }
    }

    private var logs: some View {
        VStack(alignment:.leading,spacing:12) {
            topBar
            HStack {
                Text("Logs").font(.largeTitle.bold())
                Spacer()
                Picker("Log", selection: $model.selectedLog) {
                    ForEach(model.availableLogs, id: \.id) { log in
                        Text(log.title).tag(log.id)
                    }
                }
                .frame(width:210)
                .onChange(of: model.selectedLog) { _, _ in
                    model.refreshLogNow()
                }
                Button("Refresh Log") { model.refreshLogNow() }
            }
            ScrollView {
                Text(model.logText.isEmpty ? "No log output yet.":model.logText)
                    .font(.system(.body,design:.monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .padding()
            }
            .background(.black.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
        }
        .onAppear { model.refreshLogNow() }
    }

    private var backups: some View { VStack(alignment:.leading,spacing:14) { topBar; Text("Backups").font(.largeTitle.bold()); Text("Creates a compressed SQL backup of the selected realm.").foregroundStyle(.secondary); Button("Backup Now") { model.runBackup() }.buttonStyle(.borderedProminent); Spacer() } }

    private var cleanupCenter: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                Text("Storage & Cleanup").font(.largeTitle.bold())
                Text("Remove only what you want. All deletion is restricted to WoW Control Center's own Application Support folder. Your original external WoW client is never deleted.")
                    .foregroundStyle(.secondary)

                GroupBox("Safe Cache Cleanup") {
                    VStack(alignment: .leading, spacing: 12) {
                        cleanupRow("Build Cache", "Removes the CMake/Ninja build directory. Core source and installed binaries stay intact.", "Clean", .buildCache)
                        Divider()
                        cleanupRow("Downloaded Database Cache", "Removes downloaded Cata/MoP DB release archives or CMaNGOS content DB checkout. The live realm database is kept.", "Remove Cache", .databaseCache)
                        Divider()
                        cleanupRow("Logs", "Stops services if needed and removes realm, installer and build logs for the selected era.", "Clear Logs", .logs)
                        Divider()
                        cleanupRow("Backups", "Deletes SQL backup files for the selected era only.", "Delete Backups", .backups)
                    }.padding(6)
                }

                GroupBox("Installed / Downloaded Components") {
                    VStack(alignment: .leading, spacing: 12) {
                        cleanupRow("Core Source + Installed Core", "Removes downloaded source, build output and installed auth/world binaries/configs. Realm DB and extracted client data are kept.", "Remove Core", .core)
                        Divider()
                        cleanupRow("Extracted Client / Server Data", "Removes extracted DBC/DB2/maps/vmaps/mmaps copied into Control Center. The original WoW client is never touched.", "Remove Data", .clientData)
                        Divider()
                        cleanupRow("All Downloads for This Era", "Removes core source/build, installed core, DB download cache and extracted client/server data. Realm DB and backups are kept.", "Clean Downloads", .allDownloads)
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Client Link").font(.headline)
                                Text(model.clientPath.isEmpty ? "No client is linked." : model.clientPath).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            Spacer()
                            Button("Forget Link") { pendingCleanup = .clientLink }.disabled(model.clientPath.isEmpty)
                        }
                    }.padding(6)
                }

                GroupBox("MySQL Runtime & Instance") {
                    VStack(alignment: .leading, spacing: 12) {
                        cleanupRow("Managed MySQL Data for This Era", "Deletes the selected era's isolated MySQL data directory. This removes its realm databases, accounts and characters, but does not uninstall MySQL 8.4 itself.", "Delete MySQL Data", .mysqlData)
                        Divider()
                        HStack(alignment:.top, spacing:16) {
                            VStack(alignment:.leading, spacing:3) { Text("Repair / Reinstall MySQL 8.4").font(.headline); Text("Reinstalls the MySQL program files through Homebrew without deleting Control Center realm databases.").font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                            Spacer(); Button("Repair MySQL") { model.repairMySQLRuntime() }.disabled(model.operationActive)
                        }
                        Divider()
                        cleanupRow("MySQL 8.4 Runtime", "Uninstalls the Homebrew mysql@8.4 package. Control Center realm data is kept, but realms cannot start until MySQL is installed again.", "Uninstall MySQL", .mysqlRuntime)
                    }.padding(6)
                }

                GroupBox("Destructive Reset") {
                    VStack(alignment: .leading, spacing: 12) {
                        cleanupRow("Realm Database", "Deletes this era's managed MySQL data directory, including accounts, characters and realm/world DB state.", "Delete Realm DB", .realmDatabase)
                        Divider()
                        cleanupRow("Factory Reset Selected Era", "Deletes every Control Center-managed file for this era: source/core, build, extracted data, database, caches, logs, backups and saved client/core links.", "Factory Reset", .factoryReset)
                    }.padding(6)
                }

                HStack {
                    Button { model.openApplicationDataFolder() } label: { Label("Open Application Data Folder", systemImage: "folder") }
                    Spacer()
                    Text(model.dataRoot.path).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
    }

    private func cleanupRow(_ title: String, _ detail: String, _ button: String, _ action: CleanupAction) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 20)
            Button(button, role: action.isHighlyDestructive ? .destructive : nil) { pendingCleanup = action }
        }
    }

    private func performCleanup(_ action: CleanupAction) {
        switch action {
        case .buildCache: model.cleanBuildCache()
        case .databaseCache: model.removeDatabaseDownloadCache()
        case .logs: model.clearLogs()
        case .backups: model.clearBackupsForSelectedExpansion()
        case .core: model.removeDownloadedCore()
        case .clientData: model.removeClientData()
        case .clientLink: model.forgetClientLink()
        case .allDownloads: model.cleanAllDownloadsForSelectedExpansion()
        case .mysqlData: model.deleteRealmDatabase()
        case .mysqlRuntime: model.uninstallMySQLRuntime()
        case .realmDatabase: model.deleteRealmDatabase()
        case .factoryReset: model.factoryResetSelectedExpansion()
        }
    }

    private var settings: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:14) {
                topBar
                Text("Settings").font(.largeTitle.bold())

                GroupBox("Selected Expansion") {
                    VStack(alignment:.leading,spacing:10) {
                        LabeledContent("Core",value:model.selectedExpansion.recommendedCore)
                        LabeledContent("Client",value:model.clientPath.isEmpty ? "Not selected":model.clientPath)
                        LabeledContent("Data",value:model.dataRoot.path)
                        HStack {
                            Button("Setup Guide") { section="Setup Guide" }
                            Button("Select Client…") { model.chooseClient() }
                            Button("Find Client Online") { model.findClientOnline() }
                            Button("Install Dependencies") { model.bootstrapMac() }
                            Button(model.profileInstalled ? (model.selectedExpansion == .tbc ? "Rebuild / Apply Patches" : "Repair / Rebuild Core") : "Install Core") { model.installSelectedProfile() }
                            Button("Prepare Client Data") { model.prepareClient() }
                            Button("Setup / Repair Realm") { model.setupSelectedProfile() }
                            Button("Cleanup…") { section="Storage & Cleanup" }
                        }
                    }
                    .padding(8)
                }

                GroupBox("Network / LAN Access") {
                    VStack(alignment:.leading,spacing:12) {
                        Picker("Server Access",selection:Binding(
                            get:{ model.lanAccessEnabled },
                            set:{ model.setLANAccess($0) }
                        )) {
                            Text("This Mac Only").tag(false)
                            Text("Home Network").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth:420)

                        HStack(spacing:18) {
                            LabeledContent("Mac LAN IP",value:model.detectedLANIP)
                            Button("Refresh IP") { model.refreshLANAddress() }
                        }

                        LabeledContent("Realm advertises",value:model.advertisedRealmAddress)

                        VStack(alignment:.leading,spacing:6) {
                            Text("Windows client realmlist").font(.caption.bold())
                            HStack {
                                Text(model.windowsRealmlistLine)
                                    .font(.system(.body,design:.monospaced))
                                    .textSelection(.enabled)
                                    .padding(.horizontal,10)
                                    .padding(.vertical,7)
                                    .background(.quaternary,in:RoundedRectangle(cornerRadius:7))
                                Button("Copy realmlist") { model.copyWindowsRealmlist() }
                            }
                        }

                        HStack(spacing:14) {
                            Label("Auth Server",systemImage:model.lanAuthListening ? "checkmark.circle.fill":"circle")
                                .foregroundStyle(model.lanAuthListening ? .green:.secondary)
                            Label("World Server",systemImage:model.lanWorldListening ? "checkmark.circle.fill":"circle")
                                .foregroundStyle(model.lanWorldListening ? .green:.secondary)
                            Spacer()
                            if model.networkApplyInProgress {
                                ProgressView().controlSize(.small)
                            }
                            Button(model.networkApplyInProgress ? "Applying…" : "Apply Network Settings") {
                                model.applyNetworkSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.networkApplyInProgress)
                        }

                        Text(model.networkStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("The network switch is instant and does not scan the network. Refresh IP runs only when you request it; Apply performs the database update separately. Managed MySQL stays private on 127.0.0.1:3307.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
            }
        }
    }

    private func statusCard(_ title:String,_ ready:Bool,_ detail:String)->some View { VStack(alignment:.leading,spacing:7) { HStack { Circle().frame(width:9,height:9).foregroundStyle(ready ? .green:.secondary); Text(title).font(.headline) }; Text(ready ? "READY":"NOT READY").font(.title3.bold()); Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2) }.padding(15).frame(maxWidth:.infinity,alignment:.leading).background(.thinMaterial,in:RoundedRectangle(cornerRadius:16)) }
    private func maturityBadge(_ m:ProfileMaturity)->some View { Text(m.rawValue).font(.caption2.bold()).padding(.horizontal,8).padding(.vertical,5).background(m == .supported ? Color.green.opacity(0.16):m == .community ? Color.orange.opacity(0.16):Color.secondary.opacity(0.14),in:Capsule()) }
    private func quick(_ t:String,_ symbol:String,action:@escaping()->Void)->some View { Button(action:action) { Label(t,systemImage:symbol).frame(maxWidth:.infinity,alignment:.leading).padding(9) }.buttonStyle(.bordered) }
    private func icon(_ s:String)->String { ["Dashboard":"gauge.with.dots.needle.67percent","Setup Guide":"list.number","Health Checks":"checkmark.shield.fill","Expansions":"square.stack.fill","Characters":"person.3.fill","Gear Sets":"square.grid.3x3.fill","Collection Browser":"shield.lefthalf.filled","Mounts":"figure.equestrian.sports","PlayerBots":"person.3.sequence.fill","Accounts":"person.crop.circle.badge.checkmark","Database":"cylinder.split.1x2.fill","Logs":"text.alignleft","Backups":"externaldrive.fill","Storage & Cleanup":"trash.slash.fill"][s] ?? "gearshape.fill" }
}


private enum CleanupAction: String, Identifiable {
    case buildCache, databaseCache, logs, backups, core, clientData, clientLink, allDownloads, mysqlData, mysqlRuntime, realmDatabase, factoryReset
    var id: String { rawValue }
    var isHighlyDestructive: Bool { self == .mysqlData || self == .mysqlRuntime || self == .realmDatabase || self == .factoryReset }
    var buttonTitle: String {
        switch self {
        case .buildCache: return "Clean Build Cache"
        case .databaseCache: return "Remove DB Cache"
        case .logs: return "Clear Logs"
        case .backups: return "Delete Backups"
        case .core: return "Remove Core"
        case .clientData: return "Remove Extracted Data"
        case .clientLink: return "Forget Client Link"
        case .allDownloads: return "Clean All Downloads"
        case .mysqlData: return "Delete MySQL Data"
        case .mysqlRuntime: return "Uninstall MySQL 8.4"
        case .realmDatabase: return "Delete Realm Database"
        case .factoryReset: return "Factory Reset Era"
        }
    }
    var warning: String {
        switch self {
        case .mysqlData:
            return "This permanently deletes the selected era's managed MySQL data, including realm databases, accounts and characters. MySQL 8.4 itself stays installed."
        case .mysqlRuntime:
            return "This uninstalls the Homebrew mysql@8.4 runtime from this Mac. Control Center realm data is kept. If other software uses this Homebrew package, it may also be affected."
        case .realmDatabase:
            return "This permanently deletes the selected era's managed MySQL database, including accounts and characters. Create a backup first if you want to keep them."
        case .factoryReset:
            return "This permanently removes every WoW Control Center-managed file and backup for the selected era. Your external WoW client is not deleted."
        case .backups:
            return "This deletes the selected era's backup files. This cannot be undone."
        case .core:
            return "The downloaded core source/build and installed core binaries will be removed. You can reinstall them later."
        case .clientData:
            return "Extracted server data will be removed. The original game client remains untouched."
        case .allDownloads:
            return "All app-downloaded/re-created components for the selected era will be removed, but realm DB and backups are kept."
        case .clientLink:
            return "Control Center will forget this client path. No game files will be deleted."
        default:
            return "The selected Control Center-managed files will be removed."
        }
    }
}

private struct WoWItemTooltipModifier: ViewModifier {
    let text: String
    let quality: String
    let loading: Bool
    @State private var hovering=false

    func body(content: Content) -> some View {
        content
            .onHover { value in
                hovering=value
                if value {
                    WoWTooltipPanel.shared.show(text:text,quality:quality,loading:loading)
                } else {
                    WoWTooltipPanel.shared.hide()
                }
            }
            .onChange(of:text) { _, _ in
                if hovering {
                    WoWTooltipPanel.shared.show(text:text,quality:quality,loading:loading)
                }
            }
            .onChange(of:loading) { _, _ in
                if hovering {
                    WoWTooltipPanel.shared.show(text:text,quality:quality,loading:loading)
                }
            }
    }
}

@MainActor
private final class WoWTooltipPanel {
    static let shared = WoWTooltipPanel()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<WoWTooltipPanelView>?
    private var trackingTimer: Timer?

    private init() {}

    func show(text: String, quality: String, loading: Bool) {
        let view = WoWTooltipPanelView(text:text, quality:quality, loading:loading)

        if panel == nil {
            let host = NSHostingView(rootView:view)
            host.translatesAutoresizingMaskIntoConstraints = false

            let p = NSPanel(
                contentRect:NSRect(x:0,y:0,width:470,height:260),
                styleMask:[.borderless,.nonactivatingPanel],
                backing:.buffered,
                defer:false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.transient]
            p.hidesOnDeactivate = false
            // Critical: the tooltip is visual-only. It can never intercept
            // clicks intended for Give / Give Full Set or any other control.
            p.ignoresMouseEvents = true
            p.contentView = host

            hostingView = host
            panel = p
        } else {
            hostingView?.rootView = view
        }

        resizeToContent()
        positionNearMouse()
        panel?.orderFrontRegardless()

        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(withTimeInterval:0.08,repeats:true) { [weak self] _ in
            Task { @MainActor in self?.positionNearMouse() }
        }
    }

    func hide() {
        trackingTimer?.invalidate()
        trackingTimer=nil
        panel?.orderOut(nil)
    }

    private func resizeToContent() {
        guard let host=hostingView, let panel else { return }

        let width: CGFloat = 470
        let lineCount = max(4, hostingView?.rootView.text.components(separatedBy:"\n").count ?? 4)
        let estimated = CGFloat(lineCount * 18 + 66)
        let screenLimit = max(300, (NSScreen.main?.visibleFrame.height ?? 900) - 48)
        let height = min(max(estimated, 140), screenLimit)
        panel.setContentSize(NSSize(width:width,height:height))
        host.frame = NSRect(x:0,y:0,width:width,height:height)
    }

    private func positionNearMouse() {
        guard let panel else { return }

        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x:mouse.x + 18, y:mouse.y - panel.frame.height - 18)

        let screen = NSScreen.screens.first { NSMouseInRect(mouse,$0.frame,false) }
            ?? NSScreen.main

        if let visible=screen?.visibleFrame {
            if origin.x + panel.frame.width > visible.maxX {
                origin.x = mouse.x - panel.frame.width - 18
            }
            if origin.x < visible.minX {
                origin.x = visible.minX + 8
            }

            if origin.y < visible.minY {
                origin.y = mouse.y + 20
            }
            if origin.y + panel.frame.height > visible.maxY {
                origin.y = visible.maxY - panel.frame.height - 8
            }
        }

        panel.setFrameOrigin(origin)
    }
}

private struct WoWTooltipPanelView: View {
    let text: String
    let quality: String
    let loading: Bool

    var body: some View {
        VStack(alignment:.leading,spacing:7) {
            HStack(spacing:7) {
                Circle()
                    .fill(qualityColor)
                    .frame(width:7,height:7)

                Text(quality)
                    .font(.caption.bold())
                    .foregroundStyle(qualityColor)

                Spacer()

                if loading {
                    ProgressView().controlSize(.mini)
                }
            }

            ScrollView {
                VStack(alignment:.leading,spacing:3) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.isEmpty ? " " : line)
                            .font(lineFont(index:index,line:line))
                            .foregroundStyle(lineColor(index:index,line:line))
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .fixedSize(horizontal:false,vertical:true)
                    }
                }
                .frame(maxWidth:.infinity,alignment:.leading)
                .textSelection(.enabled)
            }
            .scrollIndicators(.automatic)
        }
        .padding(13)
        .frame(width:470,alignment:.leading)
        .background(
            RoundedRectangle(cornerRadius:8)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius:8)
                        .stroke(qualityColor.opacity(0.85),lineWidth:1)
                )
        )
    }

    private var lines: [String] { text.components(separatedBy:"\n") }

    private func lineFont(index:Int,line:String) -> Font {
        if index == 0 { return .system(size:15,weight:.bold) }
        if line.hasPrefix("Item Level") { return .system(size:11,weight:.medium) }
        if line.contains("Set:") || line.hasPrefix("Equip:") || line.hasPrefix("Use:") || line.hasPrefix("Chance on hit:") { return .system(size:12,weight:.medium) }
        return .system(size:12,weight:.medium)
    }

    private func lineColor(index:Int,line:String) -> Color {
        if index == 0 { return qualityColor }
        let lower=line.lowercased()
        if line.hasPrefix("Equip:") || line.hasPrefix("Use:") || line.hasPrefix("Chance on hit:") || line.contains("Set:") { return .green }
        if line.hasPrefix("Requires ") { return .red }
        if line.hasPrefix("Item Level") || line.hasPrefix("Item #") || lower.contains("item #") { return Color.white.opacity(0.72) }
        if line.first == Character("\"") && line.last == Character("\"") { return .yellow }
        return .white
    }

    private var qualityColor: Color {
        switch quality.lowercased() {
        case "legendary": return .orange
        case "epic": return .purple
        case "rare": return .blue
        case "uncommon": return .green
        case "poor": return .gray
        default: return .white
        }
    }
}

