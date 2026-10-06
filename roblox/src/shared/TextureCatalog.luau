--!strict
-- Texturas dos efeitos. Imagens PUBLICAS da Caixa de ferramentas do Roblox (decalques gratuitos),
-- convertidas para o ID da imagem (o que ParticleEmitter/ImageLabel aceitam). Nada binario no Git.
-- Brancas/cinzas sempre que possivel: a cor vem da paleta da escola (Color/ImageColor3).
-- Trocar uma: Studio -> Caixa de ferramentas -> Decalques; cole o ID do DECALQUE num Decal e copie
-- o Texture que o Studio gerar (e esse numero que vai aqui).

local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end

return table.freeze({
	-- Circulos magicos (chao: conjuracao, zonas, telegrafias)
	CircleStar = id(4802228704), -- "Magic Circle": estrela, sol e lua, traco fino
	CircleRunes = id(127817121), -- "Magic circle1": runas e estrela, borda brilhante
	CircleOrnate = id(303872831), -- "Celestial Dragon Slayer Magic Circle": ornamentado
	CircleThorns = id(7452563698), -- "magic circle": aro com espinhos (Sangue/Necromancia)

	-- Aneis (onda de choque, avisos)
	Ring = id(1057939773), -- "Shockwave": anel de borda nitida
	SoftRing = id(12914395250), -- anel com degrade para dentro

	-- Flipbooks (ParticleEmitter.FlipbookLayout)
	FireWhite8 = id(17703243127), -- fogo branco recoloravel, 8x8
	FireColor4 = id(13344777062), -- fogo colorido, 4x4
	Smoke4 = id(13346862770), -- fumaca, 4x4

	-- Eletricidade
	ElectricBurst = id(12525387853), -- explosao radial de raios (fundo preto: so aditivo)
	ElectricArc = id(14173768118), -- arco pequeno (fundo preto: so aditivo)
})
