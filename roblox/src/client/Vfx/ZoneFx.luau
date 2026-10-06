--!strict
-- Efeitos que duram (so visual): zonas, portais, corrente de sangue e coroa de trovoes.
-- Cada um fica registrado pelo Id do servidor (ou pelo modelo) e e desfeito no fim.
--   Static       Campo Estatico: anel eletrico que segue o mago, arcos ate a borda
--   Wall         Muralha de Chamas: cortina de fogo alta com base incandescente
--   Vortex       Vortice Infernal: redemoinho de chamas girando, anel de fogo no chao
--   Singularity  Singularidade: orbe escuro com disco de acrecao; particulas sendo sugadas
--   Rain         Chuva Rubra: chuva de sangue estilizado sobre o circulo, respingos
--   Hourglass    Ampulheta Partida: esfera de tempo parado, marcadores de relogio girando

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)
local Effects = require(script.Parent.Effects)
local Lightning = require(script.Parent.Lightning)

local ZoneFx = {}

type Active = { Stop: (boolean) -> (), EndsAt: number }

local active: { [string]: Active } = {}
local UP = Vector3.new(0, 1, 0)

local function disc(position: Vector3, diameter: number, color: Color3, props: { [string]: any }?): Part
	local options: { [string]: any } = { Shape = Enum.PartType.Cylinder }
	for k, v in props or {} do
		options[k] = v
	end
	return Lib.part(
		Vector3.new(0.08, diameter, diameter),
		color,
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		options
	)
end

-- Anel de segmentos (horizontal) que pode girar e seguir um centro.
local function ring(center: Vector3, radius: number, color: Color3, segments: number, thickness: number): { BasePart }
	local parts = {}
	for i = 1, segments do
		local angle = i / segments * math.pi * 2
		local arc = 2 * math.pi * radius / segments
		table.insert(parts, Lib.part(Vector3.new(thickness, thickness * 0.6, arc * 0.8), color, CFrame.new(center)))
		parts[#parts]:SetAttribute("Angle", angle)
	end
	return parts
end

local function placeRing(parts: { BasePart }, center: Vector3, radius: number, spin: number)
	for _, p in parts do
		local angle = (p:GetAttribute("Angle") :: number) + spin
		local pos = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		p.CFrame = CFrame.lookAt(pos, pos + tangent)
	end
end

local function fadeAll(parts: { BasePart }, seconds: number)
	for _, p in parts do
		if p.Parent then
			Lib.fade(p, seconds, { Transparency = 1 })
		end
	end
end

local function register(id: string, duration: number, stop: (boolean) -> ())
	active[id] = { Stop = stop, EndsAt = os.clock() + duration }
	task.delay(duration + 0.1, function()
		local entry = active[id]
		if entry then
			active[id] = nil
			entry.Stop(false)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Zonas

local function static(p: any, palette: Lib.Palette)
	local caster: Model? = p.Caster
	local radius = p.Radius
	local outer = ring(p.Position, radius, palette.Halo, 28, 0.22)
	local inner = ring(p.Position, radius * 0.55, palette.Core, 16, 0.12)
	local floor = disc(p.Position + UP * 0.1, radius * 2, palette.Halo, { Transparency = 0.85 })
	local parts = table.clone(outer)
	for _, x in inner do
		table.insert(parts, x)
	end
	table.insert(parts, floor)
	local center = p.Position
	local nextArc = 0
	local connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local root = caster and Lib.rootPosition(caster)
		if root then
			center = Lib.groundBelow(root, caster) + UP * 0.25
		end
		placeRing(outer, center, radius, now * 0.8)
		placeRing(inner, center, radius * 0.55, -now * 1.4)
		floor.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
		if now >= nextArc then
			nextArc = now + 0.07
			local angle = math.random() * math.pi * 2
			local edge = center + Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
			local from = (if root then root else center + UP * 3) + Vector3.new(0, math.random() * 1.5, 0)
			Lightning.bolt(
				from,
				edge,
				palette,
				{ Width = 0.08, Forks = 1, Flickers = 1, Duration = 0.08, Glow = false }
			)
		end
	end)
	return function(_: boolean)
		connection:Disconnect()
		fadeAll(parts, 0.3)
	end
end

local function wall(p: any, palette: Lib.Palette)
	local from: Vector3, to: Vector3 = p.From, p.To
	local length = (to - from).Magnitude
	local direction = (to - from).Unit
	local parts: { BasePart } = {}
	local emitters: { ParticleEmitter } = {}
	local mid = (from + to) / 2 + UP * 0.15
	table.insert(parts, Lib.part(Vector3.new(1.2, 0.2, length), palette.Accent, CFrame.lookAt(mid, mid + direction)))
	Lib.swapGround(mid, length / 2, Enum.Material.CrackedLava, p.Duration + 0.5)
	local count = math.max(math.floor(length / 2.2), 3)
	for i = 0, count do
		local at = from + direction * (i / count) * length + UP * 0.4
		local anchor = Lib.anchor(at, p.Duration + 2)
		table.insert(
			emitters,
			Lib.emitter(anchor, "Flame", palette, {
				Rate = 45,
				Speed = NumberRange.new(9, 15),
				Size = Lib.seq(3.2, 2.4, 0.6),
				Lifetime = NumberRange.new(0.45, 0.75),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(8, 8),
			})
		)
		table.insert(emitters, Lib.emitter(anchor, "Ember", palette, { Rate = 10, Speed = NumberRange.new(6, 12) }))
		if i % 3 == 0 then
			local light = Instance.new("PointLight")
			light.Color = palette.Halo
			light.Range = 14
			light.Brightness = 2
			light.Parent = anchor
		end
	end
	return function(_: boolean)
		for _, e in emitters do
			e.Enabled = false
		end
		fadeAll(parts, 0.5)
	end
end

local function vortex(p: any, palette: Lib.Palette)
	local center = p.Position
	local radius = p.Radius
	local parts: { BasePart } = {}
	local spinners: { Attachment } = {}
	local emitters: { ParticleEmitter } = {}
	local hub = Lib.part(Vector3.one * 0.2, palette.Halo, CFrame.new(center), { Transparency = 1 })
	table.insert(parts, hub)
	for level = 0, 4 do
		for k = 1, 3 do
			local a = Instance.new("Attachment")
			a:SetAttribute("Level", level)
			a:SetAttribute("Phase", k / 3 * math.pi * 2)
			a.Parent = hub
			table.insert(spinners, a)
			table.insert(
				emitters,
				Lib.emitter(a, "Flame", palette, {
					Rate = 22,
					Speed = NumberRange.new(1, 3),
					Size = Lib.seq(2.4, 1.6, 0),
					Lifetime = NumberRange.new(0.3, 0.5),
				})
			)
		end
	end
	local floor = ring(center + UP * 0.2, radius, palette.Halo, 24, 0.3)
	for _, x in floor do
		table.insert(parts, x)
	end
	local smoke = Lib.emitter(hub, "Smoke", palette, { Rate = 10, Speed = NumberRange.new(4, 8), Size = Lib.seq(2, 5) })
	table.insert(emitters, smoke)
	local connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		placeRing(floor, center + UP * 0.2, radius, now * 2)
		for _, a in spinners do
			local level = a:GetAttribute("Level") :: number
			local angle = now * (5 - level * 0.5) + (a:GetAttribute("Phase") :: number)
			local r = radius * (0.3 + level * 0.17)
			a.WorldPosition = center + Vector3.new(math.cos(angle) * r, 1 + level * 2.4, math.sin(angle) * r)
		end
	end)
	return function(_: boolean)
		connection:Disconnect()
		for _, e in emitters do
			e.Enabled = false
		end
		fadeAll(parts, 0.4)
	end
end

local function singularity(p: any, palette: Lib.Palette)
	local center = p.Position + UP * 4
	local radius = p.Radius
	local core = Lib.part(Vector3.one * 3, Color3.fromRGB(8, 4, 16), CFrame.new(center), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.SmoothPlastic,
	})
	local halo = Lib.part(Vector3.one * 4.4, palette.Halo, CFrame.new(center), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
	})
	local disk = ring(center, 4.2, palette.Accent, 30, 0.35)
	local outer = ring(p.Position + UP * 0.2, radius, palette.Halo, 32, 0.2)
	-- Particulas nascem na casca de uma esfera grande e vao para dentro.
	local shell = Lib.part(Vector3.one * radius * 2, palette.Halo, CFrame.new(center), { Transparency = 1 })
	local suck = Instance.new("ParticleEmitter")
	suck.Texture = Lib.Textures.Sparkle
	suck.Color = ColorSequence.new(palette.Core, palette.Halo)
	suck.LightEmission = 1
	suck.Size = Lib.seq(0.5, 0.1)
	suck.Transparency = Lib.seq(0.1, 0.8)
	suck.Lifetime = NumberRange.new(0.6, 0.9)
	suck.Speed = NumberRange.new(radius * 1.2, radius * 1.6)
	suck.Shape = Enum.ParticleEmitterShape.Sphere
	suck.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	suck.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	suck.Rate = 70
	suck.Parent = shell
	local parts = { core, halo, shell }
	for _, x in disk do
		table.insert(parts, x)
	end
	for _, x in outer do
		table.insert(parts, x)
	end
	local connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local tilt = CFrame.new(center) * CFrame.Angles(math.rad(18), 0, math.rad(10))
		for _, s in disk do
			local angle = (s:GetAttribute("Angle") :: number) + now * 3
			local pos = tilt * Vector3.new(math.cos(angle) * 4.2, 0, math.sin(angle) * 4.2)
			s.CFrame =
				CFrame.lookAt(pos, pos + tilt:VectorToWorldSpace(Vector3.new(-math.sin(angle), 0, math.cos(angle))))
		end
		placeRing(outer, p.Position + UP * 0.2, radius * (0.85 + 0.15 * math.sin(now * 3)), -now)
		halo.Size = Vector3.one * (4.4 + math.sin(now * 8) * 0.3)
	end)
	return function(_: boolean)
		connection:Disconnect()
		suck.Enabled = false
		fadeAll(parts, 0.2)
	end
end

local function rain(p: any, palette: Lib.Palette)
	local center = p.Position
	local radius = p.Radius
	local cloud = Lib.part(Vector3.new(radius * 2, 1, radius * 2), palette.Halo, CFrame.new(center + UP * 22), {
		Transparency = 1,
	})
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = Lib.Textures.Sparkle
	drops.Color = ColorSequence.new(palette.Halo, palette.Accent)
	drops.LightEmission = 0.6
	drops.Size = NumberSequence.new(0.35, 0.2)
	drops.Squash = NumberSequence.new(2.5)
	drops.Lifetime = NumberRange.new(0.55, 0.7)
	drops.Speed = NumberRange.new(30, 38)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.SpreadAngle = Vector2.new(4, 4)
	drops.Shape = Enum.ParticleEmitterShape.Box
	drops.Rate = 120
	drops.Parent = cloud
	local mist = Lib.emitter(cloud, "Smoke", palette, {
		Color = ColorSequence.new(palette.Accent, Color3.fromRGB(40, 6, 12)),
		Size = Lib.seq(5, 9),
		Rate = 6,
		Speed = NumberRange.new(0.5, 1.5),
	})
	local floor =
		disc(center + UP * 0.12, radius * 2, palette.Accent, { Transparency = 0.6, Material = Enum.Material.Glass })
	local edge = ring(center + UP * 0.2, radius, palette.Halo, 30, 0.2)
	placeRing(edge, center + UP * 0.2, radius, 0)
	local running = true
	task.spawn(function()
		while running do
			local angle = math.random() * math.pi * 2
			local at = center + Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * radius * math.sqrt(math.random())
			Lib.burst(at, "Spark", palette, 3, { Speed = NumberRange.new(4, 8), Acceleration = Vector3.new(0, -40, 0) })
			task.wait(0.08)
		end
	end)
	local parts = { cloud, floor }
	for _, x in edge do
		table.insert(parts, x)
	end
	return function(_: boolean)
		running = false
		drops.Enabled = false
		mist.Enabled = false
		fadeAll(parts, 0.6)
	end
end

local function hourglass(p: any, palette: Lib.Palette)
	local center = p.Position + UP * 3
	local radius = p.Radius + 2
	local sphere = Lib.part(Vector3.one * radius * 2, palette.Halo, CFrame.new(center), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Glass,
		Transparency = 0.82,
	})
	local field = Lib.part(Vector3.one * radius * 1.96, palette.Accent, CFrame.new(center), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
	})
	-- 12 marcas de relogio e dois ponteiros girando devagar (tempo quase parado).
	local marks = ring(center, radius * 0.95, palette.Core, 12, 0.3)
	local hands = {
		Lib.part(Vector3.new(0.25, 0.25, radius * 0.7), palette.Core, CFrame.new(center)),
		Lib.part(Vector3.new(0.18, 0.18, radius * 0.9), palette.Halo, CFrame.new(center)),
	}
	local shards: { BasePart } = {}
	for i = 1, 8 do
		local s = Lib.part(Vector3.new(0.5, 0.9, 0.2), palette.Accent, CFrame.new(center), {
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		})
		s:SetAttribute("Angle", i / 8 * math.pi * 2)
		table.insert(shards, s)
	end
	local connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		placeRing(marks, center, radius * 0.95, now * 0.1)
		for i, h in hands do
			local angle = now * (if i == 1 then 0.15 else 1.2)
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			h.CFrame = CFrame.lookAt(center + dir * h.Size.Z / 2, center + dir * h.Size.Z)
		end
		for _, s in shards do
			local angle = (s:GetAttribute("Angle") :: number) + now * 0.3
			s.CFrame = CFrame.new(
				center
					+ Vector3.new(
						math.cos(angle) * radius * 0.7,
						math.sin(now + angle) * 1.5,
						math.sin(angle) * radius * 0.7
					)
			) * CFrame.Angles(now, angle, 0)
		end
	end)
	local parts = { sphere, field }
	for _, list in { marks, hands, shards } do
		for _, x in list do
			table.insert(parts, x)
		end
	end
	return function(_: boolean)
		connection:Disconnect()
		Effects.flash(center, palette, 2, false)
		fadeAll(parts, 0.35)
	end
end

local BUILDERS: { [string]: (any, Lib.Palette) -> (boolean) -> () } = {
	Static = static,
	Wall = wall,
	Vortex = vortex,
	Singularity = singularity,
	Rain = rain,
	Hourglass = hourglass,
}

function ZoneFx.open(p: any)
	local builder = BUILDERS[p.Mode]
	if not builder then
		return
	end
	local stop = builder(p, Lib.palette(p.School))
	register(p.Id, p.Duration, stop)
end

-- Fim de zona (a Singularidade implode).
function ZoneFx.close(p: any)
	local entry = active[p.Id]
	if entry then
		active[p.Id] = nil
		entry.Stop(true)
	end
	if p.Mode == "Singularity" then
		local palette = Lib.palette("Energy")
		local center = p.Position + UP * 4
		Effects.flash(center, palette, 5, true)
		Effects.shockwave(p.Position + UP * 0.2, palette, p.Radius * 1.4)
		Lib.burst(center, "Star", palette, 50, { Speed = NumberRange.new(20, 40) })
		Lib.burst(center, "Wisp", palette, 30, { Speed = NumberRange.new(10, 20) })
	end
end

---------------------------------------------------------------------------------------------------
-- Portais

local function portalRing(position: Vector3, facing: Vector3, palette: Lib.Palette): { BasePart }
	local parts: { BasePart } = {}
	local frame = CFrame.lookAt(position + UP * 3.4, position + UP * 3.4 + facing)
	for i = 1, 22 do
		local angle = i / 22 * math.pi * 2
		local local_ = Vector3.new(math.cos(angle) * 2.2, math.sin(angle) * 3.2, 0)
		local nextAngle = (i + 1) / 22 * math.pi * 2
		local nextLocal = Vector3.new(math.cos(nextAngle) * 2.2, math.sin(nextAngle) * 3.2, 0)
		local a, b = frame * local_, frame * nextLocal
		table.insert(
			parts,
			Lib.part(Vector3.new(0.3, 0.3, (b - a).Magnitude + 0.1), palette.Halo, CFrame.lookAt((a + b) / 2, b))
		)
	end
	local surface = Lib.part(Vector3.new(0.1, 6.2, 4.2), palette.Accent, frame * CFrame.Angles(0, math.rad(90), 0), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.ForceField,
	})
	table.insert(parts, surface)
	local anchor = Lib.anchor(position + UP * 3.4, 600)
	Lib.emitter(
		anchor,
		"Star",
		palette,
		{ Rate = 12, Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(0.6, 1) }
	)
	parts[#parts + 1] = Lib.part(Vector3.one * 0.1, palette.Halo, CFrame.new(position), { Transparency = 1 })
	anchor.Parent = parts[#parts]
	for _, part in parts do
		local size = part.Size
		part.Size = size * 0.1
		TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = size }):Play()
	end
	return parts
end

function ZoneFx.portal(p: any)
	local palette = Lib.palette(p.School)
	local parts = portalRing(p.A, p.Facing, palette)
	for _, x in portalRing(p.B, p.Facing, palette) do
		table.insert(parts, x)
	end
	Effects.flash(p.A + UP * 3, palette, 2, true)
	Effects.flash(p.B + UP * 3, palette, 2, true)
	register(p.Id, p.Duration, function(_: boolean)
		fadeAll(parts, 0.4)
	end)
end

function ZoneFx.closePortal(id: string)
	local entry = active[id]
	if entry then
		active[id] = nil
		entry.Stop(true)
	end
end

---------------------------------------------------------------------------------------------------
-- Corrente Carmesim (elos entre o mago e o alvo, com barriga) e Coroa de Trovoes

function ZoneFx.chain(caster: Model, target: Model, duration: number, palette: Lib.Palette)
	local links: { BasePart } = {}
	for _ = 1, 14 do
		table.insert(
			links,
			Lib.part(Vector3.new(0.35, 0.18, 0.55), palette.Halo, CFrame.new(), {
				Material = Enum.Material.SmoothPlastic,
			})
		)
	end
	local id = "chain_" .. tostring(target) .. tostring(os.clock())
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local a = Lib.muzzleOf(caster, Lib.rootPosition(caster) or Vector3.zero)
		local b = Lib.rootPosition(target)
		if not b or not target.Parent or not caster.Parent then
			local entry = active[id]
			if entry then
				active[id] = nil
				entry.Stop(true)
			end
			return
		end
		local count = #links
		for i, link in links do
			local t = i / (count + 1)
			local sag = math.sin(t * math.pi) * 1.2 * (1 + math.sin(os.clock() * 4) * 0.2)
			local pos = a:Lerp(b, t) - UP * sag
			local nextPos = a:Lerp(b, (i + 1) / (count + 1)) - UP * math.sin((i + 1) / (count + 1) * math.pi) * 1.2
			link.CFrame = CFrame.lookAt(pos, nextPos) * CFrame.Angles(0, 0, if i % 2 == 0 then math.rad(90) else 0)
		end
	end)
	register(id, duration, function(_: boolean)
		connection:Disconnect()
		fadeAll(links, 0.3)
	end)
end

local crowns: { [Model]: { Parts: { BasePart }, Connection: RBXScriptConnection } } = {}

function ZoneFx.crown(caster: Model, duration: number, palette: Lib.Palette)
	local spikes: { BasePart } = {}
	for i = 1, 8 do
		local s = Lib.part(Vector3.new(0.25, 1.1, 0.25), palette.Core, CFrame.new())
		s:SetAttribute("Angle", i / 8 * math.pi * 2)
		table.insert(spikes, s)
	end
	local band = {}
	for i = 1, 16 do
		local b = Lib.part(Vector3.new(0.2, 0.2, 0.5), palette.Halo, CFrame.new())
		b:SetAttribute("Angle", i / 16 * math.pi * 2)
		table.insert(band, b)
	end
	local connection = RunService.RenderStepped:Connect(function()
		local root = Lib.rootPosition(caster)
		if not root then
			return
		end
		local top = root + UP * 4.3
		local spin = os.clock() * 1.5
		for _, s in spikes do
			local angle = (s:GetAttribute("Angle") :: number) + spin
			s.CFrame = CFrame.new(top + Vector3.new(math.cos(angle) * 1.4, 0.55, math.sin(angle) * 1.4))
		end
		placeRing(band, top, 1.4, spin)
	end)
	local all = table.clone(spikes)
	for _, b in band do
		table.insert(all, b)
	end
	crowns[caster] = { Parts = all, Connection = connection }
	Effects.flash(Lib.rootPosition(caster) or Vector3.zero, palette, 2, true)
	task.delay(duration + 0.4, function()
		connection:Disconnect()
		fadeAll(all, 0.3)
		crowns[caster] = nil
	end)
end

-- Ponto de saida dos raios da coroa (ou a gema, se nao houver coroa).
function ZoneFx.crownTop(caster: Model): Vector3?
	local root = Lib.rootPosition(caster)
	return if root then root + UP * 4.6 else nil
end

return ZoneFx
