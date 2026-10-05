#!/bin/sh
set -eu
cd "$(dirname "$0")"
if [ "${MIGRATE_ON_START:-false}" = "true" ]; then
  /bin/sh ./migrate
fi
exec /bin/sh ./entrypoint.sh run
