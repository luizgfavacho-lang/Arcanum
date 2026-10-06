--!strict
-- Essencias no chao (como os bolts de Ratchet & Clank), so visual:
--   * a criatura cai e o monte EXPLODE em pecas douradas que saltam, quicam no chao e assentam;
--   * paradas, giram e piscam (brilho de moeda);
--   * quando o servidor entrega o monte a alguem (EssenceCollect), as pecas sao sugadas uma a uma
--     ate o jogador, acelerando, com um tilintar cada;
--   * ninguem pegou a tempo: somem devagar.
-- O valor real ja foi creditado no servidor; aqui so o espetaculo.

local RunService = game:GetService("RunService")

local Lib = require(script.Parent.Lib)
local Audio = require(script.Parent.Audio)

local Essence = {}

local GOLD = Color3.fromRGB(255, 206, 64)
local GOLD_CORE = Color3.fromRGB(255, 244, 190)
local GRAVITY = 95
local BOUNCE = 0.42
local PIECE_SIZE = 0.75

type Piece = {
	Part: BasePart,
	Position: Vector3,
	Velocity: Vector3,
	Spin: Vector3,
	Angle: Vector3,
	Resting: boolean,
	Delay: number, -- espera antes de ser sugada (uma a uma)
	Collected: boolean,
}

type Drop = {
	Id: string,
	Ground: number,
	Pieces: { Piece },
	Anchor: Attachment,
	Light: PointLight,
	Target: Model?,
	CollectStart: number,
	Expiring: number?,
}

local drops: { [string]: Drop } = {}
local connection: RBXScriptConnection? = nil

local function newPiece(position: Vector3): BasePart
	-- Porca sextavada estilizada: cilindro dourado curto que gira (le como "bolt" de longe).
	return Lib.part(Vector3.new(PIECE_SIZE * 0.45, PIECE_SIZE, PIECE_SIZE), GOLD, CFrame.new(position), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
	})
end

local function step(dt: number)
	local now = os.clock()
	local t = now
	local any = false
	for id, drop in drops do
		any = true
		local target = drop.Target
		local targetPos = if target then Lib.rootPosition(target) else nil
		local alive = 0
		for _, piece in drop.Pieces do
			if piece.Collected then
				continue
			end
			alive += 1
			if targetPos and now - drop.CollectStart >= piece.Delay then
				-- Sugada: acelera em direcao ao jogador.
				local offset = targetPos - piece.Position
				local distance = offset.Magnitude
				if distance < 1.6 then
					piece.Collected = true
					piece.Part:Destroy()
					Lib.burst(targetPos, "Star", Lib.palette("Fire"), 2, {
						Color = ColorSequence.new(GOLD_CORE, GOLD),
						Brightness = 2,
						Size = Lib.seq(0.35, 0),
						Speed = NumberRange.new(3, 6),
					})
					Audio.play("Essence", targetPos, 0.8)
					continue
				end
				local speed = math.min(30 + (now - drop.CollectStart - piece.Delay) * 140, 140)
				piece.Velocity = piece.Velocity:Lerp(offset.Unit * speed, math.clamp(dt * 10, 0, 1))
				piece.Position += piece.Velocity * dt
			elseif not piece.Resting then
				-- Salto e quique.
				piece.Velocity -= Vector3.new(0, GRAVITY * dt, 0)
				piece.Position += piece.Velocity * dt
				local floor = drop.Ground + PIECE_SIZE * 0.5
				if piece.Position.Y < floor and piece.Velocity.Y < 0 then
					piece.Position = Vector3.new(piece.Position.X, floor, piece.Position.Z)
					piece.Velocity =
						Vector3.new(piece.Velocity.X * 0.6, -piece.Velocity.Y * BOUNCE, piece.Velocity.Z * 0.6)
					if piece.Velocity.Magnitude < 4 then
						piece.Resting = true
						piece.Velocity = Vector3.zero
					end
				end
			end
			-- Giro (rapido no ar, de moeda em pe quando parada) e brilho piscando.
			piece.Angle += piece.Spin * dt * (if piece.Resting and not targetPos then 0.35 else 1)
			local bob = if piece.Resting and not targetPos then math.sin(t * 3 + piece.Spin.X) * 0.12 else 0
			piece.Part.CFrame = CFrame.new(piece.Position + Vector3.new(0, bob, 0))
				* CFrame.Angles(0, piece.Angle.Y, 0)
				* CFrame.Angles(0, 0, if piece.Resting and not targetPos then 0 else piece.Angle.Z)
			piece.Part.Color = if math.sin(t * 6 + piece.Spin.Y) > 0.92 then GOLD_CORE else GOLD
		end
		if drop.Expiring then
			local alpha = math.clamp((now - drop.Expiring) / 1.5, 0, 1)
			for _, piece in drop.Pieces do
				if not piece.Collected then
					piece.Part.Transparency = alpha
				end
			end
			if alpha >= 1 then
				alive = 0
			end
		end
		if alive == 0 then
			for _, piece in drop.Pieces do
				if piece.Part.Parent then
					piece.Part:Destroy()
				end
			end
			drop.Anchor:Destroy()
			drops[id] = nil
		else
			drop.Light.Brightness = 0.6 + 0.3 * math.sin(t * 4)
		end
	end
	if not any and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function ensureLoop()
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

-- Monte novo: pecas saltando do ponto da criatura.
function Essence.drop(p: any)
	local position: Vector3 = p.Position
	local count = math.clamp(math.floor(p.Pieces or 6), 1, 40)
	local ground = Lib.groundBelow(position + Vector3.new(0, 1, 0)).Y
	local anchor = Lib.anchor(Vector3.new(position.X, ground + 1, position.Z))
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = anchor
	local pieces: { Piece } = {}
	for i = 1, count do
		local angle = math.random() * math.pi * 2
		local out = 6 + math.random() * 10
		table.insert(pieces, {
			Part = newPiece(position),
			Position = position,
			Velocity = Vector3.new(math.cos(angle) * out, 22 + math.random() * 16, math.sin(angle) * out),
			Spin = Vector3.new(0, (math.random() - 0.5) * 30, (math.random() - 0.5) * 24),
			Angle = Vector3.new(0, math.random() * 6, 0),
			Resting = false,
			Delay = (i - 1) * 0.035,
			Collected = false,
		})
	end
	drops[p.Id] = {
		Id = p.Id,
		Ground = ground,
		Pieces = pieces,
		Anchor = anchor,
		Light = light,
		Target = nil,
		CollectStart = 0,
		Expiring = nil,
	}
	Lib.burst(position, "Star", Lib.palette("Fire"), 10, {
		Color = ColorSequence.new(GOLD_CORE, GOLD),
		Brightness = 1.8,
		Speed = NumberRange.new(6, 12),
	})
	Audio.play("EssenceDrop", position, 0.9)
	ensureLoop()
end

-- O servidor entregou o monte a alguem: as pecas voam ate ele.
function Essence.collect(p: any)
	local drop = drops[p.Id]
	if not drop or not p.Model then
		return
	end
	drop.Target = p.Model
	drop.CollectStart = os.clock()
	for _, piece in drop.Pieces do
		piece.Resting = false
	end
	ensureLoop()
end

function Essence.expire(p: any)
	local drop = drops[p.Id]
	if drop and not drop.Target then
		drop.Expiring = os.clock()
	end
end

-- Para o teste de fumaca: anima um quadro.
Essence.debugStep = step

return Essence
