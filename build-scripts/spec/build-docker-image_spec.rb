#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'ostruct'

require_relative '../build-docker-image'
require_relative '../lib/utils'

# Add helper to convert Hash to OpenStruct recursively
class Hash
  def to_ostruct
    JSON.parse(to_json, object_class: OpenStruct)
  end
end

RSpec.describe DockerImageBuilder do
  before :example do
    @instance = described_class.new
  end
  attr_reader :instance

  def default_config
    instance.default_config
  end

  describe '#image_tag' do
    it 'requires a repository' do
      expect { instance.image_tag(default_config.to_ostruct) }
        .to raise_error(/No repository configured/)
    end

    it 'uses the provided tag' do
      expect(Versioning).to_not receive :current_version
      config = { repository: 'repo/image', tag: 'latest' }.to_ostruct
      tag = instance.image_tag(config)
      expect(tag).to eq 'repo/image:latest'
    end

    it 'defaults to the current version' do
      expect(Versioning)
        .to receive(:current_version)
        .with(no_args)
        .and_return '0.0.0'
      tag = instance.image_tag({ repository: 'repo/image' }.to_ostruct)
      expect(tag).to eq 'repo/image:0.0.0'
    end
  end

  describe '#build_command' do
    it 'generates a command line' do
      config = default_config
               .deep_merge!(repository: 'r', tag: 't', context: 'src')
               .to_ostruct
      expect(config.context).to eq 'src'
      cmd = instance.build_command(config)
      expect(cmd).to eq %w[docker build --tag r:t src]
    end

    it 'inserts build arguments' do
      config = default_config
               .deep_merge!(repository: 'r', tag: 't', context: 'src', args: { a: 'b' })
               .to_ostruct
      cmd = instance.build_command(config)
      expect(cmd).to eq %w[docker build --tag r:t --build-arg a=b src]
    end

    it 'calls the type-specific handler' do
      # Extend the instance to have a method handling a new type
      instance = Class.new(described_class) do
        def handle_type_qq(_config, args)
          args['x'] = 'y'
        end
      end.new
      config = default_config
               .deep_merge!(type: 'qq', repository: 'r', tag: 't', context: 'src')
               .to_ostruct
      cmd = instance.build_command(config)
      expect(cmd).to eq %w[docker build --tag r:t --build-arg x=y src]
    end

    it 'can set the Dockerfile' do
      config = default_config
               .deep_merge!(repository: 'r', tag: 't', context: 'src', dockerfile: 'x')
               .to_ostruct
      cmd = instance.build_command(config)
      expect(cmd).to eq %w[docker build --tag r:t --file x src]
    end
  end

  describe '#handle_type_go' do
    def default_config
      { context: '.' }.to_ostruct
    end

    it 'errors out if listing go modules fails' do
      status = double('Status')
      expect(status).to receive(:success?).and_return false
      expect(status).to receive(:exitstatus).and_return 1
      expect(Open3).to receive(:capture2)
        .with('go', 'list', '-m', any_args)
        .and_return(['', status])
      expect(Open3).not_to receive :pipeline
      expect(instance).not_to receive(:exit)
      expect(instance).not_to receive :at_exit
      expect(FileUtils).not_to receive :rm_r
      expect { instance.handle_type_go(default_config, {}) }
        .to raise_error(/Error listing modules: 1/)
    end

    it 'does nothing if there are no replaced go modules' do
      status = double('Status')
      expect(status).to receive(:success?).and_return true
      expect(Open3).to receive(:capture2)
        .with('go', 'list', '-m', any_args)
        .and_return(['code.cloudfoundry.org', status])
      expect(Open3).not_to receive :pipeline
      expect(instance).not_to receive(:exit)
      expect(instance).not_to receive :at_exit
      expect(FileUtils).not_to receive :rm_r
      args = {}
      instance.handle_type_go(default_config, args)
      expect(args).to be_empty
    end

    it 'vendors dependencies if required' do
      # Override `at_exit` to ensure we don't call the real one
      instance = Class.new(described_class) do
        def at_exit; end
      end.new
      status = double('Status')
      expect(status).to receive(:success?).twice.and_return true
      expect(Open3).to receive(:capture2)
        .with('go', 'list', '-m', any_args)
        .and_return(['.', status])
      args = {}
      expect(Open3).to receive(:pipeline)
        .with(%w[go mod vendor])
        .and_return([status])
      expect(instance).not_to receive(:exit)
      expect(instance).to receive(:at_exit) do |&block|
        expect(FileUtils).to receive(:rm_r).with('vendor')
        block.call
      end
      instance.handle_type_go(default_config, args)
      expect(args).to eq({ 'GO111MODULE' => 'off' })
    end
  end
end
