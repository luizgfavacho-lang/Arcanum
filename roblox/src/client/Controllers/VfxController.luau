--!strict
-- Recebe os eventos visuais do servidor (Vfx/VfxFast/CastFeedback) e aciona os modulos de
-- client/Vfx, o HUD e a camera. Tudo aqui e cosmetico: nenhuma regra de jogo roda no cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Spells = require(Shared.Spells)

local Vfx = script.Parent.Parent.Vfx
local Lib = require(Vfx.Lib)
local Effects = require(Vfx.Effects)
local Lightning = require(Vfx.Lightning)
local Projectiles = require(Vfx.Projectiles)
local LifeStream = require(Vfx.LifeStream)
local Numbers = require(Vfx.Numbers)
local Staff = require(Vfx.Staff)
local Auras = require(Vfx.Auras)
local Audio = require(Vfx.Audio)
local Creatures = require(Vfx.Creatures)
local DodgeAnim = require(Vfx.DodgeAnim)
local SpellFx = require(Vfx.SpellFx)
local ZoneFx = require(Vfx.ZoneFx)
local StrikeFx = require(Vfx.StrikeFx)
local Impact = require(Vfx.Impact)
local FlameFx = require(Vfx.FlameFx)
local SignatureFx = require(Vfx.SignatureFx)
local ClientState = require(script.Parent.ClientState)
local CameraController = require(script.Parent.CameraController)
local HudController = require(script.Parent.HudController)

local player = Players.LocalPlayer

local VfxController = {}

local function isMine(model: any): boolean
	return model ~= nil and model == player.Character
end

local function distanceToMe(position: Vector3): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then (root.Position - position).Magnitude else math.huge
end

-- Tremor proporcional a distancia (impactos perto tremem mais).
local function shakeNear(position: Vector3, strength: number, radius: number)
	local d = distanceToMe(position)
	if d < radius then
		CameraController.shake(strength * (1 - d / radius))
	end
end

-- Flash branco rapido no corpo atingido.
local function hitFlash(model: Model)
	local existing = model:FindFirstChild("ArcanumHitFlash")
	if existing then
		existing:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ArcanumHitFlash"
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(0.14), { FillTransparency = 1 }):Play()
	task.delay(0.15, function()
		highlight:Destroy()
	end)
end

-- Morte: o corpo se desfaz em luz da escola e sobe levemente.
local function dissolve(model: Model, palette: Lib.Palette, boss: boolean)
	local root = Lib.rootPosition(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = false
			TweenService:Create(part, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Color = palette.Halo,
			}):Play()
		elseif part:IsA("Decal") then
			TweenService:Create(part, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
	end
	if root then
		local scale = if boss then 2.5 else 1
		Effects.flash(root, palette, 1.6 * scale, true)
		Lib.burst(root, "Wisp", palette, math.floor(24 * scale), { Speed = NumberRange.new(3, 9) })
		Lib.burst(root, "Star", palette, math.floor(14 * scale))
		Effects.shockwave(Lib.groundBelow(root, model), palette, 5 * scale)
		Audio.play("Death", root)
	end
end

-- Corpo piscando (telegrafia do Bulbo): cada vez mais rapido ate explodir.
local function pulseWarning(model: Model, duration: number, color: Color3)
	local highlight = Instance.new("Highlight")
	highlight.Name = "ArcanumWarning"
	highlight.FillColor = color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 1
	highlight.Parent = model
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < duration and model.Parent do
			local progress = (os.clock() - started) / duration
			highlight.FillTransparency = if highlight.FillTransparency > 0.5 then 0.2 else 0.9
			task.wait(0.22 * (1 - progress) + 0.04)
		end
		highlight:Destroy()
	end)
end

local DANGER = Color3.fromRGB(255, 70, 60)
local GOLD = Color3.fromRGB(255, 214, 90)
local DODGE = Color3.fromRGB(150, 220, 255)

-- Avisos ativos por criatura: um golpe interrompido apaga o aviso na hora.
type Telegraph = { Cancel: () -> (), EndsAt: number }
local telegraphs: { [Model]: { Telegraph } } = {}

local function trackTelegraph(model: Model?, cancel: () -> (), duration: number)
	if not model then
		return
	end
	local now = os.clock()
	local list = telegraphs[model] or {}
	for i = #list, 1, -1 do
		if list[i].EndsAt < now then
			table.remove(list, i)
		end
	end
	table.insert(list, { Cancel = cancel, EndsAt = now + duration })
	telegraphs[model] = list
end

local function cancelTelegraphs(model: Model)
	local list = telegraphs[model]
	if list then
		for _, t in list do
			t.Cancel()
		end
		telegraphs[model] = nil
	end
end

local function sourcePosition(source: any): Vector3?
	return if typeof(source) == "Instance" then Lib.rootPosition(source) else nil
end

-- Ponto da mira local (o feixe do proprio jogador segue sem esperar o servidor).
local function localAim(): Vector3
	local _, point = CameraController.getAim()
	return point
end

local HANDLERS: { [string]: (any) -> () } = {
	Cast = function(p)
		if not p.Caster or not p.Caster.Parent then
			return
		end
		local palette = Lib.palette(p.School)
		Staff.cast(p.Caster, palette, p.SpellId)
		Effects.castSignature(p.Caster, palette, p.Tier or 1)
		local muzzle = Lib.muzzleOf(p.Caster, Lib.rootPosition(p.Caster) or Vector3.zero)
		SpellFx.flourish(p.SpellId, p.Caster, palette, muzzle, p.School)
		if p.SpellId == "ManaShield" or p.SpellId == "EmberArmor" then
			Audio.play(p.SpellId, muzzle) -- o resto do visual vem da aura do estado
			Effects.flash(Lib.rootPosition(p.Caster) or muzzle, palette, 2.4, true)
		end
		if not p.Channeled then
			-- Conjuracao alheia (inimigos, outros jogadores): clarao menor, para nao estourar a tela.
			Effects.flash(muzzle, palette, if isMine(p.Caster) then 0.9 else 0.45, false)
		end
		Audio.play("Cast_" .. tostring(p.School), muzzle)
		if isMine(p.Caster) then
			HudController.castPulse(p.Slot or ClientState.SelectedSlot)
			CameraController.shake(0.12 + 0.05 * (p.Tier or 1))
			CameraController.kick(1.5 + (p.Tier or 1))
		end
	end,

	-- Faisca: raio ramificado que tremula, faiscas caindo e clarao no alvo.
	Bolt = function(p)
		local palette = Lib.palette(p.School)
		local from = Lib.muzzleOf(p.Caster, p.From)
		Lightning.bolt(from, p.To, palette, { Width = 0.22, Forks = 3, Flickers = 3, Duration = 0.2 })
		Audio.play("Bolt", from)
		if p.Hit then
			Effects.flash(p.To, palette, 1.4, true)
			Lib.burst(p.To, "Spark", palette, 18)
			SpellFx.residueArcs(p.To, palette, 0.6)
			shakeNear(p.To, 0.15, 40)
			if p.Forks and #p.Forks > 0 then
				SignatureFx.forks(p.To, p.Forks, palette)
			end
		end
	end,

	-- Drenar Vida: corrente de vida do alvo ate a gema.
	LifeStream = function(p)
		local palette = Lib.palette(p.School)
		if p.Hit and p.Caster then
			LifeStream.play(p.To, p.Caster, palette)
			Effects.flash(p.To, palette, 1, false)
			task.delay(0.35, SpellFx.healRing, p.Caster, palette)
			Audio.play("LifeDrain", p.To)
		else
			Lib.burst(p.To, "Wisp", palette, 6)
		end
	end,

	ProjectileSpawn = Projectiles.spawn,
	ProjectileEnd = function(p)
		Projectiles.finish(p)
		Audio.play("Impact_" .. tostring(p.School), p.Position)
		shakeNear(p.Position, if p.Radius and p.Radius > 0 then 0.6 else 0.35, 55)
	end,

	-- Corrente em Cadeia: a cada tick, fios trancados por elo e faiscas em cada alvo.
	Chain = function(p)
		local palette = Lib.palette(p.School)
		local points = table.clone(p.Points)
		points[1] = Lib.muzzleOf(p.Caster, points[1])
		for i = 1, #points - 1 do
			Lightning.braid(points[i], points[i + 1], palette, if i == 1 then 7 else 5, 0.12)
			SpellFx.chainNode(points[i + 1], palette)
			if math.random() < 0.5 then
				Lib.burst(points[i + 1], "Spark", palette, 4)
			end
		end
		if math.random() < 0.3 then
			Lib.burst(points[1], "Star", palette, 3, { Speed = NumberRange.new(2, 5) })
		end
		if isMine(p.Caster) then
			CameraController.shake(0.04)
		end
		if math.random() < 0.35 then
			Audio.play("Chain", points[#points])
		end
	end,

	-- Raio Invocado: raio do ceu no ponto mirado.
	Strike = function(p)
		local palette = Lib.palette(p.School)
		local sky = p.Position + Vector3.new(math.random(-8, 8), 70, math.random(-8, 8))
		Lightning.bolt(sky, p.Position, palette, { Width = 0.6, Forks = 5, Flickers = 4, Duration = 0.35 })
		Lightning.braid(sky, p.Position, palette, 5, 0.2)
		Effects.flash(p.Position + Vector3.new(0, 1, 0), palette, 3.5, true)
		Effects.shockwave(Lib.groundBelow(p.Position + Vector3.new(0, 2, 0), nil), palette, p.Radius)
		Lib.burst(p.Position, "Spark", palette, 30)
		SpellFx.groundCrackle(p.Position, p.Radius, palette, 1)
		Audio.play("Strike", p.Position)
		shakeNear(p.Position, 0.7, 90)
	end,

	-- Nova Flamejante / Pulso Arcano: explosao em volta do conjurador.
	Nova = function(p)
		local palette = Lib.palette(p.School)
		local ground = Lib.groundBelow(p.Position, p.Caster)
		Effects.flash(p.Position, palette, 3, true)
		Effects.shockwave(ground + Vector3.new(0, 0.1, 0), palette, p.Radius)
		task.delay(0.08, Effects.shockwave, ground + Vector3.new(0, 0.6, 0), palette, p.Radius * 0.7)
		if p.School == "Fire" then
			SpellFx.flamePillars(ground, p.Radius, palette)
			Lib.burst(
				p.Position,
				"Flame",
				palette,
				24,
				{ Speed = NumberRange.new(10, 22), Size = Lib.seq(2.6, 1.4, 0) }
			)
			Lib.burst(p.Position, "Ember", palette, 30, { Speed = NumberRange.new(10, 24) })
		else
			Lib.burst(p.Position, "Star", palette, 30, { Speed = NumberRange.new(12, 26) })
			Lib.burst(p.Position, "Wisp", palette, 20, { Speed = NumberRange.new(6, 12) })
			SpellFx.arcaneDome(p.Position, ground, p.Radius, palette, p.Popped)
		end
		Audio.play(if p.School == "Fire" then "Nova" else "Impact_Energy", p.Position)
		shakeNear(p.Position, 0.5, 60)
		if isMine(p.Caster) then
			CameraController.kick(4)
		end
	end,

	-- Espinhos Carmesins: fileira de espinhos rompendo o chao.
	SpellLine = function(p)
		local palette = Lib.palette(p.School)
		if p.School == "Blood" then
			SpellFx.bloodSpikes(p.From, p.To, p.Width, palette)
		else
			Effects.crystalSpikes(p.From, p.To, p.Width, palette)
		end
		Audio.play("SpellLine", p.From)
		shakeNear((p.From + p.To) / 2, 0.35, 50)
	end,

	-- Lanca de Magma: poca de lava onde a lanca cai.
	LavaPool = function(p)
		SpellFx.lavaPool(p.Position, p.Radius, p.Duration, p.Seed or 1)
		Audio.play("LavaSear", p.Position)
		Audio.play("LavaRumble", p.Position)
	end,

	-- Raio Invocado: nuvem e circulo antes de cair.
	StrikeWarn = function(p)
		SpellFx.stormWarn(p.Position, p.Radius, p.Duration, Lib.palette(p.School))
		Audio.play("StrikeWarn", p.Position + Vector3.new(0, 10, 0))
	end,

	-- Almas Errantes: a alma volta ao conjurador trazendo a cura.
	SoulReturn = function(p)
		if p.Caster and p.Caster.Parent then
			LifeStream.play(p.From, p.Caster, Lib.palette(p.School))
		end
	end,

	-- Grimorio completo -------------------------------------------------------------------------
	Zone = function(p)
		ZoneFx.open(p)
		local sounds = {
			Static = "StaticField",
			Wall = "FlameWall",
			Vortex = "Vortex",
			Singularity = "Singularity",
			Rain = "BloodRain",
			Hourglass = "Hourglass",
		}
		Audio.play(sounds[p.Mode] or "Blink", p.Position)
		if p.Mode == "Wall" then
			shakeNear(p.Position, 0.3, 50)
		end
	end,
	ZoneEnd = function(p)
		ZoneFx.close(p)
		if p.Mode == "Singularity" then
			Audio.play("Explosion", p.Position)
			shakeNear(p.Position, 0.8, 100)
		end
	end,
	BarrageStart = function(p)
		StrikeFx.barrageStart(p)
	end,
	BarrageHit = function(p)
		StrikeFx.barrageHit(p)
		Audio.play(if p.Mode == "Storm" then "StormBolt" else "StarFall", p.Position)
		shakeNear(p.Position, 0.35, 70)
	end,
	MeteorWarn = function(p)
		StrikeFx.meteorWarn(p)
		Audio.play("MeteorFall", p.Position + Vector3.new(0, 20, 0))
	end,
	MeteorImpact = function(p)
		StrikeFx.meteorImpact(p, SpellFx.fireGround)
		Audio.play("MeteorImpact", p.Position)
		shakeNear(p.Position, 1.2, 160)
	end,
	VerdictWarn = function(p)
		StrikeFx.verdictWarn(p)
		SignatureFx.verdictCore(p.Position, p.Radius, p.Duration, Lib.palette(p.School))
		Audio.play("VerdictWarn", p.Position)
	end,
	Verdict = function(p)
		StrikeFx.verdict(p)
		Audio.play("Verdict", p.Position)
		shakeNear(p.Position, 1, 140)
	end,
	CrownStart = function(p)
		if p.Caster and p.Caster.Parent then
			ZoneFx.crown(p.Caster, p.Duration, Lib.palette(p.School))
			Audio.play("Crown", Lib.rootPosition(p.Caster))
		end
	end,
	CrownBolt = function(p)
		local from = if p.Caster then ZoneFx.crownTop(p.Caster) else nil
		if from then
			StrikeFx.crownBolt(from, p.To, Lib.palette(p.School))
			Audio.play("StormBolt", p.To, 0.6)
		end
	end,
	Ritual = function(p)
		if p.Caster then
			StrikeFx.ritual(p.Caster, p.Position, p.Radius, Lib.palette(p.School))
			Audio.play("Ritual", p.Position)
			task.delay(0.35, shakeNear, p.Position, 0.6, 70)
		end
	end,
	Pact = function(p)
		if p.Caster then
			StrikeFx.pact(p.Caster, p.Allies or {}, Lib.palette(p.School))
			Audio.play("Pact", Lib.rootPosition(p.Caster))
		end
	end,
	LightningStep = function(p)
		StrikeFx.lightningStep(p.From, p.To, Lib.palette(p.School))
		Audio.play("LightningStep", p.To)
		if isMine(p.Caster) then
			CameraController.kick(5)
		end
	end,
	Portal = function(p)
		ZoneFx.portal(p)
		Audio.play("Portal", p.A)
		Audio.play("Portal", p.B)
	end,
	PortalUse = function(p)
		local palette = Lib.palette("Energy")
		Effects.flash(p.From + Vector3.new(0, 3, 0), palette, 2, false)
		Effects.flash(p.To, palette, 2, true)
		Lib.burst(p.To, "Star", palette, 16)
		Audio.play("Portal", p.To)
		if isMine(p.Model) then
			CameraController.kick(6)
		end
	end,
	PortalClose = function(p)
		ZoneFx.closePortal(p.Id)
	end,
	Prison = function(p)
		StrikeFx.prison(p.Position, p.Size, p.Duration, Lib.palette(p.School))
		Audio.play("Prison", p.Position)
	end,
	Hook = function(p)
		if p.Caster then
			StrikeFx.hook(p.Caster, p.Target, p.To, Lib.palette(p.School), p.Travel)
			Audio.play("Hook", p.To)
		end
	end,
	BloodChain = function(p)
		if p.Caster and p.Target then
			ZoneFx.chain(p.Caster, p.Target, p.Duration, Lib.palette(p.School))
			Audio.play("Hook", Lib.rootPosition(p.Target))
		end
	end,
	DeathTouch = function(p)
		if p.Caster and p.Target then
			StrikeFx.deathTouch(p.Caster, p.Target, Lib.palette(p.School))
			Audio.play("DeathTouch", Lib.rootPosition(p.Target))
		end
	end,
	Curse = function(p)
		StrikeFx.curse(p)
		Audio.play("Curse", p.Position)
	end,
	Hemorrhage = function(p)
		local position = (p.Target and Lib.rootPosition(p.Target)) or p.Position
		StrikeFx.hemorrhage(position, p.Radius, Lib.palette(p.School))
		Audio.play("Hemorrhage", position)
	end,
	ControlMiss = function(p)
		StrikeFx.miss(p.Position, Lib.palette(p.School))
	end,
	ArcaneBeam = function(p)
		if p.Caster and p.Caster.Parent then
			local mine = isMine(p.Caster)
			StrikeFx.arcaneBeam(
				p.Caster,
				p.To,
				Lib.palette(p.School),
				p.Hit == true,
				p.Range,
				if mine then localAim else nil
			)
			if math.random() < 0.3 then
				Audio.play("ArcaneBeam", p.To)
			end
			if mine then
				CameraController.shake(if p.Hit then 0.05 else 0.025)
			end
		end
	end,
	-- Piromania: lanca-chamas continuo (o proprio jogador segue a mira local).
	Flamethrower = function(p)
		local mine = isMine(p.Caster)
		FlameFx.update(p, if mine then localAim else nil)
		if mine then
			CameraController.shake(if p.Hits and #p.Hits > 0 then 0.06 else 0.035)
		end
	end,
	LanceCharge = function(p)
		if p.Caster then
			local gem = Lib.muzzleOf(p.Caster, Lib.rootPosition(p.Caster) or Vector3.zero)
			StrikeFx.lanceCharge(gem, p.Duration, Lib.palette(p.School))
			Audio.play("LanceCharge", gem)
		end
	end,
	FirmamentLance = function(p)
		StrikeFx.firmamentLance(p.From, p.To, Lib.palette(p.School))
		Audio.play("LanceFire", p.From)
		shakeNear(p.From, 0.8, 120)
		if isMine(p.Caster) then
			CameraController.kick(6)
		end
	end,
	BloodSlash = function(p)
		if p.Caster then
			StrikeFx.bloodSlash(p.Caster, p.Direction, p.Reach, Lib.palette(p.School))
			Audio.play("BloodSlash", Lib.rootPosition(p.Caster))
		end
	end,
	Summon = function(p)
		StrikeFx.summon(p.Position, p.Big, Lib.palette(p.School))
		Audio.play("Summon", p.Position)
	end,
	Army = function(p)
		StrikeFx.army(p.Position, Lib.palette(p.School))
		Audio.play("Army", p.Position)
		shakeNear(p.Position, 0.5, 80)
	end,
	MinionHit = function(p)
		Effects.flash(p.Position, Lib.palette(p.School), if p.Big then 1.4 else 0.8, false)
		Audio.play("MinionHit", p.Position)
	end,
	OrbShock = function(p)
		StrikeFx.orbShock(p.From, p.Points, Lib.palette(p.School))
		Audio.play("OrbShock", p.From)
	end,
	ProjectileFreeze = function(p)
		Projectiles.freeze(p.Id, p.Duration)
	end,
	Rose = function(p)
		StrikeFx.rose(p.Position, Lib.palette(p.School))
		Audio.play("Rose", p.Position)
	end,

	-- Criatura zombando (gargalhada do Ossomante).
	Taunt = function(p)
		local root = p.Model and Lib.rootPosition(p.Model)
		if root then
			Audio.play("Taunt", root)
		end
	end,

	-- Assinaturas das magias (mecanicas proprias) ---------------------------------------------
	StrikeAftershock = function(p)
		SignatureFx.aftershock(p.Position, p.Radius, Lib.palette(p.School))
		shakeNear(p.Position, 0.3, 50)
	end,
	StaticPulse = function(p)
		if p.Caster and p.Caster.Parent then
			SignatureFx.staticPulse(p.Caster, p.Radius, Lib.palette(p.School))
		end
	end,
	Remnant = function(p)
		SignatureFx.remnant(p.Position, p.Delay, Lib.palette(p.School))
	end,
	RemnantBurst = function(p)
		SignatureFx.remnantBurst(p.Position, p.Radius, Lib.palette(p.School))
		shakeNear(p.Position, 0.3, 45)
	end,
	Combustion = function(p)
		SignatureFx.combustion(p.Positions, Lib.palette(p.School))
	end,
	WallBurn = function(p)
		SignatureFx.wallBurn(p.Positions, Lib.palette(p.School))
	end,
	MeteorRoll = function(p)
		SignatureFx.meteorRoll(p.From, p.To, p.Duration, p.Radius, Lib.palette(p.School))
	end,
	ShieldHit = function(p)
		if p.Target and p.Target.Parent then
			SignatureFx.shieldHit(p.Target, p.Amount or 1)
		end
	end,
	Execute = function(p)
		if p.Target and p.Target.Parent then
			SignatureFx.execute(p.Target, Lib.palette(p.School))
			if isMine(p.Caster) then
				Impact.screenFlash(Lib.palette(p.School).Halo, 0.8)
				CameraController.shake(0.5)
			end
		end
	end,
	CurseSpread = function(p)
		SignatureFx.curseSpread(p.From, p.Points, Lib.palette(p.School))
	end,
	BruteSlam = function(p)
		SignatureFx.bruteSlam(p.Position, p.Radius, Lib.palette(p.School))
		shakeNear(p.Position, 0.5, 60)
	end,
	SweetSpot = function(p)
		SignatureFx.sweetSpot(p.Positions, Lib.palette(p.School))
	end,

	ChannelEnd = function(p)
		if p.Caster then
			StrikeFx.arcaneBeamEnd(p.Caster)
			FlameFx.stop(p.Caster)
		end
	end,

	Damage = function(p)
		local target = p.Target
		if not target or not target.Parent then
			return
		end
		Numbers.damage(target, p.Amount, Lib.palette(p.School), p.Periodic == true)
		if not p.Periodic then
			hitFlash(target)
			Creatures.flinch(target, sourcePosition(p.Source), math.clamp(p.Amount / 4, 0.4, 1.2))
		end
		if isMine(p.Source) and not p.Periodic then
			HudController.hitmarker(p.Killed == true)
			Impact.hit(target, p.Amount, true, p.Killed == true)
			if p.Amount >= 8 or p.Killed then
				Impact.screenFlash(Lib.palette(p.School).Halo, if p.Killed then 0.45 else 0.3)
			end
		end
		if isMine(target) then
			CameraController.shake(math.clamp(p.Amount / 8, 0.15, 0.6))
			HudController.hurt(p.Amount)
			if not p.Periodic then
				Audio.play("Hurt", nil)
			end
		end
	end,

	-- Reacao entre escolas (Math/ComboMath): visual, texto e som proprios.
	Reaction = function(p)
		Impact.reaction(p, isMine(p.Source))
		if isMine(p.Source) then
			CameraController.shake(0.35)
		end
	end,

	Heal = function(p)
		if p.Target and p.Target.Parent then
			Numbers.heal(p.Target, p.Amount)
			local root = Lib.rootPosition(p.Target)
			if root then
				Lib.burst(root, "Wisp", Lib.palette("Necromancy"), 8)
			end
		end
	end,

	-- Ataques de inimigos ------------------------------------------------------------------
	EnemyTelegraph = function(p)
		local palette = Lib.palette(p.School)
		if p.Kind == "Slam" then
			trackTelegraph(p.Model, Effects.dangerZone(p.Position, p.Radius, p.Duration, DANGER), p.Duration)
			Audio.play("SlamWindup", p.Position)
		elseif p.Kind == "Explode" then
			if p.Model and p.Model.Parent then
				pulseWarning(p.Model, p.Duration, palette.Halo)
			end
			local root = (p.Model and Lib.rootPosition(p.Model)) or p.Position
			local ground = Lib.groundBelow(root, p.Model)
			trackTelegraph(p.Model, Effects.dangerZone(ground, p.Radius, p.Duration, DANGER), p.Duration)
			Audio.play("Fuse", root)
		elseif p.Kind == "Line" then
			trackTelegraph(p.Model, Effects.dangerLine(p.From, p.To, p.Width, p.Duration, DANGER), p.Duration)
			Audio.play("SlamWindup", p.From)
		elseif p.Kind == "Pounce" then
			-- O agachamento vem do atributo Windup (Vfx/Creatures); aqui so poeira e brilho.
			local root = p.Model and Lib.rootPosition(p.Model)
			if root then
				Lib.burst(root, "Smoke", palette, 4, { Speed = NumberRange.new(2, 4) })
				Lib.burst(root, "Star", palette, 6, { Speed = NumberRange.new(-5, -2) })
			end
		elseif p.Kind == "Charge" then
			-- A pose de conjuracao vem do evento Cast; aqui so um brilho crescente na gema.
			local gem = Lib.muzzleOf(p.Model, Lib.rootPosition(p.Model) or Vector3.zero)
			Lib.burst(
				gem,
				"Star",
				palette,
				8,
				{ Speed = NumberRange.new(-6, -3), Lifetime = NumberRange.new(0.2, 0.3) }
			)
			Audio.play("EnemyCharge", gem)
		end
	end,

	-- Golpe interrompido (equilibrio quebrado): aviso some, faiscas e texto dourado.
	Interrupt = function(p)
		local model = p.Model
		if not model or not model.Parent then
			return
		end
		cancelTelegraphs(model)
		local root = Lib.rootPosition(model)
		if root then
			Effects.flash(root, { Core = Color3.new(1, 1, 1), Halo = GOLD, Accent = GOLD, Shape = "" }, 1.4, true)
		end
		Numbers.label(model, "INTERROMPIDO!", GOLD)
		Audio.play("Interrupt", root)
	end,

	Stagger = function(p)
		local model = p.Model
		if not model or not model.Parent then
			return
		end
		local palette = Lib.palette(model:GetAttribute("School"))
		Effects.stunStars(model, palette, p.Duration or 0.8)
		Creatures.flinch(model, nil, 1.4)
		local root = Lib.rootPosition(model)
		if root then
			Lib.burst(root, "Star", palette, 10)
			shakeNear(root, 0.25, 40)
		end
		Audio.play("Stagger", root)
	end,

	Pounce = function(p)
		local palette = Lib.palette(p.School)
		Lib.burst(p.Position, "Smoke", palette, 6, { Speed = NumberRange.new(3, 7) })
		Lib.burst(p.Position + Vector3.new(0, 0.5, 0), "Star", palette, 6)
		Audio.play("Pounce", p.Position)
	end,

	Spikes = function(p)
		local palette = Lib.palette(p.School)
		Effects.crystalSpikes(p.From, p.To, p.Width, palette)
		shakeNear((p.From + p.To) / 2, 0.5, 60)
		Audio.play("Spikes", p.From)
	end,

	-- Chefe enfurecido: rugido com duas ondas e tremor forte.
	Roar = function(p)
		local model = p.Model
		local root = model and Lib.rootPosition(model)
		if not root then
			return
		end
		local palette = Lib.palette(p.School)
		local ground = Lib.groundBelow(root, model)
		Effects.flash(root + Vector3.new(0, 3, 0), palette, 4, true)
		Effects.shockwave(ground, palette, 18)
		task.delay(0.35, Effects.shockwave, ground, palette, 26)
		Lib.burst(root, "Wisp", palette, 40, { Speed = NumberRange.new(6, 14) })
		shakeNear(root, 1, 120)
		Audio.play("Roar", root)
		local highlight = Instance.new("Highlight")
		highlight.FillColor = palette.Halo
		highlight.FillTransparency = 0.8
		highlight.OutlineColor = palette.Core
		highlight.Parent = model
		Numbers.label(model, "FÚRIA!", palette.Halo)
	end,

	Dodge = function(p)
		if p.Model and p.Model.Parent and not isMine(p.Model) then
			dodgeEffect(p.Model, p.Direction)
		end
	end,

	PerfectDodge = function(p)
		local model = p.Model
		if not model or not model.Parent then
			return
		end
		local root = Lib.rootPosition(model)
		if root then
			Effects.flash(root, { Core = Color3.new(1, 1, 1), Halo = DODGE, Accent = DODGE, Shape = "" }, 1.6, true)
		end
		if isMine(model) then
			HudController.notice("ESQUIVA PERFEITA!  +mana", DODGE)
			CameraController.kick(-3)
			Audio.play("PerfectDodge", nil)
		end
	end,

	Slam = function(p)
		local palette = Lib.palette(p.School)
		Effects.shockwave(p.Position, palette, p.Radius)
		Effects.flash(p.Position + Vector3.new(0, 1, 0), palette, 2.4, true)
		Lib.burst(p.Position, "Smoke", palette, 14, { Speed = NumberRange.new(6, 14) })
		Lib.burst(p.Position + Vector3.new(0, 1, 0), "Star", palette, 20, { Speed = NumberRange.new(10, 22) })
		shakeNear(p.Position, 0.7, 70)
		Audio.play("Slam", p.Position)
	end,

	Explosion = function(p)
		local palette = Lib.palette(p.School)
		Effects.flash(p.Position, palette, 3, true)
		Effects.shockwave(Lib.groundBelow(p.Position, nil), palette, p.Radius)
		for i = 1, 7 do
			local angle = (i / 7) * math.pi * 2
			local reach = p.Radius * (0.8 + math.random() * 0.6)
			local to = p.Position + Vector3.new(math.cos(angle) * reach, math.random() * 3 - 1, math.sin(angle) * reach)
			Lightning.bolt(p.Position, to, palette, { Width = 0.2, Forks = 1, Flickers = 2, Duration = 0.18 })
		end
		Lib.burst(p.Position, "Spark", palette, 30)
		Audio.play("Explosion", p.Position)
		shakeNear(p.Position, 0.8, 70)
	end,

	Blink = function(p)
		local palette = Lib.palette(p.School)
		Effects.flash(p.From, palette, 1.8, false)
		Effects.flash(p.To, palette, 1.8, true)
		Lib.burst(p.From, "Wisp", palette, 16, { Speed = NumberRange.new(3, 8) })
		Lib.burst(p.To, "Star", palette, 14)
		Audio.play("Blink", p.From)
	end,

	Impact = function(p)
		Effects.flash(p.Position, Lib.palette(p.School), p.Scale or 1, false)
		Audio.play("Impact_" .. tostring(p.School), p.Position, 0.7)
	end,

	Death = function(p)
		if p.Model then
			cancelTelegraphs(p.Model)
		end
		if p.Model and p.Model.Parent then
			dissolve(p.Model, Lib.palette(p.School), p.Boss == true)
			Audio.play("Death_" .. tostring(p.Model:GetAttribute("Creature")), Lib.rootPosition(p.Model))
		end
	end,
}

local function dispatch(kind: string, payload: any)
	local handler = HANDLERS[kind]
	if handler then
		handler(payload)
	end
end

-- A gema do proprio cajado mostra a escola da magia selecionada.
local function tintSelected()
	local spellId = player:GetAttribute("Slot" .. ClientState.SelectedSlot)
	local spell = if typeof(spellId) == "string" then Spells.get(spellId) else nil
	if spell then
		Staff.tintLocal(player.Character, Lib.palette(spell.Row.School))
	end
end

-- Subiu de nivel: circulo dourado e luz subindo em volta do mago.
local function levelUpEffect()
	local character = player.Character
	local root = character and Lib.rootPosition(character)
	if not root then
		return
	end
	local gold = {
		Core = Color3.fromRGB(255, 250, 220),
		Halo = Color3.fromRGB(255, 200, 80),
		Accent = Color3.fromRGB(255, 150, 40),
		Shape = "",
	}
	Effects.runeCircle(root - Vector3.new(0, 2.9, 0), gold, 5, 1.4)
	Effects.shockwave(root - Vector3.new(0, 2.9, 0), gold, 9)
	Lib.burst(root, "Wisp", gold, 40, { Speed = NumberRange.new(4, 10) })
	Audio.play("LevelUp", root)
	CameraController.kick(4)
end

-- Passo arcano: corpo agacha e inclina (Vfx/DodgeAnim), tres imagens residuais em sequencia,
-- linhas de velocidade, anel no chao e poeira.
local function dodgeEffect(character: Model, direction: Vector3?)
	local root = Lib.rootPosition(character)
	local dir = direction
	if not dir then
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		dir = if rootPart then rootPart.AssemblyLinearVelocity else Vector3.zero
	end
	DodgeAnim.play(character, dir :: Vector3)
	for i = 0, 2 do
		task.delay(i * 0.05, Effects.afterimage, character, DODGE, 0.15 + i * 0.2)
	end
	if root then
		local palette = { Core = Color3.new(1, 1, 1), Halo = DODGE, Accent = DODGE, Shape = "" }
		local ground = Lib.groundBelow(root, character)
		Effects.speedLines(root, dir :: Vector3, DODGE)
		Effects.shockwave(ground + Vector3.new(0, 0.1, 0), palette, 3.5)
		Lib.burst(ground, "Smoke", Lib.palette("Energy"), 6, { Speed = NumberRange.new(2, 6) })
		Lib.burst(root, "Wisp", palette, 8)
	end
	Audio.play("Dodge", root)
end

-- Esquiva do proprio jogador: desenhada na hora (sem esperar o servidor).
function VfxController.dodgeLocal(character: Model, direction: Vector3)
	dodgeEffect(character, direction)
	CameraController.kick(3)
end

function VfxController.start()
	Lib.folder()
	Creatures.start()
	DodgeAnim.start() -- antes do Staff: o IK do braco ja ve o corpo inclinado
	Projectiles.start()
	Numbers.start()
	Staff.start()
	Auras.start()

	Net.get("Vfx").OnClientEvent:Connect(dispatch)
	Net.get("VfxFast").OnClientEvent:Connect(dispatch)
	Net.get("CastFeedback").OnClientEvent:Connect(function(reason: string, slot: number)
		HudController.feedback(reason, slot)
		Audio.play("Fail", nil)
	end)

	ClientState.SelectedChanged:Connect(function()
		tintSelected()
		Audio.play("Select", nil)
	end)
	local function watchDeath(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				Audio.play("PlayerDeath", nil)
			end)
		end
	end
	if player.Character then
		task.spawn(watchDeath, player.Character)
	end
	player.CharacterAdded:Connect(watchDeath)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("ArcanumStaff", 10)
		task.wait(0.2)
		tintSelected()
	end)

	local lastLevel = player:GetAttribute("Level") or 1
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = player:GetAttribute("Level") or 1
		if level > lastLevel then
			levelUpEffect()
		end
		lastLevel = level
	end)
end

return VfxController
