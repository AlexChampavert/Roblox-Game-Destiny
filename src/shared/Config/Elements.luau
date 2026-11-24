--!strict
-- Elemental damage types. Weapons (Rare+) and class abilities carry an element.
-- Enemy shields of an element take bonus damage from that element (see Enemies.shield).

export type ElementDef = { id: string, name: string, color: Color3 }

local Elements: { [string]: ElementDef } = {
	Ember = { id = "Ember", name = "Ember", color = Color3.fromRGB(255, 130, 40) },
	Volt = { id = "Volt", name = "Volt", color = Color3.fromRGB(90, 200, 255) },
	Null = { id = "Null", name = "Null", color = Color3.fromRGB(170, 90, 255) },
}

return Elements
