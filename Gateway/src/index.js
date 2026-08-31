import { readFile } from "node:fs/promises"
import { APNSSender } from "./apns.js"
import { createGateway } from "./app.js"
import { loadConfig } from "./config.js"
import { createLogger } from "./logger.js"
import { AtomicRegistrationStore } from "./store.js"

const logger = createLogger()

async function main() {
  const config = loadConfig()
  const privateKey = await readFile(config.apnsPrivateKeyFile, "utf8")
  const store = new AtomicRegistrationStore({
    filePath: config.dataFile,
    encryptionKey: config.dataEncryptionKey,
  })
  await store.initialise()

  const sender = new APNSSender({
    teamID: config.apnsTeamID,
    keyID: config.apnsKeyID,
    privateKey,
    timeoutMilliseconds: config.requestTimeoutMilliseconds,
  })
  const gateway = createGateway({ config, store, sender, logger })

  await new Promise((resolve, reject) => {
    gateway.server.once("error", reject)
    gateway.server.listen(config.port, config.host, resolve)
  })
  logger.info("WootDesk Push Gateway started.")

  let shuttingDown = false
  const shutdown = async (signal) => {
    if (shuttingDown) {
      return
    }
    shuttingDown = true
    logger.info("WootDesk Push Gateway is stopping.", { signal })

    const forced = setTimeout(() => {
      gateway.server.closeAllConnections()
    }, config.shutdownGraceMilliseconds)
    forced.unref()

    try {
      await gateway.close()
      clearTimeout(forced)
      process.exitCode = 0
    } catch {
      process.exitCode = 1
    }
  }

  process.once("SIGTERM", () => void shutdown("SIGTERM"))
  process.once("SIGINT", () => void shutdown("SIGINT"))
}

main().catch(() => {
  logger.error("WootDesk Push Gateway could not start.")
  process.exitCode = 1
})
