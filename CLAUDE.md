# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

- **Run example scripts**: `bundle exec ruby examples/openfigi_lookup.rb`
- **Run all tests**: `bundle exec rake spec` or `bundle exec rspec`
- **Run single test file**: `bundle exec rspec spec/sec_id/isin_spec.rb`
- **Run specific test**: `bundle exec rspec spec/sec_id/isin_spec.rb:42`
- **Run linter**: `bundle exec rake rubocop` or `bundle exec rubocop`
- **Safe auto-fix lint issues**: `bundle exec rubocop -a`
- **Auto-fix ALL lint issues (potentially unsafe)**: `bundle exec rubocop -A`
- **Run both lint and tests**: `bundle exec rake` (default task: `rubocop` + `rbs` + `spec`)
- **Validate RBS signatures**: `bundle exec rake rbs` (also in the default task)
- **Type-check (Steep, strict)**: `bundle exec rake steep`
- **Type coverage gate**: `bundle exec rake steep:coverage` (fails if untyped calls exceed the pinned baseline)
- **Runtime signature check**: `bundle exec rake rbs:test` (runs the spec suite under RBS::Test)
- **Regenerate CFI dynamic-method sigs**: `bundle exec rake sig:cfi`
- **Generate API docs (YARD)**: `bundle exec rake yard` (HTML output in `doc/`, driven by `.yardopts`)
- **Documentation coverage gate**: `bundle exec rake yard:stats` (fails unless 100% of the public API is documented; a CI step)
- **Run tests with coverage**: `COVERAGE=1 bundle exec rspec`
- **Run benchmarks**: `bundle exec rake bench` (validation/detection throughput + allocations; machine-dependent, for catching regressions)
- **Install dependencies**: `bin/setup`
- **Interactive console**: `bin/console`

## Architecture

This is a Ruby toolkit for securities identifiers (ISIN, CUSIP, CEI, SEDOL, FIGI, LEI, IBAN, CIK, OCC, WKN, Valoren, CFI, FISN, BIC, DTI, UPI) — validate, normalize, parse, detect, convert, generate, classify, calculate checksums, and repair. CFI is a full ISO 10962:2021 classifier (`CFI#decode`). Checksum-failing identifiers can be repaired via `suggest` (homoglyph + transposition candidates, confidence-ranked). Ships an opt-in ActiveModel/Rails validator that adds no runtime dependency to the zero-dependency core.

### Directory Layout

- `lib/` — gem source (shipped in the gem)
- `sig/` — hand-written RBS type signatures mirroring the core `lib/` scope (shipped in the gem; see RBS Type Signatures below)
- `tasks/` — build-time helpers not shipped in the gem (currently `cfi_signature_generator.rb`, shared by `rake sig:cfi` and the drift spec)
- `spec/` — RSpec tests
- `examples/` — runnable integration examples (not shipped in gem, linted by rubocop)
- `docs/guides/` — lookup service integration guides (not shipped in gem)
- `docs/solutions/` — documented solutions to past problems (bugs, best practices, design patterns), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`); relevant when implementing or debugging in documented areas (not shipped in gem)
- `CONCEPTS.md` — shared domain vocabulary (identifier anatomy, named processes); relevant when orienting to the codebase or discussing domain concepts
- `sec_id.gemspec` `spec.files` includes `lib/**/*.rb`, `sig/**/*`, and select markdown files — `docs/` and `examples/` are intentionally excluded

### Class Hierarchy

All identifier classes inherit from `SecID::Base` (`lib/sec_id/base.rb`), a thin coordinator that includes three concerns:
- `Normalizable` — normalization: `#normalized` / `#normalize`, `#normalize!`, `.normalize(id)`, `#to_s`, `#to_str`, `SEPARATORS`
- `Validatable` — validation: `#valid?`, `#validate`, `#errors`, `#validate!`, `.valid?`, `.validate`, `.validate!`, `.error_class_for`, `ERROR_MAP`
- `Generatable` — generation: `.generate(random:)`, `random_string(charset, length, random:)` helper, `ALPHA`/`DIGITS`/`ALPHANUMERIC` charset constants

Base itself keeps:
- Class-level metadata methods: `type_key` (the registry symbol — single authority, read by the registry, `to_h`, `explain`, the validator, `Detector`, and `Scanner`), `short_name`, `full_name`, `id_length`, `example`, `has_checksum?`, and the `@api private` `detection_priority` (composite specificity sort key: checksum rank, `length_specificity`, registration order — `Float::INFINITY` for an unregistered class)
- `attr_reader :full_id, :identifier`
- `inherited` hook (auto-registration)
- `initialize` (abstract, raises `NotImplementedError`)
- `to_h` (returns `{ type:, full_id:, normalized:, valid:, components: }`)
- `as_json(*)` — delegates to `to_h` for JSON serialization compatibility
- `deconstruct_keys(_keys)` — returns `components` so every type destructures in `case/in`; the `keys` argument is ignored, validity is not consulted (unparseable input binds `nil` per key), and no `deconstruct` exists
- `==`, `eql?`, `hash` — value equality based on `comparison_id` (type + normalized form); instances usable as Hash keys and in Sets
- `components` (private, returns `{}` — subclasses override with type-specific attributes)
- `parse` (private, regex matching + `@full_id` assignment)

Each identifier class defines these metadata constants:
- `FULL_NAME` — human-readable standard name (e.g. `"International Securities Identification Number"`)
- `ID_LENGTH` — fixed length (`Integer`), valid length range (`Range`), or discrete valid lengths (`Array`, e.g. BIC's `[8, 11]`). `detector.rb` and `scanner.rb` read the shape via the shared `Base.length_values` (enumerable lengths) / `Base.length_specificity` (specificity weight) helpers; `validatable.rb#valid_length?` branches on the three shapes directly for its bounds check
- `EXAMPLE` — representative valid identifier string
- `VALID_CHARS_REGEX` — regex for valid character set (used by `detect_errors` fallback)

Classes with checksums include the `Checkable` concern, which adds:
- `valid?` override that validates format and checksum
- `restore` (returns full identifier string without mutation), `restore!` (mutates and returns `self`), `checksum`, `calculate_checksum` methods
- Character-to-digit conversion maps and Luhn algorithm variants
- Class-level `restore`, `restore!`, and `checksum` methods

### Registry (`lib/sec_id.rb`)

Identifier classes auto-register via `Base.inherited`. Access them through:
- `SecID[:isin]` — look up class by symbol key (raises `ArgumentError` if unknown)
- `SecID.identifiers` — all registered classes in load order
- `SecID.valid?(str, types: nil)` — quick boolean validation against all or specific types
- `SecID.detect(str)` — returns all matching type symbols sorted by specificity (e.g. `[:isin]`)
- `SecID.parse(str, types: nil, on_ambiguous: :first)` — returns a typed instance for the most specific match (or `nil`); `on_ambiguous:` accepts `:first` (default), `:raise` (raises `AmbiguousMatchError`), `:all` (returns array of all matching instances)
- `SecID.parse!(str, types: nil, on_ambiguous: :first)` — like `parse` but raises `InvalidFormatError` on failure
- `SecID.extract(text, types: nil)` — finds identifiers in freeform text, returns `Array<Match>`
- `SecID.scan(text, types: nil)` — lazy version of `extract`, returns `Enumerator<Match>`
- `SecID.explain(str, types: nil)` — returns per-type validation results for debugging detection
- `SecID.generate(key, random: Random.new)` — returns a generated, format-valid instance for a type symbol (raises `ArgumentError` on unknown type); generated values are valid in format only, not real securities
- `SecID.suggest(str, types: nil)` — returns confidence-ranked `Suggestion` repair candidates for a checksum-failing identifier. Resolves candidate types via the format-only filters (`has_checksum?` + `length_values` + `VALID_CHARS_REGEX`, mirroring detector stages 2–3 — a checksum-failing string never survives `valid?`-based detection), runs each type's `.suggest`, flattens, and ranks cross-type by confidence tier then registration order. `types:` narrows to the given types (non-checksum types are silently dropped — no oracle). The private `suggestable_types` helper does the resolution

### Detector (`lib/sec_id/detector.rb`)

`@api private` class that implements type detection via a three-stage pipeline:
1. **Special-char dispatch** — `/` routes to FISN, ` ` to OCC, `*@#` to CUSIP
2. **Length lookup** — pre-computed `Hash{Integer => Array<Class>}` from `ID_LENGTH` constants
3. **Charset pre-filter** — survivors filtered by `VALID_CHARS_REGEX` before calling `valid?`

Specificity sort: reads each class's `Base.detection_priority` (checksum types first, then smaller length range, then load order).

Fast paths bypass the full sort: `#matches?` (used by `SecID.valid?`) short-circuits on the first valid candidate; `#first_match` (used by `SecID.parse`) builds the winning instance once and selects it via `min_by`, avoiding a second instantiation.

Lazily instantiated from `SecID.detect`; cache invalidated when new types register.

### Scanner (`lib/sec_id/scanner.rb`)

`@api private` class that finds identifiers in freeform text. Uses a composite regex with three named groups (FISN, OCC, simple tokens) and cursor-based overlap prevention. Candidates are length-filtered, charset-filtered, and validated, then the most specific match is returned as a `Match` data object (`Data.define(:type, :raw, :range, :identifier)`).

Lazily instantiated from `SecID.scan`/`SecID.extract`; cache invalidated when new types register.

### Suggestion value object (`lib/sec_id/suggestion.rb`)

`Suggestion = Data.define(:type, :identifier, :edit, :position, :from, :to, :confidence)` — the frozen record `suggest` returns, mirroring `Scanner::Match` (flat immutable `Data`, not the hand-rolled CFI value classes). `identifier` is the valid, parsed `SecID::Base` instance (so callers get `.to_s`, `.to_h`, `.country_code` for free); `edit` is `:substitution` / `:transposition` / `:checksum`. Coordinate system: `:substitution` — `position` is the 0-based index, `from`/`to` the single changed characters; `:transposition` — `position` is the left index, `from`/`to` the two-character adjacent substring before/after the swap; `:checksum` — `position` is `nil`, `from`/`to` the old/new check-character string, `confidence` is `nil`. `Data` supplies `==`/`hash`/`to_h`/`deconstruct_keys`; the reopened `class Suggestion` block (not the `Data.define` block, so Steep types `self` as the instance) adds `as_json(*) => to_h`, `to_s => identifier.to_s`, and the runtime-introspectable domain enumerations `EDIT_KINDS` (`%i[substitution transposition checksum]`, rank order) and `CONFIDENCE_LEVELS` (`%i[high medium]`; `:checksum` candidates carry `nil`) — mirroring `Validatable::ERROR_MAP`'s discoverability role so consumers enumerate legal values instead of parsing docs.

### ActiveModel / Rails Validator (`lib/sec_id/active_model.rb`, `lib/sec_id/railtie.rb`)

Optional, opt-in adapter — **never on the default `require 'sec_id'` path**, so the gem keeps zero runtime dependencies (ActiveModel/railties are dev/test deps only).

- `lib/sec_id/active_model.rb` defines a top-level `::SecIdValidator < ActiveModel::EachValidator` (top-level constant so ActiveModel's `sec_id` → `SecIdValidator` lookup resolves it; distinct from the `SecID` module). It requires `active_model`, re-raising a clear `LoadError` if absent. `check_validity!` resolves `type:`/`types:` via `SecID[]` (fail-fast `ArgumentError` at class-load on unknown type, both keys together, or an empty `types:`). `validate_each` is strict by default (`SecID.valid?`); `normalize: true` switches to the separator-lenient `SecID[t].normalize` path and writes the canonical string back on success (agnostic/allowlist ambiguity resolves to the first matching type in registration/allowlist order — KTD5); `details: true` (single `type:` only) surfaces sec_id's specific failure reason. The error is added under the i18n key `:sec_id` with a built-in type-aware English default (`DEFAULT_MESSAGE`, `%{type_name}` interpolation) supplied as ActiveModel's `message:` fallback — no locale files shipped, so the only i18n override point is the attribute-scoped key `activemodel.errors.models.<model>.attributes.<attr>.sec_id` (the generic `errors.messages.sec_id` is not consulted); `message:` is the general override.
- `lib/sec_id/railtie.rb` defines `SecID::Railtie < Rails::Railtie` with an `initializer` that requires `sec_id/active_model` after the framework boots. It is loaded only by the guarded last line of `lib/sec_id.rb` (`require 'sec_id/railtie' if defined?(Rails::Railtie)`), which is inert outside Rails.
- CI verifies the adapter across a Rails-version matrix (7.2, 8.0, 8.1, head) on Ruby 4.0 via `gemfiles/rails_*.gemfile` (each `eval_gemfile`s the root `Gemfile` and pins `activemodel`/`railties`; the root `Gemfile` only declares them unpinned when not run through a `gemfiles/` variant). `rails_head` is `continue-on-error`.

### Concerns (`lib/sec_id/concerns/`)

#### Normalizable (`normalizable.rb`)

Provides normalization and display formatting methods. Defines `SEPARATORS` constant (`/[\s-]/` by default).
- Class methods: `normalize(id)`, `to_pretty_s(id)`
- Instance methods: `normalized`, `normalize` (alias), `normalize!`, `to_pretty_s`, `to_s`, `to_str`
- `to_pretty_s` returns a human-readable formatted string or `nil` for invalid input; subclasses override for type-specific formatting (IBAN/LEI: 4-char groups, ISIN/CUSIP/FIGI: component-separated, OCC: space-separated components, Valoren: thousands grouping)

#### Validatable (`validatable.rb`)

Provides validation methods. Defines `ERROR_MAP` constant (maps error code symbols to exception classes).
- Class methods: `valid?(id)`, `validate(id)` (returns instance), `validate!(id)`, `error_class_for(code)`
- Instance methods: `valid?`, `validate` (eagerly triggers errors, returns self), `errors` (memoized, returns `Errors`), `validate!`
- Private methods: `valid_format?`, `error_codes`, `detect_errors`, `valid_length?`, `valid_characters?`, `checksum_width`, `validation_message`, `build_error`

#### Checkable (`checkable.rb`)

Provides checksum validation and calculation for identifiers with checksums. Include this in classes that have a checksum (ISIN, CUSIP, SEDOL, FIGI, LEI, IBAN, CEI, DTI, UPI).

Constants:
- `CHAR_TO_DIGITS` - Multi-digit mapping for ISIN (letters expand to two digits)
- `CHAR_TO_DIGIT` - Single-digit mapping (A=10, B=11, ..., Z=35)

Luhn algorithm variants (private):
- `luhn_sum_double_add_double(digits)` - Used by CUSIP and CEI
- `luhn_sum_indexed(digits)` - Used by FIGI
- `luhn_sum_standard(digits)` - Used by ISIN
- `reversed_digits_single(id)` - Converts identifier to reversed digit array (single-digit mapping)
- `reversed_digits_multi(id)` - Converts identifier to reversed digit array (multi-digit mapping for ISIN)

Validation overrides (private):
- `error_codes` - Returns `[:invalid_checksum]` when format is valid but checksum doesn't match
- `checksum_width` - Returns `1` (used by `Validatable#valid_length?` to allow optional checksum in length check; LEI and IBAN override → `2`)

`restore` and `to_s` use `checksum_width` to right-justify the checksum string (e.g. `5` → `"05"` for width 2). IBAN overrides `restore`/`to_s` because its checksum is mid-string.

Helper methods (private):
- `mod10`, `div10mod10`, `mod97` - Checksum calculation helpers
- `mod31_30_check_char(base, alphabet, alphabet_value)` - Shared ISO 7064 hybrid MOD 31,30 walker, parameterized by alphabet (explicit args, not `self.class::ALPHABET`, to avoid RBS's `UnknownConstant`); used by DTI and UPI
- `validate_format_for_calculation!` - Raises error if format invalid

#### v7 Deprecation Bridge (`deprecation.rb`)

The v7 rename of the check-digit concept to `checksum` ships a bridge that keeps the pre-v7 names working through v7 (all removed in v8; the `Checkable` concern name itself is unchanged):
- `SecID::Deprecation.warn(old:, new:, removed_in: 'v8')` (`lib/sec_id/deprecation.rb`) emits one `Kernel#warn` per call — no dedup, visible at Ruby's default verbosity (silenced by `-W0` / `$VERBOSE = nil`). No `category:` is passed, because `Warning[:deprecated]` defaults off and would hide the migration signal.
- Deprecated method aliases warn then delegate: instance/class `check_digit` → `checksum`, `calculate_check_digit` → `calculate_checksum`, class-level `has_check_digit?` → `has_checksum?`. Written as explicit typed methods (not metaprogrammed) so Steep sees both name sets and `STEEP_UNTYPED_BASELINE` holds. The per-type sigs narrow the deprecated `calculate_check_digit`/`self.check_digit` to the same concrete return type as their canonical counterparts (`Integer`, or `String` for DTI/UPI), so callers still on the old names during v7 keep full type precision; the `check_digit` reader stays the unified `(Integer | String)?` (an `attr_reader` can't be narrowed per subclass).
- `SecID::InvalidCheckDigitError` is a constant alias of `InvalidChecksumError` (same class object, so `rescue` under either name keeps working).
- `to_h`/`deconstruct_keys` carry both `:checksum` and a mirrored `:check_digit` key through v7 via the single `Base#components_with_deprecation_bridge` wrapper — each type's own `components` returns only `:checksum`, and the wrapper mirrors the canonical value (so the deprecated reader never fires internally). v8 removal is a one-file revert: drop the wrapper and point `to_h`/`deconstruct_keys` back at `components`.
- The `:invalid_check_digit` error code flips hard to `:invalid_checksum` with **no** dual emission (dual would duplicate `errors.details` entries). See `MIGRATION.md` for the matcher change.

#### Generatable (`generatable.rb`)

Provides generation of new, format-valid identifiers for use as test fixtures. Included in `Base`, so every type inherits a `.generate` entry point. **Generated values are valid in format only — they are not real, registered securities** (random country codes, FIGI prefixes, OCC dates, CFI category/group/attribute choices).

Constants (charset building blocks): `ALPHA`, `DIGITS`, `ALPHANUMERIC`.

Class methods (added via `included`/`extend(ClassMethods)`):
- `generate(random: Random.new)` - Builds `new(generate_body(random))`, then calls `restore!` when `has_checksum?` is true, else returns the instance
- `random_string(charset, length, random:)` (private) - Draws `length` characters from `charset` using `Array#sample(random:)`

Per-type hooks:
- Each type defines a private class-level `generate_body(random)` returning a valid body (identifier without checksum); checksum types' bodies are restored by the default `generate`
- Checksum-less types (CFI, FISN, BIC) compose the complete identifier in `generate_body`; no `restore!` is called
- IBAN composes a full-length body with a placeholder `"00"` checksum in `generate_body`; the default `generate` then calls `restore!` to replace them with the real two-digit check value
- OCC overrides `generate` entirely (via `OCC.build`)
- FIGI resamples its prefix until it is not in `RESTRICTED_PREFIXES`; IBAN generates only numeric-BBAN countries (`NUMERIC_COUNTRY_RULES`); CIK/Valoren use a random integer (not a digit char-fill) to avoid leading-zero bodies
- CFI samples each attribute position only from the letters `SecID::CFI::Tables` permits for that group (plus `X`; pure-N/A positions yield only `X`, so `K`'s `XXXX` falls out), then applies the `ED` cross-position rule — so every generated code passes strict `valid?`

#### Suggestable (`suggestable.rb`)

The repair engine for checksum-failing identifiers, opt-in `include`d by the 9 checksum types (**not** on `Base` — R9 requires non-checksum types to have no `.suggest`; and **not** folded into `Checkable`, keeping the one-capability-per-concern convention). Adds instance `#suggest` and, via `self.included(base) -> base.extend(ClassMethods)`, class-level `.suggest(str)` (which is `new(str).suggest`).

- Constants: `HOMOGLYPHS` (a frozen `Hash[String, Array[String]]` — the bidirectional homoglyph/OCR confusion table that drives enumeration *and* is the sole substitution candidate space; the recall lever, tuned via `benchmark/suggest_precision.rb`); `RANK` (`{ substitution: 0, transposition: 1, checksum: 2 }`).
- `#suggest` returns `[]` when the input is already `valid?` (nothing to repair) or not `valid_format?` (unparseable). Otherwise it enumerates, per position, the character's `HOMOGLYPHS` substitutions plus adjacent transpositions, adds the `restore` result (the `:checksum` fallback, guaranteeing the two-character-check case for LEI/IBAN), dedupes, keeps only `self.class.new(candidate).valid?` (the oracle — no false candidate escapes), classifies each survivor, and sorts by `RANK`.
- Classification is **position-agnostic** (never assumes a trailing checksum — IBAN splices mid-string): `candidate.identifier == identifier` (equal bodies) → `:checksum`; else a single differing index → `:substitution` (`:high`), or an adjacent mutual swap → `:transposition` (`:medium`). No `:low`/coincidental tier is ever generated. `checksum_suggestion` renders `from`/`to` via `checksum` + private `checksum_width` (so a 2-char check reports the full field).
- Candidate sets stay in the tens per identifier (25/37/52 for a 12/20/22-char id), not hundreds — the human-error net, not a full single-character net.

### Identifier Classes

Each identifier type (`lib/sec_id/*.rb`) implements:
- `ID_REGEX` constant with named capture groups for parsing
- `initialize` that calls `parse` and extracts components
- Type-specific attributes (e.g., `country_code`, `nsin` for ISIN; `cusip6`, `issue` for CUSIP)
- Private `components` method returning a hash of parsed attributes (read by both `#to_h` and `#deconstruct_keys`); classes with no type-specific attributes (CIK, WKN, Valoren) inherit the empty `{}` default

**Classes with checksums** (ISIN, CUSIP, SEDOL, FIGI, LEI, IBAN, CEI, DTI, UPI):
- Include `Checkable` **and** `Suggestable` concerns (the repair engine rides the checksum-as-oracle, so the two are wired together across all 9)
- Implement `calculate_checksum` with standard-specific algorithm
- LEI and IBAN override `checksum_width` → `2` (two-character checksum)
- DTI's and UPI's check "digit" is a `String` (can be a letter), not an `Integer` — the only types where this differs; `Checkable`'s `checksum`/`calculate_checksum` contracts are typed `Integer | String` to admit it

**Classes without checksums** (CIK, OCC, WKN, Valoren, CFI, FISN, BIC):
- Do not include `Checkable`
- Validation based solely on format (CFI additionally validates its category/group/attribute tables strictly — see below)

**Type-specific normalization overrides:**
- CIK: `normalized` returns `@identifier.rjust(10, '0')`; `normalize!` also updates `@padding`
- Valoren: `normalized` returns `@identifier.rjust(9, '0')`; `normalize!` also updates `@padding`
- OCC: `normalized` returns `compose_symbol(underlying, date_str, type, strike_mills)` (pads underlying to 6 chars)
- OCC, FISN: override `SEPARATORS = /-/` (spaces are structural in these formats)

**Type-specific validation overrides:**
- FIGI: `detect_errors` returns `:invalid_prefix` for restricted prefixes (BS, BM, GG, GB, GH, KY, VG)
- CFI: strict ISO 10962:2021 validation — `detect_errors` returns `:invalid_category`, `:invalid_group`, and/or `:invalid_attribute` (impermissible attribute letter, `K` code missing `XXXX`, or an `ED` cross-position rule violation); attribute checks are skipped when the group is already invalid. All tables live in `SecID::CFI::Tables` (`lib/sec_id/cfi/tables.rb`), deeply frozen via `SecID::DeepFreeze.call` (`lib/sec_id/deep_freeze.rb`, a shared recursive Hash/Array freezer also used to freeze `CFI::CATEGORIES`/`GROUPS`); `CATEGORIES`/`GROUPS`/`.categories`/`.groups_for`/`#category`/`#group` are derived from it. `#decode` returns a frozen `CFI::Classification` (`lib/sec_id/cfi/classification.rb`); returns `nil` for an invalid CFI. Its `#category`, `#group`, and each attribute are `CFI::Field` objects (`lib/sec_id/cfi/field.rb`: `#code` letter, `#name` symbol, `#label` ISO string, `#meaning`, `#to_s`/`#to_h`/`#as_json`) that define a `<name>?` predicate per symbol in the field's own domain — so `category.equity?` and `attributes.voting_right.voting?` answer, but an out-of-domain predicate raises `NoMethodError` (this scoping is what replaced the old flat value-predicates). `#attributes` is a frozen `CFI::AttributeSet` (`lib/sec_id/cfi/attribute_set.rb`) — an `Enumerable` of the attribute fields with per-meaning readers (`attributes.voting_right`) and nil-safe `#[]` (`attributes[:form]`), keyed by each position's group meaning; pure-N/A positions are omitted and `X` decodes to `:not_applicable`. `Classification#to_h`/`#as_json` serialize the nested field hashes. `CFI#category`/`#group` (bare symbols) and `components`/`to_h` (raw letters) are unchanged — decoded field objects are reachable only through `#decode`. The old category-wide equity predicates were removed (migrate to `cfi.decode.attributes.<meaning>.<value>?`)
- IBAN: `detect_errors` returns `:invalid_bban` when BBAN format doesn't match country rules; `.supported_countries` returns sorted array of all supported country codes
- OCC: `error_codes` returns `:invalid_date` when date string can't be parsed
- BIC: `detect_errors` returns `:invalid_country` when positions 5-6 are not in the recognized set (`lib/sec_id/bic/country_codes.rb`); `.countries` returns the sorted frozen set of recognized ISO 3166 / SWIFT country codes
- DTI: `calculate_checksum` consults `GRANDFATHERED_CODES` (a frozen `Hash[String, String]`, base → registered code) before running the ISO 7064 hybrid MOD 31,30 algorithm; a hit means the registry's hand-assigned code (currently only Bitcoin, `4H95J0R2` → `4H95J0R2X`) wins over the algorithmic result, and this is honored API-wide (`valid?`, `restore`, `restore!`, `checksum`) since they all route through `calculate_checksum`
- UPI (ISO 4914): 12 characters — fixed `QZ` prefix + 9-character body + 1 check character, all drawn from DTI's 30-symbol alphabet; `calculate_checksum` runs the shared `Checkable#mod31_30_check_char` over the 11 preceding characters (no grandfathered codes, no first-char restriction). A non-`QZ` string fails as `:invalid_format` via the regex (the prefix is structural, not a restricted-prefix list). Shares the 12-char length bucket with ISIN/FIGI: a digit-checked UPI that also satisfies ISIN's Luhn double-detects `[:isin, :upi]` (ISIN first, since UPI registers after it); a letter-checked UPI detects as `[:upi]` alone (KTD3)

### Conversion Methods

- `ISIN#to_cusip` - Convert ISIN to CUSIP (for CGS country codes only)
- `ISIN#to_sedol` - Convert ISIN to SEDOL (for GB, IE, GG, IM, JE, FK country codes)
- `ISIN#to_wkn` - Convert ISIN to WKN (for DE country code)
- `ISIN#to_valoren` - Convert ISIN to Valoren (for CH/LI country codes)
- `CUSIP#to_isin(country_code)` - Convert CUSIP to ISIN
- `SEDOL#to_isin(country_code = 'GB')` - Convert SEDOL to ISIN (supports GB, IE, GG, IM, JE, FK)
- `WKN#to_isin(country_code = 'DE')` - Convert WKN to ISIN
- `Valoren#to_isin(country_code = 'CH')` - Convert Valoren to ISIN (supports CH, LI)

### Errors (`lib/sec_id/errors.rb`)

Frozen, immutable value object returned by `#errors`. Contains:
- `details` — array of `{ error: Symbol, message: String }` hashes (frozen)
- `messages` — array of human-readable error message strings
- `none?` — true when no errors
- `any?` / `empty?` / `size` — collection-like query methods
- `each` — yields each error detail hash
- `to_a` — alias for `messages`
- `as_json(*)` — delegates to `details` for JSON serialization compatibility

### Error Handling

- `SecID::Error` - Base error class
- `SecID::InvalidFormatError` - Raised by `validate!` for format errors (`:invalid_length`, `:invalid_characters`, `:invalid_format`) and by `calculate_checksum` on invalid format
- `SecID::InvalidChecksumError` - Raised by `validate!` for `:invalid_checksum` (aliased as the deprecated `SecID::InvalidCheckDigitError` through v7 — see the v7 Deprecation Bridge)
- `SecID::InvalidStructureError` - Raised by `validate!` for type-specific structural errors (`:invalid_prefix`, `:invalid_category`, `:invalid_group`, `:invalid_attribute`, `:invalid_bban`, `:invalid_date`, `:invalid_country`)
- `SecID::AmbiguousMatchError` - Raised by `parse`/`parse!` when `on_ambiguous: :raise` and multiple types match
- `Validatable::ERROR_MAP` maps error code symbols to exception classes; unmapped codes default to `InvalidFormatError`
- `#validate!` returns `self` on success, raises on first error; `.validate!` returns the instance
- **Important:** Classes that include `Checkable` must implement `calculate_checksum`. If `NotImplementedError` is raised from a concrete identifier class, it indicates a missing implementation.

### RBS Type Signatures (`sig/`)

Hand-written RBS signatures mirror the core `lib/` scope (everything except `lib/sec_id/active_model.rb` and `lib/sec_id/railtie.rb`), shipped in the gem (`sig/**/*` in `spec.files`). Checked by Steep in strict mode (`Steepfile`, `configure_code_diagnostics(D::Ruby.strict)`) and verified at runtime against the spec suite by RBS::Test (`rake rbs:test`; the generated CFI per-instance methods are the documented exception — see below). `rbs` and `steep` are dev/test-only (`require: false`); the gem stays zero-runtime-dependency. `sig/manifest.yaml` declares the one stdlib dependency (`date`; `Set` is core in rbs 4.0).

Key facts for working in `sig/`:

- **`lib/**/*.rb` is byte-identical to the pre-types source — a deliberate property, not a limitation**: types were added with zero edits to the securities logic, so no checksum or classification behavior could be altered. The pragmatic choices below are driven by *inherent* runtime nilability and RBS/stdlib limits — they would remain even if `lib/` were editable, since the only alternative is dead "can't-happen" guards in checksum math (verified redundant by RBS::Test). All are documented inline in the sigs:
  - **Concern mixins**: `Base` includes the four concerns and `extend`s their `ClassMethods` (RBS doesn't run `self.included` hooks). Instance concerns use host-interface self-types (`_NormalizableHost`, `_ValidatableHost` with a refined `def class: () -> singleton(Base)`); `Checkable`'s self-type is `SecID::Base` (Base doesn't include it, so no ancestor cycle). Class-method modules use the `_IdentifierClass`/`_GeneratableClass` interfaces (whose `new` returns `Base`).
  - **`untyped` where a value is legitimately nilable but used as non-nil after runtime validation** (e.g. component readers, `identifier` overrides in SEDOL/LEI/Valoren, `@identifier` on Base). `untyped` — not a non-nil "happy-path" lie — because RBS::Test sees the real `nil` for invalid input; a non-nil type would fail the runtime gate.
  - **`restore`/`restore!`/`calculate_checksum` are declared on `Base`** (only checksum types implement them) so `Generatable#generate` and `Checkable::ClassMethods` type-check without narrowing on `has_checksum?`.
  - **Input type**: `SecID::input = String | Integer | nil` (numeric input is accepted by Valoren/CIK/CUSIP).
  - Two Steep diagnostics are relaxed in the `Steepfile` for idioms RBS simply can't express: `UnannotatedEmptyCollection` (base.rb's `regexp.match(...) || {}`) and `UnknownConstant` (`Normalizable::ClassMethods`' polymorphic `self::SEPARATORS`). Neither affects the untyped-call gate.
- **Coverage gate is a pinned baseline**, not literal zero: `Rakefile`'s `STEEP_UNTYPED_BASELINE` caps the residual untyped calls that are intrinsic, not a gap to close — receivers that are genuinely nilable at runtime (the `valid?`/`errors` design) plus idioms RBS/stdlib can't express (nilable stdlib `MatchData` in the scanner, `Array#map!`'s type-invariance, `freeze`-after-`case` in `DeepFreeze`, widening CFI table literals). Forcing them to zero would only add dead guards to checksum/classification math; `rake rbs:test` verifies them at runtime instead. `rake steep:coverage` fails if the count exceeds the baseline — lower it whenever it drops.
- **CFI dynamic methods are generated**: `Field`'s `<symbol>?` predicates and `AttributeSet`'s `<meaning>` readers are per-instance singleton methods RBS can't express per-instance, so `rake sig:cfi` emits the union of all names from `SecID::CFI::Tables` into `sig/sec_id/cfi/{field,attribute_set}.rbs` (marked generated; don't hand-edit). `tasks/cfi_signature_generator.rb` holds the walk; `spec/sig/cfi_signatures_spec.rb` regenerates in memory and fails if the committed files drift from the tables. Because these predicates/readers are defined per-instance via `define_singleton_method`, RBS::Test cannot hook them — `rake rbs:test` does **not** runtime-verify the generated CFI sigs; their guardrail is the drift spec (name-set equality against `SecID::CFI::Tables`) plus Steep's static call-site checks.
- **RBS::Test exclusions**: five specs are tagged `:rbs_test_incompatible` and skipped under `rake rbs:test` (performance/timing budgets, an alias-identity check via `#method`, a missing-keyword `ArgumentError` assertion, and the deprecation-warning `uplevel` attribution check whose stack depth the instrumentation frame shifts) — the instrumentation changes their runtime behavior; they aren't signature-conformance tests.

When editing `lib/` in the typed scope, update the corresponding `sig/` file and keep `bundle exec rake steep` / `rake steep:coverage` / `rake rbs:test` green.

## Code Style

- Ruby 3.2+ required
- Max line length: 120 characters
- RuboCop with rubocop-rspec extension
- RSpec with `expect` syntax only (no monkey patching)
- Scripts with `#!/usr/bin/env ruby` shebangs must have execute permission (`chmod +x`)

### Method Ordering (Stepdown Rule)

Follow the "Stepdown Rule" from Clean Code: methods should be ordered so that callers appear before callees. Code should read top-to-bottom like a newspaper article—high-level concepts first, implementation details below.

```ruby
# Good - caller before callee, reads top-to-bottom
def validate
  check_format
  check_value
end

def check_format
  parse_components
end

def check_value
  # ...
end

def parse_components
  # ...
end

# Bad - callees appear before callers
def parse_components
  # ...
end

def check_format
  parse_components
end

def validate
  check_format
  check_value
end
```

## Commit Message Convention

This project follows [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

Format: `<type>[optional scope]: <description>`

### Types

| Type | Description | Version bump |
|------|-------------|--------------|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `docs` | Documentation only | — |
| `style` | Formatting, whitespace | — |
| `refactor` | Code change (no feature/fix) | — |
| `perf` | Performance improvement | — |
| `test` | Adding/fixing tests | — |
| `build` | Build system or dependencies | — |
| `ci` | CI configuration | — |
| `chore` | Maintenance tasks | — |

### Breaking Changes

Use `!` after type or add `BREAKING CHANGE:` footer. Breaking changes trigger a MAJOR version bump.

### Examples

```
feat: add WKN support
fix: correct CUSIP checksum for alphanumeric input
docs: update README with LEI usage examples
refactor: extract shared Normalizable module
feat!: rename full_id to identifier across all classes
chore: bump version to 4.4.0
```

## Changelog Format

This project follows [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/).

Allowed categories in **required order**:

1. **Added** — new features
2. **Changed** — changes to existing functionality
3. **Deprecated** — soon-to-be removed features
4. **Removed** — removed features
5. **Fixed** — bug fixes
6. **Security** — vulnerability fixes

Rules:
- Categories must appear in the order listed above within each release section
- Each category must appear **at most once** per release section — always append to an existing category rather than creating a duplicate
- Do NOT use non-standard categories like "Updated", "Internal", or "Breaking changes"
- Breaking changes should be prefixed with **BREAKING:** within the relevant category (typically Changed or Removed)

## Documentation Style

All classes and methods must have YARD documentation. Follow these conventions:

- Always leave a **blank line** between the main description and `@` attributes (params, return, etc.)
- Document all public methods with description, params, and return types
- Document all private methods with params and return types, add description for complex logic
- Include `@example` blocks for non-obvious usage patterns
- Use `@raise` to document exceptions
- **Omit descriptions that just repeat the code** - if the method name and signature make it obvious, only include `@param`, `@return`, and `@raise` tags without a description

```ruby
# Good - blank line before @param
# Calculates the checksum for this identifier.
#
# @param value [String] the value to calculate
# @return [Integer] the calculated checksum
def calculate_checksum(value)
end

# Bad - no blank line
# Calculates the checksum for this identifier.
# @param value [String] the value to calculate
# @return [Integer] the calculated checksum
def calculate_checksum(value)
end
```

## Community Standards

The repository includes GitHub community standards files:

- **`CODE_OF_CONDUCT.md`** — Contributor Covenant v2.1; enforcement contact: `leonid@svyatov.com`
- **`CONTRIBUTING.md`** — development setup, code style, commit conventions, and PR process
- **`SECURITY.md`** — vulnerability reporting via GitHub Security Advisories; v5.x supported
- **`.github/ISSUE_TEMPLATE/bug_report.md`** — bug report template (version, reproduction steps, expected vs actual)
- **`.github/ISSUE_TEMPLATE/feature_request.md`** — feature request template (problem, solution, alternatives)
- **`.github/pull_request_template.md`** — PR checklist (tests, RuboCop, changelog, docs, commit format)

When creating issues or PRs, follow the templates. Commit messages must use Conventional Commits (see Commit Message Convention section).

## Pre-Commit Checklist

Before committing changes, always verify these files are updated to accurately reflect the changes:

- **CLAUDE.md** - Update this file
- **README.md** - Update usage examples, Table of Contents, and supported standards list
- **CHANGELOG.md** - Add entry under `[Unreleased]` section describing the change (use only standard Keep a Changelog categories — see Changelog Format section above)
- **sec_id.gemspec** - Update `description` if adding/removing supported standards
- **Marketing copy** - When adding major features or capabilities, ensure all descriptions stay accurate and unified: `sec_id.gemspec` (summary + description), `README.md` (tagline), GitHub repo description (via `gh repo edit --description`), and `CLAUDE.md` (architecture intro)

## Releasing a New Version

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):
- **MAJOR** — breaking changes (incompatible API changes)
- **MINOR** — new features (backwards-compatible)
- **PATCH** — bug fixes (backwards-compatible)

1. Update `lib/sec_id/version.rb` with the new version number
2. Update `CHANGELOG.md`: change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD` and add new empty `[Unreleased]` section
3. Update `README.md` installation version if needed (e.g., `~> 4.3` to `~> 4.4`)
4. Commit changes: `git commit -am "chore: bump version to X.Y.Z"`
5. Release: `bundle exec rake release` — builds the gem, creates and pushes the git tag, pushes to RubyGems.org
6. Create GitHub release at https://github.com/svyatov/sec_id/releases with notes from CHANGELOG
