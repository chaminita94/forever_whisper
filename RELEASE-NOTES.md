# Forever Whisper 0.15.0-beta7

Changes since the last published version, 0.15.0-beta2.

## Conversations and contacts

- Add a New messages divider before the first unread incoming message. Opening a pending conversation takes you to that boundary.
- Preserve your reading position when messages arrive while you are browsing older history. Latest messages takes you to the bottom and clears the unread count.
- Add local nicknames and private notes. Search by character name, nickname, note, or message text. Notes appear when hovering a contact and are never sent to the other player.
- Add per-contact Notify when online. It is off by default, can be disabled from the same menu, and alerts on known offline-to-online changes without polling.
- Add per-contact Mute notifications. Muted conversations retain messages, history, and unread badges while suppressing sounds, combat previews, online alerts, and unsolicited window opening.
- Add a sidebar sort button: Recent, A-Z, and Online first. Pinned conversations stay first in every mode.
- Add Delete conversation to character and Battle.net contact menus, with confirmation. This removes its history, pin, unread count, and drafts. A new whisper creates a fresh conversation.

## Messages and replies

- Right-click a message for Copy text or Reply. Copy text opens a selectable field for Ctrl+C.
- Simplify sent quotes to [Reply to: excerpt] answer, leaving the original sender's name out of the prefix.
- Shorten long quoted excerpts with ... while preserving the complete original message in history. Older quoted replies remain readable.

## Combat popup customization

- Drag the combat notification to move it and resize it from the bottom-right grip, including during combat.
- Save popup position and size separately from the main window.
- Pause automatic dismissal while moving or resizing, then resume the selected duration.
- Add Settings > Arrange popup for a persistent preview. /fw popup opens it and /fw popup reset restores the default geometry.
- Add Settings > Popup options: duration from 3 to 30 seconds, text size from 10 to 20, show only the sender's name, and lock position and size.

## Fixes and polish

- Fix the main window jumping when starting or finishing a resize. Keep the top-left corner fixed, respect UI scale, and remove the release-time size snap.
- Save the main window's position consistently after moving and resizing.
- Make sidebar status icons visible above avatar backgrounds and explicitly label Online, Offline, or Unknown before app/location information.
- Refresh Battle.net status on friend login/logout events.
- Apply hidden BattleTag discriminators to existing saved profiles as well as new conversations.
- Reuse message/divider frames and keep resizing updates active only while dragging.

## Compatibility and beta notes

- Intended for Classic Era and Forever. This remains a beta; recent changes have automated coverage but still need in-game testing on both clients.
- Character presence depends on the friend/guild information available from Blizzard. Unknown is shown when reliable status is unavailable.
- Typing indicators require compatible Forever Whisper installations on both sides for character whispers. Battle.net typing and read receipts are not supported.
- Existing history and settings are retained. Back up SavedVariables before beta testing.
