# WotLK Transmog Integration (in progress)

This branch adds a standalone client-side MogIt collection UI installer.

- Requires WoW 3.3.5a client and a separately installed, compatible AzerothCore mod-transmog server module.
- Run `bash Scripts/install-transmog-ui.sh "/path/to/WoW 3.3.5a"` to install client addons.
- On the character screen enable MogIt and related addons; in game use `/mogit`.
- The server-side Transmogrifier/NPC applies appearances; MogIt browses/preview catalogs.
- This branch does **not** yet import all WoWCC 1.6.46 source changes or unlock all account appearances.
- Do not populate appearance tables blindly: confirm active module schema, config and account scope before modifying database rows.
- Core/MMAPS rebuild is not necessary for *only* the client addon installer.

Source of addon package: https://github.com/ZhengPeiRu21/transmog-addons
