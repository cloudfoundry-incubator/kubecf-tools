#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ostruct'
require 'tempfile'
require 'yaml'

require_relative '../build-go-binary'

RSpec.describe GoBinaryBuilder do
  def default_config
    instance.default_config
  end

  before(:example) do
    @instance = described_class.new
  end
  attr_reader :instance

  describe '#default_config' do
    it 'sets a reasonable default output path' do
      result = JSON.parse(default_config.to_json, object_class: OpenStruct)
      expect(result.output.name).to eq File.basename(Dir.getwd)
    end
  end

  describe '#build_env' do
    before(:example) do
      Tempfile.create(['go-build-config-', 'yaml']) do |file|
        YAML.dump({}, file)
        file.close
        options = OpenStruct.new(config: file.path)
        @config = instance.load_config(options, default_config: default_config)
      end
    end

    it 'sets nothing by default' do
      result = instance.build_env(@config)
      expect(result).to be_empty
    end

    it 'sets GOOS as requested' do
      @config.output.os = 'haiku'
      result = instance.build_env(@config)
      expect(result).to eq 'GOOS' => 'haiku'
    end

    it 'sets GOARCH as requested' do
      @config.output.arch = 'z80'
      result = instance.build_env(@config)
      expect(result).to eq 'GOARCH' => 'z80'
    end

    it 'disables CGO as requested' do
      @config.build.cgo = false
      result = instance.build_env(@config)
      expect(result).to eq 'CGO_ENABLED' => '0'
    end
  end

  describe '#build_command' do
    before(:example) do
      Tempfile.create(['go-build-config-', 'yaml']) do |file|
        YAML.dump({ build: { ldflags: '-v' } }, file)
        file.close
        options = OpenStruct.new(config: file.path)
        @config = instance.load_config(options, default_config: default_config)
      end

      @output = File.join(Dir.getwd, File.basename(Dir.getwd))
    end

    it 'generates a reasonable default build command' do
      result = instance.build_command(@config)
      expect(result).to eq ['go', 'build', '-ldflags=-v', '-o', @output, '.']
    end

    it 'sets the version variable' do
      allow(Versioning).to receive(:current_version).and_return('0.0.0')
      @config.build['version-variable'] = 'pikachu'
      result = instance.build_command(@config)
      ldflags = '-v -X pikachu=0.0.0'
      expect(result).to eq ['go', 'build', "-ldflags=#{ldflags}", '-o', @output, '.']
    end

    it 'allows overriding the output directory' do
      @config.output.directory = '/tmp'
      result = instance.build_command(@config)
      output = File.join('/tmp', File.basename(Dir.getwd))
      expect(result).to eq ['go', 'build', '-ldflags=-v', '-o', output, '.']
    end

    it 'allows overriding the output binary name' do
      @config.output.name = 'hello'
      result = instance.build_command(@config)
      output = File.join(Dir.getwd, 'hello')
      expect(result).to eq ['go', 'build', '-ldflags=-v', '-o', output, '.']
    end

    it 'allows overriding the package name' do
      @config.package = 'main'
      result = instance.build_command(@config)
      expect(result).to eq ['go', 'build', '-ldflags=-v', '-o', @output, 'main']
    end
  end
end
