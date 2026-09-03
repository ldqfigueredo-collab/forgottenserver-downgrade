-- Weapon upgrade system: use a rune on a weapon for a chance to enchant it.
-- Level (and protection charges) live entirely on the weapon item itself
-- (custom attributes), not on the player.
--
-- Bonus is applied via item:setAttribute("attack", n) — persisted correctly
-- (src/item.cpp's serializeAttr/unserializeAttr both handle ATTR_ATTACK).
-- item:setBoostPercent() was tried first and scales more elegantly across
-- weapon types, but src/item.cpp's serializeAttr never writes ATTR_BOOST back
-- out (only the legacy read path exists) — it silently doesn't survive a
-- server restart or even a relog, which fails this feature's core "permanent
-- upgrade" premise. Not used for that reason.
--
-- Distance weapons (bow/crossbow) get a synthetic non-zero virtual base
-- attack (distanceVirtualBaseAttack) instead of their true items.xml base of
-- 0 — real Tibia gives launchers 0 base attack (damage comes from the ammo),
-- so a %-of-base bonus on the true value would always be a no-op. The
-- resulting bonus still applies for real: src/weapons.cpp's
-- WeaponDistance::getWeaponDamage adds the equipped launcher's own
-- item->getAttack() on top of the ammo's attack for any WEAPON_AMMO shot.
--
-- Wands/rods are deliberately NOT included (see validWeaponTypes below) —
-- their real damage is min/max from weapons.xml, not items.xml "attack", and
-- setting a non-zero attack override on them switches src/weapons.cpp's
-- WeaponWand::getWeaponDamage to a completely different magic-level-scaled
-- formula instead of scaling the curated min/max, which isn't safe to
-- calibrate as a quick fix. Needs its own design pass (e.g. a temporary
-- magic-level buff condition applied on equip) before Sorcerer/Druid can be
-- covered — flagged, not silently shipped half-working.
local validWeaponTypes = {
	[WEAPON_SWORD] = true,
	[WEAPON_CLUB] = true,
	[WEAPON_AXE] = true,
	[WEAPON_DISTANCE] = true
}

local distanceVirtualBaseAttack = 10

local protectionRuneId = 8301
local maxProtectionCharges = 5

local runes = {
	[7759] = { -- rune of empowerment: +0 to +9 -> +1 to +10
		minLevel = 0,
		maxLevel = 9,
		downgradeOnFail = false,
		rangeMessage = "This rune only works on a weapon between +0 and +9.",
		chances = {
			[0] = 100,
			[1] = 95,
			[2] = 90,
			[3] = 80,
			[4] = 70,
			[5] = 60,
			[6] = 50,
			[7] = 40,
			[8] = 30,
			[9] = 20
		}
	},
	[8310] = { -- rune of ascension: +10 to +12 -> +11 to +13
		minLevel = 10,
		maxLevel = 12,
		downgradeOnFail = true,
		rangeMessage = "This rune only works on a weapon of +10 or higher, below +13.",
		chances = {
			[10] = 30,
			[11] = 20,
			[12] = 10
		}
	}
}

local function getBonusPercent(level)
	local tier1Levels = math.min(level, 10)
	local tier2Levels = math.max(level - 10, 0)
	return tier1Levels * 2 + tier2Levels * 4
end

local function refreshDescription(weapon, level, protectionCharges)
	local bonusPercent = getBonusPercent(level)
	local description = "This weapon has been upgraded to +" .. level .. " (+" ..
		                     bonusPercent .. "% attack)."
	if protectionCharges and protectionCharges > 0 then
		description = description .. " Protected against " .. protectionCharges ..
			               " failed upgrade" ..
			               (protectionCharges > 1 and "s" or "") .. "."
	end
	weapon:setAttribute("description", description)
end

local function applyLevel(weapon, level, baseAttack, baseName, protectionCharges)
	local bonusPercent = getBonusPercent(level)
	local newAttack = baseAttack + math.floor(baseAttack * bonusPercent / 100)
	weapon:setAttribute("attack", newAttack)
	weapon:setAttribute("name", "+" .. level .. " " .. baseName)
	weapon:setCustomAttribute("upgradeLevel", level)
	refreshDescription(weapon, level, protectionCharges)
end

local function getWeaponType(target)
	if type(target) ~= "userdata" or not target:isItem() then return nil end
	local weaponType = ItemType(target:getId()):getWeaponType()
	if not validWeaponTypes[weaponType] then return nil end
	return weaponType
end

local function getBaseAttack(target, weaponType)
	if weaponType == WEAPON_DISTANCE then return distanceVirtualBaseAttack end
	return ItemType(target:getId()):getAttack()
end

local weaponUpgrade = Action()

function weaponUpgrade.onUse(player, item, fromPosition, target, toPosition,
                             isHotkey)
	local itemId = item:getId()

	local weaponType = getWeaponType(target)
	if not weaponType then
		player:sendCancelMessage("You can only use this on a weapon.")
		return true
	end

	local level = target:getCustomAttribute("upgradeLevel") or 0
	local protectionCharges = target:getCustomAttribute("protectionCharges") or 0

	if itemId == protectionRuneId then
		if level < 10 or level > 12 then
			player:sendCancelMessage(
				"This rune only protects a weapon of +10, +11 or +12, before a masterwork upgrade attempt.")
			return true
		end

		if protectionCharges >= maxProtectionCharges then
			player:sendCancelMessage(
				"This weapon is already protected as much as it can be.")
			return true
		end

		item:remove(1)
		protectionCharges = protectionCharges + 1
		target:setCustomAttribute("protectionCharges", protectionCharges)
		refreshDescription(target, level, protectionCharges)
		target:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
		player:say(
			"Your weapon is now protected against " .. protectionCharges ..
				" failed upgrade" .. (protectionCharges > 1 and "s" or "") .. ".",
			TALKTYPE_MONSTER_SAY)
		return true
	end

	local rune = runes[itemId]
	if not rune then return false end

	if level < rune.minLevel or level > rune.maxLevel then
		player:sendCancelMessage(rune.rangeMessage)
		return true
	end

	local baseAttack = getBaseAttack(target, weaponType)
	local baseName = ItemType(target:getId()):getName()

	item:remove(1)

	if math.random(100) <= rune.chances[level] then
		local newLevel = level + 1
		applyLevel(target, newLevel, baseAttack, baseName, protectionCharges)
		target:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
		player:say("Your weapon has been upgraded to +" .. newLevel .. "!",
		          TALKTYPE_MONSTER_SAY)
	else
		target:getPosition():sendMagicEffect(CONST_ME_POFF)
		if rune.downgradeOnFail and level > rune.minLevel then
			if protectionCharges > 0 then
				protectionCharges = protectionCharges - 1
				target:setCustomAttribute("protectionCharges", protectionCharges)
				refreshDescription(target, level, protectionCharges)
				player:say(
					"The upgrade failed, but your weapon's protection absorbed the setback! (" ..
						protectionCharges .. " protection" ..
						(protectionCharges ~= 1 and "s" or "") .. " left)",
					TALKTYPE_MONSTER_SAY)
			else
				local newLevel = level - 1
				applyLevel(target, newLevel, baseAttack, baseName, 0)
				player:say(
					"The upgrade failed and your weapon slipped to +" .. newLevel ..
						"!", TALKTYPE_MONSTER_SAY)
			end
		else
			player:say(
				"The upgrade failed, but your weapon was unaffected.",
				TALKTYPE_MONSTER_SAY)
		end
	end

	return true
end

weaponUpgrade:id(7759, 8310, protectionRuneId)
weaponUpgrade:register()
