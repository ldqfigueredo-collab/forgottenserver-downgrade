# BUILD_NOTES.md

Running build/feature log for this server. Every custom feature gets an entry here stating exactly what was touched and which deploy mechanism (`/reload <type>`, container restart, or full rebuild — see the table in `CLAUDE.md`) is needed to pick it up. See `CLAUDE.md` for the general project rules this log follows.

## Storage ID reservation scheme

`data/lib/core/storages.lua` is the single source of truth for `PlayerStorageKeys`/`GlobalStorageKeys`. Its own header comment documents these already-reserved ranges:

| Range | Reserved for |
|---|---|
| `10000000`–`20000000` | Outfits and mounts (source-level) |
| `300000`–`301000`+ | Achievements (`achievementsBase`) |
| `20000`–`21000`+ | Achievement progress (`achievementsCounter`) |

And these individual keys are currently in use in `PlayerStorageKeys` (not part of a block — scattered legacy single values):

| Key | Value |
|---|---|
| `annihilatorReward` | 30015 |
| `promotion` | 30018 |
| `delayLargeSeaShell` | 30019 |
| `firstRod` | 30020 |
| `delayWallMirror` | 30021 |
| `madSheepSummon` | 30023 |
| `crateUsable` | 30024 |

`GlobalStorageKeys` is currently empty (`{}`).

A repo-wide scan for raw `setStorageValue(...)` numeric literals in `data/` found nothing in the 35000–110000 range, so that band is clean for a new reserved scheme.

### ✅ Canonical scheme (approved)

`PlayerStorageKeys` block, `40000`–`49999` (10,000 IDs, contiguous, sized per system by expected key count — not a flat 100 each). Systems expected to enumerate per-monster or per-node (talents, tasks, kill counters) got the largest blocks; flag-only systems stay small. There is enormous free space below this too (`31000`–`299999` is entirely open), so nothing here was sized under pressure — widen further later if a block actually fills up.

| Range | Size | System | Why this size |
|---|---|---|---|
| `40000`–`41999` | 2000 | **Talent points** / talent tree | Largest block on purpose — a node-based tree (per-node rank/unlock key, potentially per branch per vocation) is the system most likely to need many keys. 2000 gives headroom for several full trees without redesign. |
| `42000`–`42999` | 1000 | **Tasks** (kill-count task system) | One task can need several keys (assigned, progress counter, completed, reward-claimed) per monster type; sized for a large monster roster. |
| `43000`–`43999` | 1000 | **Kill counters** (general/bestiary-style tracking, separate from tasks) | Same reasoning as tasks — potentially one counter per monster species. |
| `44000`–`44499` | 500 | **Item upgrades** (player-side: unlocked upgrade paths, upgrade materials/points) | Per-item upgrade *state* belongs on the item itself via `ItemAttribute`, not here — this block is only for player-level progression (e.g. "upgrade tier unlocked for weapon class X"), so it doesn't need talent/task-scale room. |
| `44500`–`44699` | 200 | **Promotion flags** (custom-vocation promotion gating, beyond the single legacy `promotion` key at 30018) | Flag-per-vocation-pair, not per-monster — small and bounded by how many vocations we add. |
| `44700`–`45199` | 500 | **Prestige** (rebirth/prestige tier tracking + per-tier unlocks) | Room for several prestige tiers each with a handful of unlock flags. |
| `45200`–`45299` | 100 | Custom vocations misc (non-talent, non-promotion role flags, e.g. Assassin/Nightblade) | Flag-only. |
| `45300`–`45399` | 100 | Custom spells | Flag-only (spell-unlock/cooldown-adjacent state, not the spell system itself). |
| `45400`–`45499` | 100 | Custom NPCs & dialogue state | Flag-only. |
| `45500`–`45599` | 100 | Custom quests | Flag-only. |
| `45600`–`45699` | 100 | Custom items & weapons (quest-item flags, unique-item ownership — distinct from the Item Upgrades block above) | Flag-only. |
| `45700`–`45799` | 100 | Custom achievements/titles | Flag-only. |
| `45800`–`45899` | 100 | Custom economy (faucet/sink tracking) | Flag-only. |
| `45900`–`45999` | 100 | **Player preferences/UI toggles** (carved out of the buffer for the auto-loot toggle; first of a likely-recurring category — settings-style flags, not tied to any single gameplay system) | Flag-only. |
| `46000`–`49999` | 4000 | Unallocated buffer for future systems | Whatever we haven't thought of yet. |

`GlobalStorageKeys` (separate namespace, currently empty):

| Range | Size | System |
|---|---|---|
| `90000`–`90099` | 100 | Custom global state (world-event/server-wide flags) — `90100`+ still free if this ever fills up |

New keys go into `PlayerStorageKeys`/`GlobalStorageKeys` in `data/lib/core/storages.lua` (never as raw numeric literals in feature scripts), named descriptively, within the block for their system.

Once approved, new keys go into `PlayerStorageKeys`/`GlobalStorageKeys` in `data/lib/core/storages.lua` (not raw numeric literals in feature scripts), named descriptively, within the assigned block for their system.

## Feature log

### Assassin / Nightblade vocation

Fast, dagger-focused melee glass-cannon striker — the project's fifth intentional role (see `CLAUDE.md` design rule 2), distinct from Knight.

| File | Change | Mechanism |
|---|---|---|
| `data/XML/vocations.xml` | Added vocation id 9 "Assassin" (base) and id 10 "Nightblade" (promoted, `fromvoc="9"`); low HP/cap gains, cheap sword-skill training, normal `attackspeed="2000"` (speed comes from the weapon, not the vocation) | **Container restart** — no hot-reload path for vocations |
| `data/items/items.xml` | Repurposed item id `2402` (was "silver dagger", unlocked/no special role) into "assassin's dagger" — `weaponType="sword"`, low weight, `attackspeed="1000"` (the 2x-speed mechanism, weapon-only) | `/reload items` |
| `data/weapons/weapons.xml` | Added `<melee id="2402">` locked to `<vocation name="Assassin"/>` and `<vocation name="Nightblade"/>`, `unproperly="1"` (penalty, not hard block, for other vocations) | `/reload weapons` |
| `data/npc/scripts/The Oracle.lua` | Added an `"assassin"` branch to the starter-vocation dialogue (`vocation[cid] = 9`) and updated the profession prompt text | `/reload npcs` |
| Outfit | No new outfit — reuses existing looktype 152 (male) / 156 (female), already named "Assassin" in `data/XML/outfits.xml` (currently `premium="yes" unlocked="no"`; no code changed, cosmetic only, deferred) | n/a |

**Known side effect**: item id `2402` was previously "silver dagger," looted by 3 monsters (`latrivan`, `witch`, `orshabaal`). They now drop "assassin's dagger" instead — no new item id was created because `items.otb` is a binary registry that can't be safely hand-edited in this workflow; every id in `items.xml` must already exist in `items.otb`, or the item silently falls back to item 0 (`Items::getItemType()`). Repurposing an existing, lightly-referenced id was the safe path; inventing a genuinely new id would require a proper OTB editor outside this session.

**PvP/economy flag**: Assassin's weapon-only 2x attack speed roughly doubles DPS with that dagger equipped, offset by the lowest HP-per-level of any vocation (`gainhp="8"`, vs. Knight's `15`) — the intent is high burst, low survivability. Not yet balance-tested against the four base roles in actual combat.

### Repeatable task system

Kill-count tasks turned in at an NPC for EXP/gold/Task Points (new currency, no sink yet — reward shop is future work). One active task per player, level-filtered, repeatable with flat rewards. Modal-window UI for OTCv8, full text-dialogue fallback for any client.

| File | Change | Mechanism |
|---|---|---|
| `data/scripts/lib/tasks.lua` | New — `Tasks` config table (id, creature, killCount, minLevel, rewards). 3 starter tasks: Rats (Lvl 1+, 50 kills, 100 exp/75 gold/1 TP), Trolls (Lvl 8+, 75 kills, 500 exp/200 gold/2 TP), Dragons (Lvl 60+, 20 kills, 2500 exp/800 gold/5 TP) — each EXP value sized to ~5% of that grind's normal hunting yield at this server's live 7x/6x/5x/4x/3x `experienceStages` (config.lua), gold sized below the creature's natural loot-gold yield | `/reload scripts` |
| `data/scripts/creaturescripts/task_kill.lua` | New — `CreatureEvent("TaskKill")`, `onKill(creature, target)`; increments `taskCurrentProgress` on a matching monster kill, capped at `killCount` | `/reload scripts` |
| `data/scripts/creaturescripts/task_modalwindow.lua` | New — `CreatureEvent("TaskModalWindow")`, `onModalWindow(...)`; handles the OTCv8 modal's Accept button (window id `4000`) | `/reload scripts` |
| `data/scripts/talkactions/task_progress.lua` | New — `TalkAction("/task", "!task")`, read-only progress + Task Points report | `/reload scripts` |
| `data/creaturescripts/scripts/login.lua` | Edited — added `player:registerEvent("TaskKill")` and `player:registerEvent("TaskModalWindow")` after the existing `DropLoot` registration | `/reload creaturescripts` — **new logins only**; already-connected players must relog to get the new events registered |
| `data/lib/core/storages.lua` | Edited — added `taskCurrentId` (42000), `taskCurrentProgress` (42001), `taskPoints` (42002) to `PlayerStorageKeys`, from the approved Tasks block (`42000`–`42999`) | **Container restart** — boot-only `dofile` chain, no reload path |
| `data/npc/Task Master.xml` + `data/npc/scripts/Task Master.lua` | New — legacy keyword-handler NPC (topic-free custom `onCreatureSay`, mirrors `The Oracle.lua`'s style). Text dialogue works on any client; if `player:isUsingOtcV8()`, also opens the `ModalWindow` task list | **Container restart** for first spawn; `/reload npcs` for later script-only edits |
| `data/globalevents/globalevents.xml` + `data/globalevents/scripts/task_npc_spawn.lua` | New `type="startup"` globalevent entry, `Game.createNpc("Task Master", Position(32371, 32241, 7))` — spawns the NPC near Thais temple without touching the binary map | **Container restart** — `startup` events only fire on real process boot |

**Storage placement note**: `taskPoints` (42002) was kept in the Tasks block rather than the separate economy block, per explicit approval — revisit when the Task Points reward shop is built.

**Position caveat**: NPC spawn position `(32371, 32241, 7)` (2 tiles from Thais temple at `32369, 32241, 7`) was picked without being able to inspect the binary OTBM for walkability — verify in-game and adjust the `Position(...)` in `task_npc_spawn.lua` if it's on an unwalkable tile.

**PvP/economy flag**: Task Points is a **new faucet with no sink yet** (explicit, approved — the planned sink is a future Task Points reward shop, not yet built). EXP/gold rewards were deliberately kept small (see `tasks.lua` note above) specifically so this system doesn't meaningfully accelerate leveling on top of the server's existing 7x-at-low-level rates.

**Post-deploy fix**: initial build assumed `getStorageValue()` returns `-1` for an unset key (classic TFS convention). This fork's actual binding (`src/luacreature.cpp:1012`, `creature:getStorageValue(key[, defaultValue = 0])`) returns **`nil`** instead unless a default is passed explicitly — caused a Lua error (`attempt to compare number with nil`) the first time a player with no task history said "task" to the NPC. Fixed by passing `-1` explicitly at all 11 call sites across the 4 files. Worth remembering for any future storage-key code in this repo.

### Extreme rates: 1000x EXP, 10x respawn, spawn-with-players-on-screen

**Explicitly requested as a permanent change despite conflicting with design rules 1 (preserve 8.6 feel) and 3 (protect PvP/economy) — flagged and confirmed before building.** Not a balanced-content feature; a deliberate, acknowledged departure from those rules for this server.

| File | Change | Mechanism |
|---|---|---|
| `config.lua` | `experienceStages` set to `nil` (was the 7x/6x/5x/4x/3x table), `rateExp = 1000` — flat 1000x on every kill | `/reload config` |
| `data/world/global-spawn.xml` | Bulk-divided all 32,395 `spawntime` values by 10 (floored, minimum clamped to 10 — see caveat below) | **Container restart** — no reload path for the map/spawn file |
| `src/configmanager.h`, `src/configmanager.cpp` | New `Boolean::IGNORE_SPAWN_BLOCK`, parsed from `ignoreSpawnBlock` in `config.lua` (default `false` in `config.lua.dist`) | n/a (engine plumbing) |
| `src/spawn.cpp:274` | `bool isBlocked = !startup && !getBoolean(ConfigManager::IGNORE_SPAWN_BLOCK) && findPlayer(sb.pos);` — new toggle gates Tibia's classic "don't respawn near a watching player" rule | **Full rebuild**: `docker compose up -d --build server` |
| `config.lua` | `ignoreSpawnBlock = true` | `/reload config` (but only takes effect once the rebuilt binary with the new toggle is running) |

**Engine floor caveat — "10x" isn't uniformly achieved**: `MINSPAWN_INTERVAL = 10 * 1000` ("10 seconds, to match RME") is a hardcoded floor in `Spawns::loadFromXml` — any computed interval below it is silently clamped to 10s (not rejected, contrary to what I initially thought before checking — values are clamped, not dropped). The dominant original value, `spawntime="60"` (26,364 of the 32,395 entries — the vast majority of the map), can only reach the 10s floor: a **6x** speedup, not 10x. Only spawns with an original interval ≥100s got the full 10x. Full before/after distribution is in the commit; nothing was silently different from what's stated here.

**Regression found and fixed along the way**: rebuilding surfaced `[Warning - Monsters::loadMonster] Unknown loot item "silver dagger"` for `data/monster/monsters/zugurosh.xml` — a latent bug from the earlier Assassin dagger rename (item 2402: "silver dagger" → "assassin's dagger"). Zugurosh's loot entry referenced the item by `name="silver dagger"` only (no `id`), so the rename silently broke that loot drop from the very first Assassin restart onward. Fixed by updating the name to `"assassin's dagger"`. Three other bosses (`latrivan`, `witch`, `orshabaal`) also reference item 2402 but include `id="2402"` alongside the name — confirmed the loader trusts `id` when present and never actually validates the `name` string against it, so those were never broken; only name-only references break on a rename. Worth checking for this pattern (`grep -rln 'name="<old-name>"' data/monster/monsters/`, not just the numeric id) on any future item rename.

**PvP/economy impact (as flagged before building)**: the three changes compound — instant respawn with no player-visibility block plus 1000x EXP means a single character parked on any spawn point gets an unlimited, uninterrupted stream of monsters for near-infinite EXP/gold/loot. This removes any meaningful leveling curve and all spawn contention between players. No sink exists or could reasonably absorb this faucet. Confirmed as an intentional, permanent, explicit exception to design rules 1 and 3 — not an oversight.

### Universal base speed 415, uncapped per-level growth

**Explicitly requested — another permanent departure from 8.6 pacing, in the same spirit as the extreme-rates change above.**

| File | Change | Mechanism |
|---|---|---|
| `data/XML/vocations.xml` | `basespeed` raised from `220` (all 10 base/promoted vocations) and `230` (Assassin/Nightblade) to a uniform `415` across all 11 entries | **Container restart** — no hot-reload path for vocations |

**Finding — no engine change needed**: per-level speed growth already exists natively in this fork, undocumented until now: `src/player.h:1147`, `baseSpeed = vocation->getBaseSpeed() + (2 * (level - 1))`. Every vocation already gains **+2 speed per level** above 1; this is not vanilla Tibia behavior but is already built into this codebase, uncapped except by the engine's own `PLAYER_MAX_SPEED = 1500` ceiling (`src/player.h:81`) and `PLAYER_MIN_SPEED = 10` floor. So this change was purely a `vocations.xml` data edit — level 1 speed is now 415, level 50 is `415 + 98 = 513`, level 100 is `613`, climbing indefinitely toward 1500.

**Compounds with the extreme-rates change**: since EXP is already 1000x (see above), characters reach whatever level they stop at almost immediately — meaning the speed-per-level growth also kicks in almost immediately, not gradually. Same category of intentional departure as the rates change, not a new consideration, but worth having in one place since they interact.

### Assassin/Nightblade spell kit

Four spells + vocation access to two existing healing spells and three existing potions. Reinforces Assassin as a fast, glass-cannon striker (design rule 2) — no storage keys needed (all mechanics use native `Condition`s and the engine's built-in per-spell cooldown, nothing persisted).

| File | Change | Mechanism |
|---|---|---|
| `data/spells/spells.xml` | Added `<instant>` entries: **Whirlwind** (`exori vortex`, lvl 20, 200 mana, 30s cooldown, 10s duration), **Rupture** (`exori rup`, lvl 25, 40 mana, range 5, 6s cooldown), **Earthen Strike** (`exori gran tera`, lvl 15, 30 mana, range 1, 4s cooldown). Added `<vocation name="Assassin"/>` + `<vocation name="Nightblade"/>` to the existing **Light Healing** (`exura`) and **Intense Healing** (`exura gran`) entries — Paladin's tier, not Knight's higher tiers | `/reload spells` |
| `data/spells/scripts/attack/whirlwind.lua` | New — adds a 10s `Condition(CONDITION_ATTRIBUTES)` with `CONDITION_PARAM_SUBID = 1`, no direct damage (`COMBAT_PARAM_AGGRESSIVE = false`), modeled on `support/blood_rage.lua` | `/reload spells` |
| `data/spells/scripts/attack/rupture.lua` | New — `COMBAT_EARTHDAMAGE`, `LEVELMAGICVALUE` formula; doubles damage only when `target:isMonster()` and HP ≤ 30% — the execute bonus never applies to players (explicit PvP call) | `/reload spells` |
| `data/spells/scripts/attack/earthen_strike.lua` | New — `COMBAT_EARTHDAMAGE`, `SKILLVALUE` formula (ties to sword skill), single target, no armor block (matches `terra_strike.lua` precedent for elemental spells) | `/reload spells` |
| `data/weapons/weapons.xml` | Added `script="whirlwind_cleave.lua"` to the existing `<melee id="2402">` (Assassin's Dagger) entry | `/reload weapons` |
| `data/weapons/scripts/whirlwind_cleave.lua` | New — `onUseWeapon(player, variant)` checks for the Whirlwind condition (subid 1); if active, executes a `COMBAT_FORMULA_SKILL` physical `Combat` with a 3x3-centered-on-player area instead of the normal single-target hit. Non-buffed attacks use an identical `COMBAT_FORMULA_SKILL` single-target `Combat`, reproducing default weapon damage so baseline (non-buffed) Assassin damage is unchanged | `/reload weapons` |
| `data/actions/scripts/other/potions.lua` | Added vocations `9, 10` to **Strong Health Potion** (7588), **Strong Mana Potion** (7589), **Great Spirit Potion** (8472) — Paladin's potion tier. Deliberately *not* added to Great Health Potion (7591) or Ultimate Health Potion (8473), which stay Knight-only — keeps Assassin's sustain "moderate," not tanky | `/reload actions` |

**Post-deploy fix**: first deploy errored on `whirlwind_cleave.lua` — `createCombatArea(AREA_SQUARE1X1)` failed with "Invalid area table." `AREA_SQUARE1X1` isn't a C++ constant; it's a Lua table defined in `data/spells/lib/spells.lua`, which is only loaded into the **spells** script interface — each legacy event system (`actions`, `spells`, `weapons`, `creaturescripts`, `talkactions`, `movements`) has its own separate `LuaScriptInterface` with its own `lib/` folder, they don't share a global namespace the way `data/lib/core/storages.lua` does (that one loads via the universal `data/global.lua` boot chain into every interface). `data/scripts/weapons/#example.lua` already inlines the same matrix for the same reason — missed that precedent on the first pass. Fixed by inlining the literal `{{1,1,1},{1,3,1},{1,1,1}}` matrix directly in the weapon script. **Worth remembering: constants/tables defined in a `data/<system>/lib/` file are scoped to that system only, not global — only `data/lib/**` (boot-loaded) and `data/scripts/lib/` (revscript-loaded) are broadly shared.**

**PvP flags (as designed)**: Whirlwind cleaving multiple adjacent players is intentional and matches existing precedent (Knight's Berserk/`exori` already does this) — not a new risk. Rupture's execute bonus is PvE-only by design, avoiding an oppressive kill-confirm effect in PvP. Neither spell nor the potion/healing grants change PvP damage output outside of normal combat — Assassin remains squishy (see vocation HP gains) even with sustain access.

### Auto-loot

**Deliberate QoL bend of 8.6-purity — explicit, conscious design choice, not a drift.** When a monster dies, its generated loot auto-moves from the corpse into the killer's equipped backpack, toggleable per player, default on. Economy-neutral: same loot table, same drop rates, same quantities — only delivery changes.

| File | Change | Mechanism |
|---|---|---|
| `data/scripts/eventcallbacks/monster/default_onDropLoot.lua` | Edited (this is the established extension point for loot generation, already handling stamina suppression/corpse ownership/party-loot messages before this change) — after the existing loot-creation loop, if the corpse owner has auto-loot enabled, attempts `item:moveTo(backpack, 0)` for each created item into their equipped backpack (`CONST_SLOT_BACKPACK`) | `/reload scripts` |
| `data/scripts/talkactions/autoloot.lua` | New — `!autoloot` / `!autoloot on` / `!autoloot off`, storage-backed, default on | `/reload scripts` |
| `data/lib/core/storages.lua` | Added `autoLootEnabled = 45900` — first key in the newly-carved **Player preferences/UI toggles** block (`45900`–`45999`, see storage table above) | **Container restart** — boot-only `dofile` chain, no reload path |

**Ownership — by construction, not by an added check**: `onDropLoot` only ever resolves to the corpse's already-established owner (`corpse:getCorpseOwner()`, set in `src/monster.cpp:1833-1849` to the individual player who dealt the most damage — same id `Player::canOpenCorpse` already uses for manual looting). Auto-loot only acts on this one player; it cannot hand loot to a non-owner, and doesn't touch any other player's ability to manually open the corpse. v1 scope: only the resolved owner gets auto-loot, not their whole party — other party members still loot manually as before (unchanged from pre-auto-loot behavior). Party-wide auto-loot is a possible v2, not built.

**Overflow safety — verified, not assumed**: `Item:moveTo()`'s default flags include `FLAG_NOLIMIT` (`src/cylinder.h:17`, "bypass limits like capacity/container limits") — calling it with defaults would force items into the backpack regardless of free space, silently defeating overflow safety. Fixed by passing `flags = 0` explicitly on every `moveTo` call, routing through the same capacity/slot-count validation a manual drag-and-drop uses. A full backpack makes the move fail and the item stays exactly where `createLootItem` put it — inside the corpse, fully visible and lootable by hand. Nothing is ever destroyed or duplicated: items are only ever created once by the untouched loot-generation loop; auto-loot strictly relocates them.

**UX fix applied during build**: the loot-broadcast message (`"Loot of X: ..."`) is now built from `corpse:getContentDescription()` *before* the auto-loot move happens, not after — otherwise a fully-auto-looted corpse would show an empty/misleading loot message even though items did drop, just not into the corpse.

**Gold**: no special-casing — gold coins are ordinary stackable loot items and flow through the same move-to-backpack path as everything else, stacking onto existing coin stacks normally. Confirmed goes to the bag, not `bankBalance`.

**Post-deploy fix**: the first build was completely broken — every kill threw `attempt to index a boolean value` at the `moveTo` line, meaning auto-loot silently did nothing (and worse, the loot-broadcast message likely never sent either, since the error aborted the function). Root cause: `Container:createLootItem()` is **not** a C++ binding — it's a pure-Lua helper in `data/lib/core/container.lua`, and it returns a **boolean success flag**, not the created `Item`. I misread the original script's `if not item then` check (which tests that boolean) as "the created item or nil on failure," and built a `createdItems` table full of `true`/`false` values, then tried to call `:moveTo()` on them. Fixed by dropping that assumption entirely: after the loot-generation loop runs (unchanged), the script now reads the corpse's actual contents via `corpse:getItems(false)` (non-recursive — top-level items/bags only, same scope as a manual drag) and moves those. This doesn't depend on any function's return value being an item reference, so it can't have the same class of bug. **Worth remembering: a Lua-callable method existing (`obj:method()` working syntactically) doesn't mean it's a C++ binding — some, like this one, are pure-Lua helpers layered into the metatable from `data/lib/core/*.lua`, and their return conventions have to be checked directly, not assumed from naming.**

**v1 scope note (per design)**: no item filter/whitelist — auto-loot moves everything the loot table generates. A future version could add a per-item or per-monster allowlist; not built here. (Superseded by the blacklist below, which adds an opt-out filter — the "no filter" note above describes the state at initial ship.)

### Auto-loot blacklist (Stage 1 — server logic + text fallback; client right-click UI is Stage 2/3, not built yet)

Per-player list of item ids that auto-loot skips (left in the corpse, exactly like an overflow item). Investigated as a combined server+OTClientV8-client feature; this is deliberately **server-only** for now — see the investigation notes below for why the full right-click UI is a separate, larger undertaking.

| File | Change | Mechanism |
|---|---|---|
| `data/lib/core/storages.lua` | Added `autoLootBlacklistCount = 45901` and `autoLootBlacklistBase = 45902` — reserves `45901`–`45951` (51 keys) in the **Player preferences/UI toggles** block. Compact-array storage: count + up to 50 item ids at `base + i`; removal shifts later entries down so lookups only ever scan `0..count-1` | **Container restart** — boot-only `dofile` chain, no reload path |
| `data/scripts/lib/autoloot_blacklist.lua` | New — shared `AutoLootBlacklist` module (`getList`, `contains`, `add`, `remove`, `clear`), used by both the talkaction and the loot script so the membership logic exists once | `/reload scripts` |
| `data/scripts/talkactions/blacklist.lua` | New — `!blacklist` (list), `!blacklist add/remove <name or id>` (resolves via `ItemType(id or name)`, `src/luaitemtype.cpp:16`), `!blacklist clear` | `/reload scripts` |
| `data/scripts/eventcallbacks/monster/default_onDropLoot.lua` | Edited again (third time this file's been the extension point) — the auto-loot move loop now skips any item where `AutoLootBlacklist.contains(player, item:getId())` is true; skipped items simply aren't moved, staying in the corpse | `/reload scripts` |

**v1 scope**: only top-level corpse items are checked (matches the existing non-recursive `getItems(false)` auto-loot scope) — an item nested inside a loot bag isn't individually filterable, the bag moves or doesn't as a whole. Cap of 50 blacklisted items per player.

**Investigation findings (client right-click UI, not built — Stage 2/3 for later)**: checked both `~/otclientv8` (the actual client source) and this server fork before deciding to build server-only first.
- **Client hooks**: confirmed clean and available. `modules/game_interface/gameinterface.lua` has a formal `addMenuHook(category, name, callback, condition, shortcut)` API specifically for adding right-click menu entries from a separate module — no core client file patching needed. `mods/game_healthbars/` already demonstrates the pattern (a third-party `.otmod` outside the core `modules/` tree).
- **Protocol**: confirmed both directions. Client: `ProtocolGame.registerExtendedOpcode`/`sendExtendedOpcode`, plus a ready-made `sendExtendedJSONOpcode`/`registerExtendedJSONOpcode` pair that auto-chunks JSON payloads. Server: `CREATURE_EVENT_EXTENDED_OPCODE` (`onExtendedOpcode(player, opcode, buffer)`) is auto-registered for every OTClient-family connection already (`src/protocolgame.cpp:222`) — no `login.lua` edit needed, unlike our other custom events. `data/lib/json.lua` (a standard `rxi/json.lua`) already exists server-side, unused until now.
- **No hard walls found.** The reason this is staged rather than built all at once: every previous feature took effect for *every* connecting player on server reload — a client mod only affects players running this specific customized OTClientV8 build with the mod installed. That's a distribution question, not a technical one, but it's a real difference from everything else in this log and worth deciding deliberately before investing in Stage 3.
- **Staged build order**: (1) server blacklist + talkaction fallback; (2) server extended-opcode handler (JSON send/receive of the blacklist) — **see next entry**; (3) client `mods/game_lootblacklist/` — right-click hooks + "Manage Loot List" window, wired to (2). Not started past (2).

### Auto-loot blacklist, Stage 2: server extended-opcode protocol handler

Server-only continuation of the entry above — no client mod yet (that's Stage 3). Lets a future client send get/add/remove/clear requests over an extended opcode and receive the current blacklist back as JSON.

| File | Change | Mechanism |
|---|---|---|
| `data/scripts/creaturescripts/loot_blacklist_opcode.lua` | New — `CreatureEvent("LootBlacklistOpcode")`, type `extendedopcode`, on opcode `2`. Decodes the JSON request (`pcall`-wrapped against malformed input), calls the existing `AutoLootBlacklist.add/remove/clear/getList` (Stage 1), replies via `player:sendExtendedOpcode(2, json.encode({items = list}))` — always the current authoritative list, sent after every action | `/reload scripts` |
| `data/creaturescripts/scripts/login.lua` | Edited — added `player:registerEvent("LootBlacklistOpcode")` (4th event registered here now: `PlayerDeath`, `DropLoot`, `TaskKill`, `TaskModalWindow`, `LootBlacklistOpcode`) | `/reload creaturescripts` — new logins only, same caveat as every prior addition to this file |

**Correction to the Stage 1 investigation note above**: I originally wrote "sending from server has no convenience wrapper" for extended opcodes — that was wrong. `Player.sendExtendedOpcode(self, opcode, buffer)` already exists in `data/lib/core/player.lua`, and there's also already a legacy `"ExtendedOpcode"` `CreatureEvent` (`data/creaturescripts/scripts/extendedopcode.lua`, handling a language-detection opcode `1`) already registered and auto-attached to every OTClient connection. Found this by actually reading the files instead of assuming from the earlier grep-only pass.

**Why a separate CreatureEvent instead of editing the existing `extendedopcode.lua`**: confirmed `Game::parsePlayerExtendedOpcode` (`src/game.cpp:5084`) loops over *all* registered `CREATURE_EVENT_EXTENDED_OPCODE` handlers for a player, not just one — so a second, independently-named handler (opcode `2`, ignoring anything else) coexists cleanly with the existing language handler (opcode `1`) with zero risk of collision. This also sidesteps the cross-system-lib isolation issue from the spell kit (`AREA_SQUARE1X1`) — `extendedopcode.lua` is legacy-registered with its own script interface and wouldn't have access to `AutoLootBlacklist` (revscript-only); our own revscript `CreatureEvent` does.

**Testing note**: this is fully built and deployed but genuinely untested end-to-end — there's no client mod yet to send it real messages, and I didn't find a confirmed way to trigger `sendExtendedOpcode` manually from OTClientV8's built-in Lua terminal without further digging into its C++ bindings (didn't want to guess a command). Real verification happens naturally once Stage 3 exists, or via a throwaway GM-only talkaction that calls the same handler logic directly if earlier confirmation is wanted.

### Auto-loot blacklist, Stage 3: client mod (right-click UI)

**Lives outside this repo** — `~/otclientv8/mods/game_lootblacklist/`, not `data/`. This is the actual OTClientV8 client install, not server content, so none of the usual `/reload` mechanics apply; the client needs to be **relaunched** to pick up a new/changed mod (didn't find a confirmed hot-reload path from the terminal without further digging, same caveat as Stage 2's testing note — didn't want to guess).

| File | Purpose |
|---|---|
| `mods/game_lootblacklist/lootblacklist.otmod` | Module manifest, `autoload: true` (always active, not an opt-in client setting), `sandboxed: true` (standard for a `mods/` addon, matches the existing `game_healthbars` example already in this client install) |
| `mods/game_lootblacklist/lootblacklistwindow.otui` | The "Manage Loot List" window layout — a `MainWindow` with a scrollable `TextList` (modeled directly on `modules/game_questlog/questlogwindow.otui`'s `QuestLog`/`QuestLabel` pattern) and a Close button |
| `mods/game_lootblacklist/lootblacklist.lua` | Registers two right-click menu hooks via `modules.game_interface.addMenuHook` (confirmed cross-module call convention — see below) — "Add to Blacklist" on any non-container item, "Manage Loot List" on any container. Registers opcode `2` via `ProtocolGame.registerExtendedOpcode`. Sends/receives JSON matching the Stage 2 protocol exactly |

**UI interpretation choice, flagging for your review**: the window shows only the *current* blacklist (it has no way to know every item you've ever seen to offer as a full togglable checklist) — clicking an entry removes it. This satisfies "toggle items" as toggle-off-to-remove, not a master checklist of all possible items with checkboxes. Adding happens exclusively via the item's own right-click, per your original spec. Say so if you pictured something closer to a real checkbox widget per row (a `CheckBox`-based list style) instead of click-to-remove labels — swapping that is a small change, I just went with the pattern I found already proven in this client (`QuestLabel`) rather than hand-rolling an unverified one.

**Two implementation details worth knowing, found while building**:
- Cross-module calls in this client need the `modules.<name>.` prefix (`modules.game_interface.addMenuHook`) — confirmed by finding the one other place in this client install that calls it (`modules/game_bot/.../analyzer.lua:1084`, `local interface = modules.game_interface`). Bare global calls only work for **unsandboxed** foundational libraries (`gamelib`, which defines `g_game`, `ProtocolGame`, etc. — confirmed via `gamelib.otmod` having no `sandboxed: true` line) — a sandboxed mod's own Lua-defined functions (like `game_interface`'s `addMenuHook`) are not automatically global to other sandboxes.
- `json.encode`/`json.decode` are already global client-side (confirmed via `modules/game_questlog/questlog.lua` using them directly with no `require`/`dofile`) — no extra wiring needed, unlike the server side where I had to `dofile('data/lib/json.lua')` explicitly.

**Post-deploy fix, found via live debugging (not guessed)**: end-to-end testing showed the client→server half working perfectly (server correctly received `add`/`get` requests and updated the blacklist — confirmed by inspecting `player_storage` directly), but the server→client response never arrived, so the UI never updated and looked completely broken ("not adding," empty window). Added temporary `print()` diagnostics to `loot_blacklist_opcode.lua`, redeployed, had the user retry, and read the logs — traced it to `Player.sendExtendedOpcode()` in `data/lib/core/player.lua` (a **pre-existing shared helper, not something built for this feature**) silently no-opping because its guard, `Player.isUsingOtClient()`, checks `self:getClient().os >= CLIENTOS_OTCLIENT_LINUX`. This specific OTCv8 build/config reports `client.os = 2` (plain `CLIENTOS_WINDOWS`) in the login handshake rather than one of the `CLIENTOS_OTCLIENT_*` codes (10-12) — so the check was always false for this client, even though it's genuinely OTCv8 and was actively sending/receiving extended opcodes the whole time (that direction works because `player:registerEvent("LootBlacklistOpcode")` in `login.lua` is unconditional, not gated on this same check). Fixed `data/lib/core/player.lua:78` to also accept `self:isUsingOtcV8()` — this fork's own custom OTCv8 handshake-string detection (`src/protocolgame.cpp`, first used for `ModalWindow` in the spell kit) — as an alternative signal, since that one *does* correctly identify this client regardless of what `os` code it reports. This is a genuine latent bug in a shared core file that predates this feature; fixing it benefits any future use of `sendExtendedOpcode`/`isUsingOtClient`, not just the blacklist.

**Second, unrelated finding from the same debug pass**: two blacklisted items showed empty names in the response (`{"id":169,"name":""}`). Not a bug — items `169` and `3585` exist in the binary `items.otb` (client sprite registry) with no matching `items.xml` entry, so they have no name defined server-side at all (same gap category as the Assassin's Dagger rename fallout earlier in this log). Added a fallback in `AutoLootBlacklist.getList()` (`data/scripts/lib/autoloot_blacklist.lua`) so a nameless item displays as `"Unknown Item (#<id>)"` instead of a blank row — real content-completeness gap in the base item pack, not something to "fix" beyond graceful display.

**Debug logging was temporary** — added to `loot_blacklist_opcode.lua` during the live investigation, removed once the root cause was confirmed and fixed; the file matches its original Stage 2 form except for the underlying `sendExtendedOpcode` behavior now actually working.

**Third post-deploy fix — client id vs. server id, a real protocol bug**: after the two fixes above, the round-trip worked, but blacklisting a gold coin resulted in a *different* item showing up. Root cause: Tibia's client↔server protocol only ever speaks in **client (sprite) ids** — the client has no concept of server ids at all, so `useThing:getId()` on the OTC client returns a client id. `loot_blacklist_opcode.lua` was treating `data.id` as a server id directly (`ItemType(id)` does a raw server-id table lookup), which silently resolved to whatever unrelated item happens to share that number in server-id space. Fixed by converting at the protocol boundary in both directions: incoming `add`/`remove` now resolve `data.id` via `Game.getItemTypeByClientId()` (confirmed via `src/luagame.cpp:154`, exists exactly for this purpose) before calling `AutoLootBlacklist`; outgoing list responses convert each stored server id back to a client id via `ItemType(id):getClientId()`. `AutoLootBlacklist` itself (Stage 1) stays server-id-keyed internally, unchanged — it's correct as-is for the `!blacklist` talkaction (which naturally deals in server ids/names via `ItemType(name_or_id)`) and for matching against real loot items (`item:getId()` on a server-side Item is a server id). The conversion only needed to happen at this one client-facing boundary.

**Stale test data**: entries added before this fix (via the client) are wrong — they're server-id lookups of what were actually client ids, so they reference unrelated items. Clear via `!blacklist clear` before retesting.

### Auto-loot blacklist, Stage 4: multi-select removal (client UI)

Follow-up to Stage 3. Replaces "click a row to remove it immediately" with "click one or more rows to select them, then click a Remove from Blacklist button" — same list, no new gameplay behavior, just a batched removal flow.

| File | Change | Mechanism |
|---|---|---|
| `data/scripts/creaturescripts/loot_blacklist_opcode.lua` | Added a `remove_many` action (`{"action":"remove_many","ids":[<client itemid>, ...]}`) alongside the existing single `remove`. Converts each id via `Game.getItemTypeByClientId()` (same boundary conversion as the existing actions), loops `AutoLootBlacklist.remove()`, then replies once with the current authoritative list via the existing `sendBlacklist()` | `/reload scripts` |
| `~/otclient/mods/game_lootblacklist/lootblacklistwindow.otui` and `~/otclientv8/mods/game_lootblacklist/lootblacklistwindow.otui` | Added a `$checked:` style state (distinct color) to the row widget (`LootBlacklistRow` in `~/otclient`, `LootBlacklistLabel` in `~/otclientv8`) for a persistent selected-highlight, separate from `$hover`. Added a "Remove from Blacklist" button next to the existing Close button; re-anchored the `TextList` to sit above it. Updated the hint text | **Client relaunch** — lives outside this repo, no hot-reload path found |
| `~/otclient/mods/game_lootblacklist/lootblacklist.lua` and `~/otclientv8/mods/game_lootblacklist/lootblacklist.lua` | Row `onClick` now toggles membership in a new `selected` table (by item id) and calls `widget:setChecked(...)` instead of sending an immediate `remove`. New `onRemoveSelected()` collects `selected` into an `ids` array, sends one `remove_many` request, clears `selected`. `refreshList()` prunes any selected id no longer present in the server's list (rows are rebuilt from scratch every refresh, so this also re-applies the checked state to surviving selections) | **Client relaunch** |

**Confirmed**: `setChecked`/`$checked` is a generic `UIWidget` pseudo-state in both client forks (`uiwidget.cpp`/`uiwidget.h` in each, `Fw::CheckedState`) — not something built for this feature, just reused. Verified present in both `~/otclient` and `~/otclientv8` source before relying on it in both mod copies.

**Scope note**: `onRemoveSelected()` no-ops silently if nothing is selected (empty `ids` array is never sent) — no separate "nothing selected" message, matches this mod's existing minimal-feedback style (row click had no confirmation either).

**Not built**: no "Select All" / "Clear Selection" convenience buttons, no Ctrl/Shift range-select — single-click toggle only, per the approved plan. Small addition later if wanted.

**Post-deploy fix attempt #1 — click hit-testing theory, `~/otclient` only, superseded (see #2 below)**: user reported clicking a row didn't select it at all. Theorized root cause: `LootBlacklistRow`'s `icon`/`name` children cover nearly the whole row and weren't marked `phantom`, so otclient's hit test (`UIWidget::recursiveGetChildByPos`, `src/framework/ui/uiwidget.cpp:1541`) would resolve clicks to a child instead of the row, and `row.onClick` (the only place the handler was wired) would never fire. Added `phantom: true` to `icon`/`name` on this theory. **This did not fix it** — a follow-up debug-logging pass (temporary `print()` in `row.onClick`) showed the handler still never fired even after the phantom fix, meaning the actual cause was never conclusively isolated. Rather than keep debugging the custom `Panel`'s click handling blind, replaced the whole approach — see fix #2.

**Post-deploy fix #2 — switched row selection to a native `CheckBox` widget**: instead of a hand-rolled `Panel` row with a manually-wired `onClick`, each row now has a real `CheckBox` (`modules/corelib/ui/uicheckbox.lua` in both forks — confirmed present and identical in both before relying on it: `UICheckBox:onClick()` internally does `self:setChecked(not self:isChecked())`, then `UIWidget::setChecked()` fires `onCheckChange` — `src/framework/ui/uiwidget.cpp:1302-1306`). This is the same widget class used throughout both clients for per-row selection elsewhere (VIP list, options, character-list pinning), so it's known-reliable rather than something built for this feature. `~/otclient/mods/game_lootblacklist/lootblacklistwindow.otui`: `LootBlacklistRow` gained a `checkbox` child (`icon`/`name` kept `phantom: true`, now cosmetic only, harmless either way). `~/otclientv8/mods/game_lootblacklist/lootblacklistwindow.otui`: same, and the row itself was renamed from a bare `LootBlacklistLabel` to a `LootBlacklistRow < Panel` containing a `checkbox` + `name` label, matching the `~/otclient` structure for parity. Both `lootblacklist.lua` files: `refreshList()` sets `row.checkbox:setChecked(...)` and wires `row.checkbox.onCheckChange`, replacing the old row-level `onClick`/`setChecked` calls entirely. This fixed selection end-to-end, confirmed live. **Client relaunch** required for both fixes.

**Post-deploy fix #3 — server never actually reloaded**: after fix #2, selection worked but "Remove from Blacklist" appeared to do nothing (checkbox cleared, item stayed in the list). Cause: the `remove_many` server-side handler (added earlier this Stage, see the `loot_blacklist_opcode.lua` row in the table above) needs `/reload scripts` to take effect, same as any revscript change — but that requires an in-game GM command, and the test character (`Shade`, see below) is in the `player` group, not GM, so there was no way to trigger it in-game. The server had been running for 13 hours with the old code the whole time, silently falling through to the "unrecognized action" path (which still replies with the unchanged list — `sendBlacklist()` runs unconditionally after the action dispatch), exactly matching the observed symptom. Fixed by `docker compose restart server` instead (equivalent effect to `/reload scripts` for a data/scripts change, just coarser — picks up all script changes on boot, no image rebuild, no data loss, only needed because no GM route was available). Confirmed clean boot (`>> Forgotten Server Online!`, no errors from this feature's files) and working removal afterward.

### Auto-loot blacklist, Stage 5: window resize + name search filter (client UI)

Follow-up to Stage 4, both client copies.

| File | Change | Mechanism |
|---|---|---|
| `~/otclient/mods/game_lootblacklist/lootblacklistwindow.otui` and `~/otclientv8/mods/game_lootblacklist/lootblacklistwindow.otui` | `LootBlacklistWindow` size `260x340` → `390x510` (50% larger, per request). Added a `searchEdit` `TextEdit` between the hint label and the item list; `~/otclient` uses its native `placeholder: Search item...` (confirmed supported: `src/framework/ui/uitextedit.cpp:1328`); `~/otclientv8` (older OTCv8 3.2 fork) has **no `placeholder` support at all** (confirmed absent from its `uitextedit.cpp`/`.h`), so it gets an explicit `searchLabel` ("Search:") next to a plain `TextEdit` instead. `itemList`'s top anchor moved from `hint.bottom` to `searchEdit.bottom` | **Client relaunch** |
| `~/otclient/mods/game_lootblacklist/lootblacklist.lua` and `~/otclientv8/mods/game_lootblacklist/lootblacklist.lua` | New `searchText` state, reset on `offline()`. New `onSearchTextChange(text)` (wired via `@onTextChange` in the otui) updates `searchText` and calls `refreshList()`. `refreshList()` now filters which rows it builds via a case-insensitive plain-text substring match (`entry.name:lower():find(query, 1, true)`, `true` = no Lua pattern interpretation) — but the existing stale-selection pruning step still runs against the full `blacklist`, not the filtered subset, so checking an item, then searching for something else, doesn't silently lose that selection | **Client relaunch** |

**Scope note**: filtering is display-only (client-side) — the server's list is unfiltered and unaffected; search text isn't persisted across window closes (`offline()` resets it, matching how `selected` already worked).

### Promotion Master NPC (item-gated promotion, test config: 3 cheese)

Lets a player promote (Sorcerer→Master Sorcerer, Druid→Elder Druid, Paladin→Royal Paladin, Knight→Elite Knight, Assassin→Nightblade) via item cost instead of vanilla's gold+premium gate. No new vocations.xml entries needed — all five base/promoted pairs were already wired via `fromvoc` from earlier work (Assassin/Nightblade vocation, this log). Uses the engine's native `vocation:getPromotion()`/`player:setVocation()` — no new storage keys.

| File | Change | Mechanism |
|---|---|---|
| `data/scripts/lib/promotions.lua` | New — `PromotionMinLevel = 50`, `PromotionCost = {item = 2696, count = 3}` (cheese, ~39% drop from rats). Global revscript-lib table, same sharing pattern as `Tasks` (visible from legacy NPC scripts too) | `/reload scripts` |
| `data/npc/Promotion Master.xml` + `data/npc/scripts/Promotion Master.lua` | New — legacy keyword-handler NPC (mirrors `Task Master.lua`'s style). `"promotion"` keyword checks: no vocation chosen yet → send to Oracle; `vocation:getPromotion()` nil → already at peak; below `PromotionMinLevel` → told to come back; insufficient cheese → told the cost. Otherwise quotes cost and asks `{yes}/{no}`; on yes, re-validates state (in case anything changed mid-conversation), removes 3 cheese, calls `player:setVocation(promotedId)` | Container restart for first spawn; `/reload npcs` for later script-only edits |
| `data/globalevents/globalevents.xml` + `data/globalevents/scripts/promotion_npc_spawn.lua` | New `type="startup"` globalevent, `Game.createNpc("Promotion Master", Position(32367, 32241, 7))` — 2 tiles from Thais temple, opposite side from Task Master's spawn point (`32371, 32241, 7`) so they don't overlap | Container restart — `startup` events only fire on real process boot |
| `data/creaturescripts/scripts/login.lua` | Edited — removed the `elseif not promotion then player:setVocation(vocation:getDemotion()) end` branch from the pre-existing login promotion check. That branch silently reverted any non-premium player sitting on a fully-promoted vocation back to base on every login (`config.lua` has `freePremium = false`, so most accounts here are non-premium) — left unfixed, cheese-promotion would appear to "randomly" undo itself on relog. Explicit decision: promotion is now premium-independent server-wide, not just for this NPC. The premium re-apply branch (`isPremium()` + storage flag 1 → re-promote) is left intact but is now effectively dead code — nothing in this codebase sets that storage flag anymore | `/reload creaturescripts` — existing connections need relog |

**Position caveat**: `(32367, 32241, 7)` was picked without being able to inspect the binary OTBM for walkability, same caveat as Task Master's spawn — verify in-game and adjust if needed.

**Known quirk in the native engine check**: `Player::isPromoted()` (`src/player.cpp:3796`) returns `true` whenever the *current* vocation has no further promotion available — including vocation id 0 (no vocation chosen yet). Not used directly by this feature (the NPC checks `vocation:getId() == 0` and `vocation:getPromotion()` instead, which handle this correctly), but worth remembering if `isPromoted()` is ever used elsewhere for a "is this a real promoted character" check.

**PvP/economy flag (explicit, per design rule 3)**: promotion's stat bonuses (faster HP/mana regen ticks, cheaper soul regen — see `vocations.xml`, added when the base/promoted pairs were first created) already existed; nothing new was invented here. At level 50 + 3 cheese (a common, low-value drop), the cost is not a meaningful gate — this is explicitly a placeholder test configuration per the user's request, not a balanced design. Revisit `PromotionCost` in `data/scripts/lib/promotions.lua` with real per-vocation costs before this is considered live content.

### Percent-of-max HP/mana regen per vocation

Adds an extra regen component on top of each vocation's existing flat per-tick amount (unchanged), scaled as a percent of max HP/mana so sustain keeps pace with a leveled-up character instead of staying a fixed small number. Uses a native engine feature (`ConditionRegeneration`'s `healthGainPercent`/`manaGainPercent`, `src/condition.cpp:1004-1051`) that already existed for item abilities but was never wired to vocations — no C++/rebuild needed, pure `data/lib/**` change.

| File | Change | Mechanism |
|---|---|---|
| `data/lib/core/player.lua` | Added `RegenPercent` table (vocation id → `{health, mana}`, encoded as `100 + extra%` matching the engine's own convention), local aliases for `CONDITION_PARAM_HEALTHGAINPERCENT`/`MANAGAINPERCENT` (60/61 — not registered as named Lua enums in `src/luascript.cpp`, but `Condition:setParameter` accepts the raw numeric key fine, confirmed via `src/luacondition.cpp:137`). New `Player:updateRegenPercent(self)` sets both params on the existing food-gated regen condition (no-ops if the player isn't fed — same gate as the existing flat regen). Wrapped the native `Player.setVocation` (Lua monkey-patch on the shared metatable) to call `updateRegenPercent()` after every successful vocation change, since the native `updateRegeneration()` (`src/player.cpp:4423`) only refreshes the flat amount, not percent — without this wrap, percent would silently stay stuck at the pre-promotion vocation's value. Also called from `Player.feed()` so newly-fed players get the correct percent immediately | Container restart — boot-only `dofile` chain (`data/lib/core/core.lua` → `player.lua`) |
| `data/creaturescripts/scripts/login.lua` | Added `player:updateRegenPercent()` after the promotion block — covers the edge case of a persisted regen condition (still-fed player logging back in) predating a vocation change made while offline | `/reload creaturescripts` — existing connections need relog |

**Values** (extra % beyond the unchanged flat amount): None +0/+0, Sorcerer +1%HP/+4%Mana, Druid +1%/+4%, Paladin +2%/+2%, Knight +3%/+1%, Master Sorcerer +2%/+6%, Elder Druid +2%/+6%, Royal Paladin +3%/+3%, Elite Knight +5%/+2%, Assassin +1%/+1%, Nightblade +2%/+2%. Percentages reinforce each vocation's existing flat-regen identity (design rule 2) rather than flattening it — Knight/Elite Knight strongest on HP%, Sorcerer/Druid and their promotions strongest on Mana%, Paladin/Royal Paladin balanced, Assassin/Nightblade lowest on both (deliberately kept low despite the original "5+3%" example prompt — see PvP flag below).

**PvP/economy flag (explicit, per design rule 3)**: unlike the flat amount, percent-of-max regen scales automatically with level, and this server already has 1000x EXP (see "Extreme rates" entry above) pushing characters to high level almost immediately — so this isn't a slow drift, the sustain increase is large from the first play session onward for every vocation. Assassin/Nightblade were deliberately kept at the lowest percentages (+1%/+1%, +2%/+2%) specifically to protect the "must stay killable" commitment made for that vocation, rather than following the user's original "5+3%" example literally — flagged and accepted before implementing. No cap was added; revisit if sustain turns out to be too strong in practice.

### Loot Bag (designated auto-loot destination container)

QoL follow-up to auto-loot: lets a player nest a dedicated container inside their equipped backpack so auto-loot fills that inner bag instead of dumping loose into the main backpack. Investigated a literal new *paperdoll* equipment slot first and ruled it out — both the engine (`src/creature.h:20-33`, `enum slots_t`, exactly 10 slots) and the OTClientV8 client (`~/otclientv8/modules/game_inventory/inventory.lua`) hardcode the classic 10-slot 8.60 paperdoll; the client's only 11th slot (`InventorySlotPurse`) is gated behind a `GamePurseSlot` feature flag from a later protocol version this server never sends. A real new slot would mean extending the wire protocol plus patching and redistributing the client binary — rejected as disproportionate to the ask and against the "preserve the 8.6 feel" rule. Built as a plain container instead, using 100% native drag-and-drop — no protocol/client changes at all.

| File | Change | Mechanism |
|---|---|---|
| `data/scripts/lib/loot_bag.lua` | New — `LootBag = { itemId = 2004 }`, the single config point for which item id is recognized as the Loot Bag | `/reload scripts` |
| `data/scripts/eventcallbacks/monster/default_onDropLoot.lua` | Edited (4th time this file's been the extension point) — after resolving the equipped backpack's `Container`, scans its top-level contents (`container:getItems(false)`) for the first item matching `LootBag.itemId` that `isContainer()`, and if found reassigns `container` to that inner `Container` before the existing move-loop runs. No behavior change if none is found | `/reload scripts` |
| `data/scripts/talkactions/lootbag.lua` | New — `!lootbag` reports whether a Loot Bag is currently found (with fill level) or how to set one up. If `player:isUsingOtcV8()`, also opens a `ModalWindow` (id `4001`, next unused after Task Master's `4000`) with the same status text | `/reload scripts` |

**Item reuse — confirmed safe, unlike the earlier Assassin's Dagger rename**: item id `2004` ("golden backpack", `containerSize="20"`) was repo-wide grepped across `data/monster/monsters/`, `data/npc/`, and `data/scripts/` before reuse — zero references found in any loot table, shop, or quest script, so recognizing it specially has no side effects on existing content. No `items.xml` edit was made — its definition is untouched, only script logic treats its id specially.

**Why no new storage key**: state is entirely derived by scanning the container tree at loot time, not persisted — nothing to store, no range from the reserved scheme needed.

**v1 scope / known limitations**: only the top-level contents of the equipped backpack are scanned (same non-recursive scope as the rest of auto-loot); if more than one Loot Bag is nested, the first one found wins; if the Loot Bag is full, items stay in the corpse with no cascade back to the outer backpack (same "nothing is ever lost" guarantee as base auto-loot, just no fallback chain). Degenerate case, not a bug: if a player equips the golden backpack itself as their main backpack rather than nesting it, loot already goes straight into it via the existing unmodified code path.

**Modal window is status-only by design**: a `ModalWindow` is a simple text/choice dialog, not a real inventory panel — it cannot perform drag-and-drop itself (hard 8.60 protocol limitation), so it only reports status. No `CreatureEvent`/`onModalWindow` handler was registered for it (unlike Task Master's), since its one "OK" button has no server-side action to take — confirmed `Game::playerAnswerModalWindow` (`src/game.cpp:5110`) only dispatches to registered handlers if any exist, so omitting one is safe, not an oversight.

**Not built (flagged as follow-up, matching this project's staged-feature style)**: no NPC currently sells a golden backpack and it isn't in any monster's loot table, so there's currently no in-game way for a player to obtain one — hand out via GM for testing until a real acquisition path (NPC shop entry, or a loot table addition) is decided.

**PvP/economy flag (per design rule 3)**: none. Pure QoL — no new item is created, no faucet/sink, no PvP-facing effect; the golden backpack already existed and this only adds script-side recognition of its id.

### Test character: Shade

Manually inserted via direct SQL (no character-creation-by-admin flow exists) for testing the Assassin vocation end-to-end: level 8 Assassin, `player` group (not GM, so vocation/weapon locks and attack-speed actually apply), Thais temple, equipped with the assassin's dagger. See `players`/`player_items` tables, player id 3, account `admin`. Not a code change — no mechanism entry needed, just a DB row.
