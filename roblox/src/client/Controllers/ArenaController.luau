--!strict
-- Arena no cliente (so visual): placar no topo enquanto voce esta na Arena (round, criaturas
-- restantes, contagem, recorde), anuncios grandes ("ROUND 3", "CHEFE!", "VENCIDO!", "DERROTA"),
-- coletaveis girando e flutuando, e efeitos de portao, teleporte e coleta. O estado vem dos
-- atributos da Model ArcanumWorld.Arena (Services/ArenaService).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Vfx = script.Parent.Parent.Vfx
local Lib = require(Vfx.Lib)
local Effects = require(Vfx.Effects)
local Audio = require(Vfx.Audio)
local CameraController = require(script.Parent.CameraController)

local ArenaController = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.GothamBold

local KIND_COLORS: { [string]: Color3 } = {
	Start = Color3.fromRGB(205, 170, 255),
	Round = Color3.fromRGB(235, 225, 255),
	Boss = Color3.fromRGB(255, 90, 80),
	Clear = Color3.fromRGB(255, 215, 90),
	Defeat = Color3.fromRGB(255, 70, 70),
}
local KIND_SOUNDS: { [string]: string } = {
	Start = "Portal",
	Round = "VerdictWarn",
	Boss = "Roar",
	Clear = "LevelUp",
	Defeat = "PlayerDeath",
}

type Ui = {
	Gui: ScreenGui,
	Panel: Frame,
	Title: TextLabel,
	Info: TextLabel,
	Record: TextLabel,
	Banner: TextLabel,
	Sub: TextLabel,
}

local ui: Ui? = nil
local bannerToken = 0

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function build(): Ui
	local gui = new("ScreenGui", {
		Name = "ArenaHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(360, 74),
		BackgroundColor3 = Color3.fromRGB(18, 12, 30),
		BackgroundTransparency = 0.25,
		Visible = false,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	new("UIStroke", { Color = Color3.fromRGB(155, 92, 255), Thickness = 1.5, Transparency = 0.2 }, panel)
	local title = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 6),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(235, 220, 255),
		Text = "ARENA ARCANA",
	}, panel)
	local info = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 34),
		BackgroundTransparency = 1,
		Font = FONT_BODY,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "",
	}, panel)
	local record = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 54),
		BackgroundTransparency = 1,
		Font = FONT_BODY,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(190, 175, 215),
		Text = "",
	}, panel)
	local banner = new("TextLabel", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 90),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 64,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.fromRGB(20, 10, 30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	}, gui)
	local sub = new("TextLabel", {
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3 + 0.07),
		Size = UDim2.fromOffset(900, 36),
		BackgroundTransparency = 1,
		Font = FONT_BODY,
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.fromRGB(20, 10, 30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	}, gui)
	return { Gui = gui, Panel = panel, Title = title, Info = info, Record = record, Banner = banner, Sub = sub }
end

local function arena(): Instance?
	local world = Workspace:FindFirstChild("ArcanumWorld")
	return world and world:FindFirstChild("Arena")
end

local function insideArena(model: Instance): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local center = Vector3.new(0, 60, 900)
	local foundation = model:FindFirstChild("Foundation") :: BasePart?
	if foundation then
		center = foundation.Position + Vector3.new(0, 4, 0)
	end
	local offset = root.Position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude < 105 and math.abs(offset.Y) < 60
end

local function refresh()
	local u = ui
	local model = arena()
	if not u or not model then
		return
	end
	local inside = insideArena(model)
	u.Panel.Visible = inside
	if not inside then
		return
	end
	local state = model:GetAttribute("State")
	local round = (model:GetAttribute("Round") or 0) :: number
	local remaining = (model:GetAttribute("Remaining") or 0) :: number
	local endsAt = (model:GetAttribute("EndsAt") or 0) :: number
	local best = (model:GetAttribute("Best") or 0) :: number
	local left = math.max(math.ceil(endsAt - Workspace:GetServerTimeNow()), 0)
	if state == "Round" then
		u.Title.Text = "ROUND " .. round
		u.Info.Text = string.format("Criaturas restantes: %d", remaining)
	elseif state == "Countdown" then
		u.Title.Text = "ARENA ARCANA"
		u.Info.Text = string.format("Comeca em %d", left)
	elseif state == "Intermission" then
		u.Title.Text = "ROUND " .. round .. " VENCIDO"
		u.Info.Text = string.format("Proximo round em %d  -  pegue vida e mana no centro", left)
	elseif state == "Defeat" then
		u.Title.Text = "DERROTA"
		u.Info.Text = string.format("Reabre em %d", left)
	else
		u.Title.Text = "ARENA ARCANA"
		u.Info.Text = "Aguardando lutadores"
	end
	u.Record.Text = string.format(
		"Recorde do servidor: round %d   -   Abates: %d",
		best,
		(model:GetAttribute("Kills") or 0) :: number
	)
end

-- Anuncio grande no meio da tela (so para quem esta na Arena ou perto do fim de round).
local function announce(p: any)
	local u = ui
	local model = arena()
	if not u or not model or not insideArena(model) then
		return
	end
	bannerToken += 1
	local token = bannerToken
	local color = KIND_COLORS[p.Kind] or Color3.new(1, 1, 1)
	u.Banner.Text = tostring(p.Text)
	u.Banner.TextColor3 = color
	u.Sub.Text = if p.Sub then tostring(p.Sub) else ""
	u.Banner.TextSize = 96
	u.Banner.TextTransparency = 0
	u.Banner.TextStrokeTransparency = 0.2
	u.Sub.TextTransparency = 0
	u.Sub.TextStrokeTransparency = 0.3
	TweenService:Create(u.Banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = 64 }):Play()
	local sound = KIND_SOUNDS[p.Kind]
	if sound then
		Audio.play(sound, nil, 0.8)
	end
	if p.Kind == "Boss" then
		CameraController.shake(0.6)
	end
	task.delay(2.6, function()
		if token ~= bannerToken then
			return
		end
		local fade = TweenInfo.new(0.6)
		TweenService:Create(u.Banner, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(u.Sub, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- Coletaveis: giram e flutuam (so neste cliente).
local pickups: { [Model]: { Base: Vector3, Phase: number } } = {}

local function trackPickup(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local base = model:GetAttribute("Base")
	if typeof(base) == "Vector3" then
		pickups[model] = { Base = base, Phase = math.random() * 6 }
	end
end

local function animatePickups()
	local t = os.clock()
	for model, info in pickups do
		if not model.Parent then
			pickups[model] = nil
			continue
		end
		local bob = math.sin(t * 2 + info.Phase) * 0.45
		local spin = CFrame.Angles(0, t * 1.6 + info.Phase, 0)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				local tilt = if p.Name == "Cross" then CFrame.identity else CFrame.Angles(0, 0, math.rad(45))
				local lift = if p.Name == "Cross" then 2.8 else 0
				p.CFrame = CFrame.new(info.Base + Vector3.new(0, bob + lift, 0)) * spin * tilt
			end
		end
	end
end

local HANDLERS: { [string]: (any) -> () } = {
	ArenaAnnounce = announce,
	-- Criatura saindo do portao: clarao, anel e fagulhas da escola (chefe: bem maior).
	ArenaSpawn = function(p)
		local palette = Lib.palette(p.School)
		local scale = if p.Boss then 3 else 1.4
		Effects.flash(p.Position, palette, scale, p.Boss)
		Lib.burst(p.Position, "Ring", palette, 1, { Size = Lib.seq(1, 8 * scale), Brightness = 1.6 })
		Lib.burst(p.Position, "Wisp", palette, math.floor(10 * scale), { Speed = NumberRange.new(4, 9) })
		Audio.play(if p.Boss then "Roar" else "Blink", p.Position, 0.7)
	end,
	-- Coletavel pego: explosao da cor e anel subindo em quem pegou.
	ArenaPickup = function(p)
		local palette = if p.Kind == "Health" then Lib.palette("Necromancy") else Lib.palette("Electricity")
		Effects.flash(p.Position, palette, 1.6, false)
		Lib.burst(p.Position, "Star", palette, 18, { Speed = NumberRange.new(6, 12), Brightness = 2 })
		local root = p.Model and Lib.rootPosition(p.Model)
		if root then
			Lib.burst(root - Vector3.new(0, 2.5, 0), "Ring", palette, 1, { Size = Lib.seq(2, 7), Brightness = 1.6 })
			Lib.burst(root, "Wisp", palette, 12)
		end
		Audio.play("PerfectDodge", p.Position, 0.8)
	end,
	ArenaTeleport = function(p)
		local palette = Lib.palette("Energy")
		if p.To then
			Effects.flash(p.To, palette, 2, true)
			Lib.burst(p.To - Vector3.new(0, 2.5, 0), "Ring", palette, 1, { Size = Lib.seq(2, 9), Brightness = 1.6 })
			Audio.play("Portal", p.To, 0.8)
		end
	end,
}

function ArenaController.start()
	ui = build()
	for _, model in CollectionService:GetTagged("ArenaPickup") do
		trackPickup(model)
	end
	CollectionService:GetInstanceAddedSignal("ArenaPickup"):Connect(trackPickup)
	local function dispatch(kind: string, payload: any)
		local handler = HANDLERS[kind]
		if handler then
			handler(payload)
		end
	end
	Net.get("Vfx").OnClientEvent:Connect(dispatch)
	RunService.RenderStepped:Connect(animatePickups)
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.2)
		end
	end)
end

-- Para o teste de fumaca: dispara um evento de Arena.
function ArenaController.debugEvent(kind: string, payload: any)
	local handler = HANDLERS[kind]
	if handler then
		handler(payload)
	end
end

return ArenaController
