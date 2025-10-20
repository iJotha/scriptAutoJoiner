--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:3000"
local APP_URL = "https://renderbots.onrender.com/api/report"
local VPS_ID = "vps_" .. game.JobId
local REQUEST_DELAY = 1.0 -- agora requisita a cada 1 segundo
local MAIN_LOOP_WAIT = 0.5

--------------------------------------------------------
-- ⏳ AGUARDAR O JOGO CARREGAR (forma reativa e confiável)
--------------------------------------------------------
print("⏳ Aguardando o jogo carregar completamente...")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Workspace = game:GetService("Workspace")

-- Espera o objeto "Plots" realmente existir no workspace
if not Workspace:FindFirstChild("Plots") then
	print("🧱 Aguardando objeto 'Plots' ser criado no Workspace...")
	repeat
		local child = Workspace.ChildAdded:Wait()
		if child.Name == "Plots" then
			break
		end
	until Workspace:FindFirstChild("Plots")
end

-- Espera os podiums internos carregarem (mapa completo)
local plots = Workspace:WaitForChild("Plots")
repeat
	task.wait(0.5)
until #plots:GetChildren() > 0

print("🚀 Jogo e mapas totalmente carregados! Iniciando execução...")

--------------------------------------------------------
-- SERVIÇOS & REQ
--------------------------------------------------------
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local req = request or http_request
if not req then
	warn("Exploit não suporta request")
	return
end

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
	local url = string.format(
		"%s/reserveServer?placeId=%s&sessionId=%s&minPlayers=1&maxPlayers=8",
		PROXY_URL,
		JOGO_ID,
		SESSION_ID
	)
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
print("🔎 Verificação completa dos Brainrots...")

local brainrots = checarBrainrots(LIMITE_GERACAO)

if #brainrots > 0 then
	tocarSom()
	for _, br in ipairs(brainrots) do
		enviarParaAppCentral(br.nome, br.valor, game.JobId)
	end
else
	print("❌ Nenhum Brainrot lucrativo encontrado.")
end

-- 🌐 Após a verificação, começa a requisitar 1x por segundo ao proxy
while true do
	print("🌐 Tentando trocar de servidor...")
	local server = reserveServer()

	if server then
		print("➡️ Teleportando para novo servidor:", server.id)
		local ok, err = pcall(function()
			TeleportService:TeleportToPlaceInstance(JOGO_ID, server.id, Players.LocalPlayer)
		end)

		if not ok then
			warn("⚠️ Falha ao teleportar:", err)
			print("⏳ Aguardando 11 segundos antes da próxima tentativa (falha de teleport).")
			task.wait(11)
		else
			task.wait(1)
		end
	else
		warn("❌ Nenhum servidor disponível. Tentará novamente em 1 segundo.")
		task.wait(1)
	end
end
