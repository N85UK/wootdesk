# App Store Screenshots

Document ID: `WOOT-SHOTS-001`

Status: Draft, awaiting release-owner review

Last captured: 1 September 2026

## Data policy

Every screenshot shows invented data served by `StubChatwootAPI` through the
`--uitesting-conversations` launch argument. No real Chatwoot server, customer,
message, or personal detail appears. The contacts, message text, labels, and
account names are the fictional values in `PreviewData`, and addresses use
`example.invalid`.

## Captured sizes

App Store Connect accepts one set per display class. These match the required
pixel dimensions exactly, captured at native simulator resolution.

| Directory | Device | Pixels | App Store display class |
|---|---|---|---|
| `iphone-6.9/` | iPhone 17 Pro Max | 1320 x 2868 | iPhone 6.9 inch |
| `ipad-13/` | iPad Pro 13-inch (M5) | 2064 x 2752 | iPad 13 inch |

## Current set

| File | Shows |
|---|---|
| `iphone-6.9/01-conversation-list.png` | Conversation list with status filter, search, priority, inbox, and unread counts |
| `iphone-6.9/02-conversation-and-triage-actions.png` | Message timeline with a private note and an attachment, the triage action row, and the reply composer |
| `iphone-6.9/03-status-actions-menu.png` | The status menu, with the current value marked by a symbol rather than by colour alone |
| `ipad-13/01-three-column-workspace.png` | The three adjacent areas: workspace sidebar, conversation list, and conversation detail |

## Known gaps

* The iPad set shows the empty detail column. A capture with a conversation
  selected needs a tap on the iPad simulator, which requires simulator device
  access to be granted, or a manual tap before capturing.
* No macOS screenshots are captured yet. macOS App Store listings need their own
  set at 2880 x 1800 or another accepted Mac size.
* The set has not been reviewed or ordered for the store listing. Ordering,
  captions, and any framing are the release owner's decision.

## Regenerating

Build once for the simulator, then install and launch with the invented-data
argument. The simulator is sandboxed away from external volumes, so capture to a
local path and copy the file into the repository afterwards.

```bash
xcodebuild build -project WootDesk.xcodeproj -scheme WootDesk \
  -destination "generic/platform=iOS Simulator" -configuration Debug \
  -derivedDataPath build/sim \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

```bash
xcrun simctl boot "iPhone 17 Pro Max"
```

```bash
xcrun simctl install booted build/sim/Build/Products/Debug-iphonesimulator/WootDesk.app
```

```bash
xcrun simctl launch booted dev.n85.wootdesk --uitesting-conversations
```

```bash
xcrun simctl io booted screenshot --type=png ~/Desktop/wootdesk-shot.png
```

Never capture a screenshot from a build connected to a real Chatwoot server. A
store screenshot is published, and a real conversation in one would disclose
customer data.
