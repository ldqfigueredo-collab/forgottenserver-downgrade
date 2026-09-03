-- Talent tree: 3 roots (5 ranks each, always available) that unlock a 2-way
-- fork at rank 5/5. All 6 branches are visible/spendable by every vocation
-- from the start -- role identity comes from which bonuses a vocation can
-- actually use, not from a gate. Shared global table, same pattern as
-- Tasks (data/scripts/lib/tasks.lua) -- visible from legacy NPC scripts too.
--
-- Design approved by the user before implementation (design rule 4, see
-- BUILD_NOTES.md). Total tree cost across all 9 nodes (~2015 points)
-- deliberately exceeds the 999-point budget at level 1000, so no character
-- can ever max the whole tree -- see BUILD_NOTES.md for the full rationale.
Talents = {}

local ROOT_MAX = 5
local BIG_BRANCH_MAX = 400
local SMALL_BRANCH_MAX = 200

local TALENT_CONDITION_SUBID = 200

-- Percent-family condition params are engine-encoded as (100 + extra%), same
-- convention as the existing RegenPercent feature (data/lib/core/player.lua)
-- -- extra% 0 means "no bonus" (100 = neutral). Special-skill params
-- (crit/leech chance & amount) are raw values instead, no offset.
local PERCENT_OFFSET_PARAMS = {
	[CONDITION_PARAM_SKILL_MELEEPERCENT] = true,
	[CONDITION_PARAM_SKILL_DISTANCEPERCENT] = true,
	[CONDITION_PARAM_STAT_MAGICPOINTSPERCENT] = true,
	[CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT] = true,
	[CONDITION_PARAM_STAT_MAXMANAPOINTSPERCENT] = true
}

Talents.Nodes = {
	root_combat = {
		storageKey = "talentRootCombat",
		maxRank = ROOT_MAX,
		requiresRoot = nil,
		name = "Combat Instinct",
		effects = {
			{param = CONDITION_PARAM_SKILL_MELEEPERCENT, perRank = 1},
			{param = CONDITION_PARAM_SKILL_DISTANCEPERCENT, perRank = 1},
			{param = CONDITION_PARAM_STAT_MAGICPOINTSPERCENT, perRank = 1}
		},
		unlocks = {"physical_mastery", "arcane_mastery"}
	},
	root_vital = {
		storageKey = "talentRootVital",
		maxRank = ROOT_MAX,
		requiresRoot = nil,
		name = "Vital Instinct",
		effects = {
			{param = CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT, perRank = 1},
			{param = CONDITION_PARAM_STAT_MAXMANAPOINTSPERCENT, perRank = 1}
		},
		unlocks = {"fortitude", "mana_well"}
	},
	root_killer = {
		storageKey = "talentRootKiller",
		maxRank = ROOT_MAX,
		requiresRoot = nil,
		name = "Killer Instinct",
		effects = {
			{param = CONDITION_PARAM_SPECIALSKILL_CRITICALHITCHANCE, perRank = 0.2},
			{param = CONDITION_PARAM_SPECIALSKILL_LIFELEECHCHANCE, perRank = 0.2}
		},
		unlocks = {"lethality", "vampirism"}
	},
	physical_mastery = {
		storageKey = "talentPhysicalMastery",
		maxRank = BIG_BRANCH_MAX,
		requiresRoot = "root_combat",
		name = "Physical Mastery",
		effects = {
			{param = CONDITION_PARAM_SKILL_MELEEPERCENT, perRank = 0.1},
			{param = CONDITION_PARAM_SKILL_DISTANCEPERCENT, perRank = 0.1}
		}
	},
	arcane_mastery = {
		storageKey = "talentArcaneMastery",
		maxRank = BIG_BRANCH_MAX,
		requiresRoot = "root_combat",
		name = "Arcane Mastery",
		effects = {{param = CONDITION_PARAM_STAT_MAGICPOINTSPERCENT, perRank = 0.1}}
	},
	fortitude = {
		storageKey = "talentFortitude",
		maxRank = BIG_BRANCH_MAX,
		requiresRoot = "root_vital",
		name = "Fortitude",
		effects = {{param = CONDITION_PARAM_STAT_MAXHITPOINTSPERCENT, perRank = 0.1}}
	},
	mana_well = {
		storageKey = "talentManaWell",
		maxRank = BIG_BRANCH_MAX,
		requiresRoot = "root_vital",
		name = "Mana Well",
		effects = {{param = CONDITION_PARAM_STAT_MAXMANAPOINTSPERCENT, perRank = 0.1}}
	},
	lethality = {
		storageKey = "talentLethality",
		maxRank = SMALL_BRANCH_MAX,
		requiresRoot = "root_killer",
		name = "Lethality",
		effects = {
			{param = CONDITION_PARAM_SPECIALSKILL_CRITICALHITCHANCE, perRank = 0.02},
			{param = CONDITION_PARAM_SPECIALSKILL_CRITICALHITAMOUNT, perRank = 0.1}
		}
	},
	vampirism = {
		storageKey = "talentVampirism",
		maxRank = SMALL_BRANCH_MAX,
		requiresRoot = "root_killer",
		name = "Vampirism",
		effects = {
			{param = CONDITION_PARAM_SPECIALSKILL_LIFELEECHCHANCE, perRank = 0.02},
			{param = CONDITION_PARAM_SPECIALSKILL_MANALEECHCHANCE, perRank = 0.02},
			{param = CONDITION_PARAM_SPECIALSKILL_LIFELEECHAMOUNT, perRank = 0.075},
			{param = CONDITION_PARAM_SPECIALSKILL_MANALEECHAMOUNT, perRank = 0.075}
		}
	}
}

-- Display order: each root immediately followed by its two children.
Talents.Order = {
	"root_combat", "physical_mastery", "arcane_mastery", "root_vital", "fortitude", "mana_well", "root_killer",
	"lethality", "vampirism"
}

-- Typed / shorthand aliases a player might type, resolved to a canonical node id.
Talents.Aliases = {
	combat = "root_combat",
	vital = "root_vital",
	killer = "root_killer",
	physical = "physical_mastery",
	phys = "physical_mastery",
	arcane = "arcane_mastery",
	magic = "arcane_mastery",
	fortitude = "fortitude",
	hp = "fortitude",
	mana = "mana_well",
	manawell = "mana_well",
	lethality = "lethality",
	crit = "lethality",
	vampirism = "vampirism",
	leech = "vampirism"
}

function Talents.resolveNodeId(input)
	if not input or input == "" then return nil end
	local key = input:lower()
	if Talents.Nodes[key] then return key end
	return Talents.Aliases[key]
end

-- Shared by the talkaction, the NPC dialogue, and the client-mod opcode
-- handler -- was previously duplicated in talent.lua and Talent Master.lua.
function Talents.formatEffect(node, rank)
	local parts = {}
	for _, effect in ipairs(node.effects) do
		local total = effect.perRank * rank
		parts[#parts + 1] = ("+%.2f"):format(total):gsub("%.?0+$", "") .. "%"
	end
	return table.concat(parts, " / ")
end

function Talents.getRank(player, nodeId)
	local node = Talents.Nodes[nodeId]
	if not node then return 0 end
	return player:getStorageValue(PlayerStorageKeys[node.storageKey], 0)
end

function Talents.getTotalPoints(player)
	return math.max(0, math.min(player:getLevel() - 1, 999))
end

function Talents.getSpentPoints(player)
	local spent = 0
	for nodeId in pairs(Talents.Nodes) do spent = spent + Talents.getRank(player, nodeId) end
	return spent
end

function Talents.getAvailablePoints(player)
	return Talents.getTotalPoints(player) - Talents.getSpentPoints(player)
end

function Talents.isUnlocked(player, nodeId)
	local node = Talents.Nodes[nodeId]
	if not node then return false end
	if not node.requiresRoot then return true end
	local rootNode = Talents.Nodes[node.requiresRoot]
	return Talents.getRank(player, node.requiresRoot) >= rootNode.maxRank
end

-- Rebuilds the single talent-bonus condition from scratch based on current
-- ranks. Percent-family params must always fully remove + re-add the
-- condition to take effect (ConditionAttributes snapshots stat/skill deltas
-- once in startCondition/endCondition -- mutating a live condition's params
-- via setParameter does NOT re-trigger that snapshot, unlike the
-- HEALTHGAINPERCENT/MANAGAINPERCENT regen params, which are read fresh every
-- tick with no snapshot step).
function Talents.applyBonuses(player)
	if player:getCondition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT, TALENT_CONDITION_SUBID) then
		player:removeCondition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT, TALENT_CONDITION_SUBID)
	end

	local totals = {}
	for nodeId, node in pairs(Talents.Nodes) do
		local rank = Talents.getRank(player, nodeId)
		if rank > 0 then
			for _, effect in ipairs(node.effects) do
				totals[effect.param] = (totals[effect.param] or 0) + effect.perRank * rank
			end
		end
	end

	if not next(totals) then return end

	local condition = Condition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT)
	condition:setParameter(CONDITION_PARAM_TICKS, -1)
	condition:setParameter(CONDITION_PARAM_SUBID, TALENT_CONDITION_SUBID)

	for param, total in pairs(totals) do
		local value = PERCENT_OFFSET_PARAMS[param] and (100 + total) or total
		condition:setParameter(param, math.floor(value + 0.5))
	end

	player:addCondition(condition)
end

-- Returns success, reason (reason only set on failure).
function Talents.addRank(player, nodeId, amount)
	amount = amount or 1
	local node = Talents.Nodes[nodeId]
	if not node then return false, "That is not a known talent." end
	if amount <= 0 then return false, "Amount must be positive." end

	if not Talents.isUnlocked(player, nodeId) then
		local rootNode = Talents.Nodes[node.requiresRoot]
		return false, ("%s is locked -- max out %s (%d/%d) first."):format(node.name, rootNode.name,
			Talents.getRank(player, node.requiresRoot), rootNode.maxRank)
	end

	local currentRank = Talents.getRank(player, nodeId)
	if currentRank >= node.maxRank then return false, ("%s is already at its maximum rank (%d/%d)."):format(
		node.name, currentRank, node.maxRank) end

	local grantable = math.min(amount, node.maxRank - currentRank)
	local available = Talents.getAvailablePoints(player)
	if available <= 0 then return false, "You have no talent points available." end

	grantable = math.min(grantable, available)

	player:setStorageValue(PlayerStorageKeys[node.storageKey], currentRank + grantable)
	Talents.applyBonuses(player)

	if grantable < amount then return true, ("Only %d point(s) could be applied (points or rank cap reached)."):format(
		grantable) end
	return true
end

-- Returns success, reason (reason only set on failure).
function Talents.removeRank(player, nodeId, amount)
	amount = amount or 1
	local node = Talents.Nodes[nodeId]
	if not node then return false, "That is not a known talent." end
	if amount <= 0 then return false, "Amount must be positive." end

	local currentRank = Talents.getRank(player, nodeId)
	if currentRank <= 0 then return false, ("%s has no points spent to remove."):format(node.name) end

	local removable = math.min(amount, currentRank)

	-- Root guard: refuse to drop a root below the rank its children need to
	-- stay unlocked (maxRank) while either child still has points spent --
	-- otherwise a player could end up with ranks in a branch whose
	-- prerequisite root no longer qualifies it as unlocked.
	if node.unlocks and (currentRank - removable) < node.maxRank then
		for _, childId in ipairs(node.unlocks) do
			local childRank = Talents.getRank(player, childId)
			if childRank > 0 then
				return false,
					("Cannot reduce %s below %d/%d while %s has points spent (%d) -- remove those first."):format(
						node.name, node.maxRank, node.maxRank, Talents.Nodes[childId].name, childRank)
			end
		end
	end

	player:setStorageValue(PlayerStorageKeys[node.storageKey], currentRank - removable)
	Talents.applyBonuses(player)

	if removable < amount then return true,
		("Only %d point(s) could be removed (rank floor reached)."):format(removable) end
	return true
end

Talents.ResetCooldownSeconds = 86400

function Talents.getResetCooldownRemaining(player)
	local lastReset = player:getStorageValue(PlayerStorageKeys.talentLastReset, 0)
	if lastReset <= 0 then return 0 end
	local remaining = Talents.ResetCooldownSeconds - (os.time() - lastReset)
	return remaining > 0 and remaining or 0
end

-- Returns success, reason (reason only set on failure).
function Talents.reset(player)
	local remaining = Talents.getResetCooldownRemaining(player)
	if remaining > 0 then
		return false, ("You can reset your talents again in %d hour(s)."):format(math.ceil(remaining / 3600))
	end

	for nodeId, node in pairs(Talents.Nodes) do player:setStorageValue(PlayerStorageKeys[node.storageKey], 0) end
	player:setStorageValue(PlayerStorageKeys.talentLastReset, os.time())
	Talents.applyBonuses(player)
	return true
end
