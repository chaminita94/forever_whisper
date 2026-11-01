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

## Messenger update included in this beta

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
