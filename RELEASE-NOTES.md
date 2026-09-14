# v1.6.12 — Five-Expansion Project Scope

- WoWCC now targets exactly five expansions: **Vanilla, The Burning Crusade, Wrath of the Lich King, Cataclysm, and Mists of Pandaria**.
- Removed WoD, Legion, Battle for Azeroth, Shadowlands, Dragonflight, and The War Within from the app's expansion model and future development scope.
- Vanilla, TBC, and WotLK are the first implemented development group and will continue receiving fixes, stability improvements, PlayerBots work, and administration features.
- Cataclysm and Mists of Pandaria are now the active expansion-development focus.
- Cata work already includes dedicated 4.3.4 DB2 extraction/catalog handling and expansion-specific database configuration.
- MoP already has profile/database/client-data groundwork and Collection Browser support; the next work is completing and validating the full setup/runtime experience.
- Current Cata/MoP priorities: reliable Apple Silicon core builds, database setup/repair, client-data preparation, realm startup, account/character administration, complete collections, and expansion-specific compatibility fixes.
- The project roadmap ends with MoP. Newer retail expansions will not be added; development will concentrate on making these five eras complete and reliable.
- README updated to make the five-expansion scope, completed work, current status, and next development phase explicit.

# v1.6.11 — WotLK Rebuild Stability Mode

- WotLK core rebuild now stops World, Auth and managed MySQL before compiling; rebuilds can no longer run while the realm is still online.
- WotLK core compilation uses one Ninja job for maximum stability on Apple Silicon.
- Fixed the build-status regression where the watchdog emitted a new prefix but the Swift UI still searched for `[build:...]`; live progress/CPU heartbeats are visible again.
- Resumable Ninja build cache from 1.6.10 remains enabled, so interrupted builds reuse completed objects.
- A long-running compiler is left alone while CPU is active; a genuinely idle build is terminated by the existing watchdog.

# Earlier releases

The repository history before v1.6.11 contains the detailed implementation notes for the earlier WoWCC builds, including WotLK PlayerBots, realm isolation, Cataclysm DB2/catalog support, collections, tooltips, client-data preparation, database repair, and build-stability work.
