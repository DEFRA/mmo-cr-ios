import { walk, collectColours } from './tree.mjs'

// Derives design tokens from the sanitised node tree we already hold — named
// styles (the design system's tokens), typography from TEXT nodes, and solid
// colours — so a tokens artefact is always produced. The dedicated Figma
// variables endpoint is Enterprise-only and often returns nothing; when it does
// return data it is added under `figmaVariables`. This mirrors how the design's
// own tree is the source of truth (no reliance on an Enterprise-gated endpoint).

function round (n) {
  return Math.round((Number(n) || 0) * 100) / 100
}

// Aggregates the named-style maps from every requested node into groups by type.
function collectNamedStyles (record) {
  const groups = {}
  for (const entry of Object.values(record.nodes)) {
    for (const [id, style] of Object.entries(entry.styles ?? {})) {
      const type = style.styleType ?? 'OTHER'
      groups[type] ??= []
      if (!groups[type].some((s) => s.id === id)) {
        groups[type].push({ id, name: style.name ?? null, description: style.description || undefined })
      }
    }
  }
  return groups
}

// Unique text styles used in the tree (typography tokens), with the named style
// they reference where one is applied.
function collectTypography (record) {
  const seen = new Map()
  for (const entry of Object.values(record.nodes)) {
    const styleNames = entry.styles ?? {}
    walk(entry.document, (node) => {
      if (node.type !== 'TEXT' || !node.style) return
      const s = node.style
      const styleId = node.styles?.text
      const token = {
        name: styleId && styleNames[styleId] ? styleNames[styleId].name : undefined,
        fontFamily: s.fontFamily,
        fontWeight: s.fontWeight,
        fontSize: s.fontSize,
        lineHeightPx: s.lineHeightPx != null ? round(s.lineHeightPx) : undefined,
        letterSpacing: s.letterSpacing != null ? round(s.letterSpacing) : undefined,
        textCase: s.textCase,
        textAlignHorizontal: s.textAlignHorizontal
      }
      const key = JSON.stringify([token.name, token.fontFamily, token.fontWeight, token.fontSize, token.lineHeightPx, token.letterSpacing, token.textCase])
      if (!seen.has(key)) seen.set(key, token)
    })
  }
  return [...seen.values()]
}

// Builds the tokens artefact. `figmaVariables` is the (already sanitised)
// Enterprise variables payload or null.
export function extractTokens (record, figmaVariables) {
  const colours = []
  for (const entry of Object.values(record.nodes)) colours.push(...collectColours(entry.document, 200))
  const uniqueColours = [...new Set(colours)]

  return {
    schemaVersion: record.schemaVersion,
    kind: 'figma-tokens',
    fileKey: record.fileKey,
    derivedFrom: figmaVariables
      ? 'node tree + named styles + Figma variables endpoint'
      : 'node tree + named styles (Figma variables endpoint returned no data / not available on this plan)',
    colours: uniqueColours,
    typography: collectTypography(record),
    namedStyles: collectNamedStyles(record),
    figmaVariables: figmaVariables ?? null
  }
}
