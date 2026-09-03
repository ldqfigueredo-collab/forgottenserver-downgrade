-- Attached to the Assassin's Dagger (item 2402) via weapons.xml. Reproduces
-- normal single-target weapon damage unless the Whirlwind buff (see
-- data/spells/scripts/attack/whirlwind.lua) is active, in which case it
-- cleaves everyone adjacent to the player instead. WHIRLWIND_SUBID must
-- match the value set on that spell's condition.
local WHIRLWIND_SUBID = 1

local normalCombat = Combat()
normalCombat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
normalCombat:setParameter(COMBAT_PARAM_BLOCKARMOR, true)
normalCombat:setFormula(COMBAT_FORMULA_SKILL, 0, 0, 1, 0)

local cleaveCombat = Combat()
cleaveCombat:setParameter(COMBAT_PARAM_TYPE, COMBAT_PHYSICALDAMAGE)
cleaveCombat:setParameter(COMBAT_PARAM_BLOCKARMOR, true)
cleaveCombat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HITAREA)
-- AREA_SQUARE1X1 (3x3 centered on caster) inlined — the named constant
-- lives in data/spells/lib/spells.lua, which isn't loaded into the weapons
-- script interface (see data/scripts/weapons/#example.lua for the same
-- inlining, same reason)
cleaveCombat:setArea(createCombatArea({
	{1, 1, 1},
	{1, 3, 1},
	{1, 1, 1}
}))
cleaveCombat:setFormula(COMBAT_FORMULA_SKILL, 0, 0, 1, 0)

function onUseWeapon(player, variant)
	if player:getCondition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT, WHIRLWIND_SUBID) then
		return cleaveCombat:execute(player, Variant(player:getPosition()))
	end
	return normalCombat:execute(player, variant)
end
