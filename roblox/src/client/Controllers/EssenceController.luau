--!strict
-- Contador de essencias no canto da tela (como o de bolts em Ratchet & Clank): o numero sobe
-- contando enquanto as pecas chegam, pulsa e mostra "+N". Tambem mostra os avisos de compra no
-- Grimorio e os ganhos de vida/mana ao subir de nivel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local SpellText = require(Shared.Data.SpellText) :: any
local HudController = require(script.Parent.HudController)
local Audio = require(script.Parent.Parent.Vfx.Audio)

local EssenceController = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 206, 64)

local shown = 0
local counter: TextLabel
local gain: TextLabel
local scale: UIScale
local pending = 0
local gainHideAt = 0

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

local function format(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (out:gsub("^%.", ""))
end

local function build()
	local gui = new("ScreenGui", {
		Name = "EssenceHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
	}, player:WaitForChild("PlayerGui"))
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = Color3.fromRGB(28, 20, 10),
		BackgroundTransparency = 0.3,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 22) }, frame)
	new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.25 }, frame)
	scale = new("UIScale", { Scale = 1 }, frame)
	new("TextLabel", {
		Size = UDim2.fromOffset(40, 44),
		Position = UDim2.fromOffset(6, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = GOLD,
		Text = "⬢",
	}, frame)
	counter = new("TextLabel", {
		Size = UDim2.new(1, -54, 1, 0),
		Position = UDim2.fromOffset(46, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 240, 200),
		TextStrokeTransparency = 0.5,
		Text = "0",
	}, frame)
	gain = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 62),
		Size = UDim2.fromOffset(160, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	}, gui)
end

local function balance(): number
	local value = player:GetAttribute("Essence")
	return if typeof(value) == "number" then value else 0
end

local function onBalance()
	local target = balance()
	if target > shown then
		pending += target - shown
		gain.Text = "+" .. format(pending)
		gain.TextTransparency = 0
		gain.TextStrokeTransparency = 0.4
		gainHideAt = os.clock() + 1.6
	else
		shown = target -- gastou: cai na hora
		counter.Text = format(shown)
	end
end

local HANDLERS: { [string]: (any) -> () } = {
	SpellBought = function(p)
		local name = SpellText[p.Id] and SpellText[p.Id].Name or p.Id
		HudController.notice(string.format("%s aprendida!", name), GOLD)
		Audio.play("SpellBought", nil)
	end,
	SpellBuyFailed = function(p)
		if p.Reason == "Essence" then
			HudController.notice(string.format("Faltam %d essências", p.Missing or 0), Color3.fromRGB(255, 140, 120))
		end
		Audio.play("Fail", nil)
	end,
	LevelGains = function(p)
		HudController.notice(
			string.format("+%.1f vida máx.   +%d mana máx.", p.Health or 0, math.floor(p.Mana or 0)),
			Color3.fromRGB(150, 255, 170)
		)
	end,
}

function EssenceController.start()
	build()
	shown = balance()
	counter.Text = format(shown)
	player:GetAttributeChangedSignal("Essence"):Connect(onBalance)
	Net.get("Vfx").OnClientEvent:Connect(function(kind: string, payload: any)
		local handler = HANDLERS[kind]
		if handler then
			handler(payload)
		end
	end)
	-- Conta subindo (rapido para montes grandes) e pulsa a cada passo.
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		local target = balance()
		if shown < target then
			accumulator += dt * math.max((target - shown) * 4, 12)
			local step = math.floor(accumulator)
			if step > 0 then
				accumulator -= step
				shown = math.min(shown + step, target)
				counter.Text = format(shown)
				scale.Scale = 1.12
				TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
			end
		elseif shown > target then
			shown = target
			counter.Text = format(shown)
		end
		if gainHideAt > 0 and os.clock() > gainHideAt then
			gainHideAt = 0
			pending = 0
			TweenService:Create(gain, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

return EssenceController
