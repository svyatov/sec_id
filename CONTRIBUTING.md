# Contributing to SecID

Thank you for your interest in contributing! This guide will help you get started.

## Code of conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Development setup

1. Fork and clone the repository
2. Run `bin/setup` to install dependencies
3. Run `bundle exec rake` to verify tests and linting pass
4. Use `bin/console` for an interactive prompt to experiment

## Running tests and linting

```bash
bundle exec rake          # Run RuboCop, RBS validation, and RSpec (recommended)
bundle exec rspec         # Run tests only
bundle exec rubocop       # Run linter only
bundle exec rubocop -a    # Auto-fix safe lint issues
```

## Changing dependencies

The lockfiles are committed and CI installs them frozen, so a dependency change is not complete until
the lockfiles are regenerated:

```bash
bundle exec rake lock:refresh   # relocks the root Gemfile and the Rails matrix gemfiles
```

CI runs Ruby 3.3 through 4.0 against a single lockfile. Bundler resolves against whichever Ruby you
run, so a lock written on a newer Ruby can pin a gem that will not install on 3.3, and only the oldest
jobs fail. If that happens, pin the offending gem in the `Gemfile` with a comment saying when the pin
can be lifted.

## Code style

- **Ruby 3.3+** required
- **Max line length:** 120 characters
- **RuboCop** with `rubocop-rspec` extension, run `bundle exec rubocop` before committing
- **RSpec** with `expect` syntax only (no monkey patching)
- Follow the **Stepdown Rule**: callers before callees, high-level methods first

## Commit convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Format: `<type>[optional scope]: <description>`

| Type       | Description                    |
|------------|--------------------------------|
| `feat`     | New feature                    |
| `fix`      | Bug fix                        |
| `docs`     | Documentation only             |
| `style`    | Formatting, whitespace         |
| `refactor` | Code change (no feature/fix)   |
| `perf`     | Performance improvement        |
| `test`     | Adding/fixing tests            |
| `build`    | Build system or dependencies   |
| `ci`       | CI configuration               |
| `chore`    | Maintenance tasks              |

Examples:

```
feat: add WKN support
fix: correct CUSIP checksum for alphanumeric input
docs: update README with LEI usage examples
```

## Pull request process

1. **Fork** the repository and create a feature branch from `main`
2. **Write tests** for any new functionality
3. **Run `bundle exec rake`** to ensure all tests pass and RuboCop is clean
4. **Update documentation** as needed:
   - `CHANGELOG.md`: add an entry under `[Unreleased]`
   - `README.md`: update usage examples if the public API changed
5. **Commit** using Conventional Commits format
6. **Push** your branch and open a Pull Request

## What makes a good contribution

### Bug reports

- Include the SecID version, Ruby version, and OS
- Provide a minimal code snippet that reproduces the issue
- Describe expected vs actual behavior

### Feature requests

- Explain the problem you're trying to solve
- Describe your proposed solution
- Consider alternatives you've evaluated

### Code contributions

- Keep changes focused: one feature or fix per PR
- Add tests for new functionality
- Follow existing code patterns and conventions
- Update YARD documentation for the public API. 100% coverage is enforced in CI (`bundle exec rake yard:stats`)

## Deprecation policy

Nothing in the public API is removed without a released warning first.

1. Deprecate in a MINOR release. The old path keeps working.
2. The notice names the replacement and the earliest version that removes it. For a method, that is a runtime warning through `SecID::Deprecation.warn`.
3. Remove no earlier than the next MAJOR release.

The v7 rename of `check_digit` to `checksum` is the worked example: v7.0.0 kept every old name working behind a warning naming its replacement and v8 as the removal version. Releases before v7 did not follow this, and their `Removed` entries have no matching `Deprecated` entry.

See [Versioning](README.md#versioning) for what counts as public API.

## Governance

SecID has one maintainer, [Leonid Svyatov](https://github.com/svyatov). They review and merge every
change, and they publish every release. There is no steering group, no vote, and no second person who
can merge.

No succession is arranged. If the maintainer stops, the project stops with them. The MIT license lets
anyone fork and continue from the last published state, and that is the intended fallback.

## Questions?

Open a [discussion](https://github.com/svyatov/sec_id/discussions) for questions, ideas, and anything
that is not a defect. The [issue tracker](https://github.com/svyatov/sec_id/issues) is for bug reports
and feature requests.
