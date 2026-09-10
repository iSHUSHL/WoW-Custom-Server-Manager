from pathlib import Path

p = Path('Sources/WoWServerControlCenter/ContentView.swift')
s = p.read_text()

old_sidebar = '''                    VStack(alignment: .leading, spacing: 5) {
                        Text("WOW CONTROL CENTER").font(.headline.bold())
                        Text(model.selectedExpansion.title).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)

                    Divider()
'''
new_sidebar = '''                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.accentColor.opacity(0.34), Color.black.opacity(0.04)],
                                        center: .center,
                                        startRadius: 4,
                                        endRadius: 62
                                    )
                                )
                                .frame(width: 108, height: 108)

                            Circle()
                                .stroke(Color.yellow.opacity(0.34), lineWidth: 1)
                                .frame(width: 94, height: 94)

                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 78, height: 78)
                                .shadow(color: Color.black.opacity(0.65), radius: 12, y: 6)
                        }
                        .padding(.top, 8)

                        Text(model.selectedExpansion.shortTitle.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                    Divider().opacity(0.55)
'''
if old_sidebar not in s:
    raise SystemExit('sidebar header block not found')
s = s.replace(old_sidebar, new_sidebar, 1)

old_footer = '''                    Divider()
                    HStack(spacing: 7) {
                        Circle().fill(model.worldRunning ? Color.green : Color.secondary).frame(width: 8, height: 8)
                        Text(model.worldRunning ? "Realm Online" : "Realm Offline")
                            .font(.caption)
                        Spacer()
                    }
                    .padding(12)
'''
new_footer = '''                    Divider().opacity(0.55)
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(model.worldRunning ? Color.green : Color.secondary)
                                .frame(width: 8, height: 8)
                                .shadow(color: model.worldRunning ? Color.green.opacity(0.7) : .clear, radius: 5)
                            Text(model.worldRunning ? "Realm Online" : "Realm Offline")
                                .font(.caption.weight(.semibold))
                            Spacer()
                        }

                        HStack {
                            Text("v1.5.81")
                            Spacer()
                            Text("Build 1581")
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    .padding(10)
'''
if old_footer not in s:
    raise SystemExit('sidebar footer block not found')
s = s.replace(old_footer, new_footer, 1)

old_topbar_start = s.index('    private var topBar: some View {')
old_dashboard_start = s.index('    private var dashboard: some View {')
new_topbar = r'''    private var topBar: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red:0.035, green:0.075, blue:0.13),
                                Color(red:0.055, green:0.10, blue:0.16),
                                Color(red:0.09, green:0.055, blue:0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.58), Color.blue.opacity(0.18), Color.yellow.opacity(0.18)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )

                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.38))
                            .frame(width: 82, height: 82)
                        Circle()
                            .stroke(Color.yellow.opacity(0.46), lineWidth: 1)
                            .frame(width: 78, height: 78)
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.yellow.opacity(0.14), radius: 12)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("WOW")
                            .font(.system(size: 13, weight: .black, design: .serif))
                            .tracking(5)
                            .foregroundStyle(Color.yellow.opacity(0.78))

                        Text("SERVER CONTROL CENTER")
                            .font(.system(size: 25, weight: .bold, design: .serif))
                            .tracking(1.5)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white, Color.yellow.opacity(0.92)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Text("CREATE  •  MANAGE  •  EXPLORE  •  CUSTOMIZE")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1.9)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 18)

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(model.selectedExpansion.title)
                            .font(.headline.weight(.semibold))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(model.worldRunning ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(model.worldRunning ? "REALM ONLINE" : (model.realmDatabaseReady ? "READY TO START" : "SETUP REQUIRED"))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.2)
                        }
                        .foregroundStyle(model.worldRunning ? Color.green : Color.orange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(minHeight: 116)
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 6)

            expansionStrip

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.realmDatabaseReady ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(model.realmDatabaseReady ? "Realm Ready" : "Realm Needs Setup")
                        .font(.subheadline.weight(.semibold))
                    maturityBadge(model.selectedExpansion.maturity)
                }

                Spacer()

                Button { model.setupSelectedProfile() } label: {
                    Label("Repair Realm", systemImage:"wrench.and.screwdriver.fill")
                        .frame(minWidth: 112)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(model.operationActive || !model.mysqlRuntimeInstalled)

                Button { model.startAll() } label: {
                    Label("Start Realm", systemImage:"play.fill")
                        .frame(minWidth: 112)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button { model.play() } label: {
                    Label("Start & Play", systemImage:"gamecontroller.fill")
                        .frame(minWidth: 116)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button { model.stopAll() } label: {
                    Label("Stop", systemImage:"stop.fill")
                        .frame(minWidth: 72)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }

    private var expansionStrip: some View {
        HStack(spacing: 8) {
            ForEach(ExpansionID.allCases) { expansion in
                Button {
                    model.selectedExpansion = expansion
                } label: {
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(expansionAccent(expansion).opacity(model.selectedExpansion == expansion ? 0.25 : 0.10))
                                .frame(width: 34, height: 34)
                            Image(systemName: expansionSymbol(expansion))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(expansionAccent(expansion))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(expansion.shortTitle)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Text(expansionVersion(expansion))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(model.selectedExpansion == expansion ? expansionAccent(expansion).opacity(0.13) : Color.black.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(model.selectedExpansion == expansion ? expansionAccent(expansion).opacity(0.82) : Color.white.opacity(0.08), lineWidth: model.selectedExpansion == expansion ? 1.4 : 1)
                    )
                    .shadow(color: model.selectedExpansion == expansion ? expansionAccent(expansion).opacity(0.22) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func expansionAccent(_ expansion: ExpansionID) -> Color {
        switch expansion {
        case .vanilla: return Color.yellow
        case .tbc: return Color.green
        case .wotlk: return Color.cyan
        case .cataclysm: return Color.orange
        case .mop: return Color.mint
        default: return Color.accentColor
        }
    }

    private func expansionSymbol(_ expansion: ExpansionID) -> String {
        switch expansion {
        case .vanilla: return "shield.fill"
        case .tbc: return "flame.fill"
        case .wotlk: return "snowflake"
        case .cataclysm: return "bolt.fill"
        case .mop: return "leaf.fill"
        default: return "circle.fill"
        }
    }

    private func expansionVersion(_ expansion: ExpansionID) -> String {
        switch expansion {
        case .vanilla: return "1.12.1"
        case .tbc: return "2.4.3"
        case .wotlk: return "3.3.5a"
        case .cataclysm: return "4.3.4"
        case .mop: return "5.4.8"
        default: return ""
        }
    }

'''
s = s[:old_topbar_start] + new_topbar + s[old_dashboard_start:]

old_dashboard_intro = '''        VStack(alignment:.leading,spacing:18) {
            topBar
            Text("Server Control Center").font(.system(size:34,weight:.bold))
            Text(model.statusMessage).foregroundStyle(.secondary)
            HStack(spacing:12) {
'''
new_dashboard_intro = '''        ScrollView {
            VStack(alignment:.leading,spacing:18) {
            topBar

            HStack {
                VStack(alignment:.leading,spacing:3) {
                    Text(model.selectedExpansion.title)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(model.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(model.worldRunning ? "LIVE" : "LOCAL REALM")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(model.worldRunning ? Color.green : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack(spacing:12) {
'''
if old_dashboard_intro not in s:
    raise SystemExit('dashboard intro not found')
s = s.replace(old_dashboard_intro, new_dashboard_intro, 1)

old_dash_end = '''            Spacer()
        }
    }

    private var setupGuide: some View {
'''
new_dash_end = '''            Spacer(minLength: 8)
            }
            .padding(.bottom, 6)
        }
    }

    private var setupGuide: some View {
'''
if old_dash_end not in s:
    raise SystemExit('dashboard end not found')
s = s.replace(old_dash_end, new_dash_end, 1)

# Make sidebar darker/more premium without changing functional controls.
s = s.replace('                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)', '''                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.34), Color.black.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)''', 1)

p.write_text(s)

b = Path('Build.command')
bs = b.read_text()
bs = bs.replace('<string>1.5.80</string>', '<string>1.5.81</string>', 1)
bs = bs.replace('<string>1580</string>', '<string>1581</string>', 1)
b.write_text(bs)

rn = Path('RELEASE-NOTES.md')
notes = rn.read_text() if rn.exists() else ''
header = '''# v1.5.81 — Premium Header & Navigation Redesign\n\n- Replaced the duplicated app-name treatment with a single premium brand header.\n- Sidebar now uses the app/Dock icon as the visual identity without repeating the app name.\n- Added a cinematic dark-gold hero treatment with realm status and expansion context.\n- Replaced the plain expansion picker with five premium expansion cards for Vanilla, TBC, WotLK, Cataclysm and MoP.\n- Consolidated Repair / Start / Start & Play / Stop into a premium action rail.\n- Added compact version/build treatment to the sidebar footer.\n- Preserved all existing sections and server-management behavior.\n\n'''
if not notes.startswith('# v1.5.81'):
    rn.write_text(header + notes)
