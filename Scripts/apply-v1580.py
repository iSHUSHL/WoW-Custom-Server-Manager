from pathlib import Path

p = Path('Sources/WoWServerControlCenter/ContentView.swift')
s = p.read_text()

old_resize = '''    private func resizeToContent() {
        guard let host=hostingView, let panel else { return }

        let width: CGFloat = 470
        let lineCount = max(4, hostingView?.rootView.text.components(separatedBy:"\\n").count ?? 4)
        let estimated = CGFloat(lineCount * 18 + 66)
        let screenLimit = max(300, (NSScreen.main?.visibleFrame.height ?? 900) - 48)
        let height = min(max(estimated, 140), screenLimit)
        panel.setContentSize(NSSize(width:width,height:height))
        host.frame = NSRect(x:0,y:0,width:width,height:height)
    }
'''

new_resize = '''    private func resizeToContent() {
        guard let host=hostingView, let panel else { return }

        // Measure the real wrapped SwiftUI content instead of guessing from
        // newline count. The tooltip stays visual-only and does not need a
        // dead ScrollView just to reveal wrapped lines.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation,$0.frame,false) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
        let maxHeight = max(320, visible.height - 32)
        let maxWidth = max(470, min(700, visible.width - 32))

        let requestedWidths: [CGFloat] = [500, 540, 580, 620, 660, 700]
        var widths: [CGFloat] = []
        for candidate in requestedWidths {
            let width = min(candidate, maxWidth)
            if width >= 470 && !widths.contains(width) { widths.append(width) }
        }
        if widths.isEmpty { widths = [maxWidth] }

        var chosenWidth = widths[0]
        var chosenHeight = maxHeight

        for width in widths {
            host.frame = NSRect(x:0,y:0,width:width,height:10_000)
            host.layoutSubtreeIfNeeded()
            let measuredHeight = max(120, ceil(host.fittingSize.height))
            chosenWidth = width
            chosenHeight = measuredHeight
            if measuredHeight <= maxHeight { break }
        }

        // Blizzard tooltips should normally show the whole card at once.
        // Widening is attempted before this final display-safety clamp.
        chosenHeight = min(chosenHeight, maxHeight)
        panel.setContentSize(NSSize(width:chosenWidth,height:chosenHeight))
        host.frame = NSRect(x:0,y:0,width:chosenWidth,height:chosenHeight)
        host.layoutSubtreeIfNeeded()
    }
'''
if old_resize not in s:
    raise SystemExit('resizeToContent block not found')
s = s.replace(old_resize, new_resize, 1)

old_body = '''            ScrollView {
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
            .scrollIndicators(.automatic)
'''
new_body = '''            VStack(alignment:.leading,spacing:3) {
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
'''
if old_body not in s:
    raise SystemExit('tooltip ScrollView block not found')
s = s.replace(old_body, new_body, 1)

old_frame = '.frame(width:470,alignment:.leading)\n        .background('
new_frame = '.frame(minWidth:470,maxWidth:.infinity,alignment:.leading)\n        .background('
if old_frame not in s:
    raise SystemExit('tooltip fixed width frame not found')
s = s.replace(old_frame, new_frame, 1)
p.write_text(s)

b = Path('Build.command')
bs = b.read_text()
if '<string>1.5.79</string>' not in bs or '<string>1579</string>' not in bs:
    raise SystemExit('expected 1.5.79 version markers not found')
bs = bs.replace('<string>1.5.79</string>', '<string>1.5.80</string>', 1)
bs = bs.replace('<string>1579</string>', '<string>1580</string>', 1)
b.write_text(bs)

rn = Path('RELEASE-NOTES.md')
notes = rn.read_text() if rn.exists() else ''
header = '''# v1.5.80 — Tooltip Auto-Fit

- Removed the unusable tooltip ScrollView/scrollbar from the mouse-transparent floating panel.
- Tooltip height now uses real SwiftUI wrapped-content measurement instead of newline estimation.
- Tooltip progressively widens up to the available display width so long Blizzard-style details fit without clipping.
- Tooltip remains mouse-transparent so Give and other controls remain clickable.

'''
if not notes.startswith('# v1.5.80'):
    rn.write_text(header + notes)
