# STARFALL — Game Design Document (v1)

> A co-op sci-fi looter-shooter for Roblox. Pick a class, squad up in fireteams of 3, play story missions that keep evolving every week, and grow stronger through levels and loot.

---

## 1. The pitch (what players see on the game page)

**Earth fell. The Meridian didn't.**
The last starship of humanity holds orbit above a shattered world. You are a **Warden**, woken from cryo with a power nobody understands. Choose your class, gather your fireteam and take back the sky.

- 5 classes, each with 3 abilities and a super
- Co-op story missions for up to 3 players
- Levels, loot and power that keep going up
- A story that changes every week. New missions, new events, new secrets on the ship
- A giant social hub: the starship **Meridian**, with an open-sky deck in orbit

**Target session:** 10–20 minutes (one mission). Most Roblox players are on phones and play short sessions, so every system has to work on mobile and fit in a short loop.

---

## 2. World & story

### Setting
Year 2291. A swarm-intelligence called **The Hollow**, part machine and part flesh, hollowed out Earth's cities in 40 days. The last survivors launched the **Meridian**, a 2-kilometre colony ship built around an old orbital station. It now orbits the broken planet.

The ship's AI, **SOL**, wakes the Wardens: soldiers from a classified program, each bonded to a fragment of a fallen star (the **Starfall**). That fragment gives them their class powers.

### Factions
| Faction | Who they are | Play style |
|---|---|---|
| **The Hollow** | Swarm intelligence. Husks, Spitters, Brutes, Seers. | Lots of enemies at once, rush you down |
| **The Iron Regime** | Human warlord army that survived on the surface and wants the Meridian for itself | Fewer enemies, use cover and snipers, tougher |
| **SOL** (ally?) | The Meridian's AI, your guide | Season 1 twist: SOL is hiding something |

### Season 1 story arc: "Signal in the Dark" (5 missions)
1. Wardens wake up and rescue a crashed shuttle.
2. A ghost signal is coming from a dead station.
3. The signal leads down into a flooded tower on Earth where the Hollow keeps its "memory".
4. The Iron Regime is also chasing the signal. You storm their fortress.
5. You break into the Hollow's core and kill the Unmaker. In its last moment it speaks with SOL's voice.

**Cliffhanger for Season 2:** the Hollow was built by the same program that made the Wardens. SOL knew all along.

---

## 3. The hub: The Meridian

A huge starship in low orbit, styled like the ISS scaled up 50×: long truss spines, solar wings, modules connected by tunnels. Earth (broken, glowing cracks) fills the sky beneath.

### Zones
| Zone | What it's for |
|---|---|
| **Hangar Bay** | Docked shuttle, launch area (pilot NPC in Phase 2) |
| **Command Deck** | **Mission Table** (holographic, launch missions), **SOL Core** (story messages for the week), **Class Terminal** |
| **The Skydeck** (spawn) | Open-air top deck with **no roof**, shielded by an energy bubble. Space and Earth above and below. Players spawn here. Social spot: benches, emotes, the season board, leaderboards (Phase 2). This is the "screenshot spot" of the game. |
| **Warden Row: the class halls** | One small hall per class, hanging off the truss arms (see below) |
| **Solar Wings** | Truss arms with giant solar panels. Hidden lore collectibles and the jumping puzzle. |
| **Firing Range** (Phase 2) | Test weapons and abilities on dummies |

### Class halls (one per class)
Each class has its own hall on the ship, generated from the class config, so a new class gets a hall automatically.

| Class | Hall | Look |
|---|---|---|
| Bulwark | **The Bastion** | Shield wall, orange light, oil and hot steel |
| Phantom | **The Shadow Gallery** | Dark, purple neon, crossed blades |
| Arcanist | **The Starwell** | Observatory around a floating shard of the Starfall |
| Lifebinder | **The Verdant Sanctum** | The last garden in orbit |
| Engineer | **The Forge Deck** | Workshop, embers, turret on display |

Each hall has its own lore, a banner and a centerpiece where you can read about the order and join it. Phase 2 makes the halls the heart of class identity: an **order vendor** (class armor and emotes), **order bounties**, **Order Rank** (ability upgrades at 5/10/15/20), and a members-only trophy wall. Players hang out in their order's hall, so it builds community.

### Hub rules
- No combat in the hub (weapons holstered, abilities off)
- Movement abilities (dash, blink, thrusters) work in the hub, which makes the jumping puzzle more fun
- Artificial gravity, normal speed
- 25–30 players per hub server, so it always feels alive

---

## 4. Classes (5)

Every class has: a **passive**, **Ability 1 (Q)**, **Ability 2 / movement (E)**, a **grenade (G)**, a **melee (V)**, a **Super (F)** that charges from kills, damage and time, an **element**, base stats and a starting weapon.

| | Element | Grenade (G) | Melee (V) |
|---|---|---|---|
| Bulwark | Ember | Frag: big impact blast | Shoulder Charge |
| Phantom | Volt | Arcbolt: chains to 4 enemies | Knife Throw (45 studs) |
| Arcanist | Null | Vortex: 4s damage zone | Void Palm (cone knockback) |
| Lifebinder | Ember | Healing: heals allies, burns enemies | Siphon Strike (heals you) |
| Engineer | Volt | Cluster: 1 + 4 blasts | Shock Wrench (stuns) |

**Finishers:** V on a non-boss enemy at ≤15% health right in front of you kills it in style, makes you briefly untouchable and drops power orbs (super energy) for nearby allies.

| | **Bulwark** | **Phantom** | **Arcanist** | **Lifebinder** | **Engineer** |
|---|---|---|---|---|---|
| Role | Tank / frontline | Assassin / precision | Crowd control / burst | Support / healer | Zone control / turrets |
| Health | 150 | 90 | 100 | 110 | 110 |
| Speed | 15 | 20 | 16 | 17 | 16 |
| Passive | **Iron Skin**: takes 15% less damage | **Predator**: +25% headshot damage | **Overflow**: ability cooldowns 15% shorter | **Mending Aura**: nearby allies regen 2 HP/s | **Scavenger**: kills refund 10% ammo, turrets last longer |
| Q | **Shield Bash**: frontal cone hit, big knockback | **Smoke Veil**: invisible for 4s, enemies lose you | **Gravity Well**: singularity that pulls and damages enemies | **Healing Pulse**: heals all allies nearby | **Sentry Turret**: auto-turret for 15s |
| E | **Charge**: dash forward, damaging enemies in the path | **Shadow Dash**: long, fast dash | **Blink**: teleport 35 studs forward | **Lifeline**: dash to the nearest ally and shield both of you | **Thrusters**: jetpack boost upward and forward |
| Super F | **Bastion**: dome shield, allies inside take 60% less damage for 10s | **Deadeye**: next 3 shots deal 5× damage and pierce | **Nova Storm**: huge explosion around you after charging | **Sanctuary**: healing zone, allies inside fully healed and protected | **Orbital Strike**: the Meridian fires a laser at the target |
| Starter weapon | Shotgun + Auto Rifle | Hand Cannon + SMG | Scout Rifle + SMG | Auto Rifle + Hand Cannon | SMG + Scout Rifle |

**Class swap:** free at any time in the hub. Each class levels separately (class level = ability upgrades), so playing all 5 makes players come back.

**Class level upgrades (Phase 2):** at class level 5 / 10 / 15 / 20, each ability gets an upgrade, e.g. Gravity Well lasts longer or Turret fires rockets.

---

## 5. Missions (5) — Season 1

All missions are **co-op for 1–3 players**. Each one is a linear series of objective zones. Enemies scale with player count (+60% health and +1 extra enemy per wave for each extra player).

| # | Mission | Location | Objectives | Boss | Recommended power |
|---|---|---|---|---|---|
| 1 | **Wake Protocol** | Frozen moon, shuttle crash site | Reach crash → clear Husks → defend beacon (45s) → kill boss | **Gravemaw**, Brute Alpha | 10 |
| 2 | **Ghost Relay** | Dead orbital station (**low gravity**) | Reach station → capture 3 relays → clear the core → kill boss | **Relay Warden**, corrupted security mech | 15 |
| 3 | **The Drowned Spire** | Flooded megacity tower on Earth | Descend → escort the data drone → defend the upload → kill boss | **The Matriarch**, Hollow queen | 20 |
| 4 | **Ironfall** | Iron Regime fortress, desert | Breach → capture 2 cannon controls → clear the courtyard → kill boss | **Commander Vex Rourke** | 25 |
| 5 | **Heart of the Hollow** | Hive core, organic cave | Push in → defend against the swarm → 3-phase boss | **The Unmaker** (3 phases: adds, enraged, final) | 30 |

**Unlocking:** mission N needs mission N-1 completed (by the fireteam leader). Missions 4 and 5 also unlock with the weekly story schedule (see section 8) so the story arrives week by week, like a TV series.

**Rewards on completion:** XP, Shards (currency), one gear drop. Bosses drop **pinnacle gear** (higher power). The first clear of each mission also gives a lore entry and a class emblem.

---

## 6. Progression

Two layers, like the game that inspired it:

### Player level (1 → 30)
- XP from kills, objectives and mission completion
- XP needed for level n = `100 × n^1.5`
- Level-ups unlock: new missions, emotes, cosmetic titles and higher drop chances
- After level 30: **Season Rank** (infinite levels, a cosmetic reward every 5 ranks)

### Power level (10 → 50 in Season 1)
- Three gear slots: **Primary**, **Secondary**, **Armor**
- Power = average of the 3 slots
- Normal drops = your power + 0–2. Boss (pinnacle) drops = your power + 3–5
- Your power vs. the mission's power changes your damage (±2% per point, between 50% and 130%). Being underpowered hurts, so players have a reason to grind.

### Weapons
Three slots:
- **Primary / secondary:** Auto Rifle, Hand Cannon, Scout Rifle, SMG (primary ammo, infinite reserve), Shotgun and Sniper (special ammo).
- **Heavy:** Rocket Launcher, Machine Gun (heavy ammo).

Each weapon has damage, fire rate, magazine, reload time, range, spread, headshot multiplier, an ADS zoom and recoil.

**Ammo economy:** special and heavy reserves are limited, refilled at mission start and topped up by **ammo bricks** dropped by enemies (green = special, purple = heavy). Bosses always drop heavy.

**Rarity:** Common → Rare (1 perk) → Legendary (2 perks) → Exotic (unique perk). **Elements:** Rare weapons are 50% elemental, and Legendary and Exotic weapons always are.

### Combat systems
- **Aim down sights** (zoom, tighter spread, slower walk), **sprint**, **slide** and **mantle**.
- **Elemental shields** on elites and bosses: the matching element deals 3× to the shield, anything else 0.5×. Breaking a shield causes an area burst.
- **Boss weak points:** a glowing core is exposed every ~10–12s for ~5s, and hits on it deal 3–3.5×.
- **Aim assist** on gamepad and touch (never for mouse), with optional **mobile auto-fire**.

### Currency
- **Shards**: earned by playing. Spent on gear upgrades and cosmetics from the ship vendor.
- **Robux**: cosmetics only (see section 9)

---

## 7. Multiplayer: fireteams

- Fireteams of up to 3, formed in the hub
- Invite anyone in the same hub server from the Fireteam panel
- The leader picks a mission at the Mission Table. The whole team is teleported into a **private reserved server** for that mission.
- When the mission ends, everyone goes back to the hub
- **Phase 2:** "Find Fireteam" matchmaking that auto-fills empty slots (MemoryStore queue), plus cross-server friend invites

---

## 8. "A story that keeps evolving": the live system

This is what keeps players coming back, and it's mostly **data, not code**:

1. **Weekly story beats.** The season has a start date. Each week unlocks a new **chapter** in `Story.lua`: a SOL message in the hub, a new mission or mission variant, sometimes a change to the hub itself.
2. **Hub changes over time.** Week 1: Earth is quiet. Week 3: a Hollow armada is visible from the Skydeck. Week 5: part of the ship is damaged and a new area opens. These are flags that the HubBuilder reads.
3. **Story flags per player.** Every player keeps a saved list of what they've done and seen. Missions and dialogue check those flags, so a returning player sees exactly where they are in the story.
4. **Weekly modifiers.** Each week one mission is "featured" with a modifier (e.g. *Low Gravity*, *Overcharged Abilities*, *Hollow Frenzy*) and double rewards.
5. **Seasons.** Every 8–10 weeks: a new season with new missions, a new enemy type and maybe a new class. The finale is a **world event**: everyone in a hub server fights together on the Skydeck.

---

## 9. What makes players come (and stay)

**Discovery and first impressions**
- Strong thumbnail and icon: a Warden in front of the Meridian with Earth cracked below
- First 60 seconds: spawn on the Skydeck with the planet below, then straight into the tutorial mission (Mission 1). No menus before the first fight.
- Mobile-first controls with big buttons. Roblox is majority mobile.

**Retention loops**
- **Daily:** 3 bounties (e.g. "50 kills with Arcanist"), each giving XP and Shards
- **Weekly:** the new story chapter, the featured mission and pinnacle drops
- **Long term:** 5 classes to level, power to grind, exotics to chase, season rank

**Social**
- Fireteams, the Skydeck as a social hub, emotes, visible titles over players' heads ("Unmaker Slayer")
- Leaderboards on the Skydeck: fastest clear for each mission

**Monetization (fair, so players don't leave)**
- **No pay-to-win.** Robux never buys power.
- Game passes: cosmetic armor sets, weapon skins, emotes, ship trails, a "Fireteam Leader" banner
- Season Pass (Phase 3): free track plus a cosmetic premium track
- Private hub servers

---

## 10. Technical architecture (summary, details in CLAUDE.md)

- **One place, two modes.** The same place runs as **HUB** (public servers) or **MISSION** (reserved servers). Mode is detected at startup from teleport data. One codebase, simple publishing.
- **Server-authoritative.** Damage, ammo, cooldowns, XP and loot are decided on the server. Clients send only intent (fire at X, use ability Q).
- **Data-driven.** Classes, weapons, enemies, missions and story are config tables. New content = new config entries.
- **Procedural blockout maps.** The hub and all 5 missions are generated from code at first, so the game is playable on day one. Replace them with hand-built maps in Studio over time; the code looks for a hand-built map first.
- **Saving:** DataStoreService with retries and autosave (move to ProfileStore before launch).

---

## 11. Roadmap

| Phase | Content | Goal |
|---|---|---|
| **0 — Starter (this repo)** | Hub + class halls, 5 classes, 5 missions, levels, power, fireteams, saving, loot rarity and perks, inventory, order vendors, bounties, Order Ranks, revive, Find Fireteam matchmaking, anti-exploit, analytics | Playable end to end |
| **1 — Polish** | Real maps for hub + Mission 1, animations, sounds, VFX, tutorial, mobile UI pass, ADS/sprint/slide | Fun for 30 minutes |
| **2 — Depth** | Armor pieces, grenades/melee, strikes playlist, hard mode, patrol zone, triumphs, clans | Reason to play every day |
| **3 — Launch** | Thumbnails, game passes, season pass, analytics, ProfileStore, anti-exploit pass | Public release |
| **4 — Live** | Weekly chapters, Season 2, world events, raids (6 players) | Players stay for months |

**Rule:** don't start a phase until the previous one is fun. A small, polished Phase 1 beats a huge broken game.
