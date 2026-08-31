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
  ]
  return Object.fromEntries(
    Object.entries(context).filter(([key]) => allowed.includes(key)),
  )
}
