FROM node:22-bookworm-slim

ARG PI_WEB_VERSION=latest
ARG PI_VERSION=0.87.1

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates tini python3 make g++ openssh-client procps tmux \
    && rm -rf /var/lib/apt/lists/*

# ONE resolution pass, deliberately. @earendil-works/pi-coding-agent ships BOTH
# the SDK that PI WEB imports as a library (SessionManager, SettingsManager,
# defineTool) AND the `pi` CLI that extensions spawn (bin: dist/bundle/cli.js),
# so a single version satisfies both.
#
# Installing them in separate `npm install` runs is NOT equivalent: PI WEB
# declares its pi peer dependencies as `>=0.87.0`, so a second run re-resolves
# that range against the registry and nests its own copy of the whole pi family
# under PI WEB's node_modules. That copy then drifts from the pinned global one
# as soon as the registry has anything newer. Passing both specs together lets
# npm hoist and dedupe to the single pinned version instead.
#
# --allow-scripts is an allowlist: only node-pty runs lifecycle scripts (it
# compiles a native module, hence the toolchain above). Pi itself needs none.
RUN npm install -g --allow-scripts=node-pty \
      "@earendil-works/pi-coding-agent@${PI_VERSION}" \
      "@jmfederico/pi-web@${PI_WEB_VERSION}"

COPY pi-web-entrypoint.sh /usr/local/bin/pi-web-entrypoint.sh
RUN chmod 0755 /usr/local/bin/pi-web-entrypoint.sh

WORKDIR /home/laurentlp
ENTRYPOINT ["tini", "--", "/usr/local/bin/pi-web-entrypoint.sh"]
CMD ["pi-web-server"]
