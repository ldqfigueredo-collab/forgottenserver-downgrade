-- Real-time house rent billing + delayed-transfer finalization. The engine's
-- own Houses::payHouses (src/house.cpp) only ever runs once, at server
-- startup (src/otserv.cpp) -- nothing calls it again while the process is
-- up. This globalevent supersedes it for ongoing billing; the boot-time
-- call is left in place to catch whatever accrued while the server was
-- down. See data/scripts/lib/house_rent.lua for the actual logic.
local event = GlobalEvent("HouseRentBilling")

function event.onTime(interval)
	local currentTime = os.time()

	for _, house in ipairs(Game.getHouses()) do
		if house:getOwnerGuid() ~= 0 then HouseRent.processDue(house, currentTime) end
	end

	HouseTransfers.processDue(currentTime)
	return true
end

event:interval(60 * 60 * 1000) -- hourly
event:register()
