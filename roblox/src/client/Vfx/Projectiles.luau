--!strict
-- Visual dos projeteis. O servidor simula; aqui seguimos o mesmo trajeto (inclusive teleguiado)
-- com um estilo por magia: Bola de Fogo (chamas, brasas, fumaca) e Missil Arcano (estrelas,
-- aureola girando). Impactos: explosao de fogo ou estouro de estrelas.

local RunService = game:GetService("RunService")

local Lib = require(script.Parent.Lib)
local Effects = require(script.Parent.Effects)

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
	}
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
	end,
	ArcaneMissile = function(position, palette, _)
		Effects.flash(position, palette, 1.2, false)
		Lib.burst(position, "Star", palette, 18, { Speed = NumberRange.new(8, 16) })
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
		local position = visual.Root.Position
		local target = visual.Homing
		local targetPos = if target and target.Parent then Lib.rootPosition(target) else nil
		if targetPos then
			local desired = (targetPos - position).Unit * visual.Speed
			visual.Velocity = visual.Velocity:Lerp(desired, math.clamp(dt * 7, 0, 1))
		end
		local nextPos = position + visual.Velocity * dt
		local cf = CFrame.lookAt(nextPos, nextPos + visual.Velocity)
		for _, p in visual.Parts do
			p.CFrame = cf
		end
		local age = now - visual.Born
		for i, p in visual.Orbit do
			local angle = age * 12 + i * (math.pi * 2 / #visual.Orbit)
			p.CFrame = cf * CFrame.Angles(0, 0, angle) * CFrame.new(0.75, 0, 0) * CFrame.Angles(0, 0, math.rad(45))
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
