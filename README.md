<p align="center">
  <img src="Resources/AppIcon-1024.png" alt="WoW Server Control Center icon" width="112" height="112">
</p>

<h1 align="center">WoW Server Control Center for macOS</h1>

<p align="center"><strong>Native macOS control center for Vanilla, TBC, WotLK, Cataclysm, and Mists of Pandaria emulator realms.</strong></p>

> **Work in progress.** WoW Server Control Center (WoWCC) is an actively developed native SwiftUI macOS application for building, configuring, running, monitoring, and administering local World of Warcraft emulator realms from one GUI.

## Project scope — five expansions only

WoWCC is intentionally focused on exactly five World of Warcraft eras:

1. **Vanilla / Classic 1.12.1**
2. **The Burning Crusade 2.4.3**
3. **Wrath of the Lich King 3.3.5a**
4. **Cataclysm 4.3.4**
5. **Mists of Pandaria 5.4.8**

**WoWCC will not target later expansions.** Warlords of Draenor, Legion, Battle for Azeroth, Shadowlands, Dragonflight, The War Within, and later retail expansions are outside the project roadmap. Keeping the scope to these five eras lets development concentrate on reliable installation, databases, client data, administration, collections, bots, and gameplay tooling instead of adding partially supported expansion profiles.

## Current development status

| Expansion | Client | Server core | Project status |
| --- | --- | --- | --- |
| Vanilla | 1.12.1 / 5875 | CMaNGOS Classic | **Implemented — continuing fixes/polish** |
| The Burning Crusade | 2.4.3 / 8606 | CMaNGOS TBC + PlayerBots | **Implemented — continuing PlayerBots/stability work** |
| Wrath of the Lich King | 3.3.5a / 12340 | AzerothCore Playerbot fork + mod-playerbots | **Implemented — primary/mature path** |
| Cataclysm | 4.3.4 / 15595 | Cataclysm Preservation TrinityCore 4.3.4 | **In active development** |
| Mists of Pandaria | 5.4.8 / 18414 | Project SkyFire 5.4.8 | **In active development** |

### What has been done

The first three eras — **Vanilla, TBC, and WotLK** — already have the main WoWCC management workflow: isolated expansion profiles, managed database/runtime, core installation/rebuild, client linking and data preparation, realm controls, accounts/characters, collections, logs, health checks, backups/cleanup, and LAN-oriented server administration. TBC and WotLK also include PlayerBots work, with WotLK currently the most mature PlayerBots path.

WoWCC also already contains important groundwork for **Cataclysm and MoP**, including expansion profiles, database/client-data handling and Collection Browser integration. Cataclysm has dedicated DB2/item-catalog handling because its data model differs from the older WotLK-style `item_template` workflow.

### What is next

Current development is focused on bringing **Cataclysm and Mists of Pandaria** up toward the same practical experience as the first three eras. Priorities include reliable core builds on Apple Silicon, complete database setup/repair, dependable client-data extraction/preparation, realm startup and configuration, account/character administration, complete expansion-specific collections, and fixing expansion-specific compatibility issues discovered during real testing.

After Cata and MoP reach that level, development will continue improving these same five expansions rather than adding newer WoW eras.

## Playing on Apple Silicon Macs

WoWCC manages the **server** side and links to a legally obtained compatible WoW client; Blizzard game clients are not included in this repository.

For older clients, Apple Silicon users may use compatible third-party launchers/wrappers where appropriate. Client compatibility varies by expansion and is separate from WoWCC's server-side support.

## What WoWCC can do

### One-app server control
- Install and manage isolated server profiles for each supported expansion.
- Start and stop the managed MySQL database, authentication/realm service, and world server independently.
- Start the complete selected realm from the Dashboard.
- Display live service state, ports, database readiness, and server health.
- Keep each expansion's data and configuration isolated.
- Configure LAN play so another computer on the same network can connect to the Mac-hosted realm.

### Guided setup
- Setup Guide shows the next required step for the selected expansion.
- Install or repair runtime dependencies.
- Install/rebuild the selected emulator core.
- Link an external compatible WoW client.
- Prepare DBC/DB2/maps/vmaps/mmaps and other required server data as appropriate to the expansion.
- Setup or repair realm databases and configuration.
- Run health checks before starting the realm.

### Built-in managed database
- Runs an app-managed MySQL instance locally instead of requiring the user to manually maintain a separate database service.
- Uses isolated realm/world/character databases appropriate to each core.
- Provides database readiness checks and repair/setup workflows.
- Keeps the managed database local to the Mac by default.

### Accounts and characters
- Create game accounts from the GUI.
- Browse realm characters.
- Reload character information from the database.
- Select a character for administration.
- Launch the linked client for character creation/play workflows.

### Items, gear, and collections
- Collection Browser targets all five supported expansions: Vanilla, TBC, WotLK, Cataclysm, and Mists of Pandaria.
- All Items exposes the expansion's database-backed item catalog through complete paging with total counts.
- Collection types include raid sets, weapons, armor, legendaries, BiS/endgame, bags, mounts, and the complete item catalog.
- Search the actual world database item catalog by name or item ID.
- Browse item icons and tooltips.
- Give individual items to a selected character where the core adapter supports it.
- Reconstruct expansion-specific gear sets from server data.
- Browse PvE/Tier, PvP, and high-end available sets.

### PlayerBots
- TBC integrates CMaNGOS PlayerBots work.
- WotLK uses the compatible AzerothCore Playerbot fork plus `mod-playerbots`.
- WotLK bot population supports managed random-bot setup and populations up to 5,000.
- PlayerBots logs and setup diagnostics are exposed through WoWCC Logs.
- Bot behavior, PvP, dungeon/raid workflows and stability remain active development areas.

### Health Check Center
Checks include Mac architecture, disk access, dependencies, core binaries/configuration, linked client and extracted data, database schemas, service state/ports, logs/backups, and Admin Center connectivity. Checks are grouped into PASS/WARNING/FAIL states, with repair actions where WoWCC can safely fix the problem automatically.

### Logs and crash diagnostics
Logs are available directly inside the **Logs** page; users should not have to hunt through Finder or Terminal. WoWCC exposes World, Auth, MySQL, installer, core-build, CMake, crash/debugger, PlayerBots, catalog, and automatically discovered profile logs.

### Backups, storage, and cleanup
- Create/manage realm backups.
- Clear build/download caches.
- Remove logs or extracted data.
- Remove/reinstall a selected core.
- Forget a linked client without deleting the original game folder.
- Factory-reset WoWCC-managed data for a selected expansion.

WoWCC does not intentionally delete the user's original external WoW client.

## Build on macOS

Install Apple Command Line Tools, then double-click `Build.command`. The release app is created at `Build/WoW Server Control Center.app`.

Run `Verify.command` to perform source and shell integrity checks.

## Local data

The canonical managed-data directory is `~/Library/Application Support/WoWServerControlCenter/`. WoWCC may create the compatibility symlink `~/.wowcc` for tools that have trouble with spaces in paths.

## Project status

This repository is **work in progress**, not a finished turnkey distribution. **Vanilla, TBC, and WotLK form the first completed development group; Cataclysm and MoP are the current expansion-development focus.** WotLK/AzerothCore + PlayerBots is presently the most mature path.

The roadmap ends with these five expansions. Newer WoW expansions are intentionally out of scope.

Expect bugs and breaking changes while the project evolves.

## Client and project disclaimer

WoWCC does **not** contain or distribute Blizzard Entertainment game clients, copyrighted game data, or proprietary assets. Users must provide their own legally obtained compatible client/data and are responsible for complying with applicable licenses and laws.

World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment, Inc. This project is independent and is not affiliated with, endorsed by, or sponsored by Blizzard Entertainment. WoWCC also is not affiliated with CMaNGOS, AzerothCore, Project SkyFire, or their maintainers.
