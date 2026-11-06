# Forever Whisper

A customizable messenger for World of Warcraft whispers, with persistent conversations, themed artwork, and combat-friendly behavior.

**Current source: 0.15.4-local; published release: 0.15.3.** Supports Classic Era and Forever.

## Features

- Twelve font choices, including rounded, book, technical, compact, fantasy, and playful styles. Dropdowns use custom chevron indicators rather than text arrows.

- Direct dropdown choices for theme, font, language, sound, contact order, and online notification destination. Long lists support filtering and the mouse wheel; sound entries can be previewed before selection.
- Transcript scrolling responds in pixels on each wheel step, including over bubbles.

- Minimal replaces Plum with a flat neutral theme and no decorative artwork, even when artwork is enabled for other themes. Sakura keeps its blossom artwork.
- Automatic Spanish/English UI from your game locale, with a manual override in Settings > Sound / language. Use Reload UI there to apply your choice. Player messages and contact details are never translated.
- 17 native alert sounds, with Listen previews and optional sounds from installed SharedMedia addons; per-contact mute still takes priority.
- Copying releases the keyboard after Ctrl+C, Escape, or Close. Clicking outside the addon releases its text fields while preserving drafts.

- Incoming messages on the left and your replies on the right, with sender labels and timestamps.
- Character and Battle.net conversations, saved message history, unread indicators, and pinned chats.
- A New messages divider marks the unread boundary. Opening a pending chat jumps to it; incoming whispers preserve your position while reading older messages.
- Use the sidebar sort dropdown to choose Recent, A-Z, or Online first; pinned chats stay at the top.
- Mute notifications per contact from the right-click menu. Muted messages remain saved and counted as unread while not being viewed.
- Search by contact name, local nickname, private note, or message text.
- Set a nickname and private note from a contact's right-click menu; these stay local.
- Choose Notify when online individually for the contacts you want to watch. Alerts appear on known offline-to-online transitions and follow the addon sound setting. Choose Popup, Chat, or Popup + Chat in Settings > Popup options. Online popups use a green status icon and wait behind whisper previews; they do not add messages or unread counts. Unknown contacts require available friend/guild status.
- Left- or right-click a web URL to select it in a compact bar inside the conversation, then press Ctrl+C. Escape closes the bar without losing your message draft. Right-click a message for Copy link or Copy links when URLs are present.
- Right-click a message for Copy text or Reply. Copy text opens a selectable field; press Ctrl+C. Reply excerpts are shortened with ... and omit the sender name from the sent prefix.
- Delete a conversation and its saved history from the right-click menu, with confirmation. New whispers can create it again.
- Reply buttons with quoted excerpts, copy chat, and supported native character actions such as invite, ignore, and report.
- A minimap button and `/fw` command; `/fw Name` opens a character conversation.
- Combat fallback to normal WoW chat, optional brief message previews, and reopening after combat.
- Resizable, movable windows with adjustable fonts, text size, opacity, dimensions, and scale.
- Nine color themes, optional themed corner and background artwork, brightness controls, and an artwork preview.
- 103 texture emojis. Other players need compatible addon support to see the images; ordinary whisper text still uses Blizzard chat.
- Optional typing indicators between compatible Forever Whisper users for character whispers. Battle.net typing and read receipts are not supported.

Online status uses information available from Blizzard friends, guild, and Battle.net APIs. Unknown status is shown when reliable information is unavailable. There are no automatic /who queries.

## Installation

Download a packaged release and extract the `ForeverWhisper` folder into your client's `Interface/AddOns` directory. For a source checkout, copy the repository's addon files into a folder named `ForeverWhisper`; developer tools are not needed in game.

The main TOC targets Forever (16001); the Classic TOC targets Classic Era (11509). Compatibility with other clients is not claimed. Check the file's supported game versions when downloading.

Open with `/fw` or the minimap button. Use **Settings > Arrange popup** or `/fw popup` to preview and position combat notifications. Drag the popup to move it, or its bottom-right grip to resize it, including during combat. Geometry saves automatically; `/fw popup reset` restores the default layout. The dismissal timer pauses during adjustments. **Settings > Popup options** controls duration (3-30 seconds), text size (10-20), name-only display, and locking position and size. Close the preview with X or right-click. Settings controls appearance, artwork, history, and behavior. Settings and histories are stored locally in WoW SavedVariables.

## Performance

Message rows are reused, history is bounded, and artwork is static. Social information updates from game events rather than periodic server polling. Static artwork and fonts account for most package size. In-game memory and frame-time measurements are still needed; Python checks do not measure game performance.

## Development

Install Python 3.12, then run:

```sh
pip install -r requirements-dev.txt
python tools/test_whisper.py
```

The tests execute Lua 5.1 using a WoW API test double. They check startup, message routing, histories, drafts, combat behavior, identity handling, and assets. Actual rendering, protected actions, and network delivery require in-game testing.

See [RELEASING.md](RELEASING.md) for tag-triggered CurseForge uploads.

## Credits and license

Code is licensed under MIT; see [LICENSE](LICENSE). Bundled assets retain their separate licenses:

- Twemoji graphics: CC BY 4.0, with attribution in [Emoji/LICENSE-GRAPHICS.txt](Emoji/LICENSE-GRAPHICS.txt).
- All bundled fonts: SIL Open Font License, with copyright notices included in the Fonts directory. See Fonts/SOURCES.md for source links.

World of Warcraft and Battle.net are Blizzard trademarks. This is an independent community addon.
