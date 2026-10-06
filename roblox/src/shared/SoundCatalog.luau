--!strict
-- Sons do jogo por evento. Fonte: biblioteca oficial de efeitos do Roblox (contas "Roblox" e
-- "ProSoundEffects", liberadas para qualquer experiencia; nomes terminados em "(SFX)").
-- Trocar um som: Studio > Toolbox (Caixa de ferramentas) > Audio > busque, botao direito >
-- "Copy Asset ID" e cole aqui no formato "rbxassetid://123456". Id vazio = silencio.
-- Volume, faixa de tom sorteada (Pitch), alcance 3D (Range, studs) e Max = segundos tocados
-- (arquivos longos sao cortados com fade; 0 = inteiro).
-- Tudo passa pelo grupo "ArcanumSfx" (Vfx/Audio): volume mestre, compressor e equalizador que
-- seguram picos e graves. Ajuste fino aqui; o volume geral fica em Audio.MASTER_VOLUME.

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
	Cast_Electricity = s(9114277757, 0.3, 1, 1.15, 70, 0.8), -- Electric Zaps 12
	Cast_Fire = s(9117987817, 0.35, 0.95, 1.1, 70, 1.2), -- Pyro Fire Ball Burst 1
	Cast_Energy = s(9125648149, 0.3, 1, 1.1, 70, 1), -- Magic Zoom Up Sharp Tubular Whoosh
	Cast_Necromancy = s(9126214321, 0.35, 0.9, 1, 70, 1.2), -- Whisper Bursts Eerie Evil
	Cast_Blood = s(9119707271, 0.32, 0.9, 1.05, 70, 1), -- Swish Suck Reversed Metallic Swoosh
	-- Impactos por escola
	Impact_Electricity = s(9119594871, 0.35, 0.95, 1.1, 80, 1), -- Static Zap Body Buzzy Impacts
	Impact_Fire = s(9114554567, 0.4, 0.9, 1.05, 90, 2.2), -- Gas Fire Explosion 3
	Impact_Energy = s(9116384485, 0.32, 1, 1.15, 80, 1.4), -- Magic Burst 1
	Impact_Necromancy = s(9116406610, 0.35, 0.85, 1, 80, 1), -- Magic Poofs Thumpy Wheezy Exhale
	Impact_Blood = s(9119990452, 0.35, 0.9, 1.05, 80, 1), -- Tentacle Slime 1
	-- Magias especificas
	Bolt = s(9116281189, 0.35, 0.95, 1.15, 90, 0.8), -- Lightning Storm Zaps Sharp Hissing
	LifeDrain = s(9125807267, 0.5, 0.95, 1.05, 90, 1.2), -- Rising Whoosh Hissing Suck Burst
	Chain = s(9114237693, 0.15, 0.95, 1.1, 60, 0.5), -- Electric Arcing 5 (ticks da canalizacao)
	Strike = s(9120019110, 0.45, 0.95, 1.05, 130, 2.5), -- Thunder Lightning 5 (Raio Invocado)
	Nova = s(9117982449, 0.4, 0.95, 1.05, 100, 1.8), -- Pyro Explosion 1
	LavaSear = s(9119165650, 0.4, 0.9, 1.05, 90, 1), -- Sizzle Short And Explosive Sear 4
	LavaRumble = s(9112822924, 0.25, 1, 1.1, 60, 4.5), -- Lava Fire Deep Rumbling 1 (borbulhando)
	StrikeWarn = s(9114237693, 0.25, 0.8, 0.9, 90, 0.5), -- Electric Arcing 5 (nuvem carregando)
	SpellLine = s(9118617342, 0.4, 0.85, 1, 90, 1.2), -- Rock Impact Large Hit Scrape
	-- Grimorio completo
	StaticField = s(9114236191, 0.3, 0.95, 1.1, 80, 1.5), -- Electric Arcing 2
	FlameWall = s(9114446852, 0.45, 0.85, 1, 100, 1.5), -- Fire Whoosh 15
	Vortex = s(9112780561, 0.4, 0.9, 1, 110, 3), -- Fire Whoosh 1 (longo)
	Singularity = s(9113436640, 0.5, 0.9, 1, 120, 3), -- Big Suck Deep Groaning Build Up
	BloodRain = s(9120583756, 0.35, 0.9, 1.05, 90, 3), -- Water Slushing Slightly Goopy Squish
	Hourglass = s(9116418291, 0.45, 0.8, 0.9, 100, 3), -- Magic Tone Falling Shimmer Flanged 2
	StormBolt = s(9120020225, 0.4, 0.95, 1.1, 160, 1.6), -- Thunder Lightning 3
	StarFall = s(9120984892, 0.35, 0.9, 1.2, 120, 0.8), -- Zap High Pitch Glassy Reversed Whoosh
	MeteorFall = s(9114428742, 0.5, 0.9, 1, 160, 1.4), -- Fireball Burning Whoosh By 1
	MeteorImpact = s(9114224721, 0.6, 0.85, 0.95, 220, 3), -- Earthquake Explosion 1
	VerdictWarn = s(9120057087, 0.45, 0.95, 1.05, 140, 1.8), -- Time Warp Searing Build Up
	Verdict = s(9126102254, 0.55, 1.1, 1.2, 200, 2.5), -- Time Warp Big Explosion Blast Boom
	Crown = s(9126082854, 0.5, 0.95, 1.05, 160, 2), -- Synth Thunder Cracks Individual Explosion
	ManaShield = s(9116395089, 0.45, 1, 1.1, 60, 2), -- Magic Glows Soft Clusters Of Chiming Hits 4
	EmberArmor = s(9114430091, 0.45, 0.9, 1, 70, 1.5), -- Fire Burst 2
	Ritual = s(9114353038, 0.5, 0.9, 1, 120, 2.5), -- Evil Drone Deep Airy Swell 1
	Pact = s(9114352428, 0.45, 0.9, 1, 120, 2.5), -- Evil Church Bell Twisted Bent 1
	LightningStep = s(9120985853, 0.45, 1, 1.15, 100, 1), -- Zaps Sharp Attack 1
	Portal = s(9116422213, 0.45, 0.8, 0.9, 90, 1.5), -- Magic Transformation 17
	Prison = s(9114619221, 0.45, 0.9, 1.1, 80, 1.2), -- Glass Tinks 3
	Hook = s(9125419776, 0.45, 0.95, 1.1, 90, 1), -- Cable Swish Thick Spinning
	DeathTouch = s(9114574159, 0.45, 1, 1.1, 80, 1.6), -- Ghost Wind Slow Build And Decay
	Curse = s(9126213995, 0.5, 0.85, 0.95, 90, 1.6), -- Whisper Bursts Eerie Evil
	Hemorrhage = s(9119559518, 0.45, 0.9, 1.1, 80, 1), -- Squishy Bone Cracks 5
	ArcaneBeam = s(9114236191, 0.2, 1.2, 1.3, 70, 0.4), -- Electric Arcing 2 (ticks)
	LanceCharge = s(9125973433, 0.45, 1, 1.05, 100, 1.4), -- Spaceship Blast Energy Charge Up
	LanceFire = s(9114118865, 0.6, 1, 1.05, 200, 2), -- Disintegrator Beam Blast 301
	BloodSlash = s(9126014020, 0.5, 0.95, 1.1, 70, 0.8), -- Swish Med High End Sharp Swords
	Summon = s(9119558965, 0.45, 0.9, 1.1, 80, 1.5), -- Squishy Bone Cracks 2
	Army = s(9114574104, 0.5, 0.9, 1, 140, 3), -- Ghost Wind Slow Build And Decay 1
	Rose = s(9116418680, 0.45, 0.9, 1, 120, 2.5), -- Magic Tone Long Swelling Magical Tones
	OrbShock = s(9119594928, 0.3, 1, 1.2, 80, 0.6), -- Static Zap Impact Buzz Twice

	-- Reacoes entre escolas (Math/ComboMath)
	Reaction_Overload = s(9126082854, 0.45, 0.85, 0.95, 110, 1.6), -- Synth Thunder Cracks Individual Explosion
	Reaction_Vaporize = s(9119165650, 0.4, 0.8, 0.9, 90, 1.2), -- Sizzle Short And Explosive Sear 4
	Reaction_Conduct = s(9114237693, 0.35, 1.15, 1.3, 90, 0.8), -- Electric Arcing 5
	Reaction_Rupture = s(9114614830, 0.4, 1.1, 1.25, 90, 1), -- Glass Smashes 3
	Reaction_Harvest = s(9125807267, 0.35, 1.1, 1.2, 80, 1), -- Rising Whoosh Hissing Suck Burst
	Reaction_Contagion = s(9119990528, 0.4, 0.75, 0.85, 80, 1), -- Tentacle Slime 2
	MinionHit = s(9117969878, 0.3, 0.9, 1.1, 60, 0.6), -- Punch Kit Beefy Hit 4
	-- Inimigos
	EnemyCharge = s(9125981170, 0.22, 0.95, 1.1, 60, 0.9), -- Pre Blast Electric Charge Up Glass
	Alert_Skeleton = s(9126213993, 0.5, 0.9, 1.1, 70, 1.4), -- Whisper Bursts Eerie
	Alert_Slime = s(9119990528, 0.5, 0.9, 1.2, 60, 1), -- Tentacle Slime 2
	Alert_Bloater = s(9114277403, 0.4, 1.1, 1.3, 70, 0.8), -- Electric Zaps 5
	Alert_Golem = s(9113980480, 0.4, 0.7, 0.8, 110, 1.5), -- Giant Crab Monster Roar Growl 2
	Taunt = s(9114571613, 0.35, 0.85, 1, 60, 2), -- Ghost Giggle Creepy Possessed
	Pounce = s(9120627691, 0.32, 0.95, 1.2, 60, 0.8), -- Web Release Wet Crunchy Whipping Swish
	Fuse = s(9114237487, 0.3, 1, 1.2, 70, 1.2), -- Electric Arcing 4 (Bulbo inchando)
	Explosion = s(9126102254, 0.42, 0.95, 1.05, 120, 2.5), -- Time Warp Big Explosion Blast Boom
	SlamWindup = s(9116302511, 0.4, 0.65, 0.75, 110, 1.6), -- Lion Roar Short Blast Attack
	Slam = s(9125404320, 0.45, 0.9, 1, 130, 2.2), -- Boom Impact Deep Distant Thumping
	Spikes = s(9114614830, 0.35, 0.7, 0.85, 110, 1.6), -- Glass Smashes 3 (cristais rompendo)
	Roar = s(9113980319, 0.5, 0.7, 0.75, 160, 3), -- Giant Crab Monster Roar Growl 1
	Blink = s(9116422213, 0.32, 0.95, 1.1, 70, 1.5), -- Magic Transformation 17
	Stagger = s(9117969687, 0.35, 0.9, 1.05, 70, 0.8), -- Punch Kit Beefy Hit 2
	Interrupt = s(9125672726, 0.4, 1.1, 1.25, 90, 1), -- Metal Impact Sledge Hammer
	Death = s(9116418035, 0.3, 0.9, 1.1, 80, 2), -- Magic Tone Falling Shimmer Flanged 3
	Death_Skeleton = s(9113542363, 0.35, 0.9, 1.1, 70, 1), -- Bone Cracks 10
	Death_Slime = s(9113537815, 0.35, 0.85, 1.1, 70, 1), -- Boink Wet Suction Pop
	Death_Golem = s(9125869797, 0.5, 0.7, 0.8, 130, 2), -- Rock Drops Smashes Impacts
	-- Jogador
	Dodge = s(9126229255, 0.5, 0.95, 1.1, 60, 0.8), -- Whoosh By Fast Airy Swooshing
	PerfectDodge = s(9126073001, 0.5, 1, 1.05, 60, 1), -- Synth Sparkle Tone High Pitch Bell Ding
	Hurt = s(9117969717, 0.3, 0.9, 1.05, 40, 0.6), -- Punch Kit Beefy Hit 3
	PlayerDeath = s(9113480915, 0.45, 0.9, 1, 60, 1.2), -- Body Fall Thud 2
	LevelUp = s(9117297453, 0.45, 1, 1, 80, 3), -- Phasey Synth Power Up High Pitched Rise 2
	-- Interface
	Fail = s(17208353912, 0.4, 1, 1), -- Roblox GUI - Negative
	Select = s(17208396156, 0.25, 1, 1.1), -- Roblox GUI - Select
	GrimoireOpen = s(15675037413, 0.5, 0.9, 1), -- Roblox UI Paper Swipe
	GrimoireClose = s(15675037413, 0.4, 1.15, 1.25), -- Roblox UI Paper Swipe (agudo)
	GrimoireHover = s(17208339919, 0.15, 1, 1.1), -- Roblox GUI - Hover 01
	GrimoireEquip = s(17208323435, 0.5, 1, 1), -- Roblox GUI - Equip
})
