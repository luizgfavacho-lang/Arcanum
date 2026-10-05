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
local ProgressionService = require(script.Parent.ProgressionService)
local WorldService = require(script.Parent.WorldService)

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
	humanoid.DisplayName = (DISPLAY_NAMES[rowName] or rowName) .. (if elite then " ★" else "")
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 80
	humanoid.HealthDisplayDistance = 80

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

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local killer = DamageService.getLastAttacker(model)
		local player = if killer then Players:GetPlayerFromCharacter(killer) else nil
		if player then
			ProgressionService.addXP(player, row.XPReward * (if elite then 2 else 1))
		end
		task.delay(2, function()
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
end

return EnemyService
