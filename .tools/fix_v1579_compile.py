from pathlib import Path

cv=Path('Sources/WoWServerControlCenter/ContentView.swift')
s=cv.read_text()
s=s.replace('if line.hasPrefix("\"\"") && line.hasSuffix("\"\"") { return .yellow }','if line.first == "\\\"" && line.last == "\\\"" { return .yellow }')
cv.write_text(s)

sm=Path('Sources/WoWServerControlCenter/ServerModel.swift')
s=sm.read_text().replace('req.cachePolicy=.returnCacheDataElseLoad','req.cachePolicy = .returnCacheDataElseLoad')
sm.write_text(s)
print('1.5.79 compile fixes applied')
