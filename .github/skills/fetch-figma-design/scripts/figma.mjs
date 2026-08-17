import { guardedFetch } from './http.mjs'
import { SafeError } from './redactor.mjs'

// Read-only Figma REST client plus URL/node parsing. Talks only to the Figma API
// (never the Figma MCP server) and only via GET. The token is sent as the
// X-Figma-Token header and is never logged.

const FILE_KEY_RE = /^[A-Za-z0-9_-]+$/
// Figma node ids look like "1:23"; component-instance ids can be richer
// ("I1:2;3:4"). Accept that shape but reject anything with URL/path characters.
const NODE_ID_RE = /^[A-Za-z0-9:;_-]+$/

function normaliseNodeId (raw) {
  // A URL carries the node id hyphenated (1234-5678); the API wants a colon.
  return String(raw).replace(/-/g, ':')
}

// Derive { fileKey, nodeId } from a Figma URL, a "fileKey#node" string, or a bare
// fileKey. `nodeFlag` (from --node) overrides any node found in the location.
export function parseLocation (input, nodeFlag) {
  if (typeof input !== 'string' || input.trim() === '') {
    throw new SafeError('No Figma URL or file key provided.', { code: 'ERR_INPUT' })
  }
  const raw = input.trim()
  let fileKey = null
  let nodeId = null

  if (raw.includes('figma.com') || raw.startsWith('http')) {
    let url
    try {
      url = new URL(raw)
    } catch {
      throw new SafeError('Input is not a valid Figma URL.', { code: 'ERR_INPUT' })
    }
    if (!url.host.toLowerCase().endsWith('figma.com')) {
      throw new SafeError('URL host is not figma.com.', { code: 'ERR_INPUT' })
    }
    const match = url.pathname.match(/\/(?:design|file|proto|board)\/([A-Za-z0-9_-]+)/)
    fileKey = match ? match[1] : null
    // .../design/:fileKey/branch/:branchKey/... — the branch key is the file key.
    const branch = url.pathname.match(/\/branch\/([A-Za-z0-9_-]+)/)
    if (branch) fileKey = branch[1]
    nodeId = url.searchParams.get('node-id')
  } else if (raw.includes('#')) {
    const [key, node] = raw.split('#')
    fileKey = key
    nodeId = node
  } else {
    fileKey = raw
  }

  if (nodeFlag) nodeId = nodeFlag
  if (nodeId) nodeId = normaliseNodeId(nodeId)

  if (!fileKey || !FILE_KEY_RE.test(fileKey)) {
    throw new SafeError('Could not parse a valid Figma file key from the input.', { code: 'ERR_INPUT' })
  }
  if (nodeId && !NODE_ID_RE.test(nodeId)) {
    throw new SafeError('Parsed node id is not in a valid form.', { code: 'ERR_INPUT' })
  }
  return { fileKey, nodeId: nodeId || null }
}

// Parse a comma-separated --nodes list into normalised, validated node ids.
export function parseNodeList (raw) {
  if (!raw) return []
  return String(raw)
    .split(',')
    .map((n) => normaliseNodeId(n.trim()))
    .filter(Boolean)
    .map((n) => {
      if (!NODE_ID_RE.test(n)) throw new SafeError(`Invalid node id "${n}" in --nodes.`, { code: 'ERR_INPUT' })
      return n
    })
}

function enc (value) {
  return encodeURIComponent(value)
}

export function createFigmaClient (config) {
  const headers = { 'X-Figma-Token': config.token, Accept: 'application/json' }

  async function get (path, { tolerate = [] } = {}) {
    const url = `${config.apiBase}${path}`
    const res = await guardedFetch(url, { headers }, { allowedHosts: config.egressHosts })
    if (tolerate.includes(res.status)) return { status: res.status, body: null }
    if (res.status === 401 || res.status === 403) {
      throw new SafeError('Figma denied access. If credentials appear wrong, ask the user to check the .env file.', { code: 'ERR_AUTH' })
    }
    if (res.status === 404) throw new SafeError('Figma file or node was not found (404).', { code: 'ERR_NOT_FOUND' })
    if (res.status === 429) throw new SafeError('Figma rate limit reached (429) — stopping early without retrying. Wait a while before re-running.', { code: 'ERR_RATE_LIMIT' })
    if (!res.ok) throw new SafeError(`Figma request failed (${res.status}).`, { code: 'ERR_FIGMA' })
    return { status: res.status, body: await res.json() }
  }

  return {
    // Shallow file read (depth=1 → pages only) to resolve a default node.
    async getFileShallow (key, depth = 1) {
      const { body } = await get(`/v1/files/${enc(key)}?depth=${depth}`)
      return body
    },
    // The design/layer tree for the requested node ids.
    async getNodes (key, ids, { depth, geometry } = {}) {
      const params = [`ids=${ids.map(enc).join(',')}`]
      if (depth) params.push(`depth=${depth}`)
      if (geometry) params.push(`geometry=${enc(geometry)}`)
      const { body } = await get(`/v1/files/${enc(key)}/nodes?${params.join('&')}`)
      return body
    },
    // Rendered images (png/svg/…) for the requested node ids.
    async getImages (key, ids, { format, scale } = {}) {
      const params = [`ids=${ids.map(enc).join(',')}`, `format=${enc(format)}`]
      if (format !== 'svg' && format !== 'pdf' && scale) params.push(`scale=${scale}`)
      const { body } = await get(`/v1/images/${enc(key)}?${params.join('&')}`)
      return body
    },
    // Download links for user-supplied image fills (imageRef → url).
    async getImageFills (key) {
      const { body } = await get(`/v1/files/${enc(key)}/images`)
      return body
    },
    // Local variables (design tokens). Best-effort: many plans return 403.
    async getLocalVariables (key) {
      const { status, body } = await get(`/v1/files/${enc(key)}/variables/local`, { tolerate: [403, 404] })
      return status === 200 ? body : null
    }
  }
}
