# Calculator

Tooki's natural-language calculator lives in `Sources/TookiKit/Calculator/`. It is a pure Swift port of the calculator engine from [Asyar](https://github.com/Xoshbin/asyar), with no added dependencies. It answers launcher queries such as `20% off 80`, `5 km to miles`, `$50 in gbp`, `days until christmas`, `time in tokyo`, `#ff8800` and `0xff`.

The public entry point is:

```swift
let snapshot = currencyRates.snapshot()
let context = CalculatorContext(rates: snapshot.rates, ratesAge: snapshot.age, preferredCurrency: "EUR")
let result = Calculator.evaluate("100 usd to eur", context: context) // CalcResult?
```

`CalcResult` mirrors Asyar's struct: `value` (main text, for example `≈ 62.1371192237 miles`), `detail` (supporting line) and `kind` (`math`, `unit`, `currency`, `date`, `time`, `base`, `color`, `percent`, `ratio`). `copyValue` drops the `≈ ` marker for the clipboard. `CalculatorContext` injects the current time, time zone, number notation (from a `Locale` or explicitly), exchange rates and preferred currency, so results are deterministic in tests. `InputGate.shouldAttempt(_:)` exposes Asyar's cheap "is this a calculation at all?" check.

## Upstream source

| | |
|---|---|
| Repository | https://github.com/Xoshbin/asyar (GPLv3) |
| Path | `asyar-launcher/src-tauri/crates/asyar-calculator` |
| Pinned commit | `034a38c3a4488ffadb6168dec5af1a874f17dfed` |
| Commit date | 2026-10-25 |

Pinned commit: 034a38c3a4488ffadb6168dec5af1a874f17dfed

The line above is read by `scripts/calculator-upstream.sh`. Keep it in this exact form.

## File mapping

| Asyar (`src/`) | Tooki (`Sources/TookiKit/Calculator/`) |
|---|---|
| `lib.rs` (`CalcKind`, `CalcResult`, `EvalContext`) | `CalcResult.swift` |
| `lib.rs` (`should_attempt`, URL and path detection) | `InputGate.swift` |
| `lib.rs` (`evaluate_query` pipeline) | `Calculator.swift` |
| `lib.rs` (`implicit_currency`, `rate_unit_currency`) | `CurrencyPhrases.swift` |
| `normalize.rs` | `Normalize.swift` |
| `locale.rs` | `NumberFormat.swift` |
| `format.rs` | `Format.swift` |
| `percent.rs` | `Percent.swift` |
| `dates.rs` | `Dates.swift`, `DateTokens.swift`, `CivilDate.swift` (replaces chrono's `NaiveDate`) |
| `timezone.rs` | `TimeZones.swift`, `ZoneNames.swift` (replaces chrono-tz) |
| `colors.rs` | `Colors.swift` |
| `cooking.rs` | `Cooking.swift` |
| `extras.rs` | `Extras.swift` |
| `engine.rs` | `ExpressionEngine.swift`, `EngineOutput.swift` |
| `currency.rs` (cache, TTL, fetch) | `Currency.swift` (`RatesCache`, `CurrencyRates`), `RatesFetcher.swift` |
| `currency.rs` (fend rate handler) | `CurrencyUnits.swift` |
| fend-core (no Asyar file) | `ExpressionTokenizer.swift`, `ExpressionParser.swift`, `BaseTarget.swift`, `MathFunctions.swift`, `Quantity.swift`, `QuantityArithmetic.swift`, `Units.swift` |
| `regex` crate | `RegexPattern.swift` (patterns compiled once, held in static constants) |

Tests live in `Tests/TookiKitTests/Calculator/`, one file per Rust module (`PercentTests.swift` for `percent.rs`, `CalculatorTests.swift` for `lib.rs`, and so on). Each Swift test is named after the Rust test it ports (`fn percent_of()` becomes `@Test func percentOf()`). `ExpressionParserTests.swift` holds Tooki-only tests for the fend replacement.

## Ported tests

All 150 upstream `#[test]` functions are ported with the same inputs and expected outputs. 146 run unchanged, 3 are adapted and 1 is skipped:

| Rust test | Status | Reason |
|---|---|---|
| `currency.rs` `fetch_rates_includes_crypto` | Skipped (`.disabled`) | Hits the live network. It is `#[ignore]` upstream too. |
| `currency.rs` `fend_handler_returns_units_per_usd` | Adapted | fend's exchange-rate handler doesn't exist. The test checks `CurrencyUnits.resolve`, which turns the same rates map into currency units (IQD is 1/1310 USD, USD is 1, unknown codes fail). |
| `engine.rs` `hostile_expression_respects_budget` | Adapted | The Swift engine has no wall-clock interrupt (parsing is linear). `10^10^10^10` overflows to infinity, so the test checks for `nil` within the same 2-second limit. |
| `lib.rs` `state_snapshot_empty_by_default` | Adapted | Asyar's Tauri `CalculatorState` is replaced by `CurrencyRates`. The test checks that a fresh store with no cache file returns no rates and no age. |

No test needed a different expected value because of fend-specific formatting: the Swift engine prints numbers the way fend does.

## What replaced fend-core

Asyar sends everything its specialized handlers don't recognize to [fend-core](https://github.com/printfn/fend). Tooki uses a small native engine instead:

- `ExpressionTokenizer` splits input into numbers, words and symbols. It understands `1,234.5`, `.5`, `1.5e3`, `0xff`, `0b101`, `0o17`, `**`, `×`, `÷`, `−` and `->`. Unknown characters fail the whole expression.
- `ExpressionParser` is a throwing recursive-descent parser with this grammar: conversions (`to`, `as`, `in`), sums, products (`*`, `/`, `of`, `per`, `mod` and implicit multiplication such as `2 pi` or `3(4 + 1)`), unary signs, right-associative `^`, postfix `!` and `%`, parentheses, constants (`pi`, `π`, `tau`, `e`) and functions (`sqrt`, `cbrt`, `abs`, `round`, `floor`, `ceil`, `ln`, `log` (base 10), `log2`, `log10`, `exp`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `sinh`, `cosh`, `tanh`). Trigonometry uses radians; `deg` and `°` are units, so `sin(30 deg)` is `0.5`.
- `Quantity` stores a value in base units plus a dimension vector (length, mass, time, temperature, information, currency), so `km/h`, `m^2`, `GBP/hour` and mixed sums like `5'10"` or `1 h 30 min` work. `100 + 10%` is 110 and `25% of 200` is 50, like fend.
- `Units.swift` is a compact table of about 110 unit definitions: length, area, volume (including cooking units), mass, time (including Asyar's `workday`, `workweek`, `workmonth`), speed, temperature (absolute scales with offsets), data sizes (SI and binary), data rates, energy, power, pressure, frequency and angles. `square`, `sq`, `cubic` and `cu` prefixes are supported.
- `CurrencyUnits` defines a unit for every code in the injected rates map (plus `dollar`, `euro`, `yen`). Like Asyar, crypto prices are rounded to 8 decimals.
- `BaseTarget` handles `to hex`, `binary`, `octal` and `decimal`.
- `EngineOutput` prints results like fend (`1024`, `177.8 cm`, `approx. 62.1371192237 miles`), and `CalcFormat.beautify` then adds digit grouping and the `≈ ` marker, exactly as in Asyar.

The engine never throws out of its API: every failure (syntax, mismatched units, division by zero, overflow) returns `nil`. It runs in well under a millisecond for typical queries (about 0.06 ms per query on an M-series Mac, measured across 38 mixed queries).

### Known gaps compared to fend

- **Precision.** Calculations use `Double`, not fend's arbitrary-precision rationals. Float noise is rounded to 15 significant digits before printing, so `0.1 + 0.2` is `0.3`. Very large values (2^53 and above) are marked approximate, and magnitudes below 1e-15 show as `≈ 0`.
- **Huge and tiny numbers** print in scientific notation (`≈ 1e30`). Asyar's string-based kind detection then classifies them as `unit`, because of the letter `e`.
- **Smaller unit and function set.** No physical constants (`speed of light`), no fend unit prefixes beyond the table, no user-defined variables, no complex numbers, no fractions output, and no `to fraction` or `to sci` targets.
- **Functions on dimensioned values.** Only `abs`, `round`, `floor` and `ceil` keep a unit. The others require a plain number (except angles, which are plain numbers in radians).
- **Base output** is limited to integers below 2^63. Expressions that mix bases (`0xff + 1`) print in decimal unless a base target is given.
- **Currency codes win over unit names when rates are loaded**, so `1 cup to ml` fails when the rates include `CUP` (the Cuban peso). Asyar has the same behavior, since its normalizer also uppercases `cup` to `CUP`.
- **The 2+2=1 easter egg** is kept for parity with Asyar.

Other platform differences:

- `TimeZone.knownTimeZoneIdentifiers` lists only canonical IANA names, so legacy link names such as `Asia/Calcutta` don't resolve by their last segment. Asyar's aliases (`india`, `sf`, `pst` and so on) still work.
- Asyar's `u128` base conversions use `UInt64` in Swift.

## Exchange rates

`Calculator` never touches the network. Rates are injected through `CalculatorContext.rates` (units of each currency per one USD).

`CurrencyRates` is the app-side store:

- `CurrencyRates(cacheURL:)` takes the JSON cache location, for example `~/Library/Application Support/Tooki/calculator/rates.json`. The file format matches Asyar's (`rates`, `fetched_at_epoch_secs`).
- `snapshot()` lazily loads the disk cache and returns the rates plus a human-readable age (`just now`, `3 min`, `2 h`, `1 d`) for `CalculatorContext.ratesAge`.
- `isStale()` uses Asyar's TTL policy: 6 hours by default; `setTTLHours(_:)` clamps to 1 to 24 hours, and zero or less restores the default. Missing rates count as stale.
- `refresh()` and `refreshIfStale()` are the only methods that use the network. The app decides when to call them. Overlapping calls do one fetch.

`RatesFetcher` uses the same sources as Asyar: `https://api.exchangerate-api.com/v4/latest/USD` for fiat (required), and CoinGecko's `simple/price` endpoint for 15 crypto coins (best effort). Requests time out after 15 seconds and send a descriptive User-Agent, which CoinGecko requires.

## Syncing with upstream

1. List what changed in the calculator crate since the pinned commit:

   ```sh
   scripts/calculator-upstream.sh
   ```

   This is equivalent to:

   ```sh
   git clone https://github.com/Xoshbin/asyar
   git -C asyar log --oneline 034a38c..HEAD -- asyar-launcher/src-tauri/crates/asyar-calculator
   ```

2. Review each diff (`git -C asyar show <commit> -- asyar-launcher/src-tauri/crates/asyar-calculator`).
3. Port the logic changes to the matching Swift file from the table above. For changes in fend-core usage, decide whether the native engine needs to support the new syntax.
4. Port new or changed `#[test]` functions to the matching Swift test file, keeping the Rust function name in camelCase. List any adapted or skipped tests in this document.
5. Run `make test`.
6. Update the pinned commit hash and date in this document (both the table and the `Pinned commit:` line) and the `// Ported from … @ <short hash>` header of every file in `Tests/TookiKitTests/Calculator/`.
