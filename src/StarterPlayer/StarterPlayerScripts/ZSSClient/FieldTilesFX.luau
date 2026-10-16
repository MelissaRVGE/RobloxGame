-- Прогибание плиток полей, как в Bee Swarm Simulator: собранная плитка вместе со своим
-- ресурсом плавно уходит вниз, а по мере восстановления так же плавно поднимается.
-- Сервер пишет полноту в атрибут Fill, двигаем плитки только здесь и только при изменении.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(RS:WaitForChild("ZSS"):WaitForChild("Config"))

local FieldTilesFX = {}

local DOWN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- восстановление приходит шагами раз в секунду: линейная анимация чуть длиннее шага
-- склеивает шаги в одно непрерывное движение вверх
local REGEN = TweenInfo.new(1.05, Enum.EasingStyle.Linear)
local REFILL = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local tiles = {} -- part -> state

local function play(st, info)
	local dy = -Config.TileDepth * (1 - st.fill)
	for i, inst in ipairs(st.parts) do
		if st.tweens[i] then
			st.tweens[i]:Cancel()
		end
		local tw = TweenService:Create(inst, info, { CFrame = st.base[i] + Vector3.new(0, dy, 0) })
		st.tweens[i] = tw
		tw:Play()
	end
end

local function track(part)
	if tiles[part] or not part:IsA("BasePart") then
		return
	end
	local st = { parts = { part }, base = { part.CFrame }, tweens = {}, fill = 1 }
	local function addRes(res)
		if res.Name == "Res" and res:IsA("BasePart") and not table.find(st.parts, res) then
			-- сервер не двигает модель ресурса, её CFrame — на полной высоте;
			-- если она пришла позже плитки, сразу опускаем её вслед за плиткой
			table.insert(st.parts, res)
			table.insert(st.base, res.CFrame)
			res.CFrame += Vector3.new(0, part.CFrame.Y - st.base[1].Y, 0)
		end
	end
	for _, c in ipairs(part:GetChildren()) do
		addRes(c)
	end
	part.ChildAdded:Connect(addRes)
	tiles[part] = st
	local function apply(instant)
		local f = part:GetAttribute("Fill") or 1
		if f == st.fill and not instant then
			return
		end
		local old = st.fill
		st.fill = f
		if instant then
			local dy = -Config.TileDepth * (1 - f)
			for i, inst in ipairs(st.parts) do
				inst.CFrame = st.base[i] + Vector3.new(0, dy, 0)
			end
		elseif f < old then
			play(st, DOWN)
		elseif f - old > 0.1 then
			play(st, REFILL)
		else
			play(st, REGEN)
		end
	end
	part:GetAttributeChangedSignal("Fill"):Connect(function()
		apply(false)
	end)
	part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			tiles[part] = nil
		end
	end)
	if (part:GetAttribute("Fill") or 1) < 1 then
		apply(true)
	end
end

local function watchField(folder)
	local tf = folder:WaitForChild("Tiles", 30)
	if not tf then
		return
	end
	for _, t in ipairs(tf:GetChildren()) do
		track(t)
	end
	-- при стриминге плитки могут подгружаться позже
	tf.ChildAdded:Connect(function(t)
		task.defer(track, t)
	end)
end

function FieldTilesFX.Init()
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local root = map:WaitForChild("Fields")
		for _, f in ipairs(root:GetChildren()) do
			task.spawn(watchField, f)
		end
		root.ChildAdded:Connect(function(f)
			task.spawn(watchField, f)
		end)
	end)
end

return FieldTilesFX
