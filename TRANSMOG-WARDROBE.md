# WoWCC WotLK Transmog Wardrobe

This build compiles the official AzerothCore `mod-transmog` into the WotLK Playerbot core.

After **Rebuild Core + PlayerBots**, the module is enabled with:
- appearance collection system
- retroactive inventory/bank appearance scan
- tracking of unusable appearances
- portable transmog
- saved transmog sets (25)
- hidden-slot appearances
- mixed armor types
- FULL mixed weapon types and handedness
- zero transmog/set cost

WoWCC's **Complete Item Collection** remains the GM wardrobe containing database-backed tier sets, armor and weapons. Give any desired appearance item to the character; the collection system records appearances when the module recognizes the item. Current upstream also supports `.transmog claim` for claiming eligible appearances from bags.

Optional NPC: `.npc add 190010`
