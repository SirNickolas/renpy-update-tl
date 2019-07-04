#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n'
[ $# = 2 ] || exit 2

readonly PREFIX="$1"
readonly DLL_FILE="$2"
[ -f "$DLL_FILE" ]

# https://stackoverflow.com/questions/26738025/gtk-icon-missing-when-running-in-ms-windows/34673860#34673860
GTK_PREFIX="`which libgtk-3-0.dll`"
readonly GTK_PREFIX="${GTK_PREFIX%/*/*}"
mkdir -p -- "$PREFIX/"{bin,lib,share/{glib-2.0/schemas,icons/{Adwaita,hicolor},locale}}

put() {
    local -r path="$1"
    shift
    cp -r -- "${@/#/$GTK_PREFIX/$path/}" "$PREFIX/$path/"
}

! sed -E 's_\\_/_g; s_^(\w):/_/\1/_' <"$DLL_FILE" | grep -vi "^$GTK_PREFIX/" >&2 || exit 1
readonly DLLS=(`sed -E 's_\\\\_/_g; s_^(\w):/_/\1/_' <"$DLL_FILE" | grep -i "^$GTK_PREFIX/bin/"`)
cp -- "${DLLS[@]}" "$PREFIX/bin/"
put lib/ gdk-pixbuf-2.0/
put share/glib-2.0/schemas/ gschemas.compiled
put share/icons/Adwaita/ scalable/ scalable-up-to-32/ icon-theme.cache index.theme
put share/icons/hicolor/ scalable/ icon-theme.cache index.theme
put share/locale/ en/ ru/
