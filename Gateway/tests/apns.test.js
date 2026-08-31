import assert from "node:assert/strict"
import { generateKeyPairSync, verify } from "node:crypto"
import { EventEmitter } from "node:events"
import test from "node:test"
import { APNSSender, createProviderToken } from "../src/apns.js"

test("APNs provider JWT uses a verifiable 64-byte ES256 P1363 signature", () => {
  const { privateKey, publicKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  })
  const token = createProviderToken({
    teamID: "TEAMID1234",
    keyID: "KEYID12345",
    privateKey,
    issuedAt: 1_788_115_200,
  })
  const [header, claims, encodedSignature] = token.split(".")
  const signature = Buffer.from(encodedSignature, "base64url")

  assert.equal(signature.length, 64)
  assert.deepEqual(
    JSON.parse(Buffer.from(header, "base64url").toString("utf8")),
    { alg: "ES256", kid: "KEYID12345" },
  )
  assert.equal(
    verify("sha256", Buffer.from(`${header}.${claims}`, "ascii"), {
      key: publicKey,
      dsaEncoding: "ieee-p1363",
    }, signature),
    true,
  )
})

test("APNs sender selects the environment and recognises an invalid token", async () => {
  const { privateKey } = generateKeyPairSync("ec", {
    namedCurve: "prime256v1",
  })
  const observed = {}
  const sender = new APNSSender({
    teamID: "TEAMID1234",
    keyID: "KEYID12345",
    privateKey: privateKey.export({ type: "pkcs8", format: "pem" }),
    clock: () => 1_788_115_200_000,
    connect(host) {
      observed.host = host
      const session = new EventEmitter()
      session.request = (headers) => {
        observed.headers = headers
        const stream = new EventEmitter()
        stream.setEncoding = () => {}
        stream.close = () => {}
        stream.end = (body) => {
          observed.body = body
          queueMicrotask(() => {
            stream.emit("response", { ":status": 410 })
            stream.emit("data", JSON.stringify({ reason: "Unregistered" }))
            stream.emit("end")
          })
        }
        return stream
      }
      session.close = () => {
        observed.closed = true
      }
      return session
    },
  })

  const result = await sender.send(
    {
      token: "ab".repeat(32),
      environment: "production",
      topic: "dev.n85.wootdesk",
    },
    { aps: { alert: { title: "WootDesk", body: "A new message was received." } } },
    "message-42-500",
  )

  assert.equal(observed.host, "https://api.push.apple.com")
  assert.equal(observed.headers[":path"], `/3/device/${"ab".repeat(32)}`)
  assert.equal(observed.headers["apns-topic"], "dev.n85.wootdesk")
  assert.match(observed.headers.authorization, /^bearer [^.]+\.[^.]+\.[^.]+$/)
  assert.equal(JSON.parse(observed.body).aps.alert.title, "WootDesk")
  assert.deepEqual(result, {
    accepted: false,
    invalidToken: true,
    status: 410,
    reason: "Unregistered",
  })
  assert.equal(observed.closed, true)
})
