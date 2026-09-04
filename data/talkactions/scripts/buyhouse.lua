-- Door-based purchase. All the actual checks/price/rent-charge logic live in
-- HousePurchase.buy (data/scripts/lib/house_rent.lua), shared with the house
-- client-mod window's direct "buy_house" opcode action.
function onSay(player, words, param)
	local position = player:getPosition()
	position:getNextPosition(player:getDirection())

	local tile = Tile(position)
	local house = tile and tile:getHouse()
	if not house then
		player:sendCancelMessage(
			"You have to be looking at the door of the house you would like to buy.")
		return false
	end

	local success, reason = HousePurchase.buy(player, house)
	if not success then
		player:sendCancelMessage(reason)
		return false
	end

	player:sendTextMessage(MESSAGE_INFO_DESCR,
	                       "You have successfully bought this house. The first rent period has been charged from your bank account.")
	return false
end
