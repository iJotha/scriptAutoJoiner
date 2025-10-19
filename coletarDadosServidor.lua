--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:3000"
local APP_URL = "https://renderbots.onrender.com/api/report"
local VPS_ID = "vps_" .. game.JobId

-- Frequência das requisições (1 requisição por segundo)
local REQUEST_DELAY = 1.0
-- Delay entre cada tentativa de teleporte caso falhe
local RETRY_DELAY = 5.0

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
					if (obj:IsA("TextLabel") or obj:IsA("TextBox")) and obj.Text and obj.Text:find("/S") then
						local valor = converterTextoGerado(obj.Text)
						if valor >= limite then
							local displayNameObj
							if obj.Name == "Generation" and obj.Parent then
								displayNameObj = obj.Parent:FindFirstChild("DisplayName")
							end
							local nome = (displayNameObj and displayNameObj:IsA("TextLabel") and displayNameObj.Text) or "Desconhecido"
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
	local ok, response = pcall(function()
		return req({Url = url, Method = "GET"})
	end)
	if not ok or not response or not response.Success then
		return nil
	end
	return response
end

--------------------------------------------------------
-- RESERVAR SERVIDOR
--------------------------------------------------------
local function reserveServer()
	local url = string.format("%s/reserveServer?placeId=%s&sessionId=%s", PROXY_URL, JOGO_ID, SESSION_ID)
	local response = safeRequest(url)
	if not response then return nil end

	local data = HttpService:JSONDecode(response.Body or response.body)
	if not data or not data.success or not data.server then
		return nil
	end

	return data.server
end

--------------------------------------------------------
-- ENVIAR PARA APP CENTRAL
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
end

--------------------------------------------------------
-- LOOP INICIAL
--------------------------------------------------------
print("🔎 Verificação inicial dos Brainrots...")
local brainrots = checarBrainrots(LIMITE_GERACAO)
if #brainrots > 0 then
	tocarSom()
	for _, br in ipairs(brainrots) do
		enviarParaAppCentral(br.nome, br.valor, game.JobId)
	end
else
	print("❌ Nenhum Brainrot lucrativo encontrado.")
end

--------------------------------------------------------
-- LOOP DE TROCA DE SERVIDOR
--------------------------------------------------------
local ultimoServerID = nil
local tentativa = 0

print("⚙️ Iniciando loop de requisições...")

while true do
	task.wait(REQUEST_DELAY)
	tentativa += 1

	local server = reserveServer()
	if server then
		-- Ignora se for o mesmo servidor recebido antes
		if ultimoServerID ~= server.id then
			print(string.format("➡️ [%d] Novo servidor recebido: %s", tentativa, server.id))
			ultimoServerID = server.id

			local ok, result = pcall(function()
				TeleportService:TeleportToPlaceInstance(JOGO_ID, server.id, Players.LocalPlayer)
			end)

			if ok then
				print("🚀 Tentando entrar no servidor:", server.id)
			else
				warn("⚠️ Falha ao teleportar. Tentará novamente em " .. RETRY_DELAY .. "s.")
				task.wait(RETRY_DELAY)
			end
		else
			print(string.format("⚠️ [%d] Servidor repetido recebido (%s), aguardando o próximo.", tentativa, server.id))
		end
	else
		print(string.format("❌ [%d] Nenhum servidor disponível. Nova tentativa em %ss.", tentativa, REQUEST_DELAY))
	end
end
