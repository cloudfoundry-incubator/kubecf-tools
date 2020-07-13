#!/usr/bin/env ruby

GIT_VERSION_COMMAND='git describe --tags --abbrev=8 --dirty 2> /dev/null'
# Based on https://semver.org/#semantic-versioning-200 but allows `v` in front to match git tags
GIT_SEMVER_REGEX=/^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/

class Versioning
  class << self
    def current_version
      verify_git!
      verify_semver_tags!
      version=`#{GIT_VERSION_COMMAND}`.strip
      version.gsub(/^v?(.*)$/, '\1')
    end

    private

    def verify_git!
      unless git_exists?
        raise('The command `git` does not exist!')
      end

      unless git_dir?
        raise("The current directory `#{Dir.pwd}` is not a git work tree!")
      end
    end
    
    def verify_semver_tags!
      unless `#{GIT_VERSION_COMMAND}`.strip =~ GIT_SEMVER_REGEX
        raise('A git tag with an semantic version is required!')
      end
    end

    def git_dir?
      system('git rev-parse --is-inside-work-tree', [:out, :err] => File::NULL)
    end

    def git_exists?
      ENV['PATH'].split(File::PATH_SEPARATOR).any? do |directory|
        File.executable?(File.join(directory, 'git'))
      end
    end
  end
end

# Do not print version during rspec run
if __FILE__ == $0
  puts Versioning.current_version
end