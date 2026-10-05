--!strict
-- Animacao local dos cajados (todos os personagens, so visual):
-- * transicao suave entre as poses Idle e Cast de Shared/StaffPose (mola exponencial);
-- * a mao direita SEMPRE na empunhadura: IK de dois ossos (HandIK) sobrescreve a animacao do braco;
-- * respiracao leve parado e inclinacao contra o movimento ao andar (sem tremer com a mao);
-- * fragmentos orbitando a gema; pulso da gema e faiscas espiralando ao conjurar.
-- O servidor so cria o cajado na pose Idle; nada aqui replica.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local StaffPose = require(Shared.StaffPose)
local Lib = require(script.Parent.Lib)
local HandIK = require(script.Parent.HandIK)

local Staff = {}

local TAG = "ArcanumStaff"
-- Gesto da mao esquerda ao conjurar (espaco do HumanoidRootPart): palma a frente do peito.
local LEFT_HAND_CAST = Vector3.new(-0.45, 1.15, -1.75)
-- Mola da estocada: antecipacao (recua) -> golpe (avanca e passa do ponto) -> volta.
local THRUST_STIFFNESS = 260
local THRUST_DAMPING = 17
local ANTICIPATION = 0.32 -- studs para tras
local THRUST_KICK = -16 -- velocidade inicial para a frente
local CAST_HOLD = 0.4 -- segundos na pose Cast apos conjurar
local RISE_SPEED = 22 -- quanto maior, mais rapido sobe para a pose Cast
local SETTLE_SPEED = 7 -- volta suave para Idle
local MAX_TILT = math.rad(10)

type Entry = {
	Model: Model, -- o cajado
	Character: Model,
	Grip: Weld,
	Current: CFrame, -- pose atual (espaco do HumanoidRootPart, sem AXIS)
	CastUntil: number,
	Tilt: Vector2,
	Shards: { Weld },
	Phase: number,
	Rig: HandIK.Rig?,
	LeftRig: HandIK.Rig?,
	LeftWeight: number,
	Thrust: number,
	ThrustVelocity: number,
	ThrustTarget: number,
	GemLight: PointLight?,
}

local entries: { [Model]: Entry } = {}

local function track(staff: Instance)
	if not staff:IsA("Model") then
		return
	end
	-- As pecas podem chegar pela rede um pouco depois do Model: espera a raiz e a Weld.
	local root = staff:WaitForChild("Root", 5)
	local grip = root and root:WaitForChild("StaffGrip", 5)
	local character = staff.Parent
	if not character or not character:IsA("Model") or not grip or not grip:IsA("Weld") then
		return
	end
	local shards = {}
	for _, child in staff:GetChildren() do
		local weld = child:FindFirstChild("ShardWeld")
		if weld and weld:IsA("Weld") then
			table.insert(shards, weld)
		end
	end
	entries[character] = {
		Model = staff,
		Character = character,
		Grip = grip,
		Current = StaffPose.Poses.Idle,
		CastUntil = 0,
		Tilt = Vector2.zero,
		Shards = shards,
		Phase = math.random() * math.pi * 2,
		Rig = HandIK.rig(character, "Right"),
		LeftRig = HandIK.rig(character, "Left"),
		LeftWeight = 0,
		Thrust = 0,
		ThrustVelocity = 0,
		ThrustTarget = 0,
		GemLight = (staff:FindFirstChild("Gem") and (staff :: any).Gem:FindFirstChild("GemLight")) :: PointLight?,
	}
end

local function untrack(staff: Instance)
	for character, entry in entries do
		if entry.Model == staff then
			entries[character] = nil
		end
	end
end

local function pulseGem(staff: Model, palette: Lib.Palette)
	local gem = staff:FindFirstChild("Gem") :: BasePart?
	if not gem then
		return
	end
	gem.Color = palette.Halo
	TweenService:Create(
		gem,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
		{ Size = Vector3.one * 0.95 }
	):Play()
	local light = gem:FindFirstChild("GemLight") :: PointLight?
	if light then
		light.Color = palette.Halo
		TweenService:Create(
			light,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
			{ Brightness = 7, Range = 16 }
		):Play()
	end
	local muzzle = gem:FindFirstChild("Muzzle") :: Attachment?
	if muzzle then
		-- Faiscas espiralando PARA DENTRO da gema (velocidade negativa).
		local e = Lib.emitter(muzzle, "Star", palette, {
			Speed = NumberRange.new(-7, -4),
			Lifetime = NumberRange.new(0.15, 0.22),
			Size = Lib.seq(0.3, 0),
		})
		e:Emit(12)
		task.delay(0.4, function()
			e:Destroy()
		end)
	end
end

-- Chamado no evento Cast: sobe para a pose Cast e pulsa a gema.
function Staff.cast(character: Model, palette: Lib.Palette)
	local entry = entries[character]
	if not entry then
		return
	end
	entry.CastUntil = os.clock() + CAST_HOLD
	pulseGem(entry.Model, palette)
	-- Antecipacao curta e depois o golpe.
	entry.ThrustTarget = ANTICIPATION
	task.delay(0.06, function()
		entry.ThrustTarget = 0
		entry.ThrustVelocity = THRUST_KICK
	end)
end

-- Cor local da gema do proprio personagem (feedback imediato ao trocar de magia).
function Staff.tintLocal(character: Model?, palette: Lib.Palette)
	local entry = character and entries[character]
	if not entry then
		return
	end
	for _, part in entry.Model:GetChildren() do
		if
			part:IsA("BasePart")
			and (part.Name == "Gem" or part.Name == "GemShell" or part.Name:match("^Shard") or part.Name:match("^Tip"))
		then
			part.Color = palette.Halo
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	for character, entry in entries do
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not entry.Model.Parent or not rootPart then
			entries[character] = nil
			continue
		end

		local casting = now < entry.CastUntil or character:GetAttribute("Channeling") ~= nil
		local target = if casting then StaffPose.Poses.Cast else StaffPose.Poses.Idle

		-- Inclinacao contra o movimento (suavizada) e respiracao quando parado.
		local localVel = rootPart.CFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity)
		local wantTilt = Vector2.new(
			math.clamp(-localVel.Z * 0.012, -MAX_TILT, MAX_TILT), -- frente/tras
			math.clamp(localVel.X * 0.01, -MAX_TILT, MAX_TILT) -- lados
		)
		entry.Tilt = entry.Tilt:Lerp(if casting then Vector2.zero else wantTilt, 1 - math.exp(-dt * 6))
		local breathe = if casting then 0 else math.sin(now * 1.6 + entry.Phase) * 0.04
		local sway = CFrame.new(0, breathe, 0) * CFrame.Angles(entry.Tilt.X, 0, entry.Tilt.Y)

		local speed = if casting then RISE_SPEED else SETTLE_SPEED
		entry.Current = entry.Current:Lerp(target * sway, 1 - math.exp(-dt * speed))

		-- Mola da estocada (somada a pose, no eixo frente/tras do corpo).
		local accel = THRUST_STIFFNESS * (entry.ThrustTarget - entry.Thrust) - THRUST_DAMPING * entry.ThrustVelocity
		entry.ThrustVelocity += accel * math.min(dt, 1 / 30)
		entry.Thrust += entry.ThrustVelocity * math.min(dt, 1 / 30)
		local posed = CFrame.new(0, 0, entry.Thrust) * entry.Current * CFrame.Angles(entry.Thrust * 0.35, 0, 0)
		entry.Grip.C0 = posed * StaffPose.AXIS

		-- Gema pulsando enquanto canaliza.
		if entry.GemLight then
			local channeling = character:GetAttribute("Channeling") ~= nil
			entry.GemLight.Brightness = if channeling then 3.5 + math.sin(now * 22) * 1.5 else 1.5
			entry.GemLight.Range = if channeling then 14 else 8
		end

		-- Mao na empunhadura: o alvo vem da MESMA pose suavizada do cajado, entao os dois andam juntos.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rig = entry.Rig
		if rig and humanoid and humanoid.Health > 0 then
			local grip = (rootPart.CFrame * posed * CFrame.new(0, StaffPose.GRIP_DISTANCE, 0)).Position
			-- Trava: se a empunhadura sair do alcance do braco, o cajado vem ate a mao (nunca o contrario).
			local shoulder = HandIK.shoulderPosition(rig)
			local maxReach = HandIK.reach(rig) * 0.96
			local offset = grip - shoulder
			if offset.Magnitude > maxReach then
				local reachable = shoulder + offset.Unit * maxReach
				local shift = rootPart.CFrame:VectorToObjectSpace(reachable - grip)
				entry.Current = CFrame.new(shift) * entry.Current
				entry.Grip.C0 = CFrame.new(shift) * posed * StaffPose.AXIS
				grip = reachable
			end
			HandIK.apply(rig, grip)
		end

		-- Mao esquerda: gesto de conjuracao (palma a frente), misturado com a animacao.
		local leftRig = entry.LeftRig
		if leftRig and humanoid and humanoid.Health > 0 then
			entry.LeftWeight += ((if casting then 1 else 0) - entry.LeftWeight) * (1 - math.exp(
				-dt * (if casting then 18 else 6)
			))
			if entry.LeftWeight > 0.01 then
				local reach = Vector3.new(0, 0, entry.Thrust * 0.6)
				HandIK.apply(leftRig, rootPart.CFrame:PointToWorldSpace(LEFT_HAND_CAST + reach), entry.LeftWeight)
			end
		end

		-- Fragmentos orbitando a gema (mais rapido ao conjurar).
		entry.Phase += dt * (if casting then 6 else 1.6)
		for i, weld in entry.Shards do
			local angle = entry.Phase + i * (math.pi * 2 / #entry.Shards)
			local radius = if casting then 0.95 else 0.75
			weld.C0 = CFrame.new(
				StaffPose.GEM_DISTANCE + math.sin(angle * 2) * 0.12,
				math.cos(angle) * radius,
				math.sin(angle) * radius
			) * CFrame.Angles(angle, angle * 0.5, 0)
		end
	end
end

function Staff.start()
	for _, staff in CollectionService:GetTagged(TAG) do
		task.spawn(track, staff)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(staff)
		task.spawn(track, staff)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
	-- Stepped roda depois da animacao e antes da fisica: o IK vence a animacao de andar.
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

return Staff
