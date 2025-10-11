--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:3000"
local APP_URL = "https://d88a7c01-bd88-445a-9261-3fa89cc6f7c4-00-2h3cc3v0bgg8e.picard.replit.dev/api/report" -- API central
local VPS_ID = "vps01"
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
-- GERA ID ÚNICO PARA ESTA SESSÃO
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
-- VERIFICAÇÃO DE BRAINROT
--------------------------------------------------------
local function verificarBrainrot(limite)
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local podiums = plot:FindFirstChild("AnimalPodiums")
		if podiums then
			for _, podium in ipairs(podiums:GetChildren()) do
				for _, obj in ipairs(podium:GetDescendants()) do
					if (obj:IsA("TextLabel") or obj:IsA("TextBox")) and obj.Text and obj.Text:find("/s") then
						local valor = converterTextoGerado(obj.Text)
						if valor >= limite then
							-- 🔍 tenta localizar o DisplayName correspondente
							local displayNameObj
							if obj.Name == "Generation" and obj.Parent then
								displayNameObj = obj.Parent:FindFirstChild("DisplayName")
							else
								-- fallback: tenta substituir o caminho
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

							print("💰 Brainrot encontrado:", nome, "(" .. valor .. ")")
							return { nome = nome, valor = valor }
						end
					end
				end
			end
		end
	end
	return nil
end

--------------------------------------------------------
-- ALERTA SONORO
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
-- SOLICITA SERVIDOR AO PROXY
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
-- ENVIA DADOS AO APP CENTRAL
--------------------------------------------------------
local function enviarParaAppCentral(nome, valor, jobId)
	-- garante que jobId seja preenchido corretamente
	local currentJobId = jobId or game.JobId

	local payload = {
		jobId = currentJobId, -- agora sempre envia o JobId correto
		nome = nome,
		valor = valor,
		vps = VPS_ID,
		timestamp = os.time()
	}

	local ok, res = pcall(function()
		return req({
			Url = APP_URL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload)
		})
	end)

	if ok then
		print("📡 Enviado ao app central:", nome, valor, "(JobID:", currentJobId .. ")")
	else
		warn("❌ Falha ao enviar para app central")
	end
end

--------------------------------------------------------
-- LOOP PRINCIPAL
--------------------------------------------------------
task.wait(5)

while true do
	local brainrot = verificarBrainrot(LIMITE_GERACAO)
	if brainrot then
		tocarSom()
		enviarParaAppCentral(brainrot.nome, brainrot.valor, game.JobId)
	else
		print("🔁 Nenhum Brainrot lucrativo. Solicitando servidor ao proxy...")
		local server = reserveServer()
		if server then
			print("Teleportando para:", server.id)
			pcall(function()
				TeleportService:TeleportToPlaceInstance(JOGO_ID, server.id, Players.LocalPlayer)
			end)
		end
	end
	task.wait(MAIN_LOOP_WAIT)
end
