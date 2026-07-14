# frozen_string_literal: true

RSpec.describe SecID::Deprecation do
  describe '.warn' do
    it 'writes one warning naming the old name, the new name, and the removal version to stderr' do
      expect { described_class.warn(old: 'check_digit', new: 'checksum') }
        .to output(a_string_including('check_digit', 'checksum', 'v8')).to_stderr
    end

    it 'honors a custom removal version' do
      expect { described_class.warn(old: 'check_digit', new: 'checksum', removed_in: 'v9') }
        .to output(a_string_including('v9')).to_stderr
    end

    it 'is silenced at -W0 verbosity ($VERBOSE = nil)' do
      original = $VERBOSE
      $VERBOSE = nil
      expect { described_class.warn(old: 'check_digit', new: 'checksum') }.not_to output.to_stderr
    ensure
      $VERBOSE = original
    end

    it 'emits a warning on every call (no dedup)' do
      expect { 2.times { described_class.warn(old: 'a', new: 'b') } }
        .to output(/deprecated.*deprecated/m).to_stderr
    end
  end
end
