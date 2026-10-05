--!strict
-- IA de uma criatura: escolhe alvo, se movimenta pelo estilo (EnemyCatalog) e ataca com
-- telegrafia (aviso visual antes do golpe). Usa o mesmo pipeline de magias do jogador
-- (Spells/Projectile + DamageService), so que com os numeros da criatura.
-- Roda no servidor; EnemyService chama step() varias vezes por segundo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
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

export type Brain = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Row: any,
	Behavior: EnemyCatalog.Behavior,
	Home: Vector3,
	Align: AlignOrientation?,
	Target: Model?,
	NextAttack: { [number]: number },
	BusyUntil: number,
	NextBlink: number,
	NextStrafe: number,
	StrafeSide: number,
	Returning: boolean,
}

local EnemyBrain = {}

function EnemyBrain.new(
	model: Model,
	row: any,
	behavior: EnemyCatalog.Behavior,
	align: AlignOrientation?,
	home: Vector3
): Brain?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return nil
	end
	local now = os.clock()
	local nextAttack = {}
	for i in behavior.Attacks do
		nextAttack[i] = now + 1 + math.random() -- nao atacam todos no mesmo instante
	end
	return {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Row = row,
		Behavior = behavior,
		Home = home,
		Align = align,
		Target = nil,
		NextAttack = nextAttack,
		BusyUntil = 0,
		NextBlink = 0,
		NextStrafe = 0,
		StrafeSide = if math.random() < 0.5 then -1 else 1,
		Returning = false,
	}
end

local function alive(model: Model?): boolean
	return StatsService.isAlive(model)
end

local function feet(brain: Brain): Vector3
	return brain.Root.Position - Vector3.new(0, brain.Humanoid.HipHeight + brain.Root.Size.Y / 2, 0)
end

local function face(brain: Brain, position: Vector3)
	local root = brain.Root
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if brain.Align and (flat - root.Position).Magnitude > 0.5 then
		brain.Align.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function hasLineOfSight(brain: Brain, target: Model): boolean
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { brain.Model, target }
	local origin = brain.Root.Position + Vector3.new(0, 1.5, 0)
	return Workspace:Raycast(origin, targetRoot.Position - origin, params) == nil
end

-- Jogador vivo mais proximo dentro do alcance de agressao.
local function acquire(brain: Brain): Model?
	local range = Units.meters(brain.Behavior.AggroMeters)
	local best: Model? = nil
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and alive(character) then
			local dist = (Targeting.position(character) - brain.Root.Position).Magnitude
			-- Mantem o alvo atual com uma folga (nao fica trocando a cada passo).
			local limit = if character == brain.Target then range * 1.4 else range
			if dist < limit then
				range = dist
				best = character
			end
		end
	end
	return best
end

-- Dispara um projetil de magia com os numeros da criatura (variante da linha do CSV).
local function fireProjectile(brain: Brain, attack: EnemyCatalog.Attack, target: Model)
	local spell = SpellsModule.get(attack.SpellId or "Fireball")
	if not spell then
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

	-- Mira com antecipacao parcial do movimento + erro pequeno: desviavel andando.
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end
	local speed = Units.meters(overrides.SpeedMetersPerSecond)
	local distance = (targetRoot.Position - brain.Root.Position).Magnitude
	local lead = targetRoot.AssemblyLinearVelocity * (distance / math.max(speed, 1)) * 0.6
	local jitter = Vector3.new(math.random() - 0.5, math.random() * 0.5, math.random() - 0.5) * 3
	local head = brain.Model:FindFirstChild("Head") :: BasePart?

	Projectile.cast({
		Player = nil,
		Caster = brain.Model,
		Spell = variant,
		Mods = Modifiers.gather(nil, spell.Id, row.School),
		Origin = if head then head.Position else brain.Root.Position,
		AimPoint = targetRoot.Position + lead + jitter,
		Stopped = false,
	})
end

local function damageArea(brain: Brain, center: Vector3, radius: number, amount: number)
	for _, victim in Targeting.hostilesInRadius(brain.Model, center, radius) do
		DamageService.applySpellDamage(brain.Model, victim, amount, brain.Row.School)
	end
end

local function perform(brain: Brain, attack: EnemyCatalog.Attack, target: Model)
	local now = os.clock()
	local row = brain.Row
	local school = row.School
	local damage = row.AttackDamage * (attack.DamageScale or 1)

	if attack.Kind == "Touch" then
		DamageService.applySpellDamage(brain.Model, target, damage, school)
		vfx:FireAllClients("Impact", { Position = Targeting.position(target), School = school, Scale = 0.8 })
		return
	end

	brain.BusyUntil = now + attack.Telegraph + 0.25
	brain.Humanoid:MoveTo(brain.Root.Position) -- para durante o aviso

	if attack.Kind == "Projectile" then
		vfx:FireAllClients(
			"Cast",
			{ Caster = brain.Model, School = school, Tier = 1, SpellId = attack.SpellId, Channeled = false }
		)
		vfx:FireAllClients(
			"EnemyTelegraph",
			{ Kind = "Charge", Model = brain.Model, Duration = attack.Telegraph, School = school }
		)
		task.delay(attack.Telegraph, function()
			if alive(brain.Model) and alive(target) and not StatusService.has(brain.Model, States.Paralyzed) then
				fireProjectile(brain, attack, target)
			end
		end)
	elseif attack.Kind == "Slam" then
		local radius = Units.meters(attack.RadiusMeters or 4)
		local center = feet(brain)
		vfx:FireAllClients("EnemyTelegraph", {
			Kind = "Slam",
			Model = brain.Model,
			Position = center,
			Radius = radius,
			Duration = attack.Telegraph,
			School = school,
		})
		task.delay(attack.Telegraph, function()
			if alive(brain.Model) and not StatusService.has(brain.Model, States.Paralyzed) then
				vfx:FireAllClients("Slam", { Position = center, Radius = radius, School = school })
				damageArea(brain, center + Vector3.new(0, 2, 0), radius, damage)
			end
		end)
	elseif attack.Kind == "Explode" then
		local radius = Units.meters(attack.RadiusMeters or 3)
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
			if alive(brain.Model) then
				local center = brain.Root.Position
				vfx:FireAllClients("Explosion", { Position = center, Radius = radius, School = school })
				damageArea(brain, center, radius, damage)
				brain.Humanoid.Health = 0 -- explode junto
			end
		end)
	end
end

-- Teleporte curto para longe do alvo (Ossomante encurralado).
local function blink(brain: Brain, target: Model)
	local from = brain.Root.Position
	local away = (from - Targeting.position(target)) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	local angle = math.rad(math.random(-60, 60))
	local dir = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(away)
	local goal = from + dir * Units.meters(8)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { brain.Model, target }
	local ground = Workspace:Raycast(goal + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	if not ground then
		return
	end
	local landing = ground.Position + Vector3.new(0, brain.Humanoid.HipHeight + brain.Root.Size.Y / 2 + 0.2, 0)
	vfx:FireAllClients("Blink", { From = from, To = landing, School = brain.Row.School })
	brain.Model:PivotTo(CFrame.lookAt(landing, Vector3.new(from.X, landing.Y, from.Z)))
end

function EnemyBrain.step(brain: Brain)
	local now = os.clock()
	local humanoid = brain.Humanoid
	if humanoid.Health <= 0 or not brain.Model.Parent then
		return
	end
	if StatusService.has(brain.Model, States.Paralyzed) or now < brain.BusyUntil then
		if brain.Target then
			face(brain, Targeting.position(brain.Target))
		end
		return
	end

	local behavior = brain.Behavior
	local root = brain.Root
	local fromHome = (root.Position - brain.Home).Magnitude

	-- Coleira: longe demais de casa, desiste, volta e se cura.
	if brain.Returning or fromHome > Units.meters(behavior.LeashMeters) then
		brain.Returning = fromHome > 4
		brain.Target = nil
		humanoid:MoveTo(brain.Home)
		face(brain, brain.Home)
		if not brain.Returning then
			humanoid.Health = humanoid.MaxHealth
		end
		return
	end

	brain.Target = acquire(brain)
	local target = brain.Target
	if not target then
		if fromHome > 4 then
			humanoid:MoveTo(brain.Home)
			face(brain, brain.Home)
		end
		return
	end

	local targetPos = Targeting.position(target)
	local distance = (targetPos - root.Position).Magnitude
	face(brain, targetPos)

	-- Movimento por estilo.
	if behavior.Style == "Ranged" then
		local keepMin = Units.meters(behavior.KeepMin or 6)
		local keepMax = Units.meters(behavior.KeepMax or 12)
		if
			behavior.BlinkWhenCloserThan
			and distance < Units.meters(behavior.BlinkWhenCloserThan)
			and now >= brain.NextBlink
		then
			brain.NextBlink = now + (behavior.BlinkCooldown or 8)
			blink(brain, target)
			return
		end
		if distance > keepMax or not hasLineOfSight(brain, target) then
			humanoid:MoveTo(targetPos)
		elseif distance < keepMin then
			humanoid:MoveTo(root.Position + (root.Position - targetPos).Unit * 10)
		else
			-- Anda de lado (mais dificil de acertar), trocando de direcao de vez em quando.
			if now >= brain.NextStrafe then
				brain.NextStrafe = now + 1.2 + math.random() * 1.5
				brain.StrafeSide = -brain.StrafeSide
			end
			local toTarget = (targetPos - root.Position).Unit
			local side = toTarget:Cross(Vector3.yAxis) * brain.StrafeSide
			humanoid:MoveTo(root.Position + side * 8)
		end
	else
		humanoid:MoveTo(targetPos)
		if behavior.Hop and math.random() < 0.12 then
			humanoid.Jump = true
		end
	end

	-- Ataque: o primeiro disponivel no alcance (um por passo).
	for i, attack in behavior.Attacks do
		local reach = Units.meters(attack.RangeMeters) + (if attack.Kind == "Touch" then 2.5 else 0)
		if now >= brain.NextAttack[i] and distance <= reach then
			if attack.Kind ~= "Projectile" or hasLineOfSight(brain, target) then
				brain.NextAttack[i] = now + attack.Cooldown + attack.Telegraph
				perform(brain, attack, target)
				break
			end
		end
	end
end

return EnemyBrain
