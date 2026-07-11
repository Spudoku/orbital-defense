#!/bin/sh
printf '\033c\033]0;%s\a' project.space-game
base_path="$(dirname "$(realpath "$0")")"
"$base_path/game_server.x86_64" "$@"
