-- Хэллоуин: окно обмена у ведьмы (тыквы → награды) и шляпа ведьмы
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Shared = RS:WaitForChild("ZSS")
local Config = require(Shared.Config)
local Icons = require(Shared.Icons)
local Remotes = Shared:WaitForChild("Remotes")
local U = require(script.Parent.U)
local State = require(script.Parent.State)
local new = U.new
local C = Color3.fromRGB

local player = Players.LocalPlayer
local WitchUI = {}
local api
local w = {}

local ORANGE = C(255, 140, 30)
local PURPLE = C(170, 90, 255)

-- те же предложения, что на сервере (Halloween.Offers); цены проверяет сервер
local OFFERS = {
	{ id = "gems", name = "Bag of Gems", desc = "10 💎 for the main gacha", cost = 60, icon = function() return Icons.gem end },
	{ id = "luckycoin", name = "Lucky Nut x2", desc = "Luck for finds", cost = 40, icon = function() return Icons.luckycoin end },
	{ id = "gatherextract", name = "Gatherer's Extract", desc = "Big gathering boost", cost = 120, icon = function() return Icons.gatherextract end },
	{ id = "capsule", name = "Firmware Capsule", desc = "A drone from the main pool", cost = 150, icon = function() return Icons.items and Icons.items.capsule end },
	{ id = "cocktail", name = "Survivor Cocktail", desc = "Every buff at once", cost = 200, icon = function() return Icons.cocktail end },
	{ id = "goldcapsule", name = "Gold Capsule", desc = "An Epic or better drone", cost = 500, icon = function() return Icons.items and Icons.items.goldcapsule end },
	{ id = "starcapsule", name = "Star Capsule", desc = "A Legendary or better drone", cost = 1500, icon = function() return Icons.items and Icons.items.starcapsule end },
	{ id = "supershake", name = "Apocalypse Super Cocktail", desc = "The rarest consumable", cost = 3000, icon = function() return Icons.supershake end },
}

local function witchModel()
	local npcs = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("NPCs")
	return npcs and npcs:FindFirstChild("witch")
end

local function build()
	local win = new("Frame", {
		Name = "WitchShop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 500),
		BackgroundColor3 = C(22, 12, 10),
		Visible = false,
		ZIndex = 20,
		Parent = api.gui,
	}, { U.corner(20), U.stroke(ORANGE, 3), U.grad(C(255, 255, 255), C(150, 120, 170), 90) })
	w.win = win
	w.scale = api.addScale(win)

	local title = new("TextLabel", {
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.new(1, -120, 0, 52),
		BackgroundTransparency = 1,
		Font = Enum.Font.Creepster,
		Text = "WITCH HAZEL'S TRADES",
		TextSize = 44,
		TextColor3 = C(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = win,
	}, { U.textStroke(C(30, 6, 0), 3) })
	U.grad(C(255, 200, 60), PURPLE, 0).Parent = title
	new("TextLabel", {
		Position = UDim2.fromOffset(26, 58),
		Size = UDim2.new(1, -120, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Pumpkins for treats. Pick them on the fields, take them from ghosts at night.",
		TextSize = 13,
		TextColor3 = C(220, 200, 230),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = win,
	})
	local close = api.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C(220, 60, 60),
		Font = Enum.Font.GothamBlack,
		Text = "X",
		TextSize = 22,
		TextColor3 = C(255, 255, 255),
		ZIndex = 22,
		Parent = win,
	}, function()
		WitchUI.Close()
	end)
	U.corner(12).Parent = close
	w.balance = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 16),
		Size = UDim2.fromOffset(220, 40),
		BackgroundColor3 = C(40, 18, 8),
		Font = Enum.Font.GothamBlack,
		Text = "🎃 0",
		TextSize = 24,
		TextColor3 = C(255, 175, 60),
		ZIndex = 21,
		Parent = win,
	}, { U.corner(12), U.stroke(ORANGE, 2, 0.3), U.textStroke(C(0, 0, 0), 2) })

	local grid = new("Frame", {
		Position = UDim2.fromOffset(20, 88),
		Size = UDim2.new(1, -40, 0, 316),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = win,
	}, { new("UIGridLayout", { CellSize = UDim2.new(0.25, -9, 0.5, -6), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	w.cards = {}
	for i, o in ipairs(OFFERS) do
		local card = new("Frame", {
			BackgroundColor3 = C(40, 20, 16),
			LayoutOrder = i,
			ZIndex = 21,
			Parent = grid,
		}, { U.corner(14), U.grad(C(255, 255, 255), C(150, 120, 170), 90) })
		local st = U.stroke(i >= 6 and PURPLE or ORANGE, 2, 0.35)
		st.Parent = card
		new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.glow or "", ImageColor3 = i >= 6 and PURPLE or ORANGE, ImageTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(110, 110), ZIndex = 21, Parent = card })
		local icon = new("ImageLabel", { BackgroundTransparency = 1, Image = o.icon() or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(58, 58), ScaleType = Enum.ScaleType.Fit, ZIndex = 22, Parent = card })
		new("TextLabel", { Position = UDim2.fromOffset(6, 74), Size = UDim2.new(1, -12, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = o.name, TextScaled = true, TextColor3 = C(255, 255, 255), ZIndex = 22, Parent = card }, { new("UITextSizeConstraint", { MaxTextSize = 14 }) })
		new("TextLabel", { Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = o.desc, TextScaled = true, TextColor3 = C(210, 195, 220), ZIndex = 22, Parent = card }, { new("UITextSizeConstraint", { MaxTextSize = 11 }) })
		local buy = api.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 30),
			BackgroundColor3 = C(255, 255, 255),
			Font = Enum.Font.GothamBlack,
			Text = "🎃 " .. U.fmt(o.cost),
			TextSize = 16,
			TextColor3 = C(255, 255, 255),
			ZIndex = 23,
			Parent = card,
		}, function()
			WitchUI.Trade(o)
		end)
		U.corner(10).Parent = buy
		U.grad(C(255, 170, 50), C(190, 70, 10), 90).Parent = buy
		U.textStroke(C(0, 0, 0), 1.5).Parent = buy
		w.cards[o.id] = { card = card, buy = buy, icon = icon, o = o }
	end

	-- нижняя полоса: трофеи Колосса и шляпа ведьмы
	local bottom = new("Frame", {
		Position = UDim2.new(0, 20, 1, -84),
		Size = UDim2.new(1, -40, 0, 66),
		BackgroundColor3 = C(30, 14, 34),
		ZIndex = 21,
		Parent = win,
	}, { U.corner(14), U.stroke(PURPLE, 2, 0.35) })
	w.trophies = new("TextLabel", {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0.45, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "🏆 Pumpkin Colossus trophies: 0",
		TextSize = 15,
		TextColor3 = C(255, 215, 120),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = bottom,
	})
	w.hatText = new("TextLabel", {
		Position = UDim2.new(0.45, 0, 0, 0),
		Size = UDim2.new(0.55, -160, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "",
		TextWrapped = true,
		TextSize = 13,
		TextColor3 = C(220, 190, 255),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 22,
		Parent = bottom,
	})
	w.hatBtn = api.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(140, 42),
		BackgroundColor3 = PURPLE,
		Font = Enum.Font.GothamBlack,
		Text = "🧙 WEAR HAT",
		TextSize = 15,
		TextColor3 = C(255, 255, 255),
		ZIndex = 23,
		Parent = bottom,
	}, function()
		local d = State.data
		local cos = d and d.cosmetics or {}
		local ok, res = pcall(function()
			return Remotes.Halloween:InvokeServer("hat", cos.hatOff == true)
		end)
		if ok and res and not res.ok then
			api.toast(res.err or "Didn't work", "bad")
		end
	end)
	U.corner(12).Parent = w.hatBtn
end

local function refresh()
	local d = State.data
	if not d or not w.win then
		return
	end
	local pk = d.pumpkins or 0
	U.countTo(w.balance, pk, function(v)
		return "🎃 " .. U.fmt(v)
	end)
	for _, c in pairs(w.cards) do
		U.tween(c.buy, 0.2, { BackgroundTransparency = pk >= c.o.cost and 0 or 0.55 })
	end
	w.trophies.Text = ("🏆 Pumpkin Colossus trophies: %d"):format(d.trophies or 0)
	local cos = d.cosmetics or {}
	if cos.witchhat then
		w.hatText.Text = "Your Witch Hat"
		w.hatBtn.Visible = true
		w.hatBtn.Text = cos.hatOff and "🧙 WEAR HAT" or "🧙 TAKE OFF"
	else
		w.hatText.Text = "🧙 Finish all of the Witch's quests to earn the Witch Hat"
		w.hatBtn.Visible = false
	end
end

local trading = false
function WitchUI.Trade(o)
	if trading then
		return
	end
	trading = true
	local ok, res = pcall(function()
		return Remotes.Halloween:InvokeServer("trade", o.id)
	end)
	trading = false
	if not ok or type(res) ~= "table" then
		api.toast("Server connection error", "bad")
		return
	end
	if not res.ok then
		api.toast(res.err or "Didn't work", "bad")
		return
	end
	api.toast(res.msg or "Done", "Epic")
	local c = w.cards[o.id]
	if c then
		local sc = U.scaleOf(c.card)
		sc.Scale = 1.08
		U.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	U.play(U.Sounds.glock, 0.6, 1.2)
end

function WitchUI.Open()
	if not w.win then
		return
	end
	if api.closeOthers then
		api.closeOthers()
	end
	refresh()
	api.openWindow(w.win, w.scale)
end

function WitchUI.Close()
	if w.win then
		api.closeWindow(w.win, w.scale)
	end
end

function WitchUI.Init(a)
	api = a
	if not Config.HalloweenOn() then
		return
	end
	build()
	State.Changed:Connect(refresh)
	refresh()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "WitchShopPrompt" then
			WitchUI.Open()
		end
	end)
	-- окно закрывается, если отойти от ведьмы
	RunService.Heartbeat:Connect(function()
		if w.win.Visible then
			local m = witchModel()
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if m and hrp and (m:GetPivot().Position - hrp.Position).Magnitude > 30 then
				WitchUI.Close()
			end
		end
	end)
end

return WitchUI
