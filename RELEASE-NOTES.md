# Forever Whisper 0.15.1

Official release of the messenger update for Classic Era and Forever.

## New in this release

- Online notifications now share the whisper popup's position, style, duration, and font, with a green online icon.
- Choose Popup, Chat, or Popup + Chat under Settings > Popup options. Enable Notify when online separately for the contacts you want to follow.
- Whispers have priority: online alerts wait while a whisper popup is visible. Alerts for contacts who went offline, were muted, were deleted, or had notifications disabled are skipped.
- Online notifications do not create messages, unread badges, or open conversations.
- Fix dragging jumps in the main window, title bar, and popup. Movement preserves the grab offset and respects UI scale.
- Stop dragging when the window is hidden or the mouse is released, and prevent moving and resizing simultaneously.

## Messenger improvements included

- Incoming messages on the left and your replies on the right, with readable sender labels, timestamps, and date separators.
- Battle.net conversations alongside character whispers, with stable recipient identities and drafts preserved when sending fails.
- New messages divider at the unread boundary. Opening a pending chat takes you there; incoming messages preserve your position while reading older history.
- Right-click messages for Copy text or Reply. Sent replies use [Reply to: excerpt] answer, with long excerpts shortened using ... .
- Local nicknames and private notes, searchable with names and message history. Notes are visible on hover and are never sent to the other player.
- Per-contact Mute notifications preserves history and unread counts while suppressing sounds, popups, online alerts, and unsolicited opening.
- Contact sorting by Recent, A-Z, or Online first, with pinned conversations always first.
- Delete conversation with confirmation, including its saved history, pin, unread count, and drafts. A new whisper creates a fresh chat.

## Popup and window customization

- Move and resize combat whisper popups independently from the main chat window, including during combat. Layout saves automatically.
- Set popup duration from 3 to 30 seconds, text size from 10 to 20, name-only display, and position/size locking.
- Preview with Settings > Arrange popup or /fw popup; restore default geometry with /fw popup reset.
- Pause dismissal while moving or resizing, then resume the selected duration.
- Fix resize jumps, release-time size snapping, window position saving, and the Latest messages button's click area.

## Presence and privacy

- Visible Online, Offline, and Unknown sidebar indicators, updated from available friend, guild, and Battle.net events without automatic /who queries or idle polling.
- Hide BattleTag discriminators in visible contact labels, including existing saved profiles, while retaining full identities internally for routing.
- Optional character typing indicators between compatible Forever Whisper users. Battle.net typing and read receipts are not supported.
- Existing settings and chat history are retained.
