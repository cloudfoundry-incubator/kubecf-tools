require 'ostruct'
require 'tempfile'
require 'yaml'

require_relative '../build-go-binary'

RSpec.describe 'Hash#deep_merge!' do
  it 'merges two hashes' do
    left = {key: 'value', left: 'yes'}
    right = {key: 'other', right: 'yes'}
    result = left.deep_merge! right
    expect(result).to eq({key: 'other', left: 'yes', right: 'yes'})
  end

  it 'merges three hashes' do
    one = {key: 1, one: 1}
    two = {key: 2, two: 2}
    three = {key: 3, three: 3}
    result = one.deep_merge! two, three
    expect(result).to eq(key: 3, one: 1, two: 2, three: 3)
  end

  it 'deeply merges hashes' do
    left = {outer: {inner: 1, left: 'yes'}}
    right = {outer: {inner: 2, right: 'yes'}}
    result = left.deep_merge! right
    expect(result).to eq({outer: {inner: 2, left: 'yes', right: 'yes'}})
  end

  it 'updates hashes in place' do
    left = {outer: {inner: 1, left: 'yes'}}
    right = {outer: {inner: 2, right: 'yes'}}
    result = left.deep_merge! right
    expect(result).to eq({outer: {inner: 2, left: 'yes', right: 'yes'}})
    expect(left).to be result
  end

  it 'overwrites for non-hash things' do
    left = {key: [1]}
    right = {key: [2]}
    result = left.deep_merge! right
    expect(result).to eq({key: [2]})
  end
end

RSpec.describe '#parse_options' do
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

RSpec.describe '#load_config' do
  it 'raises error when no config is given' do
    options = OpenStruct.new(config: '/dev/null')
    expect { load_config(options) }
      .to raise_error OptionParser::InvalidArgument, /Failed to load .*\/dev\/null/
  end

  # Generate a temporary config file with the given data, and try to load it.
  def load(config, prefix: nil)
    Tempfile.create(['go-build-config-', '.yaml']) do | file|
      YAML.dump config, file
      file.close
      load_config(OpenStruct.new(config: file.path, prefix: prefix))
    end
  end

  it 'returns the loaded configuration' do
    result = load({'key' => 'value'})
    expect(result.key).to eq 'value'
  end

  it 'returns the configuration from the given prefix' do
    result = load({'prefix' => {'key' => 'value'}}, prefix: 'prefix')
    expect(result.key).to eq 'value'
  end

  it 'raises an error if the prefix is not found' do
    expect { load({'key' => 'value'}, prefix: 'XX') }
      .to raise_error /prefix mapping XX/
  end

  it 'merges in the default configuration' do
    result = load({'key' => 'value'})
    expect(result.key).to eq 'value'
    expect(result.build.ldflags).to eq '-s -w'
  end

  it 'overwrites defaults with given configuration' do
    result = load({'build' => {'ldflags' => 'override'}})
    expect(result.build.ldflags).to eq 'override'
    expect(result.build.cgo).to eq true # Not overridden
  end

  it 'sets a reasonable default output path' do
    result = load({})
    expect(result.output.name).to eq File.basename(Dir.getwd)
  end
end

RSpec.describe '#build_env' do
  before(:example) do
    Tempfile.create(['go-build-config-', 'yaml']) do |file|
      YAML.dump({}, file)
      file.close
      @config = load_config(OpenStruct.new(config: file.path))
    end
  end

  it 'sets nothing by default' do
    result = build_env(@config)
    expect(result).to be_empty
  end

  it 'sets GOOS as requested' do
    @config.output.os = 'haiku'
    result = build_env(@config)
    expect(result).to eq 'GOOS' => 'haiku'
  end

  it 'sets GOARCH as requested' do
    @config.output.arch = 'z80'
    result = build_env(@config)
    expect(result).to eq 'GOARCH' => 'z80'
  end

  it 'disables CGO as requested' do
    @config.build.cgo = false
    result = build_env(@config)
    expect(result).to eq 'CGO_ENABLED' => '0'
  end
end

RSpec.describe '#build_command' do
  before(:example) do
    Tempfile.create(['go-build-config-', 'yaml']) do |file|
      YAML.dump({build: {ldflags: '-v'}}, file)
      file.close
      @config = load_config(OpenStruct.new(config: file.path))
    end

    @output = File.join(Dir.getwd, File.basename(Dir.getwd))
  end

  it 'generates a reasonable default build command' do
    result = build_command(@config)
    expect(result).to eq ['go', 'build', '-ldflags=-v', '-o', @output, '.']
  end

  it 'sets the version variable' do
    allow(Versioning).to receive(:current_version).and_return('0.0.0')
    @config.build['version-variable'] = 'pikachu'
    result = build_command(@config)
    ldflags = '-v -X pikachu=0.0.0'
    expect(result).to eq ['go', 'build', "-ldflags=#{ldflags}", '-o', @output, '.']
  end

  it 'allows overriding the output directory' do
    @config.output.directory = '/tmp'
    result = build_command(@config)
    output = File.join('/tmp', File.basename(Dir.getwd))
    expect(result).to eq ['go', 'build', '-ldflags=-v', '-o', output, '.']
  end

  it 'allows overriding the output binary name' do
    @config.output.name = 'hello'
    result = build_command(@config)
    output = File.join(Dir.getwd, 'hello')
    expect(result).to eq ['go', 'build', '-ldflags=-v', '-o', output, '.']
  end

  it 'allows overriding the package name' do
    @config.package = 'main'
    result = build_command(@config)
    expect(result).to eq ['go', 'build', '-ldflags=-v', '-o', @output, 'main']
  end
end
