--!strict
-- Toca sons do SoundCatalog: 3D (num ponto do mundo) ou 2D (interface). Ids vazios sao ignorados.
-- Mixagem suave: todos os sons passam pelo SoundGroup "ArcanumSfx" com volume mestre, compressor
-- (segura picos de explosoes simultaneas) e equalizador (corta o grave estrondoso e o agudo aspero).
-- O mesmo som nao empilha: no maximo MAX_SAME tocando e um intervalo minimo entre disparos.
-- Max > 0 corta o som com um fade curto (arquivos de biblioteca costumam ter cauda longa).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundCatalog = require(ReplicatedStorage.Shared.SoundCatalog)
local Lib = require(script.Parent.Lib)

local Audio = {}

Audio.MASTER_VOLUME = 0.6
local FADE = 0.25
local MAX_SAME = 2 -- copias simultaneas do mesmo som
local MIN_GAP = 0.09 -- segundos entre dois disparos do mesmo som

local group: SoundGroup? = nil
local playing: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}

local function mixer(): SoundGroup
	if group then
		return group
	end
	local g = Instance.new("SoundGroup")
	g.Name = "ArcanumSfx"
	g.Volume = Audio.MASTER_VOLUME
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -22
	compressor.Ratio = 4
	compressor.Attack = 0.005
	compressor.Release = 0.25
	compressor.GainMakeup = 0
	compressor.Parent = g
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.LowGain = -8 -- graves de explosao/pancada bem menores
	equalizer.MidGain = 0
	equalizer.HighGain = -3
	equalizer.Priority = 1
	equalizer.Parent = g
	g.Parent = SoundService
	group = g
	return g
end

function Audio.play(name: string, position: Vector3?, volumeScale: number?)
	local entry = (SoundCatalog :: any)[name]
	if not entry or entry.Id == "" then
		return
	end
	local now = os.clock()
	if (playing[name] or 0) >= MAX_SAME or now - (lastPlayed[name] or -math.huge) < MIN_GAP then
		return
	end
	lastPlayed[name] = now
	playing[name] = (playing[name] or 0) + 1

	local sound = Instance.new("Sound")
	sound.SoundId = entry.Id
	sound.Volume = entry.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = entry.PitchMin + math.random() * (entry.PitchMax - entry.PitchMin)
	sound.SoundGroup = mixer()
	if position then
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = entry.Range
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = Lib.anchor(position, math.max(entry.Max, 6) + 1)
	else
		sound.Parent = SoundService
	end

	local finished = false
	local function done()
		if not finished then
			finished = true
			playing[name] = math.max((playing[name] or 1) - 1, 0)
			sound:Destroy()
		end
	end
	sound:Play()
	sound.Ended:Connect(done)
	task.delay(math.max(entry.Max, 8) + FADE + 1, done) -- garantia (som que nao carregou)
	if entry.Max > 0 then
		task.delay(math.max(entry.Max - FADE, 0), function()
			if not finished then
				TweenService:Create(sound, TweenInfo.new(FADE), { Volume = 0 }):Play()
				task.delay(FADE, done)
			end
		end)
	end
end

return Audio
