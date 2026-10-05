#!/bin/sh
set -eu
usage() {
  echo "usage: scripts/rename.sh <package_name> [namespace]"
  echo "  package_name  Gleam package / OTP application, e.g. billing_api"
  echo "  namespace     source namespace replacing 'app', e.g. billing (defaults to package_name)"
  exit 1
}
[ $# -ge 1 ] || usage
package="$1"
namespace="${2:-$1}"
for name in "$package" "$namespace"; do
  echo "$name" | grep -Eq '^[a-z][a-z0-9_]*$' || { echo "'$name' must be snake_case"; exit 1; }
done
case "$package" in gleam_*) echo "the gleam_ prefix is reserved"; exit 1 ;; esac

cd "$(dirname "$0")/.."
[ -d src/app ] || { echo "src/app not found: already renamed?"; exit 1; }

files=$(grep -rlE "api_starter|app/|app@|app_ffi|app_smtp_ffi|app_test_ffi|app_rate_limits|app_admission|app_db_pool|app_email_queue|app_seed_pool" \
  --include='*.gleam' --include='*.erl' --include='*.toml' --include='*.md' --include='*.yml' --include='*.py' --include='*.js' --include='*.sh' \
  --include=Dockerfile . | grep -v '^./build/' | grep -v '^./scripts/rename.sh$')

for file in $files; do
  sed -i.bak \
    -e "s/api_starter/${package}/g" \
    -e "s#import app/#import ${namespace}/#g" \
    -e "s#src/app/#src/${namespace}/#g" \
    -e "s#test/app/#test/${namespace}/#g" \
    -e "s#-m app/#-m ${namespace}/#g" \
    -e "s#\`app/#\`${namespace}/#g" \
    -e "s/app@/${namespace}@/g" \
    -e "s/app_ffi/${namespace}_ffi/g" \
    -e "s/app_smtp_ffi/${namespace}_smtp_ffi/g" \
    -e "s/app_test_ffi/${namespace}_test_ffi/g" \
    -e "s/app_rate_limits/${namespace}_rate_limits/g" \
    -e "s/app_admission/${namespace}_admission/g" \
    -e "s/app_db_pool/${namespace}_db_pool/g" \
    -e "s/app_email_queue/${namespace}_email_queue/g" \
    -e "s/app_seed_pool/${namespace}_seed_pool/g" \
    "$file"
  rm -f "$file.bak"
done

mv src/app "src/${namespace}"
mv test/app "test/${namespace}"
mv src/api_starter.gleam "src/${package}.gleam"
mv test/api_starter_test.gleam "test/${package}_test.gleam"
mv src/app_ffi.erl "src/${namespace}_ffi.erl"
mv src/app_smtp_ffi.erl "src/${namespace}_smtp_ffi.erl"
mv test/app_test_ffi.erl "test/${namespace}_test_ffi.erl"
rm -rf build
if command -v gleam >/dev/null 2>&1; then gleam format src test; fi

echo "Renamed to package '${package}' with namespace '${namespace}'."
echo "Next: set APP_NAME / EMAIL_FROM in docker-compose.dev.yml and .env.example, then run 'gleam test'."
