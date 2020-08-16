#!/usr/bin/env bash

set -Eeuo pipefail

create_example() {
    # let's create an example file on the fly, to not need to implement ignore
    # lists ignoring this script
    echo 'http''://example.com/fail_without_exceptions_file' > example.md
    echo 'http''://localhost/fail_with_exceptions_file' >> example.md
}

cleanup() {
    rm -f example.md .http_exceptions
}

trap cleanup EXIT

# Positive test without .http_exceptions
cleanup
create_example
if ./httplint.sh > /dev/null ; then
    # we expect to fail because example.com
    echo "FAIL: httplint.sh without .http_exceptions didn't find example.com"
    exit 1
fi

# Positive test with .http_exceptions
cleanup
create_example
cat > .http_exceptions <<EOF
# exceptions file for httplint
localhost
127.0.0.1
example.com
EOF
if ! ./httplint.sh > /dev/null ; then
    # we expect to succeed because example.com & localhost are on the exceptions
    echo "FAIL: httplint.sh with .http_exceptions found example.com, albeit it's on exceptions"
    exit 1
fi

# Negative test with .http_exceptions
cleanup
create_example
cat > .http_exceptions <<EOF
# exceptions file for httplint
localhost
127.0.0.1
local.com
EOF
if  ./httplint.sh > /dev/null ; then
    # we expect to fail because example.com is not on the exceptions
    echo "FAIL: httplint.sh with .http_exceptions failed to find example.com"
    exit 1
fi

echo "SUCCESS: httplint.sh linted correctly"
cleanup
