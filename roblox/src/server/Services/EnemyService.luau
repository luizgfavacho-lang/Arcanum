--!strict
-- Gera criaturas nos pontos ArcanumWorld/EnemySpawns, com stats de Data/Enemies.csv, e roda a IA
-- de cada uma (Combat/EnemyBrain + Combat/EnemyCatalog).
-- 10% dos mobs magicos viram elite (vida x2, dano x1,5 via +50 de Poder Magico, XP x2).
-- Renascem apos EnemyRespawnSeconds; filhotes (ex.: gosmas divididas) nao renascem.

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
local EnemyBrain = require(script.Parent.Parent.Combat.EnemyBrain)
local EnemyCatalog = require(script.Parent.Parent.Combat.EnemyCatalog)

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

-- Animacoes padrao do R15 (catalogo do Roblox).
local IDLE_ANIMATION = "rbxassetid://507766666"
local WALK_ANIMATION = "rbxassetid://507777826"
local AI_TICK = 0.1

local EnemyService = {}

local enemiesFolder: Folder
local vfx = Net.get("Vfx")
local brains: { [Model]: EnemyBrain.Brain } = {}

local function buildModel(rowName: string, row: any, elite: boolean): Model
	local palette = Schools[row.School]
	local description = Instance.new("HumanoidDescription")
	local body = if palette then palette.Halo:Lerp(Color3.new(0.2, 0.2, 0.25), 0.55) else Color3.fromRGB(90, 90, 100)
	description.HeadColor = body
	description.TorsoColor = body
	description.LeftArmColor = body
	description.RightArmColor = body
	description.LeftLegColor = body
	description.RightLegColor = body

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = rowName
	if row.bBoss then
		model:ScaleTo(2.2)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = DISPLAY_NAMES[rowName] or rowName
	-- A barra de vida e o nome sao desenhados pelo cliente (client/Controllers/EnemyBars).
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- Morre inteiro (o cliente o desfaz em luz) em vez de desmontar.
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("DisplayName", humanoid.DisplayName)
	model:SetAttribute("School", row.School)
	model:SetAttribute("Boss", row.bBoss)

	if elite then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(255, 200, 60)
		highlight.Parent = model
	end
	return model
end

local function loadAnimation(animator: Animator, id: string): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	return if ok then track else nil
end

-- Idle sempre; caminhada misturada pela velocidade (nao desliza parado no lugar).
local function setupAnimations(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local idle = loadAnimation(animator :: Animator, IDLE_ANIMATION)
	local walk = loadAnimation(animator :: Animator, WALK_ANIMATION)
	if idle then
		idle.Looped = true
		idle:Play(0.2, 1, 0.8 + math.random() * 0.4)
	end
	if walk then
		walk.Looped = true
		humanoid.Running:Connect(function(speed: number)
			if speed > 0.5 then
				if not walk.IsPlaying then
					walk:Play(0.15)
				end
				walk:AdjustSpeed(math.clamp(speed / 14, 0.5, 1.6))
			elseif walk.IsPlaying then
				walk:Stop(0.2)
			end
		end)
	end
end

local spawnEnemy: (rowName: string, cframe: CFrame, respawnPart: BasePart?) -> ()

spawnEnemy = function(rowName: string, cframe: CFrame, respawnPart: BasePart?)
	local row = Enemies[rowName]
	if not row then
		warn("[Enemy] linha inexistente em Enemies.csv: " .. tostring(rowName))
		return
	end

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
	-- Criaturas magicas humanoides carregam cajado (bosses tem armas proprias no R3).
	if row.bMagical and not row.bBoss then
		task.spawn(StaffService.equip, model, row.School)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	setupAnimations(humanoid)

	-- Orientacao suave (AlignOrientation); a IA define para onde olhar.
	local align: AlignOrientation? = nil
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "LookAttachment"
		attachment.Parent = root
		local a = Instance.new("AlignOrientation")
		a.Mode = Enum.OrientationAlignmentMode.OneAttachment
		a.Attachment0 = attachment
		a.Responsiveness = 10
		a.MaxTorque = math.huge
		a.CFrame = root.CFrame
		a.Parent = root
		humanoid.AutoRotate = false
		align = a
	end

	local behavior = EnemyCatalog.get(rowName)
	local brain = EnemyBrain.new(model, row, behavior, align, cframe.Position)
	if brain then
		brains[model] = brain
	end

	humanoid.Died:Connect(function()
		brains[model] = nil
		-- Solta a orientacao para o corpo tombar enquanto se desfaz.
		if align then
			align:Destroy()
		end
		local position = if root then root.Position else cframe.Position
		vfx:FireAllClients("Death", { Model = model, School = row.School, Boss = row.bBoss })

		local killer = DamageService.getLastAttacker(model)
		local player = if killer then Players:GetPlayerFromCharacter(killer) else nil
		if player then
			ProgressionService.addXP(player, row.XPReward * (if elite then 2 else 1))
		end

		-- Divisao (Gosma Arcana -> gosminhas), espalhadas em volta.
		if behavior.SplitInto then
			for i = 1, behavior.SplitCount or 2 do
				local angle = (i / (behavior.SplitCount or 2)) * math.pi * 2
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3
				task.delay(
					0.15,
					spawnEnemy,
					behavior.SplitInto,
					CFrame.new(position + offset + Vector3.new(0, 1, 0)),
					nil
				)
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
end

function EnemyService.start()
	local world = WorldService.getWorld()
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = world

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
end

return EnemyService
