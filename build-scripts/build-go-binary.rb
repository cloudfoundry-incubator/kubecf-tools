#!/usr/bin/env ruby
# frozen_string_literal: true

# Build a go binary; please see README.md for usage.

require 'English'
require 'json'
require 'optparse'
require 'ostruct'
require 'yaml'

require_relative '../versioning/versioning'

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

# Parse command line options, returning an OpenStruct with the following keys:
# prefix: The config file prefix to use
# config: The path to the config file to load
def parse_options(argv)
  options = OpenStruct.new
  OptionParser.new do |opts|
    opts.on('-p', '--prefix=', :OPTIONAL, 'Configuration prefix')
  end.parse!(argv, into: options)

  raise OptionParser::MissingArgument, 'configuration file' if argv.empty?

  options.config = argv.first
  options
end

# Load the configuration file from the given file, merging it with defaults.
def load_config(options)
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

  default_config = YAML.safe_load <<~END_OF_DEFAULT_CONFIG
    package: .
    build:
      cgo: true
      ldflags: -s -w
    output:
      name: #{File.basename Dir.getwd}
  END_OF_DEFAULT_CONFIG
  config = default_config.deep_merge! config

  # Convert config to OpenStruct for ease of use
  JSON.parse(config.to_json, object_class: OpenStruct)
end

# Build the environment needed to build the go binary, given the configuration
# from load_config.
def build_env(config)
  {}.tap do |env|
    env['GOOS'] = config.output.os unless config.output.os.nil?
    env['GOARCH'] = config.output.arch unless config.output.arch.nil?
    env['CGO_ENABLED'] = '0' unless config.build.cgo
  end
end

# Build the command to build the go binary, given the configuration from
# load_config.
def build_command(config)
  unless config.build['version-variable'].nil?
    version = Versioning.current_version
    config.build.ldflags += " -X #{config.build['version-variable']}=#{version}"
  end
  output_dir = config.output.directory || Dir.getwd
  output_path = File.join(output_dir, config.output.name)
  cmd = 'go', 'build', "-ldflags=#{config.build.ldflags}", '-o', output_path
  cmd << config.package unless config.package.nil?

  cmd
end

def main
  config = load_config(parse_options(ARGV))
  env = build_env(config)
  cmd = build_command(config)
  exec env, *cmd
end

main if $PROGRAM_NAME == __FILE__
