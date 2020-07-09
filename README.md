# kubecf-tools

This repository contains various helper tools for [KubeCF](https://github.com/cloudfoundry-incubator/kubecf)

## versioning

This dir contains a common versioning script. It does print the version of the current git project to stdout.

The script prints out a pre-release version if there are any commits since the latest semver tag.
Otherwise it just prints the latest released version.

The pre-release version is combined from the latest release version plus the number of commits since this release and the small git sha of the latest commit with a `g` in front.

`<latest-released-version>-<commits-since-release>.g<small-latest-git-sha>`

For example: `1.0.2-5.gb3f7a0c1`