--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:3000"
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
-- VERIFICA SE EXISTE BRAINROT ACIMA DO LIMITE
--------------------------------------------------------
local function existeBrainrotAcimaDoLimite(limite)
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then return false end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local podiums = plot:FindFirstChild("AnimalPodiums")
		if podiums then
			for _, podium in ipairs(podiums:GetChildren()) do
				for _, obj in ipairs(podium:GetDescendants()) do
					if obj:IsA("TextLabel") and obj.Text and obj.Text:find("/s") then
						local valor = converterTextoGerado(obj.Text)
						if valor >= limite then
							return true
						end
					end
				end
			end
		end
	end
	return false
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
-- SOLICITA SERVIDOR AO PROXY
--------------------------------------------------------
local function reserveServer()
	local url = string.format("%s/reserveServer?placeId=%s&sessionId=%s&minPlayers=1&maxPlayers=8", PROXY_URL, JOGO_ID, SESSION_ID)
	local response = safeRequest(url)
	if not response then return nil end

	local body = response.Body or response.body
	local data = HttpService:JSONDecode(body)
	if not data.success then
		warn("❌ Proxy retornou erro ou não há servidores disponíveis: " .. (data.message or data.error or "unknown"))
		return nil
	end

	return data.server
end

--------------------------------------------------------
-- LOOP PRINCIPAL
--------------------------------------------------------
task.wait(5)

while true do
	if existeBrainrotAcimaDoLimite(LIMITE_GERACAO) then
		print("💰 Brainrot lucrativo detectado! (+10M/s)")
		tocarSom()
	else
		print("🔁 Nenhum Brainrot lucrativo. Solicitando servidor aleatório ao proxy...")
		local server = reserveServer()
		if server then
			print("Servidor recebido do proxy! Teleportando para:", server.id)
			pcall(function()
				TeleportService:TeleportToPlaceInstance(JOGO_ID, server.id, Players.LocalPlayer)
			end)
		else
			warn("❌ Nenhum servidor disponível do proxy. Tentará novamente na próxima iteração.")
		end
	end
	task.wait(MAIN_LOOP_WAIT)
end
