# ElvUI Dynamic Raid Frames (EDRF)

EDRF is a lightweight **WeakAura** that dynamically switches between your ElvUI raid headers (party / raid1 / raid2 / raid3) based on group size and applies a few **safe, minimal** settings to keep layouts consistent.

**Repo:** https://github.com/PeluxGit/ElvUI-Dynamic-Raid-Frames

---

## What it does

**Main use case:** handle raids where groups are **not filled sequentially**. ElvUI’s default visibility logic often assumes “if there’s a player in position 26, the raid must be >25,” which can misclassify layouts when sub-groups are sparse or uneven.  
**EDRF switches based on the actual number of group members**, not on whether players exist at specific **slot indices** in raid groups. This yields consistent behavior for partially filled raids, especially when using **raid-wide sorting**.

**Designed for Raid-Wide Sorting:** Turn on ElvUI’s Raid-Wide Sorting. EDRF treats the raid as a single pool, so even when sub-groups are uneven or non-contiguous, the visible grid remains continuous (e.g., a 10-player raid split across three groups still renders as a clean 2×5).

In addition, EDRF:

- Chooses the right header for the current group size (party, 6–15, 16–25, 26+).
- Enforces **only** the following on the active **raid** header (out of combat, via ElvUI’s DB):
  - `raidWideSorting = true`
  - `groupFilter = "1,2,3,4,5,6,7,8"`
  - `keepGroupsTogether = false`
  - `numGroups = 8` (so you never run out of slots; capacity = 40)

> ⚠️ EDRF **does not** change your ElvUI `groupBy`, `groupingOrder`, or `sortMethod`. Configure those in ElvUI as you like.

---

## Requirements

- World of Warcraft (Retail / Classic\*)
- [ElvUI](https://www.tukui.org/)
- [WeakAuras 2](https://www.curseforge.com/wow/addons/weakauras-2)

\* The aura uses standard ElvUI UnitFrames + Blizzard APIs; it should work anywhere ElvUI unit headers exist.

---

## Install

1. **In game:** `/wa` → **Import** → paste the EDRF export string from this repo (see `weakAura/EDRF_ImportString.txt`).
2. Make sure your ElvUI profile has **party**, **raid1**, **raid2**, and **raid3** headers configured (names like `ElvUF_Party`, `ElvUF_Raid1`, etc.).
3. Arrange each header’s size/position/appearance in ElvUI. EDRF will just pick which one shows.

---

## Usage

The aura runs automatically on:

- login/reload
- group/raid roster changes
- leaving combat (to apply any queued updates)

There is no chat command; no manual action is required during play.

---

## Configuration (inside the aura)

Open the aura → **Actions → On Init**. At the top you’ll find:

```lua
aura_env.EDRF = {
  HEADERS = { "party", "raid1", "raid2", "raid3" },
  BUCKETS = { partyMax = 5, raid1Max = 15, raid2Max = 25 },
  MAP     = { party = "party", raid1 = "raid1", raid2 = "raid2", raid3 = "raid3" },

  ENFORCE = {
    raidWideSorting    = true,
    groupFilter        = "1,2,3,4,5,6,7,8",
    keepGroupsTogether = false,
    numGroups          = 8,   -- enforce for raid headers
    numGroupsParty     = nil, -- set to 1 if you also want party forced
  },

  DELAYS = { debounce = 0.20, enforce = 0.05, initial = 0.00 },
  ENFORCE_ALL_ON_LOGIN = true, -- normalize all managed headers once at login
}
```

- **Buckets:** adjust where each header kicks in.
- **MAP:** if you prefer a different header for a bucket (e.g., `raid3 → "raid40"`), change it here and add that header to `HEADERS`.
- **ENFORCE:** toggle the minimal settings; everything else stays under your control in ElvUI.

---

## Manual WeakAura creation (no import string)

If you prefer to build the aura manually (or you don’t have an import string handy), follow these steps in-game:

1. **Open WeakAuras**: `/wa` → **New** → **Text** (display type).
2. **Name** it: `EDRF` (ElvUI Dynamic Raid Frames).
3. **Display** tab:
   - Display Text: leave blank (or `EDRF active` if you want a tiny label).
4. **Trigger** tab:
   - Type: **Custom**
   - Event Type: **Event**
   - Event(s) (one per line):
     ```
     GROUP_ROSTER_UPDATE
     PLAYER_ENTERING_WORLD
     PLAYER_REGEN_ENABLED
     ```
   - **Custom Trigger** function: paste the contents of `weakAura/EDRF_Trigger.lua` from this repo.
5. **Actions** tab → **Custom Init**:
   - Paste the contents of `weakAura/EDRF_OnInit.lua` from this repo.
6. **Done**. The aura will react automatically as you join/leave groups, zone, or exit combat.

---

## Troubleshooting

- **Header doesn’t switch:** Ensure your ElvUI profile defines the headers listed in `HEADERS` and that they’re enabled.
- **Layout looks different than expected:** That’s ElvUI’s own settings (size, growth direction, groups per row/column, etc.). EDRF only selects the header and enforces the four minimal knobs listed above.

---

## License

MIT — see [`LICENSE`](LICENSE).
