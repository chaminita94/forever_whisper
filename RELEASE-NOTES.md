# Forever Whisper 0.15.3

## Hotfix: item linking

- Fix Shift-clicking items into the message box while composing a whisper. Tested in game on WoW Forever.
- Support both the legacy chat-link API and the newer ChatFrameUtil API without inserting the link twice or interfering with normal chat and other addons.
- Keep item links intact when inserting and sending. If a link would exceed the message limit, leave the draft unchanged instead of cutting the link.
- Preserve outside-click keyboard release. Only an intentional item-link click returns focus to the composer; unrelated clicks still let you move normally.
