--!strict
-- Daily and weekly bounties. 3 of each are picked per player per day/week.
-- event: "Kill" | "Headshot" | "AbilityKill" | "BossKill" | "Mission"
-- filter (optional): faction for kills, missionId for missions

export type BountyDef = {
	id: string,
	text: string,
	event: string,
	target: number,
	faction: string?,
	xp: number,
	shards: number,
}

local Bounties = {}

Bounties.Daily = {
	{ id = "d_kills", text = "Defeat 60 enemies", event = "Kill", target = 60, xp = 500, shards = 30 },
	{ id = "d_hollow", text = "Defeat 40 Hollow", event = "Kill", faction = "Hollow", target = 40, xp = 450, shards = 25 },
	{ id = "d_regime", text = "Defeat 25 Iron Regime soldiers", event = "Kill", faction = "Regime", target = 25, xp = 500, shards = 30 },
	{ id = "d_heads", text = "Land 30 headshot kills", event = "Headshot", target = 30, xp = 550, shards = 35 },
	{ id = "d_ability", text = "Get 15 ability kills", event = "AbilityKill", target = 15, xp = 500, shards = 30 },
	{ id = "d_mission", text = "Complete 2 missions", event = "Mission", target = 2, xp = 700, shards = 40 },
} :: { BountyDef }

Bounties.Weekly = {
	{ id = "w_kills", text = "Defeat 500 enemies", event = "Kill", target = 500, xp = 3000, shards = 200 },
	{ id = "w_bosses", text = "Defeat 6 bosses", event = "BossKill", target = 6, xp = 3500, shards = 250 },
	{ id = "w_missions", text = "Complete 8 missions", event = "Mission", target = 8, xp = 4000, shards = 250 },
	{ id = "w_heads", text = "Land 200 headshot kills", event = "Headshot", target = 200, xp = 3000, shards = 200 },
	{ id = "w_ability", text = "Get 100 ability kills", event = "AbilityKill", target = 100, xp = 3000, shards = 200 },
} :: { BountyDef }

Bounties.PerPeriod = 3

function Bounties.find(id: string): BountyDef?
	for _, b in Bounties.Daily do
		if b.id == id then
			return b
		end
	end
	for _, b in Bounties.Weekly do
		if b.id == id then
			return b
		end
	end
	return nil
end

return Bounties
