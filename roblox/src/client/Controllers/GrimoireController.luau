--!strict
-- Grimorio (G): livro com as magias de cada escola. Mostra todas as 42 (as ainda nao implementadas
-- aparecem como "Em breve"), detalhes com os numeros do CSV e equipa a selecionada num dos 5 slots:
-- botoes 1-5 do painel ou as teclas 1-5 com o livro aberto. O servidor valida (EquipSpell) e grava
-- nos atributos Slot1..Slot5 do Player; o livro e o HUD so redesenham.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Schools = require(Shared.Schools)
local SpellCatalog = require(Shared.SpellCatalog)
local Spells = require(Shared.Spells)
local SpellData = require(Shared.Data.Spells) :: any
local SpellText = require(Shared.Data.SpellText) :: any
local CameraController = require(script.Parent.CameraController)
local ClientState = require(script.Parent.ClientState)
local Audio = require(script.Parent.Parent.Vfx.Audio)

local player = Players.LocalPlayer
local equipRemote = Net.get("EquipSpell")

local GrimoireController = {}

local SCHOOL_ORDER = { "Electricity", "Fire", "Energy", "Necromancy", "Blood" }
local SCHOOL_NAME: { [string]: string } = {
	Electricity = "Eletricidade",
	Fire = "Fogo",
	Energy = "Energia",
	Necromancy = "Necromancia",
	Blood = "Sangue",
}
local SCHOOL_GLYPH: { [string]: string } = {
	Electricity = "ϟ",
	Fire = "♨",
	Energy = "◆",
	Necromancy = "☠",
	Blood = "☾",
}
local TIER_NAME = { "Círculo I", "Círculo II", "Círculo III", "Círculo IV" }

local PANEL = Color3.fromRGB(22, 16, 32)
local INK = Color3.fromRGB(240, 234, 222)
local MUTED = Color3.fromRGB(170, 160, 185)
local GOLD = Color3.fromRGB(226, 186, 110)

type Card = { Id: string, Button: TextButton, Badge: TextLabel, Scale: UIScale, Stroke: UIStroke }

local gui: ScreenGui
local panel: Frame
local panelScale: UIScale
local dim: Frame
local grid: ScrollingFrame
local tabs: { [string]: { Button: TextButton, Stroke: UIStroke } } = {}
local cards: { Card } = {}
local slotButtons: { TextButton } = {}
local loadout: { { Button: TextButton, Glyph: TextLabel, Name: TextLabel, Stroke: UIStroke } } = {}
local detail: { [string]: any } = {}

local currentSchool = "Electricity"
local selectedId: string? = nil
local open = false
local mouseWasFree = false

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

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

local function palette(school: string): Schools.Palette
	return Schools[school] or Schools.Energy
end

local function equippedSlot(spellId: string): number?
	for i = 1, SpellCatalog.NumSlots do
		if player:GetAttribute("Slot" .. i) == spellId then
			return i
		end
	end
	return nil
end

-- Magias de uma escola: circulo crescente, implementadas primeiro, depois por nome.
local function spellsOf(school: string): { string }
	local list = {}
	for id, row in SpellData do
		if row.School == school then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = SpellData[a], SpellData[b]
		if ra.Tier ~= rb.Tier then
			return ra.Tier < rb.Tier
		end
		local ia, ib = SpellCatalog.Defs[a] ~= nil, SpellCatalog.Defs[b] ~= nil
		if ia ~= ib then
			return ia
		end
		return (SpellText[a] and SpellText[a].Name or a) < (SpellText[b] and SpellText[b].Name or b)
	end)
	return list
end

local function nameOf(id: string): string
	local text = SpellText[id]
	return if text then text.Name else id
end

---------------------------------------------------------------------------------------------------
-- Detalhes

local function statLine(row: any): string
	local parts = {}
	if row.ManaCost > 0 then
		table.insert(parts, string.format("Mana %g", row.ManaCost))
	end
	if row.HealthCostPct > 0 then
		table.insert(parts, string.format("Vida %d%%", math.floor(row.HealthCostPct * 100 + 0.5)))
	end
	if row.bChanneled then
		table.insert(parts, string.format("%g mana/s", row.ManaPerSecond))
	end
	table.insert(parts, if row.Cooldown > 0 then string.format("Recarga %g s", row.Cooldown) else "Sem recarga")
	return table.concat(parts, "   ")
end

local function combatLine(row: any): string
	local parts = {}
	if row.Damage > 0 then
		table.insert(parts, string.format("Dano %g%s", row.Damage, if row.bChanneled then "/s" else ""))
	end
	if row.RangeMeters > 0 then
		table.insert(parts, string.format("Alcance %g m", row.RangeMeters))
	end
	if row.RadiusMeters > 0 then
		table.insert(parts, string.format("Raio %g m", row.RadiusMeters))
	end
	if row.Count > 1 then
		table.insert(parts, string.format("%d×", row.Count))
	end
	return table.concat(parts, "   ")
end

local function refreshDetail()
	local id = selectedId
	if not id then
		detail.Name.Text = "Escolha uma magia"
		detail.Sub.Text = ""
		detail.Desc.Text = "Clique numa página do grimório para ler sobre ela."
		detail.Stats.Text = ""
		detail.Combat.Text = ""
		detail.Glyph.Text = ""
		detail.Status.Text = ""
		for _, b in slotButtons do
			b.Visible = false
		end
		return
	end
	local row = SpellData[id]
	local text = SpellText[id] or {}
	local p = palette(row.School)
	local learned = Spells.get(id) ~= nil
	detail.Glyph.Text = SCHOOL_GLYPH[row.School] or "✦"
	detail.Glyph.TextColor3 = p.Halo
	detail.Name.Text = text.Name or id
	detail.Sub.Text = string.format("%s  ·  %s", SCHOOL_NAME[row.School] or row.School, TIER_NAME[row.Tier] or "")
	detail.Sub.TextColor3 = p.Halo:Lerp(Color3.new(1, 1, 1), 0.35)
	detail.Desc.Text = text.Desc or ""
	detail.Stats.Text = statLine(row)
	detail.Combat.Text = combatLine(row)
	local slot = equippedSlot(id)
	for i, b in slotButtons do
		b.Visible = learned
		local on = slot == i
		b.BackgroundColor3 = if on then p.Halo else Color3.fromRGB(46, 38, 62)
		b.TextColor3 = if on then Color3.new(0, 0, 0) else INK
	end
	detail.Status.Text = if not learned
		then "Ainda não está no seu grimório (em breve)."
		elseif slot then string.format("Equipada no slot %d. Clique em outro número para mover.", slot)
		else "Clique num número ou aperte 1–5 para equipar."
	detail.Status.TextColor3 = if learned then MUTED else Color3.fromRGB(255, 140, 140)
end

---------------------------------------------------------------------------------------------------
-- Grade de paginas e slots

local function refreshCards()
	for _, card in cards do
		local slot = equippedSlot(card.Id)
		card.Badge.Visible = slot ~= nil
		card.Badge.Text = if slot then tostring(slot) else ""
		local selected = card.Id == selectedId
		card.Stroke.Color = if selected then Color3.new(1, 1, 1) else palette(SpellData[card.Id].School).Halo
		card.Stroke.Thickness = if selected then 3 else 1
	end
	for i, ui in loadout do
		local id = player:GetAttribute("Slot" .. i)
		local spellId = if typeof(id) == "string" then id else nil
		local row = if spellId then SpellData[spellId] else nil
		ui.Name.Text = if spellId then nameOf(spellId) else "—"
		ui.Glyph.Text = if row then SCHOOL_GLYPH[row.School] or "✦" else ""
		ui.Glyph.TextColor3 = if row then palette(row.School).Halo else MUTED
		ui.Stroke.Color = if spellId and spellId == selectedId then Color3.new(1, 1, 1) else Color3.fromRGB(90, 76, 120)
	end
end

local function select(id: string)
	selectedId = id
	refreshDetail()
	refreshCards()
end

local function buildCard(id: string, index: number)
	local row = SpellData[id]
	local p = palette(row.School)
	local learned = Spells.get(id) ~= nil
	local button = new("TextButton", {
		Name = id,
		LayoutOrder = index,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, grid)
	corner(button, 10)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(
			p.Halo:Lerp(Color3.new(0, 0, 0), if learned then 0.45 else 0.8),
			p.Halo:Lerp(Color3.new(0, 0, 0), if learned then 0.82 else 0.92)
		),
	}, button)
	local stroke = new("UIStroke", { Color = p.Halo, Thickness = 1, Transparency = 0.2 }, button)
	local scale = new("UIScale", { Scale = 1 }, button)
	new("TextLabel", {
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(8, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = if learned then INK else MUTED,
		Text = nameOf(id),
	}, button)
	new("TextLabel", {
		Size = UDim2.new(1, -16, 0, 14),
		Position = UDim2.fromOffset(8, 6),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = p.Halo:Lerp(Color3.new(1, 1, 1), 0.4),
		Text = (SCHOOL_GLYPH[row.School] or "") .. "  " .. (TIER_NAME[row.Tier] or ""),
	}, button)
	new("TextLabel", {
		Size = UDim2.new(1, -16, 0, 14),
		Position = UDim2.new(0, 8, 1, -20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if learned then Color3.fromRGB(150, 190, 255) else MUTED,
		Text = if not learned
			then "EM BREVE"
			elseif row.ManaCost > 0 then string.format("%g mana", row.ManaCost)
			else "custa vida",
	}, button)
	local badge = new("TextLabel", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -30, 1, -30),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = Color3.new(0, 0, 0),
		Visible = false,
		Text = "",
	}, button)
	corner(badge, 12)

	button.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.04 })
		Audio.play("GrimoireHover", nil)
	end)
	button.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		select(id)
	end)
	table.insert(cards, { Id = id, Button = button, Badge = badge, Scale = scale, Stroke = stroke })
end

local function showSchool(school: string)
	currentSchool = school
	for _, card in cards do
		card.Button:Destroy()
	end
	table.clear(cards)
	for i, id in spellsOf(school) do
		buildCard(id, i)
	end
	grid.CanvasPosition = Vector2.zero
	for name, tab in tabs do
		local p = palette(name)
		local on = name == school
		tab.Button.BackgroundColor3 = p.Halo:Lerp(Color3.new(0, 0, 0), if on then 0.25 else 0.7)
		tab.Stroke.Color = if on then Color3.new(1, 1, 1) else p.Halo
		tab.Stroke.Thickness = if on then 2 else 1
	end
	refreshCards()
end

function GrimoireController.equip(slot: number)
	local id = selectedId
	if not open or not id or not Spells.get(id) or slot < 1 or slot > SpellCatalog.NumSlots then
		return
	end
	equipRemote:FireServer(id, slot)
	Audio.play("GrimoireEquip", nil)
	local ui = loadout[slot]
	if ui then
		ui.Button.Size = UDim2.new(0.2, -8, 1, 6)
		tween(ui.Button, 0.25, { Size = UDim2.new(0.2, -8, 1, 0) }, Enum.EasingStyle.Back)
	end
end

---------------------------------------------------------------------------------------------------
-- Montagem

local function build()
	gui = new("ScreenGui", {
		Name = "ArcanumGrimoire",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	dim = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Active = true,
	}, gui)
	panel = new("Frame", {
		Size = UDim2.fromOffset(900, 580),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL,
		Active = true,
	}, gui)
	corner(panel, 16)
	new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.15 }, panel)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 170)),
	}, panel)
	panelScale = new("UIScale", { Scale = 1 }, panel)

	-- Cabecalho
	new("TextLabel", {
		Size = UDim2.fromOffset(400, 34),
		Position = UDim2.fromOffset(24, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Text = "GRIMÓRIO",
	}, panel)
	new("TextLabel", {
		Size = UDim2.fromOffset(500, 16),
		Position = UDim2.fromOffset(26, 48),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
		Text = "Escolha uma magia e equipe num dos 5 slots  •  G fecha",
	}, panel)
	local close = new("TextButton", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -50, 0, 14),
		BackgroundColor3 = Color3.fromRGB(60, 40, 60),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = INK,
		Text = "✕",
	}, panel)
	corner(close, 18)
	close.Activated:Connect(function()
		GrimoireController.close()
	end)

	-- Abas das escolas
	local tabRow = new("Frame", {
		Size = UDim2.new(1, -48, 0, 36),
		Position = UDim2.fromOffset(24, 74),
		BackgroundTransparency = 1,
	}, panel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabRow)
	for i, school in SCHOOL_ORDER do
		local button = new("TextButton", {
			Size = UDim2.new(0.2, -7, 1, 0),
			LayoutOrder = i,
			AutoButtonColor = false,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = INK,
			Text = (SCHOOL_GLYPH[school] or "") .. "  " .. (SCHOOL_NAME[school] or school),
		}, tabRow)
		corner(button, 8)
		local stroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
		tabs[school] = { Button = button, Stroke = stroke }
		button.Activated:Connect(function()
			if currentSchool ~= school then
				Audio.play("GrimoireHover", nil)
				showSchool(school)
			end
		end)
	end

	-- Paginas (grade)
	grid = new("ScrollingFrame", {
		Size = UDim2.fromOffset(540, 340),
		Position = UDim2.fromOffset(24, 122),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = GOLD,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, panel)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(168, 100),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }, grid)

	-- Detalhes
	local info = new("Frame", {
		Size = UDim2.fromOffset(300, 340),
		Position = UDim2.fromOffset(576, 122),
		BackgroundColor3 = Color3.fromRGB(14, 10, 22),
		BackgroundTransparency = 0.2,
	}, panel)
	corner(info, 12)
	new("UIStroke", { Color = Color3.fromRGB(90, 76, 120), Thickness = 1 }, info)
	detail.Glyph = new("TextLabel", {
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.fromOffset(14, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 40,
		Text = "",
	}, info)
	detail.Name = new("TextLabel", {
		Size = UDim2.new(1, -80, 0, 30),
		Position = UDim2.fromOffset(70, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = INK,
		Text = "",
	}, info)
	detail.Sub = new("TextLabel", {
		Size = UDim2.new(1, -80, 0, 16),
		Position = UDim2.fromOffset(70, 42),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, info)
	detail.Desc = new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 100),
		Position = UDim2.fromOffset(14, 74),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = INK,
		Text = "",
	}, info)
	detail.Stats = new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 18),
		Position = UDim2.fromOffset(14, 180),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(150, 190, 255),
		Text = "",
	}, info)
	detail.Combat = new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 18),
		Position = UDim2.fromOffset(14, 200),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 196, 150),
		Text = "",
	}, info)
	new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 16),
		Position = UDim2.fromOffset(14, 236),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Text = "EQUIPAR NO SLOT",
	}, info)
	local slotRow = new("Frame", {
		Size = UDim2.new(1, -28, 0, 42),
		Position = UDim2.fromOffset(14, 256),
		BackgroundTransparency = 1,
	}, info)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, slotRow)
	for i = 1, SpellCatalog.NumSlots do
		local b = new("TextButton", {
			Size = UDim2.fromOffset(46, 42),
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(46, 38, 62),
			Font = Enum.Font.GothamBlack,
			TextSize = 18,
			TextColor3 = INK,
			Text = tostring(i),
		}, slotRow)
		corner(b, 8)
		new("UIStroke", { Color = GOLD, Thickness = 1, Transparency = 0.4 }, b)
		b.Activated:Connect(function()
			GrimoireController.equip(i)
		end)
		slotButtons[i] = b
	end
	detail.Status = new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 30),
		Position = UDim2.fromOffset(14, 302),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
		Text = "",
	}, info)

	-- Seus slots (barra de baixo)
	new("TextLabel", {
		Size = UDim2.fromOffset(200, 16),
		Position = UDim2.fromOffset(26, 474),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = GOLD,
		Text = "SEUS SLOTS",
	}, panel)
	local strip = new("Frame", {
		Size = UDim2.new(1, -48, 0, 70),
		Position = UDim2.fromOffset(24, 494),
		BackgroundTransparency = 1,
	}, panel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, strip)
	for i = 1, SpellCatalog.NumSlots do
		local button = new("TextButton", {
			Size = UDim2.new(0.2, -8, 1, 0),
			LayoutOrder = i,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(36, 28, 50),
			Text = "",
		}, strip)
		corner(button, 10)
		local stroke = new("UIStroke", { Color = Color3.fromRGB(90, 76, 120), Thickness = 1.5 }, button)
		new("TextLabel", {
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(6, 6),
			BackgroundColor3 = PANEL,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = INK,
			Text = tostring(i),
		}, button)
		local glyph = new("TextLabel", {
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.new(0, 30, 0.5, -20),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 28,
			Text = "",
		}, button)
		local name = new("TextLabel", {
			Size = UDim2.new(1, -80, 1, -8),
			Position = UDim2.fromOffset(74, 4),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = INK,
			Text = "",
		}, button)
		button.Activated:Connect(function()
			local id = player:GetAttribute("Slot" .. i)
			if typeof(id) == "string" and SpellData[id] then
				if SpellData[id].School ~= currentSchool then
					showSchool(SpellData[id].School)
				end
				select(id)
			end
		end)
		loadout[i] = { Button = button, Glyph = glyph, Name = name, Stroke = stroke }
	end
end

-- Encaixa o livro em telas menores.
local function fitToScreen()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	local fit = math.min(1, viewport.X / 960, viewport.Y / 640)
	return math.max(fit, 0.5)
end

function GrimoireController.isOpen(): boolean
	return open
end

function GrimoireController.open()
	if open then
		return
	end
	open = true
	ClientState.GrimoireOpen = true
	mouseWasFree = CameraController.MouseFree
	CameraController.MouseFree = true
	gui.Enabled = true
	if not selectedId then
		local first = player:GetAttribute("Slot" .. ClientState.SelectedSlot)
		if typeof(first) == "string" and SpellData[first] then
			showSchool(SpellData[first].School)
			select(first)
		else
			showSchool(currentSchool)
		end
	else
		refreshDetail()
		refreshCards()
	end
	local fit = fitToScreen()
	panelScale.Scale = fit * 0.92
	tween(panelScale, 0.22, { Scale = fit }, Enum.EasingStyle.Back)
	dim.BackgroundTransparency = 1
	tween(dim, 0.2, { BackgroundTransparency = 0.45 })
	Audio.play("GrimoireOpen", nil)
end

function GrimoireController.close()
	if not open then
		return
	end
	open = false
	ClientState.GrimoireOpen = false
	CameraController.MouseFree = mouseWasFree
	gui.Enabled = false
	Audio.play("GrimoireClose", nil)
end

function GrimoireController.toggle()
	if open then
		GrimoireController.close()
	else
		GrimoireController.open()
	end
end

function GrimoireController.start()
	build()
	-- Teclas 1-5 com o livro aberto equipam a magia selecionada (o InputController repassa).
	ClientState.SlotKey:Connect(function(slot: number)
		GrimoireController.equip(slot)
	end)
	for i = 1, SpellCatalog.NumSlots do
		player:GetAttributeChangedSignal("Slot" .. i):Connect(function()
			if open then
				refreshDetail()
				refreshCards()
			end
		end)
	end
end

-- Para o teste de fumaca.
function GrimoireController.debugSelect(id: string)
	select(id)
end

return GrimoireController
