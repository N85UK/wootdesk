# WootDesk Performance Baseline

Document ID: `WOOT-PERF-001`

Status: In review

Owner: N85 Dev

Last reviewed: 1 September 2026

## Purpose

Records the approved performance baseline for WootDesk and the regression
thresholds the automated checks enforce. A check fails when a threshold is
exceeded, so a regression blocks the build rather than being noticed later on a
device.

## Data policy

Every measurement uses invented data generated inside the test. No real Chatwoot
server, customer, message body, or personal detail is used, and no measurement
contacts a network. The invented large conversation is built in
`ConversationPerformanceTests`, not loaded from a captured payload.

## What is measured

| Check | Workload | Threshold | Observed on the reference machine |
|---|---|---|---|
| Timeline load | Load one page of 5,000 invented messages through the real `ConversationDetailState.loadMessages` path, including deduplication and ordering | 2.0 s | about 0.02 s |
| Timeline scaling | Compare loading 4,000 against 8,000 invented messages | Doubling the input must multiply the time by less than 3.0 | within the ceiling |
| List filter | Apply a search term to 5,000 invented conversations, 50 times | 3.0 s | about 1.0 s |
| Message presentation | Convert 5,000 invented processed message bodies to displayable text | 3.0 s | about 0.13 s |
| Cold launch | Launch to the first-run setup screen with no saved profile, no Keychain access, and no network call | 12.0 s, median of three | about 4.1 s on the iOS Simulator |

### Why cold launch gained a threshold

`XCTApplicationLaunchMetric` records a number. Without a stored baseline it
never fails, so the cold-launch measurement satisfied "measurements run" but
not N85-14 AC6's "the check fails if a documented regression threshold is
exceeded". List and timeline already asserted ceilings; launch did not.

`testLaunchReachesFirstScreenWithinCeiling` now asserts one. It times launch to
the first-run screen appearing, three times, and compares the median so a single
slow run on a loaded machine does not decide the result.

The 12.0 s ceiling was measured, not guessed: three runs gave 5.41, 4.11 and
4.10 seconds. That is roughly the same headroom the list filter carries, 3.0 s
against about 1.0 s observed. Confirmed to fail by temporarily lowering it,
which reported the measured 4.12 s against the ceiling.

The original `measure` block is kept alongside it. It cannot fail, but it
records the trend, which the assertion does not.

## Reference machine

Apple silicon Mac running the supported Xcode version, Debug configuration,
tests run with `-parallel-testing-enabled NO`. Absolute timings on other
hardware will differ. The thresholds are set for that variation.

## Why the thresholds are generous

The thresholds are regression ceilings, not targets. They are deliberately far
above the observed figures for two reasons.

1. A build machine can be momentarily busy. A tight threshold would fail for
   reasons unrelated to the code and would train reviewers to ignore the check.
2. The regressions worth catching are algorithmic. An accidental quadratic scan
   over a large conversation exceeds these ceilings many times over, not
   marginally.

The scaling check exists because an absolute ceiling alone can hide a regression
that is slow but still under the limit at the tested size. Comparing two input
sizes catches a change in the growth rate directly.

## Running the checks

The performance checks run as part of the normal suite:

```bash
./script/ci.sh
```

The cold-launch metric runs with the macOS UI tests, which need the one-time
Automation Mode configuration described in `docs/MACOS_UI_TESTING.md`:

```bash
./script/ci.sh --with-ui-tests
```

## Changing a threshold

A threshold may only be raised with a recorded reason in this document and in
the delivery decision log. Raising a threshold to make a failing check pass,
without establishing why the work grew, is not an acceptable change.

## Outstanding

Physical iPhone and iPad launch and scroll measurements are not yet recorded.
Simulator and Mac timings do not substitute for them, so device acceptance
remains a release gate under N85-18.
