--!strict
-- Toca sons do SoundCatalog: 3D (num ponto do mundo) ou 2D (interface). Ids vazios sao ignorados.
-- Max > 0 corta o som com um fade curto (arquivos de biblioteca costumam ter cauda longa).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundCatalog = require(ReplicatedStorage.Shared.SoundCatalog)
local Lib = require(script.Parent.Lib)

local Audio = {}

local FADE = 0.2

function Audio.play(name: string, position: Vector3?, volumeScale: number?)
	local entry = (SoundCatalog :: any)[name]
	if not entry or entry.Id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = entry.Id
	sound.Volume = entry.Volume * (volumeScale or 1)
	sound.PlaybackSpeed = entry.PitchMin + math.random() * (entry.PitchMax - entry.PitchMin)
	if position then
		sound.RollOffMaxDistance = entry.Range
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = Lib.anchor(position, math.max(entry.Max, 6) + 1)
	else
		sound.Parent = SoundService
	end
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	if entry.Max > 0 then
		task.delay(math.max(entry.Max - FADE, 0), function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(FADE), { Volume = 0 }):Play()
				task.delay(FADE, function()
					sound:Destroy()
				end)
			end
		end)
	end
end

return Audio
