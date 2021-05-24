# frozen_string_literal: true

RSpec.describe UnityPackage do
  it 'has a version number' do
    expect(UnityPackage::VERSION).not_to be nil
  end
end
