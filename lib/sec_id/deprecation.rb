# frozen_string_literal: true

module SecID
  # Emits standardized, silenceable deprecation warnings for the v7 → v8 rename
  # bridge. Stateless: warns on every call with no per-call-site dedup, so the
  # migration signal is never suppressed by default.
  #
  # The warning is written via {Kernel#warn} at Ruby's default verbosity — it is
  # visible unless the process runs with `-W0` / `$VERBOSE = nil`. No `category:`
  # is passed, because `Warning[:deprecated]` defaults to `false` and would hide
  # the bridge warning the rename relies on.
  module Deprecation
    # Emits a standardized deprecation warning for a renamed API name.
    #
    # @param old [String] the deprecated name
    # @param new [String] the canonical replacement name
    # @param removed_in [String] the version that removes the deprecated name
    # @return [void]
    def self.warn(old:, new:, removed_in: 'v8')
      Kernel.warn(
        "SecID: `#{old}` is deprecated and will be removed in #{removed_in}; use `#{new}` instead.",
        uplevel: 2
      )
    end
  end
end
