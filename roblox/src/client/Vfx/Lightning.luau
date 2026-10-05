--!strict
-- Raios: forma ramificada regenerada a cada poucos quadros (tremulacao), nucleo branco + brilho
-- da escola, galhos laterais. `braid` desenha os 6-8 fios trancados da Corrente em Cadeia.

local Debris = game:GetService("Debris")

local Lib = require(script.Parent.Lib)

local Lightning = {}

local function path(from: Vector3, to: Vector3, jitter: number, step: number): { Vector3 }
	local points = { from }
	local delta = to - from
	local distance = delta.Magnitude
	if distance < 1e-3 then
		return { from, to }
	end
	local dir = delta.Unit
	local right = dir:Cross(Vector3.yAxis)
	right = if right.Magnitude < 1e-3 then Vector3.xAxis else right.Unit
	local up = right:Cross(dir).Unit
	local steps = math.max(2, math.ceil(distance / step))
	for i = 1, steps - 1 do
		local t = i / steps
		local envelope = math.sin(t * math.pi) -- mais solto no meio, preso nas pontas
		local offset = (right * (math.random() * 2 - 1) + up * (math.random() * 2 - 1)) * jitter * envelope
		table.insert(points, from:Lerp(to, t) + offset)
	end
	table.insert(points, to)
	return points
end

local function polyline(points: { Vector3 }, width: number, color: Color3, transparency: number, lifetime: number)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		if length > 1e-3 then
			-- Afina em direcao a ponta.
			local w = width * (1 - 0.5 * (i / #points))
			local p = Lib.part(
				Vector3.new(w, w, length + w),
				color,
				CFrame.lookAt((a + b) / 2, b),
				{ Transparency = transparency }
			)
			Debris:AddItem(p, lifetime)
		end
	end
end

export type BoltOptions = {
	Width: number?,
	Forks: number?,
	Flickers: number?,
	Duration: number?,
	Glow: boolean?, -- camada larga translucida (desligada quando Beams ja fazem o brilho)
}

-- Raio ramificado com tremulacao.
function Lightning.bolt(from: Vector3, to: Vector3, palette: Lib.Palette, options: BoltOptions?)
	local width = options and options.Width or 0.18
	local forks = options and options.Forks or 2
	local flickers = options and options.Flickers or 3
	local duration = options and options.Duration or 0.18
	local glow = not (options and options.Glow == false)
	local distance = (to - from).Magnitude
	local jitter = math.clamp(distance * 0.07, 0.4, 2.2)
	local frame = duration / flickers
	-- No maximo ~14 segmentos por raio (custo constante, mesmo em raios longos).
	local step = math.max(2.5, distance / 14)

	for k = 0, flickers - 1 do
		task.delay(k * frame, function()
			local life = frame + 0.02
			local main = path(from, to, jitter, step)
			polyline(main, width, palette.Core, 0, life)
			if glow then
				polyline(main, width * 3.2, palette.Halo, 0.55, life)
			end
			for _ = 1, forks do
				local origin = main[math.random(2, math.max(2, #main - 1))]
				local dir = ((to - from).Unit + Vector3.new(
					math.random() - 0.5,
					math.random() - 0.5,
					math.random() - 0.5
				) * 1.6).Unit
				local branch = path(origin, origin + dir * distance * (0.15 + math.random() * 0.2), jitter * 0.6, step)
				polyline(branch, width * 0.6, palette.Core, 0.1, life)
				if glow then
					polyline(branch, width * 2, palette.Halo, 0.7, life)
				end
			end
		end)
	end
end

-- Fios trancados (Beams curvos animados) + um raio nucleo. Usado a cada tick de canalizacao.
function Lightning.braid(from: Vector3, to: Vector3, palette: Lib.Palette, strands: number, lifetime: number)
	local distance = (to - from).Magnitude
	local a0 = Lib.anchor(from, lifetime + 0.05)
	local a1 = Lib.anchor(to, lifetime + 0.05)
	for i = 1, strands do
		local curve = distance * 0.18 * (math.random() * 2 - 1)
		Lib.beam(a0, a1, {
			Color = ColorSequence.new(if i % 2 == 0 then palette.Core else palette.Halo),
			Width0 = 0.15 + math.random() * 0.25,
			Width1 = 0.1 + math.random() * 0.2,
			CurveSize0 = curve,
			CurveSize1 = -curve * (0.5 + math.random()),
			Texture = Lib.Textures.Sparkle,
			TextureMode = Enum.TextureMode.Wrap,
			TextureLength = 2,
			TextureSpeed = 6,
			Transparency = NumberSequence.new(0.15 + math.random() * 0.3),
		})
	end
	Lightning.bolt(from, to, palette, { Width = 0.14, Forks = 1, Flickers = 1, Duration = lifetime, Glow = false })
end

return Lightning
