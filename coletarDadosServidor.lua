--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:3000"
local APP_URL = "http://127.0.0.1:3000/api/report"
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
local SESSION_ID = "vps_" .. HttpService:GenerateGUID(false):sub(1, 8)
print("🆔 Sessão iniciada:", SESSION_ID)

--------------------------------------------------------
-- FUNÇÕES DE CONVERSÃO
--------------------------------------------------------
local function converterTextoGerado(texto)
	texto = texto:upper()
	local valor = texto:match("%$([%d%.]+)")
	local sufixo = texto:match("%d+([KMB])/S") or ""
	valor = tonumber(valor)
	if not valor then return 0 end
	if sufixo == "K" then
		valor = valor * 1_000
	elseif sufixo == "M" then
		valor = valor * 1_000_000
	elseif sufixo == "B" then
		valor = valor * 1_000_000_000
	end
	return valor
end

--------------------------------------------------------
-- COLETA TODOS OS BRAINROTS ACIMA DO LIMITE
--------------------------------------------------------
local function coletarBrainrotsAcimaDoLimite(limite)
	local encontrados = {}
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then return encontrados end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local podiums = plot:FindFirstChild("AnimalPodiums")
		if podiums then
			for _, podium in ipairs(podiums:GetChildren()) do
				local nomeAnimal = podium.Name or "Desconhecido"
				for _, obj in ipairs(podium:GetDescendants()) do
					if obj:IsA("TextLabel") and obj.Text and obj.Text:find("/s") then
						local valor = converterTextoGerado(obj.Text)
						if valor >= limite then
							table.insert(encontrados, {
								nome = nomeAnimal,
								valor = valor
							})
						end
					end
				end
			end
		end
	end
	return encontrados
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
-- REQUEST COM DELAY FIXO
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
-- ENVIA RELATÓRIO AO APP CENTRAL
--------------------------------------------------------
local function enviarBrainrotAoApp(nome, valor)
	local timestamp = os.time()
	local body = HttpService:JSONEncode({
		jobId = game.JobId,
		nome = nome,
		valor = valor,
		vps = SESSION_ID,
		timestamp = timestamp
	})
	local response = req({
		Url = APP_URL,
		Method = "POST",
		Headers = {["Content-Type"] = "application/json"},
		Body = body
	})
	if response and response.Success then
		print(string.format("[📤] Enviado ao app: %s - %.0f", nome, valor))
	else
		warn("❌ Falha ao enviar brainrot ao app central.")
	end
end

--------------------------------------------------------
-- SOLICITA SERVIDOR AO PROXY
--------------------------------------------------------
local function reserveServer()
	local url = string.format("%s/reserveServer?placeId=%s&sessionId=%s", PROXY_URL, JOGO_ID, SESSION_ID)
	local response = safeRequest(url)
	if not response then return nil end

	local body = response.Body or response.body
	local data = HttpService:JSONDecode(body)
	if not data.success then
		warn("❌ Proxy retornou erro: " .. (data.message or data.error or "unknown"))
		return nil
	end
	return data.server
end

--------------------------------------------------------
-- LOOP PRINCIPAL
--------------------------------------------------------
task.wait(5)

while true do
	print("🔍 Checando brainrots...")
	local brainrots = coletarBrainrotsAcimaDoLimite(LIMITE_GERACAO)

	if #brainrots > 0 then
		print(string.format("💰 %d brainrots lucrativos encontrados (≥10M/s)", #brainrots))
		tocarSom()

		for _, b in ipairs(brainrots) do
			print(string.format("   -> %s | $%.0f/s", b.nome, b.valor))
			enviarBrainrotAoApp(b.nome, b.valor)
			task.wait(0.5) -- pausa entre envios
		end

		print("⏳ Aguardando antes de trocar de servidor...")
		task.wait(3)

		local server = reserveServer()
		if server then
			print("🚀 Trocando para novo servidor:", server.id)
			task.wait(1)
			pcall(function()
				TeleportService:TeleportToPlaceInstance(JOGO_ID, server.id, Players.LocalPlayer)
			end)
			break -- interrompe o loop após o teleporte
		else
			warn("❌ Nenhum servidor disponível. Tentará novamente.")
		end
	else
		print("🔁 Nenhum brainrot lucrativo encontrado.")
	end

	task.wait(MAIN_LOOP_WAIT)
end
