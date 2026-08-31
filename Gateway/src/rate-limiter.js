export class SlidingWindowRateLimiter {
  #entries = new Map()

  constructor({ windowMilliseconds, clock = () => Date.now() }) {
    this.windowMilliseconds = windowMilliseconds
    this.clock = clock
  }

  allow(key, limit) {
    const now = this.clock()
    const oldest = now - this.windowMilliseconds
    const recent = (this.#entries.get(key) ?? []).filter(
      (timestamp) => timestamp > oldest,
    )
    if (recent.length >= limit) {
      this.#entries.set(key, recent)
      return false
    }
    recent.push(now)
    this.#entries.set(key, recent)
    this.#prune(oldest)
    return true
  }

  #prune(oldest) {
    if (this.#entries.size < 1_000) {
      return
    }
    for (const [key, timestamps] of this.#entries) {
      if (timestamps.every((timestamp) => timestamp <= oldest)) {
        this.#entries.delete(key)
      }
    }
  }
}
