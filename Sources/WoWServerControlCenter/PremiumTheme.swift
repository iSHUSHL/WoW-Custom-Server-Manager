import SwiftUI
import AppKit

// MARK: - WoWCC Premium Dark Theme
// Presentation only: server/database/runtime behavior remains in ServerModel.

enum WoWCCTheme {
    static let accent = Color(red: 0.08, green: 0.45, blue: 0.98)
    static let accentHover = Color(red: 0.15, green: 0.51, blue: 1.00)
    static let accentSoft = accent.opacity(0.17)
    static let canvas = Color(red: 0.020, green: 0.030, blue: 0.043)
    static let sidebar = Color(red: 0.032, green: 0.045, blue: 0.061)
    static let panel = Color(red: 0.047, green: 0.064, blue: 0.083)
    static let panelStrong = Color(red: 0.058, green: 0.078, blue: 0.102)
    static let panelHover = Color(red: 0.070, green: 0.092, blue: 0.120)
    static let border = Color.white.opacity(0.105)
    static let subtleBorder = Color.white.opacity(0.060)
    static let success = Color(red: 0.25, green: 0.84, blue: 0.43)
    static let warning = Color(red: 1.00, green: 0.66, blue: 0.20)
    static let danger = Color(red: 1.00, green: 0.33, blue: 0.33)
    static let cornerRadius: CGFloat = 12
    static let compactCornerRadius: CGFloat = 8
}

struct WoWCCPremiumTheme: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .tint(WoWCCTheme.accent)
            .font(.system(.body, design: .rounded))
            .groupBoxStyle(WoWCCGroupBoxStyle())
            .controlSize(.regular)
            .background(WoWCCTheme.canvas)
            .overlay(alignment: .topLeading) {
                WindowAppearanceConfigurator()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }
    }
}

struct WoWCCGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            configuration.label
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: WoWCCTheme.cornerRadius, style: .continuous)
                .fill(WoWCCTheme.panel)
                .overlay {
                    RoundedRectangle(cornerRadius: WoWCCTheme.cornerRadius, style: .continuous)
                        .stroke(WoWCCTheme.border, lineWidth: 1)
                }
        )
    }
}

struct WoWCCPageChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .groupBoxStyle(WoWCCGroupBoxStyle())
            .controlSize(.regular)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WoWCCTheme.canvas)
    }
}

extension View {
    func wowccPremiumTheme() -> some View { modifier(WoWCCPremiumTheme()) }
    func wowccPageChrome() -> some View { modifier(WoWCCPageChrome()) }

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

    func wowccToolbar() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: WoWCCTheme.cornerRadius, style: .continuous)
                    .fill(WoWCCTheme.panelStrong)
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
    init(@ViewBuilder content: () -> Content) { self.content = content() }
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
                Text(title).font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
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
            Circle().fill(ready ? WoWCCTheme.success : Color.secondary).frame(width: 7, height: 7)
            Text(title).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(ready ? WoWCCTheme.success.opacity(0.10) : Color.white.opacity(0.045)))
        .overlay {
            Capsule(style: .continuous)
                .stroke(ready ? WoWCCTheme.success.opacity(0.26) : WoWCCTheme.subtleBorder, lineWidth: 1)
        }
    }
}

// Premium titlebar branding uses the exact app/Dock icon already embedded in
// the built .app. No duplicate artwork is added to the source tree.
private struct WoWCCWindowTitleBrand: View {
    let icon: NSImage

    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: WoWCCTheme.accent.opacity(0.28), radius: 7, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 0) {
                Text("WoW Server Control Center")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("macOS Server Manager")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

private final class WoWCCTitlebarAccessoryController: NSTitlebarAccessoryViewController {
    static let identifierString = "com.dualtonelab.wowcc.title-brand"
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
        window.backgroundColor = NSColor(calibratedRed: 0.020, green: 0.030, blue: 0.043, alpha: 1.0)
        if #available(macOS 11.0, *) { window.toolbarStyle = .unifiedCompact }

        installPremiumTitleBrand(in: window)
    }

    private func installPremiumTitleBrand(in window: NSWindow) {
        let alreadyInstalled = window.titlebarAccessoryViewControllers.contains {
            $0.view.identifier?.rawValue == WoWCCTitlebarAccessoryController.identifierString
        }
        guard !alreadyInstalled else { return }

        let controller = WoWCCTitlebarAccessoryController()
        controller.layoutAttribute = .left

        let brand = WoWCCWindowTitleBrand(icon: NSApp.applicationIconImage)
        let hostingView = NSHostingView(rootView: brand)
        hostingView.identifier = NSUserInterfaceItemIdentifier(WoWCCTitlebarAccessoryController.identifierString)
        hostingView.frame = NSRect(x: 0, y: 0, width: 235, height: 38)
        controller.view = hostingView

        window.addTitlebarAccessoryViewController(controller)
    }
}
