-- Item rarity system: Normal/Rare/Epic/Legendary tiers rolled once on
-- eligible equipment drops (weapons, shields, armor, jewelry).
--
-- Flat stat bonus (attack/defense/armor) is baked into the item once, the
-- same way data/scripts/actions/others/weapon_upgrade.lua does it: always
-- recomputed from ItemType's static base, never compounded on top of a
-- previous roll.
--
-- Life leech, mana leech and critical hit are NOT baked into the item.
-- They're native SPECIALSKILL_* combat stats — src/combat.cpp reads
-- player->getSpecialSkill() directly for any player-caused damage, with no
-- imbuement system involved anywhere in this fork's src/. They're applied
-- dynamically at equip time based on the CURRENT wielder's vocation (see
-- movements/rarity_affix.lua), so the same physical item behaves correctly
-- no matter who's wearing it, and stays inert to the wrong vocation.
Rarity = {
	NONE = 0,
	RARE = 1,
	EPIC = 2,
	LEGENDARY = 3
}

RarityInfo = {
	[Rarity.RARE] = {
		name = "rare",
		weight = 20,
		statPercent = 4,
		affixChance = 3,
		affixAmount = 6,
		bindOnPickup = false
	},
	[Rarity.EPIC] = {
		name = "epic",
		weight = 8,
		statPercent = 8,
		affixChance = 6,
		affixAmount = 12,
		bindOnPickup = false
	},
	[Rarity.LEGENDARY] = {
		name = "legendary",
		weight = 2,
		statPercent = 15,
		affixChance = 10,
		affixAmount = 20,
		bindOnPickup = true
	}
}

-- Rarest first, so rollTier() below can subtract weights top-down.
-- Weights sum to 30/100 — the remaining 70 falls through to Rarity.NONE.
local rollOrder = {Rarity.LEGENDARY, Rarity.EPIC, Rarity.RARE}

-- Action id tagged onto every item that rolls a rarity tier, so a single
-- MoveEvent(:aid(...)) in movements/rarity_affix.lua catches all of them
-- regardless of item id, instead of enumerating every weapon/armor id in
-- the game. Not part of the PlayerStorageKeys reserved-range scheme in
-- data/lib/core/storages.lua (action ids are a separate namespace) — 45830
-- was checked unused across data/ before picking it.
Rarity.actionId = 45830

-- Melee: Knight favors sustain (life leech), Assassin favors burst (crit)
-- — same weapon category, different identity, per CLAUDE.md design rule 2
-- (never blur the roles together). Distance: Paladin favors crit
-- (precision). Magic: Sorcerer/Druid favor mana leech. Vocation ids match
-- data/XML/vocations.xml; promotions map to the same role as their base.
local VocationRole = {
	[1] = "sorcerer",
	[5] = "sorcerer",
	[2] = "druid",
	[6] = "druid",
	[3] = "paladin",
	[7] = "paladin",
	[4] = "knight",
	[8] = "knight",
	[9] = "assassin",
	[10] = "assassin"
}

local RoleAffix = {
	knight = {
		category = "melee",
		chanceSkill = SPECIALSKILL_LIFELEECHCHANCE,
		amountSkill = SPECIALSKILL_LIFELEECHAMOUNT
	},
	assassin = {
		category = "melee",
		chanceSkill = SPECIALSKILL_CRITICALHITCHANCE,
		amountSkill = SPECIALSKILL_CRITICALHITAMOUNT
	},
	paladin = {
		category = "distance",
		chanceSkill = SPECIALSKILL_CRITICALHITCHANCE,
		amountSkill = SPECIALSKILL_CRITICALHITAMOUNT
	},
	sorcerer = {
		category = "magic",
		chanceSkill = SPECIALSKILL_MANALEECHCHANCE,
		amountSkill = SPECIALSKILL_MANALEECHAMOUNT
	},
	druid = {
		category = "magic",
		chanceSkill = SPECIALSKILL_MANALEECHCHANCE,
		amountSkill = SPECIALSKILL_MANALEECHAMOUNT
	}
}

-- Which affix pool a weapon type belongs to. Shields and armor pieces are
-- deliberately absent here — they only ever get the flat stat bonus below,
-- never leech/crit (see the design proposal this was built from).
local WeaponAffixCategory = {
	[WEAPON_SWORD] = "melee",
	[WEAPON_CLUB] = "melee",
	[WEAPON_AXE] = "melee",
	[WEAPON_DISTANCE] = "distance",
	[WEAPON_WAND] = "magic"
}

function Rarity.isEligibleItem(itemId)
	local itemType = ItemType(itemId)
	local weaponType = itemType:getWeaponType()
	if weaponType == WEAPON_SWORD or weaponType == WEAPON_CLUB or weaponType ==
		WEAPON_AXE or weaponType == WEAPON_DISTANCE or weaponType ==
		WEAPON_WAND or weaponType == WEAPON_SHIELD then
		return true
	end
	return itemType:usesSlot(CONST_SLOT_HEAD) or itemType:usesSlot(
		       CONST_SLOT_ARMOR) or itemType:usesSlot(CONST_SLOT_LEGS) or
		       itemType:usesSlot(CONST_SLOT_FEET) or itemType:usesSlot(
		       CONST_SLOT_NECKLACE) or itemType:usesSlot(CONST_SLOT_RING)
end

function Rarity.rollTier()
	local roll = math.random(1, 100)
	for _, tier in ipairs(rollOrder) do
		local info = RarityInfo[tier]
		if roll <= info.weight then return tier end
		roll = roll - info.weight
	end
	return Rarity.NONE
end

-- Recomputes attack/defense/armor/name/description from the item's TRUE
-- static ItemType base plus BOTH this system's rarity tier AND
-- weapon_upgrade.lua's upgrade level (if any), every time either system
-- changes. This is the fix for the two systems clobbering each other:
-- previously each one independently overwrote attack/name from the static
-- base using only its own bonus, so applying one after the other silently
-- erased whichever bonus was applied first (e.g. rolling a rare sword,
-- then upgrading it to +1, used to leave it displaying as a plain "+1
-- sword" with only the upgrade's attack — the rarity bonus gone). Calling
-- this single function from both places instead makes the result always
-- reflect whichever bonuses are currently tagged on the item, regardless
-- of order or how many times it's recomputed.
--
-- options.baseAttack lets a caller override the true static base attack
-- (weapon_upgrade.lua needs this for distance weapons, which have a real
-- base attack of 0 in items.xml — see that file's distanceVirtualBaseAttack
-- comment). options.extraDescription appends upgrade-specific text (e.g.
-- protection-charge count) that this file has no knowledge of.
function Rarity.refreshCombinedDisplay(item, options)
	options = options or {}
	local itemType = ItemType(item:getId())

	local tier = item:getCustomAttribute("rarityTier")
	local hasTier = tier and tier ~= Rarity.NONE
	local rarityPercent = hasTier and RarityInfo[tier].statPercent or 0

	local upgradeLevel = item:getCustomAttribute("upgradeLevel") or 0
	local upgradePercent = upgradeLevel > 0 and
		                        WeaponUpgrade.getBonusPercent(upgradeLevel) or
		                        0

	local totalPercent = rarityPercent + upgradePercent

	local baseAttack = options.baseAttack or itemType:getAttack()
	local baseDefense = itemType:getDefense()
	local baseArmor = itemType:getArmor()
	if baseAttack > 0 then
		item:setAttribute("attack", baseAttack +
			                   math.floor(baseAttack * totalPercent / 100))
	end
	if baseDefense > 0 then
		item:setAttribute("defense", baseDefense +
			                   math.floor(baseDefense * totalPercent / 100))
	end
	if baseArmor > 0 then
		item:setAttribute("armor", baseArmor +
			                   math.floor(baseArmor * totalPercent / 100))
	end

	local nameParts = {}
	if upgradeLevel > 0 then
		nameParts[#nameParts + 1] = "+" .. upgradeLevel
	end
	if hasTier then nameParts[#nameParts + 1] = RarityInfo[tier].name end
	nameParts[#nameParts + 1] = itemType:getName()
	item:setAttribute("name", table.concat(nameParts, " "))

	local descParts = {}
	if upgradeLevel > 0 then
		descParts[#descParts + 1] = "Upgraded to +" .. upgradeLevel .. " (+" ..
			                             upgradePercent .. "% attack)."
	end
	if hasTier then
		descParts[#descParts + 1] = "This is a " .. RarityInfo[tier].name ..
			                             " item (+" .. rarityPercent ..
			                             "% stats)."
		if WeaponAffixCategory[itemType:getWeaponType()] then
			descParts[#descParts + 1] =
				"It resonates differently depending on who wields it."
		end
		if RarityInfo[tier].bindOnPickup then
			descParts[#descParts + 1] =
				"It is bound to you and cannot be traded."
		end
	end
	if options.extraDescription then
		descParts[#descParts + 1] = options.extraDescription
	end

	if #descParts > 0 then
		item:setAttribute("description", table.concat(descParts, " "))
	else
		item:removeAttribute(ITEM_ATTRIBUTE_DESCRIPTION)
	end
end

-- Shared by tryApplyOnDrop, reroll and forceApplyTier below — sets (or,
-- for Rarity.NONE, clears) the rarity-specific custom attributes and
-- action id, then defers all attack/name/description recomputation to
-- Rarity.refreshCombinedDisplay so an existing weapon_upgrade bonus is
-- preserved rather than clobbered.
local function setTier(item, tier)
	if tier == Rarity.NONE then
		item:removeCustomAttribute("rarityTier")
		item:removeCustomAttribute("rarityBOP")
		item:setActionId(0)
	else
		item:setCustomAttribute("rarityTier", tier)
		if RarityInfo[tier].bindOnPickup then
			item:setCustomAttribute("rarityBOP", 1)
		else
			item:removeCustomAttribute("rarityBOP")
		end
		item:setActionId(Rarity.actionId)
	end
	Rarity.refreshCombinedDisplay(item)
end

-- Rolls a rarity tier for one freshly-created loot item and applies it.
-- Called once, right when the item is created — see the loot hook in
-- eventcallbacks/monster/default_onDropLoot.lua. Never re-rolled here;
-- re-rolling later is Rarity.reroll(), used by the Appraiser NPC.
function Rarity.tryApplyOnDrop(item)
	if not Rarity.isEligibleItem(item:getId()) then return end

	local tier = Rarity.rollTier()
	if tier == Rarity.NONE then return end

	setTier(item, tier)
end

-- Re-rolls an existing rarity item to a brand new tier (including possibly
-- Rarity.NONE) — the gold-sink gamble offered by the Appraiser NPC. Does
-- not guarantee an upgrade.
function Rarity.reroll(item)
	local tier = Rarity.rollTier()
	setTier(item, tier)
	return tier
end

-- Forces a specific tier onto an item, bypassing the roll entirely.
-- Test/debug use only (see globalevents/scripts/rarity_test_chest.lua) —
-- live drops and re-rolls always go through the random Rarity.rollTier()
-- above.
function Rarity.forceApplyTier(item, tier) setTier(item, tier) end

-- Returns chanceSkill, chanceValue, amountSkill, amountValue for the given
-- item + wielder, or nil if this item/vocation combo grants no affix
-- (wrong weapon category for the wielder's role, a non-weapon item, or no
-- rarity tier at all).
function Rarity.getAffixForWielder(item, player)
	local tier = item:getCustomAttribute("rarityTier")
	if not tier or tier == Rarity.NONE then return nil end

	local weaponCategory = WeaponAffixCategory[ItemType(item:getId()):getWeaponType()]
	if not weaponCategory then return nil end

	local role = VocationRole[player:getVocation():getId()]
	if not role then return nil end

	local roleAffix = RoleAffix[role]
	if not roleAffix or roleAffix.category ~= weaponCategory then
		return nil
	end

	local info = RarityInfo[tier]
	return roleAffix.chanceSkill, info.affixChance, roleAffix.amountSkill,
	       info.affixAmount
end

function Rarity.isBoundOnPickup(item)
	return item:getCustomAttribute("rarityBOP") == 1
end
