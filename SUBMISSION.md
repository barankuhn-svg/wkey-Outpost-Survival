# Outpost Survival — Submission

## Overview
Outpost Survival is a wave-based Roblox survival game where players fight increasingly difficult enemies using an auto-aim water gun. The game combines real-time combat, progression, and persistence through a stat upgrade system (HP, Damage, Regen), a coin economy, and scaling enemy pressure over time.

## How to Play
- Join the game
- Upgrade stats in the menu (HP, Damage, Regen) using Coins
- Press START
- Survive as long as possible against scaling enemies
- Collect coins from kills and passively
- Upgrade between rounds

## Technical Highlights
- Custom enemy replication (server Lua tables, 20Hz batch updates, client local parts)
- One server script + one client script architecture
- DataStore persistence (coins + stats saved)
- Time-based difficulty scaling (Easy -> Medium -> Hard -> Extreme -> ULTRA)
- Auto-aim water gun with Roblox Beam
- 10 custom Sloyd rigs with randomized animation pools
- Localization in 9 languages (en, de, tr, ru, fr, es, pt-BR, ko, ja)
- Mobile-first UI

## What V2 adds over V1
- Custom 3D character rigs (Sloyd) instead of default enemies
- Stat upgrade system with coin economy
- Menu screen with avatar snapshot
- Difficulty progression bar
- Death screen with stats
- HP regeneration system
- Water gun model attached to player
- Localization expanded

## Known Issues / Not Yet Implemented
- Water gun rotation has minor angle offset (~5-10 degrees)
- Spawn rate slider UI needs drag implementation refinement

## Links
- GitHub: https://github.com/barankuhn-svg/wkey-Outpost-Survival
- Roblox: https://www.roblox.com/de/games/87521674587979/Outpost-Survival

