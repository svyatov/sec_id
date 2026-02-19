# Contributing to SecID

Thank you for your interest in contributing! This guide will help you get started.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Development Setup

1. Fork and clone the repository
2. Run `bin/setup` to install dependencies
3. Run `bundle exec rake` to verify tests and linting pass
4. Use `bin/console` for an interactive prompt to experiment

## Running Tests and Linting

```bash
bundle exec rake          # Run both RuboCop and RSpec (recommended)
bundle exec rspec         # Run tests only
bundle exec rubocop       # Run linter only
bundle exec rubocop -a    # Auto-fix safe lint issues
```

## Code Style

- **Ruby 3.2+** required
- **Max line length:** 120 characters
- **RuboCop** with `rubocop-rspec` extension — run `bundle exec rubocop` before committing
- **RSpec** with `expect` syntax only (no monkey patching)
- Follow the **Stepdown Rule**: callers before callees, high-level methods first

## Commit Convention

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
fix: correct CUSIP check-digit for alphanumeric input
docs: update README with LEI usage examples
```

## Pull Request Process

1. **Fork** the repository and create a feature branch from `main`
2. **Write tests** for any new functionality
3. **Run `bundle exec rake`** to ensure all tests pass and RuboCop is clean
4. **Update documentation** as needed:
   - `CHANGELOG.md` — add an entry under `[Unreleased]`
   - `README.md` — update usage examples if the public API changed
5. **Commit** using Conventional Commits format
6. **Push** your branch and open a Pull Request

## What Makes a Good Contribution

### Bug Reports

- Include the SecID version, Ruby version, and OS
- Provide a minimal code snippet that reproduces the issue
- Describe expected vs actual behavior

### Feature Requests

- Explain the problem you're trying to solve
- Describe your proposed solution
- Consider alternatives you've evaluated

### Code Contributions

- Keep changes focused — one feature or fix per PR
- Add tests for new functionality
- Follow existing code patterns and conventions
- Update YARD documentation for public methods

## Questions?

Open a [GitHub issue](https://github.com/svyatov/sec_id/issues) for questions or discussion.
