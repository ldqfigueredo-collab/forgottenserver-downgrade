-- Activates the Whirlwind buff: for its duration, the Assassin's Dagger
-- cleaves all adjacent enemies instead of hitting a single target. The
-- actual cleave logic lives in data/weapons/scripts/whirlwind_cleave.lua,
-- which checks for this condition's subid — WHIRLWIND_SUBID must match here
-- and there.
local WHIRLWIND_SUBID = 1

local combat = Combat()
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_MAGIC_RED)
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

local condition = Condition(CONDITION_ATTRIBUTES)
condition:setParameter(CONDITION_PARAM_TICKS, 10000)
condition:setParameter(CONDITION_PARAM_SUBID, WHIRLWIND_SUBID)
condition:setParameter(CONDITION_PARAM_BUFF_SPELL, true)
combat:addCondition(condition)

function onCastSpell(creature, variant) return combat:execute(creature, variant) end
