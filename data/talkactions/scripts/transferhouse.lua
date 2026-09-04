-- Registers a house transfer that takes effect ~24h later, finalized by the
-- HouseRentBilling globalevent. See HouseTransfers.initiate,
-- data/scripts/lib/house_rent.lua, for the actual validation/logic --
-- shared with the house client-mod window so both front-ends can't drift.
function onSay(player, words, param)
	if param == "" then
		player:sendCancelMessage("You must specify the name of the player to transfer the house to.")
		return false
	end

	local house = player:getTile():getHouse()
	if not house then
		player:sendCancelMessage("You must stand in your house to initiate a transfer.")
		return false
	end

	local success, targetPlayerOrReason = HouseTransfers.initiate(player, house, param)
	if not success then
		player:sendCancelMessage(targetPlayerOrReason)
		return false
	end

	player:sendTextMessage(MESSAGE_INFO_DESCR, string.format(
		"You have started a transfer of \"%s\" to %s. It will take effect in 24 hours unless cancelled.",
		house:getName(), targetPlayerOrReason:getName()))
	targetPlayerOrReason:sendTextMessage(MESSAGE_INFO_DESCR, string.format(
		"%s has started transferring the house \"%s\" to you. It will take effect in 24 hours.",
		player:getName(), house:getName()))
	return false
end
