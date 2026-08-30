# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

MillhioreBT TFS Downgrade — a C++ Tibia game server (fork of The Forgotten Server) patched to speak the old 8.60 client protocol. It's under active development; content (monsters, spells) is not guaranteed to be 100% accurate to the original 8.60 client and is expected to be tuned over time. The map in use is `global.otbm` (`data/world/global.otbm`, `mapName = "global"` in `config.lua`).

## Running the server (Docker)

The normal way to run this project is via Docker Compose, not a bare local build:

```
docker compose up -d --build   # build the server image and start db + server
docker compose logs -f server  # follow server output
docker compose down            # stop (add -v to also wipe the MariaDB volume)
```

- `db`: MariaDB 11.4, seeded on first boot from `schema.sql`. Credentials/database are defined in `docker-compose.yml` (db: `forgottenserver`, user: `tfs`) and must match `mysqlHost`/`mysqlUser`/`mysqlPass`/`mysqlDatabase`/`mysqlPort` in `config.lua`.
- `server`: built from the repo via `Dockerfile` (Ubuntu 22.04 + vcpkg + CMake/Ninja, `RelWithDebInfo`), waits on the db healthcheck, then runs `/bin/tfs`. Ports 7171 (login/status) and 7172 (game) are published to the host.
- `config.lua` and `data/` are bind-mounted into the container (`./config.lua:/srv/config.lua`, `./data:/srv/data`), so editing either on the host and restarting the `server` container is enough to pick up changes — no rebuild needed for gameplay/content tuning. A rebuild (`docker compose up -d --build server`) is only needed after C++ (`src/`) changes.
- On first run the DB is empty except for `schema.sql`; create accounts via the in-game account manager (`accountManager = true` in `config.lua`) or by inserting rows directly.

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

The C++ engine in `src/` is a generic Tibia server core (networking, map/creature/combat simulation, database I/O, a Lua scripting binding). Almost all actual gameplay behavior — spells, monsters, vocations, items, quests, NPC behavior, rates — lives as data/config outside `src/` and is loaded at startup or on `/reload`. When customizing gameplay, prefer editing `data/` and `config.lua` over `src/`; only touch `src/` for protocol/engine-level changes (e.g. the 8.60 downgrade work itself).

### Two script registration systems in `data/`

This codebase carries both TFS's legacy XML+Lua system and the newer "revscripts" system, and content can live in either:

- **Legacy**: a top-level folder per feature (`data/actions`, `data/creaturescripts`, `data/globalevents`, `data/movements`, `data/spells`, `data/talkactions`, `data/weapons`), each with an XML index file (e.g. `data/spells/spells.xml`) that declares words/names/ids and points at a `scripts/*.lua` file, plus a shared `lib/`.
- **Revscripts**: `data/scripts/` mirrors most of the same categories (`actions`, `creaturescripts`, `globalevents`, `movements`, `spells`, `talkactions`, `weapons`, plus `eventcallbacks`, `network`, `quests`, `lib`) but each `.lua` file self-registers in Lua (no XML needed) and is auto-loaded from the directory.

When adding new spells/actions/etc., check whether similar existing content is legacy-XML or revscript style in the relevant folder and follow that convention rather than mixing patterns for the same feature.

### Where gameplay customization lives

- **Rates & world rules**: `config.lua` (rate*, world type, PvP/skull rules, protection level, house rules, connection limits, `OTCFeatures` list controlling which client-side feature flags are forced). `config.lua.dist` is the shipped default/reference — diff against it when unsure what changed.
- **Vocations** (skill gain formulas, mana/HP/cap growth, spell access): `data/XML/vocations.xml`.
- **Spells**: `data/spells/spells.xml` + `data/spells/scripts/{attack,healing,support,conjuring,house,party,custom}` (legacy) and/or `data/scripts/spells/` (revscript).
- **Monsters**: `data/monster/monsters.xml` (registry) + `data/monster/monsters/*.xml` (per-creature stats/loot/behavior) + `data/monster/lua/` (custom monster scripts).
- **Items**: `data/items/` (not detailed above; check `items.xml`/`items.otb` conventions there before editing).
- **Map**: `data/world/global.otbm` (binary OTBM, edit with Remere's Map Editor or similar — not a text format), with companion `global-spawn.xml` (creature spawns) and `global-house.xml` (house definitions). `forgotten.otbm`/`forgotten-*.xml` are a leftover default map, not the active one.
- **NPCs**: `data/npc/`.

### Database

MariaDB, schema defined in `schema.sql` (applied automatically only on first container start via `docker-entrypoint-initdb.d`). Schema changes to an existing DB need a manual migration or a fresh volume (`docker compose down -v`) — check `data/migrations/` first for the project's migration convention before hand-editing the live schema.
