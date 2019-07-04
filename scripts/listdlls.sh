#!/usr/bin/env bash

set -euo pipefail
[ $# = 0 ] || exit 2

# https://docs.microsoft.com/en-us/sysinternals/downloads/listdlls
listdlls renpy-update-tl-gui | sed -E '/\.dll$/I !d; s/.*(\w:\\)/\1/; /:\\Windows\\/I d' | sort
