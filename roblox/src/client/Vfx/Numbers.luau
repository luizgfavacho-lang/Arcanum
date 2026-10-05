--!strict
-- Numeros de dano/cura. Golpes grandes aparecem na hora; ticks pequenos (DoT, canalizacao)
-- sao somados por alvo a cada 0,35 s para nao poluir a tela.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)

local Numbers = {}

local FLUSH_INTERVAL = 0.35

type Pending = { Amount: number, Color: Color3, Small: boolean }
local pending: { [Model]: Pending } = {}

local function show(target: Model, text: string, color: Color3, amount: number, small: boolean)
	-- Criaturas sem cabeca (gosmas, bulbo) usam o corpo.
	local head = (target:FindFirstChild("Head") or target:FindFirstChild("Body")) :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffsetWorldSpace = Vector3.new((math.random() - 0.5) * 3, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = Color3.fromRGB(20, 10, 30)
	label.Text = text
	local base = if small then 16 else math.clamp(20 + amount * 1.5, 20, 40)
	label.TextSize = base * 1.5 -- "pop" inicial
	label.Parent = gui
	gui.Parent = Lib.folder()

	TweenService:Create(label, TweenInfo.new(0.12, Enum.EasingStyle.Back), { TextSize = base }):Play()
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
		StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 3.5, 0),
	}):Play()
	task.delay(0.45, function()
		TweenService:Create(label, TweenInfo.new(0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(gui, 1)
end

function Numbers.damage(target: Model, amount: number, palette: Lib.Palette, periodic: boolean)
	if periodic or amount < 1.5 then
		local entry = pending[target]
		if entry then
			entry.Amount += amount
		else
			pending[target] =
				{ Amount = amount, Color = if periodic then palette.Accent else palette.Core, Small = periodic }
		end
		return
	end
	show(target, string.format("%.1f", amount), Color3.new(1, 1, 1):Lerp(palette.Halo, 0.25), amount, false)
end

-- Texto de destaque sobre o alvo (ex.: "INTERROMPIDO!").
function Numbers.label(target: Model, text: string, color: Color3)
	show(target, text, color, 6, false)
end

function Numbers.heal(target: Model, amount: number)
	show(target, string.format("+%.1f", amount), Color3.fromRGB(110, 255, 150), amount, true)
end

function Numbers.start()
	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			for target, entry in pending do
				if target.Parent and entry.Amount >= 0.05 then
					show(target, string.format("%.1f", entry.Amount), entry.Color, entry.Amount, entry.Small)
				end
			end
			table.clear(pending)
		end
	end)
end

return Numbers
