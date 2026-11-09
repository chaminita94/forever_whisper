# Forever Whisper 0.15.5

## Community links disguised as items

WoW Forever could show an addon-blocked warning when an item-looking link in a whisper opened Blizzard's community invite handler.

### Evidence

- Saved whisper markup identified both **[Blackfang]** and **[Mystic Mushroom]** as `clubTicket` links. The visible item names were labels for community invites.
- In WoW Forever, the updated addon displayed **[Mystic Mushroom] [Community link]** with original labels enabled.
- Blizzard routes `clubTicket` links to its Communities invite lookup. [Link handler](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Shared/ItemRefHandlersShared.lua#L152)

### Fix

- Show an amber **[Community link]** warning and keep the invite non-clickable. Enable **Settings → Show community link labels** to see the original label alongside the warning.
- Preview supported item and quest links from their actual link types. Shift-click still inserts a genuine link into the draft.
- Automated checks cover a community invite with an item label, both warning display modes, genuine item previews, and Shift-click insertion.
