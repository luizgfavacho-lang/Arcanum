--!strict
-- Estados de combate (equivalentes as tags State.* da Unreal). O servidor espelha cada estado
-- ativo como atributo "State_<Nome>" = true no Model, para o cliente desenhar efeitos.

return table.freeze({
	Paralyzed = "Paralyzed", -- velocidade 0, nao conjura
	Burning = "Burning", -- DoT; reaplicar renova
	Bleeding = "Bleeding", -- DoT; x2 enquanto o alvo se move
	Cursed = "Cursed", -- +20% de dano recebido
	ArcaneCharge = "ArcaneCharge", -- proximo golpe direto +25%; consumida
	Wet = "Wet", -- combo Conducao
	ManaShield = "ManaShield", -- dano pago com mana
	Weakened = "Weakened", -- -20% de dano causado

	-- Quais estados causam dano periodico
	Dot = table.freeze({ Burning = true, Bleeding = true }),
})
