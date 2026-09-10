from pathlib import Path
import re

p=Path('Sources/WoWServerControlCenter/ContentView.swift')
s=p.read_text()

start=s.index('private enum CleanupAction: String, Identifiable {')
end=s.index('\n\nprivate struct WoWItemTooltipModifier:', start)
cleanup=s[start:end]
s=s[:start]+s[end:]

old='''    @State private var section = "Dashboard"\n    @State private var customItemID = "49623"\n    @State private var customItemCount = "1"\n    @State private var customSpellID = "72286"\n    @State private var levelTarget = "80"\n    @State private var pendingCleanup: CleanupAction?\n'''
if old not in s:
    raise SystemExit('ContentView @State block not found')
s=s.replace(old,'    @StateObject private var ui = ContentViewUIState()\n',1)

for name in ['section','customItemID','customItemCount','customSpellID','levelTarget','pendingCleanup']:
    s=s.replace('$'+name, '$ui.'+name)
    s=re.sub(r'(?<![A-Za-z0-9_.$])'+re.escape(name)+r'\b', 'ui.'+name, s)

insert_at=s.index('struct ContentView: View {')
state='''private final class ContentViewUIState: ObservableObject {\n    @Published var section = "Dashboard"\n    @Published var customItemID = "49623"\n    @Published var customItemCount = "1"\n    @Published var customSpellID = "72286"\n    @Published var levelTarget = "80"\n    @Published var pendingCleanup: CleanupAction?\n}\n\n'''
s=s[:insert_at]+cleanup+'\n\n'+state+s[insert_at:]

old_sidebar='''                            ForEach(sections, id: \\.self) { item in\n                                Button {\n                                    ui.section = item\n                                } label: {\n                                    HStack(spacing: 10) {\n                                        Image(systemName: icon(item))\n                                            .frame(width: 20)\n                                        Text(item)\n                                        Spacer()\n                                    }\n                                    .padding(.horizontal, 12)\n                                    .padding(.vertical, 9)\n                                    .contentShape(Rectangle())\n                                    .background(ui.section == item ? Color.accentColor.opacity(0.16) : Color.clear,\n                                                in: RoundedRectangle(cornerRadius: 8))\n                                }\n                                .buttonStyle(.plain)\n                            }\n'''
new_sidebar='''                            ForEach(sections, id: \\.self) { item in\n                                sidebarButton(item)\n                            }\n'''
if old_sidebar not in s:
    raise SystemExit('sidebar block not found')
s=s.replace(old_sidebar,new_sidebar,1)

anchor='''    private func statusDot(_ title: String, _ ready: Bool) -> some View {\n'''
helper='''    private func sidebarButton(_ item: String) -> some View {\n        let selected = ui.section == item\n        let symbol = icon(item)\n        return Button { ui.section = item } label: {\n            HStack(spacing: 10) {\n                Image(systemName: symbol).frame(width: 20)\n                Text(item)\n                Spacer()\n            }\n            .padding(.horizontal, 12)\n            .padding(.vertical, 9)\n            .contentShape(Rectangle())\n            .background(selected ? Color.accentColor.opacity(0.16) : Color.clear,\n                        in: RoundedRectangle(cornerRadius: 8))\n        }\n        .buttonStyle(.plain)\n    }\n\n'''
if anchor not in s:
    raise SystemExit('statusDot anchor missing')
s=s.replace(anchor,helper+anchor,1)

mod_anchor='''private struct WoWItemTooltipModifier: ViewModifier {\n'''
hover='''private final class TooltipHoverState: ObservableObject {\n    @Published var hovering = false\n}\n\n'''
s=s.replace(mod_anchor,hover+mod_anchor,1)
s=s.replace('    @State private var hovering=false\n','    @StateObject private var hoverState = TooltipHoverState()\n',1)
idx=s.index('private struct WoWItemTooltipModifier: ViewModifier {')
head,tail=s[:idx],s[idx:]
tail=tail.replace('hovering=value','hoverState.hovering=value').replace('if hovering {','if hoverState.hovering {')
s=head+tail

b=Path('Build.command')
bt=b.read_text().replace('<string>1.5.92</string>','<string>1.5.93</string>').replace('<string>1592</string>','<string>1593</string>')
b.write_text(bt)

rn=Path('RELEASE-NOTES.md')
r=rn.read_text()
r='''# v1.5.93 — macOS SDK 27 / Swift 6 UI Build Fix\n\n- Fixes local Build.command failures under macOS SDK 27 / Swift 6 where helper-view closures treated ContentView state as immutable.\n- Moves mutable ContentView helper state into a reference-backed ObservableObject.\n- Restores reliable Level field binding and cleanup/navigation mutations.\n- Splits the sidebar row into a smaller view expression to avoid Swift compiler type-check timeouts.\n- Keeps the WotLK managed MySQL 3307 self-heal from 1.5.92.\n\n'''+r
rn.write_text(r)

p.write_text(s)
