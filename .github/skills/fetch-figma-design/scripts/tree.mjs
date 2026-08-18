// Shared, dependency-free helpers for walking a sanitised Figma node tree.
// Pure functions only — no network, no fs.

export function walk (node, visit) {
  if (!node || typeof node !== 'object') return
  visit(node)
  for (const child of node.children ?? []) walk(child, visit)
}

// The top-level frames under a node: a CANVAS/DOCUMENT's frame-like children, or
// the node itself when a single frame/component was requested.
const FRAME_TYPES = new Set(['FRAME', 'COMPONENT', 'COMPONENT_SET', 'INSTANCE', 'SECTION', 'GROUP'])

// Renderable/implementable leaf frames (what we fetch and build one at a time).
// A SECTION is a container that groups these, never implemented on its own.
const FRAME_LEAF_TYPES = new Set(['FRAME', 'COMPONENT', 'COMPONENT_SET', 'INSTANCE', 'GROUP'])

// The individual frames inside a SECTION (recursing through nested sections), so
// a section can be fetched and rendered frame by frame instead of as one giant
// node. Non-frame direct children (loose text/vectors) are ignored.
export function sectionChildFrames (node) {
  if (!node || typeof node !== 'object') return []
  const out = []
  for (const child of node.children ?? []) {
    if (child.type === 'SECTION') out.push(...sectionChildFrames(child))
    else if (FRAME_LEAF_TYPES.has(child.type)) out.push(child)
  }
  return out
}

export function topFrames (document) {
  if (!document || typeof document !== 'object') return []
  if (document.type === 'CANVAS' || document.type === 'DOCUMENT') {
    return (document.children ?? []).filter((c) => FRAME_TYPES.has(c.type))
  }
  // A requested SECTION is expanded into its child frames, not treated as one.
  if (document.type === 'SECTION') return sectionChildFrames(document)
  return [document]
}

// Unique image-fill references used anywhere in the tree (for GET image fills).
export function collectImageRefs (document) {
  const refs = new Set()
  walk(document, (node) => {
    for (const fill of node.fills ?? []) {
      if (fill && fill.type === 'IMAGE' && typeof fill.imageRef === 'string') refs.add(fill.imageRef)
    }
  })
  return [...refs]
}

// Visible text runs, in document order (for the readable summary).
export function collectText (document, limit = 200) {
  const out = []
  walk(document, (node) => {
    if (node.type === 'TEXT' && typeof node.characters === 'string' && node.characters.trim()) {
      out.push({ name: node.name, text: node.characters.trim() })
    }
  })
  return out.slice(0, limit)
}

function toHex (component) {
  return Math.round(Math.max(0, Math.min(1, component)) * 255).toString(16).padStart(2, '0')
}

// Unique solid fill colours used in the tree, as hex (for the readable summary).
export function collectColours (document, limit = 60) {
  const seen = new Set()
  walk(document, (node) => {
    for (const fill of node.fills ?? []) {
      if (fill && fill.type === 'SOLID' && fill.color) {
        const { r, g, b } = fill.color
        seen.add(`#${toHex(r)}${toHex(g)}${toHex(b)}`.toUpperCase())
      }
    }
  })
  return [...seen].slice(0, limit)
}

export function sanitiseFileName (name) {
  const slug = String(name ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
  return slug || 'node'
}

export function nodeIdToFilePart (id) {
  return String(id).replace(/[^A-Za-z0-9]+/g, '-')
}
