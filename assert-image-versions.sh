#!/usr/bin/env bash
# Assert that an image built from this repo carries exactly one pi version.
#
# Usage: assert-image-versions.sh <image> <expected-pi-version>
#
# Why this exists: @earendil-works/pi-coding-agent ships BOTH the SDK that
# PI WEB imports as a library and the `pi` CLI that extensions spawn, so a
# single install satisfies both. But PI WEB declares its pi peer dependencies
# as `>=0.87.0`, so a second `npm install` pass re-resolves that range against
# the registry and nests its own copy of the whole pi family under PI WEB's
# node_modules. That copy silently drifts from the pinned global one as soon as
# the registry has anything newer — the Dockerfile installs both specs in one
# pass to prevent it, and this script proves it held.
set -euo pipefail

IMG="${1:?usage: assert-image-versions.sh <image> <expected-pi-version>}"
EXPECTED="${2:?usage: assert-image-versions.sh <image> <expected-pi-version>}"

fail() { echo "::error::$*" >&2; exit 1; }

# 1. The CLI that extensions spawn.
CLI="$(docker run --rm --entrypoint pi "${IMG}" --version)"
echo "pi CLI = ${CLI}"
[ "${CLI}" = "${EXPECTED}" ] || fail "pi CLI is ${CLI}, expected ${EXPECTED}"

# 2. Every @earendil-works package anywhere in the tree. Enumerate node_modules
#    directories and list only their DIRECT @earendil-works children — a find
#    -path glob would match across slashes and pick up every transitive dep too.
#    Deliberately NOT deduplicated: a repeated line is exactly the nested-copy
#    condition this script exists to catch.
MANIFEST="$(docker run --rm --entrypoint sh "${IMG}" -c '
  find /usr/local/lib/node_modules -type d -name node_modules | sort | while read -r nm; do
    for d in "$nm"/@earendil-works/*/; do
      [ -f "${d}package.json" ] || continue
      node -p "const p=JSON.parse(require(\"fs\").readFileSync(\"${d}package.json\")); p.name+\" \"+p.version"
    done
  done
' | sort)"

echo "--- @earendil-works packages in the image ---"
echo "${MANIFEST}"

# 3. Exactly one pi-coding-agent — the load-bearing one.
COUNT="$(printf '%s\n' "${MANIFEST}" | grep -c '^@earendil-works/pi-coding-agent ' || true)"
[ "${COUNT}" = "1" ] || fail "found ${COUNT} copies of pi-coding-agent, expected exactly 1 (a nested copy drifts from the CLI)"
printf '%s\n' "${MANIFEST}" | grep -q "^@earendil-works/pi-coding-agent ${EXPECTED}$" \
  || fail "pi-coding-agent is not ${EXPECTED}"

# 4. Upstream publishes the whole family in lockstep; fail loudly if that
#    stops being true rather than shipping a mixed-version tree.
if printf '%s\n' "${MANIFEST}" | grep -qv " ${EXPECTED}$"; then
  echo "::error::mixed @earendil-works versions detected:" >&2
  printf '%s\n' "${MANIFEST}" | grep -v " ${EXPECTED}$" >&2
  exit 1
fi

echo "OK: one pi-coding-agent, all @earendil-works packages at ${EXPECTED}"
