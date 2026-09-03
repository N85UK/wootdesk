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

### Fixed: dead space in the macOS conversation list

The conversation list column had a band of empty space above and below the
status filter, roughly 92 points on each side, with the 24 point control
centred inside it.

**Cause.** `Picker("Status Filter", selection:)` carries a label. macOS
reserves vertical space for a Picker's label even under `.segmented` style and
centres the control within that reservation. The label is never drawn, so the
space was invisible and unexplained. `.labelsHidden()` removes the reservation.
VoiceOver is unaffected: the control still reports
"Status Filter, Filter conversations by status", read from the running app.

**How it was found.** Reasoning about the view hierarchy was consistently
wrong, and five rebuilds ruled out plausible-sounding causes without getting
closer:

| Ruled out | Evidence |
|---|---|
| `.searchable` | Moved onto the list, then removed entirely. Identical measurements both times |
| Flexible layout | Gaps stayed at exactly 92 and 93 points with the window at 700 and 1200 points tall |
| `.safeAreaInset` | The one omitting `spacing: 0` wraps `profileRecoveryState`, which this view never goes through |
| `.navigationTitle` | Removed, no change |
| `.toolbar` | Removed, verified gone from the screenshot, no change |
| `.listStyle(.inset)` | Switched to `.plain`, no change |
| `.fixedSize(vertical:)` | No change, which proved the large height was the Picker's *ideal* size rather than expansion |

What actually found it was giving the picker and its padded container different
background colours and looking at the result. The Picker's own bounds filled
the whole band immediately and unambiguously.

The lesson worth keeping: measuring the accessibility tree gave precise numbers
but never identified the culprit, because SwiftUI's internal containers are not
exposed there. Colouring the suspect view answered it in one build.
