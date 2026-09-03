-- Ranged earth execute. Bonus damage only applies to monsters at or below
-- 30% health — deliberately excluded for players to avoid an oppressive
-- PvP kill-confirm effect.
local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_EARTHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_CARNIPHILA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_SMALLEARTH)

local executeBonus = false

local function callback(player, level, magicLevel)
	local min = (level / 5) + (magicLevel * 1.0) + 10
	local max = (level / 5) + (magicLevel * 1.6) + 18
	if executeBonus then
		min = min * 2
		max = max * 2
	end
	return -min, -max
end

combat:setCallback(CallBackParam.LEVELMAGICVALUE, callback)

function onCastSpell(creature, variant)
	local target = Creature(variant:getNumber())
	executeBonus = target ~= nil and target:isMonster() and target:getHealth() <= target:getMaxHealth() * 0.3
	local result = combat:execute(creature, variant)
	executeBonus = false
	return result
end
