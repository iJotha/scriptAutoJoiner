
--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:3000"
local APP_URL = "https://server-nameless-mountain-5143.fly.dev/api/report"
local VPS_ID = "vps_" .. game.JobId
local REQUEST_DELAY = 2.0
local MAIN_LOOP_WAIT = 0.5

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--------------------------------------------------------
-- LISTA DE BRAINROTS IMPORTANTES (IGNORAM LIMITE)
--------------------------------------------------------
local BRAINROTS_IMPORTANTES = {
	["..."] = true,
}

--------------------------------------------------------
-- SERVIÇOS & REQ
--------------------------------------------------------
local req = request or http_request
if not req then
	warn("Exploit não suporta request")
	return
end

--------------------------------------------------------
-- Helper: executar request de forma segura (em task.spawn)
-- Evita usar pcall em coroutine que pode yield -> corrige erro de "cannot resume dead coroutine"
--------------------------------------------------------
local function performRequest(options, timeoutSeconds)
	timeoutSeconds = timeoutSeconds or 10
	local done = false
	local ok, result, err

	-- executar a requisição em uma coroutine separada
	task.spawn(function()
		local success, res = pcall(function()
			-- req pode variar entre exploits; chamamos direto
			return req(options)
		end)
		if success then
			ok = true
			result = res
		else
			ok = false
			err = res
		end
		done = true
	end)

	-- aguardar conclusão (com timeout de segurança)
	local waited = 0
	while not done and waited < timeoutSeconds do
		task.wait(0.1)
		waited = waited + 0.1
	end

	if not done then
		return false, "timeout"
	end

	if ok then
		return true, result
	else
		return false, err
	end
end

--------------------------------------------------------
-- 🔌 WEBSOCKET – ENVIO PARA O SERVIDOR CENTRAL
--------------------------------------------------------
local WS_URL = "wss://server-nameless-mountain-5143.fly.dev"

local wsLib = nil
if websocket and websocket.connect then
    wsLib = websocket.connect
elseif WebSocket and WebSocket.connect then
    wsLib = WebSocket.connect
end

local ws

local function conectarWS()
    if not wsLib then
        warn("❌ Seu exploit não possui suporte a WebSocket.")
        return
    end

    print("[VPS] Conectando ao WebSocket...")

    local ok, socket = pcall(function()
        return wsLib(WS_URL)
    end)

    if not ok or not socket then
        warn("[VPS] Falha ao conectar WS. Tentando em 5s...")
        task.wait(5)
        return conectarWS()
    end

    ws = socket
    print("[VPS] 🟢 WebSocket conectado!")

    ws.OnClose:Connect(function()
        warn("[VPS] WebSocket desconectado. Reconectando em 3s...")
        task.wait(3)
        conectarWS()
    end)
end

-- Iniciar WS async
task.spawn(conectarWS)

--------------------------------------------------------
-- Função para enviar dados via WS
--------------------------------------------------------
local function enviarViaWS(payload)
    if not ws or not ws.Send then
        warn("[VPS] WebSocket não conectado — não enviando via WS")
        return
    end

    task.spawn(function()
        local okSend, err = pcall(function()
            ws:Send(HttpService:JSONEncode(payload))
        end)

        if not okSend then
            warn("[VPS] ❌ Falha ao enviar via WebSocket:", err)
        end
    end)
end


--------------------------------------------------------
-- DELAY INICIAL
--------------------------------------------------------
print("🕒 Aguardando 5 segundos antes de iniciar o script...")
--task.wait(5)
print("✅ Delay inicial concluído. Iniciando verificação de carregamento do jogador...")

--------------------------------------------------------
-- ESPERAR O CARREGAMENTO BÁSICO DO JOGADOR
--------------------------------------------------------
print("⏳ Aguardando jogador entrar completamente no servidor...")

local player = Players.LocalPlayer
if not player then
	print("🕓 Players.LocalPlayer ainda não existe, aguardando PlayerAdded...")
	player = Players.PlayerAdded:Wait()
end
print("✅ LocalPlayer detectado:", player.Name)

local character = player.Character or player.CharacterAdded:Wait()
print("✅ Character detectado:", character.Name)

local humanoid = character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid")
print("✅ Humanoid encontrado.")
task.wait(3)
print("🚀 Jogador totalmente pronto. Iniciando execução principal...")

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
-- VERIFICAÇÃO COMPLETA (PODIUMS)
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

						if valor >= limite or BRAINROTS_IMPORTANTES[nome] then
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
-- 🔍 NOVA FUNÇÃO: VERIFICAÇÃO DE MODELOS
--------------------------------------------------------
local function checarModelos(limite)
	local encontrados = {}
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then return encontrados end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		for _, model in ipairs(plot:GetChildren()) do
			if model:IsA("Model") then
				local displayNameValue = nil
				local generationValue = nil

				for _, desc in ipairs(model:GetDescendants()) do
					if desc.Name == "DisplayName" and (desc:IsA("TextLabel") or desc:IsA("TextBox") or desc:IsA("StringValue")) then
						displayNameValue = desc.Text or desc.Value
					elseif desc.Name == "Generation" and (desc:IsA("TextLabel") or desc:IsA("TextBox") or desc:IsA("StringValue")) then
						generationValue = desc.Text or desc.Value
					end
				end

				if displayNameValue and generationValue then
					local valor = converterTextoGerado(generationValue)
					if valor >= limite or BRAINROTS_IMPORTANTES[displayNameValue] then
						table.insert(encontrados, {nome = displayNameValue, valor = valor})
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
-- SAFE REQUEST (GET) - usa performRequest
--------------------------------------------------------
local function safeRequest(url)
	task.wait(REQUEST_DELAY)
	local ok, resOrErr = performRequest({ Url = url, Method = "GET" }, 10)
	if not ok then
		warn("❌ Falha na requisição HTTP (safeRequest):", tostring(resOrErr))
		return nil
	end
	return resOrErr
end

--------------------------------------------------------
-- RESERVAR SERVIDOR
--------------------------------------------------------
local function reserveServer()
	local url = string.format("%s/reserveServer?placeId=%s&sessionId=%s&minPlayers=1&maxPlayers=8",
		PROXY_URL, JOGO_ID, SESSION_ID)
	local response = safeRequest(url)
	if not response then return nil end

	-- compatibilidade Body / body (Opção B)
	local body = response.Body or response.body
	if not body then
		warn("❌ reserveServer: resposta sem body")
		return nil
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or type(data) ~= "table" then
		warn("❌ reserveServer: JSON inválido")
		return nil
	end
	if not data.success then return nil end
	return data.server
end

--------------------------------------------------------
-- ENVIAR PARA APP CENTRAL VIA HTTP (POST)
-- usamos performRequest para evitar pcall em coroutine que yield
--------------------------------------------------------
local function enviarParaAppCentral(nome, valor, jobId)
	local payload = {
		jobId = jobId or game.JobId,
		nome = nome,
		valor = valor,
		vps = VPS_ID,
		timestamp = os.time()
	}

	-- ===== ENVIO VIA WEBSOCKET (se conectado) =====
	-- mantemos envio via WS como principal se disponível
	enviarViaWS({
		type = "server_update",
		server = payload
	})

	-- também tentamos enviar via HTTP POST para compatibilidade (opcional)
	local options = {
		Url = APP_URL,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode(payload)
	}

	-- realizar requisição de forma segura (performRequest)
	local ok, resOrErr = performRequest(options, 10)
	if ok and resOrErr then
		print("📡 Enviado via HTTP POST:", nome, valor, "(JobID:", game.JobId .. ")")
	else
		warn("❌ Falha ao enviar via HTTP POST:", tostring(resOrErr))
	end

	task.wait(3)
end

--------------------------------------------------------
-- LOOP PRINCIPAL
--------------------------------------------------------
print("🔎 Primeira verificação completa dos Brainrots...")

local encontrouBrainrot = false
local encontradosTotal = {}

local brainrots = checarBrainrots(LIMITE_GERACAO)
local modelos = checarModelos(LIMITE_GERACAO)

-- Juntar todos os resultados em uma única lista
for _, br in ipairs(brainrots) do table.insert(encontradosTotal, br) end
for _, m in ipairs(modelos) do table.insert(encontradosTotal, m) end

if #encontradosTotal > 0 then
	encontrouBrainrot = true
	tocarSom()

	-- 🔽 Ordenar em ordem decrescente de valor (maior geração primeiro)
	table.sort(encontradosTotal, function(a, b)
		return a.valor > b.valor
	end)

	-- 📤 Enviar todos após checagem
	for _, item in ipairs(encontradosTotal) do
		enviarParaAppCentral(item.nome, item.valor, game.JobId)
	end
else
	print("❌ Nenhum Brainrot lucrativo encontrado.")
end

--------------------------------------------------------
-- LOOP DE REVISTA COM TELEPORTE ENTRE CICLOS
--------------------------------------------------------
while not encontrouBrainrot do
	encontradosTotal = {}

	local brainrots = checarBrainrots(LIMITE_GERACAO)
	local modelos = checarModelos(LIMITE_GERACAO)

	for _, br in ipairs(brainrots) do table.insert(encontradosTotal, br) end
	for _, m in ipairs(modelos) do table.insert(encontradosTotal, m) end

	if #encontradosTotal > 0 then
		encontrouBrainrot = true
		tocarSom()

		table.sort(encontradosTotal, function(a, b)
			return a.valor > b.valor
		end)

		for _, item in ipairs(encontradosTotal) do
			enviarParaAppCentral(item.nome, item.valor, game.JobId)
		end

		print("✅ Brainrot ou Model lucrativo encontrado. Encerrando revista.")
	else
		print("🔁 Nenhum item encontrado neste ciclo, tentando trocar de servidor...")

		local server = reserveServer()
		if server then
			print("🌐 Teleportando para novo servidor:", server.id)
			pcall(function()
				TeleportService:TeleportToPlaceInstance(JOGO_ID, server.id, Players.LocalPlayer)
			end)
		else
			warn("❌ Nenhum servidor disponível no momento. Tentando novamente em 5 segundos.")
		end

		task.wait(1)
	end
end

--------------------------------------------------------
-- CONTINUAR SOLICITANDO SERVIDORES MESMO APÓS ENCONTRAR
--------------------------------------------------------
print("🧠 Item valioso encontrado — mantendo busca ativa por novos servidores...")

while true do
	local server = reserveServer()
	if server then
		print("🌐 Teleportando continuamente para novo servidor:", server.id)
		pcall(function()
			TeleportService:TeleportToPlaceInstance(JOGO_ID, server.id, Players.LocalPlayer)
		end)
	else
		warn("❌ Nenhum servidor disponível. Tentando novamente em 5 segundos.")
	end
	task.wait(1)
end

