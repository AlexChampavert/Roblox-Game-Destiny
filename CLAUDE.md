# CLAUDE.md — STARFALL (Roblox)

Read `GAME_DESIGN.md` first: it's the source of truth for what the game is.
This file says how the code is built and what to do next.

## Stack
- **Luau** with **Rojo 7** (`default.project.json`). The code lives in `src/` and syncs into Roblox Studio.
- Recommended tooling (add via **Aftman** or **Rokit**): `rojo`, `selene` (lint, std = roblox), `stylua` (format), `luau-lsp`.
- No packages yet. When needed, use **Wally** (e.g. ProfileStore).

```
src/
  shared/            -> ReplicatedStorage.Shared
    Net.luau         all RemoteEvents/RemoteFunctions (created by server, found by client)
    Config/          PURE DATA: Classes, Weapons, Enemies, Missions, Progression, Story, Loot, Bounties
  server/            -> ServerScriptService.Server
    init.server.luau bootstrap: detects HUB vs MISSION mode, starts services
    Services/        Security, Telemetry, DataService, ProgressionService, CombatService,
                     ClassService, AbilityService, EnemyService, StoryService, BountyService,
                     MissionService, MatchmakingService, LoadoutService, LobbyService
    World/           Build helper, HubBuilder (the Meridian + class halls), MissionBuilder
  client/            -> StarterPlayerScripts.Client
    init.client.luau
    Controllers/     Effects, UI, HUD, Menus, Combat (camera + input)
```

## Architecture rules (keep these)
1. **One place, two modes.** Public server = HUB. Reserved server (`PrivateServerId ~= ""` and `PrivateServerOwnerId == 0`) = MISSION, and the mission id comes from the teleport data. `workspace:GetAttribute("Mode")` is `"Hub"` or `"Mission"`.
2. **Server-authoritative.** Clients only send intent (`Fire(aimPoint)`, `UseAbility(slot, aimPoint)`). The server checks fire rate, ammo, cooldowns, super charge and line of sight, and applies all damage, XP and loot. Never trust a number sent by a client.
3. **Data-driven content.** New class / weapon / enemy / mission / story week = a new entry in `shared/Config`. Logic should never hard-code content ids, except ability implementations in `AbilityService.Abilities[abilityId]`.
4. **Replication through attributes.** Player HUD state lives in Player attributes (`Level`, `XP`, `XPNext`, `Power`, `Shards`, `ClassId`, `WeaponId`, `Ammo`, `MagSize`, `Reloading`, `ReadyQ`, `ReadyE`, `SuperCharge`, `EmpoweredShots`). Timestamps use `workspace:GetServerTimeNow()`.
5. **Procedural maps are placeholders.** `HubBuilder` / `MissionBuilder` first look for hand-built maps in `ServerStorage.Maps` (`Hub`, `<missionId>`); the naming conventions are documented at the top of each builder. Real maps get built in Studio and replace the generated ones one at a time.
6. **Enemy models:** `ServerStorage.EnemyModels.<enemyId>` overrides the blocky placeholder. It needs a `Humanoid`, `HumanoidRootPart` and `Head`.
7. **Class halls** are generated from `Classes.Order` + each class's `hall` field, in `HALL_SLOTS` along the truss arms. A new class gets a hall automatically; add a slot if more than 10 classes ever exist.

## Testing in Studio
- `rojo serve`, connect from the Studio plugin, then Play.
- Enable **Game Settings → Security → Studio Access to API Services** to test saving.
- Teleports don't work in Studio. Launching a mission from the Mission Table runs it **locally in the same server** (built at z = 4000) and brings you back to the hub after. Every player in the test server joins it.
- Use **Test → Clients and Servers (2–3 players)** to test fireteams.

## Conventions
- Each service exports `Start()` (or `Init()`) and is started from `init.server.luau`. No circular requires: Security/Telemetry → Data → Progression → Combat → Class/Ability/Enemy → Story/Bounty → Mission → Matchmaking/Loadout → Lobby. Where a lower service needs something from a higher one, inject a function (see `MatchmakingService.LockReason`).
- Wrap every RemoteEvent handler in `Security.Guard(name, perSecond, handler)`.
- Anything that moves a player fast on the server (teleports, dashes) must call `Security.AllowMovement(player, seconds)` first, or the movement check will rubber-band them.
- Wrap remote handlers in type checks (`typeof(x) == "Vector3"`) before using arguments.
- No `wait()`/`spawn()`/`delay()`: use `task.*`.
- Keep files under ~500 lines; split by feature.

## FIRST TASK for Claude Code
✅ Steps 1–4 done (PR "CI + fixes + TESTING.md"): CI runs rojo build, selene, luau-lsp and StyLua (auto-formats feature branches). Keep CI green on every PR.

Original checklist:
1. Set up the toolchain (`rokit init` with rojo, selene, stylua, luau-lsp), add `selene.toml` with `std = "roblox"`, and add a GitHub Actions workflow that runs selene + stylua --check + `rojo build`.
2. Run `selene src` and luau-lsp analysis; fix every error and every real warning.
3. Review each "Implemented" item below against its description and fix logic bugs. Pay special attention to the session lock (DataService), the downed/revive flow, the aim pose math (shoulder C0) and matchmaking.
4. Write `TESTING.md`: a step-by-step Studio checklist for the user (who tests on PC), covering the full loop: Skydeck spawn → class pick → class hall + vendor → Mission Table → Wake Protocol to the end → back in the hub with XP, level, loot and bounties saved. Include 2–3 player tests for fireteams and revive.
5. Then work through the **50-idea backlog**, in the priority order given, one PR per idea (or per small group). Keep `GAME_DESIGN.md` up to date when design changes.

## Implemented in v1 (needs verification in Studio)
1. **Session-locked saving** (`DataService`): the record is `{profile, lock}`, locks go stale after 150s, and leaving or teleporting releases the lock. No dependency, but you can swap in ProfileStore if you prefer.
2. **Instant-feeling shots** (`client/Controllers/Combat.luau` `PredictShot`): local tracer, muzzle flash, hitmarker and camera recoil. The server sends tracers only to other players, and damage numbers come from the server. Sound hook: set `fireSound` in `Weapons.luau`.
3. **Gun models and aim pose**: a part-built gun on the right hand, with a rarity-colored stripe (`CombatService.attachGun`). Arms follow camera pitch: your own locally, other players' through the `AimPitch` UnreliableRemoteEvent. Arms lower while reloading.
4. **Smarter enemies** (`EnemyService`): pathfinding when there's no line of sight (computed async, at most once a second per enemy), dodgeable projectiles that lead the target, boss telegraphed slams (red circle, then explosion), and an AI budget of 12 enemies per 0.1s tick, round-robin.
5. **Revive**: fatal damage in missions puts you in a downed state for 15s. A teammate holds the prompt for 3s to revive, and Sanctuary revives instantly. A wipe means everyone is downed or dead.
6. **Find Fireteam** (`MatchmakingService`): MemoryStore sorted map per mission, a short-lived matchmaker lock, ReserveServer, then a MessagingService broadcast. After 45s alone, it launches solo.
7. **Loot**: rarities Common/Rare/Legendary/Exotic, 6 perks plus the exotic Starfall Round, an inventory (cap 40) with equip and dismantle, and an **order vendor** in each class hall (gear engram + order armor cosmetic).
8. **Bounties and Order Rank**: 3 daily and 3 weekly bounties (`Config/Bounties.luau`), auto-paid. Class XP becomes Order Rank, which unlocks Q cooldown, E cooldown, ability damage and super gain upgrades at 5/10/15/20.
9. **Anti-exploit** (`Security`): token-bucket rate limit on every remote, a server movement check with rubber-banding, "shot behind you" rejection, NaN checks and a strike log (kick at 40 strikes, decays over time).
10. **Performance and analytics**: StreamingEnabled (Earth/space model is Persistent), pooled tracer parts, the AI budget, and `Telemetry` (onboarding funnel Joined → ClassPicked → FirstLaunch → FirstClear → SecondMission → Level5, plus custom events for mission clears, wipes, level-ups and security flags).

## 50-idea backlog (priority order: top = do first)

### A. Combat feel and gameplay
1. **Aim down sights** (right click / L2): zoom per weapon, tighter spread, slower movement.
2. **Sprint, slide and mantle** (climb ledges): movement is half the fun.
3. **Melee attack** (V): class-specific melee (Bulwark shoulder charge, Phantom knife throw...).
4. **Grenades as their own slot**: each class gets a grenade (G), so there are 3 abilities plus a super.
5. **Heavy weapons** (rocket launcher, machine gun) with rare heavy ammo drops.
6. **Ammo economy**: enemies drop ammo bricks, and special ammo for snipers and shotguns.
7. **Elements** (Ember / Volt / Null): elemental enemy shields that take bonus damage from the matching element.
8. **Weak points**: boss crit spots that open during certain phases.
9. **Finishers**: press a key on a low-health enemy for a class animation and an orb drop.
10. **Gamepad and mobile aim assist**, plus an optional mobile auto-fire.

### B. Content
11. **Strikes playlist**: replay missions with random modifiers and matchmaking.
12. **Hard mode ("Eclipse")**: weekly score-attack version of a mission with locked loadouts and an exclusive reward.
13. **Patrol zone** on the moon: open world, public events every 10 minutes, hidden chests.
14. **Lost sectors**: short hidden dungeons off the patrol zone, each with a mini-boss.
15. **Skydeck world event**: a Hollow boarding party that the whole hub server defends together.
16. **First raid, "The Vault of SOL"**: 6 players, puzzle mechanics, raid-exclusive gear.
17. **Weekly dungeon** (3 players) with a rotating boss and its own exotic.
18. **PvP, "The Proving Grounds"**: 3v3 elimination, power disabled, separate rewards.
19. **Season 2 faction "The Echoes"** (corrupted Wardens), with new enemy types reusing class abilities.
20. **New classes for Season 2** (e.g. Knight with sword and shield, Ranger, Summoner). Halls generate automatically.

### C. Progression and economy
21. **Armor pieces** (helmet/arms/chest/legs/class item) with stats (Mobility, Resilience, Recovery).
22. **Weapon upgrading**: masterwork with Shards and rare materials, and reroll a perk once.
23. **Exotic quests**: multi-step missions to earn specific exotics.
24. **Collections / Codex**: every item ever earned, re-acquirable, plus a lore book.
25. **Season Pass**: free track plus a cosmetic-only premium track, and Season Rank after level 30.
26. **Triumphs**: achievement list linked to Roblox Badges.
27. **Titles and seals** shown over the player's head.
28. **Exotic pity timer**: guaranteed exotic after N pinnacle drops without one.
29. **Shaders / transmog**: recolor armor and weapons (Robux and earnable).
30. **Vault**: stash beyond the 40-slot inventory, expandable.

### D. Social
31. **Clans**: banner in the hub, clan XP, weekly clan rewards.
32. **Cross-server friend invites**: join a friend's hub or fireteam (TeleportToPlaceInstance / SocialService).
33. **Emote wheel** and Skydeck dances / sit spots.
34. **Leaderboards** on the Skydeck: fastest clears for each mission (OrderedDataStore).
35. **Spectate** your fireteam while downed or dead.
36. **Inspect a player**: see their gear, power and titles.
37. **Mentor bonus**: veterans get rewards for helping new players finish Mission 1.
38. **Order competition**: the order (class) with the most activity each week decorates its hall and gets a buff.

### E. Hub and world
39. **Hand-built Meridian** interior, with a tram between the Command Deck and the Hangar.
40. **Orbital day/night**: sunrise over the Skydeck every 20 minutes, the Earth turning.
41. **NPC vendors with dialogue**: Quartermaster, Gunsmith, and a Decryptor who opens engrams.
42. **Personal quarters**: a small pod for each player to show trophies and exotics.
43. **Animated hub**: shuttles docking, drones flying, and an NPC crew walking routes.

### F. Tech, live ops and polish
44. **Admin / live-ops panel** (group rank-gated): change the chapter, spawn events, grant items, read flags.
45. **Remote config**: balance numbers in a DataStore/MemoryStore, so hotfixes don't need a publish.
46. **Automated tests**: config validation (every mission step, enemy id, perk id exists) with Jest-Lua, run in CI.
47. **Localization**: French first, then Spanish and Portuguese (LocalizationService).
48. **Accessibility**: colorblind modes, text size, reduced screen shake, subtitles.
49. **Settings menu**: sensitivity, FOV, graphics/performance mode, keybinds.
50. **Audio pass**: music per mission and hub zone, weapon sounds, SOL voice lines, ability sound cues.

Phase 1 polish (do alongside A): an onboarding tutorial (start directly inside Wake Protocol), a mobile UI pass with bigger buttons, and hand-built maps for the hub and Mission 1.
