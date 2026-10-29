# Group Gazette

*One quiet board for every LFM message in chat.*

![WoW version](https://img.shields.io/badge/WoW-3.3.5a_WotLK-89502c?style=flat-square)
![Version](https://img.shields.io/badge/version-1.0.1-33ff99?style=flat-square)
![ElvUI](https://img.shields.io/badge/ElvUI-optional_skin-5865f2?style=flat-square)

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Commands](#commands)

---

Trade chat moves fast, and the groups you actually want get buried under spam within seconds. Group Gazette listens to every LFM message (`LFM`, `LF1M`–`LF9M`) in general/trade channels, Say and Yell, and gathers them into a single sortable bulletin board — searchable, deduplicated by poster, and auto-pruned as listings age out.

## Features

- **Live bulletin board** — every LFM message appears as a row: time since posted, class-colored poster name, and the full message.
- **Instant search** — filter the board by message text or player name as you type.
- **One row per poster** — no duplicate spam; a repost just updates the existing entry.
- **Click to whisper** — hover a row for channel and age details, click it to send a tell.
- **Hover freeze** — the list pauses while your cursor rests on an entry, so rows never shift as you read.
- **Watch keywords** — get a chat alert and an optional sound when a new listing mentions your keyword (e.g. `icc`, `toc`).
- **Chat decluttering** — optionally hide LFM messages from your chat frames entirely.
- **Expiring listings** — entries disappear after a configurable delay (30–900 s, default 60 s).
- **Optional ElvUI skin** — blends in with your ElvUI theme automatically; falls back to the standard Blizzard look if ElvUI is absent or the skin fails.

## Installation

1. Download or clone this repository.
2. Copy the `GroupGazette` folder into your `Interface/AddOns` directory:

   ```text
   Interface/AddOns/GroupGazette/
   ├── GroupGazette.toc
   ├── Core.lua          -- parsing, storage, events, slash commands
   ├── UI.lua            -- the board window
   └── Skin_ElvUI.lua    -- optional ElvUI skin
   ```

3. Restart the game (or type `/reload`).
4. Type `/gazette` to open the board.

> [!NOTE]
> There are no required dependencies. [ElvUI](https://github.com/tukui-org/ElvUI) is optional — the board skins itself only if ElvUI is loaded.

## Usage

Open the board with `/gazette`. It only collects from the moment you log in, so keep it loaded while you look for a group.

- **Search** — type in the search box to filter by message or player name.
- **Whisper** — left-click a row to open a whisper to that player.
- **Hover** — a tooltip shows the channel it was posted in and how old it is; the list freezes while you hover.
- **Drag** the window anywhere; the position is saved between sessions. Press `Esc` to close.
- **Clear board** — empties all current listings.

> [!TIP]
> Set up watch keywords before the raid rush: `/gazette watch icc` alerts you the moment someone posts a fresh LFM mentioning *icc* — even while the board is closed.

## Commands

All options live under the `/gazette` (or `/groupgazette`) command:

| Command | Description |
| --- | --- |
| `/gazette` | Open or close the board |
| `/gazette clear` | Empty the board |
| `/gazette expire <seconds>` | How long listings stay (30–900, default 60) |
| `/gazette watch <keyword>` | Toggle a watch keyword; `/gazette watch` lists all, `/gazette watch clear` removes them |
| `/gazette sound` | Toggle the alert sound for keyword hits |
| `/gazette hide` | Toggle hiding LFM messages from chat frames |
| `/gazette skin` | Toggle the ElvUI skin (needs `/reload`) |
| `/gazette reset` | Reset the window position |
| `/gazette help` | Show the command list |