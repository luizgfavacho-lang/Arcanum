--!strict
-- HUD minimo da fatia: vida, mana (com aviso de regen pausada), nivel/XP, 5 slots com recarga,
-- mira e dicas de controle. Tudo criado por codigo (sem assets).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Schools = require(Shared.Schools)
local SpellCatalog = require(Shared.SpellCatalog)
local Spells = require(Shared.Spells)
local CameraController = require(script.Parent.CameraController)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local HudController = {}

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

local function corner(parent: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function bar(parent: Instance, position: UDim2, color: Color3): (Frame, TextLabel)
	local back = new("Frame", {
		Size = UDim2.fromOffset(320, 18),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(25, 20, 35),
		BackgroundTransparency = 0.25,
	}, parent)
	corner(back, 6)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, back)
	corner(fill, 6)
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
	}, back)
	return fill, label
end

function HudController.start()
	local gui = new(
		"ScreenGui",
		{ Name = "ArcanumHud", ResetOnSpawn = false, IgnoreGuiInset = true },
		player:WaitForChild("PlayerGui")
	)

	-- Mira
	local crosshair = new("Frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, gui)
	corner(crosshair, 5)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3 }, crosshair)

	local healthFill, healthLabel = bar(gui, UDim2.new(0.5, 0, 1, -122), Color3.fromRGB(200, 40, 60))
	local manaFill, manaLabel = bar(gui, UDim2.new(0.5, 0, 1, -98), Color3.fromRGB(70, 120, 255))

	local levelLabel = new("TextLabel", {
		Size = UDim2.fromOffset(320, 18),
		Position = UDim2.new(0.5, 0, 1, -146),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 225, 140),
		TextStrokeTransparency = 0.4,
	}, gui)

	-- Barra de 5 magias
	local slotsFrame = new("Frame", {
		Size = UDim2.fromOffset(5 * 64 + 4 * 8, 64),
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
	}, gui)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, slotsFrame)

	type SlotUi = { Frame: Frame, Name: TextLabel, Cooldown: Frame, Timer: TextLabel, Stroke: UIStroke }
	local slots: { SlotUi } = {}
	for i = 1, SpellCatalog.NumSlots do
		local frame = new(
			"Frame",
			{ Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(30, 24, 44), LayoutOrder = i },
			slotsFrame
		)
		corner(frame, 10)
		local stroke = new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(80, 70, 100) }, frame)
		new("TextLabel", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(4, 2),
			BackgroundTransparency = 1,
			Text = tostring(i),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(200, 200, 210),
		}, frame)
		local name = new("TextLabel", {
			Size = UDim2.new(1, -6, 1, -18),
			Position = UDim2.fromOffset(3, 16),
			BackgroundTransparency = 1,
			TextWrapped = true,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.new(1, 1, 1),
		}, frame)
		local cooldown = new("Frame", {
			Size = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			ZIndex = 2,
		}, frame)
		corner(cooldown, 10)
		local timer = new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 3,
			Text = "",
		}, frame)
		slots[i] = { Frame = frame, Name = name, Cooldown = cooldown, Timer = timer, Stroke = stroke }
	end

	new("TextLabel", {
		Size = UDim2.fromOffset(600, 18),
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 220, 230),
		TextStrokeTransparency = 0.6,
		Text = "1-5: magias  |  Clique: magia selecionada  |  Roda: trocar  |  Segure 4: Corrente em Cadeia  |  Alt: soltar o mouse",
	}, gui)

	local crosshairStroke = crosshair:FindFirstChildOfClass("UIStroke")
	RunService.RenderStepped:Connect(function()
		-- Mira vermelha e maior quando travada num inimigo.
		local locked = CameraController.AimTarget ~= nil
		crosshair.BackgroundColor3 = if locked then Color3.fromRGB(255, 70, 70) else Color3.new(1, 1, 1)
		crosshair.Size = if locked then UDim2.fromOffset(10, 10) else UDim2.fromOffset(6, 6)
		if crosshairStroke then
			crosshairStroke.Thickness = if locked then 2 else 1
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and character then
			healthFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1), 1)
			healthLabel.Text = string.format("Vida %d / %d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))

			local mana = character:GetAttribute("Mana") or 0
			local maxMana = character:GetAttribute("MaxMana") or 1
			manaFill.Size = UDim2.fromScale(math.clamp(mana / math.max(maxMana, 1), 0, 1), 1)
			manaLabel.Text = string.format("Mana %d / %d", math.floor(mana), math.floor(maxMana))
		end

		levelLabel.Text = string.format(
			"Nível %d   •   XP %d / %d",
			math.floor(player:GetAttribute("Level") or 1),
			math.floor(player:GetAttribute("XP") or 0),
			math.floor(player:GetAttribute("XPToNext") or 0)
		)

		local now = Workspace:GetServerTimeNow()
		for i, ui in slots do
			local spellId = player:GetAttribute("Slot" .. i)
			local spell = if typeof(spellId) == "string" then Spells.get(spellId) else nil
			ui.Name.Text = if spell then spell.Name else "—"
			local palette = spell and Schools[spell.Row.School]
			ui.Stroke.Color = if i == ClientState.SelectedSlot
				then Color3.new(1, 1, 1)
				elseif palette then palette.Halo
				else Color3.fromRGB(80, 70, 100)
			ui.Stroke.Thickness = if i == ClientState.SelectedSlot then 3 else 2

			local readyAt = if spell then math.max(ClientState.Cooldowns[spell.Id] or 0, ClientState.GcdUntil) else 0
			local remaining = readyAt - now
			local total = if spell and spell.Row.Cooldown > 0 then spell.Row.Cooldown else 0.4
			if remaining > 0 then
				ui.Cooldown.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
				ui.Timer.Text = if remaining >= 1 then string.format("%d", math.ceil(remaining)) else ""
			else
				ui.Cooldown.Size = UDim2.fromScale(1, 0)
				ui.Timer.Text = ""
			end
		end
	end)
end

return HudController
