--!strict
-- Servos da Necromancia (Kind "Summon"): Erguer Esqueleto, Erguer Bruto e Exercito dos Mortos.
-- Stats dos servos em Data/Enemies.csv (SkeletonServant, BruteServant); duracao, quantidade
-- (Count) e limite de ativos (MaxTargets) na linha da magia. O Exercito invoca Count esqueletos e
-- MaxTargets brutos. Servos lutam pelo time do dono; abate deles da XP ao dono.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Enemies = require(Shared.Data.Enemies) :: any
local Net = require(Shared.Net)
local Schools = require(Shared.Schools)
local Units = require(Shared.Units)
local StatsService = require(script.Parent.Parent.Services.StatsService)
local Combat = script.Parent.Parent.Combat
local CreatureBuilder = require(Combat.CreatureBuilder)
local MinionBrain = require(Combat.MinionBrain)
local RigAnimator = require(Combat.RigAnimator)
local Targeting = require(Combat.Targeting)
local Context = require(script.Parent.Context)
local Area = require(script.Parent.Area)

local vfx = Net.get("Vfx")

local NAMES: { [string]: string } = { SkeletonServant = "Servo Esqueleto", BruteServant = "Bruto Morto-Vivo" }
local AI_TICK = 0.1

local Summon = {}

local folder: Folder? = nil
local slotCounter = 0

local function minionFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Minions"
	f.Parent = Workspace:FindFirstChild("ArcanumWorld") or Workspace
	folder = f
	return f
end

local function spawnMinion(ctx: Context.Context, rowName: string, position: Vector3, duration: number)
	local row = Enemies[rowName]
	if not row then
		warn("[Summon] linha inexistente em Enemies.csv: " .. rowName)
		return
	end
	local palette = Schools[row.School] or Schools.Necromancy
	local big = rowName == "BruteServant"
	local description = Instance.new("HumanoidDescription")
	CreatureBuilder.describe(rowName, description, palette)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = rowName
	if big then
		model:ScaleTo(1.45)
	end
	CreatureBuilder.dress(model, rowName, palette)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = NAMES[rowName] or rowName
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("DisplayName", humanoid.DisplayName)
	model:SetAttribute("School", row.School)
	model:SetAttribute("Minion", true)
	if ctx.Player then
		model:SetAttribute("OwnerUserId", ctx.Player.UserId)
	end
	model:PivotTo(CFrame.new(position + Vector3.new(0, if big then 5 else 3.5, 0)))
	model.Parent = minionFolder()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		model:Destroy()
		return
	end
	root:SetNetworkOwner(nil)
	StatsService.register(model, {
		Team = "Player",
		MaxHealth = row.MaxHealth,
		Armor = row.Armor,
		WalkSpeed = Units.meters(row.MoveSpeedMetersPerSecond),
	})
	local tracks = RigAnimator.setup(humanoid, if big then 0.8 else 1.1)
	slotCounter += 1
	MinionBrain.add({
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Owner = ctx.Caster,
		Row = row,
		Big = big,
		Slot = slotCounter,
		Anims = tracks,
		Target = nil,
		NextAttack = os.clock() + 0.8,
		ExpiresAt = os.clock() + duration,
	})
	vfx:FireAllClients("Summon", { Position = position, Model = model, Big = big, School = row.School })
	humanoid.Died:Connect(function()
		vfx:FireAllClients("Death", { Model = model, School = row.School, Boss = false })
		task.delay(1.6, function()
			model:Destroy()
		end)
	end)
end

-- Pontos em volta do mago, no chao.
local function spots(ctx: Context.Context, count: number, radius: number): { Vector3 }
	local center = Targeting.position(ctx.Caster)
	local look = Context.direction(ctx) * Vector3.new(1, 0, 1)
	local base = if look.Magnitude > 1e-3 then math.atan2(look.Z, look.X) else 0
	local list = {}
	for i = 1, count do
		local angle = base + (i - (count + 1) / 2) * (math.pi / math.max(count, 3))
		local point = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		table.insert(list, Area.groundBelow(point + Vector3.new(0, 4, 0), ctx.Caster))
	end
	return list
end

function Summon.cast(ctx: Context.Context)
	local row = ctx.Spell.Row
	local def = ctx.Spell.Def
	local duration = if row.DurationSeconds > 0 then row.DurationSeconds else 30
	if def.Army then
		local skeletons, brutes = math.max(row.Count, 1), row.MaxTargets
		vfx:FireAllClients(
			"Army",
			{ Position = Area.groundBelow(Targeting.position(ctx.Caster), ctx.Caster), School = row.School }
		)
		for i, point in spots(ctx, skeletons + brutes, 9) do
			task.delay(
				0.15 + i * 0.12,
				spawnMinion,
				ctx,
				if i <= skeletons then "SkeletonServant" else "BruteServant",
				point,
				duration
			)
		end
		return
	end
	local rowName = def.Summon or "SkeletonServant"
	local count = math.max(row.Count, 1)
	local limit = math.max(row.MaxTargets, 1)
	local existing = MinionBrain.ofOwner(ctx.Caster, rowName)
	for i = 1, #existing + count - limit do
		if existing[i] then
			MinionBrain.dismiss(existing[i]) -- o mais antigo se desfaz
		end
	end
	for _, point in spots(ctx, count, if rowName == "BruteServant" then 7 else 5) do
		spawnMinion(ctx, rowName, point, duration)
	end
end

function Summon.start()
	task.spawn(function()
		while true do
			task.wait(AI_TICK)
			MinionBrain.stepAll()
		end
	end)
end

return Summon
