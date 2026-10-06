--!strict
-- Soma uma rotacao/deslocamento ao Transform animado de um Motor6D sem acumular entre quadros:
-- se o Animator nao reescreveu o motor desde o ultimo quadro, parte da mesma base de antes.
-- Usado no RunService.Stepped (depois das animacoes) por Vfx/Creatures e Vfx/DodgeAnim.

type Overlay = { Written: CFrame, Base: CFrame }

local MotorOverlay = {}

local overlays: { [Motor6D]: Overlay } = setmetatable({}, { __mode = "k" }) :: any

function MotorOverlay.apply(motor: Motor6D, extra: CFrame)
	local previous = overlays[motor]
	local current = motor.Transform
	local base = if previous and current == previous.Written then previous.Base else current
	local written = extra * base
	motor.Transform = written
	overlays[motor] = { Written = written, Base = base }
end

return MotorOverlay
