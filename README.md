# pi-web

A **packaging image** for [PI WEB](https://pi-web.dev) — the web UI for the
[Pi coding agent](https://pi.dev).

> **This is not a fork.** It contains no upstream source. It is a Dockerfile
> that installs two published npm packages and adds a version-drift warning.
> Upstream lives at <https://github.com/jmfederico/pi-web>.

Published to `ghcr.io/laurentlp/pi-web`. Consumed by `pi-web-stack.yml` in
[laurentlp/docker](https://github.com/laurentlp/docker).

## Why this exists

Upstream publishes no prebuilt image — its docs state that no registry is
required — so one has to be built. This repo builds it in CI rather than with a
`build:` block in the compose stack, matching the `unbound_exporter` pattern.

## The one thing to keep in step

**`PI_VERSION` must track the host's `pi-coding-agent-bin` AUR package.**

```bash
pacman -Q pi-coding-agent-bin        # e.g. pi-coding-agent-bin 0.87.1-1
```

On bear this is automated: a pacman hook dispatches this workflow whenever
`pi-coding-agent-bin` is upgraded, and a node_exporter textfile metric
(`pi_version_drift`) with a Grafana `PiVersionDrift` alert catches anything that
bypasses it. To bump by hand:

```bash
gh workflow run build-image.yml -R laurentlp/pi-web -f pi_version=<version>
```

`PI_VERSION` is always pinned exactly. It is never a range: PI WEB declares its
pi peer dependencies as `>=0.87.0`, so an unpinned install would silently float
to whatever npm resolved.

## Why the SDK and CLI cannot diverge

`@earendil-works/pi-coding-agent` ships **both** the SDK that PI WEB imports as
a library (`SessionManager`, `SettingsManager`, `defineTool`, …) **and** the
`pi` CLI that extensions spawn (`bin: dist/bundle/cli.js`), at one version. So a
single install satisfies both.

**Installing them in two separate `npm install` runs is not equivalent.** PI WEB
declares its pi peer dependencies as `>=0.87.0`, so a second run re-resolves
that range against the registry and nests its own copy of the whole pi family
under PI WEB's `node_modules` — which drifts from the pinned global copy the
moment the registry has anything newer. The Dockerfile therefore passes both
specs to a single `npm install`, and `assert-image-versions.sh` proves it held:

- the `pi` CLI reports `PI_VERSION`;
- exactly **one** `pi-coding-agent` exists in the image (a second copy fails the
  build);
- every `@earendil-works/*` package is at `PI_VERSION` — upstream publishes the
  family in lockstep, and a mixed tree fails the build rather than shipping.

The CLI matters even though PI WEB runs sessions in-process on the SDK: the
`subagent` extension spawns `pi --mode json -p --no-session` child processes.

## Tags

| Tag | Use |
|---|---|
| `:latest` | What the stack pulls. |
| `:pi-<version>` | Pin the stack here if you ever need exact reproducibility. |
| `:<short-sha>` | Rollback to a specific build. |

## Version drift at runtime

The entrypoint compares its own pi version against `PI_EXPECTED_VERSION` from
the environment and **warns** on mismatch — it never refuses to start. Refusing
would remove remote access at exactly the moment the operator is away from the
desk, which is the situation this image exists for.

## Build args

| Arg | Default | Notes |
|---|---|---|
| `PI_VERSION` | `0.87.1` | Exact `@earendil-works/pi-coding-agent` version. |
| `PI_WEB_VERSION` | `latest` | `@jmfederico/pi-web` version. |

## Local build

```bash
docker build --build-arg PI_VERSION=0.87.1 -t pi-web:local .
docker run --rm --entrypoint pi pi-web:local --version
```

## License

The packaging files here are MIT. The packaged software is the property of its
respective authors — PI WEB is MIT, Pi is MIT.
