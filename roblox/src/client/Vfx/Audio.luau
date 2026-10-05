--!strict
-- Toca sons do SoundCatalog: 3D (num ponto do mundo) ou 2D (interface). Ids vazios sao ignorados.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundCatalog = require(ReplicatedStorage.Shared.SoundCatalog)
local Lib = require(script.Parent.Lib)

local Audio = {}

function Audio.play(name: string, position: Vector3?)
	local entry = (SoundCatalog :: any)[name]
	if not entry or entry.Id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = entry.Id
	sound.Volume = entry.Volume
	sound.PlaybackSpeed = entry.PitchMin + math.random() * (entry.PitchMax - entry.PitchMin)
	if position then
		sound.RollOffMaxDistance = entry.Range
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = Lib.anchor(position, 6)
	else
		sound.Parent = SoundService
	end
	sound.PlayOnRemove = false
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

return Audio
