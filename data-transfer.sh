#!/bin/bash
set -euo pipefail

usage() {
  echo "Simple tool with parallel rsyncs to transfer data as fast as possible."
  echo "Usage: $0 <local src_dir> <user@dtn01.nersc.gov:/remote/path>" <ssh_creds_path>
  exit 1
}

if [[ $# -ne 3 ]]; then
  usage
fi

SRC="$1"
DEST="$2"
KEY="$3"

# Number of parallel jobs: default to CPU cores, override with PARALLEL_JOBS
JOBS="${PARALLEL_JOBS:-$(nproc)}"

# SSH options for high throughput, using your identity file
export RSYNC_RSH="ssh -i '$KEY' -T -c aes128-ctr -o Compression=no -o ServerAliveInterval=60"

# Common rsync flags
RSYNC_OPTS=(
  --archive        # recursive, preserve metadata
  --whole-file     # skip delta algorithm (better for large initial copies)
  --inplace        # write directly to target files
  --no-compress    # avoid rsync-level compression over already-encrypted SSH
  --partial        # keep partially transferred files for resume
  --progress       # show progress per-file
)

echo "→ Syncing '$SRC' → '$DEST' with up to $JOBS parallel streams…"

if command -v parallel &>/dev/null; then
  find "$SRC" -mindepth 1 -maxdepth 1 -printf '%P\n' \
    | parallel -j "$JOBS" --eta \
        rsync "${RSYNC_OPTS[@]}" "$SRC"/{} "$DEST"/{}
else
  echo "⚠️  GNU parallel not found; running single-stream rsync"
  rsync "${RSYNC_OPTS[@]}" --recursive "$SRC"/ "$DEST"/
fi

echo "✅ Done."
