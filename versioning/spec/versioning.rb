require_relative '../versioning'
require 'tmpdir'

describe Versioning do
  def create_commit(file_name)
    File.write(file_name, 'Dummy content')
    `git add #{file_name}`
    `git commit --no-gpg-sign --message Dummy #{file_name}`
  end

  def create_git_dir_with_tag(tag)
    `git init`
    create_commit(tag)
    `git tag #{tag}`
  end

  def create_dummy_commit_and_tag(tag)
    create_commit(tag)
    `git tag #{tag}`
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        example.run
      end
    end
  end

  describe '.short_git_sha' do
    it 'returns first 8 git sha1 characters' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          create_git_dir_with_tag('v0.0.1')
          git_sha=`git rev-parse HEAD`
          expect(Versioning.short_git_sha).to eq(git_sha[0..7])
        end
      end
    end
  end

  describe '.verify_git!' do
    # Assuming that git is always there when running rspec
    context 'when git does not exist' do
      it 'raises an error' do
        allow(File).to receive(:executable?).and_return(false)
        expect {
          Versioning.verify_git!
        }.to raise_error(StandardError, /The command `git` does not exist!/)
      end
    end

    context 'when current is not a git dir' do
      it 'raises an error' do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            expect {
              Versioning.verify_git!
            }.to raise_error(StandardError, /The current directory `#{dir}` is not a git tree!/)
          end
        end
      end
    end

    context 'when current path is in a git dir' do
      it 'does not raise' do
        `git init`
        expect {
          Versioning.verify_git!
        }.to_not raise_error
      end
    end
  end

  describe '.verify_semver_tags!' do
    context 'when semver tag exists' do
      it 'does not raise an error' do
        create_git_dir_with_tag('v0.0.1')
        expect {
          Versioning.verify_semver_tags!
        }.not_to raise_error
      end
    end

    context 'when no semver tag exists' do
      it 'raises an error' do
        create_git_dir_with_tag('some_tag')
        expect {
          Versioning.verify_semver_tags!
        }.to raise_error(StandardError, /A git tag with an semantic version is required!/)
      end
    end

    context 'when no git tag exists' do
      it 'raises with the same error message' do
        `git init`
        expect {
          Versioning.verify_semver_tags!
        }.to raise_error(StandardError, /A git tag with an semantic version is required!/)
      end
    end
  end

  describe '.latest_semver_tag' do
    context 'when only one semver tag exists' do
      it 'returns the highest semver tag' do
        create_git_dir_with_tag('v0.0.1')
        git_sha=`git rev-parse HEAD`
        expect(Versioning.latest_semver_tag).to eq('v0.0.1')
      end
    end

    context 'when two semver tags exist' do
      it 'returns the highest semver tag' do
        create_git_dir_with_tag('v0.0.1')
        create_dummy_commit_and_tag('v0.0.2')
        git_sha=`git rev-parse HEAD`
        expect(Versioning.latest_semver_tag).to eq('v0.0.2')
      end
    end

    context 'when two semver tags exists and a non-semver-tag is the latest' do
      it 'returns the highest semver tag' do
        create_git_dir_with_tag('v0.0.1')
        create_dummy_commit_and_tag('v0.0.2')
        create_dummy_commit_and_tag('vnon_semver_tag')
        git_sha=`git rev-parse HEAD`
        expect(Versioning.latest_semver_tag).to eq('v0.0.2')
      end
    end
  end

  describe '.latest_semver' do
    context 'when the semver tag has a `v` in front' do
      it 'is ignored' do
        create_git_dir_with_tag('v0.0.1')
        git_sha=`git rev-parse HEAD`
        expect(Versioning.latest_semver).to eq('0.0.1')
      end
    end

    context 'when the semver tag has no `v` in front' do
      it 'returns the same value as `last_semver_tag`' do
        create_git_dir_with_tag('0.0.1')
        git_sha=`git rev-parse HEAD`
        expect(Versioning.latest_semver).to eq(Versioning.latest_semver_tag)
      end
    end
  end

  describe '.number_of_commits_since_tag' do
    context 'with no commit since the latest semver tag' do
      it 'returns 0' do
        create_git_dir_with_tag('v0.0.1')
        expect(Versioning.number_of_commits_since_tag).to eq('0')
      end
    end

    context 'with one commit since the latest semver tag' do
      it 'returns 1' do
        create_git_dir_with_tag('v0.0.1')
        create_commit('test')
        expect(Versioning.number_of_commits_since_tag).to eq('1')
      end
    end

    context 'with two commit since the latest semver tag' do
      it 'returns 2' do
        create_git_dir_with_tag('v0.0.1')
        create_commit('test')
        create_commit('test2')
        expect(Versioning.number_of_commits_since_tag).to eq('2')
      end

      it 'ignores non semver tags' do
        create_git_dir_with_tag('v0.0.1')
        create_commit('test')
        create_dummy_commit_and_tag('non_semver_tag')
        expect(Versioning.number_of_commits_since_tag).to eq('2')
      end
    end
  end

  describe '.current_version' do
    context 'with one commit since the tag v1.0.2' do
      it 'returns 1.0.2-1.g<short_hash>' do
        create_git_dir_with_tag('v1.0.2')
        create_commit('test')
        expect(Versioning.current_version).to match(/^1.0.2-1\.g\h{8}$/)
      end
    end
  end
end
