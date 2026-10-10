-- Смена дня и ночи на клиенте: плавное освещение по времени сервера + анимация ускорений
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local DN = {}
local C = Color3.fromRGB

local day, night = 1800, 600
local base = {}

-- ночь в стиле BSS: синяя и светлая, всё хорошо видно
local NIGHT = {
	Brightness = 1.4,
	Ambient = C(75, 85, 130),
	OutdoorAmbient = C(105, 120, 180),
	ExposureCompensation = 0.25,
	atmColor = C(95, 110, 170),
	atmDecay = C(45, 55, 105),
	atmDensity = 0.3,
	tint = C(200, 215, 255),
	sat = 0.05,
}

local function phase()
	local start = workspace:GetAttribute("ZSS_CycleStart")
	if not start then
		return nil
	end
	day = workspace:GetAttribute("ZSS_DayLength") or day
	night = workspace:GetAttribute("ZSS_NightLength") or night
	return (workspace:GetServerTimeNow() - start) % (day + night)
end

-- isNight, секунд до смены, доля прошедшей фазы
function DN.Info()
	local p = phase()
	if not p then
		return false, 0, 0
	end
	if p < day then
		return false, day - p, p / day
	end
	return true, day + night - p, (p - day) / night
end

local function clockFor(p)
	-- день: 7:00 → 17:30, ночь: 17:30 → 7:00 (закат и рассвет приходятся на ночь)
	if p < day then
		return 7 + 10.5 * p / day
	end
	return 17.5 + 13.5 * (p - day) / night
end

local function nightness(clock)
	local c = clock % 24
	if c >= 7 and c <= 17.5 then
		return 0
	elseif c > 17.5 and c < 19.5 then
		return (c - 17.5) / 2
	elseif c >= 19.5 or c <= 5 then
		return 1
	else
		return 1 - (c - 5) / 2
	end
end

local function lerpC(a, b, t)
	return a:Lerp(b, t)
end

function DN.Init()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	base = {
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ExposureCompensation = Lighting.ExposureCompensation,
		atmColor = atm and atm.Color,
		atmDecay = atm and atm.Decay,
		atmDensity = atm and atm.Density,
		tint = cc and cc.TintColor,
		sat = cc and cc.Saturation,
	}
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		-- ускорения на полях: парят и крутятся
		local pf = workspace:FindFirstChild("Pickups")
		if pf then
			local t = os.clock()
			for _, p in ipairs(pf:GetChildren()) do
				local y = p:GetAttribute("BaseY")
				if y then
					local cf = CFrame.new(p.Position.X, y + math.sin(t * 2.5 + p.Position.X) * 0.5, p.Position.Z) * CFrame.Angles(0, t * 2, 0)
					p.CFrame = cf
					local core = p:FindFirstChild("Core")
					if core then
						core.CFrame = cf
					end
				end
			end
		end

		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local p = phase()
		if not p then
			return
		end
		local clock = clockFor(p)
		Lighting.ClockTime = clock % 24
		local n = nightness(clock)
		Lighting.Brightness = base.Brightness + (NIGHT.Brightness - base.Brightness) * n
		Lighting.Ambient = lerpC(base.Ambient, NIGHT.Ambient, n)
		Lighting.OutdoorAmbient = lerpC(base.OutdoorAmbient, NIGHT.OutdoorAmbient, n)
		Lighting.ExposureCompensation = base.ExposureCompensation + (NIGHT.ExposureCompensation - base.ExposureCompensation) * n
		if atm then
			atm.Color = lerpC(base.atmColor, NIGHT.atmColor, n)
			atm.Decay = lerpC(base.atmDecay, NIGHT.atmDecay, n)
			atm.Density = base.atmDensity + (NIGHT.atmDensity - base.atmDensity) * n
		end
		if cc then
			cc.TintColor = lerpC(base.tint, NIGHT.tint, n)
			cc.Saturation = base.sat + (NIGHT.sat - base.sat) * n
		end
	end)
end

return DN
