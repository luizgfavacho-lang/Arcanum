--!strict
-- Efeitos compostos (Docs/03 §8): clarao, onda de choque, circulo runico e assinatura de conjuracao.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Lib = require(script.Parent.Lib)

local Effects = {}

-- Clarao: nucleo branco de 1 quadro, aureola que expande, risco horizontal (reflexo de lente),
-- brilho grande, particulas da escola e (nos grandes) raios de luz girando.
function Effects.flash(position: Vector3, palette: Lib.Palette, scale: number, withRays: boolean?)
	local core =
		Lib.part(Vector3.one * scale, Color3.new(1, 1, 1), CFrame.new(position), { Shape = Enum.PartType.Ball })
	task.delay(1 / 30, function()
		core:Destroy()
	end)

	local halo = Lib.part(
		Vector3.one * scale * 1.3,
		palette.Halo,
		CFrame.new(position),
		{ Shape = Enum.PartType.Ball, Transparency = 0.25 }
	)
	Lib.fade(halo, 0.3, { Size = Vector3.one * scale * 3.2, Transparency = 1 })

	local camera = Workspace.CurrentCamera
	local streak = Lib.part(
		Vector3.new(scale * 6, 0.1 * scale, 0.1 * scale),
		palette.Core,
		CFrame.fromMatrix(position, camera.CFrame.RightVector, camera.CFrame.UpVector),
		{ Transparency = 0.1 }
	)
	Lib.fade(streak, 0.2, { Size = Vector3.new(scale * 10, 0.02, 0.02), Transparency = 1 })

	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = scale * 10
	light.Brightness = 5
	light.Parent = halo

	Lib.burst(position, "Glow", palette, 1, { Size = Lib.seq(scale * 4, 0) })
	Lib.burst(position, "Star", palette, math.floor(8 + scale * 5))

	if withRays then
		local center = CFrame.new(position) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, 0)
		for i = 1, 6 do
			local angle = i * math.pi / 3
			local ray = Lib.part(
				Vector3.new(0.15 * scale, 0.15 * scale, scale * 3),
				palette.Core,
				center * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -scale * 1.5),
				{ Transparency = 0.2 }
			)
			Lib.fade(ray, 0.35, {
				Size = Vector3.new(0.02, 0.02, scale * 5),
				Transparency = 1,
				CFrame = center * CFrame.Angles(0, angle + 0.6, 0) * CFrame.new(0, 0, -scale * 2.5),
			})
		end
	end
end

-- Onda de choque: anel no chao que expande, parede de luz que sobe da borda e estrelas no anel.
function Effects.shockwave(position: Vector3, palette: Lib.Palette, radius: number)
	local ground = position
	local segments = 24
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local startCf = CFrame.lookAt(ground + dir * 0.5, ground + dir * 0.5 + Vector3.new(-dir.Z, 0, dir.X))
		local endCf = CFrame.lookAt(ground + dir * radius, ground + dir * radius + Vector3.new(-dir.Z, 0, dir.X))
		local arc = 2 * math.pi * radius / segments

		local ring = Lib.part(Vector3.new(0.4, 0.15, 0.6), palette.Halo, startCf, { Transparency = 0.1 })
		Lib.fade(
			ring,
			0.4,
			{ CFrame = endCf, Size = Vector3.new(0.2, 0.1, arc * 1.05), Transparency = 1 },
			Enum.EasingStyle.Quint
		)

		local wall = Lib.part(Vector3.new(0.08, 0.2, 0.6), palette.Core, startCf, { Transparency = 0.4 })
		Lib.fade(wall, 0.5, {
			CFrame = endCf * CFrame.new(0, radius * 0.25, 0),
			Size = Vector3.new(0.04, radius * 0.5, arc),
			Transparency = 1,
		}, Enum.EasingStyle.Quint)
	end
	for _ = 1, 6 do
		local angle = math.random() * math.pi * 2
		Lib.burst(
			ground + Vector3.new(math.cos(angle), 0.3, math.sin(angle)) * radius * 0.8,
			"Star",
			palette,
			3,
			{ Speed = NumberRange.new(2, 5) }
		)
	end
end

-- Circulo runico no chao: duas camadas girando em sentidos opostos, marcas runicas, aro extra,
-- pilares de luz e nucleo pulsante. Dura `duration` e some.
function Effects.runeCircle(center: Vector3, palette: Lib.Palette, radius: number, duration: number)
	type Piece = { Part: BasePart, Radius: number, Angle: number, Speed: number, Tilt: CFrame }
	local pieces: { Piece } = {}

	local function ring(r: number, count: number, speed: number, color: Color3, thickness: number)
		for i = 1, count do
			local arc = 2 * math.pi * r / count
			local p =
				Lib.part(Vector3.new(thickness, 0.05, arc * 0.7), color, CFrame.new(center), { Transparency = 0.15 })
			table.insert(
				pieces,
				{ Part = p, Radius = r, Angle = (i / count) * math.pi * 2, Speed = speed, Tilt = CFrame.identity }
			)
		end
	end
	ring(radius, 28, 0.8, palette.Halo, 0.12)
	ring(radius * 0.72, 20, -1.3, palette.Core, 0.08)
	ring(radius * 1.12, 36, 0.4, palette.Accent, 0.05)

	-- Marcas runicas (losangos) entre os aneis.
	for i = 1, 8 do
		local p = Lib.part(Vector3.new(0.35, 0.05, 0.35), palette.Core, CFrame.new(center), { Transparency = 0.1 })
		table.insert(pieces, {
			Part = p,
			Radius = radius * 0.86,
			Angle = (i / 8) * math.pi * 2,
			Speed = -0.5,
			Tilt = CFrame.Angles(0, math.rad(45), 0),
		})
	end

	local core = Lib.part(
		Vector3.new(0.05, radius * 0.5, radius * 0.5),
		palette.Halo,
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		{
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.6,
		}
	)

	-- Pilares de luz
	for i = 1, 4 do
		local angle = i * math.pi / 2 + math.pi / 4
		local base = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		local pillar = Lib.part(Vector3.new(0.2, 0.1, 0.2), palette.Halo, CFrame.new(base), { Transparency = 0.3 })
		Lib.fade(pillar, duration, {
			Size = Vector3.new(0.05, radius * 2, 0.05),
			CFrame = CFrame.new(base + Vector3.new(0, radius, 0)),
			Transparency = 1,
		})
	end

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local alpha = t / duration
		if alpha >= 1 then
			connection:Disconnect()
			for _, piece in pieces do
				piece.Part:Destroy()
			end
			core:Destroy()
			return
		end
		local grow = math.min(t / 0.12, 1) -- abre rapido
		local fadeOut = if alpha > 0.6 then (alpha - 0.6) / 0.4 else 0
		for _, piece in pieces do
			local angle = piece.Angle + piece.Speed * t
			local r = piece.Radius * grow
			piece.Part.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(r, 0, 0) * piece.Tilt
			piece.Part.Transparency = 0.15 + 0.85 * fadeOut
		end
		local pulse = 0.5 + 0.5 * math.sin(t * 18)
		core.Size = Vector3.new(0.05, radius * (0.4 + 0.15 * pulse) * grow, radius * (0.4 + 0.15 * pulse) * grow)
		core.Transparency = 0.5 + 0.5 * fadeOut
	end)
end

-- Zona de perigo (telegrafia de ataque inimigo): aro no chao + disco que enche do centro para a
-- borda durante `duration`. Quando o disco encosta no aro, o golpe acontece.
-- Retorna uma funcao que cancela o aviso (golpe interrompido).
function Effects.dangerZone(center: Vector3, radius: number, duration: number, color: Color3): () -> ()
	local flat = CFrame.new(center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local segments = 32
	local parts: { BasePart } = {}
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local arc = 2 * math.pi * radius / segments
		local pos = center + Vector3.new(math.cos(angle) * radius, 0.1, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		table.insert(
			parts,
			Lib.part(
				Vector3.new(0.25, 0.12, arc * 1.05),
				color,
				CFrame.lookAt(pos, pos + tangent),
				{ Transparency = 0.05 }
			)
		)
	end
	table.insert(
		parts,
		Lib.part(Vector3.new(0.06, radius * 2, radius * 2), color, flat, {
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.82,
			Material = Enum.Material.SmoothPlastic,
		})
	)
	local fill =
		Lib.part(Vector3.new(0.07, 0.2, 0.2), color, flat, { Shape = Enum.PartType.Cylinder, Transparency = 0.55 })
	table.insert(parts, fill)
	Lib.tween(fill, duration, { Size = Vector3.new(0.07, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)

	local done = false
	local function finish(fast: boolean)
		if done then
			return
		end
		done = true
		for _, p in parts do
			Lib.fade(p, if fast then 0.12 else 0.2, { Transparency = 1 })
		end
	end
	task.delay(duration, finish, false)
	return function()
		finish(true)
	end
end

-- Faixa de perigo no chao (linha de cristais do chefe): contorno + faixa que enche de `from` a `to`.
function Effects.dangerLine(from: Vector3, to: Vector3, width: number, duration: number, color: Color3): () -> ()
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = math.max(delta.Magnitude, 0.5)
	local direction = delta.Unit
	local ground = Vector3.new(0, 0.1, 0)
	local mid = from + direction * length / 2 + ground
	local frame = CFrame.lookAt(mid, mid + direction)
	local side = direction:Cross(Vector3.yAxis)
	local parts: { BasePart } = {}
	table.insert(
		parts,
		Lib.part(
			Vector3.new(width, 0.06, length),
			color,
			frame,
			{ Transparency = 0.82, Material = Enum.Material.SmoothPlastic }
		)
	)
	for _, s in { -1, 1 } do
		table.insert(
			parts,
			Lib.part(Vector3.new(0.22, 0.12, length), color, frame + side * s * width / 2, { Transparency = 0.05 })
		)
	end
	local startCenter = from + direction * 0.1 + ground
	local fill = Lib.part(
		Vector3.new(width, 0.08, 0.2),
		color,
		CFrame.lookAt(startCenter, startCenter + direction),
		{ Transparency = 0.5 }
	)
	table.insert(parts, fill)
	Lib.tween(fill, duration, { Size = Vector3.new(width, 0.08, length), CFrame = frame }, Enum.EasingStyle.Linear)

	local done = false
	local function finish(fast: boolean)
		if done then
			return
		end
		done = true
		for _, p in parts do
			Lib.fade(p, if fast then 0.12 else 0.2, { Transparency = 1 })
		end
	end
	task.delay(duration, finish, false)
	return function()
		finish(true)
	end
end

-- Cristais que rompem o chao em sequencia ao longo da linha.
function Effects.crystalSpikes(from: Vector3, to: Vector3, width: number, palette: Lib.Palette)
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local direction = delta.Unit
	local side = direction:Cross(Vector3.yAxis)
	local count = math.max(math.floor(length / 2.2), 2)
	for i = 1, count do
		task.delay(i * 0.025, function()
			local base = from + direction * (i - 0.5) * (length / count) + side * (math.random() - 0.5) * width * 0.6
			local height = 2.5 + math.random() * 2.5
			local tilt =
				CFrame.Angles(math.rad(math.random(-18, 18)), math.random() * math.pi, math.rad(math.random(-18, 18)))
			local final = CFrame.new(base + Vector3.new(0, height * 0.35, 0)) * tilt
			local crystal = Lib.part(
				Vector3.new(0.9, height, 0.9),
				palette.Halo:Lerp(Color3.new(1, 1, 1), 0.25),
				final - Vector3.new(0, height, 0),
				{ Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.2 }
			)
			local core = Lib.part(Vector3.new(0.4, height * 0.8, 0.4), palette.Halo, final - Vector3.new(0, height, 0))
			Lib.tween(crystal, 0.08, { CFrame = final }, Enum.EasingStyle.Back)
			Lib.tween(core, 0.08, { CFrame = final }, Enum.EasingStyle.Back)
			Lib.burst(base + Vector3.new(0, 0.3, 0), "Spark", palette, 5)
			task.delay(0.7, function()
				Lib.fade(crystal, 0.35, { Transparency = 1, CFrame = final - Vector3.new(0, height * 0.6, 0) })
				Lib.fade(core, 0.35, { Transparency = 1, CFrame = final - Vector3.new(0, height * 0.6, 0) })
			end)
		end)
	end
end

-- Imagem residual (esquiva): copia translucida do corpo que fica para tras e some.
function Effects.afterimage(model: Model, color: Color3)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			local ok, ghost = pcall(function()
				return part:Clone()
			end)
			if ok and ghost then
				ghost:ClearAllChildren()
				ghost.Anchored = true
				ghost.CanCollide = false
				ghost.CanQuery = false
				ghost.CanTouch = false
				ghost.CastShadow = false
				ghost.Material = Enum.Material.ForceField
				ghost.Color = color
				ghost.Transparency = 0.15
				ghost.CFrame = part.CFrame
				ghost.Parent = Lib.folder()
				Lib.fade(ghost, 0.4, { Transparency = 1 })
			end
		end
	end
end

-- Estrelas girando sobre a cabeca (atordoado).
function Effects.stunStars(model: Model, palette: Lib.Palette, duration: number)
	local head = (model:FindFirstChild("Head") or model:FindFirstChild("Body")) :: BasePart?
	if not head then
		return
	end
	local stars: { BasePart } = {}
	for _ = 1, 3 do
		table.insert(
			stars,
			Lib.part(Vector3.one * 0.35, palette.Core:Lerp(Color3.fromRGB(255, 220, 90), 0.6), head.CFrame, {
				Shape = Enum.PartType.Ball,
			})
		)
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= duration or not head.Parent then
			connection:Disconnect()
			for _, star in stars do
				star:Destroy()
			end
			return
		end
		local top = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.9, 0)
		for i, star in stars do
			local angle = t * 6 + i * math.pi * 2 / 3
			star.CFrame =
				CFrame.new(top + Vector3.new(math.cos(angle) * 1.1, math.sin(t * 9 + i) * 0.15, math.sin(angle) * 1.1))
		end
	end)
end

-- Assinatura de conjuracao: circulo runico aos pes + runas subindo em volta do mago.
function Effects.castSignature(caster: Model, palette: Lib.Palette, tier: number)
	local root = Lib.rootPosition(caster)
	if not root then
		return
	end
	local feet = Lib.groundBelow(root, caster) + Vector3.new(0, 0.1, 0)
	Effects.runeCircle(feet, palette, 2.2 + tier * 0.5, 0.45 + tier * 0.1)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		Lib.burst(feet + Vector3.new(math.cos(angle) * 1.8, 0.3, math.sin(angle) * 1.8), "Wisp", palette, 2)
	end
end

return Effects
