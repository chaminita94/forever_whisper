# Forever Whisper 0.15.0-beta2

## Privacy and usability fixes

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
