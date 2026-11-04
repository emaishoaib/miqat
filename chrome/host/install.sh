#!/bin/bash
#
# Registers the Miqat helper with Chrome, so the extension can start it.
# Run it again after moving the repo, because Chrome stores the helper's full path.

set -euo pipefail

HOST_NAME=com.mashoaib.miqat.timetables
EXTENSION_ID=boogfpbgcbobbphnpffeakcmokamhioi
HOST_PATH="$(cd "$(dirname "$0")" && pwd)/miqat_host.py"
HOSTS_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"

mkdir -p "$HOSTS_DIR"
cat > "$HOSTS_DIR/$HOST_NAME.json" <<EOF
{
  "name": "$HOST_NAME",
  "description": "Miqat helper for the Miqat Timetables extension",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXTENSION_ID/"]
}
EOF

echo "Registered $HOST_NAME at $HOST_PATH"
