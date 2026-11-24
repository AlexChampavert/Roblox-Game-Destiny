-- Analytics: onboarding funnel + custom events (Creator Dashboard → Analytics).
-- Every call is wrapped in pcall so analytics can never break gameplay.
-- D1/D7 retention is tracked automatically by Roblox.

local AnalyticsService = game:GetService("AnalyticsService")

local Telemetry = {}

-- Onboarding funnel: where do new players drop off?
Telemetry.Funnel = {
	Joined = 1,
	ClassPicked = 2,
	FirstLaunch = 3,
	FirstClear = 4,
	SecondMission = 5,
	Level5 = 6,
}
local FUNNEL_NAMES = {}
for name, step in Telemetry.Funnel do
	FUNNEL_NAMES[step] = name
end

local done: { [Player]: { [number]: boolean } } = {}

function Telemetry.Step(player: Player, step: number)
	done[player] = done[player] or {}
	if done[player][step] then
		return
	end
	done[player][step] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, FUNNEL_NAMES[step])
	end)
end

function Telemetry.Event(player: Player, name: string, value: number?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

function Telemetry.Forget(player: Player)
	done[player] = nil
end

return Telemetry
