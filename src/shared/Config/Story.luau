--!strict
-- The live story. Each week of the season unlocks a chapter.
-- Change SeasonStart to your launch date (UTC, os.time format).
-- Adding next week's content = adding an entry here (and missions/hub flags).

export type Chapter = {
	week: number,
	title: string,
	solMessage: string, -- shown on the SOL Core in the hub and on join
	featuredMission: string?, -- double rewards this week
	modifier: string?, -- "LowGravity" | "Overcharged" | "Frenzy"
	hubFlags: { string }?, -- read by HubBuilder to change the ship over time
}

local Story = {}

Story.SeasonName = "Season 1: Signal in the Dark"
Story.SeasonStart = os.time({ year = 2026, month = 12, day = 1, hour = 17 }) -- edit me
Story.WeekLength = 7 * 24 * 3600

Story.Chapters = {
	{
		week = 1,
		title = "Awakening",
		solMessage = "Wardens, welcome aboard the Meridian. A shuttle is down on the moon and a ghost signal is calling from Kepler Relay.",
		featuredMission = "WakeProtocol",
		hubFlags = {},
	},
	{
		week = 2,
		title = "The Drowned City",
		solMessage = "The signal leads to Earth. The Drowned Spire is open. Be careful down there.",
		featuredMission = "DrownedSpire",
		modifier = "Frenzy",
		hubFlags = { "EarthSignalBeam" },
	},
	{
		week = 3,
		title = "Iron and Fire",
		solMessage = "The Iron Regime is aiming orbital cannons at us. Stop Rourke before they fire.",
		featuredMission = "Ironfall",
		modifier = "Overcharged",
		hubFlags = { "EarthSignalBeam", "RegimeFlares" },
	},
	{
		week = 4,
		title = "Heart of the Hollow",
		solMessage = "The swarm is moving. A Hollow armada is visible from the Skydeck. It ends now.",
		featuredMission = "HeartOfTheHollow",
		modifier = "LowGravity",
		hubFlags = { "EarthSignalBeam", "HollowArmada" },
	},
} :: { Chapter }

-- Current season week (1-based). Before launch returns 1.
function Story.currentWeek(now: number?): number
	local t = now or os.time()
	if t < Story.SeasonStart then
		return 1
	end
	return math.floor((t - Story.SeasonStart) / Story.WeekLength) + 1
end

-- Latest unlocked chapter
function Story.currentChapter(now: number?): Chapter
	local week = Story.currentWeek(now)
	local current = Story.Chapters[1]
	for _, chapter in Story.Chapters do
		if chapter.week <= week then
			current = chapter
		end
	end
	return current
end

return Story
