import { constantTimeMatches } from "./security.js"

/**
 * Resolving which Chatwoot deployment a request belongs to.
 *
 * Chatwoot does not identify itself in a webhook body, so the payload cannot
 * say which server sent it. Two deployments that both have an account
 * numbered 1 are indistinguishable once the body is parsed, which is the
 * defect this module exists to close: an event from one could notify devices
 * enrolled against the other.
 *
 * The only discriminator available is the endpoint the request arrived on.
 * Each deployment therefore gets its own route secret, and that secret is the
 * deployment's identity.
 */

/**
 * Reduces a Chatwoot address to the origin that identifies the server.
 *
 * Operators paste whatever their browser showed, which is often a deep link
 * into a conversation. Comparing those strings directly would refuse
 * enrolments that should succeed, so both sides of the comparison are reduced
 * to scheme, host and port. `URL` lowercases the host and drops a default
 * port for us; a non-default port is kept, because it genuinely distinguishes
 * one server from another.
 *
 * Returns undefined rather than throwing, because both callers treat an
 * unusable address as "no match" and neither wants to catch.
 */
export function normaliseBaseURL(value) {
  if (typeof value !== "string" || value.length === 0) {
    return undefined
  }
  let parsed
  try {
    parsed = new URL(value)
  } catch {
    return undefined
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    return undefined
  }
  return parsed.origin
}

/**
 * Finds the deployment whose route secret was used, for AC1 and AC6.
 *
 * Every deployment is compared, and every comparison is constant time, so the
 * work done does not depend on which secret was supplied or on how many
 * characters of it were right. Returning early on a match would leak the
 * position of the matching deployment through timing; the loop keeps going
 * and the answer is returned at the end.
 */
export function deploymentForRouteSecret(deployments, supplied) {
  if (typeof supplied !== "string" || supplied.length === 0) {
    return undefined
  }
  let matched
  for (const deployment of deployments) {
    if (constantTimeMatches(supplied, deployment.routeSecret)) {
      matched = deployment
    }
  }
  return matched
}

/**
 * Finds the deployment serving a Chatwoot address, for AC4.
 *
 * Used at enrolment: the app sends the address of the server profile being
 * enrolled, and the gateway turns it into the deployment that profile belongs
 * to. A profile pointing somewhere the gateway is not configured for has no
 * answer, and the caller refuses the enrolment rather than attributing it to
 * whichever deployment happens to be first.
 */
export function deploymentForBaseURL(deployments, value) {
  const origin = normaliseBaseURL(value)
  if (origin === undefined) {
    return undefined
  }
  return deployments.find((deployment) => deployment.baseUrl === origin)
}
