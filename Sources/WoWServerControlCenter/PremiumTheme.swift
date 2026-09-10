import SwiftUI
import AppKit

// MARK: - WoWCC Premium Dark Theme
// Centralized visual system for the macOS app. This intentionally keeps all
// server/database logic untouched and only controls presentation.

enum WoWCCTheme {
    static let accent = Color(red: 0.10, green: 0.46, blue: 0.98)
    static let accentSoft = accent.opacity(0.16)
    static let panel = Color.white.opacity(0.055)
    static let panelStrong = Color.white.opacity(0.085)
    static let border = Color.white.opacity(0.10)
    static let subtleBorder = Color.white.opacity(0.065)
    static let sidebar = Color(red: 0.045, green: 0.060, blue: 0.078)
    static let canvas = Color(red: 0.025, green: 0.035, blue: 0.048)
    static let success = Color(red: 0.24, green: 0.82, blue: 0.42)
    static let warning = Color(red: 1.00, green: 0.66, blue: 0.20)

    static let cornerRadius: CGFloat = 12
    static let compactCornerRadius: CGFloat = 8
}

struct WoWCCPremiumTheme: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .tint(WoWCCTheme.accent)
            .font(.system(.body, design: .rounded))
            .background(WoWCCTheme.canvas)
            .overlay(alignment: .topLeading) {
                WindowAppearanceConfigurator()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func wowccPremiumTheme() -> some View {
        modifier(WoWCCPremiumTheme())
    }

    func wowccPanel(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: WoWCCTheme.cornerRadius, style: .continuous)
                    .fill(WoWCCTheme.panel)
                    .overlay {
                        RoundedRectangle(cornerRadius: WoWCCTheme.cornerRadius, style: .continuous)
                            .stroke(WoWCCTheme.border, lineWidth: 1)
                    }
            )
    }

    func wowccSelectedRow(_ selected: Bool) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: WoWCCTheme.compactCornerRadius, style: .continuous)
                    .fill(selected ? WoWCCTheme.accent : Color.clear)
            )
            .foregroundStyle(selected ? Color.white : Color.primary)
    }
}

struct WoWCCPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .wowccPanel()
    }
}

struct WoWCCSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WoWCCTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct WoWCCStatusPill: View {
    let title: String
    let ready: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ready ? WoWCCTheme.success : Color.secondary)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(ready ? WoWCCTheme.success.opacity(0.10) : Color.white.opacity(0.045))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(ready ? WoWCCTheme.success.opacity(0.26) : WoWCCTheme.subtleBorder, lineWidth: 1)
        }
    }
}

private struct WindowAppearanceConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }

        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(
            calibratedRed: 0.025,
            green: 0.035,
            blue: 0.048,
            alpha: 1.0
        )

        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unifiedCompact
        }
    }
}
