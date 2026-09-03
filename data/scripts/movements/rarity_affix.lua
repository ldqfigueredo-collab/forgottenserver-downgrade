-- Applies/removes a rarity item's life-leech/mana-leech/critical-hit affix
-- (see Rarity.getAffixForWielder in data/scripts/lib/rarity.lua) whenever
-- it's equipped or unequipped. Recomputed live from the current wielder's
-- vocation rather than baked into the item, so the same item behaves
-- correctly no matter who's wearing it. Matched by action id (all rarity
-- items share Rarity.actionId), not item id, so this one MoveEvent pair
-- covers every eligible weapon in the game.
--
-- isCheck true is a dry-run permission check (fired while deciding whether
-- a move is even allowed); only isCheck false is the real equip/de-equip,
-- see src/movement.cpp — matches the existing precedent in
-- data/scripts/movements/claw_of_the_noxious_spawn.lua.
local rarityEquip = MoveEvent()

function rarityEquip.onEquip(player, item, slot, isCheck)
	if isCheck then return true end
	local chanceSkill, chanceValue, amountSkill, amountValue =
		Rarity.getAffixForWielder(item, player)
	if chanceSkill then
		player:addSpecialSkill(chanceSkill, chanceValue)
		player:addSpecialSkill(amountSkill, amountValue)
	end
	return true
end

rarityEquip:type("equip")
rarityEquip:aid(Rarity.actionId)
rarityEquip:register()

local rarityDeEquip = MoveEvent()

function rarityDeEquip.onDeEquip(player, item, slot, isCheck)
	if isCheck then return true end
	local chanceSkill, chanceValue, amountSkill, amountValue =
		Rarity.getAffixForWielder(item, player)
	if chanceSkill then
		player:addSpecialSkill(chanceSkill, -chanceValue)
		player:addSpecialSkill(amountSkill, -amountValue)
	end
	return true
end

rarityDeEquip:type("deequip")
rarityDeEquip:aid(Rarity.actionId)
rarityDeEquip:register()
