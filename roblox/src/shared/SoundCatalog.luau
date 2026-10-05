--!strict
-- Sons do jogo por evento. Ids vazios = silencio (sem erro no Output).
-- Como preencher: Studio > Toolbox (Caixa de ferramentas) > Audio > busque (ex.: "magic fire whoosh"),
-- prefira audios publicados pelo proprio Roblox (livres para qualquer jogo), clique com o botao
-- direito > "Copy Asset ID" e cole aqui no formato "rbxassetid://123456".
-- Volume e variacao de tom (Pitch) por evento; o Audio do cliente sorteia o tom dentro da faixa.

export type Sound = { Id: string, Volume: number, PitchMin: number, PitchMax: number, Range: number }

local function s(id: string, volume: number, pitchMin: number?, pitchMax: number?, range: number?): Sound
	return { Id = id, Volume = volume, PitchMin = pitchMin or 0.95, PitchMax = pitchMax or 1.05, Range = range or 80 }
end

return table.freeze({
	-- Conjuracao por escola
	Cast_Electricity = s("", 0.5),
	Cast_Fire = s("", 0.5),
	Cast_Energy = s("", 0.5),
	Cast_Necromancy = s("", 0.5),
	Cast_Blood = s("", 0.5),
	-- Impactos por escola
	Impact_Electricity = s("", 0.6),
	Impact_Fire = s("", 0.8, 0.9, 1.05, 120),
	Impact_Energy = s("", 0.55),
	Impact_Necromancy = s("", 0.55),
	Impact_Blood = s("", 0.55),
	-- Magias especificas
	Bolt = s("", 0.6, 0.9, 1.15),
	LifeDrain = s("", 0.5),
	-- Combate e interface
	Death = s("", 0.6, 0.85, 1.1),
	Dodge = s("", 0.45, 0.95, 1.1), -- esquiva (sopro rapido)
	Interrupt = s("", 0.7, 1, 1.1), -- golpe inimigo interrompido (estalo metalico)
	LevelUp = s("", 0.7, 1, 1),
	Fail = s("", 0.35, 1, 1),
	Select = s("", 0.25, 1, 1.1),
})
