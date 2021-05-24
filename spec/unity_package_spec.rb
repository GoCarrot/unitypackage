# frozen_string_literal: true

require 'tempfile'
require 'tmpdir'

RSpec.describe UnityPackage::UnityPackage do
  let(:unitypackage_fixture) { 'spec/fixtures/UnityUIExtensions-2019-6.unitypackage' }
  let(:external_python) { 'spec/external/extractunitypackage.py' }

  describe '#initialize' do
    subject { described_class.new }

    it { is_expected.to have_attributes(missing_meta_error: true) }

    context 'without missing_meta_error' do
      subject { described_class.new(missing_meta_error: false) }

      it { is_expected.to have_attributes(missing_meta_error: false) }
    end

    context 'with a .unitypackage file specified' do
      subject { described_class.new unitypackage_fixture }

      it { is_expected.to have_attributes(missing_meta_error: true) }
    end
  end

  describe '#write' do
    subject do
      Dir.mktmpdir do |dir|
        reconstructed = "#{dir}/Reconstructed.unitypackage"
        File.open(reconstructed, 'wb') do |file|
          described_class.new(unitypackage_fixture).write(file)
        end
        return `python #{external_python} #{reconstructed} #{dir}`
      end
    end

    let(:fixture) do
      Dir.mktmpdir do |dir|
        return `python #{external_python} #{unitypackage_fixture} #{dir}`
      end
    end

    it { is_expected.to eql fixture }
  end

  describe '#<<' do
    subject(:package) { described_class.new }

    context 'when adding a file that does not have a .meta file' do
      it 'is expected to raise IOError' do
        expect { package << external_python }.to raise_error(IOError)
      end
    end

    context 'when adding multiple files' do
      it 'is expected to add all of the files' do
        package << Dir['spec/fixtures/package_contents/Assets/**/*']
        expect(package.count).to eql 6
      end
    end
  end
end
