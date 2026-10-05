--!strict
-- Animacao procedural das criaturas (so visual, no cliente). Da vida ao que nao tem animacao:
--   * Gosmas: respiram, esticam ao saltar e amassam ao pousar (mola), agacham tremendo no aviso
--     do bote e balancam atordoadas.
--   * Bulbo: flutua, oscila e gira devagar; incha e treme antes de explodir.
--   * Humanoides: a cabeca acompanha o alvo (atributo TargetUserId) e o tronco cambaleia atordoado.
--   * Todas: tranco para tras ao receber golpe (flinch), na direcao oposta ao atacante.
-- Escreve Motor6D.Transform no Stepped (depois das animacoes), somando ao que o Animator escreveu.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Creatures = {}

type Entry = {
	Model: Model,
	Kind: string,
	Root: BasePart?,
	Body: BasePart?,
	BodyMotor: Motor6D?,
	Mesh: SpecialMesh?,
	BodyHeight: number,
	Neck: Motor6D?,
	Waist: Motor6D?,
	UpperTorso: BasePart?,
	Phase: number,
	Squash: number,
	SquashVelocity: number,
	LastVelocityY: number,
	Flinch: number,
	FlinchDirection: Vector3, -- espaco do modelo, unitario no plano
	Look: Vector2, -- (yaw, pitch) atual da cabeca
	Windup: any,
	WindupStart: number,
}

type Overlay = { Written: CFrame, Base: CFrame }

local entries: { [Model]: Entry } = {}
local overlays: { [Motor6D]: Overlay } = setmetatable({}, { __mode = "k" }) :: any

-- Soma uma rotacao/deslocamento ao Transform animado sem acumular entre quadros: se o Animator
-- nao reescreveu o motor desde o ultimo quadro, parte da mesma base de antes.
local function overlay(motor: Motor6D, extra: CFrame)
	local previous = overlays[motor]
	local current = motor.Transform
	local base = if previous and current == previous.Written then previous.Base else current
	local written = extra * base
	motor.Transform = written
	overlays[motor] = { Written = written, Base = base }
end

local function find(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function track(model: Model)
	if entries[model] then
		return
	end
	local kind = model:GetAttribute("Creature")
	local root = find(model, "HumanoidRootPart")
	local body = find(model, "Body")
	local head = find(model, "Head")
	local lower = find(model, "LowerTorso")
	local entry: Entry = {
		Model = model,
		Kind = if typeof(kind) == "string" then kind else "Plain",
		Root = root,
		Body = body,
		BodyMotor = if root then root:FindFirstChild("Body") :: Motor6D? else nil,
		Mesh = if body then body:FindFirstChildOfClass("SpecialMesh") else nil,
		BodyHeight = if body then body.Size.Y else 0,
		Neck = if head then head:FindFirstChild("Neck") :: Motor6D? else nil,
		Waist = if lower then lower:FindFirstChild("Root") :: Motor6D? else nil,
		UpperTorso = find(model, "UpperTorso"),
		Phase = math.random() * 10,
		Squash = 1,
		SquashVelocity = 0,
		LastVelocityY = 0,
		Flinch = 0,
		FlinchDirection = Vector3.zAxis,
		Look = Vector2.zero,
		Windup = nil,
		WindupStart = 0,
	}
	entries[model] = entry
end

-- Golpe recebido: tranco para longe do atacante.
function Creatures.flinch(model: Model, from: Vector3?, strength: number?)
	local entry = entries[model]
	if not entry or not entry.Root then
		return
	end
	local rootCFrame = entry.Root.CFrame
	local direction = if from then rootCFrame:VectorToObjectSpace(rootCFrame.Position - from) else Vector3.zAxis
	direction = Vector3.new(direction.X, 0, direction.Z)
	entry.FlinchDirection = if direction.Magnitude > 0.01 then direction.Unit else Vector3.zAxis
	entry.Flinch = math.min(entry.Flinch + (strength or 1), 1.6)
	entry.SquashVelocity -= 3 * (strength or 1)
end

local function targetHead(model: Model): Vector3?
	local id = model:GetAttribute("TargetUserId")
	if typeof(id) ~= "number" then
		return nil
	end
	local player = Players:GetPlayerByUserId(id)
	local character = player and player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	return if head then head.Position else nil
end

local function spring(entry: Entry, target: number, dt: number, stiffness: number, damping: number)
	local acceleration = stiffness * (target - entry.Squash) - damping * entry.SquashVelocity
	entry.SquashVelocity += acceleration * dt
	entry.Squash = math.clamp(entry.Squash + entry.SquashVelocity * dt, 0.45, 1.7)
end

local function animateSlime(entry: Entry, now: number, dt: number)
	local root, motor, mesh = entry.Root, entry.BodyMotor, entry.Mesh
	if not root or not motor or not mesh then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local t = now + entry.Phase

	-- Pouso: impulso de amassar proporcional a queda.
	if entry.LastVelocityY < -8 and velocity.Y > -2 then
		entry.SquashVelocity -= math.clamp(-entry.LastVelocityY * 0.25, 2, 8)
	end
	entry.LastVelocityY = velocity.Y

	local target = 1 + 0.05 * math.sin(t * 3)
	if entry.Windup == "Pounce" then
		local progress = math.clamp((now - entry.WindupStart) / 0.5, 0, 1)
		target = 1 - 0.38 * progress + math.sin(t * 50) * 0.03 * progress
	elseif velocity.Y > 4 then
		target = 1.28
	elseif velocity.Y < -4 then
		target = 1.12
	elseif horizontal > 1 then
		target += 0.07 * math.sin(t * 13)
	end
	if entry.Model:GetAttribute("Staggered") then
		target = 0.85 + 0.1 * math.sin(t * 16)
	end
	spring(entry, target, dt, 320, 14)

	local squash = entry.Squash
	local wide = 1 / math.sqrt(squash)
	mesh.Scale = Vector3.new(wide, squash, wide)

	entry.Flinch *= math.exp(-dt * 8)
	local f = entry.Flinch * 0.35
	local tilt = CFrame.Angles(entry.FlinchDirection.Z * f, 0, -entry.FlinchDirection.X * f)
	motor.Transform = CFrame.new(0, (squash - 1) * entry.BodyHeight / 2, 0) * tilt
end

local function animateBloater(entry: Entry, now: number, dt: number)
	local motor, mesh = entry.BodyMotor, entry.Mesh
	if not motor or not mesh then
		return
	end
	local t = now + entry.Phase
	local inflate = 1 + 0.04 * math.sin(t * 2.1)
	local shake = Vector3.zero
	if entry.Windup == "Explode" then
		local progress = math.clamp((now - entry.WindupStart) / 1.1, 0, 1)
		inflate = 1 + 0.45 * progress * progress
		local amount = 0.15 * progress
		shake = Vector3.new(math.sin(t * 47) * amount, math.sin(t * 53) * amount, math.cos(t * 41) * amount)
	end
	mesh.Scale = Vector3.one * inflate

	entry.Flinch *= math.exp(-dt * 6)
	local f = entry.Flinch * 0.5
	motor.Transform = CFrame.new(Vector3.new(0, math.sin(t * 1.6) * 0.4, 0) + shake)
		* CFrame.Angles(
			math.sin(t * 1.1) * 0.08 + entry.FlinchDirection.Z * f,
			(t * 0.5) % (math.pi * 2),
			math.cos(t * 1.3) * 0.08 - entry.FlinchDirection.X * f
		)
end

local function animateHumanoid(entry: Entry, now: number, dt: number)
	local t = now + entry.Phase
	-- Cabeca acompanha o alvo (limitada, suave).
	local neck, torso = entry.Neck, entry.UpperTorso
	if neck and torso then
		local desired = Vector2.zero
		local look = targetHead(entry.Model)
		local head = find(entry.Model, "Head")
		if look and head then
			local relative = torso.CFrame:PointToObjectSpace(look)
			local neckPoint = torso.CFrame:PointToObjectSpace(head.Position)
			local delta = relative - neckPoint
			local yaw = math.atan2(-delta.X, -delta.Z)
			local pitch = math.atan2(delta.Y, Vector2.new(delta.X, delta.Z).Magnitude)
			desired = Vector2.new(math.clamp(yaw, -1.1, 1.1), math.clamp(pitch, -0.5, 0.6))
		end
		entry.Look = entry.Look:Lerp(desired, 1 - math.exp(-dt * 6))
		overlay(neck, CFrame.fromEulerAnglesYXZ(entry.Look.Y, entry.Look.X, 0))
	end

	-- Tronco: tranco do golpe e cambaleio quando atordoado.
	local waist = entry.Waist
	if waist then
		entry.Flinch *= math.exp(-dt * 9)
		local f = entry.Flinch * 0.3
		local wobble = if entry.Model:GetAttribute("Staggered") then math.sin(t * 7) * 0.18 else 0
		if f > 0.002 or wobble ~= 0 then
			overlay(
				waist,
				CFrame.Angles(
					entry.FlinchDirection.Z * f + math.abs(wobble) * 0.5,
					0,
					-entry.FlinchDirection.X * f + wobble
				)
			)
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	for model, entry in entries do
		if not model.Parent then
			entries[model] = nil
			continue
		end
		local windup = model:GetAttribute("Windup")
		if windup ~= entry.Windup then
			entry.Windup = windup
			entry.WindupStart = now
		end
		if entry.Kind == "Slime" then
			animateSlime(entry, now, dt)
		elseif entry.Kind == "Bloater" then
			animateBloater(entry, now, dt)
		else
			animateHumanoid(entry, now, dt)
		end
	end
end

function Creatures.start()
	task.spawn(function()
		while true do
			local world = Workspace:FindFirstChild("ArcanumWorld")
			local enemies = world and world:FindFirstChild("Enemies")
			if enemies then
				for _, model in enemies:GetChildren() do
					if model:IsA("Model") and model:FindFirstChild("HumanoidRootPart") then
						track(model)
					end
				end
			end
			task.wait(0.5)
		end
	end)
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

-- Para o teste de fumaca: registra e anima um quadro.
function Creatures.debugStep(model: Model, dt: number)
	track(model)
	step(dt)
end

return Creatures
