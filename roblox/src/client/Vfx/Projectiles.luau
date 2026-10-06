--!strict
-- Visual dos projeteis. O servidor simula; aqui seguimos o mesmo trajeto (inclusive teleguiado)
-- com um estilo por magia: Bola de Fogo (chamas, brasas, fumaca), Missil Arcano (estrelas,
-- aureola girando), Lanca de Magma (ponta incandescente alongada) e Almas Errantes (fogos-fatuos
-- verdes em espiral). Impactos: explosao de fogo, estouro de estrelas, respingo de magma, almas.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Lib = require(script.Parent.Lib)
local Effects = require(script.Parent.Effects)
local Lightning = require(script.Parent.Lightning)
local SpellFx = require(script.Parent.SpellFx)

local Projectiles = {}

type Visual = {
	Parts: { BasePart },
	Root: BasePart,
	Orbit: { BasePart },
	Velocity: Vector3,
	Speed: number,
	Homing: Model?,
	Born: number,
	SpellId: string,
	Seed: number,
	Light: PointLight?,
	Position: Vector3, -- posicao no trajeto (o desenho pode oscilar em volta dela)
	FrozenUntil: number, -- Ampulheta Partida: parado no ar
}

local active: { [string]: Visual } = {}

local function trail(root: BasePart, palette: Lib.Palette, width: number, lifetime: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(palette.Core, palette.Halo)
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Lifetime = lifetime
	t.WidthScale = Lib.seq(1, 0) -- afina para tras
	t.Transparency = Lib.seq(0.05, 1)
	t.FaceCamera = true
	t.Parent = root
end

local function buildFireball(position: Vector3, palette: Lib.Palette): (BasePart, { BasePart }, { BasePart })
	local core = Lib.part(Vector3.one * 0.9, palette.Core, CFrame.new(position), { Shape = Enum.PartType.Ball })
	local halo =
		Lib.part(Vector3.one * 1.9, palette.Halo, core.CFrame, { Shape = Enum.PartType.Ball, Transparency = 0.45 })
	local attachment = Instance.new("Attachment")
	attachment.Parent = core
	Lib.emitter(attachment, "Flame", palette, { Rate = 70 })
	Lib.emitter(attachment, "Ember", palette, { Rate = 25 })
	Lib.emitter(attachment, "Smoke", palette, { Rate = 12, Size = Lib.seq(0.8, 2.4) })
	trail(core, palette, 1.2, 0.18)
	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = 14
	light.Brightness = 3
	light.Parent = core
	return core, { core, halo }, {}
end

local function buildMissile(position: Vector3, palette: Lib.Palette): (BasePart, { BasePart }, { BasePart })
	local core = Lib.part(Vector3.one * 0.5, Color3.new(1, 1, 1), CFrame.new(position), { Shape = Enum.PartType.Ball })
	local halo =
		Lib.part(Vector3.one * 1.1, palette.Halo, core.CFrame, { Shape = Enum.PartType.Ball, Transparency = 0.35 })
	local attachment = Instance.new("Attachment")
	attachment.Parent = core
	Lib.emitter(
		attachment,
		"Star",
		palette,
		{ Rate = 35, Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(0.3, 0.5) }
	)
	trail(core, palette, 0.6, 0.3)
	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = 9
	light.Brightness = 2.5
	light.Parent = core
	-- Aureola girando: 3 losangos em orbita.
	local orbit = {}
	for _ = 1, 3 do
		table.insert(orbit, Lib.part(Vector3.new(0.22, 0.22, 0.22), palette.Accent, core.CFrame))
	end
	return core, { core, halo }, orbit
end

local function buildLance(position: Vector3, palette: Lib.Palette): (BasePart, { BasePart }, { BasePart })
	local core = Lib.part(Vector3.new(0.3, 0.3, 3.2), palette.Core, CFrame.new(position))
	local shell = Lib.part(Vector3.new(0.6, 0.6, 3.8), palette.Halo, core.CFrame, { Transparency = 0.4 })
	local tip = Lib.part(Vector3.new(0.5, 0.5, 0.9), palette.Accent, core.CFrame, { Shape = Enum.PartType.Ball })
	local attachment = Instance.new("Attachment")
	attachment.Parent = core
	Lib.emitter(attachment, "Ember", palette, { Rate = 60, Speed = NumberRange.new(1, 4) })
	Lib.emitter(attachment, "Flame", palette, { Rate = 40, Size = Lib.seq(1, 0.5, 0) })
	trail(core, palette, 0.7, 0.22)
	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = 12
	light.Brightness = 3
	light.Parent = core
	return core, { core, shell, tip }, {}
end

local function buildSoul(position: Vector3, palette: Lib.Palette): (BasePart, { BasePart }, { BasePart })
	local core = Lib.part(Vector3.one * 0.45, palette.Core, CFrame.new(position), { Shape = Enum.PartType.Ball })
	local halo =
		Lib.part(Vector3.one * 1.2, palette.Halo, core.CFrame, { Shape = Enum.PartType.Ball, Transparency = 0.5 })
	local attachment = Instance.new("Attachment")
	attachment.Parent = core
	Lib.emitter(attachment, "Wisp", palette, { Rate = 40, Speed = NumberRange.new(0.2, 1) })
	trail(core, palette, 0.9, 0.45)
	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = 8
	light.Brightness = 2
	light.Parent = core
	return core, { core, halo }, {}
end

local function buildBallLightning(position: Vector3, palette: Lib.Palette): (BasePart, { BasePart }, { BasePart })
	local core = Lib.part(Vector3.one * 1.4, palette.Core, CFrame.new(position), { Shape = Enum.PartType.Ball })
	local shell = Lib.part(Vector3.one * 3.4, palette.Halo, core.CFrame, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
	})
	local glow =
		Lib.part(Vector3.one * 2.4, palette.Halo, core.CFrame, { Shape = Enum.PartType.Ball, Transparency = 0.6 })
	local attachment = Instance.new("Attachment")
	attachment.Parent = core
	Lib.emitter(attachment, "Spark", palette, { Rate = 40, Speed = NumberRange.new(4, 10) })
	Lib.emitter(attachment, "Star", palette, { Rate = 12, Speed = NumberRange.new(1, 3) })
	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = 16
	light.Brightness = 3
	light.Parent = core
	return core, { core, shell, glow }, {}
end

local function buildDefault(position: Vector3, palette: Lib.Palette): (BasePart, { BasePart }, { BasePart })
	local core = Lib.part(Vector3.one * 0.7, palette.Core, CFrame.new(position), { Shape = Enum.PartType.Ball })
	local halo =
		Lib.part(Vector3.one * 1.5, palette.Halo, core.CFrame, { Shape = Enum.PartType.Ball, Transparency = 0.35 })
	trail(core, palette, 0.9, 0.25)
	return core, { core, halo }, {}
end

local BUILDERS: { [string]: (Vector3, Lib.Palette) -> (BasePart, { BasePart }, { BasePart }) } = {
	Fireball = buildFireball,
	ArcaneMissile = buildMissile,
	MagmaLance = buildLance,
	WanderingSouls = buildSoul,
	RoseOfLaments = buildSoul,
	BallLightning = buildBallLightning,
}

function Projectiles.spawn(payload: any)
	local palette = Lib.palette(payload.School)
	-- Neste cliente o projetil sai da gema na pose local (o servidor usa a pose parada).
	local start = Lib.muzzleOf(payload.Caster, payload.Position)
	local builder = BUILDERS[payload.SpellId] or buildDefault
	local root, parts, orbit = builder(start, palette)
	active[payload.Id] = {
		Parts = parts,
		Root = root,
		Orbit = orbit,
		Velocity = payload.Velocity,
		Speed = payload.Speed,
		Homing = payload.Homing,
		Born = os.clock(),
		SpellId = payload.SpellId,
		Seed = math.random() * math.pi * 2,
		Light = root:FindFirstChildOfClass("PointLight"),
		Position = start,
		FrozenUntil = 0,
	}
end

-- Ampulheta Partida: o desenho para no ar junto com o projetil do servidor.
function Projectiles.freeze(id: string, duration: number)
	local visual = active[id]
	if visual then
		visual.FrozenUntil = os.clock() + duration
	end
end

local function destroy(visual: Visual)
	for _, p in visual.Parts do
		-- Particulas e rastro terminam de sumir antes de destruir.
		p.Transparency = 1
		for _, child in p:GetDescendants() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			elseif child:IsA("PointLight") then
				child.Enabled = false
			end
		end
		task.delay(1.2, function()
			p:Destroy()
		end)
	end
	for _, p in visual.Orbit do
		p:Destroy()
	end
end

-- Marca queimada no chao, com brasas, que some devagar.
local function scorch(position: Vector3, palette: Lib.Palette, radius: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local ground = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	if not ground then
		return
	end
	local mark = Lib.part(
		Vector3.new(0.06, radius * 2, radius * 2),
		Color3.fromRGB(28, 20, 22),
		CFrame.new(ground.Position + ground.Normal * 0.04, ground.Position + ground.Normal)
			* CFrame.Angles(0, math.rad(90), 0),
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Transparency = 0.25 }
	)
	local glow = Lib.part(
		Vector3.new(0.07, radius * 1.2, radius * 1.2),
		palette.Halo,
		mark.CFrame,
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.4 }
	)
	local attachment = Instance.new("Attachment")
	attachment.Parent = mark
	local embers = Lib.emitter(attachment, "Ember", palette, { Rate = 14, SpreadAngle = Vector2.new(60, 60) })
	Lib.fade(glow, 1.2, { Transparency = 1 })
	task.delay(1.5, function()
		embers.Enabled = false
	end)
	Lib.fade(mark, 5, { Transparency = 1 }, Enum.EasingStyle.Sine)
end

local IMPACTS: { [string]: (Vector3, Lib.Palette, number) -> () } = {
	Fireball = function(position, palette, radius)
		Effects.flash(position, palette, 2.2, true)
		Effects.shockwave(position - Vector3.new(0, 1.5, 0), palette, math.max(radius, 5))
		Lib.burst(
			position,
			"Flame",
			palette,
			14,
			{ Speed = NumberRange.new(6, 14), Size = Lib.seq(2.4, 1.2, 0), Lifetime = NumberRange.new(0.25, 0.45) }
		)
		Lib.burst(position, "Ember", palette, 26, { Speed = NumberRange.new(8, 18) })
		Lib.burst(position, "Spark", palette, 16)
		Lib.burst(position, "Smoke", palette, 8, { Speed = NumberRange.new(2, 6) })
		scorch(position, palette, math.max(radius, 2.5))
		SpellFx.fireGround(position, palette, 3, 1.5)
	end,
	ArcaneMissile = function(position, palette, _)
		Effects.flash(position, palette, 1.2, false)
		Lib.burst(position, "Star", palette, 18, { Speed = NumberRange.new(8, 16) })
		SpellFx.runeBurst(position, palette)
	end,
	MagmaLance = function(position, palette, _)
		Effects.flash(position, palette, 1.8, true)
		Lib.burst(position, "Ember", palette, 30, { Speed = NumberRange.new(10, 22) })
		Lib.burst(position, "Spark", palette, 18)
		scorch(position, palette, 1.8)
	end,
	WanderingSouls = function(position, palette, _)
		Effects.flash(position, palette, 1, false)
		Lib.burst(position, "Wisp", palette, 16, { Speed = NumberRange.new(3, 8) })
	end,
	RoseOfLaments = function(position, palette, _)
		Lib.burst(position, "Wisp", palette, 10, { Speed = NumberRange.new(3, 8) })
	end,
	BallLightning = function(position, palette, radius)
		Effects.flash(position, palette, 3.5, true)
		Effects.shockwave(position - Vector3.new(0, 2, 0), palette, math.max(radius, 6))
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			local to = position
				+ Vector3.new(math.cos(angle), math.random() - 0.3, math.sin(angle)) * math.max(radius, 6)
			Lightning.bolt(position, to, palette, { Width = 0.18, Forks = 1, Flickers = 2, Duration = 0.2 })
		end
		Lib.burst(position, "Spark", palette, 30)
	end,
}

function Projectiles.finish(payload: any)
	local visual = active[payload.Id]
	local spellId = if visual then visual.SpellId else ""
	if visual then
		active[payload.Id] = nil
		destroy(visual)
	end
	local palette = Lib.palette(payload.School)
	local impact = IMPACTS[spellId]
	if impact then
		impact(payload.Position, palette, payload.Radius or 0)
	else
		Effects.flash(payload.Position, palette, if payload.Radius and payload.Radius > 0 then 2.5 else 1.4, false)
	end
end

local function step(dt: number)
	local now = os.clock()
	for id, visual in active do
		if now < visual.FrozenUntil then
			continue -- tempo parado: nem anda nem envelhece
		end
		local position = visual.Position
		local target = visual.Homing
		local targetPos = if target and target.Parent then Lib.rootPosition(target) else nil
		if targetPos then
			local desired = (targetPos - position).Unit * visual.Speed
			visual.Velocity = visual.Velocity:Lerp(desired, math.clamp(dt * 7, 0, 1))
		end
		-- O "Root" segue o trajeto do servidor; o desenho pode oscilar em volta dele.
		local age = now - visual.Born
		local nextPos = position + visual.Velocity * dt
		local cf = CFrame.lookAt(nextPos, nextPos + visual.Velocity)
		visual.Position = nextPos
		local drawn = cf
		if visual.SpellId == "ArcaneMissile" then
			-- Espiral em volta do trajeto (entra suave nos primeiros quadros).
			local amplitude = 0.7 * math.clamp(age * 5, 0, 1)
			local spin = age * 16 + visual.Seed
			drawn = cf * CFrame.new(math.cos(spin) * amplitude, math.sin(spin) * amplitude, 0)
		elseif visual.SpellId == "MagmaLance" and math.random() < dt * 14 then
			-- Gotas de lava escorrendo da lanca.
			Lib.burst(nextPos, "Ember", Lib.palette("Fire"), 2, {
				Speed = NumberRange.new(0, 2),
				Acceleration = Vector3.new(0, -60, 0),
				Lifetime = NumberRange.new(0.5, 0.8),
				Size = Lib.seq(0.5, 0.2),
			})
		elseif visual.SpellId == "BallLightning" then
			drawn = cf * CFrame.Angles(age * 3, age * 5, 0)
			if math.random() < dt * 18 then
				Lightning.bolt(
					nextPos,
					nextPos + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 6,
					Lib.palette("Electricity"),
					{ Width = 0.08, Forks = 0, Flickers = 1, Duration = 0.07, Glow = false }
				)
			end
		elseif visual.SpellId == "WanderingSouls" or visual.SpellId == "RoseOfLaments" then
			-- Fogo-fatuo: espiral larga e lenta, que ondula.
			local amplitude = 1.1 * math.clamp(age * 3, 0, 1)
			local spin = age * 7 + visual.Seed
			drawn = cf * CFrame.new(math.cos(spin) * amplitude, math.sin(spin * 1.3) * amplitude * 0.7, 0)
		elseif visual.SpellId == "Fireball" then
			drawn = cf * CFrame.Angles(0, 0, age * 9) -- nucleo girando
			if visual.Light then
				visual.Light.Brightness = 2.6 + math.noise(age * 12, visual.Seed) * 1.6 -- chama tremulando
			end
		end
		for _, p in visual.Parts do
			p.CFrame = drawn
		end
		for i, p in visual.Orbit do
			local angle = age * 12 + i * (math.pi * 2 / #visual.Orbit)
			p.CFrame = drawn * CFrame.Angles(0, 0, angle) * CFrame.new(0.75, 0, 0) * CFrame.Angles(0, 0, math.rad(45))
		end
		if age > 8 then
			active[id] = nil
			destroy(visual)
		end
	end
end

function Projectiles.start()
	RunService.RenderStepped:Connect(step)
end

return Projectiles
