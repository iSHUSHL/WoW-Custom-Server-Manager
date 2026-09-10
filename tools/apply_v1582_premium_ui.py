from pathlib import Path

p = Path('Sources/WoWServerControlCenter/ContentView.swift')
s = p.read_text()

# Sidebar: larger premium logo block and cleaner navigation width.
s = s.replace('.frame(width: 108, height: 108)', '.frame(width: 126, height: 126)', 1)
s = s.replace('.frame(width: 94, height: 94)', '.frame(width: 110, height: 110)', 1)
s = s.replace('.frame(width: 78, height: 78)', '.frame(width: 92, height: 92)', 1)
s = s.replace('.navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)', '.navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 252)', 1)

old_header = '''    private var topBar: some View {
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
'''

new_header = '''    private var topBar: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red:0.025, green:0.055, blue:0.10),
                                Color(red:0.035, green:0.085, blue:0.14),
                                Color(red:0.10, green:0.060, blue:0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Layered light gives the header the cinematic depth from the approved mockup.
                RadialGradient(
                    colors: [Color.blue.opacity(0.18), .clear],
                    center: .leading,
                    startRadius: 0,
                    endRadius: 420
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                LinearGradient(
                    colors: [.clear, Color.orange.opacity(0.10)],
                    startPoint: .center,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red:0.95,green:0.72,blue:0.20).opacity(0.82), Color.white.opacity(0.09), Color(red:0.95,green:0.72,blue:0.20).opacity(0.34)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.2
                    )

                HStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.48)).frame(width: 90,height:90)
                        Circle().stroke(Color(red:0.95,green:0.72,blue:0.20).opacity(0.68),lineWidth:1.3).frame(width:86,height:86)
                        Image(nsImage:NSApp.applicationIconImage)
                            .resizable().scaledToFit().frame(width:70,height:70)
                            .shadow(color:Color.black.opacity(0.75),radius:11,y:5)
                    }

                    VStack(alignment:.leading,spacing:4) {
                        Text("WORLD OF WARCRAFT")
                            .font(.system(size:12,weight:.black,design:.serif))
                            .tracking(4.2)
                            .foregroundStyle(Color(red:0.96,green:0.76,blue:0.25))
                        Text("SERVER CONTROL CENTER")
                            .font(.system(size:28,weight:.bold,design:.serif))
                            .tracking(1.25)
                            .foregroundStyle(
                                LinearGradient(colors:[.white,Color(red:1.0,green:0.86,blue:0.52)],startPoint:.top,endPoint:.bottom)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text("CREATE  •  MANAGE  •  EXPLORE  •  CUSTOMIZE")
                            .font(.system(size:10,weight:.semibold,design:.rounded))
                            .tracking(1.8)
                            .foregroundStyle(Color.white.opacity(0.58))
                    }

                    Spacer(minLength:20)

                    VStack(alignment:.trailing,spacing:6) {
                        Text(model.selectedExpansion.title)
                            .font(.system(size:15,weight:.bold,design:.rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing:7) {
                            Circle().fill(model.worldRunning ? Color.green : Color.orange).frame(width:7,height:7)
                            Text(model.worldRunning ? "REALM ONLINE" : (model.realmDatabaseReady ? "READY TO START" : "SETUP REQUIRED"))
                                .font(.system(size:10,weight:.black,design:.rounded))
                                .tracking(1.35)
                        }
                        .foregroundStyle(model.worldRunning ? Color.green : Color.orange)
                    }
                }
                .padding(.horizontal,22)
                .padding(.vertical,18)
            }
            .frame(minHeight:126)
            .shadow(color:Color.black.opacity(0.46),radius:18,y:8)

            expansionStrip

            HStack(spacing:12) {
                HStack(spacing:8) {
                    Circle().fill(model.realmDatabaseReady ? Color.green : Color.orange).frame(width:8,height:8)
                    Text(model.realmDatabaseReady ? "Realm Ready" : "Realm Needs Setup")
                        .font(.system(size:13,weight:.bold,design:.rounded))
                        .foregroundStyle(.white)
                    maturityBadge(model.selectedExpansion.maturity)
                }

                Spacer(minLength:14)

                premiumActionButton("Repair Realm", symbol:"wrench.and.screwdriver.fill", tint:Color(red:0.76,green:0.58,blue:0.20), disabled:model.operationActive || !model.mysqlRuntimeInstalled) {
                    model.setupSelectedProfile()
                }
                premiumActionButton("Start Realm", symbol:"play.fill", tint:Color(red:0.12,green:0.62,blue:0.28)) {
                    model.startAll()
                }
                premiumActionButton("Start & Play", symbol:"gamecontroller.fill", tint:Color(red:0.08,green:0.43,blue:0.88)) {
                    model.play()
                }
                premiumActionButton("Stop Realm", symbol:"stop.fill", tint:Color(red:0.68,green:0.16,blue:0.16)) {
                    model.stopAll()
                }
            }
            .padding(.horizontal,14)
            .padding(.vertical,12)
            .background(Color(red:0.075,green:0.070,blue:0.065).opacity(0.96), in: RoundedRectangle(cornerRadius:14,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:14,style:.continuous).stroke(Color(red:0.95,green:0.72,blue:0.20).opacity(0.22),lineWidth:1))
        }
    }

    private func premiumActionButton(_ title:String, symbol:String, tint:Color, disabled:Bool = false, action:@escaping () -> Void) -> some View {
        Button(action:action) {
            Label(title,systemImage:symbol)
                .font(.system(size:13,weight:.bold,design:.rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal,16)
                .frame(minWidth:126,minHeight:40)
                .background(
                    LinearGradient(colors:[tint.opacity(disabled ? 0.20 : 0.92),tint.opacity(disabled ? 0.12 : 0.62)],startPoint:.top,endPoint:.bottom),
                    in:RoundedRectangle(cornerRadius:9,style:.continuous)
                )
                .overlay(RoundedRectangle(cornerRadius:9,style:.continuous).stroke(Color.white.opacity(disabled ? 0.05 : 0.22),lineWidth:1))
                .shadow(color:disabled ? .clear : tint.opacity(0.26),radius:7,y:3)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.48 : 1)
    }
'''

if old_header not in s:
    raise SystemExit('topBar block not found')
s = s.replace(old_header, new_header, 1)

start = s.index('    private var expansionStrip: some View {')
end = s.index('    private func expansionAccent', start)
old_strip = s[start:end]
new_strip = '''    private var expansionStrip: some View {
        let premiumExpansions: [ExpansionID] = [.vanilla, .tbc, .wotlk, .cataclysm, .mop]
        return HStack(spacing:10) {
            ForEach(premiumExpansions) { expansion in
                Button {
                    model.selectedExpansion = expansion
                } label: {
                    HStack(spacing:10) {
                        ZStack {
                            RoundedRectangle(cornerRadius:9,style:.continuous)
                                .fill(expansionAccent(expansion).opacity(model.selectedExpansion == expansion ? 0.24 : 0.10))
                                .frame(width:40,height:40)
                            Image(systemName:expansionSymbol(expansion))
                                .font(.system(size:17,weight:.bold))
                                .foregroundStyle(expansionAccent(expansion))
                        }
                        VStack(alignment:.leading,spacing:2) {
                            Text(expansionPremiumName(expansion))
                                .font(.system(size:12,weight:.bold,design:.rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Text(expansionVersion(expansion))
                                .font(.system(size:10,weight:.semibold,design:.monospaced))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                        Spacer(minLength:2)
                    }
                    .padding(.horizontal,11)
                    .frame(maxWidth:.infinity,minHeight:62)
                    .background(
                        LinearGradient(
                            colors:model.selectedExpansion == expansion
                                ? [expansionAccent(expansion).opacity(0.18),Color(red:0.035,green:0.055,blue:0.075)]
                                : [Color(red:0.045,green:0.052,blue:0.064),Color(red:0.025,green:0.030,blue:0.038)],
                            startPoint:.topLeading,endPoint:.bottomTrailing
                        ),
                        in:RoundedRectangle(cornerRadius:12,style:.continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius:12,style:.continuous)
                            .stroke(model.selectedExpansion == expansion ? expansionAccent(expansion).opacity(0.92) : Color.white.opacity(0.10),lineWidth:model.selectedExpansion == expansion ? 1.5 : 1)
                    )
                    .shadow(color:model.selectedExpansion == expansion ? expansionAccent(expansion).opacity(0.28) : .clear,radius:9,y:2)
                }
                .buttonStyle(.plain)
                .frame(maxWidth:.infinity)
            }
        }
    }

    private func expansionPremiumName(_ expansion:ExpansionID) -> String {
        switch expansion {
        case .vanilla: return "Vanilla"
        case .tbc: return "The Burning Crusade"
        case .wotlk: return "Wrath of the Lich King"
        case .cataclysm: return "Cataclysm"
        case .mop: return "Mists of Pandaria"
        default: return expansion.shortTitle
        }
    }

'''
s = s[:start] + new_strip + s[end:]

# Improve selected nav row and overall detail background depth.
s = s.replace('section == item ? Color.accentColor.opacity(0.16) : Color.clear', 'section == item ? Color(red:0.08,green:0.20,blue:0.38).opacity(0.78) : Color.clear', 1)
s = s.replace('.frame(minWidth: 960, minHeight: 600)', '.frame(minWidth: 1180, minHeight: 720)', 1)

# Version bump.
b = Path('Build.command')
bs = b.read_text().replace('<string>1.5.81</string>', '<string>1.5.82</string>', 1).replace('<string>1581</string>', '<string>1582</string>', 1)
b.write_text(bs)
s = s.replace('Text("v1.5.81")', 'Text("v1.5.82")', 1).replace('Text("Build 1581")', 'Text("Build 1582")', 1)
p.write_text(s)

rn = Path('RELEASE-NOTES.md')
notes = rn.read_text() if rn.exists() else ''
header = '''# v1.5.82 — Premium UI Rebuild\n\n- Rebuilt the premium header after visual review of the 1.5.81 screenshot.\n- Restricts the hero expansion selector to exactly the five supported eras so cards never collapse into ellipses.\n- Replaced low-contrast standard macOS action buttons with high-contrast custom premium controls.\n- Larger cinematic brand header, stronger gold framing, richer depth and readable status presentation.\n- Larger sidebar logo and cleaner navigation proportions.\n- Increased minimum app window size so the premium layout has enough room to render correctly.\n\n'''
if not notes.startswith('# v1.5.82'):
    rn.write_text(header + notes)
