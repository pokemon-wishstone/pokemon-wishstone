# CLAUDE.md: Pokémon Wishstone

Pokémon Wishstone is a GBA ROM hack built on **rh-hideout/pokeemerald-expansion** (RHH), a C decompilation of
Pokémon Emerald with modern mechanics. The expansion version is defined in `include/constants/expansion.h`.
Repo: `github.com/pokemon-wishstone/pokemon-wishstone` (a fork of RHH).

## How we work

- **Commit each logical change separately**, with a clear message that explains *why*. When asked to push, push
  straight to `origin/master` (the owner's preference for this repo).
- **No GitHub Actions.** `.github/workflows/` came from upstream and is not used here. Don't add, enable, or
  depend on CI unless asked. The local build is the gate.
- **Verify before saying "done".** At minimum `make -j12` must succeed. For gameplay changes, also run a test
  (`make check`) or playtest in mGBA where practical. Report anything you couldn't verify.
- **Stay mergeable with upstream.** Prefer flipping a toggle in `include/config/*.h` over editing engine code.
  Keep diffs small, don't rename upstream identifiers, and don't reformat code you didn't change.
- **Ask the owner** about design calls (story, regional dex, balance) and about anything that breaks existing
  saves. Pick sensible defaults for mechanical details and say what you picked.
- **Keep this file project-level.** It holds durable workflows, conventions, and gotchas. Don't log individual
  changes here; git history is the change log.

## Build & run

Toolchain: devkitARM at `/opt/devkitpro` (`$DEVKITARM` is set), macOS arm64, 12 cores, Python 3. The repo's
own tools (`tools/*`) build automatically on the first `make`.

| Command | What it does |
|---|---|
| `make -j12` | Build `pokeemerald.gba` (+ `.elf`, `.map`). |
| `make debug` / `make release` | `-Og -g` build / optimized `pokeemerald-release.gba` (LTO, debug menus and quickstart off). |
| `make check -j12 TESTS="Name"` | Build and run the test ROM headlessly (see [Testing](#testing)). |
| `make firered` / `make leafgreen` | FRLG builds. **`make clean` is required when switching between Emerald and FRLG.** |
| `make tidy` | Remove ROMs (`poke*.gba/elf/map`) and the `build/<game>*` object dirs. |
| `make clean-generated` | Delete all auto-generated sources so they regenerate. |
| `make clean` | Everything above plus tools and assets. A slow full rebuild follows. |
| `make -j12 UNUSED_ERROR=1 DEPRECATED_ERROR=1` | Upstream's stricter warning settings (optional). |

- **Playtest:** `open -a mGBA pokeemerald.gba`. **Maps:** Porymap is in `/Applications/porymap.app`; open the
  repo root as the project.
- In-game helpers in non-release builds: hold **R + START** in the overworld for the debug menu (warp, give
  mons/items, flags & vars). Press **SELECT** on the title screen for a quickstart new game. Press **SELECT** in
  battle for the battle debug menu. Debug menu "Scripts 1–8" run `Debug_EventScript_Script_1..8` in
  `data/scripts/debug.inc`, which are free slots for testing scripts.
- The link step prints ROM/EWRAM/IWRAM usage, so watch it as content grows. The biggest ROM savers are disabling
  unused families in `include/config/species_enabled.h` and `P_CRIES_ENABLED`.
- C is compiled with `-Werror` (unused-* warnings are downgraded locally).

### Reading build errors
- A misspelled constant in a script (`.inc` or `.pory`) does **not** fail at assembly. It shows up at link time as
  `undefined reference to 'FLAG_TYPO'` inside the script's label.
- Editor/clangd diagnostics like `'global.h' file not found` are noise. The IDE has no include paths configured, so
  trust `make` instead.

## Poryscript (scripting language)

Scripts are written in [Poryscript](https://github.com/huderlem/poryscript), which adds `if/elif/else`, `while`,
`switch`, inline text, auto-wrapped text, and inline movements, and compiles to the standard script macros.

- Binary: `tools/poryscript/poryscript` is **gitignored**. On a fresh clone, run `tools/poryscript/install.sh`
  (macOS / Linux / WSL; pinned version). `command_config.json` and `font_config.json` are tracked.
- Pipeline: every `data/**/*.pory` compiles to a sibling `.inc` during make's `generated` phase, before dependency
  scanning. Nothing else needs registering because the `.include` in `data/event_scripts.s` stays the same.
- **Write new map scripts as `data/maps/<Map>/scripts.pory`.** To convert an existing map:
  1. Create `scripts.pory`. Either rewrite the scripts, or wrap the old content in a `raw` block.
  2. `git rm --cached data/maps/<Map>/scripts.inc` and add that path to `.gitignore`. It is now a build artifact.
  3. Never hand-edit a `.inc` that has a `.pory` sibling, because it gets overwritten.
- Text: `format("long text")` auto-wraps to the message box (`1_latin_rse`, 208 px, 2 lines). Shorthands from
  `font_config.json` also work: `\e`→é, `\.`→…, `\m`/`\f`→♂/♀, `\h30`→`{PAUSE_30}`.
- Commands are the macros in `asm/macros/event.inc`, called like functions.

```
mapscripts MyTown_MapScripts {
    MAP_SCRIPT_ON_TRANSITION { setflag(FLAG_VISITED_MY_TOWN) }
}

script MyTown_EventScript_Girl {
    lock
    faceplayer
    if (flag(FLAG_BADGE01_GET)) {
        msgbox(format("Wow, you beat the first Gym? You must have a really strong Pokémon!"))
    } else {
        msgbox("Good luck at the Gym!")
    }
    release
}
```

Syntax reference: <https://github.com/huderlem/poryscript#poryscript-syntax-how-to-write-scripts>.

## Where things live

**Golden rule: never hand-edit generated files.** Edit the source column, and the build regenerates the rest.

| Content | Source (edit this) | Generated (don't edit) |
|---|---|---|
| Maps: objects, warps, events, connections | `data/maps/<Map>/map.json`, `data/maps/map_groups.json`, `data/layouts/layouts.json` (use Porymap) | `data/maps/<Map>/{header,events,connections}.inc`, `data/maps/*.inc`, `data/layouts/*.inc`, `include/constants/{map_groups,layouts,map_event_ids}.h` |
| Map scripts and text | `data/maps/<Map>/scripts.pory` (or a legacy `scripts.inc`); new maps need an `.include` in `data/event_scripts.s` | `.inc` from `.pory` |
| Shared scripts / text | `data/scripts/*.inc`, `data/text/*.inc` | |
| Script commands | macros `asm/macros/event.inc`, movements `asm/macros/movement.inc`, C in `src/scrcmd.c`, table `data/script_cmd_table.inc`; specials `data/specials.inc` → `src/field_specials.c` | `include/constants/script_commands.h` |
| Flags / vars | `include/constants/flags.h`, `vars.h`. Free slots: `grep -n "FLAG_UNUSED_0x\|VAR_UNUSED_0x" include/constants/{flags,vars}.h` | |
| Species data | `src/data/pokemon/species_info/gen_N_families.h` (stats, types, abilities, dex, evolutions, `OVERWORLD()`); new species go in `include/constants/species.h` between `SPECIES_CUSTOM_START`/`_END`, data in `src/data/pokemon/species_info.h` | |
| Learnsets | level-up `src/data/pokemon/level_up_learnsets/gen_N.h`, egg `egg_moves.h`, TM/tutor compatibility `src/data/pokemon/all_learnables.json` | `src/data/pokemon/teachable_learnsets.h`, `src/data/tutor_moves.h` |
| Pokémon graphics / cries | `graphics/pokemon/<name>/`, registered in `src/data/graphics/pokemon.h`; cries `sound/direct_sound_samples/cries/` + `sound/{direct_sound_data,cry_tables}.inc` + `include/constants/cries.h` | `build/assets/*` |
| Trainers and parties | `src/data/trainers.party` (Showdown-style; **only `/* */` comments**); IDs `include/constants/opponents.h`; classes `include/constants/trainers.h`; pics `graphics/trainers/` + `src/data/graphics/trainers.h` | `src/data/trainers.h` (via `tools/trainerproc`) |
| Wild encounters | `src/data/wild_encounters.json` | `src/data/wild_encounters.h` |
| Items / moves / abilities | `src/data/items.h`, `src/data/moves_info.h`, `src/data/abilities.h` (+ constants in `include/constants/`) | |
| Starters | `src/starter_choose.c` (`GRASS/FIRE/WATER_STARTER`); level in `src/battle_setup.c` (`ScriptGiveMon(starterMon, 5, …)`) | |
| Marts | inline in map scripts: `pokemart <Label>` → `.2byte ITEM_X` … `pokemartlistend` | |
| New game, intro, options | `src/new_game.c` (`SetDefaultOptions`, `NewGameInitData`), `src/main_menu.c` (Birch intro) | |
| Music | `sound/songs/midi/*.mid` **plus a line in `sound/songs/midi/midi.cfg`**; constants `include/constants/songs.h` | `sound/songs/midi/*.s` |
| NPC overworld sprites | `graphics/object_events/pics/`, `src/data/object_events/object_event_*.h`, `include/constants/event_objects.h` | |
| Heal locations / region map | `src/data/heal_locations.json`, `src/data/region_map/region_map_sections.json` | matching `.h` files |

Strings: C uses `_("...")` or `COMPOUND_STRING("...")`. Scripts use `.string "...$"` with `\n` (new line),
`\l` (scroll), `\p` (new box), and `{PLAYER}`, `{STR_VAR_1}`, `{COLOR RED}`, `{PAUSE n}`. The character table is
`charmap.txt`.

## Feature toggles: `include/config/*.h`

Most features are compile-time toggles. Check here before writing code:
`battle.h` (`B_*` mechanics by generation, battle UI), `ai.h`, `caps.h` (level/EV caps), `overworld.h` (`OW_*`:
followers, running indoors, RTC/time of day, berries), `pokemon.h` (`P_*`: species data gen, cries, GBA-style
sprites), `species_enabled.h` (enable or disable gens and families), `item.h` (`I_*`), `debug.h`, `quickstart.h`,
`dexnav.h`, `follower_npc.h`, `name_box.h`, `text.h`, `save.h`, `summary_screen.h`, `wild_encounter.h`,
`fishing.h`, `pokerus.h`, `contest.h`, `general.h`.
**Don't edit `test.h` for gameplay**, because it only applies to `TESTING` builds.

Many features ship with a `0` placeholder for a flag or var (`B_FLAG_*`, `B_VAR_*`, `OW_FLAG_*`, etc.). To turn one
on, assign it a free `FLAG_UNUSED_*` / `VAR_UNUSED_*`.

## Testing

- Tests live in `test/*.c` and `test/battle/**`. Write them with `TEST`, `SINGLE_BATTLE_TEST`, `GIVEN`/`WHEN`/
  `SCENE`/`THEN`, `ASSUMPTIONS`, and `PARAMETRIZE`. Overworld scripts use `RUN_OVERWORLD_SCRIPT`. The guide is
  `docs/tutorials/how_to_testing_system.md`.
- `make check -j12 TESTS="Thrash"`: `TESTS` is a prefix match on the test name. `"*foo"` is an infix match, and
  `"file.c"` matches an exact file. Omit `TESTS` to run everything (slow). The first run compiles the whole test
  ROM.
- The makefile only finds tests **up to 3 directories deep** (`test/a/b/c.c`).
- macOS uses the bundled `tools/mgba/mgba-rom-test-mac`, so nothing needs installing.
- Changing data (e.g. species stats) can break upstream tests. Use `ASSUMPTIONS` or fix them. Don't delete tests
  to make them pass.

## Code style (`docs/STYLEGUIDE.md`)

- Functions and structs are `PascalCase`. Variables are `camelCase`. Globals use the `g` prefix and statics `s`.
  Macros, constants, and enums are `CAPS_CASE`.
- Use 4-space indents in C. Use tabs in `.s`/`.inc`. Braces go on their own line, and `case` aligns with `switch`.
- No magic numbers: use enums and constants. Use `u32`/`s32` for locals and the smallest type for saved or global data.
- Check configs with normal `if (CONFIG)` control flow rather than `#if`, unless the data layout needs it.
- Comments explain *why*. Put big new features in their own files.

## Gotchas

- **Save compatibility:** anything that changes `SaveBlock1/2/3` or storage breaks existing saves. `src/save.c`
  `STATIC_ASSERT`s fail the build when a block outgrows flash. `include/config/save.h` has `FREE_*` options to
  reclaim space.
- **Trainer cap:** only a few free Emerald trainer IDs remain before `MAX_TRAINERS_COUNT_EMERALD` in
  `include/constants/opponents.h`. Reuse or replace vanilla trainers, or raise the cap (save-breaking).
- **FRLG data is in-tree** (`data/maps/*_Frlg`, `*_frlg.inc`, `trainers_frlg.party`). Emerald builds ignore it.
  `dev_scripts/delete_frlg_maps.py` removes it, which tidies the tree but saves no ROM space.
- **Docs can be stale.** `docs/tutorials/` is useful but lags the code. Check it against the source before
  following it.
- Teachable learnsets: `all_learnables.json` is only created if missing. Run `make clean-teachables` to
  regenerate it.
- Any new `docs/**/*.md` must be listed in `docs/SUMMARY.md` (mdBook). This root file is exempt.

## Updating from upstream (RHH)

```sh
git remote add RHH https://github.com/rh-hideout/pokeemerald-expansion   # once
git pull RHH expansion/X.Y.Z                                                # step one version at a time
```
Check `migration_scripts/README.md` for data-conversion scripts needed for the target version, and run them
from the repo root with `python3`. Expect conflicts wherever we've changed upstream files (e.g. the Poryscript
rules in `Makefile`). Keep upstream's version and reapply ours. Rebuild and run tests afterwards.

Credit line for releases (requested by RHH): *Based off RHH's pokeemerald-expansion
https://github.com/rh-hideout/pokeemerald-expansion/*
