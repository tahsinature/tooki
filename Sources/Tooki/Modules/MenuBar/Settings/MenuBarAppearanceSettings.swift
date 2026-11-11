import AppKit
import SwiftUI
import TookiKit

/// The divider's look and the menu bar tint.
struct MenuBarAppearanceSettings: View {
    @Binding var menuBar: MenuBarConfig

    var body: some View {
        SettingsSection("Appearance") {
            SettingsRow("Divider") {
                Picker("Divider", selection: $menuBar.dividerStyle) {
                    Text("Line").tag(MenuBarDividerStyle.line)
                    Text("Chevron").tag(MenuBarDividerStyle.chevron)
                    Text("Invisible").tag(MenuBarDividerStyle.invisible)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            SettingsToggleRow("Tint the menu bar", isOn: $menuBar.tint.enabled)
            if menuBar.tint.enabled {
                SettingsRow("Tint color") {
                    ColorPicker("Tint color", selection: tintColor, supportsOpacity: false)
                        .labelsHidden()
                }
                SettingsRow("Strength") {
                    Slider(value: $menuBar.tint.opacity, in: 0.05...0.8)
                        .frame(width: 200)
                }
            }
        }
    }

    private var tintColor: Binding<Color> {
        Binding {
            let rgb = RGBColor(hex: menuBar.tint.color) ?? RGBColor(red: 0, green: 0, blue: 0)
            return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
        } set: { color in
            guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            menuBar.tint.color = RGBColor(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent).hex
        }
    }
}
