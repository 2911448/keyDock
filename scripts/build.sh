#!/bin/bash
set -euo pipefail
# Store branch builds an isolated, sandboxed preview. It never replaces dist/KeyDock.app.
exec "$(cd "$(dirname "$0")" && pwd)/store/build.sh" preview
