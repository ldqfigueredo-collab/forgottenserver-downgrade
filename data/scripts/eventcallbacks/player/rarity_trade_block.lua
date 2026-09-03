-- Blocks trading a bind-on-pickup rarity item (legendary tier — see
-- data/scripts/lib/rarity.lua). Only checks the traded item itself, not
-- its container contents, matching the existing v1-scope precedent in
-- data/scripts/lib/autoloot_blacklist.lua (top-level only).
local event = Event()

event.onTradeRequest = function(self, target, item)
	if Rarity.isBoundOnPickup(item) then
		self:sendCancelMessage(
			"This legendary item is bound to you and cannot be traded.")
		return false
	end
	return true
end

event:register()
