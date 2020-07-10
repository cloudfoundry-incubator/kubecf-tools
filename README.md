# kubecf-tools

This repository contains various helper tools for [KubeCF](https://github.com/cloudfoundry-incubator/kubecf)

## versioning

This dir contains a common versioning script. It does print the version of the current git project to stdout.

The script prints out a pre-release version if there are any commits since the current semver tag,
otherwise it just prints the latest released version.

This script is a wrapper around the functionality of `git describe --tags --dirty`.

The pre-release version is combined from the current semver tag plus the number of commits since this release and the small git sha of the latest commit with a `g` in front. If there are uncomitted changes in files tracked by git a `dirty` tag is added in the end.

`<latest-released-version>-<commits-since-release>-g<small-latest-git-sha>`

For example: `1.0.2-5.gb3f7a0c1`
