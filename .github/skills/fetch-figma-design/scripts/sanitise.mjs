import { SafeError } from './redactor.mjs'

// The sanitisation boundary. Deterministic, non-AI. Every raw Figma response
// passes through here and comes out as a design-only record: file/creator/
// author identity is never requested and is stripped defensively, plugin data is
// dropped, and a final guard fails closed if any identity key survives.

export const SCHEMA_VERSION = '1.0.0'

// Node keys carrying arbitrary or plugin-authored data — always dropped.
const DENY_KEYS = new Set(['plugindata', 'sharedplugindata'])

// Identity-bearing keys that must never appear in design output. These come from
// endpoints this skill never calls (comments/versions/meta/users); the guard is
// belt-and-braces so a future change can't silently leak them.
const IDENTITY_KEYS = new Set([
  'creator', 'user', 'users', 'handle', 'email', 'ownerid', 'owner',
  'last_touched_by', 'lasttouchedby', 'reactedusers', 'orderid'
])

// Top-level file metadata we keep (design/staleness only — no identity).
const META_KEYS = ['name', 'lastModified', 'version']

// Deep-copies a node subtree, dropping denylisted keys. Design properties
// (layout, fills, strokes, effects, characters, style, children, …) are kept so
// the calling agent has full structural context.
function stripTree (value, seen = new WeakSet()) {
  if (value == null || typeof value !== 'object') return value
  if (seen.has(value)) return undefined
  seen.add(value)
  if (Array.isArray(value)) return value.map((v) => stripTree(v, seen))
  const out = {}
  for (const [key, val] of Object.entries(value)) {
    if (DENY_KEYS.has(key.toLowerCase())) continue
    out[key] = stripTree(val, seen)
  }
  return out
}

// Fails closed: throws if any identity-bearing key survives anywhere in the
// record. Only structural keys are inspected — design text (`characters`) is
// never treated as PII, so legitimate mock copy is preserved.
export function assertNoPii (record, seen = new WeakSet()) {
  if (record == null || typeof record !== 'object') return
  if (seen.has(record)) return
  seen.add(record)
  if (Array.isArray(record)) {
    for (const item of record) assertNoPii(item, seen)
    return
  }
  for (const [key, val] of Object.entries(record)) {
    if (IDENTITY_KEYS.has(key.toLowerCase())) {
      throw new SafeError(`PII guard tripped: identity key "${key}" present in output.`, { code: 'ERR_PII' })
    }
    assertNoPii(val, seen)
  }
}

// Turns a raw GET /v1/files/:key/nodes response into a sanitised, design-only
// document. Identity metadata (role, editorType, thumbnailUrl, etc.) is dropped;
// only name/lastModified/version are kept.
export function sanitiseNodesResponse (raw, { fileKey, requestedNodeIds }) {
  if (!raw || typeof raw !== 'object' || typeof raw.nodes !== 'object') {
    throw new SafeError('Unexpected Figma nodes response shape.', { code: 'ERR_SHAPE' })
  }
  const warnings = []
  const meta = {}
  for (const key of META_KEYS) if (raw[key] != null) meta[key] = raw[key]

  const nodes = {}
  for (const [id, entry] of Object.entries(raw.nodes)) {
    if (entry == null) {
      warnings.push(`Node ${id} was null (not found in file).`)
      continue
    }
    nodes[id] = {
      document: stripTree(entry.document),
      components: stripTree(entry.components ?? {}),
      componentSets: stripTree(entry.componentSets ?? {}),
      styles: stripTree(entry.styles ?? {})
    }
  }

  const record = {
    schemaVersion: SCHEMA_VERSION,
    kind: 'figma-design',
    fileKey,
    requestedNodeIds,
    retrievedAt: new Date().toISOString(),
    file: meta,
    nodes,
    warnings
  }
  assertNoPii(record)
  return record
}

// Sanitises the local-variables (design tokens) payload, dropping any identity
// keys defensively. Returns null when tokens were unavailable.
export function sanitiseVariables (raw) {
  if (!raw || typeof raw !== 'object') return null
  const stripped = stripTree(raw.meta ?? raw)
  assertNoPii(stripped)
  return stripped
}
