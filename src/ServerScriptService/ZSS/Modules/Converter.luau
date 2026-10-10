-- Переработчик лома: как делание мёда в Bee Swarm Simulator — игрок стоит на площадке,
-- лом постепенно уходит из рюкзака и превращается в батареи.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.ZSS.Config)
local Remotes = RS.ZSS.Remotes

local Converter = {}
local Data, Quests
local active = {} -- player -> { total, nextFx }
local CV = Config.Converter
local TICK = 0.2

local function onPad(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return false
	end
	local d = Vector3.new(hrp.Position.X - CV.pad.X, 0, hrp.Position.Z - CV.pad.Z).Magnitude
	return d <= CV.radius and math.abs(hrp.Position.Y - CV.pad.Y) < 12
end

function Converter.IsActive(player)
	return active[player] ~= nil
end

function Converter.Stop(player, reason)
	local st = active[player]
	if not st then
		return
	end
	active[player] = nil
	player:SetAttribute("ZSS_Converting", false)
	if st.total > 0 then
		Remotes.Notify:FireClient(player, ("♻ Переработано: +%d 🔋%s"):format(st.total, reason and (" (" .. reason .. ")") or ""), "good")
	end
	Remotes.FX:FireAllClients("convertEnd", { owner = player.UserId })
end

function Converter.Start(player)
	local p = Data.Get(player)
	if not p then
		return
	end
	if active[player] then
		Converter.Stop(player, "остановлено")
		return
	end
	if not onPad(player) then
		Remotes.Notify:FireClient(player, "♻ Встань на площадку Переработчика", "bad")
		return
	end
	if p.scrap <= 0 then
		Remotes.Notify:FireClient(player, "🎒 Рюкзак пуст — собери ресурсы на полях!", "bad")
		return
	end
	active[player] = { total = 0, start = p.scrap }
	player:SetAttribute("ZSS_Converting", true)
	player:SetAttribute("ZSS_ConvertStart", p.scrap)
	Remotes.FX:FireAllClients("convertStart", { owner = player.UserId })
end

function Converter.Init(dataModule)
	Data = dataModule
	Quests = require(script.Parent.Quests)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		active[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, st in pairs(active) do
				local p = Data.Get(player)
				if not p or not player.Parent then
					active[player] = nil
				elseif not onPad(player) then
					Converter.Stop(player, "ты ушёл с площадки")
				elseif p.scrap <= 0 then
					Converter.Stop(player)
				else
					local rate = CV.baseRate + Data.Capacity(p) * CV.capRate
					local chunk = math.min(p.scrap, math.max(1, math.floor(rate * TICK + 0.5)))
					p.scrap -= chunk
					-- списываем ресурсы по порядку (сначала простые)
					local left = chunk
					p.res = p.res or {}
					for _, r in ipairs(Config.Resources) do
						local have = p.res[r.id] or 0
						if have > 0 and left > 0 then
							local take = math.min(have, left)
							p.res[r.id] = have - take
							if p.res[r.id] <= 0 then
								p.res[r.id] = nil
							end
							left -= take
						end
					end
					st.total += chunk
					Data.AddBatteries(player, chunk)
					Quests.Event(player, "convert", nil, chunk)
					local now = os.clock()
					if not st.nextFx or now >= st.nextFx then
						st.nextFx = now + 0.4
						Remotes.FX:FireAllClients("convertTick", { owner = player.UserId, amount = chunk })
					end
					if p.scrap <= 0 then
						Converter.Stop(player)
					end
				end
			end
		end
	end)
end

return Converter
