# frozen_string_literal: true

require 'open3'

# AE6 / R2 / R3 — end-to-end Railtie activation and the explicit-require guard.
#
# Both cases run in fresh subprocesses: booting a real Rails application requires `require 'rails'`
# to precede `require 'sec_id'` (so the guarded railtie require fires), and the main test process
# has already loaded sec_id without Rails.
RSpec.describe 'SecID::Railtie' do
  let(:libdir) { File.expand_path('../../lib', __dir__) }

  # Boots a real Rails app (rails required before sec_id, so the guarded railtie require fires),
  # then validates through the auto-loaded validator with no explicit `require 'sec_id/active_model'`.
  let(:boot_script) do
    <<~RUBY
      require 'rails'
      require 'sec_id'

      class DummyApp < Rails::Application
        config.eager_load = false
        config.secret_key_base = 'test'
      end
      Rails.application.initialize!

      abort 'validator not auto-loaded' unless defined?(SecIdValidator)

      model = Class.new do
        include ActiveModel::Validations
        attr_accessor :isin
        validates :isin, sec_id: { type: :isin }
        define_singleton_method(:name) { 'Security' }
      end

      good = model.new.tap { |m| m.isin = 'US0378331005' }
      bad  = model.new.tap { |m| m.isin = 'US0378331004' }
      abort 'good ISIN rejected' unless good.valid?
      abort 'bad ISIN accepted'  if bad.valid?
      puts 'BOOT_OK'
    RUBY
  end

  it 'auto-activates the validator when a Rails app boots (no explicit require)' do
    out, status = Open3.capture2e('bundle', 'exec', 'ruby', '-I', libdir, '-e', boot_script)

    expect(out).to include('BOOT_OK')
    expect(status).to be_success, out
  end

  it "require 'sec_id/active_model' fails with a clear error when ActiveModel is absent (R3)" do
    # Strip Bundler/RubyGems env and --disable-gems so `require 'active_model'` raises LoadError,
    # while -Ilib keeps the dependency-free sec_id core requirable.
    clean_env = %w[RUBYOPT RUBYLIB GEM_HOME GEM_PATH BUNDLE_GEMFILE].to_h { |k| [k, nil] }
    out, status = Open3.capture2e(
      clean_env, RbConfig.ruby, '--disable-gems', '-I', libdir, '-e', "require 'sec_id/active_model'"
    )

    expect(status).not_to be_success
    expect(out).to include('ActiveModel')
  end
end
