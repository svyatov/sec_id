---
name: release
description: Cut a new sec_id release — version bump, changelog, lockfile refresh, PR, signed tag, and the approval-gated CI publish to RubyGems. Use when asked to release, cut a version, bump the version, or publish the gem.
---

# Releasing a New Version

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):

- **MAJOR** — breaking changes (incompatible API changes)
- **MINOR** — new features (backwards-compatible)
- **PATCH** — bug fixes (backwards-compatible)

## Procedure

1. Update `lib/sec_id/version.rb` with the new version number
2. Update `CHANGELOG.md`: change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD` and add a new empty `[Unreleased]` section
3. Update `README.md` installation version if needed (e.g. `~> 4.3` to `~> 4.4`)
4. Run `bundle exec rake lock:refresh` — the committed lockfiles record `sec_id` as a path gem at
   its current version, and CI installs frozen, so a stale lock fails every job
5. Commit changes and open a PR: `main` requires a change request, so the bump cannot be pushed directly
6. After merging, tag the merge commit and push it:

   ```bash
   git tag -a vX.Y.Z -m "Version X.Y.Z"   # signed automatically via tag.gpgSign
   git push origin vX.Y.Z
   ```

7. Approve the `release` deployment when GitHub asks. The tag push starts
   `.github/workflows/release.yml`, which tests, builds, verifies the tag matches `SecID::VERSION`,
   and then waits for a reviewer before anything reaches RubyGems.org
8. Create the GitHub release at https://github.com/svyatov/sec_id/releases, pasting the CHANGELOG
   section for this version verbatim
9. Verify the release:

   ```bash
   git tag -v vX.Y.Z                                                  # signature
   curl -s https://rubygems.org/api/v1/attestations/sec_id-X.Y.Z.json # non-empty array
   ```

## No local publish path

`rake release` is deliberately absent (see the `Rakefile` header). Publishing runs only in CI,
authenticated through RubyGems trusted publishing, so no API key exists on any machine. Do not add
a local publish task.
