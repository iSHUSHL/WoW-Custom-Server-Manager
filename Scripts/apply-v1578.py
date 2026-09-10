from pathlib import Path
import re

cv = Path('Sources/WoWServerControlCenter/ContentView.swift')
s = cv.read_text()

old_top = '''            Button { model.startAll() } label:{ Label("Start",systemImage:"play.fill") }.buttonStyle(.borderedProminent)
            Button { model.play() } label:{ Label("Start & Play",systemImage:"gamecontroller.fill") }.buttonStyle(.borderedProminent)
            Button("Stop") { model.stopAll() }'''
new_top = '''            Button { model.setupSelectedProfile() } label:{ Label("Repair Realm",systemImage:"wrench.and.screwdriver.fill") }
                .buttonStyle(.bordered)
                .disabled(model.operationActive || !model.mysqlRuntimeInstalled)
                .help("Initialize or repair the selected realm database. TBC also validates and repairs the full world item catalog.")
            Button { model.startAll() } label:{ Label("Start",systemImage:"play.fill") }.buttonStyle(.borderedProminent)
            Button { model.play() } label:{ Label("Start & Play",systemImage:"gamecontroller.fill") }.buttonStyle(.borderedProminent)
            Button("Stop") { model.stopAll() }'''
if old_top not in s:
    raise SystemExit('topBar anchor not found')
s = s.replace(old_top, new_top, 1)

old_done = '''                        if number == 3 && model.selectedExpansion.maturity != .experimental {
                            Button(model.selectedExpansion == .tbc ? "Rebuild / Apply Patches" : "Repair / Rebuild Core", action: action)
                                .buttonStyle(.borderedProminent)
                                .disabled(model.operationActive)
                        }'''
new_done = '''                        if number == 3 && model.selectedExpansion.maturity != .experimental {
                            Button(model.selectedExpansion == .tbc ? "Rebuild / Apply Patches" : "Repair / Rebuild Core", action: action)
                                .buttonStyle(.borderedProminent)
                                .disabled(model.operationActive)
                        }
                        if number == 6 {
                            Button("Repair Realm", action: action)
                                .buttonStyle(.borderedProminent)
                                .disabled(model.operationActive || !model.mysqlRuntimeInstalled)
                                .help("Run realm database validation and repair again even when the Realm DB status is already green.")
                        }'''
if old_done not in s:
    raise SystemExit('setupStep done anchor not found')
s = s.replace(old_done, new_done, 1)

s = s.replace('contentRect:NSRect(x:0,y:0,width:390,height:220)', 'contentRect:NSRect(x:0,y:0,width:470,height:260)', 1)
old_resize = '''        // Width stays WoW-like and readable; height adapts to long item/set text.
        let width: CGFloat = 390
        let fitting = host.fittingSize
        let height = min(max(fitting.height, 80), 620)

        panel.setContentSize(NSSize(width:width,height:height))
        host.frame = NSRect(x:0,y:0,width:width,height:height)'''
new_resize = '''        let width: CGFloat = 470
        host.frame = NSRect(x:0,y:0,width:width,height:2000)
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        let screenLimit = max(260, (NSScreen.main?.visibleFrame.height ?? 900) - 48)
        let height = min(max(fitting.height, 110), screenLimit)

        panel.setContentSize(NSSize(width:width,height:height))
        host.frame = NSRect(x:0,y:0,width:width,height:height)'''
if old_resize not in s:
    raise SystemExit('tooltip resize anchor not found')
s = s.replace(old_resize, new_resize, 1)
old_scroll = '''            ScrollView {
                Text(text)
                    .font(.system(size:12,weight:.medium))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .fixedSize(horizontal:false,vertical:true)
            }
            .scrollIndicators(.automatic)'''
new_scroll = '''            Text(text)
                .font(.system(size:12,weight:.medium,design:.default))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth:.infinity,alignment:.leading)
                .fixedSize(horizontal:false,vertical:true)'''
if old_scroll not in s:
    raise SystemExit('tooltip view anchor not found')
s = s.replace(old_scroll, new_scroll, 1)
s = s.replace('.frame(width:390,alignment:.leading)', '.frame(width:470,alignment:.leading)', 1)
s = s.replace('.onChange(of:text) { _ in', '.onChange(of:text) { _, _ in')
s = s.replace('.onChange(of:loading) { _ in', '.onChange(of:loading) { _, _ in')
cv.write_text(s)

sm = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = sm.read_text()
pattern = re.compile(r'    func resolveTooltip\(for item: CatalogEntry\) \{.*?\n    \}\n\n    func iconURL\(for item: CatalogEntry\) -> URL\? \{', re.S)
replacement = '''    func resolveTooltip(for item: CatalogEntry) {
        let id = item.id
        guard id > 0 else { return }
        guard itemTooltipTexts[id] == nil else { return }
        guard !tooltipLoadingIDs.contains(id) else { return }
        guard !failedTooltipIDs.contains(id) else { return }

        tooltipLoadingIDs.insert(id)
        let itemName = item.name
        let itemQuality = item.quality
        let itemSubtitle = item.subtitle
        let itemLevel = item.itemLevel
        let itemSetID = item.itemSetID
        let expansionTitle = selectedExpansion.shortTitle
        let database = worldDatabaseName
        let port = mysqlPort
        guard let mysqlExecutable = locateMySQL("mysql") else {
            tooltipLoadingIDs.remove(id)
            itemTooltipTexts[id] = basicTooltip(for:item)
            return
        }

        tooltipQueue.addOperation {
            do {
                let client = DatabaseClient(executable: mysqlExecutable, port: port)
                let columnRaw = try client.query(database: database, sql: "SHOW COLUMNS FROM item_template;")
                let columns = columnRaw.split(separator:"\\n").compactMap { line -> String? in
                    let parts = line.split(separator:"\\t", omittingEmptySubsequences:false)
                    return parts.first.map(String.init)
                }
                let rowRaw = try client.query(database: database, sql: "SELECT * FROM item_template WHERE entry=\\(id) LIMIT 1;")
                guard let firstRow = rowRaw.split(separator:"\\n", omittingEmptySubsequences:false).first else {
                    throw NSError(domain:"WoWCC.Tooltip", code:1, userInfo:[NSLocalizedDescriptionKey:"Item row not found"])
                }
                let values = firstRow.split(separator:"\\t", omittingEmptySubsequences:false).map(String.init)
                var fields: [String:String] = [:]
                for (index, name) in columns.enumerated() where index < values.count { fields[name.lowercased()] = values[index] }

                func value(_ names: String...) -> String? {
                    for name in names { if let raw=fields[name.lowercased()], !raw.isEmpty, raw != "NULL" { return raw } }
                    return nil
                }
                func intValue(_ names: String...) -> Int {
                    for name in names { if let raw=fields[name.lowercased()], let n=Int(raw) { return n } }
                    return 0
                }
                func doubleValue(_ names: String...) -> Double {
                    for name in names { if let raw=fields[name.lowercased()], let n=Double(raw) { return n } }
                    return 0
                }
                func qualityName(_ q:Int)->String { switch q { case 0:return "Poor"; case 1:return "Common"; case 2:return "Uncommon"; case 3:return "Rare"; case 4:return "Epic"; case 5:return "Legendary"; case 6:return "Artifact"; case 7:return "Heirloom"; default:return itemQuality } }
                func slotName(_ n:Int)->String { [1:"Head",2:"Neck",3:"Shoulder",4:"Shirt",5:"Chest",6:"Waist",7:"Legs",8:"Feet",9:"Wrist",10:"Hands",11:"Finger",12:"Trinket",13:"One-Hand",14:"Shield",15:"Ranged",16:"Back",17:"Two-Hand",18:"Bag",19:"Tabard",20:"Robe",21:"Main Hand",22:"Off Hand",23:"Held In Off-hand",24:"Ammo",25:"Thrown",26:"Ranged",28:"Relic"][n] ?? "Inventory Type \\(n)" }
                func statName(_ n:Int)->String { [0:"Mana",1:"Health",3:"Agility",4:"Strength",5:"Intellect",6:"Spirit",7:"Stamina",12:"Defense Rating",13:"Dodge Rating",14:"Parry Rating",15:"Block Rating",16:"Melee Hit Rating",17:"Ranged Hit Rating",18:"Spell Hit Rating",19:"Melee Crit Rating",20:"Ranged Crit Rating",21:"Spell Crit Rating",31:"Hit Rating",32:"Crit Rating",35:"Resilience Rating",36:"Haste Rating",37:"Expertise Rating",38:"Attack Power",39:"Ranged Attack Power",43:"Mana per 5 sec",45:"Spell Power"][n] ?? "Stat \\(n)" }
                func bindingName(_ n:Int)->String? { switch n { case 1:return "Binds when picked up"; case 2:return "Binds when equipped"; case 3:return "Binds when used"; case 4,5:return "Quest Item"; default:return nil } }
                func triggerName(_ n:Int)->String { switch n { case 0:return "Use"; case 1:return "Equip"; case 2:return "Chance on hit"; case 4:return "Soulstone"; case 5:return "Use"; case 6:return "Learn"; default:return "Effect" } }
                func money(_ copper:Int)->String { let g=copper/10000, s=(copper%10000)/100, c=copper%100; var p:[String]=[]; if g>0{p.append("\\(g)g")}; if s>0{p.append("\\(s)s")}; if c>0||p.isEmpty{p.append("\\(c)c")}; return p.joined(separator:" ") }

                let q=intValue("quality"), ilvl=intValue("itemlevel"), reqLevel=intValue("requiredlevel"), inv=intValue("inventorytype")
                var lines:[String]=[]
                lines.append(value("name") ?? itemName)
                lines.append("\\(qualityName(q)) • \\(expansionTitle) • Item #\\(id)")
                lines.append("Item Level \\(ilvl > 0 ? ilvl : (itemLevel ?? 0))")
                if let binding=bindingName(intValue("bonding")){lines.append(binding)}
                if inv>0{lines.append(slotName(inv))}
                if reqLevel>0{lines.append("Requires Level \\(reqLevel)")}
                let reqSkill=intValue("requiredskill"), reqRank=intValue("requiredskillrank")
                if reqSkill>0{lines.append(reqRank>0 ? "Requires Skill #\\(reqSkill) (\\(reqRank))" : "Requires Skill #\\(reqSkill)")}
                let reqSpell=intValue("requiredspell"); if reqSpell>0{lines.append("Requires Spell #\\(reqSpell)")}
                let reqFaction=intValue("requiredreputationfaction"), reqRep=intValue("requiredreputationrank"); if reqFaction>0{lines.append("Requires Reputation: faction #\\(reqFaction), rank \\(reqRep)")}
                let armor=intValue("armor"); if armor>0{lines.append("\\(armor) Armor")}
                let block=intValue("block"); if block>0{lines.append("\\(block) Block")}
                let min1=doubleValue("dmg_min1"), max1=doubleValue("dmg_max1"), delay=intValue("delay")
                if max1>0{ let speed=delay>0 ? Double(delay)/1000.0:0; lines.append(String(format:"%.1f - %.1f Damage",min1,max1)+(speed>0 ? String(format:" • Speed %.2f",speed):"")); if speed>0{lines.append(String(format:"(%.1f damage per second)",((min1+max1)/2.0)/speed))} }
                let min2=doubleValue("dmg_min2"), max2=doubleValue("dmg_max2"); if max2>0{lines.append(String(format:"%.1f - %.1f Additional Damage",min2,max2))}
                for i in 1...10 { let t=intValue("stat_type\\(i)"), a=intValue("stat_value\\(i)"); if a != 0 { lines.append("\\(a > 0 ? "+" : "")\\(a) \\(statName(t))") } }
                for (key,label) in [("holy_res","Holy"),("fire_res","Fire"),("nature_res","Nature"),("frost_res","Frost"),("shadow_res","Shadow"),("arcane_res","Arcane")] { let n=intValue(key); if n != 0{lines.append("+\\(n) \\(label) Resistance")} }
                for i in 1...5 { let spell=intValue("spellid_\\(i)","spellid\\(i)"); if spell>0{lines.append("\\(triggerName(intValue(\"spelltrigger_\\(i)\",\"spelltrigger\\(i)\"))): Spell #\\(spell)")} }
                for i in 1...3 { let color=intValue("socketcolor_\\(i)","socketcolor\\(i)"), content=intValue("socketcontent_\\(i)","socketcontent\\(i)"); if color>0 || content>0{lines.append("Socket \\(i): color \\(color)"+(content>0 ? ", gem #\\(content)":""))} }
                let socketBonus=intValue("socketbonus"); if socketBonus>0{lines.append("Socket Bonus: spell #\\(socketBonus)")}
                let durability=intValue("maxdurability"); if durability>0{lines.append("Durability \\(durability) / \\(durability)")}
                let setID=intValue("itemset"); if setID>0{lines.append("Item Set #\\(setID)")} else if let itemSetID{lines.append("Item Set #\\(itemSetID)")}
                let stack=intValue("stackable"); if stack>1{lines.append("Max Stack: \\(stack)")}
                let sell=intValue("sellprice"); if sell>0{lines.append("Sell Price: \\(money(sell))")}
                if let desc=value("description"), !desc.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{lines.append("");lines.append("\\\"\\(desc)\\\"")}
                if !itemSubtitle.isEmpty{lines.append("");lines.append(itemSubtitle)}
                let text=lines.joined(separator:"\\n")
                DispatchQueue.main.async { self.itemTooltipTexts[id]=text; self.tooltipLoadingIDs.remove(id); self.failedTooltipIDs.remove(id) }
            } catch {
                DispatchQueue.main.async { self.itemTooltipTexts[id]=[itemName,itemQuality,itemSubtitle,"Item ID \\(id)","Detailed local tooltip unavailable: \\(error.localizedDescription)"].joined(separator:"\\n"); self.tooltipLoadingIDs.remove(id); self.failedTooltipIDs.insert(id) }
            }
        }
    }

    func iconURL(for item: CatalogEntry) -> URL? {'''
s2, count = pattern.subn(lambda m: replacement, s, count=1)
if count != 1:
    raise SystemExit(f'resolveTooltip replacement count={count}')
sm.write_text(s2)

build=Path('Build.command')
b=build.read_text().replace('1.5.77','1.5.78').replace('<string>1577</string>','<string>1578</string>')
build.write_text(b)
notes=Path('RELEASE-NOTES.md')
old=notes.read_text()
notes.write_text('# v1.5.78 — Full Tooltips + Visible Realm Repair\n\n- Permanent Repair Realm button in the top bar.\n- Repair Realm remains available after Setup step 6 is Done.\n- Collection tooltips now read detailed fields directly from the selected realm item_template database.\n- Tooltip panel widened and auto-sized so long item details are not clipped.\n- Preserves 1.5.77 TBC full-world-catalog validation and repair.\n\n'+old)
print('1.5.78 patch applied')
