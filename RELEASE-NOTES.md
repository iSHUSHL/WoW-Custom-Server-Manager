# v1.5.98 — WotLK PlayerBots Database Bootstrap

- Fixes WotLK World hanging at `Database "acore_playerbots" does not exist` / `Do you want to create it?`.
- Before worldserver starts, WoWCC verifies the real PlayerBots database contains tables, not just a stale ready marker.
- Missing/empty `acore_playerbots` automatically runs the repeatable WotLK PlayerBots bootstrap, imports module SQL/migrations, validates tables, and creates the ready marker.
- PlayerBots startup then uses the 15-minute initialization timeout instead of falling back to the normal 30-second timeout.
- Keeps the forced `AC_PLAYERBOTS_DATABASE_INFO` managed-MySQL 3307 override and clean in-app titlebar.

# v1.5.97 — WotLK PlayerBots DB Environment Override

- Forces the PlayerBots database connection through AzerothCore's highest-priority `AC_PLAYERBOTS_DATABASE_INFO` environment override.
- World Server now receives `127.0.0.1;3307;wowcc;wowcc;acore_playerbots` directly at process launch.
- Also pins PlayerBots DB worker/sync threads to 1.
- This bypasses any stale worldserver/module config that still contains port 3306.
- Keeps the clean in-app titlebar from 1.5.95.

# v1.5.96 — WotLK PlayerBots worldserver.conf DB Fix

- Fixes the remaining WotLK PlayerBots startup failure on MySQL 127.0.0.1:3306.
- The PlayerBots database pool reads `PlayerbotsDatabaseInfo` from `worldserver.conf`; WoWCC now self-heals that core setting to managed MySQL 3307 before every start.
- Keeps the all-playerbots.conf repair and clean titlebar changes from 1.5.95.
- No core rebuild, client preparation, or PlayerBots repopulation required.

# v1.5.95 — PlayerBots Runtime Config Sweep + Clean Titlebar

- Fixes persistent WotLK PlayerBots startup attempts on MySQL 3306 by repairing every runtime playerbots.conf inside the managed WotLK profile before World starts.
- Logs every repaired PlayerBots config path to playerbots-config.log, visible in WoWCC Logs.
- Removes the custom WoW icon/title/subtitle from the app window titlebar while keeping the Dock/Finder app icon.
- Keeps all 1.5.94, SDK 27, and WotLK database fixes.

# v1.5.94 — WotLK PlayerBots DB Port Self-Heal

- Fixes WotLK worldserver startup failure where acore_playerbots still attempted MySQL 127.0.0.1:3306.
- Repairs PlayerbotsDatabaseInfo to WoWCC managed MySQL port 3307 before every World start.
- Updates both persistent configs/playerbots.conf and runtime etc/modules/playerbots.conf.
- No core rebuild, client rebuild, or PlayerBots repopulation required.

# v1.5.93 — macOS SDK 27 / Swift 6 UI Build Fix

- Fixes local Build.command failures under macOS SDK 27 / Swift 6 where helper-view closures treated ContentView state as immutable.
- Moves mutable ContentView helper state into a reference-backed ObservableObject.
- Restores reliable Level field binding and cleanup/navigation mutations.
- Splits the sidebar row into a smaller view expression to avoid Swift compiler type-check timeouts.
- Keeps the WotLK managed MySQL 3307 self-heal from 1.5.92.

# v1.5.92 — WotLK Managed MySQL Port Repair

- Fixes WotLK world/auth startup attempting MySQL on port 3306 while WoWCC managed MySQL listens on 3307.
- Auth and World launch now self-heal AzerothCore database connection strings before every start and watchdog restart.
- Keeps Login/World/Character database connections aligned with WoWCC managed MySQL credentials and port.

# v1.5.91 — WotLK VMap Retry Cleanup

- Fixes `Your output directory seems to be polluted` when rerunning WotLK Prepare Client.
- Automatically removes stale `Buildings/` and `vmaps/` before `vmap4extractor`.
- Makes Prepare Client repeatable after interrupted or failed extraction attempts.
- Release artifacts are uploaded as a folder so the downloaded ZIP contains the project directly instead of another ZIP.

# v1.5.90 — WotLK MMAP Config Fix

- Fixes Prepare Client failure: `Failed to load configuration` from `mmaps_generator`.
- Copies and validates `mmaps-config.yaml` during WotLK core install.
- Prepare Client self-heals older installs by locating the config in profile/build/source paths.
- Runs `mmaps_generator --config <absolute path>` explicitly.

# v1.5.89 — WotLK Extractor Target Rescue

- Detects Playerbot fork extractor output aliases instead of assuming one filename.
- If the main WotLK PlayerBots build omits maps tools, WoWCC performs a dedicated `TOOLS_BUILD=maps-only` build and installs the extractors automatically.
- `Prepare Client` accepts upstream underscore aliases but normalizes to the stable WoWCC names.
- Extractor configure/build diagnostics are available as `cmake-wotlk-extractors.log` in WoWCC Logs.

# v1.5.88 — WotLK PlayerBots Clone + Extractor Repair

- Fixed false “mod-playerbots clone is incomplete” failure: current upstream module has no root CMakeLists.txt.
- Validates the real PlayerBots payload and automatically reclones an interrupted checkout.
- Verifies all four WotLK extractor binaries immediately after core compilation.
- Keeps WotLK PlayerBots population range up to 5,000.

# v1.5.87 — WotLK Extractor Recovery

- Fixes Prepare Client falsely reporting a missing `mapextractor` after a successful WotLK/PlayerBots core rebuild.
- WotLK rebuild now verifies all four required extractor binaries and recovers them from the CMake build tree into the managed profile `bin/` directory when necessary.
- Prepare Client can self-heal an existing WotLK installation by locating already-built extractors in the persistent build tree.
- Missing extractor errors now point to the WoWCC Core Build log instead of simply asking to reinstall repeatedly.

# v1.5.86 — WotLK PlayerBots

- Added managed WotLK PlayerBots using the compatible Playerbot AzerothCore fork plus `mod-playerbots`.
- PlayerBots page now supports both TBC and WotLK.
- Bot population range is 10–5,000 with a safe default of 150 and quick presets through 5,000.
- Added WotLK `acore_playerbots` database bootstrap, repeatable SQL migrations, managed `playerbots.conf`, live bot counts, and one-click initialization.
- WotLK PlayerBots setup logs are written to `playerbots-setup.log` and automatically appear in WoWCC Logs.
- Existing WotLK realm/client data is preserved when rebuilding the compatible PlayerBots core.

# v1.5.85 — Cataclysm Client DB2 Extraction Fix

- Makes Cataclysm mapextractor mandatory instead of silently ignoring a missing/failed extractor.
- Validates that Item.db2 and Item-sparse.db2 were actually produced.
- Finds those DB2 files regardless of extractor output folder and normalizes them into managed data/db2/.
- Keeps Cata Repair Realm dependent on real extracted 4.3.4 client data instead of failing later with a misleading missing-file error.
- Leaves MoP preparation independent from the Cataclysm DB2 rules.

# v1.5.84 — Cataclysm DB2 Realm + Catalog Fix

- Fixes Cataclysm Repair Realm incorrectly requiring the WotLK-only `world.item_template`.
- Creates/configures the Cataclysm `hotfixes` database required by the 4.3.4 Trinity branch.
- Adds `HotfixDatabaseInfo` to the managed Cata worldserver configuration.
- Requires/copies Cata `db2` client data as part of client-data readiness.
- Builds a full WoWCC Cataclysm catalog table from `Item.db2` and `Item-sparse.db2`.
- Collection Browser, Gear Sets, inventory names and tooltips use the generated Cata catalog while TBC/WotLK/MoP keep their existing tables.
- Preserves the restored pre-premium UI and tooltip auto-fit.

# v1.5.83 — WotLK / Cata / MoP Catalog Recovery

- Adds live item_template schema introspection for Collection Browser.
- Rejects suspiciously empty world catalogs instead of silently showing zero items.
- Adds catalog.log diagnostics automatically visible in the WoWCC Logs UI.
- WotLK Setup/Repair validates acore_world.item_template content after dbimport.
- Cataclysm/MoP Setup/Repair validates world.item_template content after community DB import.
- Keeps the restored pre-premium 1.5.80 UI and tooltip auto-fit behavior.

# v1.5.80 — Tooltip Auto-Fit

- Removed the unusable tooltip ScrollView/scrollbar from the mouse-transparent floating panel.
- Tooltip height now uses real SwiftUI wrapped-content measurement instead of newline estimation.
- Tooltip progressively widens up to the available display width so long Blizzard-style details fit without clipping.
- Tooltip remains mouse-transparent so Give and other controls remain clickable.

# v1.5.79 — Blizzard-Style Tooltips + Resilient Era Icons

- Reworks item hover cards into a Blizzard/WoW-style visual hierarchy with quality-colored title, green Equip/Use/Set effects, red requirements, flavor text and scroll-safe long cards.
- Hybrid tooltip data: local realm item_template appears immediately; era-correct Wowhead XML enriches spell/set/effect text when available.
- Adds era-specific icon lookup cascades for Vanilla, TBC, WotLK, Cataclysm and MoP plus generic fallback.
- Missing icons are retryable instead of becoming permanently dead after one transient network failure.
- Adds an always-visible Reload Missing Icons action and keeps persistent local icon caching.
- Keeps the 1.5.77 TBC full-world-catalog repair and 1.5.78 Repair Realm UI.

# v1.5.78 — Full Tooltips + Visible Realm Repair

- Permanent Repair Realm button in the top bar.
- Repair Realm remains available after Setup step 6 is Done.
- Collection tooltips now read detailed fields directly from the selected realm item_template database.
- Tooltip panel widened and auto-sized so long item details are not clipped.
- Preserves 1.5.77 TBC full-world-catalog validation and repair.

# v1.5.77 — TBC Full World Catalog Repair

- Fixes TBC Collections showing only a few items when a partial `mangos.item_template` had been incorrectly accepted as a ready realm.
- TBC Setup/Repair validates actual item, Epic, Legendary and Mount row counts.
- An incomplete TBC world catalog automatically rebuilds only `mangos` from official `cmangos/tbc-db`; accounts and characters are preserved.
- The realm is not marked ready if the repaired catalog still fails validation.

# v1.5.76 — Clean ZIP / Missing Runtime Build Fix

- Fixes `Build.command` failing after a successful Swift compile when the source package has no top-level `runtime/` directory.
- The app bundle now creates `runtime-template` unconditionally and copies source runtime data only when that optional folder exists.
- A missing source runtime template is informational, not a build failure.
- Preserves the complete TBC catalog fixes from 1.5.75.

# v1.5.75 — TBC Complete Catalog Restore

- Removes hard-coded item-ID era ranges from Collection Browser and Gear Sets.
- TBC now reads every item and every DB-defined item set available in its own `mangos.item_template`, including Classic content still valid in 2.4.3.
- Restores complete TBC Raid Sets, Epic+ results, Legendaries, All Items, and Mounts.
- Mounts always clear hidden quality/class/slot/iLvl filters before loading.
- Broadens mount-name fallback for unusual/custom CMaNGOS rows while retaining the native Misc/Mount classification.
- Keeps paging, class filters, item icons, tooltips, Give actions, PlayerBots, premium UI, and existing server controls intact.

# v1.5.69 — Expansion-Isolated Complete Collections

- Vanilla, TBC, WotLK, Cataclysm and MoP collections are isolated by item era so cumulative later DBs do not mix older-expansion items into the selected expansion.
- Switching expansion automatically selects All Items and loads that expansion catalog plus its gear sets.
- All Items, Legendaries, weapons, armor, raid sets, bags, mounts and BiS/endgame use the same expansion boundary.
- Changing collection resets hidden filters so complete collections are not silently reduced.
- Gear Sets uses the same expansion-only boundary.

# v1.5.68 — Complete Expansion Collection Browser

- Collection Browser now exposes every existing collection type, including Bags and Mounts.
- Switching collections automatically loads the selected collection instead of clearing the grid and waiting for another click.
- All Items is database-backed and exposes the complete `item_template` catalog for the selected expansion through paging.
- Every page now reports its real total count, so no items are silently hidden behind the first 250 rows.
- Legendaries query the realm database directly with `Quality = 5`, including all TBC legendary entries present in the installed TBC database.
- The same database-backed path is used for Vanilla, TBC, WotLK, Cataclysm, and Mists of Pandaria profiles.
- Changing expansions clears stale filters/catalog state before the new expansion is loaded.
- Death Knight filtering is no longer offered for Vanilla or TBC.
- Existing premium UI, Dock icon/title branding, server controls, PlayerBots, logs, and gameplay fixes remain intact.

# v1.5.65 — PlayerBots Creation Speed Control

Adds a PlayerBots **Creation speed** selector directly in the WoWCC UI:

- Safe: 2 logins / 5000 ms update
- Normal: 5 logins / 2000 ms update
- Fast: 10 logins / 1000 ms update
- Maximum: 20 logins / 500 ms update

Fast is the default. The selected speed is saved per profile and passed to `setup-playerbots.sh` during Populate / Repair.

The temporary 150 population cap remains removed, and the v1.5.63 GameObject::Use crash fix is retained.

# v1.5.64 — PlayerBots Population Cap Removed

- Removes WoWCC's temporary 150-bot Safe Mode enforcement.
- The population entered in the PlayerBots UI is now passed through unchanged when Populate / Repair is run.
- `setup-playerbots.sh` no longer clamps the requested population to 150.
- Script fallback is restored to 1000 if no population argument is supplied.
- Existing bot accounts and characters are preserved.
- Keeps the v1.5.63 GameObject::Use crash patch.

The UI can still initially display 150 on a fresh app state; that is only a starting value, not a cap. Enter the population you want before Populate / Repair.

# v1.5.63 — Robust GameObject::Use Patch

v1.5.62 found the correct crash and fix, but its installer matched an exact multiline source snippet. A harmless source-layout/formatting difference on the installed CMaNGOS tree caused the rebuild to stop before compilation.

v1.5.63 keeps the same confirmed C++ fix but applies it structurally:

- Finds `GameObject::Use`.
- Restricts matching to `GAMEOBJECT_TYPE_SPELLCASTER`.
- Requires the branch to contain both `onSuccess` and `info->spellcaster.charges`.
- Replaces exactly one vulnerable `[&]` capture with `[this, info]`.
- Accepts whitespace/comment/layout differences.
- Detects an already-patched source and exits successfully.
- Refuses to touch a different code path if the expected logic is genuinely gone.

No database, characters, PlayerBots population, or gameplay data are reset.

# v1.5.62 — Confirmed GameObject::Use PlayerBots Crash Fix

The full LLDB stack identified the crash path:

`GameObject::Use` → `WorldSession::HandleGameObjectUseOpcode` → `HandleBotPackets` → `PlayerbotHolder::UpdateSessions`

The failing lambda exists only in the spellcaster GameObject branch. Upstream TBC currently creates `onSuccess` with `[&]`, capturing the block-local `info` pointer variable by reference, then invokes `onSuccess()` after the switch scope. That leaves a dangling reference to the local pointer variable.

Fix:
- Changes the lambda capture from `[&]` to `[this, info]`, preserving the `GameObject` and the `GameObjectInfo*` value safely until `onSuccess()` executes.
- Patch is applied automatically during TBC core rebuild and refuses to modify the source if upstream layout no longer matches.
- TBC World is returned to **normal non-LLDB execution**, removing debugger overhead and slow Stop World behavior.
- Existing Crash/UI logging remains.
- Bot population is not reduced.
- Existing bot characters are preserved.

A TBC core rebuild is required because this is a C++ core source fix.

# v1.5.61 — LLDB Crash Handler + Faster Stop

We now have the first exact native crash location:

`GameObject::Use(Unit*, SpellEntry const*)` lambda → `EXC_BAD_ACCESS`, address `0x40`.

That is a real invalid-pointer/native access in the GameObject use path; the moving bot count was only determining when the bad path was reached.

Changes:
- LLDB now uses its dedicated **on-crash (`-k`) commands** to run `thread backtrace all` and then quit.
- This should capture the complete caller stack instead of leaving the target sitting stopped at frame #0.
- **Stop World** no longer waits the full normal grace period when the process is the LLDB/xcrun diagnostic wrapper; debugger shutdown grace is capped at 1 second.
- All debugger output remains in **Logs → World** and crash status remains in **Logs → Crash / macOS Report**.
- No bot-count reduction.
- No speculative C++ source patch yet: frame #0 identifies the failing GameObject lambda, but the caller frames are still needed to patch the correct lifetime/null-pointer path safely.

# v1.5.60 — Live LLDB Crash Capture

The previous release confirmed that macOS is producing neither a matching `.ips` report nor a core dump on this machine.

- TBC `mangosd` now launches directly under LLDB instead of relying on post-crash core files.
- LLDB is configured to stop on `SIGSEGV`, run `thread backtrace all`, then exit.
- Full LLDB output is written to the normal `worldserver.log`, which is already visible in **Logs → World**.
- The Crash log also records that LLDB live capture was active and points to the World log.
- World stdin is passed to the debugged target via `/dev/stdin` so WoWCC can continue sending console commands.
- No hidden logs were added.
- Bot population is not lowered again.

This is intentionally a diagnostic build. Running under LLDB can add overhead, but it should finally capture the crashing thread and C++ stack even when macOS crash reporting/core dumps are unavailable.

# v1.5.59 — Native LLDB Crash Backtrace

The latest crash still ended in SIGSEGV at about 118 live bots, and macOS did not create a matching `.ips` DiagnosticReports entry.

- TBC World now launches through a tiny `zsh` `exec` wrapper that requests unlimited core dumps for that process only.
- `exec` preserves the World process PID and stdin behavior.
- After an unexpected signal crash, WoWCC still checks macOS DiagnosticReports.
- WoWCC also searches for a fresh native `core`/`core.*` file and automatically runs LLDB `thread backtrace all` against the exact installed `mangosd` binary.
- LLDB output is appended to `world-crash.log` and therefore appears directly in **Logs → Crash / macOS Report**.
- No new hidden diagnostic log is introduced; all diagnostics remain available in the UI.
- If macOS refuses to produce a core file, the Crash UI explicitly records that fact.
- Keeps the existing PlayerBots Safe Mode and preserves all RNDBOT accounts/characters.

This release does not lower the bot count again. Repeated crashes at 380, 208, 131, and 118 bots show that population alone is not the root cause.

# v1.5.58 — All Logs in UI

- Replaces the fixed Logs picker with a complete log catalog.
- Adds World, Crash / macOS Report, Auth, MySQL, Installer, Core Build, and CMake Configure logs directly to the UI.
- Automatically discovers additional `.log` files in the selected profile's Logs folder and the WoWCC runtime folder, so future logs appear without another hard-coded picker change.
- Log switching refreshes immediately.
- Increases displayed tail size to 120 KB for useful native crash reports and build diagnostics.
- Missing logs show their expected path instead of silently leaving stale text on screen.
- Keeps v1.5.57 native macOS crash-report capture and v1.5.55 PlayerBots Safe Mode.

# v1.5.57 — macOS Native Crash Report Capture

- Keeps **Logs → Crash** in the WoWCC UI.
- After an unexpected `mangosd` signal crash, waits 3 seconds for macOS to write its native diagnostic report.
- Searches `~/Library/Logs/DiagnosticReports` and `/Library/Logs/DiagnosticReports` for the newest matching `mangosd` `.ips` or `.crash` report.
- Appends that native report directly to `world-crash.log`, so **Logs → Crash** can expose the crashed thread and native stack frames.
- Limits the appended native report to 120 KB.
- Keeps the existing PlayerBots Safe Mode configuration and preserves all bot characters.

Repeated crashes at progressively lower bot populations still ended in SIGSEGV 11, so this release stops guessing from population count and captures the native crash location.

# v1.5.56 — Crash Log in UI

- Adds **Crash** directly to the Logs picker.
- Displays `world-crash.log` inside WoWCC; no Finder or Terminal lookup is needed.
- Automatically refreshes the log view when switching between World, Crash, Auth, and MySQL.
- Shows a clear message when no World crash has been recorded yet.
- Keeps the v1.5.55 PlayerBots Safe Mode settings and all previous crash diagnostics.

# v1.5.55 — PlayerBots Safe Mode

The server still stopped at roughly 208 live bots, so the previous 250-bot cap was still too aggressive.

- Lowers the simultaneous TBC random-bot safety cap to 150.
- Reduces bot login rate to 1 per interval.
- Slows the PlayerBots manager update interval to 5000 ms.
- Reduces `botActiveAlone` to 5.
- Keeps bot optimizations and activity priorities enabled.
- Keeps timed logout/offline disabled.
- Preserves all existing RNDBOT accounts and characters.
- Keeps `world-crash.log` diagnostics enabled.

After installing, run PlayerBots → Populate / Repair World once, then restart World.

# v1.5.54 — PlayerBots SIGSEGV Stability Fix

The v1.5.53 crash recorder confirmed a genuine `mangosd` uncaught signal 11 (SIGSEGV) while the live PlayerBots population was climbing.

- Caps simultaneous TBC random bots at 250 while preserving all existing RNDBOT accounts/characters.
- Re-enables PlayerBots' normal bot optimizations (`DisableBotOptimizations=0`).
- Re-enables activity-priority behavior (`DisableActivityPriorities=0`).
- Reduces `botActiveAlone` from 20 to 10.
- Staggers login pressure further: max logins per interval 5 → 2.
- Slows the random-bot manager update interval from 2000 ms → 3000 ms.
- Keeps timed logout/offline disabled and keeps the population count stable.
- Keeps v1.5.53 `world-crash.log` SIGSEGV diagnostics.
- Does not delete or recreate the existing 1008 bot characters.

After installing, use PlayerBots → Populate / Repair World once so the new runtime configuration is written, then restart World.

# v1.5.53 — Swift 6 Crash Diagnostics Build Fix

- Fixes the production-build error caused by `Process.terminationHandler` being `@Sendable` under the current Swift compiler.
- Marks the process wrapper `@unchecked Sendable` and protects the cross-thread termination summary with `NSLock`.
- Cleans the unused `try? seekToEnd()` warning in the crash logger.
- Keeps the v1.5.52 `world-crash.log` diagnostics unchanged.
- Existing SwiftUI deprecation and URLSession capture diagnostics remain warnings only.

# v1.5.52 — World Crash Diagnostics

- Adds a persistent `world-crash.log` beside the World log.
- Records every mangosd launch with PID and executable path.
- Records process termination timestamp, PID, termination reason, termination status/signal, and whether WoWCC intentionally stopped it.
- Captures macOS/Unix signal exits even when CMaNGOS writes no fatal line to its normal log.
- Dashboard status now surfaces the captured termination record when TBC World dies unexpectedly.
- Keeps the 1.5.51 stable PlayerBots behavior and does not auto-restart TBC into an initialization loop.

# v1.5.51 — Stable PlayerBots Population

- Fixes the bot drop → initialize → drop loop.
- Explicitly disables `RandomBotTimedLogout` and `RandomBotTimedOffline`.
- Keeps Min/Max bot population fixed and pushes automatic population-count changes to a one-year interval.
- Reduces bot login burst from 25 to 5 per interval.
- Disables `InstantRandomize` to avoid unnecessary rerandomization churn.
- Sets the random-bot manager update interval to 2000 ms for a gentler workload.
- **Initialize Bots is now one-shot**: it sends `rndbot init` only and no longer forces `rndbot update` one second later.
- TBC PlayerBots World is no longer automatically relaunched by the WoWCC watchdog after a genuine `mangosd` exit, preventing crash → startup cache → bot init loops.
- A transient port-8085 probe still cannot stop a live `mangosd` process.
- Existing RNDBOT accounts/characters are preserved.

# v1.5.50 — True TBC Mount / Fly Anywhere Fix

- Fixes flying mounts that still refused to work in Orgrimmar/Azeroth.
- Extends mount detection beyond `SPELL_AURA_MOUNTED` to the TBC flying/flying-speed aura components used by triggered mount spells.
- Patches `SpellMgr::GetSpellAllowedInLocationError` so mount-family spells bypass AreaId, Outland-only flying-area, and `spell_area` location restrictions.
- Keeps normal battleground/arena restrictions and other spell safety checks.
- Preserves the existing `SetCanFly()` hook so flying mounts can actually lift off on Azeroth after the cast succeeds.
- Requires **Rebuild / Apply Patches** because this changes the CMaNGOS TBC core.

# v1.5.49 — World Process Persistence / PlayerBots Watchdog

- Fixes false World "Stopped" state under heavy PlayerBots load: an app-owned live `mangosd` process now wins over a transient failed port-8085 probe.
- WoWCC no longer treats a brief TCP probe failure as proof the World process is dead.
- Adds a TBC World watchdog: after the user starts World, WoWCC automatically recovers `mangosd` if it truly exits unexpectedly while MySQL + Realm remain available.
- Auto-restart is bounded to 3 attempts in 2 minutes to avoid an infinite crash loop.
- Explicit Stop World / Stop All always disables the watchdog, so user-requested shutdowns stay stopped.
- Intentional Restart World suppresses the watchdog during shutdown and re-enables it on start.
- Same-value expansion UI assignments no longer call `stopAll()`.
- Startup timeout/errors no longer flip World to stopped if `mangosd` is demonstrably still alive.
- Preserves 1.5.48 runtime PlayerBots config synchronization and long first-start initialization handling.

# v1.5.48 — PlayerBots Startup / Runtime Config Fix

- TBC PlayerBots-aware World startup timeout increased from 30 seconds to 15 minutes.
- WoWCC no longer reports a false port-8085 failure while mangosd is alive and building PlayerBots caches.
- Startup status now reports PlayerBots initialization/cache progress while waiting.
- World startup fails early only if mangosd actually exits; its log tail is included.
- Runtime `etc/aiplayerbot.conf` is automatically synchronized from WoWCC `configs/aiplayerbot.conf` immediately before every TBC World launch.
- Runtime Config diagnostics accept and inspect both the managed config and the actual CMaNGOS runtime copy.
- Keeps explicit PlayerBots SQL migrations, live online counters, 5,000-bot ceiling, individual server controls, Fly Anywhere and Dual-2H patches.

# v1.5.47 — PlayerBots Runtime Fix

- Fixes the macOS/Linux PlayerBots config location: aiplayerbot.conf is now synchronized to the profile's compiled SYSCONFDIR (`etc`) as well as WoWCC `configs`.
- Replaces the previous `InstallFullDB.sh -World` assumption with explicit, expansion-safe PlayerBots module SQL application.
- Adds a migration ledger so PlayerBots SQL is not blindly reapplied on every repair.
- Adds live diagnostics for Runtime Config and applied Bot SQL.
- Adds Initialize Bots, which sends `rndbot init` followed by `rndbot update` to the live CMaNGOS world console.
- Live bot counters refresh after World Server starts.
- Keeps the 5,000-bot configurable ceiling and player-character filtering from 1.5.46.

# v1.5.46 — Live PlayerBots + Character Visibility

- PlayerBots now supports a configured target up to 5,000.
- Adds live database counters: RNDBOT accounts, bot characters, and bots online now.
- Adds Refresh Live button.
- Characters page explicitly shows player-created characters and excludes RNDBOT population.
- Character reload continues to query the selected expansion's live character database.
- PlayerBots account sizing updated for larger populations.
- Preserves 1.5.45 individual World/Realm/MySQL controls and 1.5.44 gameplay patches.

# v1.5.45 — Individual Server Controls

- Dashboard now has independent Start / Stop / Restart controls for World Server.
- Adds independent Realm Server controls.
- Adds managed MySQL controls.
- Restart World leaves Realm and MySQL running, ideal after PlayerBots/config changes.
- MySQL Stop/Restart is guarded while Realm or World is running.
- Preserves Fly Anywhere, PlayerBots and Dual-2H changes from 1.5.44.

# v1.5.44 — Fly Anywhere + Live PlayerBots

- Adds actual flying-mount flight mode across Azeroth and Outland.
- Strengthens PlayerBots auto-create, startup login and always-active world behavior.
- Uses upstream RNDBOT prefix consistently and reports existing bot account/character counts during setup.
- Retains Dual-2H, Mount Anywhere, PlayerBots and the 1.5.43 build fix.

# v1.5.43 — Complete TBC Dual-2H Equip Path Fix

- Patches the missing `ViableEquipSlots` free-slot gate at the start of the equip path.
- Warriors with Dual Wield now pass viable-slot selection, 2H offhand validation, main/offhand 2H validation, and offhand auto-unequip handling.
- Keeps PlayerBots and Mount Anywhere from 1.5.41.
- Strict source matching remains enabled so upstream changes fail safely.

# v1.5.43 — PlayerBots / Living TBC World

- Dedicated PlayerBots page.
- TBC core rebuild fetches official `cmangos/playerbots` into `src/modules/Bots`.
- TBC compiles with `BUILD_PLAYERBOTS=ON` while retaining dual-2H and mount-anywhere patches.
- One-click Populate / Repair World for an existing TBC realm using `PLAYERBOTS_DB=YES`.
- Managed `aiplayerbot.conf`, default 150 bots, level 1-70, maps 0/1/530.
- Presets 50/100/150/250/500 and custom 10-1000.
- Toggles for bot population, BG/Arena participation and autonomous questing.
- Enables grouping, raids, guild formation, gear upgrading and RPG activity.
- Existing realm databases, accounts, characters and external client are preserved.

# v1.5.40 — TBC Patch Matcher Fix



- Fixed Repair/Rebuild failing on CMaNGOS Player.cpp due to exact whitespace/text matching.

- Dual-2H and mount-anywhere patching now matches the current CMaNGOS code structurally and tolerates indentation/comment changes.

- Still fails safely if the actual equipment or mount logic changes incompatibly.



# v1.5.40 — Core Repair / Rebuild Button

- Setup Guide Step 3 no longer becomes actionless after the core is installed.
- Installed TBC now shows **Rebuild / Apply Patches** next to the green Done state.
- The button reruns the maintained TBC core install/build pipeline, which resets/updates source, reapplies the WoWCC dual-2H + mount-anywhere patches, rebuilds mangosd/realmd, and installs the rebuilt binaries.
- Expansion Manager and Settings now use the same repair/rebuild wording when a maintained core is already installed.
- Realm databases, accounts, characters, selected client, and extracted client data are not deleted by this action.

# v1.5.38 — TBC Dual-2H + Mount Anywhere Core Patches

- CMaNGOS TBC Warriors with Dual Wield can equip a 2H weapon in both hands.
- Other classes keep stock TBC equipment rules.
- Prevents the stock auto-unequip path from removing the Warrior's second 2H.
- Actual mount-aura spells bypass spell-specific zone/area and map mount checks.
- Ordinary spell/quest/encounter location restrictions remain unchanged.
- Water, transport and shapeshift mount safety checks remain enabled.
- Patches are automatically reapplied after every TBC source update/reset.
- Patch matching is strict: if upstream changes the relevant code, the build
  stops instead of silently producing an unpatched server.
- IMPORTANT: run Install/Repair Core for TBC after updating WoWCC so mangosd is
  rebuilt with these source-level changes.

# v1.5.37 — TBC Character / Give / Gear Set Adapter

Fixes the TBC admin actions that were still using AzerothCore-only commands.

CMaNGOS TBC changes:
- Set Level now uses the console-safe native command:
  `character level <character> <level>`
- TBC level input is clamped to 1–70; Vanilla to 1–60.
- Individual Give uses CMaNGOS `send items` with an explicit character name.
  This works from the server console and for offline characters.
- TBC mount entries deliver the actual mount-teaching item; the player uses it
  to learn the mount. This avoids the non-console-safe CMaNGOS `.learn` target
  command.
- Give Custom Item uses the same CMaNGOS mail adapter.
- Give Full Set now sends all set pieces through `send items`, chunked at
  12 item stacks per mail as required by CMaNGOS.
- Custom Learn Spell for CMaNGOS works for offline characters by inserting the
  spell into `characters.character_spell`; it becomes active at next login.
  Online characters are intentionally refused to avoid live-session state
  corruption.
- WotLK/AzerothCore behavior remains unchanged.

# v1.5.36 — CMaNGOS Database Config Fix

Fixes TBC `realmd` startup failure:
`Unknown database 'tbcrealmd'`

Root cause:
- Setup created the managed databases as `realmd`, `characters`, `mangos`,
  and `logs`.
- The copied CMaNGOS example/runtime config could still contain expansion-
  prefixed database names such as `tbcrealmd`, `tbcmangos`,
  `tbccharacters`, and `tbclogs`.
- The previous regex only replaced one very specific default connection string,
  so those names survived into `realmd.conf` / `mangosd.conf`.

Fixes:
- Setup/Repair now force-writes exact CMaNGOS database connection settings:
  - realmd LoginDatabaseInfo -> realmd
  - mangosd LoginDatabaseInfo -> realmd
  - mangosd WorldDatabaseInfo -> mangos
  - mangosd CharacterDatabaseInfo -> characters
  - mangosd LogsDatabaseInfo -> logs
  - host 127.0.0.1, port 3307, user/password wowcc/wowcc
- Setup verifies the written config and refuses success if any stale TBC DB
  name remains.
- Start Realm now performs a lightweight runtime self-heal of CMaNGOS config
  files before launching realmd/world, so an existing 1.5.35 profile does not
  require a full database rebuild just to repair this mismatch.
- Existing databases/accounts/characters are preserved.

# v1.5.35 — Expansion-Aware Account Adapter

- Fixed Accounts UI being hard-coded to the AzerothCore console adapter.
- WotLK/AzerothCore keeps:
  `account create <user> <pass>`
  `account set gmlevel <user> <level> -1`
- Vanilla/TBC CMaNGOS now uses its native console syntax:
  `account create <user> <pass>`
  `account set gmlevel <user> <level>`
- TBC automatically runs:
  `account set addon <user> 1`
  so newly-created accounts can access Burning Crusade content.
- Account creation now requires the World Server to be running because these
  are live core-console commands.
- Added username/password validation to prevent whitespace/control characters
  from becoming accidental console command tokens.
- Accounts page shows which adapter is active for the selected expansion.
- Account list reloads after the command sequence finishes.

# v1.5.34 — TBC Client Root / Container Mount Fix

Root cause of:
`[cmangos-deploy]: ERROR: Client data not found in '/opt/cmangos/storage/client-data'`

- cmangos-deploy requires the contents of the actual WoW client root to appear
  directly inside `/opt/cmangos/storage/client-data`.
- 1.5.33 mounted the user-selected path directly, which could be an executable,
  wrapper folder or parent directory instead of the actual TBC client root.

Fixes:
- Automatically locates the client root by finding a direct `Data/` directory.
- Handles selecting `Wow.exe` by using its parent directory.
- Searches up to three levels below a selected wrapper/parent folder.
- TBC requires both `Data/` and a WoW executable before Docker can start.
- Shows the detected client root in the installer log.
- Creates a managed `extractor-client-data` staging directory whose root
  exactly matches cmangos-deploy's documented layout.
- Uses APFS clone-copy (`cp -cR`) when available, with normal copy fallback.
- Validates staged `Data/` and WoW executable before starting the container.
- Docker mounts the validated staging directory directly at
  `/opt/cmangos/storage/client-data`.
- Extracted output still goes only to the managed TBC profile DataDir.

# v1.5.33 — Local TBC Extractor on Apple Silicon

- Adds a local Apple Silicon extraction path for CMaNGOS TBC/Vanilla.
- New Setup Guide button: `Install Local TBC Extractor Engine`.
- The engine installs Docker CLI + Colima through Homebrew only when requested.
- Colima prefers Virtualization.framework + Rosetta when available and falls
  back to normal foreign-architecture emulation when needed.
- Prepare Client Data automatically uses the maintained amd64 CMaNGOS server
  image when native ARM extractors are unavailable.
- TBC image: `ghcr.io/mserajnik/cmangos-server-tbc`.
- Classic image: `ghcr.io/mserajnik/cmangos-server-classic`.
- Client directory is mounted read-only; extracted dbc/maps/vmaps are written
  directly to the managed profile DataDir.
- Keeps manual `Import Extracted TBC Data…` as a fallback.
- No second Windows/x86_64 computer is required if the local container engine
  is available.
- Extraction can take a long time under amd64 emulation.

# v1.5.32 — TBC Client Data Fix

- Fixed TBC Prepare Client Data falsely appearing complete when no CMaNGOS
  extractor output had actually been created.
- TBC/Vanilla now validate real dbc/maps/vmaps files.
- When CMaNGOS `ad`, `vmap_extractor`, and `vmap_assembler` are available,
  Prepare runs the official extraction sequence automatically.
- On Apple Silicon, the app now reports the upstream ARM extractor limitation
  explicitly instead of silently continuing.
- Added `Import Extracted TBC Data…` in Setup Guide for data extracted on an
  x86_64/Windows machine.
- Imported data is copied into the managed TBC DataDir and validated.
- Original WoW client files are never deleted.
- 1.5.31 background service-status behavior is preserved.

# v1.5.31 — Async Service Status Fix

Fixes status indicators without bringing back the Settings/sidebar lag.

- MySQL, Auth and World listener checks now run on a utility background queue.
- No `lsof`, `Process.waitUntilExit()` or MySQL query runs in SwiftUI rendering
  or on the MainActor status path.
- Realm DB readiness is checked in the background every 15 seconds while MySQL
  is listening.
- App-owned processes are promoted to online immediately; external/already
  running services are discovered by the background probe.
- Bottom status bar and left Realm Online/Offline indicator use the same
  `mysqlRunning`, `realmDatabaseReady`, `authRunning`, and `worldRunning` cache.
- Status refresh starts immediately when the app opens and then every 5 seconds.
- Expansion changes discard stale background results so TBC/WotLK status cannot
  bleed into one another.
- TBC DB readiness checks `realmd.account`, `realmd.realmlist`,
  `characters.characters`, `mangos.item_template`, and
  `mangos.creature_template`.

# v1.5.30 — TBC Setup Bash `set -u` Fix

Fixes the confirmed TBC Setup/Repair failure:
`setup-profile.sh: line 129: file: unbound variable`.

Cause: a Bash `local` declaration assigned `file` and used `$file` to build
`sql` in the same command while the script runs with nounset (`set -u`).
Bash expands the right-hand side before the local assignment is established.

Changes:
- Split `file`, `db`, `sentinel`, and `sql` into separate local assignments.
- The SQL path now uses `${file}` only after `file` is initialized.
- Preserves the 1.5.29 idempotent TBC database repair behavior.
- Existing realmd accounts and characters are not deleted.

# v1.5.29 — TBC Database Repair / Readiness Fix

- CMaNGOS base SQL is now idempotent: Setup/Repair skips a base database when
  its sentinel table already exists instead of importing the same CREATE TABLE
  statements again.
- Fixes repeated TBC `ERROR 1050 ... Table reference_loot_template_names
  already exists` failures caused by re-importing an existing world schema.
- If the `mangos` world schema is genuinely incomplete, Setup rebuilds only the
  world database; `realmd` accounts and `characters` are preserved.
- TBC/Vanilla `InstallFullDB.sh` is now called explicitly with `-World` rather
  than entering its interactive menu.
- Setup verifies realmd.account, realmd.realmlist, characters.characters,
  mangos.item_template and mangos.creature_template before declaring success.
- CMaNGOS setup now writes `.realm-db-ready` and prints `REALM DATABASE READY`.
- `startMySQL()` immediately updates the app's MySQL-ready state when port 3307
  is reachable.
- Realm readiness now asks MySQL directly instead of first depending on the
  potentially stale UI `mysqlRunning` flag / listener probe.

# v1.5.28 — TBC Collections / Expansion Filter Reset

Fixed a cross-expansion Collection Browser bug. Collection filters were shared
between WotLK and TBC, so a WotLK Min iLvl / quality / class / slot filter could
make every TBC category return zero rows even though `mangos.item_template` was
populated.

Changes:
- Switching expansion clears Collection Browser search, quality, class, slot and
  minimum item-level filters.
- Clears old catalog pages and results from the previous expansion.
- Resets Collection to All Items for the newly selected expansion.
- Clears cached Gear Sets and class filter when changing expansion.
- Mount Collection always clears hidden class/slot/min-iLvl filters before load.
- Keeps the 1.5.27 direct DB loaders and 1.5.26 UI performance changes.
- Confirmed current CMaNGOS TBC schema uses `mangos.item_template` with the core
  fields required by the browser (`entry`, `name`, `Quality`, `class`,
  `subclass`, `InventoryType`, `AllowableClass`, `ItemLevel`, `itemset`).

# v1.5.27 — Collections Restore

Regression fixed from 1.5.26:
the performance work intentionally stopped synchronous external service probing,
but Collection Browser and Gear Sets still used `mysqlRunning` as a hard gate.
After reopening the app, an already-running MySQL instance could therefore be
available while the cached UI flag remained false, causing Load to return
before attempting any SQL query.

Fixes:
- Collection Browser no longer blocks on the cached `mysqlRunning` UI flag.
- All Items, Raid Sets, Weapons, Armor, Legendaries, BiS/Endgame, Bags and
  Mounts now attempt the real database query directly.
- Gear Sets no longer blocks on the cached UI flag.
- Successful catalog/gear DB access marks MySQL as available.
- Characters and Accounts likewise attempt their real DB query instead of
  refusing solely because of stale presentation state.
- Keeps the 1.5.26 performance architecture: no global lsof/MySQL/log work in
  the periodic UI refresh and no return of sidebar/Settings lag.

# v1.5.26 — UI / Sidebar / Settings Performance Fix

Performance cause:
the shared ServerModel timer ran every 1.5 seconds on the MainActor and the old
refresh path performed listener checks, realm DB probing, and log reads. Those
published changes invalidated the whole SwiftUI window and could make sidebar
navigation and Settings feel slow.

Changes:
- Global refresh interval increased from 1.5s to 5s.
- Periodic refresh now checks only app-owned ManagedProcess state.
- Periodic refresh no longer runs lsof/port probes.
- Periodic refresh no longer queries MySQL.
- Periodic refresh no longer reads logs from disk.
- Published service flags update only when their value actually changes.
- Logs load only when the Logs page opens or Refresh Log is clicked.
- Settings no longer performs LAN IP discovery when opened.
- This Mac Only / Home Network switch no longer performs IP discovery and
  should respond immediately.
- LAN IP is cached per expansion.
- Refresh IP is the explicit network discovery action.
- Apply Network Settings uses the cached IP and keeps DB work away from the
  navigation/render path.

# v1.5.25 — Confirmed Settings Main-Thread Crash Fix

Crash report path:
`ContentView.settings` → `lanAuthListening` → `ServerModel.portOpen()` →
`Process.waitUntilExit()` → main CFRunLoop → `EXC_BAD_ACCESS / SIGSEGV`.

Fixes:
- Settings no longer calls `portOpen()` from SwiftUI computed properties.
- Auth/World indicators use `authRunning` / `worldRunning`.
- Apply no longer probes MySQL with `portOpen()` on the main thread.
- LAN IP detection no longer launches route/ipconfig subprocesses.
- LAN IP detection now uses `Host.current().addresses`, preferring RFC1918
  home-network IPv4 addresses.
- Database update work remains in the background worker from 1.5.24.
- MySQL remains local-only on 127.0.0.1:3307.

# v1.5.24 — Confirmed LAN Apply Actor Crash Fix

Crash report diagnosis:
`_swift_task_checkIsolatedSwift` → `ServerModel.locateMySQL()` →
`ServerModel.dbClient()` → background dispatch queue.

This was a real MainActor isolation violation and produced SIGTRAP /
EXC_BREAKPOINT on macOS.

Fixes:
- Resolves the MySQL executable, port, expansion database, LAN address and
  UserDefaults key on the MainActor before starting background work.
- Background LAN Apply never calls `ServerModel.dbClient()`,
  `ServerModel.locateMySQL()`, `ServerModel.err()`, `profileKey()`, or any
  other MainActor-isolated ServerModel method.
- Background work constructs `DatabaseClient` directly from immutable captured
  values.
- Error objects are created directly in the worker rather than through
  ServerModel.
- All UI/model mutations return to DispatchQueue.main.
- Retains schema validation, dedicated non-query execute(), address
  verification, Applying… state, and MySQL localhost-only behavior.

# v1.5.23 — LAN Apply Crash-Safe Fix

- Reworks `Apply Network Settings` to avoid fragile synchronous UI work.
- Adds a dedicated DatabaseClient `execute()` path for UPDATE statements.
- Applies LAN database changes on a background queue.
- Validates that the selected realm database and `realmlist` table exist before
  making changes.
- Detects the actual `address` / `localAddress` columns before building UPDATE.
- Verifies the realm address after the database update.
- Any database/schema problem now returns a status message instead of being
  allowed to propagate through the Settings UI.
- Removes the NSOrderedSet interface-deduplication cast from LAN IP detection.
- Removes force-unwrapped IPv4 parsing.
- Excludes invalid self-assigned `169.254.x.x` addresses.
- Adds Applying… progress state and prevents double-clicking Apply.
- MySQL remains local-only on 127.0.0.1:3307.

# v1.5.22 — Home Network / LAN Settings

- Adds Settings → Network / LAN Access.
- Two modes: `This Mac Only` and `Home Network`.
- Automatically detects the Mac's primary LAN IPv4 address.
- Shows the exact Windows WoW client line: `set realmlist <Mac-IP>`.
- Adds `Copy realmlist`, `Refresh IP`, and `Apply Network Settings`.
- Apply updates the selected supported realm database's `realmlist.address`
  and `localAddress` for AzerothCore WotLK, CMaNGOS Vanilla/TBC, and the
  community Trinity-style Cata/MoP profiles.
- Shows whether Auth port 3724 and World port 8085 are currently listening.
- Managed MySQL remains bound to localhost (`127.0.0.1:3307`) and is never
  exposed to the home network.
- LAN mode is stored separately for each expansion profile.
- Existing mount, tooltip, collection and character/Give fixes remain.

# v1.5.21 — Mount Collection Fix

- Fixes Mounts showing ordinary gear.
- Mount queries now require `InventoryType = 0`.
- Weapon and armor classes are excluded.
- Expanded TBC/WotLK mount item name matching.
- Mounts auto-load in mount-only mode and clear class/slot restrictions.
- Class, slot and minimum item-level filters are hidden on Mounts.

# v1.5.20 — Tooltip + Create Character Fix

- Removes the native macOS `.help(...)` tooltip from item cards.
  This fixes the second delayed black/white tooltip that appeared after
  keeping the mouse over an item.
- Only the custom WoW-style floating tooltip remains.
- When no character is available/selected, item actions now say exactly
  `Create Character`.
- `Give`, per-item set actions, and `Give Full Set` route to the Characters
  page as `Create Character` until a character is available.
- Once a character is selected, the normal `Give` / `Give Full Set` actions
  are shown again.
- Existing tooltip panel remains non-interactive (`ignoresMouseEvents = true`)
  so it cannot block Give buttons.

# v1.5.19 — Give Button / Tooltip Interaction Fix

- Tooltips are now attached only to the item-information area of a card.
  The action row containing Give / Give Full Set is tooltip-free.
- Hovering the action row explicitly closes the floating tooltip.
- The floating macOS tooltip panel keeps `ignoresMouseEvents = true`, so it
  cannot intercept clicks even if it visually overlaps another control.
- `Give` is no longer shown as a dead disabled button when no target character
  exists. It becomes `Create / Select Character` and opens the Characters page.
- The Collection header also shows an actionable `No character selected` button.
- Once a character is selected, the action automatically becomes `Give`.
- Gear Set per-item actions follow the same target-character behavior.
- `Give Full Set` also routes to Characters when no target is selected.
- All v1.5.18 loading-queue, icon, tooltip, class-filter and Raid/PvP features remain.

# v1.5.18 — Catalog / Icon Loading Queue Fix

- Fixes item cards that could remain on `Loading` indefinitely.
- Replaces the previous burst of up to 250 simultaneous icon lookups with a
  bounded queue (maximum 6 icon requests at once).
- Tooltip network lookups use a separate bounded queue (maximum 4 at once).
- Adds strict request timeouts so unavailable Wowhead/CDN responses cannot keep
  a card spinning indefinitely.
- Adds failed-ID caches. A failed icon/tooltip is not automatically retried on
  every SwiftUI redraw.
- Failed icons immediately fall back to the local generic item symbol.
- Adds `Retry Icons` for explicitly retrying failed icons.
- Shows live icon-loading and unavailable counts.
- Cancels pending icon/tooltip work when the catalog is cleared or switched,
  preventing stale loading indicators from old pages.
- Catalog item data remains independent from icon/tooltip loading: items render
  immediately even when remote artwork is unavailable.
- Existing floating tooltip panel, class filters and full Raid/PvP browsing remain.

# v1.5.17 — WoW Tooltip Floating Panel Fix

- Replaces the clipped SwiftUI card overlay tooltip with a dedicated macOS
  floating `NSPanel`.
- Tooltip now renders above ScrollView/LazyVGrid content instead of being clipped
  by collection cells.
- Panel follows the mouse and automatically stays inside the visible screen.
- Supports long tooltips up to 620 px high with internal scrolling.
- Non-activating and ignores mouse events, so it does not steal focus or break
  item-card hovering.
- Live-updates when the full Wowhead tooltip finishes loading.
- Keeps WoW quality border colors and offline DB tooltip fallback.
- All class filters, full Raid/PvP sets, item icons and Give actions remain.

# v1.5.16 — WoW Tooltips, Class Filters, Full Raid/PvP Sets

- Adds WoW-style hover tooltips to Collection Browser and Gear Set item cards.
- Uses expansion-specific Wowhead XML `htmlTooltip` data when available for
  damage, speed, armor, stats, requirements, equip/use effects and set bonuses.
- Keeps a database-derived tooltip as an offline fallback.
- Adds class filtering using the real `AllowableClass` bitmask from `item_template`.
- Adds the same class filter to Gear Sets.
- TBC hides Death Knight; WotLK includes Death Knight.
- Gear Sets now exposes All Sets, Raid / PvE Sets and PvP Sets.
- PvP recognition covers TBC/WotLK arena-season names including Gladiator,
  Merciless, Vengeful, Brutal, Furious, Relentless and Wrathful.
- Every DB-defined `itemset` remains visible; no two-piece minimum.
- Per-item Give and Give Full Set remain available.

# v1.5.15 — Complete Item Icons

- Adds automatic item icon resolution for the Complete Collection and Gear Sets.
- TBC items use the TBC Wowhead item endpoint; WotLK items use the WotLK endpoint.
- Resolves each item ID to its real WoW icon name and downloads the corresponding
  image from the Wowhead/ZAM icon CDN.
- Icons are cached permanently under the app's Application Support cache, so
  previously loaded pages do not need to download them again.
- Resolves only the visible catalog page to avoid flooding the network when the
  database contains tens of thousands of items.
- Shows a small loading spinner while an icon is being resolved.
- Keeps an SF Symbol fallback if an item has no available remote icon or the Mac
  is offline.
- Gear Set item cards use the same real-icon cache.
- All v1.5.14 Complete Collection functionality remains included.

# v1.5.14 — Complete TBC / WotLK Collection Browser

- Reworks Items & Gear into a Complete Item Collection browser.
- Adds full database-backed collections for:
  - Raid Sets
  - Weapons
  - Armor
  - Legendaries
  - BiS / Endgame candidate pool
  - All Items
  - Mounts
- No curated short list is required for browsing. Data comes directly from the
  selected expansion's `item_template` database.
- Adds filters for quality, equipment slot, minimum item level, name and item ID.
- Keeps paged loading so very large WotLK/TBC item tables do not freeze the UI.
- Every item card has a Give button targeting the selected character.
- Gear Sets now loads every DB-defined `itemset` without requiring two or more pieces.
- Gear Set detail keeps Give Full Set and per-piece Give actions.
- Mount discovery is expanded with DB classification plus common mount-item naming patterns.
- Character Creation, TBC ICU, MoP and Cata fixes remain included.

# v1.5.13 — TBC CMaNGOS ICU / Real CMake Branch Fix

- Fixes a v1.5.12 installer bug: the TBC dependency overrides had been placed
  in the community-core branch and therefore were never executed for CMaNGOS.
- Updates the actual Vanilla/TBC CMaNGOS configure branch.
- Adds ICU to managed build dependencies. Current CMaNGOS requires ICU
  (`uc`, `i18n`, `data`) on macOS.
- Explicitly passes Homebrew roots for Boost, ICU, OpenSSL 3 and MySQL.
- Exports BOOST_ROOT / BOOST_LIBRARYDIR and package/compiler/linker paths.
- Uses native arm64 and disables unsupported CMaNGOS extractors on Apple Silicon.
- TBC/Vanilla CMake now writes a configure log and surfaces the real
  `Could NOT find ...` / `NOTFOUND` package diagnostics.
- All Cata, MoP and Character Creation fixes remain included.

# v1.5.12 — Burning Crusade CMake Dependency Fix

- Fixes TBC/CMaNGOS CMake dependency discovery on modern Homebrew/macOS.
- Explicitly provides Homebrew paths for:
  - Boost
  - OpenSSL
  - GNU Readline
  - MySQL client
  - zlib when available
- Supplies `CMAKE_PREFIX_PATH`, package roots, compiler include paths and linker paths.
- Uses native `arm64` CMake target on Apple Silicon.
- Adds a persistent per-profile CMake configure log.
- If configure fails, the installer now surfaces the actual missing package /
  `NOTFOUND` lines and the last 40 CMake lines instead of only the generic
  `FindPackageHandleStandardArgs.cmake` failure.
- Existing Cata, MoP and Character Creation fixes remain included.

# v1.5.11 — MoP ObjectMgr Unicode / Apple Clang Fix

- Fixes MoP compile failures in `src/server/game/Globals/ObjectMgr.cpp`:
  - `wide character literals may not contain multiple characters`
- The affected source is the Russian declined-name logic in the 5.4.8 core.
- Replaces the four broken doubly-mojibaked single-character literals with
  encoding-independent Unicode escapes:
  - `ь` -> `U+044C`
  - `е` -> `U+0435`
  - `о` -> `U+043E`
  - `ё` -> `U+0451`
- The declined-name functionality is preserved; it is not disabled or commented out.
- Patch runs automatically after each MoP clone/update and verifies that no
  known invalid literal remains.
- All previous MoP Apple Silicon/OpenSSL and Cata compatibility fixes remain.
- Character Creation from v1.5.10 remains included.

# v1.5.10 — Character Creation Restored

- Restores a dedicated Character Creation panel in the Characters section.
- Available for every expansion profile.
- Expansion-aware race lists:
  - Vanilla
  - TBC
  - WotLK
  - Cataclysm
  - Mists of Pandaria
  - later custom/experimental profiles
- Expansion-aware class lists including Death Knight, Monk and Demon Hunter where appropriate.
- Account selector is populated from the selected realm's account database.
- Character name, race, class and gender are kept in the creation panel.
- `Open Character Creator` starts the selected realm/client so the core creates all
  required character rows, starting spells, items and homebind correctly.
- Reload now refreshes accounts and characters together.
- Package root is renamed to the actual current version instead of the stale 1.4.3 folder name.

# v1.5.9 — MoP Apple Silicon Core Fix

- Replaces ProjectSkyfire/SkyFire_548 as the default MoP core on this app path.
  Current SkyFire main targets x86_64/SSE2 and a newer OpenSSL requirement,
  which is a poor fit for native Apple Silicon.
- MoP now uses `brian8544/TrinityCore-5.4.8`, which documents:
  - macOS support
  - AArch64 support
  - WoW 5.4.8 build 18414
  - OpenSSL 3.x support
- Installer detects when the existing profile source points at the old upstream
  and automatically replaces source/build only.
- Realm runtime data, database data and selected game client are preserved.
- MoP CMake is explicitly configured with Homebrew OpenSSL 3 include/SSL/Crypto
  libraries and native `arm64` on Apple Silicon.
- Minimal CMake retry preserves the same OpenSSL and architecture settings.
- Existing Cataclysm fixes remain unchanged.

# v1.5.8 — Cataclysm Readline Hard Fix

- Fixes persistent `rl_abort`, `rl_done`, `rl_event_hook` undeclared errors.
- No longer relies only on the old Cata fork's CMake Readline discovery.
- Automatically patches `CliRunnable.cpp` to include the exact Homebrew GNU Readline headers found by `brew --prefix readline`.
- Verifies the selected header actually declares all three APIs before building.
- Forces Homebrew Readline include and linker paths at compiler/CMake level.
- Adds runtime rpath for the same Homebrew Readline library.
- Existing Cata ARM64, PCGRand, Argon2 and g3dlite/stat fixes remain enabled.

# v1.5.7 — Cataclysm GNU Readline Fix

- Fixes Cata compile errors in `CliRunnable.cpp`: `rl_abort`, `rl_done`, `rl_event_hook`.
- Forces Cataclysm CMake to use Homebrew GNU Readline instead of macOS/libedit compatibility headers.
- Supplies `READLINE_INCLUDE_DIR`, `READLINE_LIBRARY`, CMake prefix, compiler and pkg-config hints.
- Fallback CMake configure preserves the same Readline paths.
- Existing Apple Silicon and modern macOS Cata patches remain enabled.

# v1.5.6 — Cataclysm g3dlite stat64 Fix

- Fixes modern macOS build failure in `dep/g3dlite/source/FileSystem.cpp`.
- Replaces legacy `struct stat64` with `struct stat`.
- Replaces legacy `stat64()` with `stat()`.
- Patch is applied automatically after every Cata source clone/update.
- Existing Cata Apple Silicon fixes remain enabled.

# v1.5.5 — Cataclysm Native Apple Silicon Build Fix

- Fixes Apple Clang 21 failures in x86 MMX/SSE intrinsic headers on Apple Silicon.
- Cataclysm Argon2 now recognizes both `aarch64` and macOS `arm64`, selecting the portable implementation.
- Cataclysm PCGRand now uses portable 16-byte aligned allocation on ARM64 instead of `_mm_malloc/_mm_free`.
- Compatibility patch is applied automatically after each Cata source clone/update.
- Cata CMake is explicitly configured for native `arm64`.
- The minimal CMake retry also preserves the ARM64 target.
- No Rosetta / Intel Homebrew is required for this native build path.

# v1.5.4 — Gear Sets Fast Loader

- Fixed Gear Sets appearing to load forever.
- Gear Sets now queries ONLY actual DB-defined item sets (`itemset > 0`).
- Removed the huge high-end/BiS scan from Gear Sets startup.
- BiS/Endgame remains fully available in Items & Gear using paged background queries (250 items/page).
- Weapons, armor, legendary items, bags and mounts remain database-driven and paged.
- Added `Open BiS / Endgame` shortcut directly from Gear Sets.
- Gear Sets stays on a background queue and no longer auto-loads just by opening the screen.
- No artificial item-set LIMIT: all actual realm item sets are still loaded.

# v1.5.3 — Swift Build Fix

- Fixed Swift compile error in catalog paging:
  `parsed.first.map { offset + 1 }` -> direct empty/non-empty calculation.
- Removed unused `FileManager` local that produced the warning in cleanup code.
- No functional changes to Gear Sets, catalog paging, mounts, BiS/endgame, client-data fixes, or server startup.

# v1.5.2 — Full Gear Catalog + Gear Sets Performance Fix

- Gear Sets no longer auto-load synchronously when the screen opens.
- Heavy item-set queries run on a background queue so SwiftUI stays responsive.
- Loads every DB-defined `itemset` without an artificial set limit.
- Adds DB-driven BiS/endgame candidate groups for every equipment slot, including weapons and armor.
- BiS/endgame candidates include all high-end epic/legendary equipment above the era threshold; they are candidates because exact theorycrafted BiS varies by class/spec.
- Items & Gear now supports complete database categories: Weapons, Armor, Legendary, BiS/Endgame, Bags.
- Mounts now use the database-native mount item class/subclass (`class=15, subclass=5`) plus compatibility name fallbacks instead of a capped name-only list.
- Full realm catalog browsing is paged (250 rows/page), preventing beachballs while keeping every matching DB item accessible.
- Added Previous/Next paging and background catalog queries.
- Added visible loading indicators and disabled duplicate reload clicks.

# v1.5.1 — WotLK Client Data / World Startup Fix

- Fixed the main reason World Server could exit immediately after database initialization.
- Prepare Client Data no longer hides AzerothCore extractor failures with `|| true`.
- WotLK preparation now requires mapextractor, vmap4extractor, vmap4assembler and mmaps_generator.
- Extraction is staged and each step must succeed.
- Validates real file content in DBC, maps, vmaps and mmaps rather than checking only whether folders exist.
- Start Realm validates server data before launching Auth/World and stops with a precise missing-data message.
- Health Checks now report missing OR incomplete DBC/maps/vmaps/mmaps.
- World/Auth log errors shown in the GUI have ANSI terminal color sequences stripped.
- Existing no-space `~/.wowcc` compatibility path and DB fixes remain in place.

# v1.5.0 — Start Everything / Service Detection Fix

- Dashboard now detects actual Auth and World listeners, even after reopening the GUI.
- World Server is considered online when its real game port (8085) is listening.
- Auth is considered online when port 3724 is listening.
- Start Realm is now staged and verified: MySQL -> Realm DB -> Auth -> World.
- Start Realm waits for each service to become ready instead of assuming launch success.
- If Auth or World exits immediately, the GUI shows the tail of that service log.
- Auth/World binaries and config files launch through `~/.wowcc`, eliminating spaces from paths passed to core config parsers.
- The app creates/repairs the `~/.wowcc` compatibility symlink automatically.
- Existing servers already running outside the current GUI session are reflected correctly on Dashboard.
- Health checks use the same centralized service-port detection.

# v1.4.9 — Setup / Repair Realm Path Fix

- Setup / Repair Realm now uses only the no-space `~/.wowcc/...` path when invoking AzerothCore dbimport.
- Uses explicit `--config ~/.wowcc/runtime/profiles/wotlk/configs/dbimport.conf`.
- Creates and maintains both `configs/dbimport.conf` and `etc/dbimport.conf`.
- The `etc/dbimport.conf` copy covers AzerothCore's compiled-in fallback config lookup.
- Both dbimport configs are patched with identical DB/source/log settings.
- Setup now verifies both config files exist before launching dbimport.
- Improved GUI extraction of `Config::LoadFile` / failed-open-file errors.

# v1.4.8 — Application Support Path Fix

- Fixed AzerothCore dbimport/config failures caused by spaces in macOS `Application Support` paths.
- Runtime data remains stored in `~/Library/Application Support/WoWServerControlCenter/`.
- The app now creates a safe no-space alias at `~/.wowcc` and passes that alias to core/dbimport configs.
- WotLK `DataDir`, `SourceDirectory`, `LogsDir`, dbimport config path, and dbimport working directory now use the no-space alias.
- Prepare Client Data creates/repairs the same alias before extraction.
- GUI error detection now surfaces config-parser messages such as `the argument (...)` and invalid-value errors.

# v1.4.7 — No-Border Finder/Dock Icon

- Uses the approved icon artwork, not a newly generated design.
- Removes the baked-in outer rounded rim/shadow from the source artwork.
- Generated icon PNGs are fully opaque edge-to-edge with no transparent padding.
- The inner W/globe artwork is enlarged to fill the macOS icon canvas.
- Finder and Dock use the same AppIcon.icns.

# v1.4.6 — Full-Bleed Dock/Finder Icon

- Replaced the previous icon with the newly approved simpler icon.
- Uses the exact approved artwork as the master source.
- Removes outer transparent/empty padding before generating icon sizes.
- Generates every macOS icon size from a full-bleed 1024×1024 master.
- Uses the same AppIcon.icns for Finder and Dock.
- Refreshes LaunchServices registration after build so Finder/Dock can pick up the new icon.
- No alternate/generated icon is used.

# v1.4.5 — Dock/Finder Icon Fix

- Fixed Build.command so the icon is generated and copied before code signing.
- Fixed the invalid `$APP_DIR` path that prevented the icon from being embedded.
- CFBundleIconFile now explicitly references `AppIcon.icns`.
- Build now fails visibly if iconutil cannot create the icon or the final app bundle does not contain it.
- Added final Finder/Dock icon sanity checks.
- Added icon checks to Verify.command.

# v1.4.4 — Dock Icon

- Added the approved macOS rounded-square premium Dock/Finder icon.
- Build.command generates AppIcon.icns and embeds it in the .app bundle.
- CFBundleIconFile is set to AppIcon.

# WoW Server Control Center 1.4.3

## 1.4.3 Guided Setup + Cleanup
- Removed the Character 3D Preview module and all related asset-cache checks/code.
- Added **Setup Guide** with numbered, state-aware steps and a prominent **NEXT** action for the selected era.
- Added **Storage & Cleanup** with confirmations for build cache, DB download cache, logs, backups, core source/install, extracted client data, all era downloads, live realm DB, client-link removal, and full per-era factory reset.
- Cleanup is path-guarded and refuses to delete outside `~/Library/Application Support/WoWServerControlCenter/`.
- Original external WoW client files are never deleted by cleanup.
- Main Admin Center text is selectable; the persistent bottom status bar now supports selecting status text and has a Copy Status button.
- Bottom status allows two lines instead of hiding most compiler/database diagnostics.
- Backup script now uses the correct DB set for Cataclysm/MoP (`auth`, `characters`, `world`).
- Bundle version updated to 1.4.3.

## Added
- One-click Cataclysm 4.3.4 / 15595 profile using The Cataclysm Preservation Project TrinityCore fork.
- One-click Mists of Pandaria 5.4.8 / 18414 profile using ProjectSkyfire SkyFire_548.
- Community Trinity-style DB bootstrap (`auth`, `characters`, `world`).
- Automatic GitHub Releases DB asset discovery, download, extraction, import, and local caching.
- Cataclysm/MoP client data preparation hooks and exact client build search hints.
- Realm readiness checks for Cata/MoP required tables.
- Admin database routing to `world` and `characters` for Cata/MoP instead of incorrectly treating them as CMaNGOS `mangos` databases.
- Apple Silicon compatibility warning for current SkyFire community builds.
- Ninja and p7zip added to managed runtime dependencies.

## Important
Cataclysm is a community core and MoP is an even more toolchain-sensitive community core. Control Center now automates their installation path, but third-party upstream changes can still cause a compile or database-release incompatibility. The bottom installation status and `runtime/installer.log` preserve the exact failure instead of marking the profile ready incorrectly.

## 1.4.1 Community Build Fix
- Cataclysm and MoP native macOS builds now use conservative single-job compatibility mode.
- Failed builds automatically retry with verbose output to expose the actual compiler error.
- Per-profile build log: `~/Library/Application Support/WoWServerControlCenter/runtime/<profile>-core-build.log`.
- Admin status bar now extracts the real compiler diagnostic instead of showing only `make Error 2` / Ninja's final failed object.
- StormLib completion is no longer misreported as the cause when another parallel target fails.


## 1.4.3 MySQL Lifecycle
- Added dedicated Install MySQL 8.4, Repair/Reinstall MySQL, Restart Managed MySQL and Uninstall MySQL controls.
- Added separate Delete Managed MySQL Data for the selected era.
- Repair/reinstall preserves realm data; uninstall preserves realm data but removes the shared Homebrew mysql@8.4 runtime.
- Guided Setup now treats MySQL as its own explicit first step.
