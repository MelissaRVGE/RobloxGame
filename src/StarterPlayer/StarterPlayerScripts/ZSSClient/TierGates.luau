-- Ворота между ярусами (как «5 Bee Zone» в BSS).
-- Вдоль каждого обрыва стоит невидимая стена: если дронов меньше нужного — не пройти наверх.
-- Спускаться можно всегда (стена выключается, если игрок уже выше неё).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("ZSS"):WaitForChild("Config"))
local player = Players.LocalPlayer

-- ворота Gate_N ведут на ярус N: сколько дронов нужно, берём из конфига (а не из карты)
local REQ_BY_TIER = {}
for _, f in ipairs(Config.Fields) do
	if f.tier then
		REQ_BY_TIER[f.tier] = f.req
	end
end
local function gateReq(gate)
	local n = tonumber(gate.Name:match("^Gate_(%d+)$"))
	return (n and REQ_BY_TIER[n]) or gate:GetAttribute("Req") or 0
end

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
		local req = gateReq(gate)
		local open = d ~= nil and have >= req
		local wall = gate:FindFirstChild("Wall")
		if wall then
			local above = hrp and hrp.Position.Z > (wall.Position.Z + 1)
			wall.CanCollide = not open and not above
		end
		if shown[gate] ~= open then
			shown[gate] = open
			local door = gate:FindFirstChild("Door")
			-- ворота открываются плавно: дверь тает, лампы перетекают в зелёный
			local ti = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			if door then
				TweenService:Create(door, ti, { Transparency = open and 1 or 0.35 }):Play()
			end
			for _, p in ipairs(gate:GetChildren()) do
				if p.Name == "Lamp" then
					TweenService:Create(p, ti, { Color = open and GREEN or RED }):Play()
					local l = p:FindFirstChildOfClass("PointLight")
					if l then
						TweenService:Create(l, ti, { Color = open and GREEN or RED }):Play()
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
