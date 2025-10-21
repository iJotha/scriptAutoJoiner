--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:3000"
local APP_URL = "https://renderbots.onrender.com/api/report"
local VPS_ID = "vps_" .. game.JobId
local REQUEST_DELAY = 2.0
local MAIN_LOOP_WAIT = 0.5

--------------------------------------------------------
-- SERVIÇOS & REQ
--------------------------------------------------------
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local req = request or http_request
if not req then
	warn("Exploit não suporta request")
	return
end

--------------------------------------------------------
-- ESPERAR O CARREGAMENTO COMPLETO DO JOGADOR (com logs detalhados)
--------------------------------------------------------
print("⏳ Aguardando jogador entrar completamente no servidor...")

-- Etapa 1: Esperar pelo LocalPlayer
print("🔍 Verificando Players.LocalPlayer...")
local player = Players.LocalPlayer
if not player then
	print("🕓 Players.LocalPlayer ainda não existe, aguardando PlayerAdded...")
	player = Players.PlayerAdded:Wait()
end
print("✅ LocalPlayer detectado:", player.Name)

-- Etapa 2: Esperar o Character
print("🔍 Aguardando Character ser criado...")
local character = player.Character or player.CharacterAdded:Wait()
print("✅ Character detectado:", character.Name)

-- Etapa 3: Esperar o Humanoid
print("🔍 Procurando Humanoid dentro do Character...")
if not character:FindFirstChild("Humanoid") then
	print("🕓 Humanoid ainda não encontrado, aguardando...")
	character:WaitForChild("Humanoid")
end
print("✅ Humanoid encontrado.")

-- Etapa 4: Esperar CharacterAppearanceLoaded (se disponível)
if player.CharacterAppearanceLoaded then
	print("🔍 Aguardando CharacterAppearanceLoaded finalizar...")
	local ok = pcall(function()
		player.CharacterAppearanceLoaded:Wait()
	end)
	if ok then
		print("✅ Aparência completamente carregada.")
	else
		print("⚠️ Falha leve ao aguardar CharacterAppearanceLoaded (pode ser ignorado).")
	end
else
	print("ℹ️ player.CharacterAppearanceLoaded não disponível neste ambiente.")
end

-- Etapa 5: Esperar o jogador tocar o chão
print("🔍 Aguardando o jogador tocar o chão...")
local humanoid = character:WaitForChild("Humanoid")
repeat
	task.wait(0.2)
	print("🦶 Ainda no ar... aguardando FloorMaterial mudar de Air.")
until humanoid.FloorMaterial ~= Enum.Material.Air
print("✅ Jogador agora está tocando o chão.")

-- Etapa 6: Esperar mapa carregar
print("🔍 Aguardando Workspace.Plots ser carregado...")
repeat
	task.wait(0.5)
	print("🗺️ Verificando Workspace.Plots...")
until Workspace:FindFirstChild("Plots")
print("✅ Workspace.Plots carregado com sucesso.")
print("🚀 Tudo carregado! Iniciando execução principal...")

--------------------------------------------------------
-- GERA ID ÚNICO
--------------------------------------------------------
local SESSION_ID = "session_" .. HttpService:GenerateGUID(false)
print("🆔 Sessão iniciada:", SESSION_ID)

--------------------------------------------------------
-- CONVERSÃO DE TEXTO
--------------------------------------------------------
local function converterTextoGerado(texto)
	texto = texto:upper()
	local valor = texto:match("%$([%d%.]+)")
	local sufixo = texto:match("%d+([KMB])/S") or ""
	valor = tonumber(valor)
	if not valor then return 0 end
	if sufixo == "K" then valor *= 1_000
	elseif sufixo == "M" then valor *= 1_000_000
	elseif sufixo == "B" then valor *= 1_000_000_000 end
	return valor
end

--------------------------------------------------------
-- VERIFICAÇÃO COMPLETA
--------------------------------------------------------
local function checarBrainrots(limite)
	local encontrados = {}
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then return encontrados end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local podiums = plot:FindFirstChild("AnimalPodiums")
		if podiums then
			for _, podium in ipairs(podiums:GetChildren()) do
				for _, obj in ipairs(podium:GetDescendants()) do
					if (obj:IsA("TextLabel") or obj:IsA("TextBox")) and obj.Text and obj.Text:find("/s") then
						local valor = converterTextoGerado(obj.Text)
						if valor >= limite then
							local displayNameObj
							if obj.Name == "Generation" and obj.Parent then
								displayNameObj = obj.Parent:FindFirstChild("DisplayName")
							else
								local caminho = obj:GetFullName()
								local caminhoDisplay = caminho:gsub("%.Generation$", ".DisplayName")
								pcall(function()
									displayNameObj = game:FindFirstChild(caminhoDisplay)
								end)
							end

							local nome = "Desconhecido"
							if displayNameObj and displayNameObj:IsA("TextLabel") then
								nome = displayNameObj.Text
							end

							table.insert(encontrados, {nome = nome, valor = valor})
						end
					end
				end
			end
		end
	end
	return encontrados
end

--------------------------------------------------------
-- SOM
--------------------------------------------------------
local function tocarSom()
	local som = Instance.new("Sound")
	som.SoundId = SOM_ID
	som.Volume = 2
	som.PlayOnRemove = true
	som.Parent = Workspace
	som:Destroy()
end

--------------------------------------------------------
-- SAFE REQUEST
--------------------------------------------------------
local function safeRequest(url)
	task.wait(REQUEST_DELAY)
	local response = req({Url = url, Method = "GET"})
	if not response or not response.Success then
		warn("❌ Falha na requisição HTTP.")
		return nil
	end
	return response
end

--------------------------------------------------------
-- RESERVAR SERVIDOR
--------------------------------------------------------
local function reserveServer()
	local url = string.format("%s/reserveServer?placeId=%s&sessionId=%s&minPlayers=1&maxPlayers=8",
		PROXY_URL, JOGO_ID, SESSION_ID)
	local response = safeRequest(url)
	if not response then return nil end
	local data = HttpService:JSONDecode(response.Body or response.body)
	if not data.success then return nil end
	return data.server
end

--------------------------------------------------------
-- ENVIAR PARA APP CENTRAL (com delay)
--------------------------------------------------------
local function enviarParaAppCentral(nome, valor, jobId)
	local payload = {
		jobId = jobId or game.JobId,
		nome = nome,
		valor = valor,
		vps = VPS_ID,
		timestamp = os.time()
	}

	local ok, res = pcall(function()
		return req({
			Url = APP_URL,
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode(payload)
		})
	end)

	if ok then
		print("📡 Enviado ao app central:", nome, valor, "(JobID:", game.JobId .. ")")
	else
		warn("❌ Falha ao enviar para app central")
	end

	task.wait(3)
end

--------------------------------------------------------
-- LOOP PRINCIPAL
--------------------------------------------------------
print("🔎 Primeira verificação completa dos Brainrots...")

local brainrots = checarBrainrots(LIMITE_GERACAO)

if #brainrots > 0 then
	tocarSom()
	for _, br in ipairs(brainrots) do
		enviarParaAppCentral(br.nome, br.valor, game.JobId)
	end
else
	print("❌ Nenhum Brainrot lucrativo encontrado.")
end

while true do
	print("🌐 Tentando trocar de servidor...")

	local server = reserveServer()
	if server then
		print("➡️ Teleportando para novo servidor:", server.id)
		pcall(function()
			TeleportService:TeleportToPlaceInstance(JOGO_ID, server.id, Players.LocalPlayer)
		end)
	else
		warn("❌ Nenhum servidor disponível. Tentará novamente em 5 segundos.")
	end

	task.wait(1)
end
