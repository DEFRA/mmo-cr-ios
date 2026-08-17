import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { SafeError } from './redactor.mjs'

// Loads and validates configuration for the skill. Personal Access Token (PAT)
// only, sent as the X-Figma-Token header. Secrets are held only in the returned
// object (in memory) and never logged. The .env file lives in the skill root and
// must never be read or echoed by the agent.

const SKILL_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const ENV_FILE = resolve(SKILL_ROOT, '.env')

const DEFAULTS = {
  apiBase: 'https://api.figma.com',
  imageFormats: ['png', 'svg'],
  imageScale: 2,
  maxNodes: 200,
  // How many frame node-trees to request per GET when expanding a section, so a
  // large section is fetched in bounded batches instead of one huge response.
  nodeBatch: 5,
  // Suffix-matched hosts allowed for downloading the short-lived asset URLs that
  // the Figma API itself returns (rendered images / image fills live on S3).
  assetHostAllowlist: ['figma.com', 'amazonaws.com']
}

const VALID_FORMATS = new Set(['png', 'svg', 'jpg', 'pdf'])

// Minimal KEY=VALUE .env reader. Values already present in the environment win.
function loadEnvFile (env) {
  let text
  try {
    text = readFileSync(ENV_FILE, 'utf8')
  } catch {
    return env
  }
  const merged = { ...env }
  for (const line of text.split('\n')) {
    const m = line.match(/^\s*([A-Z][A-Z0-9_]*)\s*=\s*(.*)$/)
    if (!m) continue
    if (merged[m[1]] != null && merged[m[1]] !== '') continue
    let val = m[2].trim()
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1)
    }
    merged[m[1]] = val
  }
  return merged
}

function requireEnv (env, name) {
  const value = env[name]
  if (typeof value !== 'string' || value.trim() === '') {
    throw new SafeError(
      `Missing required configuration "${name}". Set it in the skill's .env file (see assets/.env.example).`,
      { code: 'ERR_CONFIG_MISSING' }
    )
  }
  return value.trim()
}

function parsePositiveInt (raw, fallback) {
  const n = Number.parseInt(raw, 10)
  return Number.isInteger(n) && n > 0 ? n : fallback
}

function parseScale (raw, fallback) {
  const n = Number.parseFloat(raw)
  return Number.isFinite(n) && n >= 0.01 && n <= 4 ? n : fallback
}

function parseFormats (raw, fallback) {
  const list = String(raw ?? '')
    .split(',').map((t) => t.trim().toLowerCase()).filter((t) => VALID_FORMATS.has(t))
  return list.length ? [...new Set(list)] : fallback
}

function parseApiBase (raw) {
  let url
  try {
    url = new URL(raw)
  } catch {
    throw new SafeError('FIGMA_API_BASE is not a valid URL.', { code: 'ERR_CONFIG_INVALID' })
  }
  if (url.protocol !== 'https:') throw new SafeError('FIGMA_API_BASE must use https.', { code: 'ERR_CONFIG_INVALID' })
  const path = url.pathname.replace(/\/+$/, '')
  return { apiBase: `${url.protocol}//${url.host}${path}`, host: url.host }
}

export function loadConfig (rawEnv = process.env) {
  const env = loadEnvFile(rawEnv)
  const api = parseApiBase(env.FIGMA_API_BASE ?? DEFAULTS.apiBase)
  const assetHostAllowlist = (env.FIGMA_ASSET_HOST_ALLOWLIST ?? '')
    .split(',').map((h) => h.trim().toLowerCase()).filter(Boolean)

  return Object.freeze({
    apiBase: api.apiBase,
    // API egress is locked to the Figma API host only (blocks SSRF).
    egressHosts: Object.freeze([api.host]),
    // Asset egress is limited to Figma/S3 hosts the API responses point at.
    assetHostAllowlist: Object.freeze(assetHostAllowlist.length ? assetHostAllowlist : DEFAULTS.assetHostAllowlist),
    token: requireEnv(env, 'FIGMA_PAT'),
    imageFormats: Object.freeze(parseFormats(env.FIGMA_IMAGE_FORMATS, DEFAULTS.imageFormats)),
    imageScale: parseScale(env.FIGMA_IMAGE_SCALE, DEFAULTS.imageScale),
    maxNodes: parsePositiveInt(env.FIGMA_MAX_NODES, DEFAULTS.maxNodes),
    nodeBatch: parsePositiveInt(env.FIGMA_NODE_BATCH, DEFAULTS.nodeBatch)
  })
}
