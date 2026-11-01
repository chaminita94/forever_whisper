# Forever Whisper 0.15.2

## Links and keyboard focus

- Click or right-click http://, https://, and www. links to select the URL in a compact bar inside the chat. Ctrl+C copies it and closes the bar after the copy keystroke; Escape or Close also releases keyboard focus.
- Add Copy link / Copy links to message menus. Preserve queries, Unicode, balanced parentheses, native WoW links, and the original sent/saved text.
- Stop returning keyboard focus to the composer after copying. Clicking outside the addon releases its text fields without deleting drafts or changing another addon's focused field.
- Keep deliberate typing actions: clicking an input, choosing Whisper/Reply, inserting a message shortcut or emoji, and continuing after sending.

## Language

- Automatically use Spanish for esES/esMX game clients and English for other clients.
- Add Settings > Sound / language with Automatic, Español, and English choices. The explicit Reload UI button applies the selection when the player chooses.
- Translate addon controls, dialogs, status labels, tooltips, emoji descriptions, and search hints. Names, nicknames, private notes, custom shortcuts, message history, URLs, and reply protocols remain intact.

## Sounds

- Expand to 17 native WoW sounds, including drum, troll gong, a hunting horn, alarms, boss warnings, character greetings, and warning voices. The original five choices keep their saved indices.
- Add a Listen button to preview the selected sound without enabling notifications.
- Respect the main whisper-sound toggle, the SFX audio channel, and per-contact mute. No bundled audio files or required sound library.
- Offer sounds already registered by other addons through LibSharedMedia when available. External selections are saved by name; missing assets fall back safely for notifications.

## Minimal theme

- Replace the similar Plum theme with Minimal: neutral flat colors, no corner/header/background artwork, no decorative message rails, and no top accent stripe.
- Minimal stays undecorated even when global artwork is enabled. Switching to another theme restores that theme's art without changing the global preference.
- Preview shows a no-artwork notice and hides irrelevant brightness controls for Minimal.

## Dropdowns and scrolling

- Replace cycling selectors with direct dropdown choices for theme, font, language, sound, contact order, and online-alert destination. Sliders and boolean toggles remain direct controls.
- Long dropdowns have a text filter and mouse-wheel scrolling. Sound rows offer preview buttons that do not change the saved selection.
- Dismiss menus on outside clicks or hiding the owner; do not steal composer focus.
- Scroll the transcript by pixel distance on the first wheel step, including over message bubbles, rather than by whole-message boundaries. Preserve unread behavior and the Latest messages action without idle animation updates.

## Dropdown indicators and more fonts

- Replace the literal v suffix with custom drawn chevrons, separated from the control text. They point up while open, down while closed, and use the theme accent on hover. No Blizzard arrow textures or animation loops.
- Add six static OFL font families: Questrial, Gentium Book Plus, Rajdhani, Asap Condensed, Almendra, and Carter One. There are now twelve font choices, with existing saved indices preserved.
- Include each font license and source reference, and check Spanish accents and punctuation.

## Dropdown visibility and Classic sound compatibility

- Keep button labels independent of native pressed/hover font states. Give dropdown captions and rows explicit text bounds and a consistent readable menu font; the chosen font still applies to the conversation and preview.
- Remove the unavailable war horn from the menu. Existing war-horn selections migrate to Hunting horn without shifting other saved sound choices.
- Keep WoW sound volume unchanged; no global volume controls or temporary volume changes.
