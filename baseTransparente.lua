-- Torna todas as decorações dentro de Workspace.Plots.*.Decorations com 50% de opacidade
-- Compatível com Parts, MeshParts, Decals, Textures, ImageLabels, GuiObjects simples (BackgroundTransparency),
-- e alguns outros casos comuns. Roda uma vez e imprime resumo no console.

local Workspace = game:GetService("Workspace")

local function setTransparencyToHalf()
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		warn("[TransparencyScript] Workspace.Plots não encontrado.")
		return
	end

	local modifiedCount = 0
	local skippedCount = 0

	for _, plot in ipairs(plots:GetChildren()) do
		local decorations = plot:FindFirstChild("Decorations")
		if decorations then
			for _, obj in ipairs(decorations:GetDescendants()) do
				-- BasePart (Part, MeshPart, UnionOperation, etc.)
				if obj:IsA("BasePart") then
					local ok, err = pcall(function()
						-- Ajusta propriedade principal de transparência
						obj.Transparency = 0.5
						-- Se suportado, também aplica LocalTransparencyModifier para garantir consistência local
						if typeof(obj.LocalTransparencyModifier) == "number" then
							obj.LocalTransparencyModifier = 0.5
						end
					end)
					if ok then
						modifiedCount = modifiedCount + 1
					else
						warn("[TransparencyScript] Erro ao ajustar BasePart:", err)
						skippedCount = skippedCount + 1
					end

				-- Decal / Texture
				elseif obj:IsA("Decal") or obj:IsA("Texture") then
					local ok = pcall(function() obj.Transparency = 0.5 end)
					if ok then modifiedCount = modifiedCount + 1 else skippedCount = skippedCount + 1 end

				-- ImageLabel / ImageButton (UI dentro de ScreenGuis ou SurfaceGuis)
				elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
					local ok = pcall(function() obj.ImageTransparency = 0.5 end)
					if ok then modifiedCount = modifiedCount + 1 else skippedCount = skippedCount + 1 end

				-- GuiObject genérico (ex.: Frame, TextLabel) — ajusta BackgroundTransparency se existir
				elseif obj:IsA("GuiObject") then
					local ok, _ = pcall(function()
						if obj:IsA("TextLabel") or obj:IsA("TextButton") then
							-- TextTransparency é 0..1, ajustar também texto para manter visibilidade adequada
							if obj.TextTransparency ~= nil then obj.TextTransparency = math.clamp((obj.TextTransparency or 0) + 0.5, 0, 1) end
						end
						if obj.BackgroundTransparency ~= nil then
							obj.BackgroundTransparency = 0.5
						end
					end)
					if ok then modifiedCount = modifiedCount + 1 else skippedCount = skippedCount + 1 end

				-- SurfaceAppearance (tenta ajustar TransparencyMap se presente) — geralmente não possível diretamente
				elseif obj:IsA("SurfaceAppearance") then
					-- SurfaceAppearance não tem propriedade 'Transparency' direta aplicável em todas versões.
					-- Ignoramos mas reportamos.
					skippedCount = skippedCount + 1

				else
					-- casos não tratados
					skippedCount = skippedCount + 1
				end
			end
		end
	end

	print(string.format("[TransparencyScript] Concluído — modificados: %d, pulados: %d", modifiedCount, skippedCount))
end

-- Execução
print("[TransparencyScript] Iniciando aplicação de 50% de opacidade nas Decorações de Workspace.Plots...")
setTransparencyToHalf()
