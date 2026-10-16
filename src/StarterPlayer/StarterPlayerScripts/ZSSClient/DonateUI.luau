-- Донат-магазин (как в Bee Swarm Simulator): пропуска, гемы и наборы за Robux.
-- У каждого предложения своя иконка и своя «живая» анимация карточки; покупка — окно оплаты Roblox,
-- после выдачи сервер присылает DonateDone, и на экране играет праздник.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = RS:WaitForChild("ZSS")
local DC = require(Shared.DonateConfig)
local Icons = require(Shared.Icons)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local new = U.new
local C = Color3.fromRGB
local ROBUX = utf8.char(0xE002) -- значок Robux в шрифтах Roblox

local DUI = {}
local api
local win, winScale
local tab = "passes"
local cards = {} -- key -> card
local tabs = {} -- key -> { b, fill, label }
local tabLine
local gridLayout
local footer
local hovered
local switching = 0

local W, H = 920, 664
local CW, CH = 284, 226

local function dn(key)
	return Icons.dn and Icons.dn[key] or ""
end

local function owned(o)
	local d = State.data
	if not d then
		return false
	end
	if o.kind == "pass" then
		return d.passes and d.passes[o.key] == true
	end
	return o.once and d.donateOnce and d.donateOnce[o.key] == true
end

-- ===== карточки =====
local function priceText(o)
	return ROBUX .. " " .. U.fmt(o.price)
end

local function styleBuy(card)
	local o = card.o
	local b = card.buy
	if owned(o) then
		b.Text = o.kind == "pass" and "✔ КУПЛЕНО" or "✔ ПОЛУЧЕНО"
		U.gradTo(card.buyGrad, C(120, 125, 135), C(70, 74, 82))
		card.buyStroke.Color = C(170, 175, 185)
		card.check.Visible = true
	else
		b.Text = card.note or (card.busy and "• • •") or priceText(o)
		b.TextSize = card.note and 14 or 20
		U.gradTo(card.buyGrad, C(110, 235, 90), C(30, 150, 50))
		card.buyStroke.Color = C(200, 255, 170)
		card.check.Visible = false
	end
end

local function sparkleAt(parent, pos, color, z)
	local sp = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Icons.twinkle,
		ImageColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(6, 6),
		ZIndex = z or 8,
		Parent = parent,
	})
	U.tween(sp, 0.25, { Size = UDim2.fromOffset(22, 22), Rotation = 90 }, Enum.EasingStyle.Back)
	task.delay(0.3, function()
		U.tween(sp, 0.35, { Size = UDim2.fromOffset(4, 4), ImageTransparency = 1, Rotation = 180 })
	end)
	Debris:AddItem(sp, 0.7)
end

local function buy(card)
	local o = card.o
	if card.busy or owned(o) then
		if owned(o) then
			U.pulseScale(card.buy, 1.08)
		end
		return
	end
	card.busy = true
	styleBuy(card)
	local ok, res = pcall(function()
		return Remotes.DonateBuy:InvokeServer(o.key)
	end)
	local failed = not ok or not res or not res.ok
	if failed then
		api.toast(res and res.err or "Магазин Roblox не отвечает", res and res.soon and "info" or "bad")
		-- уведомления наверху может закрывать окно, поэтому ответ видно и на самой кнопке
		card.note = res and res.soon and "⏳ СКОРО В ПРОДАЖЕ" or "✖ НЕ ВЫШЛО"
		-- кнопка «качает головой»
		local b = card.buy
		for k, r in ipairs({ -6, 5, -3, 0 }) do
			task.delay((k - 1) * 0.06, function()
				U.tween(b, 0.06, { Rotation = r })
			end)
		end
	end
	-- окно оплаты Roblox открылось (или отказ) — через секунду кнопка снова активна
	if failed then
		card.busy = false
		styleBuy(card)
	end
	task.delay(failed and 1.6 or 1.2, function()
		card.busy = false
		card.note = nil
		styleBuy(card)
	end)
end

local function makeCard(grid, o)
	local col = o.color
	local card = { o = o, fx = {}, ph = o.index * 0.77 }
	-- лучи обрезаются по краю карточки; у картинки лучей мягкий спад к краям, поэтому углы не видны
	local root = new("Frame", {
		Name = o.key,
		Size = UDim2.fromOffset(CW, CH),
		BackgroundColor3 = C(255, 255, 255),
		ClipsDescendants = true,
		Parent = grid,
	}, {
		U.corner(16),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(col:Lerp(C(20, 16, 34), 0.62), C(16, 13, 26)) }),
	})
	card.root = root
	-- ячейка сетки: держит рамку и общий масштаб карточки
	local frame = new("Frame", {
		Name = o.key .. "_Frame",
		Size = UDim2.fromOffset(CW, CH),
		BackgroundTransparency = 1,
		LayoutOrder = o.index,
		Visible = false,
		Parent = grid,
	})
	root.Parent = frame
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	card.frame = frame
	card.scale = U.scaleOf(frame) -- общий масштаб карточки и её рамки
	card.stroke = U.stroke(col, 2, 0.15)
	card.stroke.Parent = frame
	new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = frame })
	frame:SetAttribute("Card", true)

	-- лучи, свечение и иконка
	local stage = new("Frame", { Size = UDim2.new(1, 0, 0, 132), BackgroundTransparency = 1, Parent = root })
	card.stage = stage
	card.rays = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = dn("rays"),
		ImageColor3 = col,
		ImageTransparency = 0.55,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(250, 250),
		Parent = stage,
	})
	card.glow = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Icons.glow,
		ImageColor3 = col,
		ImageTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(170, 170),
		ZIndex = 2,
		Parent = stage,
	})
	card.glowScale = U.scaleOf(card.glow)
	-- обёртка иконки: её UIScale — покадровое «дыхание», UIScale самой иконки — наведение
	local wrap = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(108, 108),
		ZIndex = 4,
		Parent = stage,
	})
	card.wrapScale = new("UIScale", { Parent = wrap })
	card.icon = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = dn(o.key),
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
		Parent = wrap,
	})
	card.iconScale = U.scaleOf(card.icon)
	-- пока иконки не загружены — эмодзи вкладки, чтобы карточка не была пустой
	if card.icon.Image == "" then
		local tb = DC.Tabs[1]
		for _, t in ipairs(DC.Tabs) do
			if t.key == o.tab then
				tb = t
			end
		end
		new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = tb.icon, TextScaled = true, Font = Enum.Font.GothamBlack, Parent = card.icon })
	end

	-- особые слои анимаций
	if o.anim == "orbit" or o.anim == "capsule" or o.anim == "crown" then
		for k = 1, 3 do
			local sp = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.twinkle, ImageColor3 = col:Lerp(C(255, 255, 255), 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), ZIndex = 5, Parent = stage })
			table.insert(card.fx, sp)
		end
	elseif o.anim == "dash" then
		for k = 1, 4 do
			local ln = new("Frame", { BackgroundColor3 = col:Lerp(C(255, 255, 255), 0.4), BackgroundTransparency = 0.25, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 34 + k * 6, 0, 4), ZIndex = 3, Parent = stage }, { U.round() })
			table.insert(card.fx, ln)
		end
	elseif o.anim == "gems" then
		for k = 1, 2 + o.level * 2 do
			local g = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.gem, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14 + (k % 3) * 4, 14 + (k % 3) * 4), ImageTransparency = 0.15, ZIndex = 3, Parent = stage })
			table.insert(card.fx, { g = g, x = ((k * 0.618) % 1) * 0.84 + 0.08, sp = 0.32 + (k % 4) * 0.08, off = (k * 0.37) % 1 })
		end
	end
	if o.anim == "crown" or o.anim == "gift" or o.anim == "capsule" or o.anim == "rainbow" then
		card.sheen = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.4, 0, 0.5, 0), Size = UDim2.new(0, 26, 2, 0), Rotation = 22, BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 6, Parent = root })
		card.nextSheen = os.clock() + 1 + o.index * 0.4
	end

	-- ленточка в углу
	if o.badge then
		local rib = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -30, 0, 30),
			Size = UDim2.fromOffset(150, 26),
			Rotation = 45,
			BackgroundColor3 = C(255, 255, 255),
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = root,
		}, { new("UIGradient", { Color = ColorSequence.new(C(255, 70, 90), C(255, 150, 40)) }) })
		new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = o.badge, TextSize = 14, TextColor3 = C(255, 255, 255), ZIndex = 8, Parent = rib }, { U.textStroke(C(90, 0, 20), 1.5) })
		card.ribbon = rib
	end

	new("TextLabel", {
		Position = UDim2.fromOffset(10, 124),
		Size = UDim2.new(1, -20, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = o.name,
		TextScaled = true,
		TextColor3 = C(255, 255, 255),
		ZIndex = 5,
		Parent = root,
	}, { U.textStroke(C(0, 0, 0), 1.6), new("UITextSizeConstraint", { MaxTextSize = 21 }) })
	new("TextLabel", {
		Position = UDim2.fromOffset(10, 151),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = o.short,
		TextScaled = true,
		TextColor3 = col:Lerp(C(255, 255, 255), 0.45),
		ZIndex = 5,
		Parent = root,
	}, { U.textStroke(C(0, 0, 0), 1.2), new("UITextSizeConstraint", { MaxTextSize = 15 }) })

	-- кнопка цены
	local b = api.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(170, 40),
		BackgroundColor3 = C(255, 255, 255),
		Font = Enum.Font.GothamBlack,
		Text = priceText(o),
		TextSize = 20,
		TextColor3 = C(255, 255, 255),
		ZIndex = 6,
		Parent = root,
	}, function()
		buy(card)
	end)
	U.corner(12).Parent = b
	U.textStroke(C(0, 50, 10), 1.6).Parent = b
	card.buyGrad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(110, 235, 90), C(30, 150, 50)), Parent = b })
	card.buyStroke = U.stroke(C(200, 255, 170), 2, 0.2)
	card.buyStroke.Parent = b
	card.buy = b
	card.check = new("TextLabel", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = C(70, 200, 80),
		Font = Enum.Font.GothamBlack,
		Text = "✔",
		TextSize = 18,
		TextColor3 = C(255, 255, 255),
		Visible = false,
		ZIndex = 7,
		Parent = root,
	}, { U.round(), U.stroke(C(255, 255, 255), 2) })

	-- наведение: карточка приподнимается, иконка увеличивается, свечение и рамка ярче
	root.MouseEnter:Connect(function()
		card.hover = true
		hovered = card
		U.tween(card.scale, 0.2, { Scale = 1.035 }, Enum.EasingStyle.Back)
		U.tween(card.iconScale, 0.25, { Scale = 1.12 }, Enum.EasingStyle.Back)
		U.tween(card.glow, 0.2, { ImageTransparency = 0.1 })
		U.tween(card.stroke, 0.2, { Thickness = 3.5, Transparency = 0 })
		U.tween(card.rays, 0.3, { ImageTransparency = 0.3 })
		DUI.ShowInfo(o)
		U.play(U.Sounds.hover, 0.15, 1.15)
	end)
	root.MouseLeave:Connect(function()
		card.hover = false
		if hovered == card then
			hovered = nil
			DUI.ShowInfo(nil)
		end
		U.tween(card.scale, 0.2, { Scale = 1 })
		U.tween(card.iconScale, 0.25, { Scale = 1 })
		U.tween(card.glow, 0.2, { ImageTransparency = 0.35 })
		U.tween(card.stroke, 0.2, { Thickness = 2, Transparency = 0.15 })
		U.tween(card.rays, 0.3, { ImageTransparency = 0.55 })
	end)
	root.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		-- клик по карточке: иконка подпрыгивает с искрами (покупка — только кнопкой)
		card.jump = os.clock()
		for k = 1, 4 do
			sparkleAt(stage, UDim2.new(0.5 + (math.random() - 0.5) * 0.5, 0, 0, 64 + math.random(-40, 40)), col:Lerp(C(255, 255, 255), 0.4))
		end
		DUI.ShowInfo(o)
	end)
	cards[o.key] = card
	styleBuy(card)
	return card
end

-- покадровая анимация карточки (своя у каждого вида)
local function animate(card, t, dt)
	local o = card.o
	local ph = card.ph
	local rot, sc = 0, 1
	local raySpeed = 14
	local a = o.anim
	if a == "spin" then
		raySpeed = 70
		sc = 1 + 0.035 * math.sin(t * 5 + ph)
		rot = math.sin(t * 1.4 + ph) * 4
	elseif a == "bounce" then
		local k = math.abs(math.sin(t * 2.6 + ph))
		sc = 0.97 + 0.07 * k
		rot = math.sin(t * 2.6 + ph) * 5
	elseif a == "orbit" then
		rot = math.sin(t * 1.5 + ph) * 6
		for i, sp in ipairs(card.fx) do
			local ang = t * 1.6 + i * math.pi * 2 / 3
			sp.Position = UDim2.new(0.5 + math.cos(ang) * 0.27, 0, (64 + math.sin(ang) * 46) / 132, 0)
			sp.Rotation = t * 120 + i * 40
			sp.ImageTransparency = 0.2 + 0.4 * (0.5 + 0.5 * math.sin(ang))
		end
	elseif a == "dash" then
		rot = -7 + math.sin(t * 7 + ph) * 3
		for i, ln in ipairs(card.fx) do
			local k = (t * 1.3 + i * 0.27) % 1
			ln.Position = UDim2.new(0.42 - k * 0.42, 0, (44 + i * 13) / 132, 0)
			ln.BackgroundTransparency = 0.15 + 0.85 * k
		end
	elseif a == "swing" then
		rot = math.sin(t * 2.2 + ph) * 11
	elseif a == "crown" then
		raySpeed = 22
		sc = 1 + 0.03 * math.sin(t * 2 + ph)
		rot = math.sin(t * 1.2 + ph) * 3
		for i, sp in ipairs(card.fx) do
			local k = (t * 0.45 + i / 3) % 1
			sp.Position = UDim2.new(0.5 + (i - 2) * 0.22, 0, (110 - k * 90) / 132, 0)
			sp.ImageTransparency = math.abs(k - 0.5) * 2
			sp.Rotation = k * 200
		end
	elseif a == "gems" then
		rot = math.sin(t * 1.8 + ph) * 5
		sc = 1 + 0.03 * math.sin(t * 3.1 + ph)
		for _, f in ipairs(card.fx) do
			local k = (t * f.sp + f.off) % 1
			f.g.Position = UDim2.new(f.x, 0, k * 1.15 - 0.08, 0)
			f.g.Rotation = k * 180
			f.g.ImageTransparency = 0.15 + 0.85 * math.max(0, (k - 0.75) / 0.25)
		end
	elseif a == "capsule" then
		rot = math.sin(t * 1.6 + ph) * 9
		local pulse = 0.5 + 0.5 * math.sin(t * 3 + ph)
		card.glowScale.Scale = 0.95 + 0.15 * pulse
		for i, sp in ipairs(card.fx) do
			local k = (t * 0.6 + i / 3) % 1
			local ang = i * 2.1
			sp.Position = UDim2.new(0.5 + math.cos(ang) * 0.3, 0, (64 + math.sin(ang) * 48) / 132, 0)
			sp.ImageTransparency = math.abs(k - 0.5) * 2
			sp.Rotation = k * 180
		end
	elseif a == "gift" then
		rot = math.sin(t * 1.3 + ph) * 3
		-- раз в 2.6 с подарок подпрыгивает и трясётся
		local k = ((t + ph) % 2.6) / 0.5
		if k < 1 then
			sc = 1 + math.sin(k * math.pi) * 0.12
			rot += math.sin(k * math.pi * 4) * 9 * (1 - k)
			if not card.hopped then
				card.hopped = true
				for i = 1, 5 do
					sparkleAt(card.stage, UDim2.new(0.5 + (math.random() - 0.5) * 0.6, 0, 0, 64 + math.random(-46, 30)), Color3.fromHSV(math.random(), 0.5, 1), 5)
				end
			end
		else
			card.hopped = false
		end
	elseif a == "shake" then
		local k = ((t + ph) % 2.2) / 0.45
		rot = k < 1 and math.sin(k * math.pi * 6) * 8 * (1 - k) or math.sin(t * 1.4) * 2
	elseif a == "recycle" then
		raySpeed = -40
		rot = math.sin(t * 1.7 + ph) * 6
	elseif a == "rainbow" then
		raySpeed = 30
		local c = Color3.fromHSV((t * 0.18) % 1, 0.6, 1)
		card.rays.ImageColor3 = c
		card.glow.ImageColor3 = c
		card.stroke.Color = c
		rot = math.sin(t * 2 + ph) * 6
		sc = 1 + 0.03 * math.sin(t * 4 + ph)
	end
	-- прыжок по клику
	if card.jump then
		local k = (t - card.jump) / 0.5
		if k < 1 then
			sc *= 1 + math.sin(k * math.pi) * 0.15
			rot += math.sin(k * math.pi * 2) * 12 * (1 - k)
		else
			card.jump = nil
		end
	end
	card.icon.Rotation = rot
	card.wrapScale.Scale = sc
	card.rays.Rotation = (card.rays.Rotation + raySpeed * dt) % 360
	if card.sheen and t >= card.nextSheen then
		card.nextSheen = t + 3.2 + math.random() * 1.5
		card.sheen.Position = UDim2.new(-0.4, 0, 0.5, 0)
		U.tween(card.sheen, 0.7, { Position = UDim2.new(1.4, 0, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end
	if card.ribbon then
		card.ribbon.Rotation = 45 + math.sin(t * 3 + ph) * 1.5
	end
end

-- ===== подсказка внизу окна =====
local DEFAULT_INFO = "Наведи на предложение, чтобы узнать подробности. Оплата — через окно Roblox, без подтверждения ничего не списывается."
function DUI.ShowInfo(o)
	if not footer then
		return
	end
	local text = o and ('<b><font color="#%s">%s</font></b>  —  %s'):format(o.color:ToHex(), o.name, o.desc) or DEFAULT_INFO
	if footer.label.Text == text then
		return
	end
	footer.token = (footer.token or 0) + 1
	local token = footer.token
	U.tween(footer.label, 0.1, { TextTransparency = 1 })
	task.delay(0.1, function()
		if footer.token ~= token then
			return
		end
		footer.label.Text = text
		U.tween(footer.label, 0.18, { TextTransparency = 0 })
	end)
	if o then
		U.tween(footer.stroke, 0.2, { Color = o.color, Transparency = 0.2 })
	else
		U.tween(footer.stroke, 0.2, { Color = C(120, 100, 180), Transparency = 0.5 })
	end
end

-- ===== вкладки =====
local function tabDef(key)
	for _, t in ipairs(DC.Tabs) do
		if t.key == key then
			return t
		end
	end
end

local function setTab(key, instant)
	local prev = tab
	tab = key
	switching += 1
	local token = switching
	local td = tabDef(key)
	for k, tb in pairs(tabs) do
		local on = k == key
		local d = tabDef(k)
		U.tween(tb.fill, 0.22, { BackgroundTransparency = on and 0 or 0.75, BackgroundColor3 = on and d.color or C(60, 50, 90) })
		U.tween(tb.label, 0.22, { TextColor3 = on and C(30, 20, 10) or C(220, 210, 245) })
		U.tween(tb.labelStroke, 0.22, { Transparency = on and 1 or 0.3 })
	end
	local tb = tabs[key]
	U.tween(tabLine, 0.3, { Position = UDim2.fromOffset(tb.b.Position.X.Offset + 20, 132), BackgroundColor3 = td.color }, Enum.EasingStyle.Quart)
	U.tween(footer.hint, 0.12, { TextTransparency = 1 })
	task.delay(0.12, function()
		if switching == token then
			footer.hint.Text = td.icon .. "  " .. td.hint
			U.tween(footer.hint, 0.2, { TextTransparency = 0 })
		end
	end)
	-- старые карточки уходят, новые появляются по очереди с пружинкой
	local outT = (instant or prev == key) and 0 or 0.16
	if outT > 0 then
		for _, card in pairs(cards) do
			if card.frame.Visible then
				U.tween(card.stroke, outT, { Transparency = 1 })
				U.tween(card.scale, outT, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			end
		end
	end
	task.delay(outT, function()
		if switching ~= token then
			return
		end
		local list = {}
		for _, card in pairs(cards) do
			local show = card.o.tab == key
			card.frame.Visible = show
			if show then
				table.insert(list, card)
			end
		end
		table.sort(list, function(a, b)
			return a.o.index < b.o.index
		end)
		-- 4 предложения — ровный квадрат 2×2, иначе по 3 в ряд
		gridLayout.FillDirectionMaxCells = #list == 4 and 2 or 3
		if not hovered then
			DUI.ShowInfo(nil)
		end
		for i, card in ipairs(list) do
			card.stroke.Transparency = 1
			card.scale.Scale = 0
			task.delay((i - 1) * 0.045, function()
				if switching ~= token then
					return
				end
				U.tween(card.stroke, 0.3, { Transparency = card.hover and 0 or 0.15 })
				U.tween(card.scale, 0.42, { Scale = card.hover and 1.035 or 1 }, Enum.EasingStyle.Back)
			end)
		end
	end)
end

local function refresh()
	for _, card in pairs(cards) do
		styleBuy(card)
	end
end

-- ===== окно =====
local headerIcon, titleGrad, borderGrad
local bgGlows = {}

local function build()
	win = new("Frame", {
		Name = "Donate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = C(255, 255, 255),
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 20,
		Parent = api.gui,
	}, {
		U.corner(22),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(44, 30, 78), C(16, 12, 30)) }),
	})
	winScale = api.addScale(win)
	local border = U.stroke(C(255, 255, 255), 3.5)
	border.Parent = win
	borderGrad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 200, 60)),
			ColorSequenceKeypoint.new(0.35, C(255, 90, 180)),
			ColorSequenceKeypoint.new(0.7, C(90, 200, 255)),
			ColorSequenceKeypoint.new(1, C(255, 200, 60)),
		}),
		Parent = border,
	})
	-- мягкие цветные пятна света плывут по фону
	for i, col in ipairs({ C(255, 90, 180), C(90, 160, 255), C(255, 200, 60) }) do
		local g = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = col, ImageTransparency = 0.8, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(520, 520), Parent = win })
		table.insert(bgGlows, { g = g, ph = i * 2.1 })
	end

	-- шапка
	headerIcon = new("ImageLabel", { BackgroundTransparency = 1, Image = dn("rail"), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(52, 42), Size = UDim2.fromOffset(70, 70), ZIndex = 3, Parent = win })
	local title = new("TextLabel", {
		Position = UDim2.fromOffset(94, 12),
		Size = UDim2.fromOffset(520, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "ДОНАТ-МАГАЗИН",
		TextSize = 34,
		TextColor3 = C(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = win,
	}, { U.textStroke(C(60, 20, 40), 2.5) })
	titleGrad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 210, 70)),
			ColorSequenceKeypoint.new(0.45, C(255, 250, 210)),
			ColorSequenceKeypoint.new(0.55, C(255, 250, 210)),
			ColorSequenceKeypoint.new(1, C(255, 150, 60)),
		}),
		Parent = title,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(96, 50),
		Size = UDim2.fromOffset(560, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Поддержи игру и получи бонусы 💖",
		TextSize = 16,
		TextColor3 = C(215, 195, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = win,
	})
	local close = api.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = C(235, 60, 70),
		Font = Enum.Font.GothamBlack,
		Text = "X",
		TextSize = 22,
		TextColor3 = C(255, 255, 255),
		ZIndex = 5,
		Parent = win,
	}, function()
		DUI.Close()
	end)
	U.corner(14).Parent = close
	U.stroke(C(255, 255, 255), 2, 0.4).Parent = close

	-- вкладки
	for i, t in ipairs(DC.Tabs) do
		local b = api.button({
			Position = UDim2.fromOffset(18 + (i - 1) * 222, 84),
			Size = UDim2.fromOffset(210, 44),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 4,
			Parent = win,
		}, function()
			if tab ~= t.key then
				U.play(U.Sounds.tap, 0.4, 1.1)
				setTab(t.key)
			end
		end)
		local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(60, 50, 90), BackgroundTransparency = 0.75, ZIndex = 4, Parent = b }, { U.corner(14) })
		U.stroke(t.color, 1.5, 0.35).Parent = fill
		local labelStroke = U.textStroke(C(0, 0, 0), 1.5, 0.3)
		local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = t.icon .. "  " .. t.name:upper(), TextSize = 19, TextColor3 = C(220, 210, 245), ZIndex = 5, Parent = b }, { labelStroke })
		tabs[t.key] = { b = b, fill = fill, label = label, labelStroke = labelStroke }
	end
	tabLine = new("Frame", { Position = UDim2.fromOffset(38, 132), Size = UDim2.fromOffset(170, 4), BackgroundColor3 = DC.Tabs[1].color, BorderSizePixel = 0, ZIndex = 5, Parent = win }, { U.round() })

	-- сетка предложений
	local grid = new("Frame", {
		Position = UDim2.fromOffset(18, 144),
		Size = UDim2.fromOffset(W - 36, CH * 2 + 14),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = win,
	}, {
		new("UIGridLayout", {
			Name = "Layout",
			CellSize = UDim2.fromOffset(CW, CH),
			CellPadding = UDim2.fromOffset(16, 12),
			FillDirectionMaxCells = 3,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	gridLayout = grid.Layout
	for _, o in ipairs(DC.List) do
		makeCard(grid, o)
	end

	-- подвал: описание наведённого предложения и подсказка вкладки
	local foot = new("Frame", {
		Position = UDim2.new(0, 18, 1, -56),
		Size = UDim2.new(1, -36, 0, 42),
		BackgroundColor3 = C(12, 9, 24),
		BackgroundTransparency = 0.15,
		ZIndex = 3,
		Parent = win,
	}, { U.corner(12) })
	local fs = U.stroke(C(120, 100, 180), 1.5, 0.5)
	fs.Parent = foot
	local label = new("TextLabel", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		RichText = true,
		Text = DEFAULT_INFO,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = C(225, 215, 245),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = foot,
	})
	local hint = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -78, 0, 66),
		Size = UDim2.fromOffset(360, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "",
		TextSize = 13,
		TextColor3 = C(190, 175, 230),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = win,
	})
	footer = { frame = foot, label = label, stroke = fs, hint = hint }
end

-- ===== праздник после покупки =====
local fxGui
local queue, playing = {}, false
local celebrate
local function playNext()
	if playing or #queue == 0 then
		return
	end
	playing = true
	celebrate(table.remove(queue, 1))
end
local function enqueue(key)
	if DC.ByKey[key] then
		table.insert(queue, key)
		playNext()
	end
end

-- праздники идут по очереди: несколько покупок подряд не накладываются друг на друга
function celebrate(key)
	local o = DC.ByKey[key]
	if not fxGui then
		fxGui = new("ScreenGui", { Name = "ZSS_DonateFX", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Parent = player:WaitForChild("PlayerGui") })
	end
	local vp = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.55, 1.15)
	local root = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(8, 4, 16), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = fxGui })
	U.tween(root, 0.3, { BackgroundTransparency = 0.4 })
	local center = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = root })
	new("UIScale", { Scale = s, Parent = center })
	local function img(image, size, color, tr, z)
		return new("ImageLabel", { BackgroundTransparency = 1, Image = image, ImageColor3 = color, ImageTransparency = tr, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), ZIndex = z, Parent = center })
	end
	local rays1 = img(dn("rays"), 760, o.color, 1, 1)
	local rays2 = img(dn("rays"), 520, C(255, 245, 210), 1, 2)
	local glow = img(Icons.glow, 420, o.color, 1, 3)
	U.tween(rays1, 0.5, { ImageTransparency = 0.35 })
	U.tween(rays2, 0.5, { ImageTransparency = 0.55 })
	U.tween(glow, 0.4, { ImageTransparency = 0.1 })
	local icon = img(dn(o.key), 230, C(255, 255, 255), 0, 5)
	local isc = new("UIScale", { Scale = 0, Parent = icon })
	U.tween(isc, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	icon.Rotation = -25
	U.tween(icon, 0.6, { Rotation = 0 }, Enum.EasingStyle.Back)
	local function line(text, y, size, color, font, delay)
		local l = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, y + 24), Size = UDim2.fromOffset(900, size + 8), BackgroundTransparency = 1, Font = font, Text = text, TextSize = size, TextColor3 = color, TextTransparency = 1, ZIndex = 6, Parent = center }, { U.textStroke(C(0, 0, 0), 2.5, 1) })
		task.delay(delay, function()
			U.tween(l, 0.35, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, y) }, Enum.EasingStyle.Back)
			U.tween(l:FindFirstChildOfClass("UIStroke"), 0.35, { Transparency = 0 })
		end)
		return l
	end
	local l1 = line("СПАСИБО ЗА ПОДДЕРЖКУ!", 158, 44, C(255, 225, 120), Enum.Font.GothamBlack, 0.25)
	new("UIGradient", { Color = ColorSequence.new(C(255, 230, 120), C(255, 130, 200)), Parent = l1 })
	line("Получено: " .. o.name, 206, 26, C(255, 255, 255), Enum.Font.GothamBlack, 0.4)
	line(o.short, 240, 20, o.color:Lerp(C(255, 255, 255), 0.4), Enum.Font.GothamBold, 0.5)
	U.play(U.Sounds.fanfare, 0.55, 1)
	task.delay(0.15, function()
		U.play(U.Sounds.prize, 0.5, 1.05)
	end)
	task.delay(0.45, function()
		U.play(U.Sounds.sparkle, 0.45, 1.1)
	end)
	-- конфетти сверху
	local colors = { C(255, 90, 160), C(255, 210, 60), C(90, 200, 255), C(130, 255, 110), C(190, 110, 255), C(255, 255, 255) }
	for i = 1, 70 do
		local x = math.random()
		local w = math.random(8, 16)
		local cf = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, -0.05 - math.random() * 0.2), Size = UDim2.fromOffset(w, math.floor(w * 0.55)), Rotation = math.random(0, 360), BackgroundColor3 = colors[(i % #colors) + 1], BorderSizePixel = 0, ZIndex = 8, Parent = root }, { U.corner(2) })
		local dur = 1.8 + math.random() * 1.4
		U.tween(cf, dur, { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.25, 1.08), Rotation = cf.Rotation + math.random(-540, 540) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(cf, dur + 0.1)
	end
	-- искры вокруг иконки
	for i = 1, 14 do
		task.delay(0.2 + i * 0.07, function()
			local a = math.random() * math.pi * 2
			local d = math.random(110, 190)
			local sp = img(Icons.twinkle, 8, o.color:Lerp(C(255, 255, 255), 0.5), 0, 7)
			sp.Position = UDim2.new(0.5, math.cos(a) * d * 0.4, 0.5, math.sin(a) * d * 0.4)
			U.tween(sp, 0.5, { Position = UDim2.new(0.5, math.cos(a) * d, 0.5, math.sin(a) * d), Size = UDim2.fromOffset(30, 30), Rotation = 180 }, Enum.EasingStyle.Quart)
			task.delay(0.5, function()
				U.tween(sp, 0.35, { ImageTransparency = 1, Size = UDim2.fromOffset(6, 6) })
			end)
			Debris:AddItem(sp, 1)
		end)
	end
	local alive = true
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		rays1.Rotation += dt * 18
		rays2.Rotation -= dt * 30
		icon.Rotation = math.sin(t * 2.2) * 5 * math.min(1, t)
		glow.Size = UDim2.fromOffset(420 + math.sin(t * 3) * 30, 420 + math.sin(t * 3) * 30)
	end)
	local function finish()
		if not alive then
			return
		end
		alive = false
		U.tween(root, 0.35, { BackgroundTransparency = 1 })
		for _, d in ipairs(center:GetDescendants()) do
			if d:IsA("ImageLabel") then
				U.tween(d, 0.35, { ImageTransparency = 1 })
			elseif d:IsA("TextLabel") then
				U.tween(d, 0.35, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				U.tween(d, 0.35, { Transparency = 1 })
			end
		end
		U.tween(isc, 0.35, { Scale = 1.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.4, function()
			conn:Disconnect()
			root:Destroy()
			playing = false
			playNext()
		end)
	end
	root.Activated:Connect(function()
		if os.clock() - t0 > 0.6 then
			finish()
		end
	end)
	task.delay(3.6, finish)
	refresh()
end

-- ===== API =====
function DUI.IsOpen()
	return U.isOpen(win, winScale)
end

function DUI.Close()
	if win then
		api.closeWindow(win, winScale)
	end
end

function DUI.Open(startTab)
	if not win then
		return
	end
	api.closeOthers()
	if startTab and tabDef(startTab) then
		tab = startTab
	end
	refresh()
	api.openWindow(win, winScale)
	U.play(U.Sounds.chime, 0.3, 1.3)
	setTab(tab, true)
end

function DUI.Toggle()
	if DUI.IsOpen() then
		DUI.Close()
	else
		DUI.Open()
	end
end

function DUI.Init(a)
	api = a
	build()
	DUI.ShowInfo(nil)
	State.Changed:Connect(function()
		if win.Visible then
			refresh()
		end
	end)
	Remotes:WaitForChild("DonateDone").OnClientEvent:Connect(enqueue)
	RunService.RenderStepped:Connect(function(dt)
		if not win.Visible then
			return
		end
		local t = os.clock()
		headerIcon.Rotation = math.sin(t * 1.7) * 7
		titleGrad.Offset = Vector2.new(((t * 0.35) % 2) - 1, 0)
		borderGrad.Rotation = (t * 50) % 360
		for i, g in ipairs(bgGlows) do
			g.g.Position = UDim2.fromScale(0.5 + math.cos(t * 0.21 + g.ph) * 0.38, 0.5 + math.sin(t * 0.17 + g.ph * 1.3) * 0.35)
		end
		for _, card in pairs(cards) do
			if card.frame.Visible then
				animate(card, t, dt)
			end
		end
	end)
end

DUI.Celebrate = enqueue

return DUI
