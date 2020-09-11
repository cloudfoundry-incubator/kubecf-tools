#!/usr/bin/env ruby
# frozen_string_literal: true

# Build a go binary; please see README.md for usage.

require 'English'
require 'json'
require 'optparse'
require 'ostruct'
require 'yaml'

require_relative 'lib/utils'
require_relative '../versioning/versioning'

# GoBinaryBuilder is a collection of methods to spawn a `go build` command.
class GoBinaryBuilder
  include Utils

  def default_config
    YAML.safe_load <<~END_OF_DEFAULT_CONFIG
      package: .
      build:
        cgo: true
        ldflags: -s -w
      output:
        name: #{File.basename Dir.getwd}
    END_OF_DEFAULT_CONFIG
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
    options = parse_options(ARGV)
    config = load_config(options, default_config: default_config)
    env = build_env(config)
    cmd = build_command(config)
    exec env, *cmd
  end
end

GoBinaryBuilder.new.main if $PROGRAM_NAME == __FILE__
