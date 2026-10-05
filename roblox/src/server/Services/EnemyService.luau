--!strict
-- Gera criaturas nos pontos ArcanumWorld/EnemySpawns, com stats de Data/Enemies.csv.
-- 10% dos mobs magicos viram elite (vida x2, dano x1,5 via +50 de Poder Magico, XP x2).
-- Sem IA ainda (T-05): ficam parados. Renascem apos EnemyRespawnSeconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.CombatSettings)
local Enemies = require(Shared.Data.Enemies) :: any
local Schools = require(Shared.Schools)
local Units = require(Shared.Units)

local StatsService = require(script.Parent.StatsService)
local DamageService = require(script.Parent.DamageService)
local Net = require(Shared.Net)
local ProgressionService = require(script.Parent.ProgressionService)
local WorldService = require(script.Parent.WorldService)
local StaffService = require(script.Parent.StaffService)

-- Nomes exibidos (originais; ver Docs/01-GDD.md §5). TODO: mover para String Table.
local DISPLAY_NAMES: { [string]: string } = {
	UndeadMage = "Necrótico Sussurrante",
	SkeletonMage = "Ossomante",
	StormBloater = "Bulbo Tempestuoso",
	BloodWitchSpider = "Tecedeira Rubra",
	ArcaneSlime = "Gosma Arcana",
	ManaWraith = "Espectro de Mana",
	VoidStrider = "Andarilho do Vazio",
	CrystalGolem = "Golem de Cristal",
}

local EnemyService = {}

local enemiesFolder: Folder
local vfx = Net.get("Vfx")

-- Animacao idle padrao do R15 (catalogo do Roblox).
local IDLE_ANIMATION = "rbxassetid://507766666"
local LOOK_RANGE = 70 -- studs: inimigos viram o rosto para o jogador mais proximo
local living: { [Model]: AlignOrientation } = {}

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

local function spawnEnemy(spawnPart: BasePart)
	local rowName = spawnPart:GetAttribute("EnemyRow")
	local row = if typeof(rowName) == "string" then Enemies[rowName] else nil
	if not row then
		warn("[Enemy] linha inexistente em Enemies.csv: " .. tostring(rowName))
		return
	end

	local elite = row.bMagical and not row.bBoss and math.random() < Settings.EliteChance
	local model = buildModel(rowName, row, elite)
	model:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
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
	-- Criaturas magicas humanoides tambem carregam cajado (bosses tem armas proprias no R3).
	if row.bMagical and not row.bBoss then
		task.spawn(StaffService.equip, model, row.School)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE_ANIMATION
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(idle)
	end)
	if ok and track then
		track.Looped = true
		track:Play(0.2, 1, 0.8 + math.random() * 0.4) -- velocidades diferentes: nao ficam sincronizados
	end

	-- Vira o rosto suavemente (AlignOrientation; o alvo e atualizado em start()).
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "LookAttachment"
		attachment.Parent = root
		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.Responsiveness = 8
		align.MaxTorque = math.huge
		align.CFrame = root.CFrame
		align.Parent = root
		humanoid.AutoRotate = false
		living[model] = align
	end

	humanoid.Died:Connect(function()
		-- Solta a orientacao para o corpo tombar enquanto se desfaz.
		local align = living[model]
		if align then
			align:Destroy()
		end
		living[model] = nil
		vfx:FireAllClients("Death", { Model = model, School = row.School, Boss = row.bBoss })
		local killer = DamageService.getLastAttacker(model)
		local player = if killer then Players:GetPlayerFromCharacter(killer) else nil
		if player then
			ProgressionService.addXP(player, row.XPReward * (if elite then 2 else 1))
		end
		task.delay(1.6, function()
			model:Destroy()
		end)
		task.delay(Settings.EnemyRespawnSeconds, spawnEnemy, spawnPart)
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
		if spawnPart:IsA("BasePart") then
			task.spawn(spawnEnemy, spawnPart)
		end
	end

	-- Inimigos olham para o jogador vivo mais proximo (ate a IA de verdade, RT-02).
	while true do
		task.wait(0.15)
		for model, align in living do
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or not model.Parent then
				living[model] = nil
				continue
			end
			local best: Vector3? = nil
			local bestDist = LOOK_RANGE
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local other = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if other and humanoid and humanoid.Health > 0 then
					local dist = (other.Position - root.Position).Magnitude
					if dist < bestDist then
						best, bestDist = other.Position, dist
					end
				end
			end
			if best then
				local flat = Vector3.new(best.X, root.Position.Y, best.Z)
				if (flat - root.Position).Magnitude > 0.5 then
					align.CFrame = CFrame.lookAt(root.Position, flat)
				end
			end
		end
	end
end

return EnemyService
