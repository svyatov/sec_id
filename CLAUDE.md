# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Everything derivable from the source lives in the source. This file carries only what reading the
code cannot teach: contracts, rationale, gotchas, and repo conventions. Run `bundle exec rake -T`
for the task list, and read `lib/` for the API.

## Build and Test Commands

Standard invocations (`bundle exec rspec`, `rubocop`, `rake`, `bin/setup`, `bin/console`) work as
expected. The non-obvious ones:

- **Run tests with coverage**: `COVERAGE=1 bundle exec rspec` (opt-in via env var)
- **Type coverage gate**: `bundle exec rake steep:coverage` (fails if untyped calls exceed the pinned baseline)
- **Runtime signature check**: `bundle exec rake rbs:test` (runs the spec suite under RBS::Test)
- **Regenerate CFI dynamic-method sigs**: `bundle exec rake sig:cfi`
- **Documentation coverage gate**: `bundle exec rake yard:stats` (fails unless 100% of the public API is documented; a CI step)
- **Run benchmarks**: `bundle exec rake bench` (machine-dependent, for catching regressions)
- **Refresh lockfiles**: `bundle exec rake lock:refresh` (required after a version bump — see the release skill)

The default `rake` task is `rubocop` + `rbs` + `spec`.

## Architecture

This is a Ruby toolkit for securities identifiers (ISIN, CUSIP, CEI, SEDOL, FIGI, LEI, IBAN, CIK, OCC, WKN, Valoren, CFI, FISN, BIC, DTI, UPI) — validate, normalize, parse, detect, convert, generate, classify, calculate checksums, and repair. CFI is a full ISO 10962:2021 classifier (`CFI#decode`). Checksum-failing identifiers can be repaired via `suggest` (homoglyph + transposition candidates, confidence-ranked). Ships an opt-in ActiveModel/Rails validator that adds no runtime dependency to the zero-dependency core.

All identifier classes inherit from `SecID::Base`, which includes the `Normalizable`, `Validatable`,
and `Generatable` concerns. Checksum types additionally include `Checkable` and `Suggestable`.
`Detector` and `Scanner` are `@api private`. Read the files for the method inventories.

### Directory Layout

Standard gem layout. What `ls` doesn't tell you:

- `tasks/` — build-time helpers **not shipped in the gem** (currently `cfi_signature_generator.rb`, shared by `rake sig:cfi` and the drift spec)
- `docs/solutions/` — documented solutions to past problems (bugs, best practices, design patterns), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`); **read these when implementing or debugging in a documented area**
- `CONCEPTS.md` — shared domain vocabulary (identifier anatomy, named processes); read when orienting to the codebase or discussing domain concepts
- `sec_id.gemspec` `spec.files` ships `lib/**/*.rb`, `sig/**/*`, and select markdown — `docs/` and `examples/` are **intentionally excluded**

### Design constraints and gotchas

These are the decisions the code can't explain on its own.

**Type metadata**
- `type_key` is the single authority for the registry symbol — read by the registry, `to_h`, `explain`, the validator, `Detector`, and `Scanner`. Don't introduce a second source.
- `ID_LENGTH` has three legal shapes: fixed `Integer`, `Range`, or discrete `Array` (BIC's `[8, 11]`). `detector.rb`/`scanner.rb` read the shape via the shared `Base.length_values` / `Base.length_specificity` helpers; `validatable.rb#valid_length?` branches on all three directly.
- `deconstruct_keys(_keys)` ignores its argument and does **not** consult validity — unparseable input binds `nil` per key. There is deliberately no `deconstruct`.
- Equality is by `comparison_id` (type + normalized form), so instances work as Hash keys and in Sets.

**Detection**
- Detection is a three-stage pipeline: special-char dispatch (`/`→FISN, ` `→OCC, `*@#`→CUSIP), length lookup, then charset pre-filter before `valid?`. Adding a type means keeping all three consistent.
- Specificity sorting reads `Base.detection_priority` (checksum rank, length specificity, registration order; `Float::INFINITY` when unregistered). `#matches?` and `#first_match` are fast paths that deliberately bypass the full sort — don't "simplify" them into it.
- Detector and Scanner caches are invalidated when a new type registers.

**Checksums**
- Classes that include `Checkable` **must** implement `calculate_checksum`. A `NotImplementedError` from a concrete identifier class means that implementation is missing.
- `checksum_width` defaults to `1`; LEI and IBAN override it to `2`. `restore`/`to_s` right-justify against it (`5` → `"05"`). IBAN overrides `restore`/`to_s` outright because its checksum sits mid-string, not at the end.
- `mod31_30_check_char(base, alphabet, alphabet_value)` takes the alphabet as an **explicit argument** rather than reading `self.class::ALPHABET` — this avoids RBS's `UnknownConstant`. Don't refactor it back.
- DTI's and UPI's check "digit" is a `String` (can be a letter), not an `Integer` — the only types where this differs. `Checkable`'s contracts are typed `Integer | String` to admit it.
- DTI's `calculate_checksum` consults `GRANDFATHERED_CODES` before running ISO 7064 MOD 31,30. A hit means the registry's hand-assigned code (currently only Bitcoin, `4H95J0R2` → `4H95J0R2X`) beats the algorithmic result. Because `valid?`, `restore`, `restore!`, and `checksum` all route through `calculate_checksum`, this is honored API-wide.
- UPI's `QZ` prefix is **structural** (enforced by the regex, failing as `:invalid_format`), not a restricted-prefix list. UPI shares the 12-char bucket with ISIN/FIGI: a digit-checked UPI that also satisfies ISIN's Luhn double-detects as `[:isin, :upi]` (ISIN first, since UPI registers later); a letter-checked UPI detects as `[:upi]` alone (KTD3).

**Generation**
- **Generated values are format-valid only — they are not real, registered securities** (random country codes, FIGI prefixes, OCC dates, CFI attribute choices).
- Each type defines a private class-level `generate_body(random)`. Checksum-less types (CFI, FISN, BIC) compose the complete identifier there; OCC overrides `generate` entirely via `OCC.build`; IBAN emits a `"00"` placeholder checksum that the default `generate` then restores.
- FIGI resamples until its prefix is not in `RESTRICTED_PREFIXES`; IBAN only generates numeric-BBAN countries; CIK/Valoren use a random integer rather than a digit char-fill to avoid leading-zero bodies.
- CFI samples each attribute position only from the letters `SecID::CFI::Tables` permits for that group (plus `X`), then applies the `ED` cross-position rule — so every generated code passes strict `valid?`.

**Repair (`Suggestable`)**
- Deliberately **not** on `Base` (R9 requires non-checksum types to have no `.suggest`) and **not** folded into `Checkable` (one capability per concern). It is `include`d by the 9 checksum types.
- `HOMOGLYPHS` is the sole substitution candidate space and the recall lever — tune it via `benchmark/suggest_precision.rb`.
- The checksum is the oracle: only `self.class.new(candidate).valid?` survivors are returned. A valid candidate is **not** necessarily the intended correction.
- Classification is **position-agnostic** — never assume a trailing checksum, because IBAN splices mid-string. Equal bodies → `:checksum`; one differing index → `:substitution` (`:high`); adjacent mutual swap → `:transposition` (`:medium`). No `:low` tier is ever generated.
- Candidate sets stay in the tens (25/37/52 for a 12/20/22-char id) — this is the human-error net, not a full single-character net.

**CFI classification**
- All tables live in `SecID::CFI::Tables`, deeply frozen via `SecID::DeepFreeze.call`. `CATEGORIES`/`GROUPS`/`.categories`/`.groups_for`/`#category`/`#group` are all derived from it.
- Attribute checks are **skipped when the group is already invalid**.
- `CFI::Field` predicates are scoped to the field's own domain: `category.equity?` and `attributes.voting_right.voting?` answer, but an out-of-domain predicate raises `NoMethodError`. This scoping replaced the old flat category-wide value predicates (migrate to `cfi.decode.attributes.<meaning>.<value>?`).
- Decoded field objects are reachable **only** through `#decode`. `CFI#category`/`#group` return bare symbols and `components`/`to_h` return raw letters — deliberately unchanged.
- `AttributeSet` omits pure-N/A positions and decodes `X` to `:not_applicable`.

**Errors**
- `Validatable::ERROR_MAP` maps error codes to exception classes; unmapped codes default to `InvalidFormatError`.
- `#validate!` returns `self` on success and raises on the **first** error.

### ActiveModel / Rails Validator

Optional, opt-in adapter — **never on the default `require 'sec_id'` path**, so the gem keeps zero runtime dependencies (ActiveModel/railties are dev/test deps only). `lib/sec_id/railtie.rb` is loaded only by the guarded last line of `lib/sec_id.rb`, which is inert outside Rails.

- `::SecIdValidator` is a **top-level** constant (so ActiveModel's `sec_id` → `SecIdValidator` lookup resolves it) — distinct from the `SecID` module. Don't namespace it.
- `check_validity!` fails fast at class-load on an unknown type, both `type:`/`types:` together, or an empty `types:`.
- `normalize: true` switches to the separator-lenient path and writes the canonical string back on success; agnostic/allowlist ambiguity resolves to the first matching type in registration/allowlist order (KTD5).
- No locale files ship. The only i18n override point is the attribute-scoped key `activemodel.errors.models.<model>.attributes.<attr>.sec_id` — the generic `errors.messages.sec_id` is **not** consulted. `message:` is the general override.
- The Rails-version matrix (7.2, 8.0, 8.1, head) runs via `gemfiles/rails_*.gemfile`, each `eval_gemfile`ing the root `Gemfile`; the root `Gemfile` only declares `activemodel`/`railties` unpinned when not run through a `gemfiles/` variant. `rails_head` is `continue-on-error`.

### v7 Deprecation Bridge (`deprecation.rb`)

The v7 rename of the check-digit concept to `checksum` keeps the pre-v7 names working through v7 (all removed in v8; the `Checkable` concern name itself is unchanged):

- `SecID::Deprecation.warn` emits one `Kernel#warn` per call — no dedup. It passes **no** `category:`, because `Warning[:deprecated]` defaults off and would hide the migration signal.
- Deprecated aliases are written as explicit typed methods, **not** metaprogrammed, so Steep sees both name sets and `STEEP_UNTYPED_BASELINE` holds. Per-type sigs narrow the deprecated `calculate_check_digit`/`self.check_digit` to the same concrete return type as their canonical counterparts; the `check_digit` reader stays the unified `(Integer | String)?` (an `attr_reader` can't be narrowed per subclass).
- `SecID::InvalidCheckDigitError` is a constant alias of `InvalidChecksumError` — the same class object, so `rescue` under either name works.
- `to_h`/`deconstruct_keys` carry both `:checksum` and a mirrored `:check_digit` through the single `Base#components_with_deprecation_bridge` wrapper. Each type's own `components` returns only `:checksum`, so the deprecated reader never fires internally. **v8 removal is a one-file revert**: drop the wrapper and point `to_h`/`deconstruct_keys` back at `components`.
- The `:invalid_check_digit` error code flips hard to `:invalid_checksum` with **no** dual emission (dual would duplicate `errors.details` entries). See `MIGRATION.md` for the matcher change.

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

Follow the "Stepdown Rule" from Clean Code: methods are ordered so that callers appear before
callees. Code reads top-to-bottom like a newspaper article — high-level concepts first,
implementation details below. So `validate` comes before `check_format`, which comes before
`parse_components`; never the reverse.

## Commit Message Convention

This project follows [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):
`<type>[optional scope]: <description>`, with the standard type set (`feat`, `fix`, `docs`, `style`,
`refactor`, `perf`, `test`, `build`, `ci`, `chore`).

Breaking changes use `!` after the type or a `BREAKING CHANGE:` footer, and trigger a MAJOR bump.

## Changelog Format

This project follows [Keep a Changelog v1.1.0](https://keepachangelog.com/en/1.1.0/).

- Categories must appear in this order within each release section: **Added**, **Changed**, **Deprecated**, **Removed**, **Fixed**, **Security**
- Each category appears **at most once** per release section — always append to an existing category rather than creating a duplicate
- Do NOT use non-standard categories like "Updated", "Internal", or "Breaking changes"
- Breaking changes are prefixed with **BREAKING:** within the relevant category (typically Changed or Removed)

## Documentation Style

All classes and methods must have YARD documentation. Follow these conventions:

- Always leave a **blank line** between the main description and `@` attributes (params, return, etc.)
- Document all public methods with description, params, and return types
- Document all private methods with params and return types, add description for complex logic
- Include `@example` blocks for non-obvious usage patterns
- Use `@raise` to document exceptions
- **Omit descriptions that just repeat the code** — if the method name and signature make it obvious, only include `@param`, `@return`, and `@raise` tags without a description

```ruby
# Calculates the checksum for this identifier.
#
# @param value [String] the value to calculate
# @return [Integer] the calculated checksum
def calculate_checksum(value)
end
```

## Community Standards

When creating issues or PRs, follow the templates in `.github/`. Commit messages must use
Conventional Commits (see above). Code of Conduct enforcement contact: `leonid@svyatov.com`.

## Pre-Commit Checklist

Before committing changes, always verify these files are updated to accurately reflect the changes:

- **CLAUDE.md** - Update this file
- **README.md** - Update usage examples, Table of Contents, and supported standards list
- **CHANGELOG.md** - Add entry under `[Unreleased]` section describing the change (use only standard Keep a Changelog categories — see Changelog Format section above)
- **sec_id.gemspec** - Update `description` if adding/removing supported standards
- **Marketing copy** - When adding major features or capabilities, ensure all descriptions stay accurate and unified: `sec_id.gemspec` (summary + description), `README.md` (tagline), GitHub repo description (via `gh repo edit --description`), and `CLAUDE.md` (architecture intro)

## Releasing a New Version

See the `release` skill (`.claude/skills/release/SKILL.md`) for the full procedure.

**There is no local publish path.** `rake release` is deliberately absent (see the `Rakefile`
header); publishing runs only in CI through RubyGems trusted publishing, so no API key exists on
any machine.
