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
local RigAnimator = require(Combat.RigAnimator)
local CollisionGroups = require(Combat.CollisionGroups)

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
	CollisionGroups.assign(model, CollisionGroups.MONSTERS) -- a Muralha de Chamas bloqueia criaturas
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
		else RigAnimator.setup(humanoid, if row.bBoss then 0.75 else 1)

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
		-- Abate de servo conta para o dono (atributo OwnerUserId).
		local ownerId = if killer then killer:GetAttribute("OwnerUserId") else nil
		local player = if killer
			then Players:GetPlayerFromCharacter(killer) or (if typeof(ownerId) == "number"
				then Players:GetPlayerByUserId(ownerId)
				else nil)
			else nil
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
