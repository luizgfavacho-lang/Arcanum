--!strict
-- Barras de vida das criaturas (o servidor desliga a barra padrao do Roblox):
-- nome + barra com a cor da escola e trilha de dano; elite com borda dourada e estrela.
-- Chefes perto do jogador ganham uma barra grande no topo da tela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Schools = require(ReplicatedStorage.Shared.Schools)

local player = Players.LocalPlayer

local EnemyBars = {}

local BOSS_RANGE = 90

type Entry = {
	Gui: BillboardGui,
	Awareness: TextLabel,
	AwarenessScale: UIScale,
	LastAwareness: any,
	Fill: Frame,
	Trail: Frame,
	Humanoid: Humanoid,
	Shown: number,
	TrailValue: number,
}

local entries: { [Model]: Entry } = {}

local bossGui: ScreenGui
local bossFrame: Frame
local bossFill: Frame
local bossTrail: Frame
local bossName: TextLabel
local bossShown, bossTrailValue = 1, 1

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

local function attach(model: Model)
	if entries[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	-- Criaturas sem cabeca (gosmas, bulbo) usam o corpo; a altura da barra vem do servidor.
	local head = model:FindFirstChild("Head") or model:FindFirstChild("Body") or model:WaitForChild("Head", 5)
	if not humanoid or not humanoid:IsA("Humanoid") or not head then
		return
	end
	local barOffset = model:GetAttribute("BarOffset")
	local palette = Schools[model:GetAttribute("School") or ""] or Schools.Energy
	local elite = model:GetAttribute("Elite") == true

	local gui = new("BillboardGui", {
		Name = "ArcanumBar",
		Size = UDim2.new(5, 0, 1.1, 0),
		StudsOffsetWorldSpace = Vector3.new(
			0,
			if typeof(barOffset) == "number" then barOffset else 2.6 * (if model:GetAttribute("Boss") then 2.2 else 1),
			0
		),
		Adornee = head,
		AlwaysOnTop = false,
		MaxDistance = 110,
		LightInfluence = 0,
	}, nil)
	new("TextLabel", {
		Size = UDim2.fromScale(1, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = if elite then Color3.fromRGB(255, 214, 110) else Color3.fromRGB(240, 236, 248),
		TextStrokeTransparency = 0.35,
		Text = (model:GetAttribute("DisplayName") or model.Name) .. (if elite then "  ★" else ""),
	}, gui)
	local back = new("Frame", {
		Size = UDim2.fromScale(1, 0.32),
		Position = UDim2.fromScale(0, 0.6),
		BackgroundColor3 = Color3.fromRGB(16, 12, 24),
		BackgroundTransparency = 0.15,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, back)
	new("UIStroke", {
		Color = if elite then Color3.fromRGB(255, 200, 70) else Color3.fromRGB(10, 8, 16),
		Thickness = if elite then 2 else 1,
	}, back)
	local trail = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 240, 220) }, back)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, trail)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, back)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
	new(
		"UIGradient",
		{ Color = ColorSequence.new(palette.Halo:Lerp(Color3.new(1, 0.3, 0.3), 0.55), Color3.fromRGB(160, 20, 40)) },
		fill
	)

	-- "!" (avistou) e "?" (procurando) acima do nome.
	local awareness = new("TextLabel", {
		Size = UDim2.fromScale(0.4, 1.1),
		Position = UDim2.fromScale(0.5, -1.15),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.fromRGB(40, 20, 10),
		Text = "",
	}, gui)
	local awarenessScale = new("UIScale", { Scale = 1 }, awareness)

	gui.Parent = player:WaitForChild("PlayerGui")
	entries[model] = {
		Gui = gui,
		Awareness = awareness,
		AwarenessScale = awarenessScale,
		LastAwareness = nil,
		Fill = fill,
		Trail = trail,
		Humanoid = humanoid,
		Shown = 1,
		TrailValue = 1,
	}
end

local function buildBossBar()
	bossGui = new(
		"ScreenGui",
		{ Name = "ArcanumBoss", ResetOnSpawn = false, IgnoreGuiInset = true },
		player:WaitForChild("PlayerGui")
	)
	bossFrame = new("Frame", {
		Size = UDim2.fromOffset(520, 40),
		Position = UDim2.new(0.5, 0, 0, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, bossGui)
	bossName = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 226, 160),
		TextStrokeTransparency = 0.3,
	}, bossFrame)
	local back = new("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 24),
		BackgroundColor3 = Color3.fromRGB(16, 12, 24),
		BackgroundTransparency = 0.1,
	}, bossFrame)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, back)
	new("UIStroke", { Color = Color3.fromRGB(200, 160, 90), Thickness = 1.5 }, back)
	bossTrail = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 240, 220) }, back)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, bossTrail)
	bossFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, back)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, bossFill)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(240, 70, 90), Color3.fromRGB(130, 20, 60)) }, bossFill)
end

local function smooth(shown: number, trailValue: number, fraction: number, dt: number): (number, number)
	shown += (fraction - shown) * (1 - math.exp(-dt * 16))
	if fraction >= trailValue then
		trailValue = fraction
	else
		trailValue += (fraction - trailValue) * (1 - math.exp(-dt * 2.5))
	end
	return shown, trailValue
end

function EnemyBars.start()
	buildBossBar()

	task.spawn(function()
		while true do
			local world = Workspace:FindFirstChild("ArcanumWorld")
			local enemies = world and world:FindFirstChild("Enemies")
			if enemies then
				for _, model in enemies:GetChildren() do
					if model:IsA("Model") and not entries[model] then
						task.spawn(attach, model)
					end
				end
			end
			task.wait(0.5)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local boss: Model? = nil
		for model, entry in entries do
			if not model.Parent or entry.Humanoid.Health <= 0 then
				entry.Gui:Destroy()
				entries[model] = nil
				continue
			end
			local fraction = entry.Humanoid.Health / math.max(entry.Humanoid.MaxHealth, 1)
			entry.Shown, entry.TrailValue = smooth(entry.Shown, entry.TrailValue, fraction, dt)
			entry.Fill.Size = UDim2.fromScale(entry.Shown, 1)
			entry.Trail.Size = UDim2.fromScale(entry.TrailValue, 1)

			local awareness = model:GetAttribute("Awareness")
			if awareness ~= entry.LastAwareness then
				entry.LastAwareness = awareness
				entry.Awareness.Text = if awareness == "Alert" then "!" elseif awareness == "Search" then "?" else ""
				entry.Awareness.TextColor3 = if awareness == "Alert"
					then Color3.fromRGB(255, 205, 60)
					else Color3.fromRGB(170, 210, 255)
				entry.AwarenessScale.Scale = 1.8 -- "pop"
			end
			entry.AwarenessScale.Scale += (1 - entry.AwarenessScale.Scale) * (1 - math.exp(-dt * 14))

			if model:GetAttribute("Boss") and myRoot then
				local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - myRoot.Position).Magnitude < BOSS_RANGE then
					boss = model
				end
			end
		end

		bossFrame.Visible = boss ~= nil
		if boss then
			local entry = entries[boss]
			bossName.Text = string.upper(boss:GetAttribute("DisplayName") or boss.Name)
			local fraction = entry.Humanoid.Health / math.max(entry.Humanoid.MaxHealth, 1)
			bossShown, bossTrailValue = smooth(bossShown, bossTrailValue, fraction, dt)
			bossFill.Size = UDim2.fromScale(bossShown, 1)
			bossTrail.Size = UDim2.fromScale(bossTrailValue, 1)
		end
	end)
end

return EnemyBars
