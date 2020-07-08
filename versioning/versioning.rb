#!/usr/bin/env ruby

# Based on https://semver.org/#semantic-versioning-200 but allows `v` in front to match git tags
GIT_SEMVER_REGEX=/^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/

class Versioning
  class << self
    def verify_git!
      unless git_exists?
        raise('The command `git` does not exist!')
      end

      unless git_dir?
        raise("The current directory `#{Dir.pwd}` is not a git tree!")
      end
    end

    def verify_semver_tags!
      unless git_semver_tag_exists?
        raise('A git tag with an semantic version is required!')
      end
    end

    def short_git_sha
      `git rev-parse --short=8 HEAD`.strip
    end

    def latest_semver_tag
      `git tag -l --sort=v:refname`.split.select{|i| i[GIT_SEMVER_REGEX] }.last
    end

    def latest_semver
      latest_semver_tag.gsub(/^v?(.*)$/, '\1')
    end

    def number_of_commits_since_tag
      `git rev-list #{latest_semver_tag}..HEAD --count`.strip.to_i
    end

    def current_version
      if number_of_commits_since_tag > 0
        "#{latest_semver}-#{number_of_commits_since_tag}.g#{short_git_sha}"
      else
        latest_semver
      end
    end

    private

    def git_semver_tag_exists?
      `git tag`.split.any? do |tag|
        tag =~ GIT_SEMVER_REGEX
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
  Versioning.verify_git!
  Versioning.verify_semver_tags!
  puts Versioning.current_version
end
