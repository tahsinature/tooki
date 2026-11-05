import ApplicationServices
import TookiKit

/// Finds the menu item an app has assigned to a shortcut, e.g. "File › Save".
enum MenuShortcutFinder {
    private static let maxDepth = 5
    private static let maxItems = 4000

    static func menuItem(for combo: KeyCombo, in pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.3)
        guard let menuBar: AXUIElement = attribute(kAXMenuBarAttribute, of: app) else { return nil }
        var budget = maxItems
        return search(menuBar, for: combo, path: [], depth: 0, budget: &budget)
    }

    private static func search(_ element: AXUIElement, for combo: KeyCombo, path: [String], depth: Int, budget: inout Int) -> String? {
        guard depth <= maxDepth, let children: [AXUIElement] = attribute(kAXChildrenAttribute, of: element) else { return nil }
        for child in children {
            budget -= 1
            guard budget > 0 else { return nil }
            let title: String = attribute(kAXTitleAttribute, of: child) ?? ""
            let childPath = title.isEmpty ? path : path + [title]
            if matches(child, combo) { return childPath.joined(separator: " › ") }
            if let found = search(child, for: combo, path: childPath, depth: depth + 1, budget: &budget) { return found }
        }
        return nil
    }

    private static func matches(_ item: AXUIElement, _ combo: KeyCombo) -> Bool {
        guard let character: String = attribute(kAXMenuItemCmdCharAttribute, of: item), !character.isEmpty,
              let rawModifiers: Int = attribute(kAXMenuItemCmdModifiersAttribute, of: item)
        else { return false }
        return character.lowercased() == combo.key && modifiers(from: rawModifiers) == combo.modifiers
    }

    /// AX menu modifiers: 1 = shift, 2 = option, 4 = control, 8 = no command.
    private static func modifiers(from raw: Int) -> KeyCombo.Modifiers {
        var modifiers: KeyCombo.Modifiers = raw & 8 == 0 ? .command : []
        if raw & 1 != 0 { modifiers.insert(.shift) }
        if raw & 2 != 0 { modifiers.insert(.option) }
        if raw & 4 != 0 { modifiers.insert(.control) }
        return modifiers
    }

    private static func attribute<T>(_ name: String, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
