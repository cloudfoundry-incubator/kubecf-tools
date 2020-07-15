require_relative '../versioning'
require 'tmpdir'

describe Versioning do
  def create_commit(file_name)
    File.write(file_name, 'Dummy content')
    `git add #{file_name}`
    `git commit --no-gpg-sign --message Dummy #{file_name}`
  end

  def create_commit_and_tag(tag)
    create_commit(tag)
    `git tag #{tag}`
  end

  def create_git_dir_with_tag(tag)
    `git init`
    create_commit(tag)
    `git tag #{tag}`
  end

  def create_uncomitted_changes(file)
    File.write(file, 'Dummy content')
    `git add #{file}`
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        example.run
      end
    end
  end
  
  describe '.current_version' do
    context 'when git does not exist' do
      it 'raises an error' do
        # Assuming that git is always there when running rspec
        allow(File).to receive(:executable?).and_return(false)
        expect {
          Versioning.current_version
        }.to raise_error(StandardError, /The command `git` does not exist!/)
      end
    end

    context 'when current dir is not a git work tree' do
      it 'raises an error' do
        expect {
          Versioning.current_version
        }.to raise_error(StandardError, /The current directory `#{Dir.getwd}` is not a git work tree!/)
      end
    end

    context 'when current dir is a git work tree"' do
      it 'does not raise' do
        create_git_dir_with_tag('v0.0.1')
        expect {
          Versioning.current_version
        }.to_not raise_error
      end
    end
    
    context 'when the current tag is a semver version' do
      it 'does not raise an error' do
        create_git_dir_with_tag('v0.0.1')
        expect {
          Versioning.current_version
        }.not_to raise_error
      end
    end

    context 'when the current tag is a not a semver version' do
      it 'raises an error' do
        create_git_dir_with_tag('some_tag')
        expect {
          Versioning.current_version
        }.to raise_error(StandardError, /A git tag with an semantic version is required!/)
      end
    end

    context 'when no git tag exists' do
      it 'raises with the same error message' do
        `git init`
        expect {
          Versioning.current_version
        }.to raise_error(StandardError, /A git tag with an semantic version is required!/)
      end
    end

    context 'when the current tag is a semver tag with a `+` element' do
      it 'raise with an error that this not supported' do
        create_git_dir_with_tag('1.0.2+gold')
        expect {
          Versioning.current_version
        }.to raise_error(StandardError, /A git tag version including plus elements is not supported!/)
      end
    end

    context 'when the current tag is a semver tag without a `v` in front' do
      it 'does not raise and returns the correct semver version' do
        create_git_dir_with_tag('1.0.2')
        expect(Versioning.current_version).to match(/^1\.0\.2$/)
      end
    end

    context 'with newer commits since the current semver tag' do
      before(:each) do
        create_git_dir_with_tag('v1.0.2')
        create_commit('test')
      end

      context 'when there are no uncommitted changes' do
        it 'returns a pre-release version without a dirty tag' do
          expect(Versioning.current_version).to match(/^1\.0\.2-1-g\h{8}$/)
        end
      end

      context 'when there are uncommitted changes' do
        context 'in files tracked by git' do
          it 'returns a pre-release version with a dirty tag' do
            create_uncomitted_changes('tracked_file')
            expect(Versioning.current_version).to match(/^1\.0\.2-1-g\h{8}-dirty$/)
          end
        end

        context 'in files not tracked by git' do
          it 'returns a pre-release version without a dirty tag' do
            File.write('some_untracked_file', 'Dummy content')
            expect(Versioning.current_version).to match(/^1\.0\.2-1-g\h{8}$/)
          end
        end
      end
    end

    context 'with no new commits since the current semver tag' do
      before(:each) do
        create_git_dir_with_tag('v1.0.2')
      end

      context 'when there are no uncommitted changes' do
        it 'returns just the release version' do
          expect(Versioning.current_version).to match(/^1\.0\.2$/)
        end
      end

      context 'when there are uncommitted changes' do
        it 'returns the release version with a dirty tag' do
          create_uncomitted_changes('tracked_file')
          expect(Versioning.current_version).to match(/^1\.0\.2-dirty$/)
        end
      end
    end
  end
end
