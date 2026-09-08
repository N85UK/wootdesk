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

  constructor({
    filePath,
    encryptionKey,
    clock = () => Date.now(),
    deployments = [],
    logger = { info() {}, warn() {} },
  }) {
    this.filePath = filePath
    this.encryptionKey = encryptionKey
    this.clock = clock
    this.deployments = deployments
    this.logger = logger
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
      await this.#attributeLegacyRegistrations()
      this.#ready = true
    })
  }

  /**
   * Attributes registrations written before deployment scoping (N85-64 AC5).
   *
   * A registration stored by an older gateway has no deployment, and the
   * routing filter matches on deployment, so such a registration matches
   * nothing and its device silently stops receiving notifications. That is the
   * safe failure and the criterion demands it: a registration must never be
   * routed to a deployment it was not enrolled against. It is not an
   * acceptable place to leave things, though, so the two cases are handled
   * differently.
   *
   * With exactly one deployment configured there is no ambiguity. The device
   * enrolled against that Chatwoot because it is the only one this gateway has
   * ever served, so it is attributed and the file is rewritten once.
   *
   * With more than one, there is no honest answer. Picking one would be
   * guessing, and guessing wrong notifies a device about another company's
   * conversations. They are left unattributed, and the operator is told how
   * many and what to do, because a silent gap in delivery is far harder to
   * diagnose than a noisy one.
   */
  async #attributeLegacyRegistrations() {
    const legacy = this.#data.registrations.filter(
      (item) => item.deploymentId === undefined,
    )
    if (legacy.length === 0) {
      return
    }

    if (this.deployments.length !== 1) {
      this.logger.warn(
        "Registrations from before deployment scoping were not attributed and will not be notified.",
        {
          count: legacy.length,
          deploymentCount: this.deployments.length,
          remedy:
            "This gateway serves more than one Chatwoot, so these cannot be attributed safely. The affected devices must enrol again.",
        },
      )
      return
    }

    const [only] = this.deployments
    for (const item of legacy) {
      item.deploymentId = only.id
    }
    await this.#persist()
    this.logger.info(
      "Registrations from before deployment scoping were attributed to the only configured deployment.",
      { count: legacy.length, deploymentId: only.id },
    )
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

  /// Recipients for one event.
  ///
  /// An assigned conversation goes only to devices enrolled by that agent. An
  /// unassigned one goes to every device on the account, which matches how
  /// Chatwoot itself treats an unassigned conversation. Registrations that
  /// carry no agent identity can never match an assignee; the caller reports
  /// them so the condition is visible rather than silent.
  /**
   * Selects the devices to notify for one event (N85-64 AC1 and AC2).
   *
   * Filtering is by deployment first, then account, then assignee. The
   * deployment filter is the one this method exists for: an account number is
   * only unique within a Chatwoot, so two deployments that both have an
   * account numbered 1 previously selected each other's registrations.
   *
   * `otherDeployments` counts registrations that matched the account and
   * assignee but belong to a different Chatwoot. They are exactly the devices
   * the old behaviour would have notified and this one does not, so the caller
   * logs the count. Without it, the fix working and delivery being broken look
   * identical from the outside.
   */
  async registrationsForEvent(deploymentID, accountID, assigneeID, ttlDays) {
    const all = await this.registrationsForAccount(accountID, ttlDays)

    const mine = all.filter((item) => item.deploymentId === deploymentID)
    const otherDeployments = all.length - mine.length

    if (assigneeID === undefined) {
      return { recipients: mine, unroutable: 0, otherDeployments }
    }
    const recipients = mine.filter((item) => item.agentId === assigneeID)
    const unroutable = mine.filter((item) => item.agentId === undefined).length
    return { recipients, unroutable, otherDeployments }
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
            // Not part of the response body, but routing needs it.
            deploymentId: item.deploymentId,
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
      agentId: registration.agentId,
      // Which Chatwoot this device enrolled against (N85-64 AC4). Persisted
      // here because this list is the whole of what is stored: a field absent
      // from it is silently dropped on write, which is how the first version
      // of this change routed nothing at all.
      deploymentId: registration.deploymentId,
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

/**
 * The additional data the device token is sealed against.
 *
 * `deploymentId` is deliberately not included, matching `agentId`, which is
 * equally routing-critical and equally absent. Adding either would bind the
 * token to it cryptographically, but the only attacker it would stop is one
 * who can already rewrite this file, and that attacker has better options.
 * The cost would be real: every registration written before deployment
 * scoping would need decrypting and resealing during the upgrade in AC5,
 * turning a field assignment into a migration that can fail halfway.
 */
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
      agentId: registration.agentId,
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
