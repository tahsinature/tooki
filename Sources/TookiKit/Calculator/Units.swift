import Foundation

/// The compact unit table that replaces fend-core's unit database.
/// Factors convert one unit into base units: metres, kilograms, seconds,
/// kelvin, bits, cubic metres for volume, radians for angles.
enum UnitTable {
    private struct Definition {
        /// Case-sensitive abbreviations, shown as written (`km`, `GiB`).
        let symbols: [String]
        /// Case-insensitive long names, shown in singular or plural form.
        let names: [String]
        let factor: Double
        let dimension: UnitDimension
        var offset: Double = 0
        /// Fixed label regardless of spelling (`°C` for `c`, `C`, `celsius`).
        var label: String?
    }

    private static let irregularPlurals = [
        "foot": "feet", "inch": "inches", "century": "centuries",
        "celsius": "celsius", "fahrenheit": "fahrenheit", "kelvin": "kelvin",
        "hertz": "hertz", "horsepower": "horsepower",
    ]

    private static let definitions: [Definition] = [
        // Length
        Definition(symbols: ["m"], names: ["meter", "metre"], factor: 1, dimension: .length),
        Definition(symbols: ["km"], names: ["kilometer", "kilometre"], factor: 1000, dimension: .length),
        Definition(symbols: ["cm"], names: ["centimeter", "centimetre"], factor: 0.01, dimension: .length),
        Definition(symbols: ["mm"], names: ["millimeter", "millimetre"], factor: 0.001, dimension: .length),
        Definition(symbols: ["µm", "μm", "um"], names: ["micrometer", "micrometre", "micron"], factor: 1e-6, dimension: .length),
        Definition(symbols: ["nm"], names: ["nanometer", "nanometre"], factor: 1e-9, dimension: .length),
        Definition(symbols: ["mi"], names: ["mile"], factor: 1609.344, dimension: .length),
        Definition(symbols: ["yd"], names: ["yard"], factor: 0.9144, dimension: .length),
        Definition(symbols: ["ft", "'"], names: ["foot"], factor: 0.3048, dimension: .length),
        Definition(symbols: ["in", "\""], names: ["inch"], factor: 0.0254, dimension: .length),
        Definition(symbols: ["nmi"], names: ["nautical mile"], factor: 1852, dimension: .length),
        Definition(symbols: ["ly"], names: ["light year", "lightyear"], factor: 9_460_730_472_580_800, dimension: .length),
        Definition(symbols: ["au", "AU"], names: ["astronomical unit"], factor: 149_597_870_700, dimension: .length),
        // Area
        Definition(symbols: ["ha"], names: ["hectare"], factor: 10_000, dimension: .area),
        Definition(symbols: ["ac"], names: ["acre"], factor: 4046.8564224, dimension: .area),
        // Volume
        Definition(symbols: ["l", "L"], names: ["liter", "litre"], factor: 0.001, dimension: .volume),
        Definition(symbols: ["ml", "mL"], names: ["milliliter", "millilitre"], factor: 1e-6, dimension: .volume),
        Definition(symbols: ["cl"], names: ["centiliter", "centilitre"], factor: 1e-5, dimension: .volume),
        Definition(symbols: ["dl"], names: ["deciliter", "decilitre"], factor: 1e-4, dimension: .volume),
        Definition(symbols: ["cc"], names: [], factor: 1e-6, dimension: .volume),
        Definition(symbols: ["gal"], names: ["gallon"], factor: 0.003785411784, dimension: .volume),
        Definition(symbols: ["qt"], names: ["quart"], factor: 0.000946352946, dimension: .volume),
        Definition(symbols: ["pt"], names: ["pint"], factor: 0.000473176473, dimension: .volume),
        Definition(symbols: [], names: ["cup"], factor: 0.0002365882365, dimension: .volume),
        Definition(symbols: ["floz", "fl oz"], names: ["fluid ounce"], factor: 2.95735295625e-5, dimension: .volume),
        Definition(symbols: ["tbsp"], names: ["tablespoon"], factor: 1.478676478125e-5, dimension: .volume),
        Definition(symbols: ["tsp"], names: ["teaspoon"], factor: 4.92892159375e-6, dimension: .volume),
        // Mass
        Definition(symbols: ["g"], names: ["gram", "gramme"], factor: 0.001, dimension: .mass),
        Definition(symbols: ["kg"], names: ["kilogram", "kilo"], factor: 1, dimension: .mass),
        Definition(symbols: ["mg"], names: ["milligram"], factor: 1e-6, dimension: .mass),
        Definition(symbols: ["µg", "μg", "ug", "mcg"], names: ["microgram"], factor: 1e-9, dimension: .mass),
        Definition(symbols: ["t"], names: ["tonne", "metric ton"], factor: 1000, dimension: .mass),
        Definition(symbols: [], names: ["ton"], factor: 907.18474, dimension: .mass),
        Definition(symbols: ["lb", "lbs"], names: ["pound"], factor: 0.45359237, dimension: .mass),
        Definition(symbols: ["oz"], names: ["ounce"], factor: 0.028349523125, dimension: .mass),
        Definition(symbols: ["st"], names: ["stone"], factor: 6.35029318, dimension: .mass),
        Definition(symbols: ["ct"], names: ["carat"], factor: 0.0002, dimension: .mass),
        // Time
        Definition(symbols: ["s", "sec", "secs"], names: ["second"], factor: 1, dimension: .time),
        Definition(symbols: ["ms"], names: ["millisecond"], factor: 0.001, dimension: .time),
        Definition(symbols: ["µs", "μs", "us"], names: ["microsecond"], factor: 1e-6, dimension: .time),
        Definition(symbols: ["ns"], names: ["nanosecond"], factor: 1e-9, dimension: .time),
        Definition(symbols: ["min", "mins"], names: ["minute"], factor: 60, dimension: .time),
        Definition(symbols: ["h", "hr", "hrs"], names: ["hour"], factor: 3600, dimension: .time),
        Definition(symbols: ["d"], names: ["day"], factor: 86_400, dimension: .time),
        Definition(symbols: ["wk", "wks"], names: ["week"], factor: 604_800, dimension: .time),
        Definition(symbols: [], names: ["fortnight"], factor: 1_209_600, dimension: .time),
        Definition(symbols: ["mo"], names: ["month"], factor: 2_629_800, dimension: .time),
        Definition(symbols: ["yr", "yrs"], names: ["year"], factor: 31_557_600, dimension: .time),
        Definition(symbols: [], names: ["decade"], factor: 315_576_000, dimension: .time),
        Definition(symbols: [], names: ["century"], factor: 3_155_760_000, dimension: .time),
        Definition(symbols: [], names: ["workday"], factor: 28_800, dimension: .time),
        Definition(symbols: [], names: ["workweek"], factor: 144_000, dimension: .time),
        Definition(symbols: [], names: ["workmonth"], factor: 576_000, dimension: .time),
        // Speed
        Definition(symbols: ["mph"], names: [], factor: 0.44704, dimension: .speed),
        Definition(symbols: ["kph", "kmh"], names: [], factor: 1000.0 / 3600, dimension: .speed),
        Definition(symbols: ["kn", "kt"], names: ["knot"], factor: 1852.0 / 3600, dimension: .speed),
        // Temperature: kelvin = (reading + offset) × factor
        Definition(symbols: ["K"], names: ["kelvin"], factor: 1, dimension: .temperature, label: "K"),
        Definition(symbols: ["°C", "C", "degC"], names: ["celsius"], factor: 1, dimension: .temperature, offset: 273.15, label: "°C"),
        Definition(symbols: ["°F", "F", "degF"], names: ["fahrenheit"], factor: 5.0 / 9, dimension: .temperature, offset: 459.67, label: "°F"),
        // Data (bytes are listed before bits so case-insensitive `mb` means megabytes)
        Definition(symbols: ["B"], names: ["byte"], factor: 8, dimension: .information),
        Definition(symbols: ["kB", "KB"], names: ["kilobyte"], factor: 8e3, dimension: .information),
        Definition(symbols: ["MB"], names: ["megabyte"], factor: 8e6, dimension: .information),
        Definition(symbols: ["GB"], names: ["gigabyte"], factor: 8e9, dimension: .information),
        Definition(symbols: ["TB"], names: ["terabyte"], factor: 8e12, dimension: .information),
        Definition(symbols: ["PB"], names: ["petabyte"], factor: 8e15, dimension: .information),
        Definition(symbols: ["KiB"], names: ["kibibyte"], factor: 8 * 1024, dimension: .information),
        Definition(symbols: ["MiB"], names: ["mebibyte"], factor: 8 * 1_048_576, dimension: .information),
        Definition(symbols: ["GiB"], names: ["gibibyte"], factor: 8 * 1_073_741_824, dimension: .information),
        Definition(symbols: ["TiB"], names: ["tebibyte"], factor: 8 * 1_099_511_627_776, dimension: .information),
        Definition(symbols: ["PiB"], names: ["pebibyte"], factor: 8 * 1_125_899_906_842_624, dimension: .information),
        Definition(symbols: ["b", "bit"], names: ["bit"], factor: 1, dimension: .information),
        Definition(symbols: ["kb", "Kb", "kbit"], names: ["kilobit"], factor: 1e3, dimension: .information),
        Definition(symbols: ["Mb", "Mbit"], names: ["megabit"], factor: 1e6, dimension: .information),
        Definition(symbols: ["Gb", "Gbit"], names: ["gigabit"], factor: 1e9, dimension: .information),
        Definition(symbols: ["Tb", "Tbit"], names: ["terabit"], factor: 1e12, dimension: .information),
        Definition(symbols: ["bps"], names: [], factor: 1, dimension: .dataRate),
        Definition(symbols: ["kbps", "Kbps"], names: [], factor: 1e3, dimension: .dataRate),
        Definition(symbols: ["Mbps"], names: [], factor: 1e6, dimension: .dataRate),
        Definition(symbols: ["Gbps"], names: [], factor: 1e9, dimension: .dataRate),
        // Energy
        Definition(symbols: ["J"], names: ["joule"], factor: 1, dimension: .energy),
        Definition(symbols: ["kJ"], names: ["kilojoule"], factor: 1e3, dimension: .energy),
        Definition(symbols: ["MJ"], names: ["megajoule"], factor: 1e6, dimension: .energy),
        Definition(symbols: ["cal"], names: ["calorie"], factor: 4.184, dimension: .energy),
        Definition(symbols: ["kcal", "Cal"], names: ["kilocalorie"], factor: 4184, dimension: .energy),
        Definition(symbols: ["Wh"], names: ["watt hour"], factor: 3600, dimension: .energy),
        Definition(symbols: ["kWh"], names: ["kilowatt hour"], factor: 3.6e6, dimension: .energy),
        Definition(symbols: ["BTU", "btu"], names: [], factor: 1055.05585262, dimension: .energy),
        Definition(symbols: ["eV"], names: ["electronvolt"], factor: 1.602176634e-19, dimension: .energy),
        // Power
        Definition(symbols: ["W"], names: ["watt"], factor: 1, dimension: .power),
        Definition(symbols: ["kW"], names: ["kilowatt"], factor: 1e3, dimension: .power),
        Definition(symbols: ["MW"], names: ["megawatt"], factor: 1e6, dimension: .power),
        Definition(symbols: ["GW"], names: ["gigawatt"], factor: 1e9, dimension: .power),
        Definition(symbols: ["hp"], names: ["horsepower"], factor: 745.69987158227022, dimension: .power),
        // Pressure
        Definition(symbols: ["Pa"], names: ["pascal"], factor: 1, dimension: .pressure),
        Definition(symbols: ["hPa"], names: ["hectopascal"], factor: 100, dimension: .pressure),
        Definition(symbols: ["kPa"], names: ["kilopascal"], factor: 1e3, dimension: .pressure),
        Definition(symbols: ["MPa"], names: ["megapascal"], factor: 1e6, dimension: .pressure),
        Definition(symbols: ["bar"], names: [], factor: 1e5, dimension: .pressure),
        Definition(symbols: ["mbar"], names: ["millibar"], factor: 100, dimension: .pressure),
        Definition(symbols: ["psi"], names: [], factor: 6894.757293168361, dimension: .pressure),
        Definition(symbols: ["atm"], names: ["atmosphere"], factor: 101_325, dimension: .pressure),
        Definition(symbols: ["mmHg"], names: [], factor: 133.322387415, dimension: .pressure),
        Definition(symbols: ["torr", "Torr"], names: [], factor: 101_325.0 / 760, dimension: .pressure),
        // Frequency
        Definition(symbols: ["Hz"], names: ["hertz"], factor: 1, dimension: .frequency),
        Definition(symbols: ["kHz"], names: ["kilohertz"], factor: 1e3, dimension: .frequency),
        Definition(symbols: ["MHz"], names: ["megahertz"], factor: 1e6, dimension: .frequency),
        Definition(symbols: ["GHz"], names: ["gigahertz"], factor: 1e9, dimension: .frequency),
        // Angle (dimensionless, measured in radians)
        Definition(symbols: ["rad"], names: ["radian"], factor: 1, dimension: .none),
        Definition(symbols: ["deg"], names: ["degree"], factor: .pi / 180, dimension: .none),
        Definition(symbols: ["°"], names: [], factor: .pi / 180, dimension: .none, label: "°"),
    ]

    /// Case-sensitive abbreviations (`km`, `GiB`, `fl oz`).
    private static let symbols: [String: ResolvedUnit] = {
        var table: [String: ResolvedUnit] = [:]
        for definition in definitions {
            for symbol in definition.symbols {
                table[symbol] = resolved(definition, singular: symbol, plural: symbol)
            }
        }
        return table
    }()

    /// Lowercased long names in singular and plural form (`mile`, `miles`, `light years`).
    private static let longNames: [String: ResolvedUnit] = {
        var table: [String: ResolvedUnit] = [:]
        for definition in definitions {
            for name in definition.names {
                let plural = irregularPlurals[name] ?? name + "s"
                let unit = resolved(definition, singular: name, plural: plural)
                table[name] = unit
                table[plural] = unit
            }
        }
        return table
    }()

    /// Case-insensitive fallback for abbreviations (`f` → `°F`, `gb` → `GB`). The first definition wins.
    private static let caseInsensitiveSymbols: [String: ResolvedUnit] = {
        var table: [String: ResolvedUnit] = [:]
        for definition in definitions {
            for symbol in definition.symbols where table[symbol.lowercased()] == nil {
                table[symbol.lowercased()] = resolved(definition, singular: symbol, plural: symbol)
            }
        }
        return table
    }()

    /// An abbreviation spelled exactly (`km`) or a long name in any case (`Miles`, `fl oz`, `light years`).
    static func exact(_ name: String) -> ResolvedUnit? {
        symbols[name] ?? longNames[name.lowercased()]
    }

    static func caseInsensitive(_ name: String) -> ResolvedUnit? {
        caseInsensitiveSymbols[name.lowercased()]
    }

    private static func resolved(_ definition: Definition, singular: String, plural: String) -> ResolvedUnit {
        ResolvedUnit(
            display: DisplayUnit(
                singular: definition.label ?? singular,
                plural: definition.label ?? plural,
                factor: definition.factor,
                offset: definition.offset
            ),
            dimension: definition.dimension
        )
    }
}
