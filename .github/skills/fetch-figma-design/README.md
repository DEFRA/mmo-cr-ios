# fetch-figma-design

A Node.js CLI + agent skill that fetches a Figma design (node tree, rendered
images, image fills and design tokens) via the **Figma REST API** and writes
**design-only, PII-free** output to a git-ignored `.cache/` folder — no
dependencies, no server, **read-only by design**.

> For the agent-facing procedure (how Copilot should call this skill step by
> step), see [SKILL.md](SKILL.md). This README is the human-facing setup and
> usage reference.

## What it does

- Fetches a Figma design by **URL** or **`fileKey#node`** and writes a sanitised
  node tree (`design.json`), a readable summary (`design.md`) and downloaded
  assets (`assets/`).
- Downloads **rendered images** (PNG/SVG by default), **user-supplied image
  fills**, and **design tokens** (`tokens.json`, derived from the node tree — colours, typography, named
  styles — plus Enterprise Figma variables when that endpoint is available).
- **Strips all identity/PII before anything is written**: it never calls the
  comments, versions, file-metadata, users or activity-log endpoints, so creator,
  authors, commenters and approvers are never fetched. Plugin data is dropped, and
  a final guard fails closed if any identity key survives.
- **Never mutates Figma and never uses the Figma MCP server** — only Figma REST
  `GET` requests to the API host and the asset URLs those responses return.

See [references/security-and-fields.md](references/security-and-fields.md) for the
full data-minimisation and PII contract, and
[references/output-schema.json](references/output-schema.json) for the JSON shape.

## Requirements

- Node.js **18+** (uses the built-in `fetch`; no `npm install` needed).
- A Figma **Personal Access Token** with **File content: Read-only** scope.

## Setup

1. Copy [assets/.env.example](assets/.env.example) to `.env` in this folder.
2. Create a token: Figma → **Settings** → **Security** → **Personal access
   tokens** → **Generate new token**, scope **File content: Read-only**. Copy it
   immediately (shown once).
3. Fill in `.env`:

   | Variable                     | Required | Default                  | Purpose                                            |
   | ---------------------------- | :------: | ------------------------ | -------------------------------------------------- |
   | `FIGMA_PAT`                  |    ✅    | —                        | PAT, sent as `X-Figma-Token`                       |
   | `FIGMA_API_BASE`             |    —     | `https://api.figma.com`  | API base (`https://api.figma-gov.com` for gov)     |
   | `FIGMA_IMAGE_FORMATS`        |    —     | `png,svg`                | Rendered image formats                             |
   | `FIGMA_IMAGE_SCALE`          |    —     | `2`                      | Render scale (0.01–4)                              |
   | `FIGMA_MAX_NODES`            |    —     | `200`                    | Cap on frames rendered per run                     |
| `FIGMA_NODE_BATCH`           |    —     | `5`                      | Frame node-trees fetched per request for a section |
`.env` is git-ignored and must **never** be committed, read back, or printed —
including by the agent, on any error.

## Usage

Run every command from this folder:

```bash
# 1) Outline first (cheap, no downloads) — confirm scope for large designs
node scripts/cli.mjs "<figma-url | fileKey#node>" --outline

# 2) Full fetch (design tree + all assets) into .cache/
node scripts/cli.mjs "<figma-url | fileKey#node>"

# Restrict a large design (or a section) to specific frames
node scripts/cli.mjs "<figma-url>" --nodes 1-23,4-56

# Tree only, no downloads
node scripts/cli.mjs "<figma-url>" --no-assets
```

When the requested node is a **SECTION**, the section is fetched **frame by
frame**: each child frame gets its own `frames/<slug>/` subfolder
(`design.json`, `design.md`, `assets/`) and a section-level `section.json` /
`section.md` index lists every extracted frame. A section is never implemented as
a single page — work through its frames one at a time.

| Flag              | Effect                                                        |
| ----------------- | ------------------------------------------------------------- |
| `--outline`       | Pages/frames only; no downloads                               |
| `--nodes a-b,c-d` | Restrict to specific node ids                                 |
| `--no-assets`     | Sanitised node tree only                                      |
| `--geometry`      | Include raw vector path data (off by default)                 |
| `--batch <n>`     | Frame node-trees fetched per request when expanding a section |
| `--format png,svg`| Override rendered image formats                               |
| `--scale <n>`     | Override render scale (0.01–4)                                |
| `--depth <n>`     | Cap node-tree depth                                           |
| `--out [path]`    | Write under a chosen dir instead of `.cache/`                 |

### Output

Written to `.cache/<fileKey>/<node>/` (overwritten per run):

| File                    | Contents                                                    |
| ----------------------- | ----------------------------------------------------------- |
| `design.json`           | Full sanitised node tree + component/style maps             |
| `design.md`             | Readable summary: frames, colours, text, asset manifest     |
| `assets/render-*.{png,svg}` | Rendered node/frame images                              |
| `assets/fill-*`         | Downloaded user-supplied image fills                        |
| `assets/tokens.json`    | Design tokens derived from the tree (+ Enterprise variables) |
| `assets/manifest.json`  | Map of asset files → node ids / imageRefs                   |
| `outline.json`          | (`--outline` only) pages/frames outline                     |

When the requested node is a **SECTION**, output is instead written per frame:

| Path                          | Contents                                               |
| ----------------------------- | ------------------------------------------------------ |
| `section.json` / `section.md` | Section-level index listing every extracted frame      |
| `frames/<slug>/design.json`   | That frame's sanitised node tree                       |
| `frames/<slug>/design.md`     | That frame's readable summary                          |
| `frames/<slug>/assets/`       | That frame's renders, image fills, tokens, manifest    |

## Errors

Printed to **stderr** as redacted JSON: `{ "error": "...", "code": "..." }`.
On an auth error (`401`/`403`), check `.env` yourself — the agent will not (and
must not) read it for you.

## Boundaries (by design, not configurable)

- **Read-only:** only Figma REST `GET`; any non-GET is refused in code. No Figma
  write, and the Figma MCP server is never used.
- Network egress is locked to the Figma API host plus the Figma/S3 asset hosts the
  API responses point at; no other URL is ever fetched.
- Identity endpoints (comments, versions, meta, users, activity logs) are never
  called; identity keys are stripped and the output fails closed if any survive.
- Every run is stateless — nothing is cached or reused between invocations beyond
  the `.cache/` output, which the agent deletes once done.
