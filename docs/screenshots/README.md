# App Store Screenshots

Document ID: `WOOT-SHOTS-001`

Status: Draft, awaiting release-owner review

Last captured: 3 September 2026

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
| `iphone-6.5/` | iPhone 13 Pro Max | 1284 x 2778 | iPhone 6.5 inch, **the slot App Store Connect actually shows** |
| `iphone-6.9/` | iPhone 17 Pro Max | 1320 x 2868 | iPhone 6.9 inch |
| `ipad-13/` | iPad Pro 13-inch (M5) | 2064 x 2752 | iPad 13 inch |
| `mac-2880/` | MacBook Pro Mac16,8 | 2880 x 1800 | Mac, one of Apple's four accepted sizes |

The listing for this app presents a **6.5 inch** iPhone slot, which accepts
1242 x 2688, 2688 x 1242, 1284 x 2778 or 2778 x 1284. The 6.9 inch captures do
not fit it. App Store Connect states it will use the 6.5 inch screenshots for
all iPhone display sizes, so that set is the one to complete first.

## Current set

| File | Shows |
|---|---|
| `iphone-6.9/01-conversation-list.png` | Conversation list with status filter, search, priority, inbox, and unread counts |
| `iphone-6.9/02-conversation-and-triage-actions.png` | Message timeline with a private note and an attachment, the triage action row, and the reply composer |
| `iphone-6.9/03-status-actions-menu.png` | The status menu, with the current value marked by a symbol rather than by colour alone |
| `ipad-13/01-three-column-workspace.png` | The three adjacent areas: workspace sidebar, conversation list, and conversation detail |
| `mac-2880/01-conversation-and-triage.png` | The Mac three-column layout with the triage action row, a private note, attachment metadata, and the reply composer |

## Capturing the Mac set

The window is sized to 1440 x 900 points, which on a Retina display captures at
2880 x 1800 pixels, one of the four sizes App Store Connect accepts for Mac.

```bash
open build/shots/Build/Products/Release/WootDesk.app --args --uitesting-conversations
osascript -e 'tell application "System Events" to tell process "WootDesk"
  set position of window 1 to {60, 60}
  set size of window 1 to {1440, 900}
end tell'
screencapture -o -R 60,60,1440,900 -x docs/screenshots/mac-2880/01-conversation-and-triage.png
```

Select a conversation before capturing. An empty detail pane reading "No
Conversation Selected" is a poor advertisement and hides the triage row, the
private-note presentation and the composer, which are the things worth showing.

### A defect this capture found

With a conversation selected, the Mac toolbar showed **two identical refresh
buttons**. `ConversationListView` and `ConversationDetailView` each add a
`.primaryAction` toolbar item using `arrow.clockwise`. On iOS they sit in
separate navigation bars and only one is ever visible; macOS unifies the split
view's toolbar, so both appeared side by side with nothing to tell them apart,
and only the list one carries the Command R shortcut.

The detail action now uses `arrow.clockwise.circle`, so the two are
distinguishable.

### Still outstanding: dead space in the macOS conversation list

The conversation list column has a band of empty space above and below the
status filter on macOS. It is cosmetic, visible in the current capture, and not
yet diagnosed. What is known, measured through the accessibility API with the
window at 1440 x 900 points:

| Element | Position |
|---|---|
| Column content begins | y = 112, below the toolbar |
| Status filter | y = 204, height 24 |
| List scroll area | y = 321, extending to the window bottom |

That leaves **92 points above the filter and 93 points below it**, almost
perfectly symmetric, as though the 24 point control is centred in a 208 point
band.

Ruled out so far:

- **`.searchable`.** Moving it from the `VStack` onto the list changed nothing,
  and removing it entirely changed nothing. The measurements were identical in
  all three builds.
- **Flexible layout.** The gaps stay at exactly 92 and 93 points with the
  window at 700 and at 1200 points tall, so this is fixed spacing rather than
  a stack distributing free space.
- **The `safeAreaInset` in `profileRecoveryState`.** That inset omits
  `spacing: 0` and would contribute default spacing, but it wraps a different
  view that the conversation list never goes through.

The `VStack(spacing: 0)` in `ConversationListView.body` applies only
`.padding(.vertical, 8)` around the filter, so the space is being introduced by
something outside that view, most likely the surrounding `NavigationSplitView`
column or a modifier applied to it in `WootDeskApp`.

## Uploaded to App Store Connect

`iphone-6.5/01-conversation-list.png` is uploaded against iOS version 1.0 and
build 24. The listing shows "1 of 10 Screenshots".

## Known gaps

* Only one 6.5 inch screenshot is uploaded. The conversation detail and the
  triage menu still need capturing at 1284 x 2778. Driving taps on the
  simulator needs simulator device access to be granted from the panel; the
  request went unanswered, so only the launch screen could be captured
  unattended.
* The iPad set shows the empty detail column, for the same reason.
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
