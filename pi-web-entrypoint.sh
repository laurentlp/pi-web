#!/bin/sh
# Warn — never refuse to start — when this image's pi version differs from the
# version the deployment expects.
#
# Refusing to start would remove remote access at exactly the moment the
# operator is away from the desk, which is the situation this image exists for.
# The Grafana `PiVersionDrift` alert is the escalation path; this is the
# in-band hint that shows up in `docker logs`.
set -eu

SDK_PKG=/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/package.json
HAVE="$(node -p "require('${SDK_PKG}').version")"
EXPECTED="${PI_EXPECTED_VERSION:-}"

if [ -n "${EXPECTED}" ] && [ "${EXPECTED}" != "${HAVE}" ]; then
  echo "WARNING: pi version drift — image has ${HAVE}, host expects ${EXPECTED}." >&2
  echo "WARNING: dispatch laurentlp/pi-web build-image with pi_version=${EXPECTED}, then redeploy the pi-web stack." >&2
fi

exec "$@"
