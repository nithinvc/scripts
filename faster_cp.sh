#!/usr/bin/env bash
# fast parallel drop-in replacement for `cp src dst`
# requires: GNU parallel, bash, coreutils

set -euo pipefail
if [[ $# -ne 2 ]]; then
    echo "Usage: $(basename "$0") SRC DST" >&2
    exit 1
fi

SRC="$1"
DST="$2"

# If SRC is a file or symlink → single-threaded cp -p
if [[ -L "$SRC" ]] || [[ -f "$SRC" ]]; then
    cp -p "$SRC" "$DST"
    exit
fi

# If SRC is a directory → recursive, parallelized
if [[ -d "$SRC" ]]; then
    # ensure destination dir exists
    mkdir -p "$DST"

    # export for GNU parallel subprocesses
    export SRC DST

    # 1) Recreate directory tree
    find "$SRC" -mindepth 1 -type d -print0 \
      | parallel -0 --jobs 0 bash -c '
          src="$1"; dst="$2"; dir="$0"
          rel="${dir#${src}/}"
          mkdir -p "${dst}/${rel}"
        ' {} "$SRC" "$DST"

    # 2) Copy symlinks (as links, not targets)
    find "$SRC" -type l -print0 \
      | parallel -0 --jobs 0 bash -c '
          src="$2"; dst="$3"; link="$1"
          rel="${link#${src}/}"
          ln -snf "$(readlink "$link")" "${dst}/${rel}"
        ' _ {} "$SRC" "$DST"

    # 3) Copy regular files, preserving mode/timestamps
    find "$SRC" -type f -print0 \
      | parallel -0 --jobs 0 bash -c '
          src="$2"; dst="$3"; file="$1"
          rel="${file#${src}/}"
          cp -p "$file" "${dst}/${rel}"
        ' _ {} "$SRC" "$DST"

    exit
fi

# else, SRC not found
echo "cp: cannot stat '$SRC': No such file or directory" >&2
exit 1
