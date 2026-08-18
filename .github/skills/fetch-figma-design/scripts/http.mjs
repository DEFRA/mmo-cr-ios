import { SafeError, redactString } from './redactor.mjs'

// Enforces the read-only network boundary. Only GET is ever permitted, and only
// hosts in `allowedHosts` (the Figma API, or the Figma/S3 asset hosts) may be
// contacted. This blocks SSRF and guarantees the skill can never write to Figma.

function assertGet (options) {
  const method = String(options.method ?? 'GET').toUpperCase()
  if (method !== 'GET') {
    throw new SafeError(`Refusing non-GET request (${method}) — this skill is strictly read-only.`, { code: 'ERR_METHOD' })
  }
}

// Host match is suffix-aware so exact API hosts (api.figma.com) and wildcard
// asset hosts (*.amazonaws.com) both work from the same allowlist mechanism.
export function assertAllowedHost (rawUrl, allowedHosts) {
  if (!Array.isArray(allowedHosts) || allowedHosts.length === 0) {
    throw new SafeError('Refusing request: no egress allowlist configured.', { code: 'ERR_EGRESS' })
  }
  let url
  try {
    url = new URL(rawUrl)
  } catch {
    throw new SafeError('Refusing to request an invalid URL.', { code: 'ERR_EGRESS' })
  }
  if (url.protocol !== 'https:') throw new SafeError('Refusing non-https request.', { code: 'ERR_EGRESS' })
  const host = url.host.toLowerCase()
  const allowed = allowedHosts.some((h) => host === h || host.endsWith(`.${h}`))
  if (!allowed) throw new SafeError(`Refusing to contact disallowed host "${url.host}".`, { code: 'ERR_EGRESS' })
  return url
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

function backoffDelay (attempt, retryAfterHeader) {
  const retryAfter = Number.parseInt(retryAfterHeader, 10)
  if (Number.isInteger(retryAfter) && retryAfter > 0) return retryAfter * 1000
  const base = Math.min(2000 * 2 ** attempt, 30000)
  return Math.round(base * (0.7 + Math.random() * 0.6))
}

// GET-only fetch wrapper that enforces the egress allowlist and retries 5xx with
// exponential backoff + jitter. A 429 (rate limit) is NOT retried: it is returned
// immediately so the caller can fail fast and stop early rather than waiting on
// backoff. Never logs the token / Authorization header.
export async function guardedFetch (rawUrl, options = {}, { allowedHosts, maxRetries = 4 } = {}) {
  assertGet(options)
  assertAllowedHost(rawUrl, allowedHosts)
  for (let attempt = 0; ; attempt += 1) {
    let res
    try {
      res = await fetch(rawUrl, { ...options, method: 'GET', redirect: 'follow' })
    } catch (err) {
      throw new SafeError(`Network request failed: ${redactString(String(err?.message ?? err))}`, { code: 'ERR_NETWORK' })
    }
    // Fail fast on rate limiting (429) and any non-5xx status; only retry 5xx.
    if (res.status < 500) return res
    if (attempt >= maxRetries) return res
    await sleep(backoffDelay(attempt, res.headers.get('retry-after')))
  }
}
