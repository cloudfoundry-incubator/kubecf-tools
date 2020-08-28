#!/usr/bin/env ruby

# Based on https://semver.org/#semantic-versioning-200 but we do support the
# common `v` prefix in front and do not allow plus elements like `1.0.0+gold`.
SUPPORTED_VERSION_FORMAT = /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?$/.freeze

class Versioning
  class << self
    def current_version
      verify_git!

      git_describe_version = `git describe --tags --abbrev=8 --dirty 2> /dev/null`.strip
      unless git_describe_version =~ SUPPORTED_VERSION_FORMAT
        if git_describe_version.include?('+')
          raise('A git tag version including plus elements is not supported!')
        else
          raise('A git tag with a semantic version is required!')
        end
      end

      version = git_describe_version.delete_prefix('v')
      if pre_release_version?(version)
        split_pre_release_identifiers(version)
      else
        version
      end
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

    def pre_release_version?(version)
      version =~ /-g\h{8}(-dirty)?$/
    end

    def additional_pre_release_identifier?(version)
      # For example, `v2.4.0-alpha-5-gcbc89373-dirty` has the additional
      # pre-release identifier `alpha` while `v2.4.0-5-gcbc89373-dirty`
      # has only the default git pre-release identifiers.
      version =~ /^[\d.]+-[\w.]+-\d+-g\h{8}(-dirty)?$/
    end

    def split_pre_release_identifiers(version)
      if additional_pre_release_identifier?(version)
        # e.g. v2.4.0-alpha.1-5-gcbc89373-dirty -> v2.4.0-alpha.1.5.gcbc89373-dirty
        version.gsub(/^([\d.]+)-(.*)-(\d+)-(g\h{8}(-dirty)?)$/, '\1-\2.\3.\4')
      else
        # e.g. v2.4.0-5-gcbc89373-dirty -> v2.4.0-5.gcbc89373-dirty
        version.gsub(/^(.*)-(\d+)-(g\h{8}(-dirty)?)$/, '\1-\2.\3')
      end
    end
  end
end

# Do not print version during rspec run.
puts Versioning.current_version if __FILE__ == $0
