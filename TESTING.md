# TESTING.md — how to test STARFALL in Roblox Studio (PC)

Follow this from top to bottom. When something doesn't match the **✅ expected** line, copy the red errors from the **Output** window (View → Output) and send them to Claude with the step number.

---

## 0. One-time setup (about 15 minutes)

1. **Install Roblox Studio**: https://create.roblox.com → *Start Creating*.
2. **Install Aftman** (the tool installer): download the Windows/macOS release from https://github.com/LPGhatguy/aftman/releases, run `aftman self-install`, then restart your terminal.
3. **Get the project**: `git clone https://github.com/AlexChampavert/Roblox-Game-Destiny` then `cd Roblox-Game-Destiny` and run `aftman install`. This installs rojo, selene and stylua at the versions in `aftman.toml`.
4. **Install the Rojo plugin in Studio**: run `rojo plugin install`, then restart Studio.
5. **Create the place**: in Studio, *New → Baseplate*. Delete the `Baseplate` part and the default `SpawnLocation` from Workspace, because the game builds its own world.
6. **Game settings** (Home → Game Settings):
   - **Avatar → Avatar type: R15**. Required, because the gun and aim pose use R15 arms.
   - **Security → Enable Studio Access to API Services: ON**. Required for saving. You need to **publish the place first** (File → Publish to Roblox).
7. **Connect Rojo**: in a terminal in the project folder, run `rojo serve`. In Studio, open the Rojo plugin (Plugins tab) and click **Connect**. The code appears under ReplicatedStorage, ServerScriptService and StarterPlayer.

> Every time you start testing: `rojo serve` + Connect in the plugin. Code changes from GitHub sync live.

---

## 1. Solo: hub, classes and halls

Press **Play** (F5).

| # | Do this | ✅ Expected |
|---|---|---|
| 1.1 | Wait for spawn | You spawn on the **Skydeck**: white deck, glass railings, no roof, stars, the broken blue Earth below. Output shows `[Starfall] Server ready in Hub mode`. |
| 1.2 | Look at the screen | The **class picker** opens by itself (5 classes). The HUD shows LV 1, ⚡10 and ◆0 at the top left, and buttons at the top right. |
| 1.3 | Pick **Arcanist** | Notification "You joined the Arcanist order.". The Q/F/E boxes appear at the bottom, and your outline is blue. |
| 1.4 | Walk to the **Command Deck** (the closed room at the front, with the door facing the deck) | You see the hologram table, the golden SOL sphere and the class terminal. |
| 1.5 | Press E near the **SOL sphere** | The SOL panel shows the season, the week and the message. |
| 1.6 | Walk onto a **truss arm** (the narrow walkway leaving the deck sideways) | You find the **class halls** along the walkway, each with its name over the door. |
| 1.7 | Enter **The Starwell** and press E on the centerpiece | The hall panel shows the lore, "You are a member", Order Rank 0, the 4 locked upgrades and the **Order Vendor**. |
| 1.8 | Enter **The Bastion** (Bulwark) and press E | It says "not a member" and shows a **JOIN** button. Don't click it. |
| 1.9 | Press **E** (Blink) on the deck, away from any prompt | You teleport about 35 studs forward. Movement abilities work in the hub. |
| 1.10 | Jumping puzzle: walk to the very end of the **+Z truss** and climb the white steps | You reach a gold platform with a glowing cube. Press E and the lore text appears. |
| 1.11 | Click **Gear** (top right) | You see 3 equipped Common items and an empty inventory. |
| 1.12 | Click **Bounties** | 3 daily and 3 weekly bounties, each at 0 progress. |

## 2. Solo: Mission 1 "Wake Protocol"

| # | Do this | ✅ Expected |
|---|---|---|
| 2.1 | Press E on the **Mission Table** and click **LAUNCH** on Wake Protocol | "[Studio] Running mission locally". You're teleported to a snowy pad and the night lighting changes. The SOL intro appears in the feed. |
| 2.2 | Look at your character | You're holding a gun, your arms aim where the camera looks, the camera is over the shoulder, and the mouse is locked. |
| 2.3 | Follow the tall orange beam | The objective reads "Find the crashed shuttle". Near the wreck, it completes and the next one starts. |
| 2.4 | Shoot Husks (left click) | You get tracers and a muzzle flash right away, a small camera kick, a white hitmarker (gold on headshots) and floating damage numbers. Husks run at you. |
| 2.5 | Reload with R, swap weapons with 1 and 2 | The ammo counter changes, "RELOADING" shows, and the gun model changes. |
| 2.6 | Use **Q** (Gravity Well) on a group | A blue sphere pulls the enemies in, then explodes. |
| 2.7 | Spitters (green) shoot at you | Their **green balls fly toward you**, and you can dodge them by strafing. |
| 2.8 | Defend the beacon: stay inside the zone | The progress bar fills only while you're in the zone. Leave it and you get "get back in the zone!". |
| 2.9 | Fill your super (the F box shows READY) and press **F** | Nova Storm: a big blue explosion. |
| 2.10 | Fight **Gravemaw** | Boss health bar on top. **Red circles** appear under you before slams, so move out. At 50% you get "Gravemaw calls the swarm!" and Husks spawn. |
| 2.11 | Let yourself get downed (stand in a slam with low HP) | Solo: the red "DOWNED" banner shows, then a wipe, "Restarting from checkpoint". You come back at the boss zone entrance and the boss restarts. |
| 2.12 | Kill Gravemaw | You get the SOL outro, "MISSION COMPLETE", XP, a **PINNACLE** loot drop, and possibly a level-up. After 20s you're back on the Skydeck. |
| 2.13 | Open **Gear** | The new item is equipped (if it was better), and the old one is in the inventory with Equip and Dismantle buttons. |
| 2.14 | Open **Bounties** | "Defeat 60 enemies" and similar now show progress. |
| 2.15 | Open the **Mission Table** | Ghost Relay unlocks at level 4. Wake Protocol shows "Cleared 1x". |

## 3. Saving

| # | Do this | ✅ Expected |
|---|---|---|
| 3.1 | Stop the test, then Play again | Same level, XP, class, gear, bounties and Shards. No class picker this time. |
| 3.2 | Look at the Output when you join | No `[DataService] ... temporary profile` warning. If you see it, API access is off or the place isn't published (step 0.6). |

## 4. Multiplayer (Test tab → Clients and Servers → 2 players → Start)

| # | Do this | ✅ Expected |
|---|---|---|
| 4.1 | Player 1: Fireteam → **Invite** Player 2 | Player 2 gets an invite popup. Click **Accept**, and both see the team (★ next to the leader). |
| 4.2 | Player 2 opens the Mission Table | They see "Leader launches" and no button. |
| 4.3 | Player 1 launches Wake Protocol | Both are moved into the mission. Enemies are tougher (more health, more of them). |
| 4.4 | Player 2 looks at Player 1 | Player 1's arms aim up and down with their camera, and you can see their tracers. |
| 4.5 | Let Player 2 get downed | "Player2 is down!" appears for everyone. Player 1 holds E on Player 2 for 3s, and Player 2 is revived at 40% health. Player 2 does **not** see a revive prompt on themselves. |
| 4.6 | Lifebinder test: switch Player 1 to Lifebinder in the hub. In a mission, let Player 2 go down and use **F (Sanctuary)** next to them | Instant revive. |
| 4.7 | Both players get downed | Wipe, then a restart from the checkpoint. |

## 6. Combat systems (backlog A)

| # | Do this | ✅ Expected |
|---|---|---|
| 6.1 | In a mission, hold **right click** | The camera zooms in (a lot with a sniper, a little with an SMG), you walk slower, and shots group much tighter. Mouse sensitivity drops so aiming feels the same. |
| 6.2 | Hold **Shift** while moving | You run faster and the view widens slightly. Shooting stops the sprint. |
| 6.3 | Sprint and press **C** | You slide forward and the camera drops low. |
| 6.4 | Jump at a waist-to-head-high block of cover and press **Space** again in the air | You climb on top of it (mantle). |
| 6.5 | Press **G** | A grenade arcs out and explodes. Each class's grenade looks and acts differently (Phantom's chains lightning, Lifebinder's heals). |
| 6.6 | Press **V** next to an enemy | Class melee: Bulwark lunges, Phantom throws a knife, Engineer stuns. |
| 6.7 | Shoot a Husk down to a sliver of health, walk up to it | **FINISH [V]** appears. Press V: the enemy dies with a beam and your super meter jumps. |
| 6.8 | Press **3** | You switch to the Rocket Launcher. The ammo counter turns purple and shows the reserve (e.g. "1 / 1 · 2"). |
| 6.9 | Fire a rocket at a group | A glowing rocket flies and explodes on impact, damaging everything nearby. |
| 6.10 | Kill enemies until a green or purple cube drops, then walk over it | "+Special ammo" / "+Heavy ammo", and the reserve number goes up. |
| 6.11 | Shoot a **Hollow Seer** (purple) | A purple shield bar sits over its health. Kinetic shots barely dent it. A Null weapon or Arcanist abilities melt it. Breaking it makes a burst and "Shield broken!". |
| 6.12 | Fight **Gravemaw** | About every 12s a yellow glowing core appears on its chest with "weak point exposed!". Hitting it deals gold numbers and big damage. |
| 6.13 | Plug in a **gamepad** and aim near an enemy | Shots snap onto enemies that are slightly off the crosshair (aim assist). With the mouse there's no snapping. |

## 5. Things that only work in a published game (not Studio)

- **Teleporting to a real mission server** (Studio runs missions in the same server instead).
- **Find Fireteam** across servers. In Studio it just launches solo.
- **Analytics** (Creator Dashboard → Analytics → Funnels/Events) shows up after real players join.

To test these: **File → Publish to Roblox**, set the game to **Private**, then join from the Roblox app with 2 accounts (or a friend).

## Known placeholders (normal for now)

- All maps, enemies and guns are blocky placeholders built from code.
- There's no sound yet. Fire sounds are wired up, but `fireSound` is empty in `Weapons.luau`.
- Mobile works (on-screen buttons), but the layout isn't polished yet.
