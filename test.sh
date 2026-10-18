#!/bin/sh
# Runs the tests. With only the Command Line Tools (no Xcode), swift test does not find the
# Swift Testing macros on its own, so their plugin path is passed when it is there.
set -e
cd "$(dirname "$0")"
PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [ "$(xcode-select -p)" = /Library/Developer/CommandLineTools ] && [ -d "$PLUGINS" ]; then
  swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS"
else
  swift test
fi
