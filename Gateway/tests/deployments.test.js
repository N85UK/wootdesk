import assert from "node:assert/strict"
import { randomBytes } from "node:crypto"
import test from "node:test"
import {
  deploymentForBaseURL,
  deploymentForRouteSecret,
  normaliseBaseURL,
} from "../src/deployments.js"

const first = {
  id: "production",
  baseUrl: "https://chat.invalid",
  routeSecret: randomBytes(32).toString("base64url"),
  signingSecret: "aaaaaaaaaaaaaaaaaaaaaaaa",
}
const second = {
  id: "review",
  baseUrl: "https://review.invalid",
  routeSecret: randomBytes(32).toString("base64url"),
  signingSecret: "bbbbbbbbbbbbbbbbbbbbbbbb",
}
const deployments = [first, second]

test("normaliseBaseURL reduces a Chatwoot address to its origin", () => {
  // An operator writes the address in whatever form their browser showed it.
  // All of these are the same server, and treating them as different ones
  // would refuse enrolments that ought to succeed.
  for (const value of [
    "https://chat.invalid",
    "https://chat.invalid/",
    "https://CHAT.invalid",
    "https://chat.invalid/app/accounts/1/conversations",
    "https://chat.invalid:443/",
  ]) {
    assert.equal(normaliseBaseURL(value), "https://chat.invalid", value)
  }
})

test("normaliseBaseURL keeps a non-default port, which distinguishes a server", () => {
  assert.equal(normaliseBaseURL("https://chat.invalid:8443/"), "https://chat.invalid:8443")
})

test("normaliseBaseURL rejects anything that is not an http address", () => {
  for (const value of ["", "not a url", "ftp://chat.invalid", "javascript:alert(1)"]) {
    assert.equal(normaliseBaseURL(value), undefined, value)
  }
})

test("deploymentForRouteSecret matches the deployment that owns the secret", () => {
  assert.equal(deploymentForRouteSecret(deployments, first.routeSecret)?.id, "production")
  assert.equal(deploymentForRouteSecret(deployments, second.routeSecret)?.id, "review")
})

test("deploymentForRouteSecret returns nothing for an unknown secret", () => {
  // AC6. An unconfigured deployment must be refused rather than guessed at,
  // and the caller turns this into a 404.
  assert.equal(deploymentForRouteSecret(deployments, randomBytes(32).toString("base64url")), undefined)
  assert.equal(deploymentForRouteSecret(deployments, ""), undefined)
  assert.equal(deploymentForRouteSecret(deployments, first.routeSecret.slice(0, -1)), undefined)
})

test("deploymentForBaseURL matches regardless of how the address was written", () => {
  assert.equal(deploymentForBaseURL(deployments, "https://chat.invalid/")?.id, "production")
  assert.equal(deploymentForBaseURL(deployments, "https://REVIEW.invalid")?.id, "review")
})

test("deploymentForBaseURL returns nothing for a server the gateway does not know", () => {
  assert.equal(deploymentForBaseURL(deployments, "https://elsewhere.invalid"), undefined)
  assert.equal(deploymentForBaseURL(deployments, "nonsense"), undefined)
})
