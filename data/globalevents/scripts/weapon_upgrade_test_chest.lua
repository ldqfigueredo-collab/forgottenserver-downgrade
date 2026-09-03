-- Test-only content: stocks a chest next to Eryn (Thais temple) with enough
-- runes to push a weapon from +0 to +13, for manually testing the weapon
-- upgrade system (see data/scripts/actions/others/weapon_upgrade.lua).
-- Runs on every real boot (type="startup"), so the chest and its contents
-- reappear after a container restart the same way the Task/Promotion Master
-- NPCs do -- regular ground items are not saved back to the map on shutdown.
function onStartup()
	local chest = Game.createItem(1740, 1, Position(32370, 32244, 7))
	if not chest then return true end

	local container = Container(chest.uid)
	if not container then return true end

	container:addItem(2376, 1) -- sword (melee test weapon)
	container:addItem(2456, 1) -- bow (distance test weapon)
	container:addItem(7759, 100) -- rune of empowerment
	container:addItem(7759, 100) -- rune of empowerment
	container:addItem(8310, 100) -- rune of ascension
	container:addItem(8310, 100) -- rune of ascension
	container:addItem(8301, 20) -- rune of protection

	return true
end
