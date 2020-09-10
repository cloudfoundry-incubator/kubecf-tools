# frozen_string_literal: true

require 'ostruct'

require_relative '../lib/utils'

RSpec.describe 'Hash#deep_merge!' do
  it 'merges two hashes' do
    left = { key: 'value', left: 'yes' }
    right = { key: 'other', right: 'yes' }
    result = left.deep_merge! right
    expect(result).to eq({ key: 'other', left: 'yes', right: 'yes' })
  end

  it 'merges three hashes' do
    one = { key: 1, one: 1 }
    two = { key: 2, two: 2 }
    three = { key: 3, three: 3 }
    result = one.deep_merge! two, three
    expect(result).to eq(key: 3, one: 1, two: 2, three: 3)
  end

  it 'deeply merges hashes' do
    left = { outer: { inner: 1, left: 'yes' } }
    right = { outer: { inner: 2, right: 'yes' } }
    result = left.deep_merge! right
    expect(result).to eq({ outer: { inner: 2, left: 'yes', right: 'yes' } })
  end

  it 'updates hashes in place' do
    left = { outer: { inner: 1, left: 'yes' } }
    right = { outer: { inner: 2, right: 'yes' } }
    result = left.deep_merge! right
    expect(result).to eq({ outer: { inner: 2, left: 'yes', right: 'yes' } })
    expect(left).to be result
  end

  it 'overwrites for non-hash things' do
    left = { key: [1] }
    right = { key: [2] }
    result = left.deep_merge! right
    expect(result).to eq({ key: [2] })
  end
end

RSpec.describe 'Utils.parse_options' do
  include Utils

  it 'returns an OpenStruct' do
    expect(parse_options(%w[hello])).to be_a(OpenStruct)
  end

  context 'when no prefix is specified' do
    it 'returns no prefix' do
      result = parse_options(%w[hello])
      expect(result.prefix).to be_nil
    end
  end

  context 'when prefix is specified' do
    it 'returns the expected prefix' do
      result = parse_options(%w[--prefix=hello world])
      expect(result.prefix).to eq 'hello'
    end
  end

  it 'returns the configuration file to use' do
    result = parse_options(%w[hello])
    expect(result.config).to eq 'hello'
  end

  it 'raises an error when no configuratation file is given' do
    expect { parse_options(%w[]) }
      .to raise_error(OptionParser::MissingArgument, /configuration file/)
  end
end

RSpec.describe 'Utils.load_config' do
  it 'raises error when no config is given' do
    options = OpenStruct.new(config: '/dev/null')
    expect { Utils.load_config(options) }
      .to raise_error OptionParser::InvalidArgument, %r{Failed to load .*/dev/null}
  end

  # Generate a temporary config file with the given data, and try to load it.
  def load(config, default: {}, prefix: nil)
    Tempfile.create(['go-build-config-', '.yaml']) do |file|
      YAML.dump config, file
      file.close
      options = OpenStruct.new(config: file.path, prefix: prefix)
      Utils.load_config(options, default_config: default)
    end
  end

  it 'returns the loaded configuration' do
    result = load({ 'key' => 'value' })
    expect(result.key).to eq 'value'
  end

  it 'returns the configuration from the given prefix' do
    result = load({ 'prefix' => { 'key' => 'value' } }, prefix: 'prefix')
    expect(result.key).to eq 'value'
  end

  it 'raises an error if the prefix is not found' do
    expect { load({ 'key' => 'value' }, prefix: 'XX') }
      .to raise_error(/prefix mapping XX/)
  end

  it 'merges in the default configuration' do
    default = { 'hello' => 'world' }
    result = load({ 'key' => 'value' }, default: default)
    expect(result.key).to eq 'value'
    expect(result.hello).to eq 'world'
  end

  it 'overwrites defaults with given configuration' do
    default = { 'top' => { 'one' => 1, 'two' => 2 } }
    result = load({ 'top' => { 'one' => 3 } }, default: default)
    expect(result.top.one).to eq 3
    expect(result.top.two).to eq 2 # Not overridden
  end
end
