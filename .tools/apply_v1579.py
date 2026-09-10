from pathlib import Path
import re

cv = Path('Sources/WoWServerControlCenter/ContentView.swift')
s = cv.read_text()

# Always expose icon reload for the current page, not only after a permanent failure.
s = s.replace('''                if !model.failedIconIDs.isEmpty {
                    Text("\\(model.failedIconIDs.count) icon(s) unavailable")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button("Retry Icons") { model.retryFailedIcons() }
                }

                Spacer()''', '''                if !model.failedIconIDs.isEmpty {
                    Text("\\(model.failedIconIDs.count) icon(s) need retry")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Button("Reload Missing Icons") { model.retryFailedIcons() }
                    .help("Retry every missing icon on the current catalog page using era-specific sources and local cache.")

                Spacer()''', 1)

# Replace tooltip sizing with deterministic line-based sizing; this avoids AppKit fittingSize clipping with ScrollView.
old_resize = '''        let width: CGFloat = 470
        host.frame = NSRect(x:0,y:0,width:width,height:2000)
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        let screenLimit = max(260, (NSScreen.main?.visibleFrame.height ?? 900) - 48)
        let height = min(max(fitting.height, 110), screenLimit)

        panel.setContentSize(NSSize(width:width,height:height))
        host.frame = NSRect(x:0,y:0,width:width,height:height)'''
new_resize = '''        let width: CGFloat = 470
        let lineCount = max(4, hostingView?.rootView.text.components(separatedBy:"\\n").count ?? 4)
        let estimated = CGFloat(lineCount * 18 + 66)
        let screenLimit = max(300, (NSScreen.main?.visibleFrame.height ?? 900) - 48)
        let height = min(max(estimated, 140), screenLimit)
        panel.setContentSize(NSSize(width:width,height:height))
        host.frame = NSRect(x:0,y:0,width:width,height:height)'''
if old_resize not in s:
    raise SystemExit('tooltip resize anchor not found')
s = s.replace(old_resize, new_resize, 1)

# Blizzard-like structured renderer: title quality color, green effects/set bonuses, red requirements, gold flavor text.
old_view = '''            Text(text)
                .font(.system(size:12,weight:.medium,design:.default))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth:.infinity,alignment:.leading)
                .fixedSize(horizontal:false,vertical:true)'''
new_view = '''            ScrollView {
                VStack(alignment:.leading,spacing:3) {
                    ForEach(Array(lines.enumerated()), id: \\.offset) { index, line in
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
            .scrollIndicators(.automatic)'''
if old_view not in s:
    raise SystemExit('tooltip text view anchor not found')
s = s.replace(old_view, new_view, 1)

insert_before = '''    private var qualityColor: Color {'''
helpers = '''    private var lines: [String] { text.components(separatedBy:"\\n") }

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
        if line.hasPrefix("\"") && line.hasSuffix("\"") { return .yellow }
        return .white
    }

'''
if insert_before not in s:
    raise SystemExit('qualityColor anchor not found')
s = s.replace(insert_before, helpers + insert_before, 1)
cv.write_text(s)

sm = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = sm.read_text()

# Remove permanent-failure gating so the retry button and later page visits can recover transient failures.
s = s.replace('''        guard !failedIconIDs.contains(itemID) else { return }

        let local=itemIconCacheRoot''', '''        let local=itemIconCacheRoot''', 1)

# Do not skip failed IDs when resolving a visible page.
s = s.replace('''            if item.iconURL == nil,
               itemIconURLs[item.id] == nil,
               !failedIconIDs.contains(item.id) {
                resolveItemIcon(itemID:item.id)
            }''', '''            if item.iconURL == nil,
               itemIconURLs[item.id] == nil,
               !iconLoadingIDs.contains(item.id) {
                resolveItemIcon(itemID:item.id)
            }''', 1)

# Replace single Wowhead XML source with a cascade of era-correct endpoints and generic fallback.
old_endpoint = '''            let endpoint: String
            switch expansion {
            case .tbc: endpoint="https://www.wowhead.com/tbc/item=\\(itemID)&xml"
            case .wotlk: endpoint="https://www.wowhead.com/wotlk/item=\\(itemID)&xml"
            default: endpoint="https://www.wowhead.com/item=\\(itemID)&xml"
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

            guard let a=xml.range(of:"<icon"),'''
new_endpoint = '''            var resolvedXML: String?
            for endpoint in Self.wowheadXMLCandidates(expansion: expansion, itemID: itemID) {
                if let candidate = Self.fetchText(endpoint, timeout: 7), candidate.contains("<item") {
                    resolvedXML = candidate
                    break
                }
            }
            guard let xml = resolvedXML else { finishFailure(); return }

            guard let a=xml.range(of:"<icon"),'''
if old_endpoint not in s:
    raise SystemExit('icon endpoint anchor not found')
s = s.replace(old_endpoint, new_endpoint, 1)

# Publish local DB tooltip immediately, then enrich it with era-correct htmlTooltip text when available.
old_publish = '''                let text=lines.joined(separator:"\\n")
                DispatchQueue.main.async { self.itemTooltipTexts[id]=text; self.tooltipLoadingIDs.remove(id); self.failedTooltipIDs.remove(id) }
            } catch {
                DispatchQueue.main.async { self.itemTooltipTexts[id]=[itemName,itemQuality,itemSubtitle,"Item ID \\(id)","Detailed local tooltip unavailable: \\(error.localizedDescription)"].joined(separator:"\\n"); self.tooltipLoadingIDs.remove(id); self.failedTooltipIDs.insert(id) }
            }'''
new_publish = '''                let localText=lines.joined(separator:"\\n")
                DispatchQueue.main.async { self.itemTooltipTexts[id]=localText }

                var enriched: String?
                for endpoint in Self.wowheadXMLCandidates(expansion: expansion, itemID: id) {
                    guard let xml=Self.fetchText(endpoint,timeout:7) else { continue }
                    if let parsed=Self.extractHTMLTooltip(xml), !parsed.isEmpty {
                        enriched=parsed
                        break
                    }
                }
                DispatchQueue.main.async {
                    if let enriched { self.itemTooltipTexts[id]=enriched }
                    self.tooltipLoadingIDs.remove(id)
                    self.failedTooltipIDs.remove(id)
                }
            } catch {
                DispatchQueue.main.async { self.itemTooltipTexts[id]=[itemName,itemQuality,itemSubtitle,"Item ID \\(id)","Detailed local tooltip unavailable: \\(error.localizedDescription)"].joined(separator:"\\n"); self.tooltipLoadingIDs.remove(id); self.failedTooltipIDs.insert(id) }
            }'''
if old_publish not in s:
    raise SystemExit('tooltip publish anchor not found')
s = s.replace(old_publish, new_publish, 1)

# Capture expansion for the hybrid resolver.
needle = '''        let expansionTitle = selectedExpansion.shortTitle
        let database = worldDatabaseName'''
replace = '''        let expansionTitle = selectedExpansion.shortTitle
        let expansion = selectedExpansion
        let database = worldDatabaseName'''
if needle not in s:
    raise SystemExit('tooltip expansion capture anchor not found')
s = s.replace(needle, replace, 1)

# Insert shared era URL cascade + synchronous fetch + htmlTooltip cleaner.
anchor = '''    func iconURL(for item: CatalogEntry) -> URL? {'''
helper = r'''    nonisolated private static func wowheadXMLCandidates(expansion: ExpansionID, itemID: Int) -> [String] {
        let base="https://www.wowhead.com"
        let era:[String]
        switch expansion {
        case .vanilla: era=["classic"]
        case .tbc: era=["tbc"]
        case .wotlk: era=["wotlk"]
        case .cataclysm: era=["cata"]
        case .mop: era=["mop-classic","mop"]
        default: era=[]
        }
        var urls=era.map { "\(base)/\($0)/item=\(itemID)&xml" }
        urls.append("\(base)/item=\(itemID)&xml")
        return urls
    }

    nonisolated private static func fetchText(_ endpoint:String, timeout:TimeInterval) -> String? {
        guard let url=URL(string:endpoint) else { return nil }
        var req=URLRequest(url:url)
        req.timeoutInterval=timeout
        req.cachePolicy=.returnCacheDataElseLoad
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) WoWServerControlCenter/1.5.79",forHTTPHeaderField:"User-Agent")
        req.setValue("application/xml,text/xml;q=0.9,text/html;q=0.8,*/*;q=0.7",forHTTPHeaderField:"Accept")
        let sem=DispatchSemaphore(value:0)
        final class Box: @unchecked Sendable { var data:Data?; var status:Int=0 }
        let box=Box()
        URLSession.shared.dataTask(with:req) { data,response,_ in
            box.data=data
            box.status=(response as? HTTPURLResponse)?.statusCode ?? 0
            sem.signal()
        }.resume()
        guard sem.wait(timeout:.now()+timeout+1) == .success,
              (200..<300).contains(box.status), let data=box.data else { return nil }
        return String(data:data,encoding:.utf8)
    }

    nonisolated private static func extractHTMLTooltip(_ xml:String) -> String? {
        guard let a=xml.range(of:"<htmlTooltip>"), let b=xml.range(of:"</htmlTooltip>",range:a.upperBound..<xml.endIndex) else { return nil }
        var html=String(xml[a.upperBound..<b.lowerBound])
        html=html.replacingOccurrences(of:"<![CDATA[",with:"").replacingOccurrences(of:"]]>",with:"")
        for br in ["<br />","<br/>","<br>","</tr>","</table>","</div>","</p>"] { html=html.replacingOccurrences(of:br,with:"\n",options:.caseInsensitive) }
        html=html.replacingOccurrences(of:"</td>",with:"    ",options:.caseInsensitive)
        html=html.replacingOccurrences(of:"</th>",with:"    ",options:.caseInsensitive)
        html=html.replacingOccurrences(of:"<[^>]+>",with:"",options:.regularExpression)
        for (e,v) in ["&nbsp;":" ","&#160;":" ","&amp;":"&","&lt;":"<","&gt;":">","&quot;":"\"","&#39;":"'"] { html=html.replacingOccurrences(of:e,with:v) }
        html=html.replacingOccurrences(of:"[ \\t]+\\n",with:"\n",options:.regularExpression)
        html=html.replacingOccurrences(of:"\\n{3,}",with:"\n\n",options:.regularExpression)
        return html.trimmingCharacters(in:.whitespacesAndNewlines)
    }

'''
if anchor not in s:
    raise SystemExit('iconURL helper anchor not found')
s = s.replace(anchor, helper + anchor, 1)

sm.write_text(s)

# Version + notes.
b = Path('Build.command')
s = b.read_text().replace('<string>1.5.78</string>','<string>1.5.79</string>',1).replace('<string>1578</string>','<string>1579</string>',1)
b.write_text(s)

rn = Path('RELEASE-NOTES.md')
old = rn.read_text()
head = '''# v1.5.79 — Blizzard-Style Tooltips + Resilient Era Icons\n\n- Reworks item hover cards into a Blizzard/WoW-style visual hierarchy with quality-colored title, green Equip/Use/Set effects, red requirements, flavor text and scroll-safe long cards.\n- Hybrid tooltip data: local realm item_template appears immediately; era-correct Wowhead XML enriches spell/set/effect text when available.\n- Adds era-specific icon lookup cascades for Vanilla, TBC, WotLK, Cataclysm and MoP plus generic fallback.\n- Missing icons are retryable instead of becoming permanently dead after one transient network failure.\n- Adds an always-visible Reload Missing Icons action and keeps persistent local icon caching.\n- Keeps the 1.5.77 TBC full-world-catalog repair and 1.5.78 Repair Realm UI.\n\n'''
if not old.startswith('# v1.5.79'):
    rn.write_text(head + old)

print('1.5.79 patch applied')
