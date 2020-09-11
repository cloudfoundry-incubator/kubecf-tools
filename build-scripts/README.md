# Build Scripts

This directory contains stub build scripts.

## build-go-binary

This builds a go binary; it should be run in the git repository of the binary
itself (as opposed to `kubecf-tools`).  It should be executed as:

```bash
build-go-binary [options] <config file>
```

There is only one available option, `--prefix`.  If given, then the
configuration file is expected have an extra level, where the key is the value
of the option.  This is used to be able to store multiple unrelated
configurations within the same file.

The configuration file should be a YAML document, with the following keys (where
`.` indicates a nested mapping):

Key | Description | Default | Example
-- | -- | -- | --
`package` | The package to build | `.`
`build.cgo` | Whether to allow CGO | `true` | `false`
`build.ldflags` | Linker flags | `-s -w`
`build.version-variable` | If given, the application version will be defined via `-ldflags=-X`. | | `main.appVersion`
`output.directory` | Output directory | `.`
`output.name` | Output binary name (within the output directory) | (working directory name)
`output.os` | Output binary host OS | Build host OS | `linux`
`output.arch` | Output binary host architecture | Build host architecture | `amd64`

## build-docker-image

This builds a docker image; it should be run in the git repository of the image
itself (as opposed to `kubecf-tools`).  It should be executed as:

```bash
build-docker-image [options] <config file>
```

There is only one available option, `--prefix`.  If given, then the
configuration file is expected have an extra level, where the key is the value
of the option.  This is used to be able to store multiple unrelated
configurations within the same file.

The configuration file should be a YAML document, with the following keys (where
`.` indicates a nested mapping):

Key | Description | Default | Example
-- | -- | -- | --
`dockerfile` | Path to Dockerfile to build | `Dockerfile`
`context` | Path to build context | `.` | `src/docker`
`args.*` | Build arguments | |
`repository` | Image repository | | `cfcontainerization/something`
`tag` | Image tag | (repository version) | `latest`
`type` | Enable special handling of images | | (see below)

The `type` configuration enables special handling of images; the currently
available options are:

`type` | Description
-- | --
`go` | Automatically sets `GO111MODULE=off` as a build arg if `go.mod` uses `replace`
