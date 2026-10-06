--!strict
-- Arena de rounds (estilo Ratchet & Clank: Going Commando). Regras em Shared/Math/ArenaMath.
--   Idle         esperando; quem entra no portal do Sandbox aparece na Arena
--   Countdown    5 s ate o round 1
--   Round        criaturas saem dos 4 portoes (cacadoras: sem coleira, sempre atras de alguem)
--                ate acabar a cota do round; nos rounds de chefe, os chefes entram primeiro
--   Intermission round vencido: XP para todos, coletaveis renascem, contagem para o proximo
--   Defeat       todos os lutadores cairam ou sairam: limpa a Arena e volta para Idle
-- Lutadores = jogadores vivos dentro do circulo. Qualquer um pode entrar no meio (entra na luta).
-- Coletaveis de vida e mana no centro: passar por cima pega; renascem em PickupRespawnSeconds.
-- Estado replicado nos atributos da Model "Arena" (o cliente desenha a HUD da Arena).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ArenaMath = require(Shared.Math.ArenaMath)
local Enemies = require(Shared.Data.Enemies) :: any
local Net = require(Shared.Net)
local StatsService = require(script.Parent.StatsService)
local DamageService = require(script.Parent.DamageService)
local ProgressionService = require(script.Parent.ProgressionService)
local WorldService = require(script.Parent.WorldService)
local EnemyService = require(script.Parent.EnemyService)
local ArenaBuilder = require(script.Parent.Parent.Arena.ArenaBuilder)

local ArenaService = {}

local TICK = 0.2
local PORTAL_REACH = 6 -- studs do centro do portal para atravessar
local PICKUP_REACH = 4.5
local TELEPORT_COOLDOWN = 2
local FALL_DEPTH = 40 -- caiu da ilha: volta para dentro
local BOSS_ROW = "CrystalGolem"

type Pickup = { Kind: string, Position: Vector3, Model: Model, Available: boolean, RespawnAt: number }

local layout: ArenaBuilder.Layout
local vfx = Net.get("Vfx")
local state = "Idle"
local round = 0
local stateEndsAt = 0
local toSpawn = 0
local bossesToSpawn = 0
local nextSpawn = 0
local best = 0
local kills = 0
local alive: { [Model]: boolean } = {}
local pickups: { Pickup } = {}
local lastTeleport: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function aliveCount(): number
	local n = 0
	for model in alive do
		if model.Parent and StatsService.isAlive(model) then
			n += 1
		else
			alive[model] = nil
		end
	end
	return n
end

local function insideArena(position: Vector3): boolean
	local offset = position - layout.Center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= layout.Radius + 6
		and offset.Y > -FALL_DEPTH
		and offset.Y < 60
end

-- Jogadores vivos dentro da Arena.
local function fighters(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root and StatsService.isAlive(character) and insideArena(root.Position) then
			table.insert(list, player)
		end
	end
	return list
end

local function publish()
	local model = layout.Model
	model:SetAttribute("State", state)
	model:SetAttribute("Round", round)
	model:SetAttribute("Remaining", toSpawn + bossesToSpawn + aliveCount())
	model:SetAttribute("EndsAt", stateEndsAt)
	model:SetAttribute("Best", best)
	model:SetAttribute("Kills", kills)
	model:SetAttribute("Fighters", #fighters())
end

local function announce(text: string, sub: string?, kind: string)
	vfx:FireAllClients("ArenaAnnounce", { Text = text, Sub = sub, Kind = kind, Center = layout.Center })
end

local function teleport(character: Model, position: Vector3, facing: Vector3)
	lastTeleport[character] = os.clock()
	character:PivotTo(CFrame.lookAt(position, position + facing))
end

---------------------------------------------------------------------------------------------------
-- Coletaveis

local function setPickupVisible(pickup: Pickup, visible: boolean)
	pickup.Available = visible
	pickup.Model:SetAttribute("Available", visible)
	for _, p in pickup.Model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = if visible then (p:GetAttribute("BaseTransparency") or 0) :: number else 1
		elseif p:IsA("PointLight") or p:IsA("ParticleEmitter") then
			p.Enabled = visible
		end
	end
end

local function buildPickup(kind: string, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = kind .. "Pickup"
	local color = if kind == "Health" then Color3.fromRGB(90, 235, 120) else Color3.fromRGB(80, 160, 255)
	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.CanQuery = false
	crystal.CastShadow = false
	crystal.Material = Enum.Material.Neon
	crystal.Color = color
	crystal.Size = Vector3.new(1.4, 2.6, 1.4)
	crystal.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(45))
	crystal.Parent = model
	local shell = crystal:Clone()
	shell.Name = "Shell"
	shell.Material = Enum.Material.Glass
	shell.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
	shell.Transparency = 0.45
	shell.Size = Vector3.new(2.2, 3.6, 2.2)
	shell:SetAttribute("BaseTransparency", 0.45)
	shell.Parent = model
	-- Simbolo: cruz (vida) ou gota em losango (mana).
	if kind == "Health" then
		for _, size in { Vector3.new(2.2, 0.6, 0.3), Vector3.new(0.6, 2.2, 0.3) } do
			local bar = crystal:Clone()
			bar.Name = "Cross"
			bar.Color = Color3.new(1, 1, 1)
			bar.Size = size
			bar.CFrame = CFrame.new(position + Vector3.new(0, 2.8, 0))
			bar.Parent = model
		end
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = crystal
	local attachment = Instance.new("Attachment")
	attachment.Parent = crystal
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	motes.LightEmission = 1
	motes.Brightness = 1.6
	motes.Rate = 8
	motes.Lifetime = NumberRange.new(0.8, 1.2)
	motes.Speed = NumberRange.new(1, 2)
	motes.Acceleration = Vector3.new(0, 3, 0)
	motes.Size = NumberSequence.new(0.35, 0)
	motes.Parent = attachment
	model.PrimaryPart = crystal
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Base", position)
	model:AddTag("ArenaPickup")
	model.Parent = layout.Model
	return model
end

local function refreshPickups()
	for _, pickup in pickups do
		if not pickup.Available then
			setPickupVisible(pickup, true)
		end
	end
end

local function tryPickups(now: number)
	for _, pickup in pickups do
		if not pickup.Available then
			if now >= pickup.RespawnAt then
				setPickupVisible(pickup, true)
			end
			continue
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local stats = character and StatsService.get(character)
			if
				character
				and root
				and stats
				and stats.Humanoid.Health > 0
				and (root.Position - pickup.Position).Magnitude <= PICKUP_REACH
			then
				-- So pega se precisar (vida ou mana abaixo do maximo).
				local humanoid = stats.Humanoid
				local needs = if pickup.Kind == "Health"
					then humanoid.Health < humanoid.MaxHealth
					else stats.Mana < stats.MaxMana
				if needs then
					if pickup.Kind == "Health" then
						DamageService.heal(character, humanoid.MaxHealth * ArenaMath.Config.HealthPickupFraction)
					else
						StatsService.setMana(stats, stats.Mana + stats.MaxMana * ArenaMath.Config.ManaPickupFraction)
					end
					pickup.RespawnAt = now + ArenaMath.Config.PickupRespawnSeconds
					setPickupVisible(pickup, false)
					vfx:FireAllClients(
						"ArenaPickup",
						{ Kind = pickup.Kind, Position = pickup.Position, Model = character }
					)
					break
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Criaturas

local function clearEnemies()
	for model in alive do
		if model.Parent then
			model:Destroy()
		end
	end
	table.clear(alive)
end

local function track(model: Model)
	alive[model] = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if alive[model] then
				alive[model] = nil
				kills += 1
			end
		end)
	end
end

local function spawnOne(rowName: string, boss: boolean)
	local gate = layout.Gates[math.random(1, #layout.Gates)]
	local jitter = gate.RightVector * (math.random() - 0.5) * 10
	local cframe = gate + jitter + Vector3.new(0, if boss then 6 else 0, 0)
	vfx:FireAllClients("ArenaSpawn", {
		Position = cframe.Position,
		School = (Enemies[rowName] and Enemies[rowName].School) or "Energy",
		Boss = boss,
	})
	task.delay(0.45, function()
		if state ~= "Round" then
			return
		end
		EnemyService.spawn(rowName, cframe, {
			HealthScale = ArenaMath.healthScale(round),
			SpellPower = ArenaMath.spellPower(round),
			EliteChance = ArenaMath.eliteChance(round),
			Hunt = { Center = layout.Center, Radius = layout.Radius + 6 },
			OnSpawned = track,
		})
	end)
end

---------------------------------------------------------------------------------------------------
-- Estados

local function setState(newState: string, duration: number?)
	state = newState
	stateEndsAt = if duration then serverNow() + duration else 0
end

local function startRound(n: number)
	round = n
	local players = math.max(#fighters(), 1)
	toSpawn = ArenaMath.enemyCount(n, players)
	bossesToSpawn = ArenaMath.bossCount(n)
	nextSpawn = os.clock() + 1
	setState("Round")
	if bossesToSpawn > 0 then
		announce("ROUND " .. n, if bossesToSpawn > 1 then "CHEFES A CAMINHO!" else "UM CHEFE SE APROXIMA!", "Boss")
	else
		announce("ROUND " .. n, string.format("%d criaturas", toSpawn), "Round")
	end
end

local function defeat()
	best = math.max(best, round - 1)
	announce("DERROTA", string.format("Voce chegou ao round %d", round), "Defeat")
	clearEnemies()
	setState("Defeat", ArenaMath.Config.DefeatSeconds)
end

local function step()
	local now = os.clock()
	local players = fighters()

	-- Quem caiu da ilha volta para dentro.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root then
			local offset = root.Position - layout.Center
			local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flatDistance < layout.Radius + 60 and offset.Y < -FALL_DEPTH and offset.Y > -400 then
				teleport(character, layout.Arrival, layout.Center - layout.Arrival)
			end
		end
	end

	-- Portais: Sandbox -> Arena e saida -> Sandbox.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root and now - (lastTeleport[character] or -math.huge) > TELEPORT_COOLDOWN then
			if (root.Position - (layout.Entrance + Vector3.new(0, 4, 0))).Magnitude < PORTAL_REACH then
				teleport(character, layout.Arrival, layout.Center - layout.Arrival)
				vfx:FireAllClients("ArenaTeleport", { Model = character, To = layout.Arrival })
			elseif (root.Position - layout.Exit).Magnitude < PORTAL_REACH then
				local back = layout.Entrance + Vector3.new(-10, 4, 0)
				teleport(character, back, Vector3.new(-1, 0, 0))
				vfx:FireAllClients("ArenaTeleport", { Model = character, To = back })
			end
		end
	end

	tryPickups(now)

	if state == "Idle" then
		if #players > 0 then
			setState("Countdown", ArenaMath.Config.CountdownSeconds)
			announce("ARENA ARCANA", "Prepare-se!", "Start")
		end
	elseif state == "Countdown" then
		if #players == 0 then
			setState("Idle")
		elseif serverNow() >= stateEndsAt then
			startRound(1)
		end
	elseif state == "Round" then
		if #players == 0 then
			defeat()
		else
			local living = aliveCount()
			local cap = ArenaMath.maxAlive(round, #players)
			if now >= nextSpawn and living < cap then
				if bossesToSpawn > 0 then
					bossesToSpawn -= 1
					spawnOne(BOSS_ROW, true)
					nextSpawn = now + 2.5
				elseif toSpawn > 0 then
					toSpawn -= 1
					local name = ArenaMath.pick(ArenaMath.roster(round), math.random()) or "ArcaneSlime"
					spawnOne(name, false)
					nextSpawn = now + ArenaMath.spawnInterval(round)
				end
			end
			if toSpawn == 0 and bossesToSpawn == 0 and living == 0 and now >= nextSpawn then
				best = math.max(best, round)
				local xp = ArenaMath.roundXP(round)
				for _, player in players do
					ProgressionService.addXP(player, xp)
				end
				announce(
					"ROUND " .. round .. " VENCIDO!",
					string.format("+%d XP  -  proximo round em %d s", xp, ArenaMath.Config.IntermissionSeconds),
					"Clear"
				)
				refreshPickups()
				setState("Intermission", ArenaMath.Config.IntermissionSeconds)
			end
		end
	elseif state == "Intermission" then
		if #players == 0 then
			defeat()
		elseif serverNow() >= stateEndsAt then
			startRound(round + 1)
		end
	elseif state == "Defeat" then
		if serverNow() >= stateEndsAt then
			round = 0
			kills = 0
			refreshPickups()
			setState("Idle")
		end
	end
	publish()
end

function ArenaService.init()
	layout = ArenaBuilder.build(WorldService.getWorld())
	for _, pad in layout.Pads do
		table.insert(pickups, {
			Kind = pad.Kind,
			Position = pad.Position,
			Model = buildPickup(pad.Kind, pad.Position),
			Available = true,
			RespawnAt = 0,
		})
	end
	publish()
end

function ArenaService.start()
	while true do
		task.wait(TICK)
		local ok, err = pcall(step)
		if not ok then
			warn("[Arena] " .. tostring(err))
		end
	end
end

return ArenaService
