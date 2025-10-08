--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101" -- som de notificação
local MIN_PLAYERS = 1
local MAX_PLAYERS = 8
local MAX_SERVERS_TO_COLLECT = 50 -- quantos servidores coletar antes de escolher aleatório

local REQUEST_DELAY = 0.6        -- delay entre requisições HTTP (evita 429)
local MAX_RETRIES_ON_429 = 4     -- tentativas com backoff quando 429
local MAIN_LOOP_WAIT = 0.5       -- espera curta entre iterações do loop principal

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
-- REQUISIÇÃO HTTP COM TRATAMENTO DE 429 E BACKOFF
--------------------------------------------------------
local function safeRequest(url)
	local attempt = 0
	local backoff = REQUEST_DELAY

	while attempt <= MAX_RETRIES_ON_429 do
		local ok, response = pcall(function()
			return req({Url = url, Method = "GET"})
		end)

		if not ok or not response then
			warn("❌ Requisição falhou (pcall):", tostring(response))
			-- espera antes de tentar novamente (pequeno backoff)
			task.wait(backoff)
			attempt = attempt + 1
			backoff = backoff * 1.5
		else
			-- alguns executores usam response.Success / response.StatusCode
			local status = response.StatusCode or response.statusCode or (response.Success and 200) or 0

			-- se 429 -> esperar e tentar novamente (exponential backoff)
			if status == 429 then
				warn("⚠️ Too Many Requests (429). Aguardando " .. tostring(backoff) .. "s e tentando de novo.")
				task.wait(backoff)
				attempt = attempt + 1
				backoff = backoff * 1.8
			else
				-- sucesso (ou outro erro de status, mas tentamos decodificar o Body)
				if not response.Body and response.body then
					response.Body = response.body
				end
				return response
			end
		end
	end

	-- após retries
	return nil
end

--------------------------------------------------------
-- FUNÇÃO DE BUSCA DE SERVIDOR (coletar até MAX_SERVERS_TO_COLLECT)
-- mantém a lógica recursiva do seu código original
--------------------------------------------------------
local function findRandomServer(cursor, foundServers)
	foundServers = foundServers or {}

	local url = string.format(
		"https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100%s",
		JOGO_ID,
		cursor and ("&cursor=" .. cursor) or ""
	)

	local response = safeRequest(url)
	if not response then
		warn("Erro ao buscar servidores (safeRequest retornou nil).")
		return false
	end

	-- alguns executores retornam tabela com Body, outros com .Body string
	if not response.Body and response.body then
		response.Body = response.body
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	if not ok or not data then
		warn("Falha ao decodificar JSON da resposta.")
		return false
	end

	-- coleta servidores válidos
	for _, server in ipairs(data.data or {}) do
		if server.playing == MIN_PLAYERS and server.maxPlayers == MAX_PLAYERS then
			table.insert(foundServers, server.id)
			if #foundServers >= MAX_SERVERS_TO_COLLECT then
				break
			end
		end
	end

	-- se ainda não coletou o suficiente e existir próxima página, continua (com delay)
	if #foundServers < MAX_SERVERS_TO_COLLECT and data.nextPageCursor then
		task.wait(REQUEST_DELAY) -- <-- delay entre páginas (evita 429)
		return findRandomServer(data.nextPageCursor, foundServers)
	else
		if #foundServers == 0 then
			warn("Nenhum servidor com " .. MIN_PLAYERS .. "/" .. MAX_PLAYERS .. " encontrado.")
			return false
		end

		-- escolhe aleatoriamente e teleporta
		math.randomseed(tick() + os.time())
		local randomIndex = math.random(1, #foundServers)
		local serverId = foundServers[randomIndex]
		print("Servidor aleatório encontrado! Teleportando para:", serverId)
		pcall(function()
			TeleportService:TeleportToPlaceInstance(JOGO_ID, serverId, Players.LocalPlayer)
		end)
		return true
	end
end

--------------------------------------------------------
-- LOOP PRINCIPAL (sem wait de 15s; só um pequeno MAIN_LOOP_WAIT)
--------------------------------------------------------
task.wait(5) -- espera inicial para o jogo carregar

while true do
	if existeBrainrotAcimaDoLimite(LIMITE_GERACAO) then
		print("💰 Brainrot lucrativo detectado! (+10M/s)")
		tocarSom()
	else
		print("🔁 Nenhum Brainrot lucrativo. Buscando servidor aleatório...")
		findRandomServer()
	end

	-- espera curta entre iterações (não causa 429; controle real do rate-limit é REQUEST_DELAY)
	task.wait(MAIN_LOOP_WAIT)
end
