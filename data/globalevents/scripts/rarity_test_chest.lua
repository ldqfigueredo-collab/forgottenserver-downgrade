-- Test-only content: stocks a chest next to Eryn (Thais temple) with one
-- dagger (item 2379) at each rarity tier, for manually eyeballing the item
-- rarity system (see data/scripts/lib/rarity.lua). The three non-normal
-- daggers are forced to their tier via Rarity.forceApplyTier -- bypassing
-- the random roll entirely, since this is for visual inspection, not a
-- drop-rate test. Runs on every real boot (type="startup"), so the chest
-- reappears after a container restart the same way the weapon-upgrade test
-- chest and the Task/Promotion Master NPCs do -- regular ground items are
-- not saved back to the map on shutdown.
function onStartup()
	-- Same tile as the weapon-upgrade test chest (confirmed reachable in
	-- live play) rather than a guessed nearby tile -- the +2-tiles-east
	-- guess used previously landed inside a wall. Tiles can stack multiple
	-- items, so two chests coexisting here is fine.
	local chest = Game.createItem(1740, 1, Position(32370, 32244, 7))
	if not chest then return true end

	local container = Container(chest.uid)
	if not container then return true end

	container:addItem(2379, 1) -- normal dagger, untouched

	local rare = container:addItem(2379, 1)
	if rare then Rarity.forceApplyTier(rare, Rarity.RARE) end

	local epic = container:addItem(2379, 1)
	if epic then Rarity.forceApplyTier(epic, Rarity.EPIC) end

	local legendary = container:addItem(2379, 1)
	if legendary then Rarity.forceApplyTier(legendary, Rarity.LEGENDARY) end

	return true
end
