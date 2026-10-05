--!strict
-- Corrente de vida (Drenar Vida): fita ondulante do alvo ate a gema, com contas de luz correndo
-- de A para B, fiapos saindo do alvo e brilho de cura no conjurador.

local RunService = game:GetService("RunService")

local Lib = require(script.Parent.Lib)

local LifeStream = {}

local DURATION = 0.55

local function bezier(a: Vector3, control: Vector3, b: Vector3, t: number): Vector3
	return a:Lerp(control, t):Lerp(control:Lerp(b, t), t)
end

function LifeStream.play(targetPos: Vector3, caster: Model, palette: Lib.Palette)
	local from = targetPos
	local to = Lib.muzzleOf(caster, Lib.rootPosition(caster) or targetPos)
	local lift = Vector3.new(0, (to - from).Magnitude * 0.25, 0)
	local control = (from + to) / 2 + lift

	-- Fitas: duas beams com curvas opostas, textura correndo em direcao ao mago.
	local a0 = Lib.anchor(from, DURATION + 0.1)
	local a1 = Lib.anchor(to, DURATION + 0.1)
	for i = 1, 2 do
		local beam = Lib.beam(a0, a1, {
			Color = ColorSequence.new(palette.Halo, palette.Core),
			Width0 = 0.9,
			Width1 = 0.35,
			CurveSize0 = (i == 1 and 1 or -1) * 3,
			CurveSize1 = (i == 1 and -1 or 1) * 2,
			Texture = Lib.Textures.Sparkle,
			TextureMode = Enum.TextureMode.Wrap,
			TextureLength = 1.5,
			TextureSpeed = -4,
			Transparency = NumberSequence.new(0.25),
		})
		Lib.fade(beam, DURATION, { Width0 = 0, Width1 = 0 })
	end

	-- Contas de luz percorrendo a curva.
	local beads = {}
	for i = 1, 7 do
		beads[i] = Lib.part(Vector3.one * 0.45, palette.Core, CFrame.new(from), { Shape = Enum.PartType.Ball })
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / DURATION
		if t >= 1 then
			connection:Disconnect()
			for _, bead in beads do
				bead:Destroy()
			end
			return
		end
		for i, bead in beads do
			local u = math.clamp(t * 1.6 - (i - 1) * 0.09, 0, 1)
			bead.CFrame = CFrame.new(bezier(from, control, to, u))
			bead.Transparency = if u <= 0 or u >= 1 then 1 else 0.1
		end
	end)

	Lib.burst(from, "Wisp", palette, 10, { Speed = NumberRange.new(2, 5) })
	task.delay(DURATION * 0.6, function()
		Lib.burst(to, "Star", palette, 10, { Speed = NumberRange.new(2, 6) })
	end)
end

return LifeStream
