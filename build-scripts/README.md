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
