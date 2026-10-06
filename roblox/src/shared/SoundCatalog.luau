--!strict
-- Sons do jogo por evento. Fonte: biblioteca oficial de efeitos do Roblox (contas "Roblox" e
-- "ProSoundEffects", liberadas para qualquer experiencia; nomes terminados em "(SFX)").
-- Trocar um som: Studio > Toolbox (Caixa de ferramentas) > Audio > busque, botao direito >
-- "Copy Asset ID" e cole aqui no formato "rbxassetid://123456". Id vazio = silencio.
-- Volume, faixa de tom sorteada (Pitch), alcance 3D (Range, studs) e Max = segundos tocados
-- (arquivos longos sao cortados com fade; 0 = inteiro).

export type Sound = {
	Id: string,
	Volume: number,
	PitchMin: number,
	PitchMax: number,
	Range: number,
	Max: number,
}

local function s(id: number?, volume: number, pitchMin: number?, pitchMax: number?, range: number?, max: number?): Sound
	return {
		Id = if id then "rbxassetid://" .. tostring(id) else "",
		Volume = volume,
		PitchMin = pitchMin or 0.95,
		PitchMax = pitchMax or 1.05,
		Range = range or 80,
		Max = max or 0,
	}
end

return table.freeze({
	-- Conjuracao por escola
	Cast_Electricity = s(9114277757, 0.45, 1, 1.15, 90, 0.8), -- Electric Zaps 12
	Cast_Fire = s(9117987817, 0.55, 0.95, 1.1, 90, 1.2), -- Pyro Fire Ball Burst 1
	Cast_Energy = s(9125648149, 0.45, 1, 1.1, 90, 1), -- Magic Zoom Up Sharp Tubular Whoosh
	Cast_Necromancy = s(9126214321, 0.5, 0.9, 1, 90, 1.2), -- Whisper Bursts Eerie Evil
	Cast_Blood = s(9119707271, 0.5, 0.9, 1.05, 90, 1), -- Swish Suck Reversed Metallic Swoosh
	-- Impactos por escola
	Impact_Electricity = s(9119594871, 0.55, 0.95, 1.1, 100, 1), -- Static Zap Body Buzzy Impacts
	Impact_Fire = s(9114554567, 0.7, 0.9, 1.05, 130, 2.2), -- Gas Fire Explosion 3
	Impact_Energy = s(9116384485, 0.5, 1, 1.15, 100, 1.4), -- Magic Burst 1
	Impact_Necromancy = s(9116406610, 0.55, 0.85, 1, 100, 1), -- Magic Poofs Thumpy Wheezy Exhale
	Impact_Blood = s(9119990452, 0.55, 0.9, 1.05, 100, 1), -- Tentacle Slime 1
	-- Magias especificas
	Bolt = s(9116281189, 0.55, 0.95, 1.15, 110, 0.8), -- Lightning Storm Zaps Sharp Hissing
	LifeDrain = s(9125807267, 0.5, 0.95, 1.05, 90, 1.2), -- Rising Whoosh Hissing Suck Burst
	Chain = s(9114237693, 0.25, 0.95, 1.1, 80, 0.5), -- Electric Arcing 5 (ticks da canalizacao)
	Strike = s(9120019110, 0.8, 0.95, 1.05, 200, 2.5), -- Thunder Lightning 5 (Raio Invocado)
	Nova = s(9117982449, 0.7, 0.95, 1.05, 130, 1.8), -- Pyro Explosion 1
	SpellLine = s(9118617342, 0.7, 0.85, 1, 120, 1.2), -- Rock Impact Large Hit Scrape
	-- Inimigos
	EnemyCharge = s(9125981170, 0.35, 0.95, 1.1, 70, 0.9), -- Pre Blast Electric Charge Up Glass
	Alert_Skeleton = s(9126213993, 0.5, 0.9, 1.1, 70, 1.4), -- Whisper Bursts Eerie
	Alert_Slime = s(9119990528, 0.5, 0.9, 1.2, 60, 1), -- Tentacle Slime 2
	Alert_Bloater = s(9114277403, 0.4, 1.1, 1.3, 70, 0.8), -- Electric Zaps 5
	Alert_Golem = s(9113980480, 0.7, 0.7, 0.8, 140, 1.5), -- Giant Crab Monster Roar Growl 2
	Taunt = s(9114571613, 0.55, 0.85, 1, 70, 2), -- Ghost Giggle Creepy Possessed
	Pounce = s(9120627691, 0.5, 0.95, 1.2, 70, 0.8), -- Web Release Wet Crunchy Whipping Swish
	Fuse = s(9114237487, 0.5, 1, 1.2, 90, 1.2), -- Electric Arcing 4 (Bulbo inchando)
	Explosion = s(9126102254, 0.8, 0.95, 1.05, 180, 2.5), -- Time Warp Big Explosion Blast Boom
	SlamWindup = s(9116302511, 0.7, 0.65, 0.75, 160, 1.6), -- Lion Roar Short Blast Attack
	Slam = s(9125404320, 0.9, 0.9, 1, 200, 2.2), -- Boom Impact Deep Distant Thumping
	Spikes = s(9114614830, 0.6, 0.7, 0.85, 150, 1.6), -- Glass Smashes 3 (cristais rompendo)
	Roar = s(9113980319, 1, 0.7, 0.75, 250, 3), -- Giant Crab Monster Roar Growl 1
	Blink = s(9116422213, 0.5, 0.95, 1.1, 90, 1.5), -- Magic Transformation 17
	Stagger = s(9117969687, 0.6, 0.9, 1.05, 90, 0.8), -- Punch Kit Beefy Hit 2
	Interrupt = s(9125672726, 0.7, 1.1, 1.25, 120, 1), -- Metal Impact Sledge Hammer
	Death = s(9116418035, 0.5, 0.9, 1.1, 100, 2), -- Magic Tone Falling Shimmer Flanged 3
	Death_Skeleton = s(9113542363, 0.6, 0.9, 1.1, 90, 1), -- Bone Cracks 10
	Death_Slime = s(9113537815, 0.6, 0.85, 1.1, 80, 1), -- Boink Wet Suction Pop
	Death_Golem = s(9125869797, 0.9, 0.7, 0.8, 200, 2), -- Rock Drops Smashes Impacts
	-- Jogador
	Dodge = s(9126229255, 0.5, 0.95, 1.1, 60, 0.8), -- Whoosh By Fast Airy Swooshing
	PerfectDodge = s(9126073001, 0.5, 1, 1.05, 60, 1), -- Synth Sparkle Tone High Pitch Bell Ding
	Hurt = s(9117969717, 0.5, 0.9, 1.05, 40, 0.6), -- Punch Kit Beefy Hit 3
	PlayerDeath = s(9113480915, 0.7, 0.9, 1, 60, 1.2), -- Body Fall Thud 2
	LevelUp = s(9117297453, 0.6, 1, 1, 80, 3), -- Phasey Synth Power Up High Pitched Rise 2
	-- Interface
	Fail = s(17208353912, 0.4, 1, 1), -- Roblox GUI - Negative
	Select = s(17208396156, 0.25, 1, 1.1), -- Roblox GUI - Select
	GrimoireOpen = s(15675037413, 0.5, 0.9, 1), -- Roblox UI Paper Swipe
	GrimoireClose = s(15675037413, 0.4, 1.15, 1.25), -- Roblox UI Paper Swipe (agudo)
	GrimoireHover = s(17208339919, 0.15, 1, 1.1), -- Roblox GUI - Hover 01
	GrimoireEquip = s(17208323435, 0.5, 1, 1), -- Roblox GUI - Equip
})
