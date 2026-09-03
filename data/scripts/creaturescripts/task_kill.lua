local taskKill = CreatureEvent("TaskKill")

function taskKill.onKill(creature, target)
	local player = creature:getPlayer()
	if not player or not target:isMonster() then
		return true
	end

	local taskId = player:getStorageValue(PlayerStorageKeys.taskCurrentId, -1)
	local task = taskId > 0 and Tasks[taskId]
	if not task then
		return true
	end

	if target:getName():lower() ~= task.creature:lower() then
		return true
	end

	local progress = player:getStorageValue(PlayerStorageKeys.taskCurrentProgress, -1)
	if progress < 0 then
		progress = 0
	end

	if progress < task.killCount then
		player:setStorageValue(PlayerStorageKeys.taskCurrentProgress, progress + 1)
	end

	return true
end

taskKill:register()
