# frozen_string_literal: true

module SecID
  # Auto-activates the ActiveModel validator inside a Rails application.
  #
  # It is loaded only through the guarded require at the end of `lib/sec_id.rb`
  # (`require 'sec_id/railtie' if defined?(Rails::Railtie)`), so it is never referenced outside
  # Rails and the default `require 'sec_id'` path stays free of Rails/ActiveModel. The initializer
  # requires `sec_id/active_model` after the framework has booted, when ActiveModel is guaranteed
  # present — so a Rails app needs no `require:` option and no initializer of its own.
  class Railtie < ::Rails::Railtie
    initializer('sec_id.active_model') { require 'sec_id/active_model' }
  end
end
