-- Ворота между ярусами (как «5 Bee Zone» в BSS).
-- Вдоль каждого обрыва стоит невидимая стена: если дронов меньше нужного — не пройти наверх.
-- Спускаться можно всегда (стена выключается, если игрок уже выше неё).
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local TierGates = {}
local State
local RED, GREEN = Color3.fromRGB(255, 60, 50), Color3.fromRGB(80, 255, 110)
local shown = {}

local function update()
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("TierGates")
	if not folder then
		return
	end
	local d = State.data
	local have = d and d.equippedTotal or 0
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for _, gate in ipairs(folder:GetChildren()) do
		local req = gate:GetAttribute("Req") or 0
		local open = d ~= nil and have >= req
		local wall = gate:FindFirstChild("Wall")
		if wall then
			local above = hrp and hrp.Position.Z > (wall.Position.Z + 1)
			wall.CanCollide = not open and not above
		end
		if shown[gate] ~= open then
			shown[gate] = open
			local door = gate:FindFirstChild("Door")
			if door then
				door.Transparency = open and 1 or 0.35
			end
			for _, p in ipairs(gate:GetChildren()) do
				if p.Name == "Lamp" then
					p.Color = open and GREEN or RED
					local l = p:FindFirstChildOfClass("PointLight")
					if l then
						l.Color = p.Color
					end
				end
			end
			local beam = gate:FindFirstChild("Beam")
			if beam then
				for _, t in ipairs(beam:GetDescendants()) do
					if t:IsA("TextLabel") and t.Name == "Title" then
						t.Text = (open and "✔ " or "🔒 ") .. req .. " ДРОНОВ"
					end
				end
			end
		end
	end
end

function TierGates.Init(state)
	State = state
	State.Changed:Connect(update)
	task.spawn(function()
		while true do
			pcall(update)
			task.wait(0.3)
		end
	end)
end

return TierGates
