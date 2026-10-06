--!strict
-- Regras PURAS das mecanicas proprias de cada magia (testadas em tests/SpellMath.spec.luau).
-- Referencias de jogos consagrados ao lado de cada regra.

local SpellMath = {}

-- Campo Estatico (Plasma Field, Razor/DotA): o pulso fere mais na borda do que no centro.
SpellMath.StaticCenter = 0.6
SpellMath.StaticEdge = 1.6
function SpellMath.staticFieldMultiplier(distance: number, radius: number): number
	if radius <= 0 then
		return 1
	end
	local t = math.clamp(distance / radius, 0, 1)
	return SpellMath.StaticCenter + (SpellMath.StaticEdge - SpellMath.StaticCenter) * t
end

-- Lamina de Sangue (Darkin Blade, Aatrox/LoL): a ponta da lamina ("ponto doce") fere mais.
SpellMath.SweetSpotStart = 0.6 -- fracao do alcance onde comeca a ponta
SpellMath.SweetSpotBonus = 1.5
function SpellMath.bladeMultiplier(distance: number, reach: number): (number, boolean)
	if reach > 0 and distance >= reach * SpellMath.SweetSpotStart then
		return SpellMath.SweetSpotBonus, true
	end
	return 1, false
end

-- Nova Flamejante (Pyroclasm/Brand, LoL): quem ja queimava sofre Combustao.
SpellMath.CombustionBonus = 1.5
function SpellMath.novaMultiplier(targetBurning: boolean): number
	return if targetBurning then SpellMath.CombustionBonus else 1
end

-- Toque Mortal (Reaper's Scythe, Necrophos/DotA): abaixo do limiar depois do golpe = execucao.
-- Chefes nunca sao executados.
SpellMath.ExecuteThreshold = 0.15
function SpellMath.shouldExecute(healthAfter: number, maxHealth: number, isBoss: boolean): boolean
	return not isBoss and healthAfter > 0 and maxHealth > 0 and healthAfter / maxHealth <= SpellMath.ExecuteThreshold
end

-- Veredito da Aurora (Sun Strike + Solar Flare): o miolo da coluna atordoa.
SpellMath.VerdictCore = 0.45
function SpellMath.inVerdictCore(distance: number, radius: number): boolean
	return distance <= radius * SpellMath.VerdictCore
end

-- Singularidade (Black Hole, Enigma/DotA): o miolo do vortice prende.
SpellMath.SingularityCore = 0.5
function SpellMath.inSingularityCore(distance: number, radius: number): boolean
	return distance <= radius * SpellMath.SingularityCore
end

-- Armadura de Brasas (Molten Shield, Annie/LoL): reduz o dano recebido.
SpellMath.EmberArmorReduction = 0.15

-- Ampulheta Partida (Chronosphere): fora do tempo, os inimigos ficam vulneraveis (Maldicao).
-- Tempestade (Static Storm/Thundergod's Wrath): fracao dos raios que procura um inimigo.
SpellMath.TempestSeek = 0.7

-- Lentidao: velocidade final de quem esta lento (fracao 0..0.9).
function SpellMath.slowedSpeed(baseSpeed: number, slowFraction: number): number
	return baseSpeed * (1 - math.clamp(slowFraction, 0, 0.9))
end

-- Meteoro (Chaos Meteor, Invoker/DotA): distancia rolada depois de cair.
function SpellMath.meteorRoll(speed: number, duration: number): number
	return math.max(speed, 0) * math.max(duration, 0)
end

return table.freeze(SpellMath)
