import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { assertAllowedHost } from './http.mjs'
import { SafeError, redactString } from './redactor.mjs'
import { sanitiseFileName, nodeIdToFilePart } from './tree.mjs'

// Downloads design assets — rendered node images (png/svg/…), user-supplied image
// fills, and (best-effort) design tokens — into <outDir>/assets. Every asset URL
// is one the authenticated Figma API returned; each download is GET-only, https,
// and host-checked against the asset allowlist before any request is made.

const EXT_BY_TYPE = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/svg+xml': 'svg',
  'image/gif': 'gif',
  'application/pdf': 'pdf'
}

// Fetches an asset URL (GET-only, https, host-checked) and returns its bytes in
// memory. The caller decides the filename/extension and writes it once.
async function fetchAsset (rawUrl, config) {
  assertAllowedHost(rawUrl, config.assetHostAllowlist)
  let res
  try {
    res = await fetch(rawUrl, { method: 'GET', redirect: 'follow' })
  } catch (err) {
    throw new SafeError(`Asset download failed: ${redactString(String(err?.message ?? err))}`, { code: 'ERR_NETWORK' })
  }
  if (!res.ok) return { ok: false, status: res.status }
  const buffer = Buffer.from(await res.arrayBuffer())
  const contentType = (res.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase()
  return { ok: true, buffer, bytes: buffer.length, contentType }
}

// Renders the requested nodes in each configured format and downloads them.
async function renderNodes (client, fileKey, nodes, assetsDir, config, manifest, warnings) {
  const ids = nodes.map((n) => n.id)
  for (const format of config.imageFormats) {
    let result
    try {
      result = await client.getImages(fileKey, ids, { format, scale: config.imageScale })
    } catch (err) {
      warnings.push(`Render (${format}) failed: ${redactString(String(err?.message ?? err))}`)
      continue
    }
    if (result?.err) {
      warnings.push(`Render (${format}) error: ${redactString(String(result.err))}`)
      continue
    }
    for (const node of nodes) {
      const url = result?.images?.[node.id]
      if (!url) {
        warnings.push(`No ${format} render for "${node.name}" (${node.id}).`)
        continue
      }
      const res = await fetchAsset(url, config)
      if (!res.ok) {
        warnings.push(`Failed to download ${format} render for ${node.id} (status ${res.status}).`)
        continue
      }
      const file = `render-${sanitiseFileName(node.name)}-${nodeIdToFilePart(node.id)}.${format}`
      await writeFile(join(assetsDir, file), res.buffer)
      manifest.renders.push({ nodeId: node.id, name: node.name, format, file, bytes: res.bytes })
    }
  }
}

// Downloads the user-supplied image fills referenced in the tree.
async function downloadImageFills (client, fileKey, imageRefs, assetsDir, config, manifest, warnings) {
  if (imageRefs.length === 0) return
  let result
  try {
    result = await client.getImageFills(fileKey)
  } catch (err) {
    warnings.push(`Image fills lookup failed: ${redactString(String(err?.message ?? err))}`)
    return
  }
  const map = result?.meta?.images ?? result?.images ?? {}
  for (const ref of imageRefs) {
    const url = map[ref]
    if (!url) {
      warnings.push(`No download URL for image fill "${ref}".`)
      continue
    }
    const res = await fetchAsset(url, config)
    if (!res.ok) {
      warnings.push(`Failed to download image fill ${ref} (status ${res.status}).`)
      continue
    }
    const ext = EXT_BY_TYPE[res.contentType] ?? 'bin'
    const file = `fill-${nodeIdToFilePart(ref)}.${ext}`
    await writeFile(join(assetsDir, file), res.buffer)
    manifest.imageFills.push({ imageRef: ref, file, bytes: res.bytes })
  }
}

// Writes the derived design tokens to <outDir>/assets/tokens.json (always, even
// with --no-assets) and returns the relative path.
export async function writeTokens (outDir, tokens) {
  const assetsDir = join(outDir, 'assets')
  await mkdir(assetsDir, { recursive: true })
  await writeFile(join(assetsDir, 'tokens.json'), JSON.stringify(tokens, null, 2))
  return 'assets/tokens.json'
}

// Orchestrates all downloads and returns a manifest describing what was written.
export async function downloadAssets ({ client, fileKey, nodes, imageRefs, tokens, outDir, config }) {
  const assetsDir = join(outDir, 'assets')
  await mkdir(assetsDir, { recursive: true })
  const manifest = { renders: [], imageFills: [], tokensFile: null }
  const warnings = []

  await renderNodes(client, fileKey, nodes, assetsDir, config, manifest, warnings)
  await downloadImageFills(client, fileKey, imageRefs, assetsDir, config, manifest, warnings)

  if (tokens) manifest.tokensFile = await writeTokens(outDir, tokens)

  await writeFile(join(assetsDir, 'manifest.json'), JSON.stringify(manifest, null, 2))
  return { manifest, warnings, assetsDir }
}
