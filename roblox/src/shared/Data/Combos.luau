--!strict
-- GERADO por roblox/tools/gen_data.py a partir de Data/Combos.csv. NAO EDITE: mude o CSV e rode o gerador.

return table.freeze({
	Conduction = table.freeze({ TriggerSchool = "Electricity", TargetState = "State.Wet", DamageMultiplier = 1.5, ExtraEffect = "ForceParalyze", ExtraValue = 1, bConsumesState = true, Notes = "Eletricidade em alvo molhado: x1,5 e paralisia garantida 1 s; seca o alvo" }),
	UnholyPyre = table.freeze({ TriggerSchool = "Fire", TargetState = "State.Cursed", DamageMultiplier = 1.3, ExtraEffect = "SpreadBurning", ExtraValue = 4, bConsumesState = false, Notes = "Fogo em amaldicoado: x1,3; queimadura verde salta para 1 alvo a 4 m" }),
	Steam = table.freeze({ TriggerSchool = "Fire", TargetState = "State.Wet", DamageMultiplier = 0.8, ExtraEffect = "SteamCloud", ExtraValue = 4, bConsumesState = true, Notes = "Fogo em molhado: dano x0,8, apaga e cria nevoa de vapor (raio 4) que cega inimigos" }),
	Overcharge = table.freeze({ TriggerSchool = "Electricity", TargetState = "State.ArcaneCharge", DamageMultiplier = 1, ExtraEffect = "ExtraChainJump", ExtraValue = 1, bConsumesState = true, Notes = "Raio em alvo com Carga Arcana: +1 salto (alem do +25% da carga)" }),
	BoilingBlood = table.freeze({ TriggerSchool = "Blood", TargetState = "State.Burning", DamageMultiplier = 1.2, ExtraEffect = "BleedAmplify", ExtraValue = 1.5, bConsumesState = false, Notes = "Sangue em alvo queimando: sangramento x1,5" }),
	Harvest = table.freeze({ TriggerSchool = "Necromancy", TargetState = "State.Bleeding", DamageMultiplier = 1, ExtraEffect = "FullLifeDrain", ExtraValue = 1, bConsumesState = false, Notes = "Necromancia em alvo sangrando: cura de drenagem passa a 100%" }),
	Meltdown = table.freeze({ TriggerSchool = "Fire", TargetState = "State.Paralyzed", DamageMultiplier = 1.3, ExtraEffect = "", ExtraValue = 0, bConsumesState = false, Notes = "Fogo em paralisado: x1,3" }),
	Lockdown = table.freeze({ TriggerSchool = "Energy", TargetState = "State.Paralyzed", DamageMultiplier = 1, ExtraEffect = "ExtendPrison", ExtraValue = 1.5, bConsumesState = false, Notes = "Prisao de Energia em paralisado: duracao x1,5" }),
})
