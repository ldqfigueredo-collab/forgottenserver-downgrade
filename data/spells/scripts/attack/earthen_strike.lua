local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_EARTHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_STONES)

local function callback(player, skill, attack, factor)
	local min = (player:getLevel() / 5) + (skill * attack * 0.05) + 10
	local max = (player:getLevel() / 5) + (skill * attack * 0.08) + 18
	return -min, -max
end

combat:setCallback(CallBackParam.SKILLVALUE, callback)

function onCastSpell(creature, variant) return combat:execute(creature, variant) end
