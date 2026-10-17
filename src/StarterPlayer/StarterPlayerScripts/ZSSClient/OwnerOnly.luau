-- Личные зомби и сферы-баффы: сервер помечает их атрибутом Owner (UserId владельца).
-- Чужие убираются из мира только на этом клиенте: их не видно, они не мешают
-- ходить и не попадают в лучи. Сервер по-прежнему ведёт их и сам удалит.
local Players = game:GetService("Players")

local OwnerOnly = {}
local myId = Players.LocalPlayer.UserId

local function check(inst, only)
	if only and inst.Name ~= only then
		return
	end
	local owner = inst:GetAttribute("Owner")
	if owner and owner ~= myId then
		-- отложено: прямо в ChildAdded менять Parent нельзя
		task.defer(function()
			if inst.Parent then
				inst.Parent = nil
			end
		end)
	end
end

-- only: прятать только объекты с этим именем
local function watch(name, only)
	task.spawn(function()
		local folder = workspace:WaitForChild(name)
		for _, c in ipairs(folder:GetChildren()) do
			check(c, only)
		end
		folder.ChildAdded:Connect(function(c)
			check(c, only)
		end)
	end)
end

function OwnerOnly.Init()
	watch("Zombies")
	-- ящички-находки остаются общими: через время их может взять любой
	watch("Pickups", "BuffPickup")
end

return OwnerOnly
