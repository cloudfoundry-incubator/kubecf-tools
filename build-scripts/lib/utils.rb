#!/usr/bin/env ruby

# frozen_string_literal: true

require 'json'
require 'tempfile'
require 'yaml'

# Add deep_merge! to Hash
class Hash
  def deep_merge!(*hashes)
    merge!(*hashes) do |_key, old, new|
      if old.respond_to? :deep_merge!
        old.deep_merge! new
      else
        new
      end
    end
  end
end

# Top level module for misc helpers; this exists to make it easier to plop into
# random scripts.
module Utils
  # Parse command line options, returning an OpenStruct with the following keys:
  # prefix: The config file prefix to use
  # config: The path to the config file to load
  def parse_options(argv)
    options = OpenStruct.new
    OptionParser.new do |opts|
      opts.on('-p', '--prefix=', :REQUIRED, 'Configuration prefix')
    end.parse!(argv, into: options)

    raise OptionParser::MissingArgument, 'configuration file' if argv.empty?

    options.config = argv.first
    options
  end

  # Load the configuration file from the given file, merging it with defaults.
  def load_config(options, default_config: {})
    config = YAML.load_file(options.config, fallback: nil)
    if config.nil?
      message = "Failed to load configuration file #{options.config}"
      raise OptionParser::InvalidArgument, message
    end

    if options.prefix
      config = config[options.prefix]
      raise <<~ERROR if config.nil?
        Configuration file #{options.config} has no prefix mapping #{options.prefix}
      ERROR
    end

    config = default_config.dup.deep_merge! config

    # Convert config to OpenStruct for ease of use
    JSON.parse(config.to_json, object_class: OpenStruct)
  end

  class << self
    include Utils
  end
end
