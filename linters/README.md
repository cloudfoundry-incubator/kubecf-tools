# Linters

## httplint.sh

Lint for URLs using http, instead of https.

The linter looks for a file __.http_exceptions__ in `pwd`. If it doesn't exist,
it excludes `127.0.0.1` & `localhost`by default. If it exists, it expects one
line for each allowed domain. The file can contain comments, starting with `#`.
