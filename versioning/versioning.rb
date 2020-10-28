#!/usr/bin/env ruby

require 'date'
require 'optparse'

def parse_options
  options = {}
  option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

    opts.on('--next [TYPE]', String, 'Prints the next version. Possible values are "major", "minor" or "patch".') do |type|
      if type.nil?
        warn('ERROR: Invalid empty value for --next')
        puts option_parser.help
        exit 1
      elsif !%w[major minor patch].include? type
        warn("ERROR: Invalid --next type '#{type}'")
        puts option_parser.help
        exit 1
      end
      options[:next_type] = type
    end
  end
  option_parser.parse!
  options
end

# Based on https://semver.org/#semantic-versioning-200 but we do support the
# common `v` prefix in front and do not allow plus elements like `1.0.0+gold`.
SUPPORTED_VERSION_FORMAT = /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?$/.freeze

class Versioning
  class << self
    def current_version
      verify_git!

      tag = `git describe --tags --abbrev=0`.strip

      unless tag =~ SUPPORTED_VERSION_FORMAT
        if tag.include?('+')
          raise('A git tag version including plus elements is not supported!')
        else
          raise('A git tag with a semantic version is required!')
        end
      end

      # Version starts being the last tag that points to a commit in the branch,
      # then it gets mutated based on a series of constraints.
      version = tag
      # If the tag doesn't point to HEAD, it's a pre-release.
      if `git tag --points-at HEAD`.strip.empty?
        # The commit timestamp should be in the format yyyymmddHHMMSS in UTC.
        git_commit_timestamp = `git show --no-patch --format="%ci" HEAD`.strip
        git_commit_timestamp = DateTime.parse(git_commit_timestamp).new_offset
        git_commit_timestamp = git_commit_timestamp.strftime("%Y%m%d%H%M%S")

        # The number of commits since last tag that points to a commits in the
        # branch.
        git_number_commits = `git rev-list --count #{version}..HEAD`.strip

        # Add `g` to the short hash to match git describe.
        git_commit_short_hash = `git rev-parse --short=8 HEAD`.strip
        git_commit_short_hash = "g#{git_commit_short_hash}"

        # The version gets assembled with the pre-release part.
        version = "#{version}-#{git_commit_timestamp}.#{git_number_commits}.#{git_commit_short_hash}"
      end
      # If there's a change in the source tree that didn't get committed, append
      # `-dirty` to the version string.
      version = "#{version}-dirty" unless `git status --short`.strip.empty?

      version = version.delete_prefix('v')
      version
    end

    def next(current_version, type)
      parts = parts(current_version)
      case type
      when 'patch'
        parts[:patch] += 1
      when 'minor'
        parts[:minor] += 1
        parts[:patch] = 0
      when 'major'
        parts[:major] += 1
        parts[:minor] = 0
        parts[:patch] = 0
      end
      # The next version only has the major, minor and patch parts.
      "#{parts[:major]}.#{parts[:minor]}.#{parts[:patch]}"
    end

    private

    def verify_git!
      raise('The command `git` does not exist!') unless git_exists?

      raise("The current directory `#{Dir.pwd}` is not a git work tree!") unless git_dir?
    end

    def git_dir?
      system('git rev-parse --is-inside-work-tree', %i[out err] => File::NULL)
    end

    def git_exists?
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |directory|
        File.executable?(File.join(directory, 'git'))
      end
    end

    def parts(version)
      {
        major: version[/^([0-9]+)\.[0-9]+\.[0-9]+.*/, 1].to_i,
        minor: version[/^[0-9]+\.([0-9]+)\.[0-9]+.*/, 1].to_i,
        patch: version[/^[0-9]+\.[0-9]+\.([0-9]+).*/, 1].to_i,
        tail: version[/^[0-9]+\.[0-9]+\.[0-9]+(.*)/, 1]
      }
    end
  end
end

# Do not print version during rspec run.
if $PROGRAM_NAME == __FILE__
  options = parse_options
  version = Versioning.current_version
  version = Versioning.next(version, options[:next_type]) unless options[:next_type].nil?
  puts version
end
