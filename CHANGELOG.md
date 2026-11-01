# Forever Whisper 0.15.2 - local test

- Make http://, https://, and www. URLs clickable inside conversations. Clicking opens a selected URL in the copy window; press Ctrl+C.
- Add Copy link to message right-click menus, or Copy links when the message contains several URLs.
- Preserve URL query strings, Unicode bytes, and balanced parentheses; avoid copying surrounding prose punctuation.
- Preserve native WoW item/player links and texture escapes.
- Keep outgoing messages and saved history as their original plain text. URL markup is local display only.

Not yet published to CurseForge.

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

# Forever Whisper 0.15.0-beta6

## Contact customization and message actions

- Add local nicknames and private notes from each contact's right-click menu. Both are searchable; notes appear on hover. They are never sent to the other player.
- Add Notify when online as an opt-in setting for each contact. Disable it from the same menu. Alerts use available friends, guild, and Battle.net events, without polling, and fire on known offline-to-online transitions.
- Add right-click message actions for Copy text and Reply. Copy text opens a selectable text field for Ctrl+C.
- Send quoted replies as [Reply to: excerpt] answer, without the original sender's name in the prefix.
- Shorten long reply excerpts to 48 bytes, adding ... without splitting UTF-8 characters. The original message stays in history.
- Continue reading the older named quote format.

# Forever Whisper 0.15.0-beta5

## Adjustable combat popup

- Drag combat whisper notifications to move them, including during combat.
- Resize them from the bottom-right grip; position and dimensions are saved separately from the main chat window.
- Pause automatic dismissal while moving or resizing, then resume the usual seven-second timer.
- Add Settings > Arrange popup for a persistent preview, plus /fw popup and /fw popup reset commands.
- Keep the larger message area responsive to the chosen popup size, without idle frame updates.

# Forever Whisper 0.15.0-beta4

## Conversation management and resizing

- Add Delete conversation to character and Battle.net right-click menus, with confirmation.
- Remove the deleted contact's history, pin, unread count, draft, and quote draft. Other chats stay intact; a new whisper creates a fresh conversation.
- Fix the bottom-right resize grip jumping when clicked by resizing from cursor movement instead of snapping an edge to the cursor.
- Keep the top-left corner fixed while resizing, respect window scale, and avoid 10-pixel snapping on release.
- Save window position consistently after moving and resizing.

# Forever Whisper 0.15.0-beta3

## Sidebar presence fixes

- Draw online/offline indicators above the avatar background so they remain visible.
- Show explicit Online, Offline, or Unknown status before app and location details.
- Refresh Battle.net presence on friend account login and logout events without polling.
- Apply hidden BattleTag labels to existing profiles, keeping full identity keys internal.

# Forever Whisper 0.15.0-beta2

## Privacy and usability fixes

- Fix message rows intercepting clicks in the middle of the Latest messages button.
- Hide BattleTag discriminators such as #1234 from contact labels, headings, sender labels, and combat notifications.
- Hide discriminators in old quoted-message labels, search previews, and copied conversations. Full BattleTags remain internal for reliable routing.
- Replace loose reply arrows with compact labeled Reply buttons and larger click targets.
- Separate quoted sender names and excerpts from the new message.

# Forever Whisper 0.15.0-beta1

This beta brings the messenger update to Classic Era and adds Battle.net conversations.

## New

- Incoming messages appear on the left and your replies on the right.
- Reply arrows let you quote a specific message.
- Optional short message previews during combat, with normal WoW chat fallback.
- Capture incoming and outgoing Battle.net whispers and reply from the addon.
- Battle.net conversations keep a stable identity across reconnects and stay separate from character chats.
- Optional typing indicators between compatible Forever Whisper users in character conversations.
- Friend, guild, and Battle.net status information where Blizzard provides it, without automatic /who queries.

## Fixes

- Fix initialization stopping before the composer, settings, and minimap button appear.
- Merge same-realm character aliases while preserving message history.
- Preserve drafts when a Battle.net recipient disconnects or sending fails.
- Keep drafts, reply quotes, and unread counts associated with the correct conversation.

## Beta notes

- Recent changes need further in-game testing on Forever and Classic Era. Automated checks use a WoW API test double.
- Typing indicators require compatible Forever Whisper installations on both sides and do not work for Battle.net conversations.
- Emoji images require compatible addon support on the receiving side.
- Players outside the available friend/guild information may show unknown status.
- Existing chat history and settings are retained. As with any beta, back up SavedVariables before testing.

# Changelog

## 0.15.0 — development build

- Capture incoming and outgoing Battle.net whispers with stable conversation identities.
- Route Battle.net replies through native Battle.net whisper APIs.
- Preserve drafts when a recipient is disconnected or sending fails.
- Keep Battle.net names separate from character conversations.

## 0.14.1

- Fix startup stopping before settings, the composer, and the minimap button are created.
- Merge same-realm character aliases while preserving message history.

## 0.14.0

- Add reply quotes and optional typing indicators between compatible Forever Whisper users.

## 0.13.0

- Add incoming messages on the left and outgoing messages on the right.
- Add optional, brief combat message previews.
