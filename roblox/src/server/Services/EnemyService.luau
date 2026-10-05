--!strict
-- Gera criaturas nos pontos ArcanumWorld/EnemySpawns, com stats de Data/Enemies.csv, corpo de
-- Combat/CreatureBuilder e IA de Combat/EnemyBrain + Combat/EnemyCatalog.
-- 10% dos mobs magicos viram elite (vida x2, dano x1,5 via +50 de Poder Magico, XP x2, reagem
-- mais rapido). Renascem apos EnemyRespawnSeconds; filhotes (ex.: gosmas divididas) nao renascem.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local Enemies = require(Shared.Data.Enemies) :: any
local Net = require(Shared.Net)
local Schools = require(Shared.Schools)
local Units = require(Shared.Units)

local StatsService = require(script.Parent.StatsService)
local DamageService = require(script.Parent.DamageService)
local ProgressionService = require(script.Parent.ProgressionService)
local WorldService = require(script.Parent.WorldService)
local StaffService = require(script.Parent.StaffService)
local Combat = script.Parent.Parent.Combat
local EnemyBrain = require(Combat.EnemyBrain)
local EnemyCatalog = require(Combat.EnemyCatalog)
local CreatureBuilder = require(Combat.CreatureBuilder)
local Targeting = require(Combat.Targeting)

-- Nomes exibidos (originais; ver Docs/01-GDD.md §5). TODO: mover para String Table.
local DISPLAY_NAMES: { [string]: string } = {
	UndeadMage = "Necrótico Sussurrante",
	SkeletonMage = "Ossomante",
	StormBloater = "Bulbo Tempestuoso",
	BloodWitchSpider = "Tecedeira Rubra",
	ArcaneSlime = "Gosma Arcana",
	ArcaneSlimeSmall = "Gosminha",
	ManaWraith = "Espectro de Mana",
	VoidStrider = "Andarilho do Vazio",
	CrystalGolem = "Golem de Cristal",
}

-- Animacoes padrao do R15 (catalogo do Roblox, liberadas para qualquer jogo).
local ANIMATIONS: { [string]: string } = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Point = "rbxassetid://507770453", -- avistou o alvo
	Cheer = "rbxassetid://507770677", -- bracos para cima (preparo de pancada / rugido)
	Laugh = "rbxassetid://507770818", -- zomba ao acertar ou vencer
}
local RUN_ABOVE = 11 -- studs/s: acima disso corre em vez de andar
local AI_TICK = 0.1

local EnemyService = {}

local enemiesFolder: Folder
local vfx = Net.get("Vfx")

local function buildModel(rowName: string, row: any, elite: boolean): Model
	local palette = Schools[row.School] or Schools.Energy
	local model = CreatureBuilder.buildBlob(rowName, palette)
	if not model then
		local description = Instance.new("HumanoidDescription")
		CreatureBuilder.describe(rowName, description, palette)
		local rig = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		if row.bBoss then
			rig:ScaleTo(2.2)
		end
		CreatureBuilder.dress(rig, rowName, palette)
		model = rig
	end
	local m = model :: Model
	m.Name = rowName

	local humanoid = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = DISPLAY_NAMES[rowName] or rowName
	-- A barra de vida e o nome sao desenhados pelo cliente (client/Controllers/EnemyBars).
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- Morre inteiro (o cliente o desfaz em luz) em vez de desmontar.
	humanoid.BreakJointsOnDeath = false
	m:SetAttribute("DisplayName", humanoid.DisplayName)
	m:SetAttribute("School", row.School)
	m:SetAttribute("Boss", row.bBoss)

	if elite then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(255, 200, 60)
		highlight.Parent = m
	end
	return m
end

local function loadAnimation(animator: Animator, id: string): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	return if ok then track else nil
end

-- Idle sempre; andar/correr misturados pela velocidade (nao desliza parado no lugar).
-- Cada criatura toca num ritmo um pouco diferente (ninguem respira em sincronia).
local function setupAnimations(humanoid: Humanoid, tempo: number): { [string]: AnimationTrack }
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ANIMATIONS do
		local track = loadAnimation(animator :: Animator, id)
		if track then
			tracks[name] = track
		end
	end
	local idle, walk, run = tracks.Idle, tracks.Walk, tracks.Run
	if idle then
		idle.Looped = true
		idle.Priority = Enum.AnimationPriority.Idle
		idle:Play(0.2, 1, tempo * (0.85 + math.random() * 0.3))
	end
	for _, name in { "Point", "Cheer", "Laugh" } do
		local track = tracks[name]
		if track then
			track.Looped = false
			track.Priority = Enum.AnimationPriority.Action
		end
	end
	if walk then
		walk.Looped = true
		walk.Priority = Enum.AnimationPriority.Movement
	end
	if run then
		run.Looped = true
		run.Priority = Enum.AnimationPriority.Movement
	end
	humanoid.Running:Connect(function(speed: number)
		local running = speed > RUN_ABOVE and run ~= nil
		local active = if running then run else walk
		local other = if running then walk else run
		if other and other.IsPlaying then
			other:Stop(0.25)
		end
		if not active then
			return
		end
		if speed > 0.5 then
			if not active.IsPlaying then
				active:Play(0.2)
			end
			local reference = if running then 20 else 12
			active:AdjustSpeed(math.clamp(speed / reference, 0.5, 1.6) * tempo)
		elseif active.IsPlaying then
			active:Stop(0.25)
		end
	end)
	return tracks
end

-- Bulbo morto antes de explodir: estoura de qualquer jeito e fere TODOS em volta (jogadores e
-- outras criaturas). Matar o bulbo perto do bando e uma tatica.
local function deathBurst(
	model: Model,
	row: any,
	burst: { DamageScale: number, Delay: number, RadiusMeters: number },
	killer: Model?,
	position: Vector3
)
	local radius = Units.meters(burst.RadiusMeters)
	vfx:FireAllClients("EnemyTelegraph", {
		Kind = "Explode",
		Model = model,
		Position = position,
		Radius = radius,
		Duration = burst.Delay,
		School = row.School,
	})
	task.delay(burst.Delay, function()
		local damage = row.AttackDamage * burst.DamageScale
		vfx:FireAllClients("Explosion", { Position = position, Radius = radius, School = row.School })
		for other, stats in StatsService.all() do
			if
				other ~= model
				and stats.Humanoid.Health > 0
				and (Targeting.position(other) - position).Magnitude <= radius
			then
				-- Criaturas atingidas contam como golpe do jogador (XP do abate vai para ele).
				local source = if stats.Team == "Monsters" then killer else model
				DamageService.applySpellDamage(source, other, damage, row.School)
			end
		end
	end)
end

local spawnEnemy: (rowName: string, cframe: CFrame, respawnPart: BasePart?) -> Model?

spawnEnemy = function(rowName: string, cframe: CFrame, respawnPart: BasePart?): Model?
	local row = Enemies[rowName]
	if not row then
		warn("[Enemy] linha inexistente em Enemies.csv: " .. tostring(rowName))
		return nil
	end
	local behavior = EnemyCatalog.get(rowName)
	local elite = row.bMagical and not row.bBoss and math.random() < Settings.EliteChance
	local model = buildModel(rowName, row, elite)
	model:PivotTo(cframe)
	model.Parent = enemiesFolder

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root:SetNetworkOwner(nil)
	end

	StatsService.register(model, {
		Team = "Monsters",
		MaxHealth = row.MaxHealth * (if elite then 2 else 1),
		Armor = row.Armor,
		SpellPower = if elite then 50 else 0,
		WalkSpeed = Units.meters(row.MoveSpeedMetersPerSecond),
	})
	model:SetAttribute("Elite", elite)
	if behavior.Staff then
		task.spawn(StaffService.equip, model, row.School)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local tracks = if CreatureBuilder.isBlob(rowName)
		then {}
		else setupAnimations(humanoid, if row.bBoss then 0.75 else 1)

	-- Orientacao suave (AlignOrientation); a IA define para onde olhar.
	local align: AlignOrientation? = nil
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "LookAttachment"
		attachment.Parent = root
		local a = Instance.new("AlignOrientation")
		a.Mode = Enum.OrientationAlignmentMode.OneAttachment
		a.Attachment0 = attachment
		a.Responsiveness = if row.bBoss then 6 else 12
		a.MaxTorque = math.huge
		a.CFrame = root.CFrame
		a.Parent = root
		humanoid.AutoRotate = false
		align = a
	end

	local brain = EnemyBrain.new(model, row, behavior, align, cframe.Position, elite)
	if brain then
		brain.Anims = tracks
	end

	humanoid.Died:Connect(function()
		local position = if root then root.Position else cframe.Position
		local selfDestructed = brain ~= nil and brain.SelfDestructed
		EnemyBrain.remove(model)
		model:SetAttribute("Windup", nil)
		model:SetAttribute("Awareness", nil)
		-- Solta a orientacao para o corpo tombar enquanto se desfaz.
		if align then
			align:Destroy()
		end
		vfx:FireAllClients("Death", { Model = model, School = row.School, Boss = row.bBoss })

		local killer = DamageService.getLastAttacker(model)
		local player = if killer then Players:GetPlayerFromCharacter(killer) else nil
		if player then
			ProgressionService.addXP(player, row.XPReward * (if elite then 2 else 1))
		end

		if behavior.DeathBurst and not selfDestructed then
			deathBurst(model, row, behavior.DeathBurst, killer, position)
		end

		-- Divisao (Gosma Arcana -> gosminhas), espalhadas em volta e ja de olho no matador.
		if behavior.SplitInto then
			local count = behavior.SplitCount or 2
			for i = 1, count do
				local angle = (i / count) * math.pi * 2 + math.random()
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3
				task.delay(0.15, function()
					local child = spawnEnemy(
						behavior.SplitInto :: string,
						CFrame.new(position + offset + Vector3.new(0, 1, 0)),
						nil
					)
					local childBrain = if child then EnemyBrain.get(child) else nil
					if childBrain and killer and StatsService.isAlive(killer) then
						EnemyBrain.provoke(childBrain, killer)
					end
				end)
			end
		end

		task.delay(1.6, function()
			model:Destroy()
		end)
		if respawnPart then
			task.delay(
				Settings.EnemyRespawnSeconds,
				spawnEnemy,
				rowName,
				respawnPart.CFrame + Vector3.new(0, 4, 0),
				respawnPart
			)
		end
	end)
	return model
end

function EnemyService.start()
	local world = WorldService.getWorld()
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = world

	-- Cada golpe recebido vai para a IA (aggro, atordoamento, empurrao); acertar o jogador
	-- pode render uma zombaria.
	DamageService.Damaged:Connect(function(source: Model?, target: Model, amount: number, periodic: boolean)
		local victim = EnemyBrain.get(target)
		if victim then
			EnemyBrain.hurt(victim, source, amount, periodic)
		end
		local attacker = if source then EnemyBrain.get(source) else nil
		if attacker and amount > 0 and not periodic then
			EnemyBrain.landed(attacker)
		end
	end)

	local spawns = world:FindFirstChild("EnemySpawns")
	if not spawns then
		warn("[Enemy] ArcanumWorld sem pasta EnemySpawns")
		return
	end
	for _, spawnPart in spawns:GetChildren() do
		local rowName = spawnPart:GetAttribute("EnemyRow")
		if spawnPart:IsA("BasePart") and typeof(rowName) == "string" then
			task.spawn(spawnEnemy, rowName, spawnPart.CFrame + Vector3.new(0, 4, 0), spawnPart)
		end
	end

	-- Laco da IA.
	while true do
		task.wait(AI_TICK)
		EnemyBrain.stepAll()
	end
end

return EnemyService
