--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101" -- som de notificação
local MIN_PLAYERS = 1
local MAX_PLAYERS = 8
local MAX_SERVERS_TO_COLLECT = 50 -- quantidade máxima de servidores para coletar antes de escolher aleatório

--------------------------------------------------------
-- SERVIÇOS
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
-- FUNÇÃO DE BUSCA DE SERVIDOR (coletar até MAX_SERVERS_TO_COLLECT)
--------------------------------------------------------
local function findRandomServer(cursor, foundServers)
	foundServers = foundServers or {}

	local url = string.format(
		"https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100%s",
		JOGO_ID,
		cursor and ("&cursor=" .. cursor) or ""
	)

	local response = req({Url = url, Method = "GET"})
	if not response.Success then
		warn("Erro ao buscar servidores: " .. (response.StatusMessage or "Erro desconhecido"))
		return
	end

	local data = HttpService:JSONDecode(response.Body)
	for _, server in ipairs(data.data) do
		if server.playing == MIN_PLAYERS and server.maxPlayers == MAX_PLAYERS then
			table.insert(foundServers, server.id)
			if #foundServers >= MAX_SERVERS_TO_COLLECT then
				break
			end
		end
	end

	if #foundServers < MAX_SERVERS_TO_COLLECT and data.nextPageCursor then
		return findRandomServer(data.nextPageCursor, foundServers)
	else
		if #foundServers == 0 then
			warn("Nenhum servidor com " .. MIN_PLAYERS .. "/" .. MAX_PLAYERS .. " encontrado.")
			return false
		end

		-- Escolhe aleatoriamente um servidor da lista
		local randomIndex = math.random(1, #foundServers)
		local serverId = foundServers[randomIndex]
		print("Servidor aleatório encontrado! Teleportando para:", serverId)
		TeleportService:TeleportToPlaceInstance(JOGO_ID, serverId, Players.LocalPlayer)
		return true
	end
end

--------------------------------------------------------
-- LOOP PRINCIPAL
--------------------------------------------------------
task.wait(5) -- tempo para carregar o jogo

while true do
	if existeBrainrotAcimaDoLimite(LIMITE_GERACAO) then
		print("💰 Brainrot lucrativo detectado! (+10M/s)")
		tocarSom()
	else
		print("🔁 Nenhum Brainrot lucrativo. Buscando servidor aleatório...")
		findRandomServer()
	end
	task.wait(15)
end
