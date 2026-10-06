--!strict
-- HUD da fatia (tudo por codigo, sem imagens):
-- * mira dinamica (abre ao conjurar, vermelha sobre inimigo) + marcador de acerto/abate;
-- * vida e mana com gradiente e "trilha" de dano que desce devagar;
-- * nivel e barra de XP; faixa de "subiu de nivel";
-- * 5 slots: cor/forma da escola, custo, recarga com contagem, escurece sem mana,
--   pulo ao conjurar, tremor + aviso ao falhar;
-- * esquiva: indicador de recarga ao lado da vida e aviso dourado na esquiva perfeita.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Schools = require(Shared.Schools)
local SpellCatalog = require(Shared.SpellCatalog)
local Spells = require(Shared.Spells)
local CameraController = require(script.Parent.CameraController)
local ClientState = require(script.Parent.ClientState)

local player = Players.LocalPlayer

local HudController = {}

local PANEL = Color3.fromRGB(18, 14, 28)
local TEXT = Color3.fromRGB(240, 236, 248)
local FONT = Enum.Font.GothamBold
local FONT_LIGHT = Enum.Font.GothamMedium

-- Simbolo por escola (forma alem da cor: acessibilidade para daltonismo).
local SCHOOL_GLYPH: { [string]: string } = {
	Electricity = "ϟ",
	Fire = "♨",
	Energy = "◆",
	Necromancy = "☠",
	Blood = "☾",
}

local FEEDBACK_TEXT: { [string]: string } = {
	Mana = "Mana insuficiente",
	Health = "Vida insuficiente",
	Cooldown = "Em recarga",
	Paralyzed = "Paralisado!",
}

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

local function tween(
	inst: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	TweenService
		:Create(
			inst,
			TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
			goal
		)
		:Play()
end

-- Barra com fundo, trilha (dano recente) e preenchimento com gradiente.
type Bar = { Fill: Frame, Trail: Frame, Label: TextLabel, Shown: number, TrailValue: number, Root: Frame }
local function makeBar(
	parent: Instance,
	position: UDim2,
	size: UDim2,
	colorA: Color3,
	colorB: Color3,
	label: boolean
): Bar
	local root = new("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
	}, parent)
	corner(root, 5)
	new("UIStroke", { Color = Color3.fromRGB(80, 70, 110), Thickness = 1, Transparency = 0.3 }, root)
	local trail = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 240, 220),
		BackgroundTransparency = 0.25,
	}, root)
	corner(trail, 5)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, root)
	corner(fill, 5)
	new("UIGradient", { Color = ColorSequence.new(colorA, colorB), Rotation = 0 }, fill)
	-- Brilho no topo da barra (volume).
	local shine = new("Frame", {
		Size = UDim2.new(1, 0, 0.45, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
	}, fill)
	corner(shine, 5)
	local text = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 13,
		TextColor3 = TEXT,
		TextStrokeTransparency = 0.45,
		ZIndex = 3,
		Visible = label,
	}, root)
	return { Fill = fill, Trail = trail, Label = text, Shown = 1, TrailValue = 1, Root = root }
end

local function updateBar(bar: Bar, fraction: number, dt: number)
	fraction = math.clamp(fraction, 0, 1)
	-- Preenchimento acompanha rapido; a trilha espera um pouco e desce devagar.
	bar.Shown += (fraction - bar.Shown) * (1 - math.exp(-dt * 18))
	if fraction >= bar.TrailValue then
		bar.TrailValue = fraction
	else
		bar.TrailValue += (fraction - bar.TrailValue) * (1 - math.exp(-dt * 2.5))
	end
	bar.Fill.Size = UDim2.fromScale(bar.Shown, 1)
	bar.Trail.Size = UDim2.fromScale(bar.TrailValue, 1)
end

type SlotUi = {
	Frame: Frame,
	Scale: UIScale,
	Gradient: UIGradient,
	Glyph: TextLabel,
	Name: TextLabel,
	Cost: TextLabel,
	Cooldown: Frame,
	Timer: TextLabel,
	Stroke: UIStroke,
	Dim: Frame,
	SpellId: string?,
}

local slots: { SlotUi } = {}
local toast: TextLabel
local crosshairTicks: { Frame } = {}
local crosshairDot: Frame
local hitmarker: Frame
local spread = 0
local levelBanner: TextLabel
local manaBar: Bar
local hurtEdges: { Frame } = {}
local deathOverlay: Frame
local dodgeFill: Frame
local dodgeScale: UIScale
local dodgeReadyAt = 0
local dodgeTotal = 1

function HudController.castPulse(slot: number)
	local ui = slots[slot]
	if ui then
		ui.Scale.Scale = 0.86
		tween(ui.Scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	spread = math.max(spread, 10)
end

function HudController.feedback(reason: string, slot: number?)
	local message = FEEDBACK_TEXT[reason] or reason
	toast.TextColor3 = Color3.fromRGB(255, 120, 130)
	toast.TextSize = 18
	toast.Text = message
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	toast.Position = UDim2.new(0.5, 0, 1, -228)
	tween(toast, 0.2, { Position = UDim2.new(0.5, 0, 1, -236) })
	task.delay(0.9, function()
		if toast.Text == message then
			tween(toast, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)

	local ui = if slot then slots[slot] else nil
	if ui then
		-- Tremor horizontal do slot.
		task.spawn(function()
			for _, x in { -6, 6, -4, 4, -2, 0 } do
				ui.Frame.Position = UDim2.new(0.5, x, 0.5, 0)
				task.wait(0.03)
			end
		end)
	end
	if reason == "Mana" then
		manaBar.Root.BackgroundColor3 = Color3.fromRGB(160, 40, 60)
		tween(manaBar.Root, 0.5, { BackgroundColor3 = PANEL })
	end
end

-- Aviso curto com cor propria (ex.: esquiva perfeita).
function HudController.notice(text: string, color: Color3)
	toast.Text = text
	toast.TextColor3 = color
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	toast.TextSize = 26
	tween(toast, 0.25, { TextSize = 20 }, Enum.EasingStyle.Back)
	task.delay(1.1, function()
		if toast.Text == text then
			tween(toast, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

-- Esquiva usada: o indicador esvazia e enche durante a recarga.
function HudController.dodged(cooldown: number)
	dodgeReadyAt = os.clock() + cooldown
	dodgeTotal = cooldown
	dodgeScale.Scale = 0.8
	tween(dodgeScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Bordas da tela ficam vermelhas ao receber dano (mais forte quanto maior o golpe).
function HudController.hurt(amount: number)
	local strength = math.clamp(amount / 6, 0.25, 1)
	for _, edge in hurtEdges do
		edge.BackgroundTransparency = 1 - 0.55 * strength
		tween(edge, 0.6, { BackgroundTransparency = 1 })
	end
end

local function buildHurtEdges(gui: ScreenGui)
	-- Quatro faixas com gradiente de transparencia (forte na borda, some para o centro).
	local specs = {
		{ Size = UDim2.new(1, 0, 0.22, 0), Position = UDim2.fromScale(0, 0), Rotation = 90 },
		{ Size = UDim2.new(1, 0, 0.22, 0), Position = UDim2.fromScale(0, 0.78), Rotation = -90 },
		{ Size = UDim2.new(0.16, 0, 1, 0), Position = UDim2.fromScale(0, 0), Rotation = 0 },
		{ Size = UDim2.new(0.16, 0, 1, 0), Position = UDim2.fromScale(0.84, 0), Rotation = 180 },
	}
	for _, spec in specs do
		local edge = new("Frame", {
			Size = spec.Size,
			Position = spec.Position,
			BackgroundColor3 = Color3.fromRGB(200, 20, 30),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, gui)
		new("UIGradient", { Rotation = spec.Rotation, Transparency = NumberSequence.new(0, 1) }, edge)
		table.insert(hurtEdges, edge)
	end
end

-- Tela de morte: escurece e mostra "Você caiu" ate o personagem renascer.
local function buildDeathOverlay(gui: ScreenGui)
	deathOverlay = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 4, 12),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
	}, gui)
	new("TextLabel", {
		Size = UDim2.fromOffset(600, 70),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 54,
		TextColor3 = Color3.fromRGB(235, 90, 100),
		TextStrokeTransparency = 0.4,
		Text = "VOCÊ CAIU",
		ZIndex = 21,
	}, deathOverlay)
	new("TextLabel", {
		Size = UDim2.fromOffset(600, 30),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Font = FONT_LIGHT,
		TextSize = 18,
		TextColor3 = TEXT,
		Text = "Renascendo...",
		ZIndex = 21,
	}, deathOverlay)

	local function watch(character: Model)
		deathOverlay.Visible = false
		deathOverlay.BackgroundTransparency = 1
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				deathOverlay.Visible = true
				tween(deathOverlay, 1.2, { BackgroundTransparency = 0.35 })
			end)
		end
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

function HudController.hitmarker(killed: boolean)
	local color = if killed then Color3.fromRGB(255, 80, 80) else Color3.new(1, 1, 1)
	for _, line in hitmarker:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = color
			line.Size = UDim2.fromOffset(if killed then 16 else 11, 2)
		end
	end
	hitmarker.Visible = true
	hitmarker.Rotation = 45
	local stamp = os.clock()
	hitmarker:SetAttribute("Stamp", stamp)
	task.delay(if killed then 0.35 else 0.15, function()
		if hitmarker:GetAttribute("Stamp") == stamp then
			hitmarker.Visible = false
		end
	end)
end

local function buildCrosshair(gui: ScreenGui)
	local holder = new("Frame", {
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, gui)
	crosshairDot = new("Frame", {
		Size = UDim2.fromOffset(4, 4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, holder)
	corner(crosshairDot, 2)
	for i = 1, 4 do
		local horizontal = i <= 2
		local tick = new("Frame", {
			Size = if horizontal then UDim2.fromOffset(8, 2) else UDim2.fromOffset(2, 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, holder)
		new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.6, Thickness = 1 }, tick)
		crosshairTicks[i] = tick
	end
	hitmarker = new("Frame", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2
		new("Frame", {
			Size = UDim2.fromOffset(11, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(angle) * 9, 0.5, math.sin(angle) * 9),
			Rotation = math.deg(angle),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		}, hitmarker)
	end
end

local function buildSlots(gui: ScreenGui)
	local bar = new("Frame", {
		Size = UDim2.fromOffset(5 * 72 + 4 * 10, 72),
		Position = UDim2.new(0.5, 0, 1, -22),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
	}, gui)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)

	for i = 1, SpellCatalog.NumSlots do
		local holder =
			new("Frame", { Size = UDim2.fromOffset(72, 72), BackgroundTransparency = 1, LayoutOrder = i }, bar)
		local frame = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
		}, holder)
		corner(frame, 12)
		local scale = new("UIScale", { Scale = 1 }, frame)
		local gradient = new("UIGradient", { Rotation = 90 }, frame)
		local stroke = new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(80, 70, 100) }, frame)
		local glyph = new("TextLabel", {
			Size = UDim2.fromScale(1, 0.62),
			Position = UDim2.fromScale(0, 0.04),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 0.15,
			Text = "",
		}, frame)
		new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) }, glyph)
		local name = new("TextLabel", {
			Size = UDim2.new(1, -6, 0, 24),
			Position = UDim2.new(0, 3, 1, -26),
			BackgroundTransparency = 1,
			TextWrapped = true,
			Font = FONT,
			TextSize = 10,
			TextColor3 = TEXT,
			TextStrokeTransparency = 0.4,
		}, frame)
		new("TextLabel", {
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromOffset(4, 3),
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.3,
			Text = tostring(i),
			Font = FONT,
			TextSize = 12,
			TextColor3 = TEXT,
		}, frame)
		local cost = new("TextLabel", {
			Size = UDim2.fromOffset(30, 14),
			Position = UDim2.new(1, -32, 0, 4),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(140, 180, 255),
			TextStrokeTransparency = 0.4,
		}, frame)
		local dim = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(10, 10, 30),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, frame)
		corner(dim, 12)
		local cooldown = new("Frame", {
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			ZIndex = 3,
		}, frame)
		corner(cooldown, 12)
		local timer = new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.3,
			ZIndex = 4,
			Text = "",
		}, frame)
		slots[i] = {
			Frame = frame,
			Scale = scale,
			Gradient = gradient,
			Glyph = glyph,
			Name = name,
			Cost = cost,
			Cooldown = cooldown,
			Timer = timer,
			Stroke = stroke,
			Dim = dim,
			SpellId = nil,
		}
	end
end

local function refreshSlotLook(ui: SlotUi, spellId: string?)
	ui.SpellId = spellId
	local spell = if spellId then Spells.get(spellId) else nil
	if not spell then
		ui.Name.Text = "—"
		ui.Glyph.Text = ""
		ui.Cost.Text = ""
		ui.Gradient.Color = ColorSequence.new(Color3.fromRGB(40, 34, 56), Color3.fromRGB(24, 20, 34))
		return
	end
	local palette = Schools[spell.Row.School] or Schools.Energy
	ui.Name.Text = spell.Name
	ui.Glyph.Text = SCHOOL_GLYPH[spell.Row.School] or "✦"
	ui.Glyph.TextColor3 = palette.Core
	ui.Cost.Text = if spell.Row.ManaCost > 0 then tostring(spell.Row.ManaCost) else ""
	ui.Gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, palette.Halo:Lerp(Color3.new(0, 0, 0), 0.35)),
		ColorSequenceKeypoint.new(1, palette.Halo:Lerp(Color3.new(0, 0, 0), 0.8)),
	})
end

function HudController.start()
	local gui = new("ScreenGui", {
		Name = "ArcanumHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	buildHurtEdges(gui)
	buildCrosshair(gui)
	buildSlots(gui)
	buildDeathOverlay(gui)

	local healthBar = makeBar(
		gui,
		UDim2.new(0.5, 0, 1, -128),
		UDim2.fromOffset(400, 20),
		Color3.fromRGB(255, 92, 92),
		Color3.fromRGB(176, 22, 52),
		true
	)
	manaBar = makeBar(
		gui,
		UDim2.new(0.5, 0, 1, -104),
		UDim2.fromOffset(400, 16),
		Color3.fromRGB(110, 170, 255),
		Color3.fromRGB(80, 60, 230),
		true
	)
	local xpBar = makeBar(
		gui,
		UDim2.new(0.5, 0, 1, -96),
		UDim2.fromOffset(400, 4),
		Color3.fromRGB(255, 220, 120),
		Color3.fromRGB(255, 170, 60),
		false
	)
	xpBar.Root.Position = UDim2.new(0.5, 0, 1, -98)
	xpBar.Root.BackgroundTransparency = 0.5

	local levelBadge = new("TextLabel", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0.5, -226, 1, -102),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 220, 130),
	}, gui)
	corner(levelBadge, 22)
	new("UIStroke", { Color = Color3.fromRGB(255, 200, 90), Thickness = 2 }, levelBadge)

	-- Esquiva (espelho do nivel, a direita da vida): enche de baixo para cima na recarga.
	local dodge = new("Frame", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0.5, 226, 1, -102),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		ClipsDescendants = true,
	}, gui)
	corner(dodge, 22)
	new("UIStroke", { Color = Color3.fromRGB(150, 220, 255), Thickness = 2 }, dodge)
	dodgeScale = new("UIScale", { Scale = 1 }, dodge)
	dodgeFill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(90, 170, 230),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, dodge)
	new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 10,
		TextColor3 = TEXT,
		TextStrokeTransparency = 0.4,
		Text = "Q\nESQUIVA",
		TextWrapped = true,
		ZIndex = 2,
	}, dodge)

	toast = new("TextLabel", {
		Size = UDim2.fromOffset(400, 26),
		Position = UDim2.new(0.5, 0, 1, -236),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 120, 130),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	}, gui)

	levelBanner = new("TextLabel", {
		Size = UDim2.fromOffset(600, 60),
		Position = UDim2.fromScale(0.5, 0.28),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 44,
		TextColor3 = Color3.fromRGB(255, 226, 140),
		TextStrokeColor3 = Color3.fromRGB(90, 40, 10),
		TextStrokeTransparency = 0.2,
		TextTransparency = 1,
		Text = "",
	}, gui)

	new("TextLabel", {
		Size = UDim2.fromOffset(1000, 16),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(210, 206, 224),
		TextTransparency = 0.25,
		TextStrokeTransparency = 0.7,
		Text = "1-5 magias  •  Clique: magia selecionada  •  Roda: trocar  •  Segure: canalizadas  •  Q/Shift: esquivar  •  G: grimório  •  V: trocar ombro  •  Alt: soltar o mouse",
	}, gui)

	-- Subiu de nivel: faixa central.
	local lastLevel = player:GetAttribute("Level") or 1
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = player:GetAttribute("Level") or 1
		if level > lastLevel then
			levelBanner.Text = "NÍVEL " .. tostring(level)
			levelBanner.TextTransparency = 0
			levelBanner.TextStrokeTransparency = 0.2
			levelBanner.TextSize = 70
			tween(levelBanner, 0.35, { TextSize = 44 }, Enum.EasingStyle.Back)
			task.delay(1.8, function()
				tween(levelBanner, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end)
		end
		lastLevel = level
	end)

	RunService.RenderStepped:Connect(function(dt)
		-- Mira: abre ao conjurar, fecha devagar; vermelha sobre inimigo.
		spread = spread * math.exp(-dt * 9)
		local gap = 7 + spread
		local hostile = CameraController.AimTarget ~= nil
		local color = if hostile then Color3.fromRGB(255, 80, 80) else Color3.new(1, 1, 1)
		crosshairTicks[1].Position = UDim2.new(0.5, -gap - 4, 0.5, 0)
		crosshairTicks[2].Position = UDim2.new(0.5, gap + 4, 0.5, 0)
		crosshairTicks[3].Position = UDim2.new(0.5, 0, 0.5, -gap - 4)
		crosshairTicks[4].Position = UDim2.new(0.5, 0, 0.5, gap + 4)
		for _, tick in crosshairTicks do
			tick.BackgroundColor3 = color
		end
		crosshairDot.BackgroundColor3 = color

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local mana = if character then character:GetAttribute("Mana") or 0 else 0
		local maxMana = if character then character:GetAttribute("MaxMana") or 1 else 1
		if humanoid then
			updateBar(healthBar, humanoid.Health / math.max(humanoid.MaxHealth, 1), dt)
			healthBar.Label.Text = string.format("%d / %d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
		end
		updateBar(manaBar, mana / math.max(maxMana, 1), dt)
		manaBar.Label.Text = string.format("%d / %d", math.floor(mana), math.floor(maxMana))

		local xp = player:GetAttribute("XP") or 0
		local xpNext = player:GetAttribute("XPToNext") or 1
		updateBar(xpBar, if xpNext > 0 then xp / xpNext else 1, dt)
		levelBadge.Text = tostring(math.floor(player:GetAttribute("Level") or 1))

		local dodgeLeft = dodgeReadyAt - os.clock()
		dodgeFill.Size = UDim2.fromScale(1, 1 - math.clamp(dodgeLeft / dodgeTotal, 0, 1))
		dodgeFill.BackgroundTransparency = if dodgeLeft > 0 then 0.65 else 0.35

		local now = Workspace:GetServerTimeNow()
		for i, ui in slots do
			local spellId = player:GetAttribute("Slot" .. i)
			local id = if typeof(spellId) == "string" then spellId else nil
			if id ~= ui.SpellId then
				refreshSlotLook(ui, id)
			end
			local spell = if id then Spells.get(id) else nil

			local selected = i == ClientState.SelectedSlot
			local palette = spell and Schools[spell.Row.School]
			ui.Stroke.Color = if selected
				then Color3.new(1, 1, 1)
				elseif palette then palette.Halo
				else Color3.fromRGB(80, 70, 100)
			ui.Stroke.Thickness = if selected then 3 else 1.5
			ui.Frame.Size = if selected then UDim2.fromScale(1.1, 1.1) else UDim2.fromScale(1, 1)

			local affordable = spell == nil or mana >= spell.Row.ManaCost
			ui.Dim.BackgroundTransparency = if affordable then 1 else 0.45
			ui.Cost.TextColor3 = if affordable then Color3.fromRGB(140, 180, 255) else Color3.fromRGB(255, 110, 110)

			local readyAt = if spell then math.max(ClientState.Cooldowns[spell.Id] or 0, ClientState.GcdUntil) else 0
			local remaining = readyAt - now
			local total = if spell and spell.Row.Cooldown > 0 then spell.Row.Cooldown else 0.4
			if remaining > 0 then
				ui.Cooldown.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
				ui.Timer.Text = if remaining >= 1
					then string.format("%d", math.ceil(remaining))
					elseif remaining > 0.45 then string.format("%.1f", remaining)
					else ""
			else
				ui.Cooldown.Size = UDim2.fromScale(1, 0)
				ui.Timer.Text = ""
			end
		end
	end)
end

return HudController
