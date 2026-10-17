-- Zombie Swarm Simulator — клиентская точка входа
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = RS:WaitForChild("ZSS")
local Remotes = Shared:WaitForChild("Remotes")

local State = require(script.State)
local FX = require(script.FX)
local Renderer = require(script.DroneRenderer)
local ZombieAnim = require(script.ZombieAnim)
local WorldFX = require(script.WorldFX)
local UI = require(script.UI)
local PlayerAnim = require(script.PlayerAnim)
local DayNight = require(script.DayNight)
local TierGates = require(script.TierGates)
local FieldTilesFX = require(script.FieldTilesFX)
local OwnerOnly = require(script.OwnerOnly)
local WorldLOD = require(script.WorldLOD)

OwnerOnly.Init()
FX.Init(Renderer)
Renderer.Init(FX)
ZombieAnim.Init()
WorldFX.Init()
PlayerAnim.Init()
FX.PlayerAnim = PlayerAnim
DayNight.Init()
UI.Init()
TierGates.Init(State, UI)
FieldTilesFX.Init()
task.spawn(WorldLOD.Init) -- ждёт карту, не задерживая загрузку данных

Remotes.DataSync.OnClientEvent:Connect(State.Set)
task.spawn(function()
	local ok, data = pcall(function()
		return Remotes.GetData:InvokeServer()
	end)
	if ok and data and not State.data then
		State.Set(data)
	end
end)

-- ===== ИНСТРУМЕНТ «Скребок» =====
local function hookTool(tool)
	if not tool:IsA("Tool") or tool:GetAttribute("ZSSHooked") then
		return
	end
	tool:SetAttribute("ZSSHooked", true)
	local Shop = require(Shared.ShopConfig)
	local last = 0
	tool.Activated:Connect(function()
		local id = tool:GetAttribute("ZSSWeapon")
		local item = Shop.ById[id or ""]
		local cd = item and item.stats and item.stats.cd or 0.45
		local now = os.clock()
		if now - last < cd * 0.85 then
			return
		end
		last = now
		Remotes.Scoop:FireServer()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			FX.Scoop(hrp.Position + hrp.CFrame.LookVector * 2.5 - Vector3.new(0, 2.5, 0))
		end
		-- своя анимация удара у каждого оружия
		PlayerAnim.Play(char, id)
	end)
end

local function watchContainer(c)
	for _, t in ipairs(c:GetChildren()) do
		hookTool(t)
	end
	c.ChildAdded:Connect(hookTool)
end

player.CharacterAdded:Connect(watchContainer)
if player.Character then
	watchContainer(player.Character)
end
watchContainer(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(function()
	watchContainer(player:WaitForChild("Backpack"))
end)
