import {
  chmod,
  mkdir,
  open,
  readFile,
  rename,
  unlink,
} from "node:fs/promises"
import { basename, dirname, join } from "node:path"
import { randomUUID } from "node:crypto"
import { conflict, notFound } from "./errors.js"
import { decryptToken, encryptToken, hash } from "./security.js"

const currentVersion = 1

export class AtomicRegistrationStore {
  #data = emptyData()
  #queue = Promise.resolve()
  #ready = false

  constructor({ filePath, encryptionKey, clock = () => Date.now() }) {
    this.filePath = filePath
    this.encryptionKey = encryptionKey
    this.clock = clock
  }

  get isReady() {
    return this.#ready
  }

  async initialise() {
    return this.#exclusive(async () => {
      await mkdir(dirname(this.filePath), { recursive: true, mode: 0o700 })
      try {
        const contents = await readFile(this.filePath, "utf8")
        const decoded = JSON.parse(contents)
        validateStore(decoded)
        this.#data = decoded
        await chmod(this.filePath, 0o600)
      } catch (error) {
        if (error?.code !== "ENOENT") {
          throw new Error("The encrypted registration store could not be loaded.")
        }
        this.#data = emptyData()
        await this.#persist()
      }
      this.#ready = true
    })
  }

  async createRegistration(registration, idempotency) {
    return this.#exclusive(async () => {
      this.#requireReady()
      return this.#withIdempotency(idempotency, async () => {
        if (
          this.#data.registrations.some(
            (item) => item.deviceId === registration.deviceId,
          )
        ) {
          throw conflict("A registration already exists for this device.")
        }

        const now = new Date(this.clock()).toISOString()
        const stored = this.#sealRegistration({
          ...registration,
          createdAt: now,
          updatedAt: now,
        })
        this.#data.registrations.push(stored)
        return { status: 201, body: registrationResponse(stored) }
      })
    })
  }

  async updateRegistration(registration, idempotency) {
    return this.#exclusive(async () => {
      this.#requireReady()
      return this.#withIdempotency(idempotency, async () => {
        const index = this.#data.registrations.findIndex(
          (item) => item.deviceId === registration.deviceId,
        )
        if (index === -1) {
          throw notFound()
        }

        const current = this.#data.registrations[index]
        const stored = this.#sealRegistration({
          ...registration,
          createdAt: current.createdAt,
          updatedAt: new Date(this.clock()).toISOString(),
        })
        this.#data.registrations[index] = stored
        return { status: 200, body: registrationResponse(stored) }
      })
    })
  }

  async deleteRegistration(deviceID, idempotency) {
    return this.#exclusive(async () => {
      this.#requireReady()
      return this.#withIdempotency(idempotency, async () => {
        this.#data.registrations = this.#data.registrations.filter(
          (item) => item.deviceId !== deviceID,
        )
        return { status: 204, body: undefined }
      })
    })
  }

  async registrationsForAccount(accountID, ttlDays) {
    return this.#exclusive(async () => {
      this.#requireReady()
      return this.#transaction(async () => {
        const oldest = this.clock() - ttlDays * 24 * 60 * 60 * 1000
        const retained = this.#data.registrations.filter(
          (item) => Date.parse(item.updatedAt) >= oldest,
        )
        if (retained.length !== this.#data.registrations.length) {
          this.#data.registrations = retained
          await this.#persist()
        }

        return retained
          .filter((item) => item.accountId === accountID)
          .map((item) => ({
            ...registrationResponse(item).registration,
            token: decryptToken(
              item.token,
              this.encryptionKey,
              associatedData(item),
            ),
            tokenHash: item.tokenHash,
          }))
      })
    })
  }

  async removeInvalidRegistration(deviceID, tokenHash) {
    return this.#exclusive(async () => {
      this.#requireReady()
      return this.#transaction(async () => {
        const before = this.#data.registrations.length
        this.#data.registrations = this.#data.registrations.filter(
          (item) =>
            item.deviceId !== deviceID || item.tokenHash !== tokenHash,
        )
        if (before !== this.#data.registrations.length) {
          await this.#persist()
          return true
        }
        return false
      })
    })
  }

  async beginDelivery(identifier, ttlSeconds) {
    return this.#exclusive(async () => {
      this.#requireReady()
      return this.#transaction(async () => {
        this.#prune()
        const keyHash = hash(identifier)
        const existing = this.#data.deliveries.find(
          (item) => item.keyHash === keyHash,
        )
        if (existing !== undefined) {
          return {
            complete: existing.complete,
            completedDeviceIDs: [...existing.completedDeviceIds],
          }
        }

        const record = {
          keyHash,
          complete: false,
          completedDeviceIds: [],
          createdAt: new Date(this.clock()).toISOString(),
          expiresAt: new Date(
            this.clock() + ttlSeconds * 1000,
          ).toISOString(),
        }
        this.#data.deliveries.push(record)
        await this.#persist()
        return { complete: false, completedDeviceIDs: [] }
      })
    })
  }

  async markDeviceDelivered(identifier, deviceID) {
    return this.#exclusive(async () => {
      this.#requireReady()
      return this.#transaction(async () => {
        const record = this.#delivery(identifier)
        if (!record.completedDeviceIds.includes(deviceID)) {
          record.completedDeviceIds.push(deviceID)
          await this.#persist()
        }
      })
    })
  }

  async completeDelivery(identifier) {
    return this.#exclusive(async () => {
      this.#requireReady()
      return this.#transaction(async () => {
        const record = this.#delivery(identifier)
        if (!record.complete) {
          record.complete = true
          await this.#persist()
        }
      })
    })
  }

  async flush() {
    await this.#queue
  }

  #delivery(identifier) {
    const keyHash = hash(identifier)
    const record = this.#data.deliveries.find(
      (item) => item.keyHash === keyHash,
    )
    if (record === undefined) {
      throw new Error("The delivery reservation is missing.")
    }
    return record
  }

  async #withIdempotency(idempotency, operation) {
    return this.#transaction(async () => {
      this.#prune()
      const keyHash = hash(idempotency.key)
      const existing = this.#data.idempotency.find(
        (item) => item.scope === idempotency.scope && item.keyHash === keyHash,
      )
      if (existing !== undefined) {
        if (existing.requestHash !== idempotency.requestHash) {
          throw conflict("The Idempotency-Key was reused for another request.")
        }
        return {
          status: existing.status,
          body: existing.body,
          replayed: true,
        }
      }

      const result = await operation()
      this.#data.idempotency.push({
        scope: idempotency.scope,
        keyHash,
        requestHash: idempotency.requestHash,
        status: result.status,
        body: result.body,
        createdAt: new Date(this.clock()).toISOString(),
        expiresAt: new Date(
          this.clock() + idempotency.ttlSeconds * 1000,
        ).toISOString(),
      })
      await this.#persist()
      return { ...result, replayed: false }
    })
  }

  async #transaction(operation) {
    const previous = structuredClone(this.#data)
    try {
      return await operation()
    } catch (error) {
      this.#data = previous
      throw error
    }
  }

  #prune() {
    const now = this.clock()
    this.#data.idempotency = this.#data.idempotency.filter(
      (item) => Date.parse(item.expiresAt) > now,
    )
    this.#data.deliveries = this.#data.deliveries.filter(
      (item) => Date.parse(item.expiresAt) > now,
    )
  }

  #sealRegistration(registration) {
    const metadata = {
      deviceId: registration.deviceId,
      profileId: registration.profileId,
      accountId: registration.accountId,
      environment: registration.environment,
      topic: registration.topic,
      createdAt: registration.createdAt,
      updatedAt: registration.updatedAt,
    }
    return {
      ...metadata,
      tokenHash: hash(registration.token),
      token: encryptToken(
        registration.token,
        this.encryptionKey,
        associatedData(metadata),
      ),
    }
  }

  async #persist() {
    const directory = dirname(this.filePath)
    const temporaryPath = join(
      directory,
      `.${basename(this.filePath)}.${process.pid}.${randomUUID()}.tmp`,
    )
    let handle
    try {
      handle = await open(temporaryPath, "wx", 0o600)
      await handle.writeFile(`${JSON.stringify(this.#data)}\n`, "utf8")
      await handle.sync()
      await handle.close()
      handle = undefined
      await rename(temporaryPath, this.filePath)
      await chmod(this.filePath, 0o600)
      await syncDirectory(directory)
    } catch (error) {
      await handle?.close().catch(() => {})
      await unlink(temporaryPath).catch(() => {})
      throw error
    }
  }

  #requireReady() {
    if (!this.#ready) {
      throw new Error("The registration store is not ready.")
    }
  }

  #exclusive(operation) {
    const result = this.#queue.then(operation, operation)
    this.#queue = result.catch(() => {})
    return result
  }
}

function emptyData() {
  return {
    version: currentVersion,
    registrations: [],
    idempotency: [],
    deliveries: [],
  }
}

function validateStore(value) {
  if (
    value?.version !== currentVersion ||
    !Array.isArray(value.registrations) ||
    !Array.isArray(value.idempotency) ||
    !Array.isArray(value.deliveries)
  ) {
    throw new Error("The registration store format is unsupported.")
  }
}

function associatedData(registration) {
  return [
    registration.deviceId,
    registration.profileId,
    registration.accountId,
    registration.environment,
    registration.topic,
    registration.createdAt,
    registration.updatedAt,
  ].join("|")
}

function registrationResponse(registration) {
  return {
    registration: {
      deviceId: registration.deviceId,
      profileId: registration.profileId,
      accountId: registration.accountId,
      environment: registration.environment,
      topic: registration.topic,
      updatedAt: registration.updatedAt,
    },
  }
}

async function syncDirectory(directory) {
  const handle = await open(directory, "r")
  try {
    await handle.sync()
  } catch (error) {
    if (error?.code !== "EINVAL" && error?.code !== "EPERM") {
      throw error
    }
  } finally {
    await handle.close()
  }
}
