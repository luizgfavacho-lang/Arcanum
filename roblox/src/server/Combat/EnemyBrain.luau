--!strict
-- IA das criaturas (servidor, ~10 vezes por segundo). Maquina de estados com PERSONALIDADE por
-- individuo (tempo de reacao, agressividade, agilidade, coragem, velocidade), para que dois
-- Ossomantes nunca se comportem igual:
--   Idle    passeia perto de casa, para e olha em volta
--   Alert   viu, ouviu ou apanhou: "!" na cabeca, encara, aponta e chama o bando (tempo de reacao)
--   Combat  luta pelo estilo (EnemyCatalog): flanqueia e cerca, mantem distancia, desvia de magias
--   Search  perdeu o alvo de vista: vai ate onde o viu por ultimo e procura ("?")
--   Return  desistiu (coleira): volta para casa regenerando
--   Flee    pouca vida: foge por alguns segundos e depois volta (so os menos corajosos)
-- Ataques tem telegrafia e podem ser INTERROMPIDOS: quebrar o equilibrio (Math/CombatMath)
-- cancela o golpe em preparacao e atordoa. Golpes fortes empurram criaturas leves.
-- Usa o mesmo pipeline de magias do jogador (Spells/Projectile + DamageService).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local CombatMath = require(Shared.Math.CombatMath)
local SpellMath = require(Shared.Math.SpellMath)
local Net = require(Shared.Net)
local SpellsModule = require(Shared.Spells)
local States = require(Shared.States)
local Units = require(Shared.Units)

local Services = script.Parent.Parent.Services
local DamageService = require(Services.DamageService)
local StatsService = require(Services.StatsService)
local StatusService = require(Services.StatusService)
local Projectile = require(script.Parent.Parent.Spells.Projectile)
local Modifiers = require(script.Parent.Modifiers)
local Targeting = require(script.Parent.Targeting)
local EnemyCatalog = require(script.Parent.EnemyCatalog)

local vfx = Net.get("Vfx")

local FLAT = Vector3.new(1, 0, 1)
local LOSE_SECONDS = 3.5 -- sem ver o alvo por esse tempo: vai procurar
local SEARCH_SECONDS = 9
local SEPARATION_STUDS = 6
local VISION_COS = math.cos(math.rad(75)) -- cone de visao (150 graus)
local RANGED_GAP = 0.7 -- intervalo minimo entre disparos de criaturas diferentes no mesmo alvo

export type Personality = {
	Reaction: number, -- segundos entre perceber e agir
	Aggression: number, -- divide as recargas
	Agility: number, -- 0..1: desviar de magias
	Courage: number, -- 0..1: chance de NAO fugir
	Speed: number, -- multiplicador de velocidade
	Range: number, -- 0..1: distancia preferida entre KeepMin e KeepMax
}

export type Brain = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Row: any,
	Behavior: EnemyCatalog.Behavior,
	Home: Vector3,
	Align: AlignOrientation?,
	Anims: { [string]: AnimationTrack },
	Personality: Personality,
	State: string,
	StateSince: number,
	Target: Model?,
	LastSeenPos: Vector3,
	LastSeenAt: number,
	LastHurt: number,
	AlertUntil: number,
	NextAttack: { [number]: number },
	NextAnyAttack: number,
	BusyUntil: number,
	AttackToken: number,
	Winding: boolean,
	NextBlink: number,
	NextStrafe: number,
	StrafeSide: number,
	StrafePause: boolean,
	FlankAngle: number,
	NextWander: number,
	WanderGoal: Vector3?,
	LookYaw: number,
	LookAroundUntil: number,
	StuckPos: Vector3,
	StuckSince: number,
	DetourUntil: number,
	Poise: CombatMath.Poise,
	Fled: boolean,
	FleeUntil: number,
	Enraged: boolean,
	CooldownScale: number,
	SpeedScale: number,
	SelfDestructed: boolean,
}

local EnemyBrain = {}

local brains: { [Model]: Brain } = {}
local lastShotAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function flat(v: Vector3): Vector3
	return v * FLAT
end

local function alive(model: Model?): boolean
	return StatsService.isAlive(model)
end

local function paralyzed(brain: Brain): boolean
	return StatusService.has(brain.Model, States.Paralyzed)
end

---------------------------------------------------------------------------------------------------
-- Criacao

function EnemyBrain.new(
	model: Model,
	row: any,
	behavior: EnemyCatalog.Behavior,
	align: AlignOrientation?,
	home: Vector3,
	elite: boolean
): Brain?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return nil
	end
	local now = os.clock()
	local nextAttack = {}
	for i in behavior.Attacks do
		nextAttack[i] = now + rand(0.8, 2) -- nao atacam todos no mesmo instante
	end
	local personality: Personality = {
		Reaction = rand(0.25, 0.7) * (if elite then 0.6 else 1),
		Aggression = rand(0.8, 1.3) + (if elite then 0.3 else 0),
		Agility = math.clamp(math.random() + (if elite then 0.3 else 0), 0, 1),
		Courage = math.random(),
		Speed = rand(0.9, 1.12),
		Range = math.random(),
	}
	local brain: Brain = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Row = row,
		Behavior = behavior,
		Home = home,
		Align = align,
		Anims = {},
		Personality = personality,
		State = "Idle",
		StateSince = now,
		Target = nil,
		LastSeenPos = home,
		LastSeenAt = -math.huge,
		LastHurt = -math.huge,
		AlertUntil = 0,
		NextAttack = nextAttack,
		NextAnyAttack = 0,
		BusyUntil = 0,
		AttackToken = 0,
		Winding = false,
		NextBlink = 0,
		NextStrafe = 0,
		StrafeSide = if math.random() < 0.5 then -1 else 1,
		StrafePause = false,
		FlankAngle = math.rad(rand(-70, 70)),
		NextWander = now + rand(1, 4),
		WanderGoal = nil,
		LookYaw = math.random() * math.pi * 2,
		LookAroundUntil = 0,
		StuckPos = root.Position,
		StuckSince = now,
		DetourUntil = 0,
		Poise = CombatMath.newPoise(behavior.Poise),
		Fled = false,
		FleeUntil = 0,
		Enraged = false,
		CooldownScale = 1,
		SpeedScale = 1,
		SelfDestructed = false,
	}
	brains[model] = brain
	return brain
end

function EnemyBrain.get(model: Model): Brain?
	return brains[model]
end

function EnemyBrain.remove(model: Model)
	brains[model] = nil
end

---------------------------------------------------------------------------------------------------
-- Corpo: animacao, velocidade, orientacao, deslocamento

local function play(brain: Brain, name: string, fade: number?, speed: number?)
	local track = brain.Anims[name]
	if track then
		track:Play(fade or 0.15, 1, speed or 1)
	end
end

-- Gargalhada (animacao + som nos clientes).
local function taunt(brain: Brain)
	if brain.Anims.Laugh then
		play(brain, "Laugh", 0.2, 1.2)
		vfx:FireAllClients("Taunt", { Model = brain.Model })
	end
end

local function stopAnim(brain: Brain, name: string)
	local track = brain.Anims[name]
	if track and track.IsPlaying then
		track:Stop(0.2)
	end
end

local function setSpeed(brain: Brain, multiplier: number)
	if paralyzed(brain) then
		return
	end
	local stats = StatsService.get(brain.Model)
	if not stats then
		return
	end
	local speed = SpellMath.slowedSpeed(
		stats.BaseWalkSpeed * multiplier * brain.Personality.Speed * brain.SpeedScale,
		StatusService.value(brain.Model, States.Slowed) or 0
	)
	if math.abs(brain.Humanoid.WalkSpeed - speed) > 0.05 then
		brain.Humanoid.WalkSpeed = speed
	end
end

local function face(brain: Brain, position: Vector3)
	local root = brain.Root
	local target = Vector3.new(position.X, root.Position.Y, position.Z)
	if brain.Align and (target - root.Position).Magnitude > 0.5 then
		brain.Align.CFrame = CFrame.lookAt(root.Position, target)
	end
end

local function feet(brain: Brain): Vector3
	return brain.Root.Position - Vector3.new(0, brain.Humanoid.HipHeight + brain.Root.Size.Y / 2, 0)
end

local function eyes(brain: Brain): Vector3
	local head = brain.Model:FindFirstChild("Head") :: BasePart?
	return if head then head.Position else brain.Root.Position + Vector3.new(0, 1, 0)
end

-- Empurra para longe dos aliados proximos (o bando se espalha em volta do alvo em vez de empilhar).
local function separation(brain: Brain): Vector3
	local push = Vector3.zero
	local position = brain.Root.Position
	for _, other in brains do
		if other ~= brain then
			local delta = flat(position - other.Root.Position)
			local distance = delta.Magnitude
			if distance > 0.01 and distance < SEPARATION_STUDS then
				push += delta.Unit * (1 - distance / SEPARATION_STUDS)
			end
		end
	end
	return push
end

local function moveTo(brain: Brain, goal: Vector3, speedMultiplier: number)
	local now = os.clock()
	local position = brain.Root.Position
	setSpeed(brain, speedMultiplier)
	local toGoal = flat(goal - position)
	local destination = goal + separation(brain) * 6

	-- Desvio temporario quando ficou preso (pula e contorna pelo lado).
	if now < brain.DetourUntil and toGoal.Magnitude > 0.1 then
		destination = position + toGoal.Unit * 4 + toGoal.Unit:Cross(Vector3.yAxis) * brain.StrafeSide * 10
	end
	brain.Humanoid:MoveTo(destination)

	if (position - brain.StuckPos).Magnitude > 1.5 then
		brain.StuckPos = position
		brain.StuckSince = now
	elseif now - brain.StuckSince > 1.2 and toGoal.Magnitude > 5 then
		brain.Humanoid.Jump = true
		brain.StrafeSide = -brain.StrafeSide
		brain.DetourUntil = now + 1
		brain.StuckSince = now
	end
end

local function stop(brain: Brain)
	brain.Humanoid:MoveTo(brain.Root.Position)
	brain.StuckPos = brain.Root.Position
	brain.StuckSince = os.clock()
end

---------------------------------------------------------------------------------------------------
-- Percepcao

local function lineOfSight(brain: Brain, target: Model): boolean
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Aliados nao bloqueiam a visao (o projetil tambem os atravessa).
	params.FilterDescendantsInstances = { brain.Model.Parent or brain.Model, target }
	local origin = eyes(brain)
	return Workspace:Raycast(origin, targetRoot.Position - origin, params) == nil
end

local function canSee(brain: Brain, character: Model, wideOpen: boolean): boolean
	local toTarget = Targeting.position(character) - brain.Root.Position
	local distance = toTarget.Magnitude
	if distance > Units.meters(brain.Behavior.AggroMeters) then
		return false
	end
	if not wideOpen and distance > Units.meters(brain.Behavior.HearMeters) then
		local look = flat(brain.Root.CFrame.LookVector)
		local dir = flat(toTarget)
		if look.Magnitude > 0.01 and dir.Magnitude > 0.01 and look.Unit:Dot(dir.Unit) < VISION_COS then
			return false
		end
	end
	return lineOfSight(brain, character)
end

-- Jogador vivo mais proximo que esta criatura percebe.
local function spot(brain: Brain, wideOpen: boolean): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and alive(character) then
			local distance = (Targeting.position(character) - brain.Root.Position).Magnitude
			if distance < bestDistance and canSee(brain, character, wideOpen) then
				best, bestDistance = character, distance
			end
		end
	end
	return best
end

---------------------------------------------------------------------------------------------------
-- Estados

local function setTarget(brain: Brain, target: Model?)
	brain.Target = target
	local player = if target then Players:GetPlayerFromCharacter(target) else nil
	brain.Model:SetAttribute("TargetUserId", if player then player.UserId else nil)
end

local function setState(brain: Brain, state: string)
	if brain.State == state then
		return
	end
	brain.State = state
	brain.StateSince = os.clock()
	local awareness = if state == "Alert" then "Alert" elseif state == "Search" then "Search" else nil
	brain.Model:SetAttribute("Awareness", awareness)
	if state == "Idle" or state == "Return" then
		setTarget(brain, nil)
	end
end

local alert: (brain: Brain, target: Model, fromPack: boolean, reactionScale: number) -> ()

-- Quem avista primeiro chama os aliados ociosos por perto (cada um reage no seu tempo).
local function callPack(brain: Brain, target: Model)
	local range = Units.meters(brain.Behavior.PackMeters)
	if range <= 0 then
		return
	end
	for _, other in brains do
		if
			other ~= brain
			and (other.State == "Idle" or other.State == "Search")
			and (other.Root.Position - brain.Root.Position).Magnitude < range
		then
			task.delay(rand(0.15, 0.6), function()
				if brains[other.Model] and (other.State == "Idle" or other.State == "Search") and alive(target) then
					alert(other, target, true, 1)
				end
			end)
		end
	end
end

alert = function(brain: Brain, target: Model, fromPack: boolean, reactionScale: number)
	local now = os.clock()
	setTarget(brain, target)
	brain.LastSeenPos = Targeting.position(target)
	brain.LastSeenAt = now
	brain.AlertUntil = now + brain.Personality.Reaction * reactionScale * (if fromPack then 0.7 else 1)
	brain.FlankAngle = math.rad(rand(-70, 70))
	setState(brain, "Alert")
	stop(brain)
	face(brain, brain.LastSeenPos)
	if not fromPack then
		play(brain, "Point", 0.1, 1.4)
		callPack(brain, target)
	end
end

---------------------------------------------------------------------------------------------------
-- Ataques

-- Comeca a preparar um golpe. O token muda se o golpe for interrompido.
local function windup(brain: Brain, duration: number, kind: string): number
	brain.AttackToken += 1
	brain.Winding = true
	brain.Model:SetAttribute("Windup", kind)
	brain.BusyUntil = math.max(brain.BusyUntil, os.clock() + duration + 0.1)
	return brain.AttackToken
end

local function release(brain: Brain)
	brain.Winding = false
	brain.Model:SetAttribute("Windup", nil)
end

local function valid(brain: Brain, token: number): boolean
	return brain.AttackToken == token and alive(brain.Model) and not paralyzed(brain)
end

local function interrupt(brain: Brain)
	if brain.Winding then
		vfx:FireAllClients("Interrupt", { Model = brain.Model })
	end
	brain.AttackToken += 1
	release(brain)
	stopAnim(brain, "Cheer")
end

local function damageArea(brain: Brain, center: Vector3, radius: number, amount: number)
	for _, victim in Targeting.hostilesInRadius(brain.Model, center, radius) do
		DamageService.applySpellDamage(brain.Model, victim, amount, brain.Row.School)
	end
end

-- Dispara um projetil de magia com os numeros da criatura (variante da linha do CSV).
local function fireProjectile(brain: Brain, attack: EnemyCatalog.Attack, target: Model, shot: number)
	local spell = SpellsModule.get(attack.SpellId or "Fireball")
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not spell or not targetRoot then
		return
	end
	local row = brain.Row
	local base = spell.Row
	local overrides = {
		Damage = row.AttackDamage * (attack.DamageScale or 1),
		Count = attack.Count or base.Count,
		SpeedMetersPerSecond = attack.SpeedMetersPerSecond or base.SpeedMetersPerSecond,
		ProcChance = attack.ProcChance or base.ProcChance,
		RangeMeters = attack.RangeMeters * 1.4,
		School = row.School,
	}
	local variant: SpellsModule.Spell = {
		Id = spell.Id,
		Def = spell.Def,
		Row = setmetatable(overrides, { __index = base }),
		Name = spell.Name,
		Desc = spell.Desc,
	}

	-- Mira com antecipacao parcial (cada criatura erra diferente) + erro pequeno: desviavel andando.
	-- O segundo tiro de uma rajada mira onde o jogador iria se desviasse do primeiro.
	local speed = Units.meters(overrides.SpeedMetersPerSecond)
	local distance = (targetRoot.Position - brain.Root.Position).Magnitude
	local leadFactor = (0.35 + brain.Personality.Agility * 0.45) * (if shot > 1 then 1.6 else 1)
	local lead = flat(targetRoot.AssemblyLinearVelocity) * (distance / math.max(speed, 1)) * leadFactor
	local jitter = Vector3.new(rand(-1.5, 1.5), rand(0, 1), rand(-1.5, 1.5))

	Projectile.cast({
		Player = nil,
		Caster = brain.Model,
		Spell = variant,
		Mods = Modifiers.gather(nil, spell.Id, row.School),
		Origin = eyes(brain),
		AimPoint = targetRoot.Position + lead + jitter,
		Stopped = false,
	})
end

local function projectileAttack(brain: Brain, attack: EnemyCatalog.Attack, target: Model)
	local school = brain.Row.School
	local shots = attack.Volley or 1
	if brain.Personality.Aggression > 1.15 and math.random() < 0.35 then
		shots += 1 -- os mais agressivos as vezes disparam em rajada
	end
	local token = windup(brain, attack.Telegraph + (shots - 1) * 0.32, "Projectile")
	vfx:FireAllClients(
		"EnemyTelegraph",
		{ Kind = "Charge", Model = brain.Model, Duration = attack.Telegraph, School = school }
	)
	task.delay(attack.Telegraph, function()
		for shot = 1, shots do
			if not valid(brain, token) or not alive(target) then
				break
			end
			vfx:FireAllClients(
				"Cast",
				{ Caster = brain.Model, School = school, Tier = 1, SpellId = attack.SpellId, Channeled = false }
			)
			fireProjectile(brain, attack, target, shot)
			lastShotAt[target] = os.clock()
			if shot < shots then
				task.wait(0.32)
			end
		end
		if brain.AttackToken == token then
			release(brain)
		end
	end)
end

-- Bote: agacha (aviso), salta na direcao do alvo e acerta quem estiver no caminho.
local function pounceAttack(brain: Brain, attack: EnemyCatalog.Attack, target: Model, damage: number)
	local school = brain.Row.School
	local token = windup(brain, attack.Telegraph + 0.6, "Pounce")
	stop(brain)
	vfx:FireAllClients("EnemyTelegraph", { Kind = "Pounce", Model = brain.Model, Duration = attack.Telegraph })
	task.delay(attack.Telegraph, function()
		if not valid(brain, token) or not alive(target) then
			if brain.AttackToken == token then
				release(brain)
			end
			return
		end
		release(brain)
		local humanoid, root = brain.Humanoid, brain.Root
		local from = root.Position
		local aim = Targeting.position(target)
		local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			aim += flat(targetRoot.AssemblyLinearVelocity) * 0.25
		end
		local toAim = flat(aim - from)
		local direction = if toAim.Magnitude > 0.1 then toAim.Unit else flat(root.CFrame.LookVector).Unit
		local distance = math.min(toAim.Magnitude + 2, Units.meters(attack.RangeMeters) * 1.25)
		-- No ar o Humanoid puxa a velocidade para WalkSpeed: entao a velocidade do salto e a WalkSpeed.
		humanoid.WalkSpeed = math.clamp(distance / 0.55, 8, 70)
		humanoid:MoveTo(from + direction * distance)
		humanoid.Jump = true
		vfx:FireAllClients("Pounce", { Model = brain.Model, Position = feet(brain), School = school })

		local reach = brain.Root.Size.X / 2 + 2.6
		local started = os.clock()
		local hit = false
		while os.clock() - started < 0.65 do
			task.wait(0.05)
			if not alive(brain.Model) then
				return
			end
			if not hit and alive(target) and (Targeting.position(target) - root.Position).Magnitude < reach then
				hit = true
				DamageService.applySpellDamage(brain.Model, target, damage, school)
				vfx:FireAllClients("Impact", { Position = Targeting.position(target), School = school, Scale = 1 })
			end
		end
		stop(brain)
		setSpeed(brain, 1)
	end)
end

local function slamAttack(brain: Brain, attack: EnemyCatalog.Attack, damage: number)
	local school = brain.Row.School
	local repeats = if brain.Enraged then attack.EnrageRepeat or 0 else 0
	local token = windup(brain, attack.Telegraph + repeats * 0.8, "Slam")
	stop(brain)
	play(brain, "Cheer", 0.1, 1.6)

	local function slamAt(index: number)
		local radius = Units.meters(attack.RadiusMeters or 4) * (1 + index * 0.35)
		local center = feet(brain)
		local telegraph = if index == 0 then attack.Telegraph else 0.55
		vfx:FireAllClients("EnemyTelegraph", {
			Kind = "Slam",
			Model = brain.Model,
			Position = center,
			Radius = radius,
			Duration = telegraph,
			School = school,
		})
		task.delay(telegraph, function()
			if not valid(brain, token) then
				return
			end
			stopAnim(brain, "Cheer")
			vfx:FireAllClients("Slam", { Position = center, Radius = radius, School = school })
			damageArea(brain, center + Vector3.new(0, 2, 0), radius, damage)
			if index < repeats then
				play(brain, "Cheer", 0.1, 2)
				slamAt(index + 1)
			else
				release(brain)
			end
		end)
	end
	slamAt(0)
end

-- Linha de cristais do chefe ate o alvo (desvie para o lado).
local function spikeAttack(brain: Brain, attack: EnemyCatalog.Attack, target: Model, damage: number)
	local school = brain.Row.School
	local from = feet(brain)
	local toTarget = flat(Targeting.position(target) - from)
	local direction = if toTarget.Magnitude > 0.1 then toTarget.Unit else flat(brain.Root.CFrame.LookVector).Unit
	local length = Units.meters(attack.LengthMeters or 16)
	local width = Units.meters(attack.WidthMeters or 2)
	local to = from + direction * length
	local token = windup(brain, attack.Telegraph, "SpikeLine")
	stop(brain)
	face(brain, to)
	play(brain, "Cheer", 0.1, 1.8)
	vfx:FireAllClients("EnemyTelegraph", {
		Kind = "Line",
		Model = brain.Model,
		From = from,
		To = to,
		Width = width,
		Duration = attack.Telegraph,
		School = school,
	})
	task.delay(attack.Telegraph, function()
		if not valid(brain, token) then
			return
		end
		release(brain)
		stopAnim(brain, "Cheer")
		vfx:FireAllClients("Spikes", { From = from, To = to, Width = width, School = school })
		task.wait(0.12)
		for _, victim in Targeting.hostilesInRadius(brain.Model, (from + to) / 2, length / 2 + width) do
			if Targeting.distanceToSegment(Targeting.position(victim), from, to) <= width / 2 + 1.2 then
				DamageService.applySpellDamage(brain.Model, victim, damage, school)
			end
		end
	end)
end

local function explodeAttack(brain: Brain, attack: EnemyCatalog.Attack, damage: number)
	local school = brain.Row.School
	local radius = Units.meters(attack.RadiusMeters or 3)
	local token = windup(brain, attack.Telegraph + 1, "Explode")
	brain.Humanoid.WalkSpeed = 0
	vfx:FireAllClients("EnemyTelegraph", {
		Kind = "Explode",
		Model = brain.Model,
		Position = brain.Root.Position,
		Radius = radius,
		Duration = attack.Telegraph,
		School = school,
	})
	task.delay(attack.Telegraph, function()
		if brain.AttackToken ~= token or not alive(brain.Model) then
			return -- morreu antes: quem estoura e o DeathBurst (EnemyService)
		end
		local center = brain.Root.Position
		brain.SelfDestructed = true
		vfx:FireAllClients("Explosion", { Position = center, Radius = radius, School = school })
		damageArea(brain, center, radius, damage)
		brain.Humanoid.Health = 0 -- explode junto
	end)
end

local function perform(brain: Brain, attack: EnemyCatalog.Attack, target: Model)
	local now = os.clock()
	local damage = brain.Row.AttackDamage * (attack.DamageScale or 1)
	local kind = attack.Kind
	if kind == "Touch" then
		DamageService.applySpellDamage(brain.Model, target, damage, brain.Row.School)
		vfx:FireAllClients("Impact", { Position = Targeting.position(target), School = brain.Row.School, Scale = 0.8 })
		brain.BusyUntil = now + 0.25
	elseif kind == "Projectile" then
		projectileAttack(brain, attack, target)
	elseif kind == "Pounce" then
		pounceAttack(brain, attack, target, damage)
	elseif kind == "Slam" then
		slamAttack(brain, attack, damage)
	elseif kind == "SpikeLine" then
		spikeAttack(brain, attack, target, damage)
	elseif kind == "Explode" then
		explodeAttack(brain, attack, damage)
	end
	brain.BusyUntil = math.max(brain.BusyUntil, now + attack.Telegraph + (attack.Recovery or 0.2))
	-- Pausa curta e variada antes do proximo golpe (nada de metralhadora ritmada).
	brain.NextAnyAttack = brain.BusyUntil + rand(0.3, 0.9) / brain.Personality.Aggression
end

-- Escolhe o primeiro ataque pronto que serve para a distancia atual.
local function tryAttack(brain: Brain, target: Model, distance: number, visible: boolean): boolean
	local now = os.clock()
	if now < brain.NextAnyAttack then
		return false
	end
	for i, attack in brain.Behavior.Attacks do
		local reach = Units.meters(attack.RangeMeters) + (if attack.Kind == "Touch" then 2.5 else 0)
		local minimum = Units.meters(attack.MinRangeMeters or 0)
		if now >= brain.NextAttack[i] and distance <= reach and distance >= minimum then
			local needsSight = attack.Kind == "Projectile" or attack.Kind == "Pounce" or attack.Kind == "SpikeLine"
			local crowded = attack.Kind == "Projectile" and now - (lastShotAt[target] or -math.huge) < RANGED_GAP
			if (not needsSight or visible) and not crowded then
				local jitter = rand(0.85, 1.25)
				brain.NextAttack[i] = now
					+ (attack.Cooldown * jitter * brain.CooldownScale / brain.Personality.Aggression)
					+ attack.Telegraph
				perform(brain, attack, target)
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------------------------------------------
-- Reacoes

-- Teleporte curto para longe do alvo (Ossomante encurralado ou desviando).
local function blink(brain: Brain, awayFrom: Vector3, sideways: boolean)
	local from = brain.Root.Position
	local away = flat(from - awayFrom)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	-- `awayFrom` ja e lateral no desvio: so um pouco de variacao.
	local angle = if sideways then math.rad(rand(-20, 20)) else math.rad(rand(-60, 60))
	local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(away)
	local goal = from + direction * Units.meters(if sideways then 4 else 8)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { brain.Model.Parent or brain.Model }
	local ground = Workspace:Raycast(goal + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	if not ground then
		return false
	end
	local landing = ground.Position + Vector3.new(0, brain.Humanoid.HipHeight + brain.Root.Size.Y / 2 + 0.2, 0)
	vfx:FireAllClients("Blink", { From = from, To = landing, School = brain.Row.School })
	brain.Model:PivotTo(CFrame.lookAt(landing, Vector3.new(awayFrom.X, landing.Y, awayFrom.Z)))
	return true
end

local function knockback(brain: Brain, from: Vector3, speed: number)
	local direction = flat(brain.Root.Position - from)
	if direction.Magnitude < 0.1 then
		return
	end
	local attachment = brain.Root:FindFirstChild("KnockbackAttachment") :: Attachment?
	if not attachment then
		local a = Instance.new("Attachment")
		a.Name = "KnockbackAttachment"
		a.Parent = brain.Root
		attachment = a
	end
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = direction.Unit * speed + Vector3.new(0, speed * 0.25, 0)
	push.MaxForce = math.huge
	push.Parent = brain.Root
	Debris:AddItem(push, Settings.KnockbackDuration)
end

local function stagger(brain: Brain, duration: number)
	interrupt(brain)
	local now = os.clock()
	brain.BusyUntil = math.max(brain.BusyUntil, now + duration)
	brain.NextAnyAttack = math.max(brain.NextAnyAttack, now + duration + 0.3)
	stop(brain)
	vfx:FireAllClients("Stagger", { Model = brain.Model, Duration = duration })
	brain.Model:SetAttribute("Staggered", true)
	task.delay(duration, function()
		if brain.Model.Parent then
			brain.Model:SetAttribute("Staggered", nil)
		end
	end)
end

-- Fica furioso com pouca vida (chefe): ruge, fica mais rapido e ataca mais.
local function enrage(brain: Brain)
	local config = brain.Behavior.Enrage
	if not config then
		return
	end
	brain.Enraged = true
	interrupt(brain)
	local now = os.clock()
	brain.BusyUntil = now + 1.6
	brain.Poise.ImmuneUntil = now + 4
	stop(brain)
	play(brain, "Cheer", 0.1, 0.8)
	vfx:FireAllClients("Roar", { Model = brain.Model, School = brain.Row.School })
	task.delay(1.6, function()
		stopAnim(brain, "Cheer")
		brain.CooldownScale = config.CooldownScale
		brain.SpeedScale = config.SpeedScale
		brain.Model:SetAttribute("Enraged", true)
	end)
end

-- Ja nasce de olho em alguem (ex.: gosminhas que saem da gosma morta).
function EnemyBrain.provoke(brain: Brain, target: Model)
	alert(brain, target, true, 0.4)
end

-- Chamado pelo EnemyService a cada golpe recebido.
function EnemyBrain.hurt(brain: Brain, source: Model?, amount: number, periodic: boolean)
	if brain.Humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	brain.LastHurt = now

	if source and source ~= brain.Model and Targeting.isHostile(brain.Model, source) then
		local state = brain.State
		if state == "Idle" or state == "Search" then
			alert(brain, source, false, 0.5)
		elseif state == "Return" then
			if (brain.Root.Position - brain.Home).Magnitude < Units.meters(brain.Behavior.LeashMeters) then
				alert(brain, source, false, 0.5)
			end
		elseif state == "Alert" then
			brain.AlertUntil = math.min(brain.AlertUntil, now + 0.15)
		elseif state == "Combat" and source ~= brain.Target and math.random() < 0.4 then
			setTarget(brain, source) -- vira para quem esta batendo
		end
		brain.LastSeenPos = Targeting.position(source)
		brain.LastSeenAt = now
	end

	local enrageConfig = brain.Behavior.Enrage
	if
		enrageConfig
		and not brain.Enraged
		and brain.Humanoid.Health / math.max(brain.Humanoid.MaxHealth, 1) < enrageConfig.Below
	then
		enrage(brain)
		return
	end

	if periodic or amount <= 0 then
		return
	end
	if CombatMath.hitPoise(brain.Poise, amount, now, Settings) then
		stagger(brain, brain.Behavior.StaggerTime)
	elseif not brain.Winding and now >= brain.BusyUntil then
		brain.BusyUntil = now + 0.12 -- micro-pausa de impacto
	end
	local speed = CombatMath.knockbackSpeed(amount, brain.Humanoid.MaxHealth, brain.Behavior.Weight, Settings)
	if speed > 0 and source then
		knockback(brain, Targeting.position(source), speed)
	end
end

-- Um projetil foi lancado: criaturas ageis na linha de tiro tentam sair do caminho.
local function onProjectile(caster: Model, position: Vector3, velocity: Vector3)
	local speed = velocity.Magnitude
	if speed < 1 then
		return
	end
	local direction = velocity / speed
	for _, brain in brains do
		local chance = brain.Behavior.DodgeChance
		if
			chance
			and (brain.State == "Combat" or brain.State == "Alert")
			and not brain.Winding
			and Targeting.isHostile(caster, brain.Model)
		then
			local relative = brain.Root.Position - position
			local along = relative:Dot(direction)
			local miss = relative - direction * along
			local timeToHit = along / speed
			if
				along > 0
				and miss.Magnitude < 4.5
				and timeToHit > 0.18
				and math.random() < chance * (0.4 + brain.Personality.Agility * 0.6)
			then
				local react = math.min(brain.Personality.Reaction * 0.5, timeToHit * 0.5)
				task.delay(react, function()
					if not brains[brain.Model] or brain.Winding or paralyzed(brain) then
						return
					end
					local side = flat(miss)
					side = if side.Magnitude > 0.3
						then side.Unit
						else direction:Cross(Vector3.yAxis).Unit * (if math.random() < 0.5 then -1 else 1)
					local now = os.clock()
					if
						brain.Behavior.BlinkWhenCloserThan
						and now >= brain.NextBlink
						and math.random() < 0.3
						and blink(brain, brain.Root.Position - side * 10, true)
					then
						brain.NextBlink = now + (brain.Behavior.BlinkCooldown or 8)
						return
					end
					setSpeed(brain, 2.2)
					brain.Humanoid:MoveTo(brain.Root.Position + side * 9)
					brain.BusyUntil = math.max(brain.BusyUntil, now + 0.45)
				end)
			end
		end
	end
end
Projectile.Launched:Connect(onProjectile)

-- Acertou o jogador: os mais agressivos zombam (gargalhada).
function EnemyBrain.landed(brain: Brain)
	if brain.Anims.Laugh and not brain.Winding and math.random() < 0.3 * brain.Personality.Aggression then
		task.delay(0.3, taunt, brain)
	end
end

---------------------------------------------------------------------------------------------------
-- Comportamento por estado

local function idle(brain: Brain, now: number)
	local seen = spot(brain, false)
	if seen then
		alert(brain, seen, false, 1)
		return
	end
	if now >= brain.NextWander then
		brain.NextWander = now + rand(3, 8)
		local wander = Units.meters(brain.Behavior.WanderMeters)
		if wander > 0 and math.random() < 0.6 then
			local angle = math.random() * math.pi * 2
			local radius = wander * math.sqrt(math.random())
			brain.WanderGoal = brain.Home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		else
			brain.WanderGoal = nil
			brain.LookYaw += rand(-2, 2)
		end
	end
	local goal = brain.WanderGoal
	if goal and flat(goal - brain.Root.Position).Magnitude > 2.5 then
		moveTo(brain, goal, 0.4)
		face(brain, goal)
	else
		if goal then
			brain.WanderGoal = nil
			stop(brain)
		end
		face(brain, brain.Root.Position + Vector3.new(math.cos(brain.LookYaw), 0, math.sin(brain.LookYaw)) * 10)
	end
end

local function returning(brain: Brain)
	local humanoid = brain.Humanoid
	humanoid.Health = math.min(humanoid.Health + humanoid.MaxHealth * 0.15 * 0.1, humanoid.MaxHealth)
	if flat(brain.Home - brain.Root.Position).Magnitude < 4 then
		humanoid.Health = humanoid.MaxHealth
		brain.Fled = false
		stop(brain)
		setState(brain, "Idle")
		return
	end
	moveTo(brain, brain.Home, 1)
	face(brain, brain.Home)
end

local function search(brain: Brain, now: number)
	local seen = spot(brain, true)
	if seen then
		alert(brain, seen, false, 0.5)
		return
	end
	if now - brain.StateSince > SEARCH_SECONDS then
		setState(brain, "Return")
		return
	end
	if flat(brain.LastSeenPos - brain.Root.Position).Magnitude > 4 and brain.LookAroundUntil == 0 then
		moveTo(brain, brain.LastSeenPos, 0.75)
		face(brain, brain.LastSeenPos)
		return
	end
	-- Chegou: olha em volta.
	if brain.LookAroundUntil == 0 then
		brain.LookAroundUntil = now + rand(2, 3.5)
		stop(brain)
	end
	local sweep = math.sin((now - brain.StateSince) * 2.2) * 1.4
	face(
		brain,
		brain.Root.Position + Vector3.new(math.cos(brain.LookYaw + sweep), 0, math.sin(brain.LookYaw + sweep)) * 10
	)
	if now > brain.LookAroundUntil then
		setState(brain, "Return")
	end
end

local function flee(brain: Brain, now: number)
	local target = brain.Target
	if now > brain.FleeUntil or not target then
		setState(brain, "Combat")
		return
	end
	local position = brain.Root.Position
	local away = flat(position - Targeting.position(target))
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	local wobble = away:Cross(Vector3.yAxis) * math.sin(now * 3) * 4
	local goal = position + away * 14 + wobble
	moveTo(brain, goal, 1.2)
	face(brain, goal)
end

-- Movimento de combate pelo estilo.
local function maneuver(brain: Brain, target: Model, distance: number, visible: boolean, now: number)
	local behavior = brain.Behavior
	local position = brain.Root.Position
	local targetPos = Targeting.position(target)
	local toTarget = flat(targetPos - position)
	local towards = if toTarget.Magnitude > 0.1 then toTarget.Unit else flat(brain.Root.CFrame.LookVector).Unit
	local side = towards:Cross(Vector3.yAxis)

	if behavior.Style == "Ranged" then
		local keepMin = Units.meters(behavior.KeepMin or 6)
		local keepMax = Units.meters(behavior.KeepMax or 12)
		local preferred = keepMin + (keepMax - keepMin) * brain.Personality.Range
		face(brain, targetPos)
		if
			behavior.BlinkWhenCloserThan
			and distance < Units.meters(behavior.BlinkWhenCloserThan)
			and now >= brain.NextBlink
		then
			brain.NextBlink = now + (behavior.BlinkCooldown or 8)
			blink(brain, targetPos, false)
			return
		end
		if not visible then
			-- Sem visao: contorna pelo lado (procura um angulo de tiro) em vez de ir reto.
			moveTo(brain, targetPos + side * brain.StrafeSide * 10, 0.9)
		elseif distance > keepMax then
			moveTo(brain, targetPos - towards * preferred + side * brain.StrafeSide * 4, 0.85)
		elseif distance < keepMin then
			moveTo(brain, position - towards * 10 + side * brain.StrafeSide * 4, 1)
		else
			-- Anda de lado com pausas e trocas de direcao irregulares.
			if now >= brain.NextStrafe then
				brain.NextStrafe = now + rand(0.8, 2.4)
				brain.StrafePause = math.random() < 0.25
				if math.random() < 0.6 then
					brain.StrafeSide = -brain.StrafeSide
				end
			end
			if brain.StrafePause then
				stop(brain)
			else
				local drift = (preferred - distance) * 0.5
				moveTo(brain, position + side * brain.StrafeSide * 8 - towards * drift, 0.6)
			end
		end
	elseif behavior.Style == "Kamikaze" then
		-- Zigue-zague que fecha conforme chega perto.
		local amplitude = math.clamp(distance * 0.35, 0, 10)
		moveTo(brain, targetPos + side * math.sin(now * 2.3 + brain.FlankAngle * 3) * amplitude, 1)
		face(brain, targetPos)
	elseif behavior.Style == "Boss" then
		face(brain, targetPos)
		if distance > Units.meters(3.5) then
			moveTo(brain, targetPos, 1)
		else
			stop(brain)
		end
	else
		-- Melee: aproxima por um angulo proprio (flanqueia) e cerca junto com o bando.
		local fromTarget = flat(position - targetPos)
		fromTarget = if fromTarget.Magnitude > 0.1 then fromTarget.Unit else -towards
		local approach = CFrame.fromAxisAngle(Vector3.yAxis, brain.FlankAngle):VectorToWorldSpace(fromTarget)
		local ring = math.max(distance - 8, 3)
		moveTo(brain, targetPos + approach * ring, 1)
		face(brain, targetPos)
		if behavior.Hop and math.random() < 0.08 then
			brain.Humanoid.Jump = true
		end
	end
end

local function combat(brain: Brain, now: number)
	local target = brain.Target
	if not target or not alive(target) then
		local other = spot(brain, true)
		if other then
			setTarget(brain, other)
			target = other
		else
			stop(brain)
			taunt(brain) -- venceu
			setState(brain, "Return")
			return
		end
	end
	local behavior = brain.Behavior
	local position = brain.Root.Position
	local targetPos = Targeting.position(target)
	local distance = (targetPos - position).Magnitude
	local visible = canSee(brain, target, true)
	if visible then
		brain.LastSeenPos = targetPos
		brain.LastSeenAt = now
	elseif now - brain.LastSeenAt > LOSE_SECONDS then
		brain.LookAroundUntil = 0
		setState(brain, "Search")
		return
	end

	-- Coleira (mais folgada enquanto esta apanhando).
	local leash = Units.meters(behavior.LeashMeters) * (if now - brain.LastHurt < 5 then 1.5 else 1)
	if (position - brain.Home).Magnitude > leash then
		setState(brain, "Return")
		return
	end

	-- Fuga com pouca vida (uma vez), conforme a coragem.
	local health = brain.Humanoid.Health / math.max(brain.Humanoid.MaxHealth, 1)
	if behavior.FleeBelow and not brain.Fled and health < behavior.FleeBelow then
		brain.Fled = true
		if math.random() > brain.Personality.Courage then
			brain.FleeUntil = now + rand(2, 3.2)
			setState(brain, "Flee")
			callPack(brain, target)
			return
		end
	end

	if tryAttack(brain, target, distance, visible) then
		return
	end
	maneuver(brain, target, distance, visible, now)
end

function EnemyBrain.step(brain: Brain)
	local now = os.clock()
	if brain.Humanoid.Health <= 0 or not brain.Model.Parent then
		return
	end
	if paralyzed(brain) or now < brain.BusyUntil then
		-- Golpes de area/bote ficam travados na direcao; a conjuracao acompanha o alvo.
		local tracking = not brain.Winding or brain.Model:GetAttribute("Windup") == "Projectile"
		if brain.Target and tracking then
			face(brain, Targeting.position(brain.Target))
		end
		return
	end

	local state = brain.State
	if state == "Idle" then
		idle(brain, now)
	elseif state == "Alert" then
		if brain.Target then
			face(brain, brain.LastSeenPos)
		end
		if now >= brain.AlertUntil then
			setState(brain, if brain.Target then "Combat" else "Idle")
		end
	elseif state == "Combat" then
		combat(brain, now)
	elseif state == "Search" then
		search(brain, now)
	elseif state == "Flee" then
		flee(brain, now)
	elseif state == "Return" then
		returning(brain)
	end
end

function EnemyBrain.stepAll()
	for model, brain in brains do
		if not model.Parent then
			brains[model] = nil
		else
			local ok, err = pcall(EnemyBrain.step, brain)
			if not ok then
				warn("[Enemy] erro na IA de " .. model.Name .. ": " .. tostring(err))
				brains[model] = nil
			end
		end
	end
end

return EnemyBrain
