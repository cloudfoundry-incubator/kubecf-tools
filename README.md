# kubecf-tools

This repository contains various helper tools for [KubeCF](https://github.com/cloudfoundry-incubator/kubecf)

## versioning

This dir contains a common versioning script which prints the version of the current git commit to stdout.

This script is a wrapper around the functionality of `git describe --tags --dirty` and requires the latest tag of the current branch to be a semver version, otherwise it raises an exception.

If the latest commit is not tagged by a semver tag then a pre-release version is printed.

`<latest-released-version>-<commits-since-release>-g<small-latest-git-sha>[-<dirty-tag>]`

For example: `1.0.2-5-gb3f7a0c1-dirty`
