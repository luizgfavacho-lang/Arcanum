--!strict
-- GERADO por roblox/tools/gen_data.py a partir de Data/Passives.csv. NAO EDITE: mude o CSV e rode o gerador.

return table.freeze({
	Alchemist = table.freeze({ BonusValue = 0.5, BonusValue2 = 2, PenaltyValue = 0, Threshold = 0, Chance = 0, Notes = "Pocoes +BonusValue duracao; bebe BonusValue2x mais rapido; nao usa escudo" }),
	ArcaneExplorer = table.freeze({ BonusValue = 1, BonusValue2 = 0, PenaltyValue = 0.05, Threshold = 0, Chance = 0, Notes = "Bussola p/ estrutura inexplorada; +BonusValue item nos baus; -PenaltyValue dano fora de estruturas" }),
	BloodTide = table.freeze({ BonusValue = 0.4, BonusValue2 = 0.4, PenaltyValue = 0.1, Threshold = 0.5, Chance = 0, Notes = "Abaixo de Threshold vida: ate +BonusValue dano e +BonusValue2 velocidade; acima de 90%: -PenaltyValue dano" }),
	Conductor = table.freeze({ BonusValue = 0.5, BonusValue2 = 1, PenaltyValue = 0.15, Threshold = 0, Chance = 0, Notes = "Raios curam BonusValue do dano e recarregam mana; cadeias +BonusValue2 alvo; -PenaltyValue velocidade na chuva" }),
	CursedLuck = table.freeze({ BonusValue = 3, BonusValue2 = 0, PenaltyValue = 2, Threshold = 0, Chance = 0.1, Notes = "Chance de critico x BonusValue; 5% de falha que custa PenaltyValue x mana (Chance=critico)" }),
	Gravedigger = table.freeze({ BonusValue = 0.15, BonusValue2 = 0, PenaltyValue = 0, Threshold = 0, Chance = 0, Notes = "Mortos-vivos ignoram ate serem atacados; +BonusValue dano necromantico; animais fogem" }),
	HeadInTheClouds = table.freeze({ BonusValue = 0.3, BonusValue2 = 4, PenaltyValue = 0, Threshold = 0, Chance = 0, Notes = "Planar segurando pulo (BonusValue2 mana/s), sem dano de queda; +BonusValue dano de explosoes" }),
	Leech = table.freeze({ BonusValue = 0.08, BonusValue2 = 0, PenaltyValue = 0.5, Threshold = 0, Chance = 0, Notes = "Corpo a corpo cura BonusValue do dano; regen natural de vida -PenaltyValue (substitui fome)" }),
	ShortFuse = table.freeze({ BonusValue = 0.25, BonusValue2 = 0, PenaltyValue = 0.15, Threshold = 0, Chance = 0, Notes = "Recargas -BonusValue; custo de mana +PenaltyValue" }),
	StoneSkin = table.freeze({ BonusValue = 6, BonusValue2 = 0, PenaltyValue = 0.15, Threshold = 0, Chance = 0, Notes = "+BonusValue armadura e imune a empurrao; -PenaltyValue velocidade" }),
	MinersLuck = table.freeze({ BonusValue = 1, BonusValue2 = 0.3, PenaltyValue = 0.1, Threshold = 0, Chance = 0.25, Notes = "Chance de minerio extra (Chance) e +BonusValue2 de Manita por veio; -PenaltyValue mana maxima" }),
	LoneWolf = table.freeze({ BonusValue = 0.2, BonusValue2 = 0, PenaltyValue = 1, Threshold = 0, Chance = 0, Notes = "Sem aliados/servos a 20 m: +BonusValue dano; nao pode invocar servos (PenaltyValue=1)" }),
	VoidDancer = table.freeze({ BonusValue = 6, BonusValue2 = 8, PenaltyValue = 0.1, Threshold = 0, Chance = 0, Notes = "Dash de BonusValue m (recarga BonusValue2 s) com invulnerabilidade curta; -PenaltyValue vida maxima" }),
	SoulCollector = table.freeze({ BonusValue = 1, BonusValue2 = 0.02, PenaltyValue = 0.1, Threshold = 0, Chance = 0, Notes = "Abates dao almas (ate 20): +BonusValue2 poder magico por alma; perde metade ao morrer; -PenaltyValue XP" }),
	Phoenix = table.freeze({ BonusValue = 0.5, BonusValue2 = 0, PenaltyValue = 0.2, Threshold = 0, Chance = 0, Notes = "Renasce 1x por dia com BonusValue da vida; ate renascer de novo -PenaltyValue cura recebida" }),
	ManaFuse = table.freeze({ BonusValue = 0.3, BonusValue2 = 0, PenaltyValue = 0.25, Threshold = 0, Chance = 0, Notes = "+BonusValue mana maxima; ao zerar a mana sofre dano igual a PenaltyValue da vida maxima" }),
})
