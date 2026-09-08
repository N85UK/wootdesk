export function createLogger(output = console) {
  function write(level, message, context = {}) {
    output.log(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        level,
        message,
        ...sanitise(context),
      }),
    )
  }

  return Object.freeze({
    info: (message, context) => write("info", message, context),
    warn: (message, context) => write("warn", message, context),
    error: (message, context) => write("error", message, context),
  })
}

/**
 * An allowlist rather than a denylist, so a field has to be considered before
 * it can be logged. Anything not named here is dropped silently, which is the
 * right default for a service that handles device tokens and webhook bodies.
 *
 * The cost of that default is that a field added to a log call and forgotten
 * here simply never appears. That happened with `deploymentId`: the routing
 * decisions for N85-64 were being logged without saying which Chatwoot they
 * concerned, which is the one thing those lines exist to record.
 */
function sanitise(context) {
  const allowed = [
    "requestId",
    "method",
    "route",
    "status",
    "durationMilliseconds",
    "deliveryOutcome",
    "count",
    "signal",
    // N85-64. An operator-chosen deployment name such as "default" or
    // "review", the number of deployments configured, and the fixed remedy
    // text shown when registrations cannot be attributed. None of these carry
    // anything a reader supplied.
    "deploymentId",
    "deploymentCount",
    "remedy",
  ]
  return Object.fromEntries(
    Object.entries(context).filter(([key]) => allowed.includes(key)),
  )
}
