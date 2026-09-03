# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

MillhioreBT `forgottenserver-downgrade` — a **TFS 1.5+ core** (`STATUS_SERVER_VERSION = "1.5+"` in `src/definitions.h`) with the **client protocol locked to 8.60** (`CLIENT_VERSION_MIN`/`MAX = 860`). This is a protocol downgrade, not an engine downgrade: the Lua API is the modern TFS 1.x OOP/class-based API (`Player`, `Npc`, `Combat`, `Vocation`, `Weapon`, `ModalWindow`, … — 31 registered classes across `src/lua*.cpp`) plus **revscriptsys** (`data/scripts/`), not old TFS 0.x procedural style.

**Two script registration conventions coexist in `data/` and both are live:**
- **Legacy XML-registered**: a top-level folder per feature (`data/actions`, `data/creaturescripts`, `data/globalevents`, `data/movements`, `data/spells`, `data/talkactions`, `data/weapons`), each with an XML index (e.g. `data/spells/spells.xml`) pointing at a `scripts/*.lua` file.
- **Revscripts**: `data/scripts/` mirrors the same categories, but each `.lua` file self-registers via the modern class API (no XML needed).

**When adding content, check which convention the target folder already uses and follow it — don't mix patterns within the same feature.** Old TFS 0.x-only procedural functions (`doPlayerSendTextMessage`, `doCreateItem`, etc.) exist only as a backward-compat shim in `data/lib/compat/compat.lua`; don't write new code in that style — call the modern OOP API directly, exactly as the shim itself does internally.

The map in use is `global.otbm` (`data/world/global.otbm`, `mapName = "global"` in `config.lua`).

## Client: OTClient Redemption

The intended client is **OTClient Redemption** (`~/otclient`, built natively per-platform — e.g. `OTClient.app` on macOS via CMake/Ninja, same pattern as building this server from source), **not OTCv8** (`~/otclientv8` — kept around, but no longer the target; superseded 2026-09-02).

This matters more than a naming swap: Redemption does **not** send the OTCv8 detection marker string, so `isOTCv8` stays `false` for it server-side (`src/protocolgame.cpp:367-371`). Concretely:

- The generic "is some OTClient-family client" branch still fires (`operatingSystem >= CLIENTOS_OTCLIENT_LINUX`, true for Redemption on any platform), which enables the base extended-opcode channel — but `sendOTCv8Features()` (the `OTCFeatures` list push from `config.lua`) is skipped, since that call is nested inside `if (isOTCv8)` specifically.
- **Modal windows are currently non-functional for this client.** `ProtocolGame::sendModalWindow()` (`src/protocolgame.cpp:2184-2188`) is gated by `if (!isOTCv8) { return; }` — with `isOTCv8` false, this is the same silent no-op documented below for vanilla 8.60 clients. Every modal-window-based feature built so far (Task Master, Promotion Master, the Loot Bag status window) is affected. Not yet fixed — flagged here so it isn't mistaken for working.

**Design rule (now load-bearing, not just future-proofing)**: build any player-menu *logic* to work via talkactions/NPC dialogue first (universal, works for any client) before layering a modal-window UI on top — on the actual client in use today, the modal-window layer doesn't render at all, so talkaction/dialogue is the only path that currently works.

Redemption also ships its own client-local static Lua data for some UI (e.g. the Spell List window's spell table, `~/otclient/modules/gamelib/spells.lua`) sourced from a different upstream ("canary") reference dataset — this needs to be kept in sync with this server's actual `data/spells/spells.xml` by hand; there's no server-side push for it. See `BUILD_NOTES.md` for the spell-list fix and its limitations.

## Running the server (Docker)

```
docker compose up -d --build   # build the server image and start db + server
docker compose logs -f server  # follow server output
docker compose down            # stop (add -v to also wipe the MariaDB volume)
```

- `db`: MariaDB 11.4, seeded on first boot from `schema.sql`. Credentials/database are defined in `docker-compose.yml` (db: `forgottenserver`, user: `tfs`) and must match `mysqlHost`/`mysqlUser`/`mysqlPass`/`mysqlDatabase`/`mysqlPort` in `config.lua`.
- `server`: built from the repo via `Dockerfile` (Ubuntu 22.04 + vcpkg + CMake/Ninja, `RelWithDebInfo`), waits on the db healthcheck, then runs `/bin/tfs`. Ports 7171 (login/status) and 7172 (game) are published to the host.
- `config.lua` and `data/` are bind-mounted (`./config.lua:/srv/config.lua`, `./data:/srv/data`) — editing either on the host is picked up **without a rebuild**, but whether it needs a `/reload`, a container restart, or nothing further depends on exactly what changed. See **Change → mechanism table** below; don't assume "restart" or "just reload" by default.
- On first run the DB is empty except for `schema.sql`; create accounts via the in-game account manager (`accountManager = true` in `config.lua`) or by inserting rows directly.

## Change → mechanism table

**Every feature or edit you make must state which of these applies**, in your summary to the user and in the `BUILD_NOTES.md` log entry for it.

| Change | Mechanism | Notes |
|---|---|---|
| `data/items/items.xml` (and `.otb`) | `/reload items` (in-game GM command) | `Item::items.reload()` re-parses both files from scratch |
| `data/weapons/`, `data/spells/`, `data/actions/`, `data/movements/`, `data/talkactions/`, `data/creaturescripts/` (the **legacy XML-registered** folders) | `/reload <type>` (e.g. `/reload weapons`) | `BaseEvents::reload()` (`src/baseevents.cpp:69`) just re-runs `loadFromXml()` on that folder's index — it never touches `data/scripts/` |
| `data/scripts/*` (revscripts: `actions`, `creaturescripts`, `globalevents`, `movements`, `spells`, `talkactions`, `weapons`, `lib`, …) | `/reload scripts` **only** | `RELOAD_TYPE_SCRIPTS` → `g_scripts->loadScripts("scripts", …)` (`src/game.cpp:5285`). The matching legacy reload type (e.g. `/reload talkactions`) does **not** pick these up — it only rescans the legacy folder |
| `data/npc/` (`.xml` definitions + `scripts/*.lua` dialogue) | `/reload npcs` | `Npcs::reload()` only reloads the script of NPCs that **already exist as live objects** — it does not scan for or spawn brand-new NPCs (see vocations.xml-style caveat: a genuinely new NPC needs to be created via `Game.createNpc()`, typically from a `startup` globalevent, which only runs on a real boot — see restart row below) |
| `data/lib/**` (e.g. `data/lib/core/storages.lua`) | **container restart** | Loaded once via a hardcoded `dofile` chain (`data/global.lua` → `data/lib/lib.lua` → `data/lib/core/core.lua` → `dofile("data/lib/core/storages.lua")`) at process boot. No `/reload` case touches `data/lib/` at all — this is easy to assume is "just a Lua table, surely reload picks it up," but it doesn't |
| A brand-new NPC's *first appearance* (via `Game.createNpc()` in a `type="startup"` globalevent) | **container restart** | `type="startup"` globalevents only fire once, at real process boot — `/reload globalevents` reloads the event *definitions* but never re-triggers a startup run |
| `data/XML/vocations.xml` | **container restart** (`docker compose restart server`) | `Vocations`/`Vocation` has **no `reload()` method anywhere in `src/`** and `"vocation"` is absent from the reload dispatch table — there is no hot-reload path, full stop |
| `data/XML/outfits.xml` | **container restart** | same — no reload path |
| `config.lua` — rates, world type, PvP/skull rules, protection level, most gameplay toggles | `/reload config` | Re-read live; `ConfigManager::load()` updates these every call |
| `config.lua` — `ip`, ports, `mapName`, `mapAuthor`, `mysqlHost`/`mysqlUser`/etc., `bindOnlyGlobalAddress`, `startupDatabaseOptimization` | **container restart** | Gated by an `if (!loaded)` one-time guard in `ConfigManager::load()` (`src/configmanager.cpp:191`) — `/reload config` silently skips these on subsequent calls |
| `src/**` (engine/protocol) | **full rebuild**: `docker compose up -d --build server` | Anything here is a last resort — prefer `data/`/`config.lua` |

## Design rules (project intent — read before building anything)

These are the user's standing rules for this project. They apply to every feature, not just the ones already built.

1. **Preserve the 8.6 feel.** In-bounds: anything that existed in or fits 2011-era 8.6 Tibia. Out-of-bounds: imbuements, prey, charms, forge, market, store, Wheel of Destiny, and any post-8.6 spell/item tiers. When unsure, err classic.
2. **Keep the four base roles legible — Knight (melee tank), Paladin (ranged/hybrid), Sorcerer (offense magic), Druid (heal/support).** Never blur these into each other. A new vocation (e.g. the Assassin/Nightblade fast-melee glass-cannon striker) is allowed to exist as its own **intentional fifth role**, with its own distinct identity — it just must not become a blurred clone of Knight or of any other existing role.
3. **Protect PvP and the economy.**
   - No vocation should dominate PvP. Assassin's high DPS is deliberately balanced by low HP — it must stay killable.
   - Every gold/item faucet needs a sink.
   - Death penalty stays meaningful.
   - No unlimited gold/item generation.
   - **Flag the PvP impact of any new bonus before adding it** — say so explicitly, don't bury it.
4. **Plan before code.** For anything touching balance, new vocations, new spells, or new stats: propose a written design (names, numbers, effects) and wait for explicit approval before implementing. Trivial edits the user explicitly asked for can proceed directly without a separate plan step.
5. **Storage IDs are a reserved-range scheme, not ad hoc numbers.** See `BUILD_NOTES.md` for the currently-approved ranges. Before claiming a new storage key: read `data/lib/core/storages.lua`, confirm which range your system falls under (or propose a new block if none fits), and get it approved — don't invent a number on the spot.

## Building from source (outside Docker)

Use this only when iterating on `src/` (C++ engine) directly rather than through the Docker image.

- Dependencies are managed via vcpkg (`vcpkg.json`); CMake presets (`CMakePresets.json`) expect `VCPKG_ROOT` set and use Ninja.
- Configure + build:
  ```
  cmake --preset vcpkg
  cmake --build build --config RelWithDebInfo
  ```
- Useful CMake options (`-D<OPTION>=ON/OFF`): `HTTP` (default ON), `USE_LUAJIT` (default OFF, uses Lua instead), `BUILD_TESTING` (default OFF).
- VS Code / Zed launch configs build into `build-debug/` and `build-release/` instead (see `.vscode/launch.json`, `.zed/`); use whichever matches your editor.
- The resulting `tfs` binary expects to run from a working directory containing `config.lua` and `data/` (i.e. the repo root, or `/srv` inside Docker).

## Linting / CI checks

There is no application test suite (`BUILD_TESTING` is off by default and no unit tests exist in-tree). CI (`.github/workflows/`) instead runs static checks — reproduce these locally before pushing content or C++ changes:

- **C++ formatting**: `clang-format -n -style=file --Werror src/*.{cpp,h}` (must match `.clang-format`; run without `-n` to auto-fix).
- **Lua syntax**: `find data/ -name '*.lua' -print0 | xargs -0 -n1 luac -p`
- **Lua lint**: `luacheck data config.lua.dist` (non-blocking in CI, but keep it clean)
- **Lua format**: `luaformatter -i <file>` per `.lua-format` (tab-indented, see `.editorconfig`)
- **XML syntax**: `find data/ -name '*.xml' -print0 | xargs -0 -n1 xmllint --noout`

Only touched files matter for these — CI scopes each workflow by path (`src/**`, `data/**.lua`, `data/**.xml`).

## Architecture

### Engine (`src/`) vs. content (`data/`)

The C++ engine in `src/` is a generic Tibia server core (networking, map/creature/combat simulation, database I/O, the Lua scripting binding). Almost all actual gameplay behavior — spells, monsters, vocations, items, quests, NPC behavior, rates — lives as data/config outside `src/`. When customizing gameplay, prefer editing `data/` and `config.lua` over `src/`; only touch `src/` for protocol/engine-level changes.

### Where gameplay customization lives

- **Rates & world rules**: `config.lua` (rate*, world type, PvP/skull rules, protection level, house rules, connection limits, `OTCFeatures` list controlling which client-side feature flags are forced). `config.lua.dist` is the shipped default/reference — diff against it when unsure what changed.
- **Vocations** (skill gain formulas, mana/HP/cap growth, spell access): `data/XML/vocations.xml`. **No hot-reload — restart required, see table above.**
- **Spells**: `data/spells/spells.xml` + `data/spells/scripts/{attack,healing,support,conjuring,house,party,custom}` (legacy) and/or `data/scripts/spells/` (revscript).
- **Monsters**: `data/monster/monsters.xml` (registry) + `data/monster/monsters/*.xml` (per-creature stats/loot/behavior) + `data/monster/lua/` (custom monster scripts).
- **Items**: `data/items/items.xml` (+ `items.otb`, both re-parsed together on `/reload items`).
- **Weapons**: `data/weapons/weapons.xml` (vocation locks, `unproperly` penalty vs. hard block) + `data/weapons/scripts/`.
- **Map**: `data/world/global.otbm` (binary OTBM, edit with Remere's Map Editor or similar — not a text format), with companion `global-spawn.xml` (creature spawns) and `global-house.xml` (house definitions). `forgotten.otbm`/`forgotten-*.xml` are a leftover default map, not the active one.
- **NPCs**: `data/npc/` (`.xml` definition + `scripts/*.lua` dialogue, legacy-style keyword handler).
- **Storage IDs**: `data/lib/core/storages.lua` — see reserved-range scheme in `BUILD_NOTES.md`.

### Database

MariaDB, schema defined in `schema.sql` (applied automatically only on first container start via `docker-entrypoint-initdb.d`). Schema changes to an existing DB need a manual migration or a fresh volume (`docker compose down -v`) — check `data/migrations/` first for the project's migration convention before hand-editing the live schema. Note: `towns` table is a cache populated fresh from the OTBM map on every server start by `data/globalevents/scripts/startup.lua` (`TRUNCATE` + repopulate) — town data itself lives in the binary map, not authored in SQL.

## See also

`BUILD_NOTES.md` — the running build/feature log: what's been added, which reload/restart mechanism each feature needs, and the approved storage-ID reservation scheme.
