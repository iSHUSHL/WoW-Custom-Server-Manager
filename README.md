<p align="center">
  <img src="Resources/AppIcon-1024.png" alt="WoW Server Control Center icon" width="112" height="112">
</p>

<h1 align="center">WoW Server Control Center for macOS</h1>

<p align="center"><strong>Native macOS control center for local World of Warcraft emulator realms.</strong></p>

## Project scope — exactly five expansions

> **Project scope:** WoWCC development is intentionally limited to exactly five expansions: **Vanilla, The Burning Crusade, Wrath of the Lich King, Cataclysm, and Mists of Pandaria**. WoD, Legion, Battle for Azeroth, Shadowlands, Dragonflight, The War Within, and other later expansions are out of scope and are not planned for support.

**Current source milestone: v1.6.46 — Dungeon Clear Runtime Fix.**

WoW Server Control Center (WoWCC) is an actively developed native SwiftUI macOS application for building, configuring, running, monitoring, and administering local WoW emulator realms from one GUI. It is designed especially for Apple Silicon Macs and can be built without opening the Xcode GUI.

## Current expansion targets

| Expansion | Client | Server core | Development target |
| --- | --- | --- | --- |
| Vanilla | 1.12.1 | CMaNGOS Classic | Supported scope |
| The Burning Crusade | 2.4.3 / 8606 | CMaNGOS TBC + PlayerBots | Supported scope |
| Wrath of the Lich King | 3.3.5a / 12340 | AzerothCore Playerbot fork + mod-playerbots | Primary current path |
| Cataclysm | 4.3.4 / 15595 | TrinityCore 4.3.4 preservation/community path | Supported scope |
| Mists of Pandaria | 5.4.8 / 18414 | Project SkyFire 5.4.8 | Supported scope |

## v1.6.46 highlights

- WotLK Dungeon Bot Leader / Dungeon Clear build workflow.
- Rebuilt Dungeon Clear worldserver is deployed into the actual WoWCC WotLK runtime profile rather than being left only in the source build tree.
- Runtime worldserver is SHA-256 verified against the freshly rebuilt module-enabled binary.
- Exact server binary/config paths are surfaced in WoWCC diagnostics.
- GM Island specialist hub and central class/spec Gear Menu development.
- One-click Gear Menu module build/update workflow.
- Simplified Characters workflow: toon list/status/details and Set Level remain; AI Game Master, Character Maxer, and Character Inventory are intentionally removed.
- Quick Give and targeted World Console administration remain separate from Characters.

## Core capabilities

- Install and manage isolated server profiles for the five supported expansions.
- Start/stop managed MySQL, authentication/realm service, and world server.
- Dashboard health/service state and guided setup/repair workflows.
- Account creation and character administration.
- Database-backed item/collection browsing and Quick Give.
- WotLK PlayerBots integration, including bot population controls.
- Dungeon Bot Leader integration for supported WotLK dungeon navigation.
- GM Island administration and Gear Menu module development.
- LAN-play configuration.
- Integrated logs and build diagnostics so routine troubleshooting does not require hunting through Finder/Terminal.
- Backup, cleanup, rebuild, client-linking, and data-preparation workflows.

## WotLK Dungeon Bot Leader

WoWCC can build the Dungeon Clear module into the WotLK AzerothCore worldserver. In v1.6.46 the installer also deploys the rebuilt binaries into WoWCC's actual WotLK runtime profile and verifies the runtime worldserver hash. Restart the World Server after a successful module build before testing Dungeon Clear in game.

Holiday/event encounters may use special LFG/event behavior and should not be assumed to follow ordinary dungeon routes.

## GM Island / Gear Menu

The WotLK GM Island workflow provides a clean specialist hub plus a central Gossip Gear Menu architecture. The menu source covers all ten WotLK classes and their specs. The Gear Menu module must be compiled into the active worldserver; WoWCC provides a build/update action and diagnostics for that workflow.

## Playing on Apple Silicon Macs

WoWCC manages the server side and links to a legally obtained compatible WoW client; Blizzard game clients are not included in this repository. Users must provide their own compatible client/data.

## Build on macOS

Install Apple Command Line Tools, then double-click `BUILD-WoWCC.command` or `Build.command`. The release app is created under `Build/`.

Run `Verify.command` for source/shell integrity checks.

## Local data

Canonical managed data is stored under:

`~/Library/Application Support/WoWServerControlCenter/`

WoWCC may also create compatibility paths/symlinks for tools that have trouble with spaces.

## Project status

This repository is work in progress. WotLK/AzerothCore is currently the most mature path. Emulator compatibility, PlayerBots behavior, custom modules, Cataclysm/MoP support, and source patches continue to be tested and refined.

## Client and project disclaimer

WoWCC does not contain or distribute Blizzard Entertainment game clients, copyrighted game data, or proprietary assets. Users must provide their own legally obtained compatible client/data and are responsible for applicable licenses and laws.

World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment, Inc. This project is independent and is not affiliated with, endorsed by, or sponsored by Blizzard Entertainment. WoWCC also is not affiliated with CMaNGOS, AzerothCore, Project SkyFire, or their maintainers.
