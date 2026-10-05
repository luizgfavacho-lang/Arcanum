--!strict
-- Efeitos visuais (so no cliente, so cosmeticos). Tudo gerado por codigo com as cores de cada
-- escola (Shared/Schools). Placeholders do padrao final descrito em Docs/03-Renderizacao.md §8:
-- clarao (nucleo branco + aureola + risco horizontal), raio ramificado que se redesenha,
-- projetil com nucleo/halo/rastro, corrente de vida, anel runico de conjuracao, numeros de dano.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Schools = require(Shared.Schools)

local VfxController = {}

local folder: Folder
local DEFAULT_PALETTE = Schools.Energy

local function paletteOf(school: any): Schools.Palette
	return (if typeof(school) == "string" then Schools[school] else nil) or DEFAULT_PALETTE
end

local function neon(size: Vector3, color: Color3, cframe: CFrame, shape: Enum.PartType?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.CFrame = cframe
	p.Transparency = transparency or 0
	p.Parent = folder
	return p
end

local function fadeAndDestroy(p: BasePart, duration: number, endSize: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if endSize then
		goal.Size = endSize
	end
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, duration + 0.05)
end

local function burst(position: Vector3, palette: Schools.Palette, count: number, speed: number)
	local holder = neon(Vector3.one * 0.1, palette.Core, CFrame.new(position), nil, 1)
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, palette.Core),
		ColorSequenceKeypoint.new(0.3, palette.Halo),
		ColorSequenceKeypoint.new(1, palette.Accent),
	})
	emitter.LightEmission = 1
	emitter.Brightness = 3
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.25, 0.6)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(holder, 1)
end

-- Clarao: nucleo branco de 1 quadro, aureola que expande, risco anamorfico e particulas.
local function flash(position: Vector3, school: any, scale: number)
	local palette = paletteOf(school)
	local core = neon(Vector3.one * scale, palette.Core, CFrame.new(position), Enum.PartType.Ball)
	task.delay(1 / 30, function()
		core:Destroy()
	end)

	local halo = neon(Vector3.one * scale * 1.2, palette.Halo, CFrame.new(position), Enum.PartType.Ball, 0.3)
	fadeAndDestroy(halo, 0.3, Vector3.one * scale * 3)

	local camera = Workspace.CurrentCamera
	-- Risco horizontal alinhado a tela (reflexo de lente).
	local streak = neon(
		Vector3.new(scale * 5, 0.12 * scale, 0.12 * scale),
		palette.Core,
		CFrame.fromMatrix(position, camera.CFrame.RightVector, camera.CFrame.UpVector),
		nil,
		0.2
	)
	fadeAndDestroy(streak, 0.18, Vector3.new(scale * 8, 0.02, 0.02))

	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = scale * 8
	light.Brightness = 4
	light.Parent = halo

	burst(position, palette, math.floor(10 + scale * 6), 14 + scale * 4)
end

-- Raio ramificado entre dois pontos; redesenha a forma algumas vezes (tremulacao).
local function boltSegments(from: Vector3, to: Vector3, jitter: number): { Vector3 }
	local points = { from }
	local distance = (to - from).Magnitude
	local steps = math.max(2, math.ceil(distance / 3))
	local dir = (to - from).Unit
	local right = dir:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-3 then
		right = Vector3.xAxis
	end
	right = right.Unit
	local up = right:Cross(dir).Unit
	for i = 1, steps - 1 do
		local t = i / steps
		local offset = (right * (math.random() - 0.5) + up * (math.random() - 0.5)) * jitter * 2
		table.insert(points, from:Lerp(to, t) + offset)
	end
	table.insert(points, to)
	return points
end

local function drawPolyline(points: { Vector3 }, width: number, color: Color3, transparency: number, lifetime: number)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		if length > 1e-3 then
			local p = neon(Vector3.new(width, width, length), color, CFrame.lookAt((a + b) / 2, b), nil, transparency)
			fadeAndDestroy(p, lifetime)
		end
	end
end

local function lightning(from: Vector3, to: Vector3, school: any, strands: number, lifetime: number)
	local palette = paletteOf(school)
	local redraws = 2
	for r = 0, redraws - 1 do
		task.delay(r * (lifetime / redraws), function()
			local segmentLife = lifetime / redraws + 0.03
			drawPolyline(boltSegments(from, to, 0.9), 0.12, palette.Core, 0, segmentLife)
			for _ = 1, strands - 1 do
				drawPolyline(boltSegments(from, to, 1.6), 0.25, palette.Halo, 0.35, segmentLife)
			end
		end)
	end
end

-- Projeteis -------------------------------------------------------------------------------------

type Visual = { Model: Part, Halo: Part, Velocity: Vector3, Speed: number, Homing: Model?, Born: number }
local projectiles: { [string]: Visual } = {}

local function rootPosition(model: Model): Vector3?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function spawnProjectile(payload: any)
	local palette = paletteOf(payload.School)
	local core = neon(Vector3.one * 0.7, palette.Core, CFrame.new(payload.Position), Enum.PartType.Ball)
	local halo = neon(Vector3.one * 1.5, palette.Halo, core.CFrame, Enum.PartType.Ball, 0.35)

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.5, 0)
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.5, 0)
	a1.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(palette.Core, palette.Halo)
	trail.LightEmission = 1
	trail.Lifetime = 0.25
	trail.WidthScale = NumberSequence.new(1, 0) -- rastro afina para tras
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = core

	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = 10
	light.Brightness = 2
	light.Parent = core

	projectiles[payload.Id] = {
		Model = core,
		Halo = halo,
		Velocity = payload.Velocity,
		Speed = payload.Speed,
		Homing = payload.Homing,
		Born = os.clock(),
	}
end

local function endProjectile(payload: any)
	local visual = projectiles[payload.Id]
	if visual then
		projectiles[payload.Id] = nil
		visual.Model:Destroy()
		visual.Halo:Destroy()
	end
	flash(payload.Position, payload.School, if payload.Radius and payload.Radius > 0 then 3 else 1.6)
end

local function stepProjectiles(dt: number)
	for id, visual in projectiles do
		-- Mesmo direcionamento do servidor (Spells/Projectile.luau).
		local target = visual.Homing
		local targetPos = target and target.Parent and rootPosition(target)
		local position = visual.Model.Position
		if targetPos then
			local desired = (targetPos - position).Unit * visual.Speed
			visual.Velocity = visual.Velocity:Lerp(desired, math.clamp(dt * 7, 0, 1))
		end
		local nextCFrame = CFrame.lookAt(position + visual.Velocity * dt, position + visual.Velocity * dt * 2)
		visual.Model.CFrame = nextCFrame
		visual.Halo.CFrame = nextCFrame
		if os.clock() - visual.Born > 8 then
			projectiles[id] = nil
			visual.Model:Destroy()
			visual.Halo:Destroy()
		end
	end
end

-- Outros efeitos -------------------------------------------------------------------------------

local function castRing(caster: Model, school: any)
	local root = caster:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local palette = paletteOf(school)
	local feet = root.Position - Vector3.new(0, 2.8, 0)
	local ring = neon(
		Vector3.new(0.15, 3, 3),
		palette.Halo,
		CFrame.new(feet) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.PartType.Cylinder,
		0.3
	)
	fadeAndDestroy(ring, 0.35, Vector3.new(0.05, 8, 8))
	local inner = neon(Vector3.new(0.16, 2, 2), palette.Core, ring.CFrame, Enum.PartType.Cylinder, 0.5)
	fadeAndDestroy(inner, 0.25, Vector3.new(0.05, 4, 4))
end

local function lifeStream(fromPos: Vector3, caster: Model, school: any)
	local palette = paletteOf(school)
	for i = 0, 5 do
		task.delay(i * 0.05, function()
			local target = rootPosition(caster)
			if not target then
				return
			end
			local orb = neon(Vector3.one * 0.6, palette.Halo, CFrame.new(fromPos), Enum.PartType.Ball, 0.1)
			local tween = TweenService:Create(
				orb,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine),
				{ CFrame = CFrame.new(target), Size = Vector3.one * 0.2 }
			)
			tween:Play()
			Debris:AddItem(orb, 0.4)
		end)
	end
end

local function floatingNumber(target: Model, text: string, color: Color3, small: boolean)
	local head = target:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random() * 2 - 1, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = if small then 16 else 24
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = folder
	TweenService
		:Create(gui, TweenInfo.new(0.8), { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 3, 0) })
		:Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	Debris:AddItem(gui, 0.85)
end

-- Estados: efeitos simples presos ao personagem enquanto o atributo State_* estiver ativo.
local STATE_EFFECTS: { [string]: (BasePart) -> Instance } = {
	Burning = function(root)
		local fire = Instance.new("Fire")
		fire.Heat = 6
		fire.Size = 4
		fire.Color = Schools.Fire.Halo
		fire.SecondaryColor = Schools.Fire.Accent
		fire.Parent = root
		return fire
	end,
	Paralyzed = function(root)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Schools.Electricity.Halo
		sparkles.Parent = root
		return sparkles
	end,
	ArcaneCharge = function(root)
		local light = Instance.new("PointLight")
		light.Color = Schools.Energy.Halo
		light.Range = 8
		light.Brightness = 3
		light.Parent = root
		return light
	end,
	Bleeding = function(root)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Schools.Blood.Halo
		sparkles.Parent = root
		return sparkles
	end,
}

local attached: { [Model]: { [string]: Instance } } = setmetatable({}, { __mode = "k" }) :: any

local function refreshStates()
	local candidates: { Model } = {}
	local world = Workspace:FindFirstChild("ArcanumWorld")
	local enemies = world and world:FindFirstChild("Enemies")
	if enemies then
		for _, child in enemies:GetChildren() do
			if child:IsA("Model") then
				table.insert(candidates, child)
			end
		end
	end
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(candidates, plr.Character)
		end
	end

	for _, model in candidates do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local current = attached[model] or {}
			attached[model] = current
			for state, factory in STATE_EFFECTS do
				local on = model:GetAttribute("State_" .. state) == true
				if on and not current[state] then
					current[state] = factory(root)
				elseif not on and current[state] then
					current[state]:Destroy()
					current[state] = nil
				end
			end
		end
	end
end

-- Eventos do servidor ---------------------------------------------------------------------------

local HANDLERS: { [string]: (any) -> () } = {
	Cast = function(p)
		castRing(p.Caster, p.School)
	end,
	Bolt = function(p)
		lightning(p.From, p.To, p.School, 3, 0.15)
		if p.Hit then
			flash(p.To, p.School, 1.2)
		end
	end,
	LifeStream = function(p)
		if p.Hit then
			lifeStream(p.To, p.Caster, p.School)
			flash(p.To, p.School, 0.9)
		end
	end,
	ProjectileSpawn = spawnProjectile,
	ProjectileEnd = endProjectile,
	Chain = function(p)
		local points = p.Points
		for i = 1, #points - 1 do
			lightning(points[i], points[i + 1], p.School, 4, 0.11)
		end
	end,
	ChannelEnd = function(_) end,
	Damage = function(p)
		if p.Target and p.Target.Parent then
			local palette = paletteOf(p.School)
			floatingNumber(
				p.Target,
				string.format("%.1f", p.Amount),
				if p.Periodic then palette.Accent else Color3.new(1, 1, 1),
				p.Periodic
			)
		end
	end,
	Heal = function(p)
		if p.Target and p.Target.Parent then
			floatingNumber(p.Target, string.format("+%.1f", p.Amount), Color3.fromRGB(90, 255, 140), true)
		end
	end,
}

local function dispatch(kind: string, payload: any)
	local handler = HANDLERS[kind]
	if handler then
		handler(payload)
	end
end

function VfxController.start()
	folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = Workspace

	Net.get("Vfx").OnClientEvent:Connect(dispatch)
	Net.get("VfxFast").OnClientEvent:Connect(dispatch)
	RunService.RenderStepped:Connect(stepProjectiles)

	task.spawn(function()
		while true do
			refreshStates()
			task.wait(0.25)
		end
	end)
end

return VfxController
