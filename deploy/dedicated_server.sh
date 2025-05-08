#!/bin/sh
echo -ne '\033c\033]0;torpedosim\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/dedicated_server.x86_64" "$@"
