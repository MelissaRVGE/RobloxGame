-- Свободные ячейки хотбара на клиенте: что в них лежит, как положить предмет и
-- перетаскивание (мышью — сразу, на телефоне — после короткого удержания).
-- Источники перетаскивания: ячейки инвентаря и сами ячейки хотбара.
-- Цели: ячейки хотбара внизу экрана и полоска хотбара в окне инвентаря.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local Shared = RS:WaitForChild("ZSS")
local Hotbar = require(Shared.Hotbar)
local Shop = require(Shared.ShopConfig)
local Items = require(Shared.ItemsConfig)
local Icons = require(Shared.Icons)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local new = U.new
local C = Color3.fromRGB

local HS = {}
HS.Free = Hotbar.Free
HS.First = Hotbar.First
HS.toast = function() end

-- ===== что лежит в ячейках =====
function HS.List()
	local d = State.data
	return Hotbar.Normalize(d and d.hotbar)
end

function HS.Key(slot)
	return HS.List()[slot] or ""
end

-- картинка, цвет рамки и название предмета по ключу ячейки
function HS.Visual(key)
	local kind, id, it = Hotbar.Parse(key)
	if not kind then
		return nil
	end
	if kind == "shop" then
		local g = Shop.Grades[it.grade or 1] or Shop.Grades[1]
		return { image = Icons[it.icon or id] or "", color = g.color, name = it.name, kind = kind, id = id }
	end
	local tier = Items.Tiers[it.tier]
	return { image = Icons.items and Icons.items[id] or "", color = tier and tier.color or C(200, 200, 200), name = it.name, kind = kind, id = id }
end

function HS.Count(key)
	return Hotbar.Count(key, State.data)
end

-- ключ предмета из инвентаря: расходник магазина или находка с действием
function HS.ShopKey(item)
	return item and item.stack and item.id or nil
end
function HS.FindKey(item)
	return item and item.use and ("f:" .. item.id) or nil
end

-- положить предмет в ячейку (сразу на экране, сервер подтверждает следом)
function HS.Assign(slot, key)
	local d = State.data
	if not d then
		return
	end
	local before = Hotbar.Normalize(d.hotbar)
	local after = Hotbar.Place(before, slot, key)
	local same = true
	for i = 1, HS.Free do
		if before[i] ~= after[i] then
			same = false
		end
	end
	if same then
		return
	end
	d.hotbar = after
	Remotes.SetHotbar:FireServer(slot, key or "")
	State.Set(d)
end

-- использовать предмет из ячейки
function HS.Use(slot)
	local key = HS.Key(slot)
	local kind, id, it = Hotbar.Parse(key)
	if not kind then
		return false
	end
	if HS.Count(key) <= 0 then
		HS.toast(kind == "shop" and ("No “%s”. Buy it in the Shop"):format(it.name) or ("No “%s” in your backpack"):format(it.name), "bad")
		return false
	end
	if kind == "shop" then
		Remotes.UseItem:FireServer(id)
	else
		task.spawn(function()
			local ok, res = pcall(function()
				return Remotes.BagAction:InvokeServer("use", id)
			end)
			if ok and res then
				HS.toast(res.ok and (res.msg or "Done") or (res.err or "Didn't work"), res.ok and "good" or "bad")
			end
		end)
	end
	return true
end

-- ===== наведённый предмет инвентаря: клавиши 3–6 кладут его в ячейку =====
local hoverKey
function HS.SetHover(key)
	hoverKey = key
end
function HS.ClearHover(key)
	if hoverKey == key then
		hoverKey = nil
	end
end
function HS.HoverKey()
	return hoverKey
end

-- ===== перетаскивание =====
local dragGui, root, ghost
local drag -- текущее перетаскивание
local targets = {} -- obj -> { slot, onHover(on), onDragState(on) }
local lastDropAt = 0

local function ensureGui()
	if dragGui then
		return
	end
	dragGui = new("ScreenGui", {
		Name = "ZSS_Drag",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 60,
		Parent = player:WaitForChild("PlayerGui"),
	})
	dragGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = dragGui })
end

local function makeGhost(vis, size)
	ensureGui()
	local g = {}
	g.frame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C(255, 255, 255),
		BackgroundTransparency = 0.05,
		Parent = root,
	}, { U.corner(14), U.grad(U.darken(vis.color, 0.35), C(14, 16, 20), 90) })
	g.stroke = U.stroke(vis.color, 2.5)
	g.stroke.Parent = g.frame
	g.glow = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.9, 1.9), BackgroundTransparency = 1, Image = Icons.glow or "", ImageColor3 = vis.color, ImageTransparency = 0.45, ZIndex = 0, Parent = g.frame })
	g.icon = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), BackgroundTransparency = 1, Image = vis.image, ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = g.frame })
	g.scale = U.scaleOf(g.frame)
	return g
end

local function toLocal(p)
	return p - root.AbsolutePosition
end

local function hitTarget(p)
	local best, bestD
	for obj, t in pairs(targets) do
		if obj.Parent and obj.Visible and obj:IsDescendantOf(game) and (not t.isActive or t.isActive()) then
			local ok = true
			local anc = obj
			while anc and anc:IsA("GuiObject") do
				if not anc.Visible then
					ok = false
					break
				end
				anc = anc.Parent
			end
			if ok then
				local a, s = obj.AbsolutePosition, obj.AbsoluteSize
				local pad = math.max(6, s.X * 0.12) -- небольшой запас, чтобы попасть было легко
				if p.X >= a.X - pad and p.X <= a.X + s.X + pad and p.Y >= a.Y - pad and p.Y <= a.Y + s.Y + pad then
					local d = (a + s / 2 - p).Magnitude
					if not bestD or d < bestD then
						best, bestD = obj, d
					end
				end
			end
		end
	end
	return best
end

local function setHover(obj)
	if drag.hover == obj then
		return
	end
	if drag.hover and targets[drag.hover] then
		targets[drag.hover].onHover(false)
	end
	drag.hover = obj
	if obj then
		targets[obj].onHover(true)
		U.play(U.Sounds.hover, 0.22, 1.25)
		U.tween(drag.g.scale, 0.18, { Scale = 0.92 }, Enum.EasingStyle.Back)
	else
		U.tween(drag.g.scale, 0.18, { Scale = 1.08 }, Enum.EasingStyle.Back)
	end
end

local function finish(p)
	local dr = drag
	drag = nil
	lastDropAt = os.clock()
	for _, t in pairs(targets) do
		t.onDragState(false)
	end
	if dr.hover and targets[dr.hover] then
		targets[dr.hover].onHover(false)
	end
	local g = dr.g
	local target = p and hitTarget(p)
	local tslot = target and targets[target].slot
	if tslot then
		-- влетает в ячейку и растворяется в ней
		local a = target.AbsolutePosition + target.AbsoluteSize / 2
		U.tween(g.frame, 0.16, { Position = UDim2.fromOffset(toLocal(a).X, toLocal(a).Y), Rotation = 0 }, Enum.EasingStyle.Quart)
		U.tween(g.scale, 0.16, { Scale = 0.75 }, Enum.EasingStyle.Quart)
		task.delay(0.12, function()
			U.tween(g.frame, 0.14, { BackgroundTransparency = 1 })
			U.tween(g.stroke, 0.14, { Transparency = 1 })
			U.tween(g.icon, 0.14, { ImageTransparency = 1 })
			U.tween(g.glow, 0.14, { ImageTransparency = 1, Size = UDim2.fromScale(2.8, 2.8) })
		end)
		task.delay(0.32, function()
			g.frame:Destroy()
		end)
		if tslot ~= dr.fromSlot then
			HS.Assign(tslot, dr.key)
			U.play(U.Sounds.chime, 0.35, 1.2)
		end
		return
	end
	if dr.fromSlot then
		-- вынесли из хотбара — ячейка освобождается, предмет «падает» и тает
		HS.Assign(dr.fromSlot, "")
		U.play(U.Sounds.tap, 0.4, 0.8)
		local pos = g.frame.Position
		U.tween(g.frame, 0.3, { Position = pos + UDim2.fromOffset(0, 26), Rotation = g.frame.Rotation + 25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		U.tween(g.scale, 0.3, { Scale = 0.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		U.tween(g.frame, 0.3, { BackgroundTransparency = 1 })
		U.tween(g.stroke, 0.3, { Transparency = 1 })
		U.tween(g.icon, 0.3, { ImageTransparency = 1 })
		U.tween(g.glow, 0.3, { ImageTransparency = 1 })
	else
		-- отпустили мимо — плавно возвращается на место
		local src = dr.source
		if src and src.Parent then
			local a = toLocal(src.AbsolutePosition + src.AbsoluteSize / 2)
			U.tween(g.frame, 0.28, { Position = UDim2.fromOffset(a.X, a.Y), Rotation = 0 }, Enum.EasingStyle.Quart)
		end
		U.tween(g.scale, 0.28, { Scale = 0.7 }, Enum.EasingStyle.Quart)
		task.delay(0.14, function()
			U.tween(g.frame, 0.16, { BackgroundTransparency = 1 })
			U.tween(g.stroke, 0.16, { Transparency = 1 })
			U.tween(g.icon, 0.16, { ImageTransparency = 1 })
			U.tween(g.glow, 0.16, { ImageTransparency = 1 })
		end)
	end
	task.delay(0.4, function()
		g.frame:Destroy()
	end)
end

local function begin(key, source, fromSlot, p)
	local vis = HS.Visual(key)
	if not vis then
		return
	end
	local size = math.clamp(source.AbsoluteSize.X, 52, 72)
	local g = makeGhost(vis, size)
	local lp = toLocal(p)
	g.frame.Position = UDim2.fromOffset(lp.X, lp.Y)
	g.scale.Scale = 0.6
	U.tween(g.scale, 0.25, { Scale = 1.08 }, Enum.EasingStyle.Back)
	drag = { key = key, source = source, fromSlot = fromSlot, g = g, pos = lp, target = lp, rot = 0 }
	for _, t in pairs(targets) do
		t.onDragState(true)
	end
	if HS.onBegin then
		HS.onBegin()
	end
	U.play(U.Sounds.tick, 0.4, 1.3)
end

RunService.RenderStepped:Connect(function(dt)
	if not drag then
		return
	end
	-- иконка догоняет палец/курсор с плавным сглаживанием и чуть наклоняется по ходу движения
	local k = 1 - math.exp(-dt * 28)
	local prev = drag.pos
	drag.pos = prev:Lerp(drag.target, k)
	local vx = (drag.pos.X - prev.X) / math.max(dt, 1e-3)
	drag.rot += (math.clamp(vx * 0.012, -14, 14) - drag.rot) * (1 - math.exp(-dt * 12))
	drag.g.frame.Position = UDim2.fromOffset(drag.pos.X, drag.pos.Y)
	drag.g.frame.Rotation = drag.rot
end)

-- точка указателя в координатах AbsolutePosition
local function pointOf(input)
	return Vector2.new(input.Position.X, input.Position.Y)
end

UIS.InputChanged:Connect(function(input)
	if not drag then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input == drag.input then
		local p = pointOf(input)
		drag.target = toLocal(p)
		setHover(hitTarget(p))
	end
end)

UIS.InputEnded:Connect(function(input)
	if not drag then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input == drag.input then
		finish(pointOf(input))
	end
end)

function HS.IsDragging()
	return drag ~= nil
end

-- true сразу после броска: нажатие на ячейку под пальцем не считается кликом
function HS.JustDropped()
	return os.clock() - lastDropAt < 0.2
end

-- obj можно тащить; getKey() -> ключ предмета или nil; fromSlot() -> номер ячейки хотбара (если это она)
function HS.AttachSource(obj, getKey, fromSlot, onReject)
	obj.InputBegan:Connect(function(input)
		local touch = input.UserInputType == Enum.UserInputType.Touch
		if drag or not (touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			return
		end
		local start = pointOf(input)
		local t0 = os.clock()
		local done = false
		local conns = {}
		local function stop()
			done = true
			for _, c in ipairs(conns) do
				c:Disconnect()
			end
		end
		local function tryBegin(p)
			stop()
			local key = getKey()
			if not key then
				if onReject then
					onReject()
				end
				return
			end
			begin(key, obj, fromSlot and fromSlot() or nil, p)
			if drag then
				drag.input = touch and input or nil
				drag.target = toLocal(p)
				setHover(hitTarget(p))
			end
		end
		table.insert(conns, UIS.InputChanged:Connect(function(ch)
			if done then
				return
			end
			if ch.UserInputType == Enum.UserInputType.MouseMovement or ch == input then
				local p = pointOf(ch)
				local moved = (p - start).Magnitude
				if touch then
					-- на телефоне палец двигает список — тащим только после удержания
					if moved > 14 then
						stop()
					end
				elseif moved > 7 then
					tryBegin(p)
				end
			end
		end))
		table.insert(conns, UIS.InputEnded:Connect(function(e)
			if e == input or e.UserInputType == Enum.UserInputType.MouseButton1 then
				stop()
			end
		end))
		if touch then
			task.delay(0.35, function()
				if not done and os.clock() - t0 >= 0.34 then
					tryBegin(pointOf(input))
				end
			end)
		end
	end)
end

-- obj принимает предметы; onHover(on) — подсветка под указателем, onDragState(on) — идёт перетаскивание,
-- isActive() — можно ли сейчас бросить сюда (например, хотбар под открытым окном — нельзя)
function HS.AddTarget(obj, slot, onHover, onDragState, isActive)
	targets[obj] = { slot = slot, onHover = onHover or function() end, onDragState = onDragState or function() end, isActive = isActive }
	obj.Destroying:Connect(function()
		targets[obj] = nil
	end)
end

return HS
