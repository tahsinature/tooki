import Foundation

/// Ingredient conversions between volume and weight using a density table:
/// `1 tablespoon of honey in grams`, `250 g of flour in cups`.
enum CookingConversion {
    private struct VolumeUnit {
        let milliliters: Double, singular: String, plural: String
    }

    private struct WeightUnit {
        let grams: Double, label: String
    }

    private static let pattern = RegexPattern(#"(?i)^(\d+(?:\.\d+)?)\s*([a-z]+)\s+of\s+([a-z][a-z\- ]*?)\s+(?:in|to|as)\s+([a-z]+)$"#)

    private static let volumeUnits: [String: VolumeUnit] = expand([
        (["tsp", "teaspoon", "teaspoons"], VolumeUnit(milliliters: 4.92892, singular: "tsp", plural: "tsp")),
        (["tbsp", "tablespoon", "tablespoons"], VolumeUnit(milliliters: 14.7868, singular: "tbsp", plural: "tbsp")),
        (["cup", "cups"], VolumeUnit(milliliters: 236.588, singular: "cup", plural: "cups")),
        (["ml", "milliliter", "milliliters", "millilitre", "millilitres"], VolumeUnit(milliliters: 1, singular: "ml", plural: "ml")),
        (["l", "liter", "liters", "litre", "litres"], VolumeUnit(milliliters: 1000, singular: "l", plural: "l")),
    ])

    private static let weightUnits: [String: WeightUnit] = expand([
        (["g", "gram", "grams"], WeightUnit(grams: 1, label: "g")),
        (["kg", "kilogram", "kilograms"], WeightUnit(grams: 1000, label: "kg")),
        (["oz", "ounce", "ounces"], WeightUnit(grams: 28.3495, label: "oz")),
        (["lb", "lbs", "pound", "pounds"], WeightUnit(grams: 453.592, label: "lb")),
    ])

    /// Common kitchen ingredient densities in g/ml.
    private static let densities: [String: Double] = expand([
        (["water"], 1.0),
        (["milk"], 1.03),
        (["honey"], 1.42),
        (["flour", "all purpose flour", "all-purpose flour", "plain flour"], 0.5283),
        (["sugar", "granulated sugar"], 0.8454),
        (["brown sugar"], 0.93),
        (["powdered sugar", "icing sugar"], 0.56),
        (["butter"], 0.9586),
        (["oil", "olive oil", "vegetable oil", "sunflower oil"], 0.92),
        (["rice"], 0.85),
        (["salt"], 1.217),
        (["cocoa", "cocoa powder"], 0.52),
        (["oats", "rolled oats"], 0.41),
        (["syrup", "maple syrup"], 1.32),
        (["cream"], 1.01),
        (["yogurt", "yoghurt"], 1.03),
        (["peanut butter"], 1.09),
    ])

    /// Converts `<amount> <volume unit> of <ingredient> to <weight unit>` and the reverse.
    /// Returns `nil` for unknown ingredients.
    static func evaluate(_ query: String) -> CalcResult? {
        guard let match = pattern.firstMatch(in: query.trimmingCharacters(in: .whitespacesAndNewlines)),
              let amount = Double(match.text(1)) else { return nil }
        let from = match.text(2).lowercased()
        let ingredient = match.text(3).lowercased().trimmingCharacters(in: .whitespaces)
        let to = match.text(4).lowercased()
        guard let density = densities[ingredient] else { return nil }
        let detail = "\(ingredient) ≈ \(CalcFormat.plain(density)) g/ml"

        if let volume = volumeUnits[from], let weight = weightUnits[to] {
            let value = kitchenRounded(amount * volume.milliliters * density / weight.grams)
            return CalcResult(value: "\(CalcFormat.number(value)) \(weight.label)", detail: detail, kind: .unit)
        }

        if let weight = weightUnits[from], let volume = volumeUnits[to] {
            let value = kitchenRounded(amount * weight.grams / density / volume.milliliters)
            let label = value == 1 ? volume.singular : volume.plural
            return CalcResult(value: "\(CalcFormat.number(value)) \(label)", detail: detail, kind: .unit)
        }

        return nil
    }

    /// 1 decimal for values of 10 or more, 2 below that.
    private static func kitchenRounded(_ value: Double) -> Double {
        let scale: Double = abs(value) >= 10 ? 10 : 100
        return (value * scale).rounded() / scale
    }

    private static func expand<Value>(_ entries: [([String], Value)]) -> [String: Value] {
        var table: [String: Value] = [:]
        for (names, value) in entries {
            for name in names {
                table[name] = value
            }
        }
        return table
    }
}
