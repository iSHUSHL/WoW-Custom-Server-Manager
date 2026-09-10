<p align="center">
  <img src="Resources/AppIcon-1024.png" alt="WoW Server Control Center icon" width="112" height="112">
</p>

<h1 align="center">WoW Server Control Center for macOS</h1>

<p align="center"><strong>Native macOS control center for local Vanilla, TBC, and WotLK emulator realms.</strong></p>

> **Work in progress.** WoW Server Control Center (WoWCC) is an actively developed native SwiftUI macOS application for building, configuring, running, monitoring, and administering local World of Warcraft emulator realms from one GUI.

The main supported targets are **Vanilla 1.12.1**, **The Burning Crusade 2.4.3**, and **Wrath of the Lich King 3.3.5a**. Each expansion uses its own compatible server core, database, runtime, configuration, and game client. The project is designed especially for Apple Silicon Macs and can be built without opening the Xcode GUI.

## Current expansion targets

| Expansion | Client | Server core | Status |
| --- | --- | --- | --- |
| Vanilla | 1.12.1 | CMaNGOS Classic | Work in progress |
| The Burning Crusade | 2.4.3 / 8606 | CMaNGOS TBC + PlayerBots | Active development |
| Wrath of the Lich King | 3.3.5a / 12340 | AzerothCore | Primary turnkey path |

Experimental/community profiles also exist for later expansions, but Vanilla, TBC, and WotLK are the main focus of this project.

## Playing on Apple Silicon Macs

WoWCC manages the **server** side and links to a legally obtained compatible WoW client; Blizzard game clients are not included in this repository.

Apple Silicon users can use **WoWSilicon** to run the original older Windows WoW clients on modern macOS. WoWSilicon currently provides profiles for Vanilla 1.12.1, TBC 2.4.3, and WotLK 3.3.5a, matching WoWCC's three primary eras. See https://wowsilicon.github.io/ for the launcher and requirements.

## What WoWCC can do

### One-app server control
- Install and manage isolated server profiles for each expansion.
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
- Prepare DBC/maps/vmaps/mmaps and other required server data.
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
- Collection Browser reads directly from the selected expansion world database for Vanilla, TBC, WotLK, Cataclysm, and Mists of Pandaria.
- All Items exposes every `item_template` row through complete paging with total counts; collection switching loads automatically.
- Collection types include raid sets, weapons, armor, legendaries, BiS/endgame, bags, mounts, and the complete item catalog.
- Search the actual world database item catalog by name or item ID.
- Browse item icons and tooltips.
- Give individual items to a selected character.
- Reconstruct expansion-specific gear sets from server data.
- Browse PvE/Tier, PvP, and high-end available sets.
- Give complete sets from the GUI.
- Browse curated collections such as notable weapons, armor, legendaries, and mounts.

### Mount management
- Search/load mount-learning items from the selected expansion database.
- Give/learn mounts for a selected character through the Admin Center adapters.
- TBC development includes optional custom gameplay patches for mount/flying behavior.

### TBC PlayerBots
- Integrates the CMaNGOS PlayerBots module into the TBC build.
- Populate/repair the PlayerBots world from the GUI.
- Configure bot population and startup behavior.
- Show live bot/character information.
- Current development includes faster bot creation/login tuning and native crash diagnostics.
- PlayerBots support is experimental and remains an active stability workstream.

### TBC gameplay customization
WoWCC includes optional source-level TBC patches used by this project, including work around custom Warrior dual-two-handed weapon support and mount/flying restrictions. These patches are applied during the managed TBC rebuild workflow and remain experimental.

### Health Check Center
Checks include Mac architecture, disk access, dependencies, core binaries/configuration, linked client and extracted data, database schemas, service state/ports, logs/backups, and Admin Center connectivity. Checks are grouped into PASS/WARNING/FAIL states, with repair actions where WoWCC can safely fix the problem automatically.

### Logs and crash diagnostics
Logs are available directly inside the **Logs** page; users should not have to hunt through Finder or Terminal. WoWCC exposes World, Auth, MySQL, installer, core-build, CMake, crash/debugger, and automatically discovered profile logs.

TBC development builds also include native crash-diagnostic work for tracking CMaNGOS/PlayerBots crashes. Debug facilities are temporary development aids and are removed or reduced when a root cause is fixed.

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

This repository is **work in progress**, not a finished turnkey distribution. Features, database adapters, emulator compatibility, PlayerBots behavior, and source patches are still being tested and refined. WotLK/AzerothCore is currently the most mature path; TBC/CMaNGOS + PlayerBots is under active development; Vanilla support is also being developed and validated.

Expect bugs and breaking changes while the project evolves.

## Client and project disclaimer

WoWCC does **not** contain or distribute Blizzard Entertainment game clients, copyrighted game data, or proprietary assets. Users must provide their own legally obtained compatible client/data and are responsible for complying with applicable licenses and laws.

World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment, Inc. This project is independent and is not affiliated with, endorsed by, or sponsored by Blizzard Entertainment. WoWCC also is not affiliated with WoWSilicon, CMaNGOS, AzerothCore, or their maintainers.
