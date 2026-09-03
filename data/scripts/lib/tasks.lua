-- Task system config. Each entry's table index is its permanent task id
-- (used as the storage value and the modal-window choice id) — only ever
-- append new tasks, never renumber or remove existing ones, or players with
-- an active task will silently get remapped onto a different one.
Tasks = {
	[1] = {
		name = "Rats",
		creature = "Rat",
		killCount = 50,
		minLevel = 1,
		rewards = {exp = 100, gold = 75, points = 1}
	},
	[2] = {
		name = "Trolls",
		creature = "Troll",
		killCount = 75,
		minLevel = 8,
		rewards = {exp = 500, gold = 200, points = 2}
	},
	[3] = {
		name = "Dragons",
		creature = "Dragon",
		killCount = 20,
		minLevel = 60,
		rewards = {exp = 2500, gold = 800, points = 5}
	}
}
