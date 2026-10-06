--!strict
-- Efeitos das mecanicas proprias de cada magia (as "assinaturas" inspiradas em LoL/DotA), so visual:
-- ramificacao da Faisca, onda de choque do Raio Invocado, pulso do Campo Estatico, resquicio do
-- Passo Relampago, Combustao, projeteis incinerados pela Muralha, rolagem do Meteoro, impacto no
-- Escudo de Mana, execucao do Toque Mortal, praga da Maldicao, pancada do Bruto, ponta da Lamina de
-- Sangue e o miolo do Veredito. Texto curto flutuando no mundo para cada um.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)
local Effects = require(script.Parent.Effects)
local Lightning = require(script.Parent.Lightning)
local Audio = require(script.Parent.Audio)

local SignatureFx = {}

local UP = Vector3.yAxis

-- Texto curto que sobe e some num ponto do mundo (ex.: "COMBUSTAO!").
function SignatureFx.floatText(position: Vector3, text: string, color: Color3, size: number?)
	local anchor = Lib.anchor(position + UP * 2.5, 1.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.TextStrokeColor3 = Color3.fromRGB(20, 10, 20)
	label.Text = text
	local base = size or 26
	label.TextSize = base * 1.6
	label.Parent = gui
	gui.Parent = anchor
	TweenService:Create(label, TweenInfo.new(0.14, Enum.EasingStyle.Back), { TextSize = base }):Play()
	TweenService:Create(gui, TweenInfo.new(1, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = UP * 3 }):Play()
	task.delay(0.55, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

---------------------------------------------------------------------------------------------------
-- Eletricidade

-- Faisca ramificando (Arc Lightning): raios saltando de alvo em alvo.
function SignatureFx.forks(from: Vector3, points: { Vector3 }, palette: Lib.Palette)
	local last = from
	for i, point in points do
		local origin = last
		task.delay((i - 1) * 0.05, function()
			Lightning.bolt(origin, point, palette, { Width = 0.15, Forks = 1, Flickers = 2, Duration = 0.16 })
			Lib.burst(point, "Zap", palette, 1, { Size = Lib.seq(2, 4) })
			Lib.burst(point, "Arc", palette, 3)
			Audio.play("OrbShock", point, 0.6)
		end)
		last = point
	end
end

-- Onda de choque do Raio Invocado: anel eletrico correndo pelo chao com arcos na borda.
function SignatureFx.aftershock(position: Vector3, radius: number, palette: Lib.Palette)
	Effects.shockwave(position + UP * 0.2, palette, radius)
	local seal = Lib.groundDecal(position, radius * 2.2, Lib.Catalog.CircleRunes, palette.Halo, { Brightness = 2 })
	seal.Image.Size = UDim2.fromScale(0.3, 0.3)
	Lib.tween(seal.Image, 0.35, { Size = UDim2.fromScale(1, 1), ImageTransparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(seal.Part, 0.4)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local edge = position + Vector3.new(math.cos(angle), 0.4, math.sin(angle)) * radius
		task.delay(0.05 + math.random() * 0.12, function()
			Lightning.bolt(
				position + UP * 0.5,
				edge,
				palette,
				{ Width = 0.08, Forks = 1, Flickers = 1, Duration = 0.1, Glow = false }
			)
			Lib.burst(edge, "Arc", palette, 2)
		end)
	end
	Audio.play("StaticField", position)
end

-- Pulso do Campo Estatico (Plasma Field): anel que sai do mago ate a borda, onde estala mais forte.
function SignatureFx.staticPulse(caster: Model, radius: number, palette: Lib.Palette)
	local root = Lib.rootPosition(caster)
	if not root then
		return
	end
	local ground = Lib.groundBelow(root, caster)
	local ring = Lib.groundDecal(ground, radius * 2.1, Lib.Catalog.Ring, palette.Halo, { Brightness = 2.2 })
	ring.Image.Size = UDim2.fromScale(0.15, 0.15)
	Lib.tween(ring.Image, 0.4, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad)
	Lib.tween(ring.Image, 0.4, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(ring.Part, 0.45)
	task.delay(0.3, function()
		for _ = 1, 5 do
			local angle = math.random() * math.pi * 2
			Lib.burst(ground + Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius), "Arc", palette, 2, {
				Size = Lib.seq(2, 3),
			})
		end
	end)
end

-- Resquicio do Passo Relampago (Static Remnant): uma silhueta de raios que treme e explode.
function SignatureFx.remnant(position: Vector3, delay: number, palette: Lib.Palette)
	local base = Lib.groundBelow(position)
	local body = Lib.part(Vector3.new(1.6, 5, 1.6), palette.Halo, CFrame.new(base + UP * 2.6), {
		Material = Enum.Material.ForceField,
		Transparency = 0.1,
	})
	local core = Lib.part(Vector3.new(0.5, 4.2, 0.5), palette.Core, CFrame.new(base + UP * 2.6), {
		Transparency = 0.35,
	})
	local anchor = Lib.anchor(base + UP * 2.5, delay + 0.5)
	local crackle = Lib.emitter(anchor, "Arc", palette, { Rate = 26, Size = Lib.seq(1.6, 2.4) })
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= delay or not body.Parent then
			connection:Disconnect()
			crackle.Enabled = false
			body:Destroy()
			core:Destroy()
			return
		end
		local shake = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.25
		body.CFrame = CFrame.new(base + UP * 2.6 + shake)
		core.Transparency = 0.2 + 0.3 * math.random()
	end)
end

function SignatureFx.remnantBurst(position: Vector3, radius: number, palette: Lib.Palette)
	Effects.flash(position + UP * 2, palette, 2.4, true)
	Effects.shockwave(Lib.groundBelow(position) + UP * 0.2, palette, radius)
	Lib.burst(position + UP * 2, "Zap", palette, 2, { Size = Lib.seq(4, 9) })
	Audio.play("OrbShock", position)
end

---------------------------------------------------------------------------------------------------
-- Fogo

-- Combustao (Nova em quem ja queimava): labareda alta e texto.
function SignatureFx.combustion(positions: { Vector3 }, palette: Lib.Palette)
	for _, position in positions do
		Lib.burst(position, "Blaze", palette, 3, {
			Size = Lib.seq(3, 5),
			Speed = NumberRange.new(3, 8),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(20, 20),
		})
		Lib.burst(position, "Ember", palette, 14, { Speed = NumberRange.new(8, 16) })
		SignatureFx.floatText(position, "COMBUSTAO!", Color3.fromRGB(255, 150, 50), 22)
	end
	if positions[1] then
		Audio.play("EmberArmor", positions[1])
	end
end

-- Projeteis incinerados pela Muralha de Chamas.
function SignatureFx.wallBurn(positions: { Vector3 }, palette: Lib.Palette)
	for _, position in positions do
		Lib.burst(position, "Flame", palette, 4, { Speed = NumberRange.new(2, 5) })
		Lib.burst(position, "Smoke", palette, 4, { Size = Lib.seq(0.8, 2.5) })
		Lib.burst(position, "Ember", palette, 8)
	end
	if positions[1] then
		Audio.play("LavaSear", positions[1])
	end
end

-- Meteoro rolando (Chaos Meteor): rocha em brasa girando ate o fim, deixando fogo no caminho.
function SignatureFx.meteorRoll(from: Vector3, to: Vector3, duration: number, radius: number, palette: Lib.Palette)
	local size = math.max(radius * 1.3, 3)
	local rock = Lib.part(Vector3.one * size, Color3.fromRGB(52, 30, 24), CFrame.new(from + UP * size / 2), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Basalt,
	})
	local magma = Lib.part(Vector3.one * size * 0.82, Color3.fromRGB(255, 110, 25), rock.CFrame, {
		Shape = Enum.PartType.Ball,
		Transparency = 0.15,
	})
	local attachment = Instance.new("Attachment")
	attachment.Parent = rock
	Lib.emitter(attachment, "Flame", palette, { Rate = 50, Size = Lib.seq(size * 0.7, size, 0.4) })
	Lib.emitter(attachment, "Blaze", palette, { Rate = 10, Size = Lib.seq(size * 0.8, size * 1.2) })
	Lib.emitter(attachment, "Smoke", palette, { Rate = 12, Size = Lib.seq(size * 0.6, size * 1.8) })
	Lib.emitter(attachment, "Ember", palette, { Rate = 30, Speed = NumberRange.new(4, 10) })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 18
	light.Brightness = 2.5
	light.Parent = rock
	local direction = (to - from) * Vector3.new(1, 0, 1)
	local axis = if direction.Magnitude > 0.01 then direction.Unit:Cross(UP) else Vector3.xAxis
	local spin = (to - from).Magnitude / (size * 0.5) -- rolar sem deslizar
	local started = os.clock()
	local nextScorch = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - started) / duration, 1)
		local position = from:Lerp(to, t) + UP * size / 2
		local roll = CFrame.fromAxisAngle(axis, -spin * t)
		rock.CFrame = CFrame.new(position) * roll
		magma.CFrame = rock.CFrame
		if os.clock() >= nextScorch then
			nextScorch = os.clock() + 0.25
			local ground = from:Lerp(to, t)
			local mark = Lib.groundDecal(ground, size * 1.4, Lib.Catalog.SoftRing, Color3.fromRGB(255, 90, 20), {
				Brightness = 1.4,
				Transparency = 0.2,
				Lift = 0.2,
			})
			Lib.tween(mark.Image, 1.6, { ImageTransparency = 1, ImageColor3 = Color3.fromRGB(60, 20, 10) })
			Debris:AddItem(mark.Part, 1.7)
			Lib.burst(ground + UP, "Spark", palette, 4)
		end
		if t >= 1 then
			connection:Disconnect()
			Effects.flash(position, palette, 2.4, true)
			Lib.burst(position, "Blaze", palette, 5, { Size = Lib.seq(3, 5), Speed = NumberRange.new(4, 10) })
			Lib.burst(position, "Smoke", palette, 10, { Size = Lib.seq(2, 7) })
			Lib.fade(rock, 0.3, { Transparency = 1, Size = Vector3.one * size * 0.5 })
			Lib.fade(magma, 0.3, { Transparency = 1 })
			Audio.play("MeteorImpact", position, 0.6)
		end
	end)
	Audio.play("LavaRumble", from)
end

---------------------------------------------------------------------------------------------------
-- Energia

-- Escudo de Mana segurando um golpe: bolha hexagonal acende e ondula.
function SignatureFx.shieldHit(target: Model, amount: number)
	local root = Lib.rootPosition(target)
	if not root then
		return
	end
	local palette = Lib.palette("Energy")
	local size = 7 + math.min(amount, 10) * 0.15
	local bubble = Lib.part(Vector3.one * size, palette.Halo, CFrame.new(root), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
		Transparency = 0,
	})
	Lib.fade(bubble, 0.35, { Transparency = 1, Size = Vector3.one * size * 1.08 })
	Lib.burst(root, "Star", palette, 6, { Speed = NumberRange.new(6, 10), Brightness = 2 })
	Audio.play("ManaShield", root, 0.5)
end

-- Miolo do Veredito: circulo solar menor que aponta onde fica o atordoamento.
function SignatureFx.verdictCore(position: Vector3, radius: number, duration: number, palette: Lib.Palette)
	local core = Lib.groundDecal(position, radius * 0.9, Lib.Catalog.CircleOrnate, palette.Accent, {
		Brightness = 2.2,
		Transparency = 0.6,
	})
	Lib.tween(core.Image, duration, { ImageTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Lib.tween(
		core.Part,
		duration,
		{ CFrame = core.Part.CFrame * CFrame.Angles(0, -math.pi, 0) },
		Enum.EasingStyle.Linear
	)
	task.delay(duration, function()
		Lib.tween(core.Image, 0.4, { ImageTransparency = 1 })
		Debris:AddItem(core.Part, 0.45)
	end)
end

---------------------------------------------------------------------------------------------------
-- Necromancia

-- Execucao (Reaper's Scythe): foice espectral corta o alvo, pilar de almas e texto.
function SignatureFx.execute(target: Model, palette: Lib.Palette)
	local root = Lib.rootPosition(target)
	if not root then
		return
	end
	local blade = Lib.part(Vector3.new(0.3, 1.2, 9), palette.Halo, CFrame.new(root + Vector3.new(3, 4, 0)), {
		Transparency = 0.1,
	})
	local edge = Lib.part(Vector3.new(0.12, 0.4, 9), palette.Core, blade.CFrame, { Transparency = 0 })
	local swing = CFrame.new(root) * CFrame.Angles(0, 0, math.rad(-60)) * CFrame.new(0, 0, 0)
	Lib.fade(blade, 0.22, { CFrame = swing, Transparency = 1 }, Enum.EasingStyle.Quint)
	Lib.fade(edge, 0.22, { CFrame = swing, Transparency = 1 }, Enum.EasingStyle.Quint)
	task.delay(0.12, function()
		Effects.flash(root, palette, 3, true)
		local pillar = Lib.part(Vector3.new(2.5, 0.5, 2.5), palette.Halo, CFrame.new(root), {
			Transparency = 0.2,
			Shape = Enum.PartType.Cylinder,
		})
		pillar.CFrame = CFrame.new(root + UP * 6) * CFrame.Angles(0, 0, math.rad(90))
		Lib.fade(pillar, 0.6, { Size = Vector3.new(18, 0.2, 0.2), Transparency = 1 })
		Lib.burst(root, "Wisp", palette, 24, { Speed = NumberRange.new(6, 14) })
		SignatureFx.floatText(root, "EXECUTADO!", Color3.fromRGB(120, 255, 170), 30)
	end)
	Audio.play("DeathTouch", root)
end

-- Praga da Maldicao passando do morto para os vizinhos.
function SignatureFx.curseSpread(from: Vector3, points: { Vector3 }, palette: Lib.Palette)
	Lib.burst(from, "Smoke", palette, 10, {
		Color = ColorSequence.new(Color3.fromRGB(80, 160, 70), Color3.fromRGB(30, 50, 25)),
		Size = Lib.seq(1.5, 5),
		Transparency = Lib.seq(0.4, 1),
	})
	for _, point in points do
		local orb = Lib.part(Vector3.one * 0.5, palette.Halo, CFrame.new(from), { Shape = Enum.PartType.Ball })
		local mid = (from + point) / 2 + UP * 3
		local started = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - started) / 0.45, 1)
			orb.CFrame = CFrame.new(from:Lerp(mid, t):Lerp(mid:Lerp(point, t), t))
			if t >= 1 then
				connection:Disconnect()
				orb:Destroy()
				Lib.burst(point, "Wisp", palette, 8)
			end
		end)
	end
	if #points > 0 then
		SignatureFx.floatText(from, "PRAGA!", Color3.fromRGB(140, 255, 120), 22)
		Audio.play("Curse", from, 0.7)
	end
end

-- Bruto rompendo o chao: anel de terra, pedras voando e poeira.
function SignatureFx.bruteSlam(position: Vector3, radius: number, palette: Lib.Palette)
	Effects.shockwave(position + UP * 0.2, palette, radius * 1.2)
	Lib.burst(position + UP, "Smoke", palette, 14, {
		Color = ColorSequence.new(Color3.fromRGB(110, 96, 80), Color3.fromRGB(60, 52, 46)),
		Size = Lib.seq(2, 7),
		Speed = NumberRange.new(6, 14),
		Transparency = Lib.seq(0.3, 1),
	})
	for _ = 1, 8 do
		local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.xAxis
		local chunk =
			Lib.part(Vector3.one * (0.5 + math.random() * 0.7), Color3.fromRGB(70, 60, 52), CFrame.new(position + UP), {
				Material = Enum.Material.Slate,
			})
		local landing = position + dir * radius * (0.6 + math.random() * 0.6)
		TweenService:Create(chunk, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			CFrame = CFrame.new(landing + UP * 0.3) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
		}):Play()
		task.delay(1.5, function()
			Lib.fade(chunk, 0.4, { Transparency = 1 })
		end)
	end
	Audio.play("Slam", position, 0.7)
end

---------------------------------------------------------------------------------------------------
-- Sangue

-- Ponta da Lamina de Sangue: corte crescente carmesim e texto.
function SignatureFx.sweetSpot(positions: { Vector3 }, palette: Lib.Palette)
	for _, position in positions do
		local slash = Lib.part(
			Vector3.new(0.2, 0.25, 5),
			palette.Halo,
			CFrame.new(position) * CFrame.Angles(0, math.random() * 6, math.rad(25)),
			{
				Transparency = 0.05,
			}
		)
		Lib.fade(slash, 0.25, { Size = Vector3.new(0.05, 0.05, 8), Transparency = 1 })
		Lib.burst(position, "Spark", palette, 10, { Color = ColorSequence.new(palette.Halo), Brightness = 2 })
		SignatureFx.floatText(position, "PONTA!", Color3.fromRGB(255, 90, 100), 22)
	end
end

return SignatureFx
