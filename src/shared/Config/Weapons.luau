--!strict
-- Weapon archetypes. Damage is base damage at power parity.

export type WeaponDef = {
	id: string,
	name: string,
	damage: number,
	rpm: number, -- rounds per minute
	magSize: number,
	reloadTime: number,
	range: number, -- studs
	spread: number, -- degrees (hip-fire cone)
	pellets: number, -- >1 for shotguns
	headshotMult: number,
	automatic: boolean,
	length: number, -- gun model length (studs)
	recoil: number, -- camera kick (degrees per shot)
	adsFov: number, -- camera field of view while aiming down sights (hip = 70)
	fireSound: string?, -- e.g. "rbxassetid://123" — set when you have audio
}

local Weapons: { [string]: WeaponDef } = {
	AutoRifle = {
		id = "AutoRifle",
		name = "Auto Rifle",
		damage = 9,
		rpm = 600,
		magSize = 40,
		reloadTime = 2.0,
		range = 220,
		spread = 1.6,
		pellets = 1,
		headshotMult = 1.6,
		length = 3.2,
		adsFov = 55,
		recoil = 0.6,
		automatic = true,
	},
	HandCannon = {
		id = "HandCannon",
		name = "Hand Cannon",
		damage = 32,
		rpm = 140,
		magSize = 10,
		reloadTime = 1.8,
		range = 180,
		spread = 0.6,
		pellets = 1,
		headshotMult = 2.0,
		length = 1.7,
		adsFov = 58,
		recoil = 2.2,
		automatic = false,
	},
	ScoutRifle = {
		id = "ScoutRifle",
		name = "Scout Rifle",
		damage = 24,
		rpm = 260,
		magSize = 16,
		reloadTime = 2.1,
		range = 350,
		spread = 0.3,
		pellets = 1,
		headshotMult = 1.8,
		length = 3.8,
		adsFov = 42,
		recoil = 1.2,
		automatic = false,
	},
	SMG = {
		id = "SMG",
		name = "SMG",
		damage = 6,
		rpm = 900,
		magSize = 45,
		reloadTime = 1.6,
		range = 120,
		spread = 2.4,
		pellets = 1,
		headshotMult = 1.4,
		length = 2.2,
		adsFov = 62,
		recoil = 0.4,
		automatic = true,
	},
	Shotgun = {
		id = "Shotgun",
		name = "Shotgun",
		damage = 11,
		rpm = 70,
		magSize = 6,
		reloadTime = 2.4,
		range = 45,
		spread = 6,
		pellets = 8,
		headshotMult = 1.3,
		length = 3.4,
		adsFov = 64,
		recoil = 4.0,
		automatic = false,
	},
	Sniper = {
		id = "Sniper",
		name = "Sniper Rifle",
		damage = 120,
		rpm = 45,
		magSize = 4,
		reloadTime = 2.8,
		range = 600,
		spread = 0.05,
		pellets = 1,
		headshotMult = 2.5,
		length = 4.8,
		adsFov = 20,
		recoil = 5.0,
		automatic = false,
	},
}

return Weapons
