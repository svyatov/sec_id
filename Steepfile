# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature 'sig'
  check 'lib'

  # The ActiveModel adapter and Railtie live off the default require path and
  # depend on activemodel/railties stubs we intentionally don't type.
  ignore 'lib/sec_id/active_model.rb'
  ignore 'lib/sec_id/railtie.rb'

  # Strict: every implicit `untyped` (FallbackAny) is surfaced, so coverage gaps
  # cannot hide. Two diagnostics are relaxed for idioms RBS/Steep cannot express at
  # all — not a byte-identical concession (neither affects the untyped-call gate):
  #
  # - UnannotatedEmptyCollection: base.rb's `regexp.match(...) || {}` returns a bare
  #   `{}` literal whose type Steep won't infer through the `||`.
  # - UnknownConstant: Normalizable::ClassMethods reads `self::SEPARATORS` (polymorphic
  #   constant dispatch so OCC/FISN's overrides apply). An extend-module's `self` can't
  #   be typed as `singleton(Base)`, so `self::SEPARATORS` can't resolve.
  configure_code_diagnostics(
    D::Ruby.strict.merge(
      D::Ruby::UnannotatedEmptyCollection => :information,
      D::Ruby::UnknownConstant => :information
    )
  )

  # Set is a core class in rbs 4.0 (always loaded); only `date` is a library.
  library 'date'
end
