import assert from "node:assert/strict"
import { randomBytes } from "node:crypto"
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import test from "node:test"
import { AtomicRegistrationStore } from "../src/store.js"
import { registration } from "./helpers.js"

test("store encrypts APNs tokens at rest and decrypts them for delivery", async (t) => {
  const directory = await mkdtemp(join(tmpdir(), "wootdesk-store-test-"))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const filePath = join(directory, "store.json")
  const store = new AtomicRegistrationStore({
    filePath,
    encryptionKey: randomBytes(32),
  })
  await store.initialise()
  const value = registration()
  await store.createRegistration(value, {
    scope: "test-create",
    key: "store-test-key-0001",
    requestHash: "invented-request-hash",
    ttlSeconds: 3_600,
  })

  const contents = await readFile(filePath, "utf8")
  assert.equal(contents.includes(value.token), false)
  assert.equal(contents.includes("Invented customer"), false)
  const registrations = await store.registrationsForAccount(42, 90)
  assert.equal(registrations.length, 1)
  assert.equal(registrations[0].token, value.token)
})

test("store refuses corrupt persisted state", async (t) => {
  const directory = await mkdtemp(join(tmpdir(), "wootdesk-store-corrupt-"))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const filePath = join(directory, "store.json")
  await writeFile(filePath, "not json", { mode: 0o600 })
  const store = new AtomicRegistrationStore({
    filePath,
    encryptionKey: randomBytes(32),
  })
  await assert.rejects(store.initialise(), /could not be loaded/)
  assert.equal(store.isReady, false)
})

test("a failed atomic write rolls back the in-memory mutation", async (t) => {
  const directory = await mkdtemp(join(tmpdir(), "wootdesk-store-rollback-"))
  t.after(async () => {
    await chmod(directory, 0o700).catch(() => {})
    await rm(directory, { recursive: true, force: true })
  })
  const filePath = join(directory, "store.json")
  const store = new AtomicRegistrationStore({
    filePath,
    encryptionKey: randomBytes(32),
  })
  await store.initialise()

  await chmod(directory, 0o500)
  await assert.rejects(
    store.createRegistration(registration(), {
      scope: "test-create",
      key: "store-rollback-key-0001",
      requestHash: "invented-request-hash",
      ttlSeconds: 3_600,
    }),
  )
  await chmod(directory, 0o700)

  assert.equal((await store.registrationsForAccount(42, 90)).length, 0)
})
