-- Enforces the vocation-exclusive outfits sold by the Outfitter NPC (see
-- data/scripts/lib/outfit_unlocks.lua). Only outfits with a vocationGroup are
-- restricted here; everything else (default outfits, quest outfits, GM
-- outfit commands, monster outfit changes) passes through untouched.
--
-- Requires data/events/events.xml's Creature.onChangeOutfit entry enabled
-- (enabled="1") for this hook to ever fire — /reload events picks that up.
EventCallback.onChangeOutfit = function(creature, outfit)
	local player = creature:getPlayer()
	if not player or player:getGroup():getAccess() then
		return
	end

	local unlock = OutfitUnlocksByLookType[outfit.lookType]
	if not unlock or not unlock.vocationGroup then
		return
	end

	local group = OutfitVocationGroups[unlock.vocationGroup]
	if not table.contains(group.ids, player:getVocation():getId()) then
		player:sendTextMessage(MESSAGE_STATUS_SMALL,
			string.format("Only the %s vocation may wear the %s outfit.", group.name, unlock.name))
		return false
	end
end

EventCallback:register()
