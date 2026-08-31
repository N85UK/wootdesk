export class GatewayError extends Error {
  constructor(status, code, message) {
    super(message)
    this.name = "GatewayError"
    this.status = status
    this.code = code
  }
}

export function badRequest(code, message) {
  return new GatewayError(400, code, message)
}

export function unauthorised() {
  return new GatewayError(401, "unauthorised", "Authentication failed.")
}

export function notFound() {
  return new GatewayError(404, "not_found", "The requested resource was not found.")
}

export function conflict(message = "The request conflicts with existing state.") {
  return new GatewayError(409, "conflict", message)
}

export function tooLarge() {
  return new GatewayError(413, "payload_too_large", "The request body is too large.")
}

export function rateLimited() {
  return new GatewayError(429, "rate_limited", "Too many requests. Try again later.")
}

export function unavailable() {
  return new GatewayError(503, "not_ready", "The service is not ready.")
}
