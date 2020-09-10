#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'fileutils'
require 'open3'

require_relative 'lib/utils'
require_relative '../versioning/versioning'

# DockerImageBuilder is a collection of methods to spawn a `docker build` command.
class DockerImageBuilder
  include Utils

  def default_config
    YAML.safe_load <<~END_OF_DEFAULT_CONFIG
      context: .
      args: {}
    END_OF_DEFAULT_CONFIG
  end

  def image_tag(config)
    raise 'No repository configured' unless config.repository

    tag = config.tag || Versioning.current_version
    "#{config.repository}:#{tag}"
  end

  def build_command(config)
    args = config.args.to_h

    handler = :"handle_type_#{config.type}"
    method(handler).call config, args if methods.include? handler

    cmd = ['docker', 'build', '--tag', image_tag(config)]
    args.each_pair.sort.each do |k, v|
      cmd << '--build-arg' << "#{k}=#{v}"
    end
    cmd << '--file' << config.dockerfile if config.dockerfile
    cmd << config.context
  end

  def handle_type_go(config, args)
    # Check if any module has local replacements; we only need to do the special
    # handling if we do.
    Dir.chdir config.context do
      cmd = ['go', 'list', '-m', '-f',
             '{{ if .Replace }}{{ .Replace.Path }}{{ end }}', 'all']
      stdout, status = Open3.capture2(*cmd)
      raise "Error listing modules: #{status.exitstatus}" unless status.success?
      return unless stdout.each_line.any? { |line| './'.include? line.chr }

      puts "\e[0;1;31mUsing local modules\e[0m"
      exit 1 unless Open3.pipeline(%w[go mod vendor]).first.success?
      at_exit { FileUtils.rm_r 'vendor' }
      args['GO111MODULE'] = 'off'
    end
  end

  def main
    options = parse_options(ARGV)
    config = load_config(options, default_config: default_config)
    cmd = build_command(config)
    exit 1 unless Open3.pipeline(cmd).first.success?
  end
end

DockerImageBuilder.new.main if $PROGRAM_NAME == __FILE__
