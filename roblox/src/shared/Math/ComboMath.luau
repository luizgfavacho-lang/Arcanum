--!strict
-- Reacoes entre escolas (regras PURAS, testadas em tests/ComboMath.spec.luau).
-- Um golpe DIRETO de uma escola num alvo com certo estado dispara uma reacao. Periodicos (DoT),
-- respingos de outra reacao e alvos ainda em recarga de reacao nao disparam.
--
--   Sobrecarga  Fogo em Paralisado / Eletricidade em Queimando: explode e fere quem esta em volta
--   Vaporizar   Fogo em Encharcado: x1,5 e consome a agua
--   Conducao    Eletricidade em Encharcado: (o x1,5 ja vem do DamageMath) arcos para outros encharcados
--   Ruptura     Energia em Paralisado: x1,4 e quebra a paralisia
--   Colheita    Necromancia em Sangrando: o conjurador cura parte do dano
--   Contagio    Sangue em Envenenado: veneno e sangramento se espalham para quem esta perto

export type Reaction = {
	Id: string,
	Label: string, -- texto na tela (PT-BR)
	School: string, -- escola do golpe que dispara
	State: string, -- estado que o alvo precisa ter
	Multiplier: number, -- multiplica o dano do golpe que disparou
	Consumes: boolean, -- remove o estado do alvo
	SplashFraction: number, -- fracao do dano aplicada em volta (0 = sem respingo)
	SplashRadiusMeters: number,
	SplashOnlyState: boolean, -- respingo so atinge quem tem o mesmo estado (Conducao)
	HealFraction: number, -- cura do conjurador (fracao do dano)
	SpreadRadiusMeters: number, -- espalha estados (Contagio)
}

local ComboMath = {}

ComboMath.Cooldown = 0.6 -- segundos entre reacoes no mesmo alvo

local function reaction(fields: { [string]: any }): Reaction
	local r: Reaction = {
		Id = fields.Id,
		Label = fields.Label,
		School = fields.School,
		State = fields.State,
		Multiplier = fields.Multiplier or 1,
		Consumes = fields.Consumes == true,
		SplashFraction = fields.SplashFraction or 0,
		SplashRadiusMeters = fields.SplashRadiusMeters or 0,
		SplashOnlyState = fields.SplashOnlyState == true,
		HealFraction = fields.HealFraction or 0,
		SpreadRadiusMeters = fields.SpreadRadiusMeters or 0,
	}
	return table.freeze(r)
end

-- Ordem = prioridade (o primeiro que casar vence).
ComboMath.Reactions = table.freeze({
	reaction({
		Id = "Vaporize",
		Label = "VAPORIZAR",
		School = "Fire",
		State = "Wet",
		Multiplier = 1.5,
		Consumes = true,
	}),
	reaction({
		Id = "Overload",
		Label = "SOBRECARGA",
		School = "Fire",
		State = "Paralyzed",
		Multiplier = 1.25,
		SplashFraction = 0.6,
		SplashRadiusMeters = 3.5,
	}),
	reaction({
		Id = "Overload",
		Label = "SOBRECARGA",
		School = "Electricity",
		State = "Burning",
		Multiplier = 1.25,
		Consumes = true,
		SplashFraction = 0.6,
		SplashRadiusMeters = 3.5,
	}),
	reaction({
		Id = "Conduct",
		Label = "CONDUCAO",
		School = "Electricity",
		State = "Wet",
		SplashFraction = 0.4,
		SplashRadiusMeters = 7,
		SplashOnlyState = true,
	}),
	reaction({
		Id = "Rupture",
		Label = "RUPTURA",
		School = "Energy",
		State = "Paralyzed",
		Multiplier = 1.4,
		Consumes = true,
	}),
	reaction({ Id = "Harvest", Label = "COLHEITA", School = "Necromancy", State = "Bleeding", HealFraction = 0.3 }),
	reaction({
		Id = "Contagion",
		Label = "CONTAGIO",
		School = "Blood",
		State = "Poisoned",
		Multiplier = 1.15,
		SpreadRadiusMeters = 4.5,
	}),
})

-- Reacao que um golpe direto de `school` dispara num alvo; `has(state)` diz se o alvo tem o estado.
function ComboMath.find(school: string?, has: (state: string) -> boolean): Reaction?
	if not school then
		return nil
	end
	for _, r in ComboMath.Reactions do
		if r.School == school and has(r.State) then
			return r
		end
	end
	return nil
end

-- A recarga por alvo ja passou?
function ComboMath.ready(lastReactionAt: number?, now: number): boolean
	return lastReactionAt == nil or now - lastReactionAt >= ComboMath.Cooldown
end

-- Dano do respingo em quem esta em volta.
function ComboMath.splashDamage(r: Reaction, hitDamage: number): number
	return math.max(hitDamage, 0) * r.SplashFraction
end

function ComboMath.healAmount(r: Reaction, hitDamage: number): number
	return math.max(hitDamage, 0) * r.HealFraction
end

return table.freeze(ComboMath)
