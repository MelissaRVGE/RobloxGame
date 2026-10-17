-- Квесты NPC (диалог + трекер + книга заданий), Мастерская сот и прогресс переработки
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Q = require(Shared.QuestsConfig)
local Items = require(Shared.ItemsConfig)
local Shop = require(Shared.ShopConfig)
local Icons = require(Shared.Icons)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local new = U.new
local T = U.Theme
local C = Color3.fromRGB

local QuestUI = {}
local api
local dlg = {}
local tracker = {}
local cells = {}
local conv = {}
local openNpc

local function itemName(id)
	return Items.ById[id] and Items.ById[id].name or id
end

local function rewardText(r)
	local parts = {}
	if r.batteries then
		table.insert(parts, "🔋 " .. U.fmt(r.batteries))
	end
	if r.gems then
		table.insert(parts, "💎 " .. r.gems)
	end
	for id, n in pairs(r.items or {}) do
		table.insert(parts, itemName(id) .. " x" .. n)
	end
	for id, n in pairs(r.consum or {}) do
		table.insert(parts, (Shop.ById[id] and Shop.ById[id].name or id) .. " x" .. n)
	end
	return table.concat(parts, "   ")
end

-- ===== ДИАЛОГ =====
local function buildDialog()
	local win = new("Frame", {
		Name = "QuestDialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 500),
		BackgroundColor3 = T.Bg,
		Visible = false,
		ZIndex = 20,
		Parent = api.gui,
	}, { U.corner(18), U.grad(C(255, 255, 255), C(165, 170, 165), 90) })
	dlg.win = win
	dlg.scale = api.addScale(win)
	dlg.stroke = U.stroke(C(255, 200, 80), 3)
	dlg.stroke.Parent = win
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = T.Panel, Parent = win }, { U.corner(18) })
	dlg.header = header
	dlg.avatar = new("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = C(255, 200, 80), Parent = header }, { U.round() })
	dlg.avatarText = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "?", TextColor3 = C(20, 20, 20), Parent = dlg.avatar }, { new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }) })
	dlg.name = new("TextLabel", { Position = UDim2.fromOffset(78, 8), Size = UDim2.new(1, -150, 0, 32), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 255, 255), Parent = header }, { U.textStroke(C(0, 0, 0), 2) })
	dlg.role = new("TextLabel", { Position = UDim2.fromOffset(79, 42), Size = UDim2.new(1, -150, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, Parent = header })
	local close = api.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = T.Danger, Font = Enum.Font.GothamBlack, Text = "X", TextSize = 20, TextColor3 = C(255, 255, 255), Parent = header }, function()
		QuestUI.Close()
	end)
	U.corner(10).Parent = close

	dlg.speech = new("TextLabel", { Position = UDim2.fromOffset(18, 84), Size = UDim2.new(1, -36, 0, 92), BackgroundColor3 = C(30, 34, 30), Font = Enum.Font.GothamMedium, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C(235, 238, 228), Parent = win }, { U.corner(12), U.pad(10), U.stroke(C(70, 80, 70), 1.2) })
	dlg.stage = new("TextLabel", { Position = UDim2.fromOffset(18, 184), Size = UDim2.new(1, -36, 0, 26), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 220, 120), Parent = win }, { U.textStroke(C(0, 0, 0), 1.6) })
	dlg.goals = new("Frame", { Position = UDim2.fromOffset(18, 216), Size = UDim2.new(1, -36, 0, 170), BackgroundTransparency = 1, Parent = win }, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	dlg.reward = new("TextLabel", { Position = UDim2.fromOffset(18, 390), Size = UDim2.new(1, -36, 0, 40), BackgroundColor3 = C(40, 34, 14), Font = Enum.Font.GothamBlack, TextScaled = true, TextWrapped = true, TextColor3 = C(255, 225, 140), Parent = win }, { U.corner(10), U.pad(6), U.stroke(C(255, 200, 80), 1.2, 0.4), new("UITextSizeConstraint", { MaxTextSize = 14 }) })
	dlg.action = api.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(280, 48), BackgroundColor3 = T.Accent, Font = Enum.Font.GothamBlack, TextSize = 19, TextColor3 = C(20, 30, 10), Text = "", Parent = win }, function()
		QuestUI.DoAction()
	end)
	U.corner(12).Parent = dlg.action
	U.stroke(C(255, 255, 255), 2.5, 0.3).Parent = dlg.action
end

local function goalRow(g, cur, i)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C(26, 30, 26), LayoutOrder = i, Parent = dlg.goals }, { U.corner(9), U.stroke(C(60, 70, 60), 1) })
	local done = cur >= g.n
	local ratio = math.clamp(cur / math.max(g.n, 1), 0, 1)
	new("Frame", { Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = done and C(90, 200, 60) or C(70, 110, 160), BackgroundTransparency = 0.45, Parent = row }, { U.corner(9) })
	if g.t == "deliver" and Icons.items[g.id] then
		new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.items[g.id], Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(4, 3), ZIndex = 3, Parent = row })
	end
	local pad = (g.t == "deliver") and 38 or 10
	new("TextLabel", { Position = UDim2.fromOffset(pad, 0), Size = UDim2.new(1, -pad - 110, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(240, 240, 235), Text = (done and "✔ " or "• ") .. Q.GoalText(g, g.id and itemName(g.id)), ZIndex = 3, Parent = row }, { U.textStroke(C(0, 0, 0), 1, 0.3) })
	new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(100, 34), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = done and C(170, 255, 130) or C(255, 255, 255), Text = U.fmt(math.min(cur, g.n)) .. " / " .. U.fmt(g.n), ZIndex = 3, Parent = row }, { U.textStroke(C(0, 0, 0), 1.4) })
end

function QuestUI.Refresh()
	if not openNpc or not dlg.win.Visible then
		return
	end
	local npc = Q.ById[openNpc]
	local d = State.data
	local v = d and d.quests and d.quests[openNpc] or { stage = 1, total = #npc.quests }
	dlg.name.Text = npc.name
	dlg.role.Text = npc.role
	dlg.avatar.BackgroundColor3 = npc.color
	dlg.avatarText.Text = utf8.char(utf8.codepoint(npc.name, 1))
	dlg.stroke.Color = npc.color
	for _, c in ipairs(dlg.goals:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local q = npc.quests[v.stage]
	if not q then
		dlg.speech.Text = "Спасибо тебе. Без тебя мы бы не справились. Все мои задания выполнены!"
		dlg.stage.Text = ("✔ ЦЕПОЧКА ЗАВЕРШЕНА (%d/%d)"):format(#npc.quests, #npc.quests)
		dlg.reward.Text = npc.quests[#npc.quests].perkText and ("🏅 Получен бонус: " .. npc.quests[#npc.quests].perkText) or ""
		dlg.action.Text = "ЗАКРЫТЬ"
		dlg.action.BackgroundColor3 = C(90, 100, 90)
		dlg.mode = "close"
		return
	end
	dlg.speech.Text = (v.stage == 1 and not v.active) and (npc.greet .. "\n\n" .. q.text) or q.text
	dlg.stage.Text = ("ЗАДАНИЕ %d/%d: %s"):format(v.stage, #npc.quests, q.title:upper())
	for i, g in ipairs(q.goals) do
		goalRow(g, v.active and v.goals and v.goals[i] or 0, i)
	end
	dlg.reward.Text = "🎁 Награда: " .. rewardText(q.reward) .. (q.perkText and ("\n🏅 " .. q.perkText) or "")
	if not v.active then
		dlg.action.Text = "📜 ВЗЯТЬ ЗАДАНИЕ"
		dlg.action.BackgroundColor3 = C(255, 200, 80)
		dlg.mode = "accept"
	elseif v.ready then
		dlg.action.Text = "✔ СДАТЬ ЗАДАНИЕ"
		dlg.action.BackgroundColor3 = T.Accent
		dlg.mode = "turnin"
	else
		dlg.action.Text = "В ПРОЦЕССЕ…"
		dlg.action.BackgroundColor3 = C(80, 90, 80)
		dlg.mode = "close"
	end
end

function QuestUI.DoAction()
	if not openNpc then
		return
	end
	if dlg.mode == "close" then
		QuestUI.Close()
		return
	end
	local ok, res = pcall(function()
		return Remotes.QuestAction:InvokeServer(openNpc, dlg.mode)
	end)
	if ok and res then
		if res.ok then
			api.toast(res.msg, "good")
			if dlg.mode == "turnin" then
				U.play(U.Sounds.pop, 0.9, 0.9)
				if res.perkText then
					api.toast("🏅 " .. res.perkText, "Legendary")
				end
			end
		else
			api.toast(res.err or "Не получилось", "bad")
		end
	end
	task.wait(0.25)
	QuestUI.Refresh()
end

function QuestUI.Open(npcId)
	if not Q.ById[npcId] then
		return
	end
	if api.closeOthers then
		api.closeOthers()
	end
	QuestUI.CloseBook()
	openNpc = npcId
	api.openWindow(dlg.win, dlg.scale)
	QuestUI.Refresh()
end

function QuestUI.Close()
	QuestUI.CloseBook()
	if dlg.win then
		api.closeWindow(dlg.win, dlg.scale)
	end
	if cells.win then
		api.closeWindow(cells.win, cells.scale)
	end
	openNpc = nil
end

-- ===== СПИСОК ПРИНЯТЫХ ЗАДАНИЙ (слева) =====
local trackerVisible = true
local trackerSig = nil

local function buildTracker()
	local f = new("Frame", {
		Name = "QuestTracker",
		Position = UDim2.fromOffset(112, 180),
		Size = UDim2.fromOffset(290, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = api.gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	tracker.frame = f
	tracker.scale = api.addScale(f)
	-- заголовок со сворачиванием
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C(20, 24, 30), BackgroundTransparency = 0.1, Text = "", AutoButtonColor = false, LayoutOrder = 0, Parent = f }, { U.corner(10) })
	local hst = U.stroke(C(255, 255, 255), 1.5)
	hst.Parent = head
	new("UIGradient", { Color = ColorSequence.new(C(255, 200, 80), C(255, 120, 60)), Parent = hst })
	new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.quest, Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(28, 28), Parent = head })
	tracker.title = new("TextLabel", { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -70, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 225, 150), Text = "ЗАДАНИЯ", Parent = head }, { U.textStroke(C(0, 0, 0), 1.4) })
	tracker.arrow = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(24, 34), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = C(255, 225, 150), Text = "▼", Parent = head })
	tracker.collapsed = false
	head.Activated:Connect(function()
		tracker.collapsed = not tracker.collapsed
		tracker.arrow.Text = tracker.collapsed and "▶" or "▼"
		for _, c in ipairs(f:GetChildren()) do
			if c:IsA("Frame") and c.Name == "Card" then
				U.fadeVisible(c, not tracker.collapsed, 0.18)
			end
		end
	end)
	tracker.cards = {}
end

-- маленькая «плашка» награды: иконка + число
local function rewardChip(parent, image, text, color, order)
	local chip = new("Frame", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C(12, 14, 18), BackgroundTransparency = 0.2, LayoutOrder = order, Parent = parent }, {
		U.corner(6),
		new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6) }),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3) }),
	})
	new("ImageLabel", { BackgroundTransparency = 1, Image = image or "", Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = chip })
	new("TextLabel", { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = color, Text = text, LayoutOrder = 2, Parent = chip })
end

-- плашки награды задания (батареи, гемы, находки для крафта, расходники, бонус)
local function addRewardChips(parent, r, perkText)
	local o = 0
	if r.batteries then
		o += 1
		rewardChip(parent, Icons.battery, U.fmt(r.batteries), C(190, 255, 110), o)
	end
	if r.gems then
		o += 1
		rewardChip(parent, Icons.gem, tostring(r.gems), C(130, 225, 255), o)
	end
	-- находки по редкости: сначала простые материалы, потом редкие
	local ids = {}
	for id in pairs(r.items or {}) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ia, ib = Items.ById[a], Items.ById[b]
		return (ia and ia.index or 0) < (ib and ib.index or 0)
	end)
	for _, id in ipairs(ids) do
		o += 1
		local it = Items.ById[id]
		local col = it and Items.Tiers[it.tier] and Items.Tiers[it.tier].color:Lerp(C(255, 255, 255), 0.35) or C(255, 220, 160)
		rewardChip(parent, Icons.items[id], "x" .. r.items[id], col, o)
	end
	for id, n in pairs(r.consum or {}) do
		o += 1
		rewardChip(parent, Icons[id], "x" .. n, C(255, 220, 160), o)
	end
	if perkText then
		o += 1
		rewardChip(parent, Icons.trophy, "БОНУС", C(255, 210, 80), o)
	end
end

local function rewardRow(card, r, perkText, order)
	local rw = new("Frame", { Size = UDim2.new(1, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order or 50, Parent = card }, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	addRewardChips(rw, r, perkText)
	return rw
end

local function makeCard(npc, q, order, parent, subText)
	parent = parent or tracker.frame
	local card = new("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C(16, 19, 24), BackgroundTransparency = 0.12, LayoutOrder = order, Visible = parent ~= tracker.frame or not tracker.collapsed, Parent = parent }, {
		U.corner(10),
		U.pad(8),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local st = U.stroke(npc.color, 1.6, 0.25)
	st.Parent = card
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, npc.color:Lerp(C(255, 255, 255), 0.2)), ColorSequenceKeypoint.new(0.08, C(255, 255, 255)), ColorSequenceKeypoint.new(1, C(255, 255, 255)) }), Parent = card })
	new("TextLabel", { Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 255, 255), Text = q.title, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 0, Parent = card }, { U.textStroke(C(0, 0, 0), 1.2) })
	new("TextLabel", { Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = npc.color:Lerp(C(255, 255, 255), 0.35), Text = subText or (npc.name .. " • " .. npc.role), LayoutOrder = 1, Parent = card })
	local goals = {}
	for i, g in ipairs(q.goals) do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1 + i, Parent = card })
		local barBg = new("Frame", { Position = UDim2.new(0, 0, 1, -4), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C(40, 44, 52), BorderSizePixel = 0, Parent = row }, { U.round() })
		local bar = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = npc.color, BorderSizePixel = 0, Parent = barBg }, { U.round() })
		local txt = new("TextLabel", { Size = UDim2.new(1, -64, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(225, 228, 220), Text = Q.GoalText(g, g.id and itemName(g.id)), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		local num = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(62, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C(255, 255, 255), Text = "", Parent = row })
		goals[i] = { bar = bar, txt = txt, num = num, g = g }
	end
	rewardRow(card, q.reward, q.perkText, 50)
	local ready = new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(150, 255, 120), Text = "✔ Готово! Вернись к " .. npc.name, Visible = false, LayoutOrder = 60, Parent = card })
	return { card = card, goals = goals, stroke = st, ready = ready, npc = npc }
end

-- прогресс целей на карточке плавно подтягивается к новым значениям
local function updateCard(c, v)
	for i, gr in ipairs(c.goals) do
		local cur = math.min(v.goals and v.goals[i] or 0, gr.g.n)
		local done = cur >= gr.g.n
		local goalN = gr.g.n
		U.tween(gr.bar, 0.35, { Size = UDim2.fromScale(math.clamp(cur / math.max(goalN, 1), 0, 1), 1), BackgroundColor3 = done and C(120, 230, 80) or c.npc.color })
		U.countTo(gr.num, cur, function(x)
			return U.fmt(x) .. "/" .. U.fmt(goalN)
		end, 0.35)
		U.tween(gr.num, 0.25, { TextColor3 = done and C(150, 255, 120) or C(255, 255, 255) })
		U.tween(gr.txt, 0.25, { TextColor3 = done and C(160, 220, 150) or C(225, 228, 220) })
	end
	c.ready.Visible = v.ready == true
	U.tween(c.stroke, 0.25, { Color = v.ready and C(140, 255, 100) or c.npc.color })
end

local function refreshTracker()
	local d = State.data
	if not tracker.frame then
		return
	end
	tracker.frame.Visible = trackerVisible
	if not d or not d.quests then
		return
	end
	-- состав карточек меняется только при взятии/сдаче квеста
	local active = {}
	local sig = ""
	for _, npc in ipairs(Q.NPCs) do
		local v = d.quests[npc.id]
		local q = v and v.active and npc.quests[v.stage]
		if q then
			table.insert(active, { npc = npc, q = q, v = v })
			sig ..= npc.id .. v.stage .. ";"
		end
	end
	if sig ~= trackerSig then
		trackerSig = sig
		for _, c in pairs(tracker.cards) do
			c.card:Destroy()
		end
		tracker.cards = {}
		for i, a in ipairs(active) do
			tracker.cards[a.npc.id] = makeCard(a.npc, a.q, i)
		end
	end
	tracker.title.Text = ("ЗАДАНИЯ  (%d)"):format(#active)
	tracker.frame:FindFirstChildOfClass("TextButton").Visible = #active > 0
	for _, a in ipairs(active) do
		local c = tracker.cards[a.npc.id]
		if c then
			updateCard(c, a.v)
		end
	end
end

function QuestUI.SetVisible(on)
	trackerVisible = on
	if tracker.frame then
		tracker.frame.Visible = on
	end
end

-- ===== КНИГА ЗАДАНИЙ (кнопка «Задания» в левом меню, как в BSS) =====
-- Вкладки «Активные» и «Выполненные», фильтр по NPC, карточки с прогрессом и наградой.
local book = { tab = "active", filter = nil, cards = {}, sig = nil }
local BOOK_W, BOOK_H, BOOK_H_MOBILE = 430, 600, 450

local function bookCounts(d)
	local done, total, active, ready = 0, 0, 0, 0
	for _, npc in ipairs(Q.NPCs) do
		local v = d and d.quests and d.quests[npc.id]
		total += #npc.quests
		if v then
			done += math.clamp(v.stage - 1, 0, #npc.quests)
			if v.active then
				active += 1
				if v.ready then
					ready += 1
				end
			end
		end
	end
	return done, total, active, ready
end

-- сколько заданий можно сдать прямо сейчас (для значка на кнопке меню)
function QuestUI.ReadyCount()
	local _, _, _, ready = bookCounts(State.data)
	return ready
end

local function npcChip(npc, i)
	local W = (BOOK_W - 24 - 3 * 6) / 4
	local b = api.button({ Size = UDim2.fromOffset(W, 70), BackgroundColor3 = C(22, 26, 32), BackgroundTransparency = 0.05, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = book.strip }, function()
		book.filter = book.filter ~= npc.id and npc.id or nil
		QuestUI.RefreshBook()
	end)
	U.corner(12).Parent = b
	local st = U.stroke(npc.color, 1.5, 0.55)
	st.Parent = b
	local tint = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = npc.color, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = b }, { U.corner(12), new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.4, 1) }) })
	local av = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = npc.color, ZIndex = 2, Parent = b }, { U.round(), U.stroke(C(255, 255, 255), 1.5, 0.3) })
	new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = C(20, 20, 20), Text = utf8.char(utf8.codepoint(npc.name, 1)), ZIndex = 3, Parent = av })
	-- в подписи — имя без звания («Доктор Лиза» → «Лиза»)
	local short = npc.name:match("(%S+)$") or npc.name
	new("TextLabel", { Position = UDim2.fromOffset(2, 36), Size = UDim2.new(1, -4, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = npc.color:Lerp(C(255, 255, 255), 0.45), Text = short, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = b }, { U.textStroke(C(0, 0, 0), 1.2) })
	local barBg = new("Frame", { Position = UDim2.new(0, 8, 1, -14), Size = UDim2.new(1, -46, 0, 6), BackgroundColor3 = C(40, 44, 52), BorderSizePixel = 0, ZIndex = 2, Parent = b }, { U.round() })
	local bar = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = npc.color, BorderSizePixel = 0, ZIndex = 2, Parent = barBg }, { U.round() })
	local num = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 1, -19), Size = UDim2.fromOffset(36, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C(235, 235, 235), Text = "0/15", ZIndex = 2, Parent = b })
	-- значок «!» (можно взять) или «✔» (можно сдать)
	local badge = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C(255, 200, 40), Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C(20, 20, 20), Text = "!", Visible = false, ZIndex = 4, Parent = b }, { U.round() })
	b.MouseEnter:Connect(function()
		U.tween(st, 0.15, { Transparency = 0 })
	end)
	b.MouseLeave:Connect(function()
		U.tween(st, 0.15, { Transparency = book.filter == npc.id and 0 or 0.55 })
	end)
	book.chips[npc.id] = { b = b, st = st, tint = tint, bar = bar, num = num, badge = badge, npc = npc }
end

local function buildBook()
	local win = new("Frame", {
		Name = "QuestBook",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 380, 0.5, 10),
		Size = UDim2.fromOffset(BOOK_W, BOOK_H),
		BackgroundColor3 = T.Bg,
		Visible = false,
		ZIndex = 20,
		Parent = api.gui,
	}, { U.corner(18), U.grad(C(255, 255, 255), C(165, 170, 165), 90) })
	book.win = win
	book.scale = api.addScale(win)
	local wst = U.stroke(C(255, 255, 255), 3)
	wst.Parent = win
	book.strokeGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(255, 200, 80)), ColorSequenceKeypoint.new(0.5, C(255, 240, 190)), ColorSequenceKeypoint.new(1, C(255, 140, 60)) }), Parent = wst })
	-- шапка
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = C(60, 40, 12), Parent = win }, { U.corner(18), U.grad(C(255, 255, 255), C(170, 140, 100), 90) })
	new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.glow, ImageColor3 = C(255, 200, 80), ImageTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(36, 32), Size = UDim2.fromOffset(80, 80), Parent = header })
	book.icon = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.quest, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(36, 32), Size = UDim2.fromOffset(48, 48), ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = header })
	local title = new("TextLabel", { Position = UDim2.fromOffset(68, 6), Size = UDim2.new(1, -130, 0, 32), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "ЗАДАНИЯ", TextColor3 = C(255, 255, 255), Parent = header }, { U.textStroke(C(40, 20, 0), 2), new("UITextSizeConstraint", { MaxTextSize = 28 }) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 245, 200), C(255, 170, 40)), Parent = title })
	book.sub = new("TextLabel", { Position = UDim2.fromOffset(69, 38), Size = UDim2.new(1, -130, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 225, 170), Text = "", Parent = header })
	local close = api.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = T.Danger, Font = Enum.Font.GothamBlack, Text = "X", TextSize = 20, TextColor3 = C(255, 255, 255), Parent = header }, function()
		QuestUI.CloseBook()
	end)
	U.corner(10).Parent = close
	-- NPC: прогресс цепочки и фильтр
	book.strip = new("Frame", { Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -24, 0, 70), BackgroundTransparency = 1, Parent = win }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	book.chips = {}
	for i, npc in ipairs(Q.NPCs) do
		npcChip(npc, i)
	end
	-- вкладки с плавно переезжающей подложкой
	local tabs = new("Frame", { Position = UDim2.fromOffset(12, 152), Size = UDim2.new(1, -24, 0, 38), BackgroundColor3 = C(14, 16, 20), BackgroundTransparency = 0.1, Parent = win }, { U.corner(12), U.stroke(C(70, 76, 86), 1.2) })
	book.tabPill = new("Frame", { Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(0.5, -6, 1, -6), BackgroundColor3 = C(255, 255, 255), Parent = tabs }, { U.corner(10) })
	book.tabGrad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 210, 90), C(230, 140, 40)), Parent = book.tabPill })
	book.tabBtns = {}
	for i, key in ipairs({ "active", "done" }) do
		local tb = api.button({ Position = UDim2.new((i - 1) * 0.5, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = C(255, 255, 255), Text = "", ZIndex = 3, Parent = tabs }, function()
			if book.tab ~= key then
				book.tab = key
				QuestUI.RefreshBook()
			end
		end)
		book.tabBtns[key] = tb
	end
	-- список карточек
	book.list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 198),
		Size = UDim2.new(1, -16, 1, -210),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C(255, 200, 80),
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = win,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 1) }),
	})
	book.empty = new("TextLabel", { Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true, TextColor3 = T.Muted, Text = "", Visible = false, LayoutOrder = 0, Parent = book.list })
	-- иконка в шапке мягко покачивается
	RunService.RenderStepped:Connect(function()
		if win.Visible then
			local t = os.clock()
			book.icon.Rotation = math.sin(t * 1.6) * 6
			book.strokeGrad.Rotation = (t * 50) % 360
		end
	end)
end

-- компактная карточка: выполненное задание, новое задание у NPC или завершённая цепочка
local function smallCard(npc, order, titleText, subText, reward, perkText, kind)
	local card = new("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = kind == "done" and C(18, 26, 18) or C(16, 19, 24), BackgroundTransparency = 0.12, LayoutOrder = order, Parent = book.list }, {
		U.corner(10),
		U.pad(8),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	U.stroke(kind == "done" and C(120, 220, 90) or npc.color, 1.4, kind == "new" and 0.2 or 0.45).Parent = card
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1, LayoutOrder = 0, Parent = card })
	local mark = kind == "done" and "✔" or kind == "new" and "!" or "★"
	new("TextLabel", { Size = UDim2.fromOffset(18, 17), BackgroundColor3 = kind == "done" and C(110, 210, 80) or C(255, 200, 40), Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = C(20, 20, 20), Text = mark, Parent = head }, { U.corner(5) })
	new("TextLabel", { Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = kind == "done" and C(200, 240, 190) or C(255, 255, 255), Text = titleText, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head }, { U.textStroke(C(0, 0, 0), 1.2) })
	new("TextLabel", { Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = npc.color:Lerp(C(255, 255, 255), 0.35), Text = subText, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1, Parent = card })
	if reward then
		rewardRow(card, reward, perkText, 2)
	end
	return card
end

local function bookSection(npc, order, text)
	local f = new("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order, Parent = book.list })
	new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = npc.color, Parent = f }, { U.round() })
	new("TextLabel", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = npc.color:Lerp(C(255, 255, 255), 0.4), Text = text, Parent = f }, { U.textStroke(C(0, 0, 0), 1.2) })
	return f
end

function QuestUI.RefreshBook()
	if not book.win or not book.win.Visible then
		return
	end
	local d = State.data
	local quests = d and d.quests or {}
	local done, total, active, ready = bookCounts(d)
	book.sub.Text = ("Выполнено %d из %d  •  активных %d"):format(done, total, active) .. (ready > 0 and ("  •  можно сдать %d"):format(ready) or "")
	-- NPC-плашки
	for _, npc in ipairs(Q.NPCs) do
		local c = book.chips[npc.id]
		local v = quests[npc.id] or { stage = 1 }
		local n = math.clamp(v.stage - 1, 0, #npc.quests)
		U.tween(c.bar, 0.35, { Size = UDim2.fromScale(n / #npc.quests, 1) })
		c.num.Text = ("%d/%d"):format(n, #npc.quests)
		local sel = book.filter == npc.id
		U.tween(c.tint, 0.2, { BackgroundTransparency = sel and 0.55 or 1 })
		U.tween(c.st, 0.2, { Transparency = sel and 0 or 0.55, Thickness = sel and 2.5 or 1.5 })
		local badge = v.ready and "✔" or (not v.active and not v.done) and "!" or nil
		if badge then
			c.badge.Text = badge
			c.badge.BackgroundColor3 = v.ready and C(120, 230, 80) or C(255, 200, 40)
		end
		U.fadeVisible(c.badge, badge ~= nil, 0.2)
	end
	-- вкладки: подложка переезжает к выбранной
	local nActive, nDone = 0, 0
	for _, npc in ipairs(Q.NPCs) do
		if not book.filter or book.filter == npc.id then
			local v = quests[npc.id] or { stage = 1 }
			nDone += math.clamp(v.stage - 1, 0, #npc.quests)
			if not v.done then
				nActive += 1
			end
		end
	end
	book.tabBtns.active.Text = ("АКТИВНЫЕ (%d)"):format(nActive)
	book.tabBtns.done.Text = ("ВЫПОЛНЕННЫЕ (%d)"):format(nDone)
	U.tween(book.tabPill, 0.25, { Position = UDim2.new(book.tab == "active" and 0 or 0.5, 3, 0, 3) }, Enum.EasingStyle.Quart)
	U.tween(book.tabBtns.active, 0.2, { TextColor3 = book.tab == "active" and C(40, 22, 0) or C(220, 220, 220) })
	U.tween(book.tabBtns.done, 0.2, { TextColor3 = book.tab == "done" and C(40, 22, 0) or C(220, 220, 220) })

	-- состав списка меняется только при смене вкладки/фильтра или взятии/сдаче задания
	local sig = book.tab .. ":" .. tostring(book.filter)
	for _, npc in ipairs(Q.NPCs) do
		local v = quests[npc.id] or {}
		sig ..= ";" .. npc.id .. tostring(v.stage) .. tostring(v.active)
	end
	if sig ~= book.sig then
		local tabChanged = book.lastTab ~= book.tab or book.lastFilter ~= book.filter
		book.sig, book.lastTab, book.lastFilter = sig, book.tab, book.filter
		for _, ch in ipairs(book.list:GetChildren()) do
			if ch.Name == "Card" then
				ch:Destroy()
			end
		end
		book.cards = {}
		local made = {}
		local order = 0
		local function add(inst)
			order += 1
			inst.LayoutOrder = order
			table.insert(made, inst)
		end
		for _, npc in ipairs(Q.NPCs) do
			if not book.filter or book.filter == npc.id then
				local v = quests[npc.id] or { stage = 1 }
				local q = npc.quests[v.stage]
				if book.tab == "active" then
					local stageText = ("%s  •  задание %d/%d"):format(npc.name, v.stage, #npc.quests)
					if q and v.active then
						local c = makeCard(npc, q, 0, book.list, stageText)
						book.cards[npc.id] = c
						add(c.card)
					elseif q then
						add(smallCard(npc, 0, q.title, "Новое задание  •  поговори с: " .. npc.name, q.reward, q.perkText, "new"))
					else
						add(smallCard(npc, 0, "Все задания выполнены!", npc.name .. "  •  цепочка пройдена " .. #npc.quests .. "/" .. #npc.quests, nil, nil, "chain"))
					end
				else
					local last = math.clamp(v.stage - 1, 0, #npc.quests)
					if last > 0 then
						add(bookSection(npc, 0, ("%s  —  %d/%d"):format(npc.name, last, #npc.quests)))
						for k = last, 1, -1 do
							local dq = npc.quests[k]
							add(smallCard(npc, 0, dq.title, ("Задание %d/%d"):format(k, #npc.quests), dq.reward, dq.perkText, "done"))
						end
					end
				end
			end
		end
		book.empty.Text = book.tab == "active" and "Нет заданий." or "Ты ещё не сдал ни одного задания.\nПоговори с жителями базы — у них есть работа!"
		U.fadeVisible(book.empty, #made == 0, 0.2)
		-- карточки появляются по очереди, плавно
		for i, inst in ipairs(made) do
			inst.Visible = false
			if i <= 12 then
				task.delay((i - 1) * 0.035, function()
					if inst.Parent then
						U.fadeVisible(inst, true, 0.22)
					end
				end)
			else
				inst.Visible = true
			end
		end
		if tabChanged then
			book.list.CanvasPosition = Vector2.zero
		end
	end
	for _, npc in ipairs(Q.NPCs) do
		local c = book.cards[npc.id]
		local v = quests[npc.id]
		if c and v then
			updateCard(c, v)
		end
	end
end

-- окно — справа от левой колонки HUD (на телефоне — по центру)
local function placeBook()
	if book.mobile then
		book.win.AnchorPoint = Vector2.new(0.5, 0.5)
		book.win.Position = UDim2.fromScale(0.5, 0.5)
		book.win.Size = UDim2.fromOffset(BOOK_W, BOOK_H_MOBILE)
	else
		local x = api.hudRight and api.hudRight() or 370
		book.win.AnchorPoint = Vector2.new(0, 0.5)
		book.win.Position = UDim2.new(0, x + 14, 0.5, 14)
		book.win.Size = UDim2.fromOffset(BOOK_W, BOOK_H)
	end
end

function QuestUI.OpenBook()
	if not book.win then
		return
	end
	if api.closeOthers then
		api.closeOthers()
	end
	if dlg.win then
		api.closeWindow(dlg.win, dlg.scale)
	end
	if cells.win then
		api.closeWindow(cells.win, cells.scale)
	end
	openNpc = nil
	placeBook()
	book.sig = nil
	api.openWindow(book.win, book.scale)
	QuestUI.RefreshBook()
end

function QuestUI.CloseBook()
	if book.win then
		api.closeWindow(book.win, book.scale)
	end
end

function QuestUI.ToggleBook()
	if book.win and U.isOpen(book.win, book.scale) then
		QuestUI.CloseBook()
	else
		QuestUI.OpenBook()
	end
end

-- маркеры над NPC: ! — есть задание, ? — можно сдать, … — в процессе
local function refreshMarkers()
	local d = State.data
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
	if not folder or not d then
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		local tag = m:FindFirstChild("Tag")
		local mark = tag and tag:FindFirstChild("Marker")
		local v = d.quests and d.quests[m.Name]
		if mark and v then
			if v.done then
				mark.Text = ""
			elseif not v.active then
				mark.Text = "!"
				mark.TextColor3 = C(255, 215, 40)
			elseif v.ready then
				mark.Text = "?"
				mark.TextColor3 = C(130, 255, 90)
			else
				mark.Text = "?"
				mark.TextColor3 = C(170, 170, 170)
			end
		end
	end
end

-- ===== МАСТЕРСКАЯ ГНЁЗД =====
local function buildCells()
	local win = new("Frame", {
		Name = "CellShop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 360),
		BackgroundColor3 = T.Bg,
		Visible = false,
		ZIndex = 20,
		Parent = api.gui,
	}, { U.corner(18), U.stroke(C(255, 180, 50), 3), U.grad(C(255, 255, 255), C(170, 160, 140), 90) })
	cells.win = win
	cells.scale = api.addScale(win)
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = C(60, 40, 10), Parent = win }, { U.corner(18), U.grad(C(255, 255, 255), C(180, 150, 110), 90) })
	new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.energy, ImageColor3 = C(255, 255, 255), Size = UDim2.fromOffset(50, 44), Position = UDim2.fromOffset(12, 9), Parent = header })
	local title = new("TextLabel", { Position = UDim2.fromOffset(72, 6), Size = UDim2.new(1, -140, 0, 32), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "МАСТЕРСКАЯ СОТ", TextColor3 = C(255, 255, 255), Parent = header }, { U.textStroke(C(40, 20, 0), 2) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 245, 200), C(255, 170, 40)), Parent = title })
	cells.sub = new("TextLabel", { Position = UDim2.fromOffset(73, 38), Size = UDim2.new(1, -140, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(255, 225, 170), Parent = header })
	local close = api.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = T.Danger, Font = Enum.Font.GothamBlack, Text = "X", TextSize = 20, TextColor3 = C(255, 255, 255), Parent = header }, function()
		api.closeWindow(win)
	end)
	U.corner(10).Parent = close
	cells.count = new("TextLabel", { Position = UDim2.fromOffset(20, 74), Size = UDim2.new(1, -40, 0, 46), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = C(255, 255, 255), Parent = win }, { U.textStroke(C(40, 20, 0), 2.5) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C(255, 240, 190), C(255, 175, 50)), Parent = cells.count })
	local barBg = new("Frame", { Position = UDim2.fromOffset(20, 126), Size = UDim2.new(1, -40, 0, 22), BackgroundColor3 = C(20, 16, 10), Parent = win }, { U.corner(8), U.stroke(C(90, 70, 40), 1.4) })
	cells.bar = new("Frame", { Size = UDim2.fromScale(0.1, 1), BackgroundColor3 = C(255, 255, 255), Parent = barBg }, { U.corner(8), U.grad(C(255, 215, 110), C(220, 130, 20), 90) })
	cells.info = new("TextLabel", { Position = UDim2.fromOffset(20, 156), Size = UDim2.new(1, -40, 0, 64), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextColor3 = C(230, 225, 215), Text = "Каждое гнездо на твоей станции заряжает одного дрона. Остальные дроны ждут своей очереди. С каждым новым гнездом цена растёт.", Parent = win })
	local function buy(qty)
		local ok, res = pcall(function()
			return Remotes.BuyCell:InvokeServer(qty)
		end)
		if ok and res then
			api.toast(res.ok and res.msg or res.err, res.ok and "good" or "bad")
		end
	end
	cells.buy1 = api.button({ Position = UDim2.new(0, 20, 1, -110), Size = UDim2.new(0.5, -26, 0, 58), BackgroundColor3 = C(255, 190, 60), Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = C(40, 22, 0), Text = "", Parent = win }, function()
		buy(1)
	end)
	U.corner(12).Parent = cells.buy1
	cells.buy5 = api.button({ Position = UDim2.new(0.5, 6, 1, -110), Size = UDim2.new(0.5, -26, 0, 58), BackgroundColor3 = C(230, 140, 40), Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = C(40, 15, 0), Text = "", Parent = win }, function()
		buy(5)
	end)
	U.corner(12).Parent = cells.buy5
	cells.hint = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(1, -40, 0, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = T.Muted, Text = "", Parent = win })
end

local function refreshCells()
	if not cells.win or not cells.win.Visible then
		return
	end
	local d = State.data
	if not d then
		return
	end
	local slots = d.dockSlots or Config.Hive.startCells
	local hive = player:GetAttribute("ZSS_Hive")
	cells.sub.Text = hive and ("Твоя станция: №" .. hive) or "Сначала займи свободную станцию у южной стены"
	cells.count.Text = ("ГНЁЗДА: %d / %d"):format(slots, Config.Hive.maxCells)
	cells.bar.Size = UDim2.fromScale(math.clamp(slots / Config.Hive.maxCells, 0.02, 1), 1)
	if slots >= Config.Hive.maxCells then
		cells.buy1.Text = "СТАНЦИЯ ЗАПОЛНЕНА"
		cells.buy5.Text = "—"
		cells.buy1.BackgroundColor3 = C(80, 80, 80)
		cells.buy5.BackgroundColor3 = C(80, 80, 80)
		cells.hint.Text = "Все 50 гнёзд куплены!"
		return
	end
	local c1 = Config.CellCost(slots + 1)
	local c5 = 0
	for k = 1, math.min(5, Config.Hive.maxCells - slots) do
		c5 += Config.CellCost(slots + k)
	end
	cells.buy1.Text = ("+1 ГНЕЗДО\n🔋 %s"):format(U.fmt(c1))
	cells.buy5.Text = ("+%d ГНЁЗД\n🔋 %s"):format(math.min(5, Config.Hive.maxCells - slots), U.fmt(c5))
	cells.buy1.BackgroundColor3 = d.batteries >= c1 and C(255, 190, 60) or C(110, 95, 70)
	cells.buy5.BackgroundColor3 = d.batteries >= c5 and C(230, 140, 40) or C(110, 85, 60)
	cells.hint.Text = ("Следующее гнездо №%d • у тебя 🔋 %s"):format(slots + 1, U.fmt(d.batteries))
end

function QuestUI.OpenCells()
	if api.closeOthers then
		api.closeOthers()
	end
	api.openWindow(cells.win, cells.scale)
	refreshCells()
end

-- ===== ПРОГРЕСС ПЕРЕРАБОТКИ =====
local function buildConv()
	local f = new("Frame", {
		Name = "ConvertBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -180),
		Size = UDim2.fromOffset(380, 52),
		BackgroundColor3 = C(14, 30, 14),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = api.gui,
	}, { U.corner(14), U.stroke(C(120, 255, 90), 2.5) })
	conv.frame = f
	conv.scale = api.addScale(f)
	conv.title = new("TextLabel", { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C(180, 255, 150), Text = "♻ ПЕРЕРАБОТКА ЛОМА…", Parent = f }, { U.textStroke(C(0, 0, 0), 1.4) })
	local bg = new("Frame", { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 16), BackgroundColor3 = C(5, 10, 5), Parent = f }, { U.corner(8) })
	conv.fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C(255, 255, 255), Parent = bg }, { U.corner(8), U.grad(C(190, 255, 140), C(70, 190, 40), 90) })
	conv.text = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = C(255, 255, 255), ZIndex = 3, Parent = bg }, { U.textStroke(C(0, 0, 0), 1.2) })
end

local function updateConv()
	local on = player:GetAttribute("ZSS_Converting") == true
	if on ~= conv.shown then
		conv.shown = on
		-- полоска переработки плавно выпрыгивает и сворачивается
		if on then
			conv.fill.Size = UDim2.fromScale(0, 1)
			U.openPanel(conv.frame, conv.scale, conv.scale:GetAttribute("Animating") and conv.scale:GetAttribute("BaseScale") or conv.scale.Scale)
		else
			U.closePanel(conv.frame, conv.scale)
		end
	end
	if not on then
		return
	end
	local d = State.data
	local start = math.max(player:GetAttribute("ZSS_ConvertStart") or 1, 1)
	local left = d and d.scrap or 0
	U.tween(conv.fill, 0.3, { Size = UDim2.fromScale(math.clamp(1 - left / start, 0, 1), 1) })
	U.countTo(conv.text, left, function(v)
		return ("осталось ресурсов: %s  •  не сходи с площадки"):format(U.fmt(v))
	end, 0.3)
end

-- на ПК трекер стоит под сеткой вкладок (y считает UI.FitRail)
local desktopTop = 360
function QuestUI.PlaceTracker(y, animate)
	desktopTop = y
	if tracker.frame and not tracker.mobile then
		if animate then
			U.tween(tracker.frame, 0.3, { Position = UDim2.fromOffset(12, y) }, Enum.EasingStyle.Quart)
		else
			tracker.frame.Position = UDim2.fromOffset(12, y)
		end
	end
end

function QuestUI.ApplyLayout(mobile)
	book.mobile = mobile
	if book.win and book.win.Visible then
		placeBook()
	end
	if tracker.frame then
		tracker.mobile = mobile
		tracker.frame.Position = mobile and UDim2.fromOffset(6, 160) or UDim2.fromOffset(12, desktopTop)
		tracker.frame.Visible = trackerVisible
		if mobile then
			tracker.scale.Scale = math.min(tracker.scale.Scale, 0.72)
		end
	end
end

function QuestUI.Init(a)
	api = a
	buildDialog()
	buildTracker()
	buildBook()
	buildCells()
	buildConv()
	local function onData()
		refreshTracker()
		refreshMarkers()
		QuestUI.Refresh()
		QuestUI.RefreshBook()
		refreshCells()
		updateConv()
	end
	State.Changed:Connect(onData)
	if State.data then
		onData()
	end
	player:GetAttributeChangedSignal("ZSS_Converting"):Connect(updateConv)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "QuestPrompt" then
			QuestUI.Open(prompt:GetAttribute("Npc"))
		elseif prompt.Name == "CellShopPrompt" then
			QuestUI.OpenCells()
		end
	end)
	-- NPC маркеры подпрыгивают; диалог закрывается, если отойти
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
		if folder then
			for i, m in ipairs(folder:GetChildren()) do
				local tag = m:FindFirstChild("Tag")
				if tag then
					tag.StudsOffset = Vector3.new(0, 4.2 + math.abs(math.sin(t * 3 + i)) * 0.35, 0)
				end
			end
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and openNpc and folder and folder:FindFirstChild(openNpc) then
			if (folder[openNpc]:GetPivot().Position - hrp.Position).Magnitude > 25 then
				QuestUI.Close()
			end
		end
		if hrp and U.isOpen(cells.win, cells.scale) and (hrp.Position - Config.CellShop.center).Magnitude > Config.CellShop.radius + 14 then
			api.closeWindow(cells.win, cells.scale)
		end
		if conv.frame.Visible then
			conv.frame:FindFirstChildOfClass("UIStroke").Transparency = 0.3 * (0.5 + 0.5 * math.sin(t * 6))
		end
	end)
end

return QuestUI
