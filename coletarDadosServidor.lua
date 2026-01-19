
--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:8081"
local APP_URL = "https://sticker-fundamentals-statutes-mason.trycloudflare.com/api/report"
local VPS_ID = "vps_" .. game.JobId
local REQUEST_DELAY = 2.0
local MAIN_LOOP_WAIT = 0.5

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

print("🚀 [VPS] Script iniciado | JobId:", game.JobId)

--------------------------------------------------------
-- LISTA DE BRAINROTS IMPORTANTES
--------------------------------------------------------
local BRAINROTS_IMPORTANTES = {
	["Bunito Bunito Spinito"] = true,
}

--------------------------------------------------------
-- LISTA DE BRAINROTS BLOQUEADOS (NUNCA ENVIAR)
--------------------------------------------------------
local BRAINROTS_BLOQUEADOS = {
	["Lucky Block"] = true,
}

--------------------------------------------------------
-- SERVIÇOS & REQ
--------------------------------------------------------
local req = request or http_request
if not req then
	warn("❌ [VPS] Exploit não suporta request")
	return
end

--------------------------------------------------------
-- SAFE REQUEST
--------------------------------------------------------
local function performRequest(options, timeoutSeconds)
	timeoutSeconds = timeoutSeconds or 10
	local done = false
	local ok, result, err

	task.spawn(function()
		local success, res = pcall(function()
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

	local waited = 0
	while not done and waited < timeoutSeconds do
		task.wait(0.1)
		waited += 0.1
	end

	if not done then
		warn("⏱️ [HTTP] Timeout")
		return false, "timeout"
	end

	return ok, ok and result or err
end

--------------------------------------------------------
-- 🔌 WEBSOCKET
--------------------------------------------------------
local WS_URL = "wss://sticker-fundamentals-statutes-mason.trycloudflare.com"
local wsLib = (websocket and websocket.connect) or (WebSocket and WebSocket.connect)
local ws

local function conectarWS()
	if not wsLib then
		warn("❌ [WS] Exploit sem suporte a WebSocket")
		return
	end

	print("🔌 [WS] Conectando...")

	local ok, socket = pcall(function()
		return wsLib(WS_URL)
	end)

	if not ok or not socket then
		warn("⚠️ [WS] Falha ao conectar. Tentando novamente em 5s...")
		task.wait(5)
		return conectarWS()
	end

	ws = socket
	print("🟢 [WS] Conectado com sucesso")

	ws.OnClose:Connect(function()
		warn("🔴 [WS] Conexão encerrada. Reconectando em 3s...")
		task.wait(0.1)
		conectarWS()
	end)
end

task.spawn(conectarWS)

local function enviarViaWS(payload)
	if not ws or not ws.Send then
		warn("⚠️ [WS] Não conectado — envio ignorado")
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			ws:Send(HttpService:JSONEncode(payload))
		end)

		if ok then
			print("📡 [WS] Dados enviados")
		else
			warn("❌ [WS] Falha no envio:", err)
		end
	end)
end

--------------------------------------------------------
-- ESPERAR PLAYER
--------------------------------------------------------
print("⏳ [PLAYER] Aguardando LocalPlayer...")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("Humanoid")
print("✅ [PLAYER] Jogador pronto:", player.Name)
task.wait(2)

--------------------------------------------------------
-- CONVERSÃO (GENERATION)
--------------------------------------------------------
local function converterTextoGerado(texto)
	texto = texto:upper()
	local valor = texto:match("([%d%.]+)")
	local sufixo = texto:match("([KMB])/S") or texto:match("([KMB])$")
	valor = tonumber(valor)
	if not valor then return 0 end
	if sufixo == "K" then valor *= 1e3
	elseif sufixo == "M" then valor *= 1e6
	elseif sufixo == "B" then valor *= 1e9 end
	return valor
end

--------------------------------------------------------
-- 🔍 REVISTA (DEBRIS) - NOVA ESTRUTURA
--------------------------------------------------------
local function checarBrainrotsDebris(limite)
	print("🔍 [SCAN] Iniciando varredura em Debris...")
	local encontrados = {}

	local debris = Workspace:FindFirstChild("Debris")
	if not debris then
		warn("⚠️ [SCAN] Pasta Debris não encontrada")
		return encontrados
	end

	for _, obj in ipairs(debris:GetDescendants()) do
		if obj.Name == "FastOverheadTemplate" then
			local overhead = obj:FindFirstChild("AnimalOverhead")
			if not overhead then continue end

			local displayName = overhead:FindFirstChild("DisplayName")
			local generation = overhead:FindFirstChild("Generation")

			if displayName and generation
				and displayName:IsA("TextLabel")
				and generation:IsA("TextLabel") then

				local nome = displayName.Text
				local valor = converterTextoGerado(generation.Text)

				-- ⛔ BLOQUEIO ABSOLUTO
				if BRAINROTS_BLOQUEADOS[nome] then
					print(string.format("🚫 [SKIP] %s bloqueado (blacklist)", nome))
					continue
				end

				-- ✅ REGRA DE ENVIO
				if valor >= limite or BRAINROTS_IMPORTANTES[nome] then
					print(string.format("💰 [FOUND] %s | Valor: %s", nome, valor))
					table.insert(encontrados, { nome = nome, valor = valor })
				end
			end
		end
	end

	print("📊 [SCAN] Total encontrados:", #encontrados)
	return encontrados
end

--------------------------------------------------------
-- SOM
--------------------------------------------------------
local function tocarSom()
	print("🔔 [SOUND] Tocando alerta sonoro")
	local som = Instance.new("Sound")
	som.SoundId = SOM_ID
	som.Volume = 2
	som.PlayOnRemove = true
	som.Parent = Workspace
	som:Destroy()
end

--------------------------------------------------------
-- RESERVAR SERVIDOR
--------------------------------------------------------
local function reserveServer()
	print("🌐 [SERVER] Solicitando novo servidor...")
	local url = string.format(
		"%s/reserveServer?placeId=%s&sessionId=%s&minPlayers=1&maxPlayers=8",
		PROXY_URL, JOGO_ID, "session_" .. game.JobId
	)

	local ok, res = performRequest({ Url = url, Method = "GET" }, 10)
	if not ok or not res then
		warn("❌ [SERVER] Falha ao reservar servidor")
		return nil
	end

	local body =
		res.Body
		or res.body
		or res.ResponseBody
		or res.response
		or res.Response

	if type(body) ~= "string" then
		warn("❌ [SERVER] Corpo da resposta inválido:", typeof(body))
		return nil
	end

	print("🧪 [DEBUG] Body recebido:", body)

	local success, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	if not success then
		warn("❌ [SERVER] Falha ao decodificar JSON do proxy")
		return nil
	end

	if not data.success then
		warn("⚠️ [SERVER] Proxy recusou servidor:", data.message or "sem mensagem")
		return nil
	end


	print("✅ [SERVER] Servidor reservado:", data.server.id)
	return data.server

end

--------------------------------------------------------
-- ENVIAR PARA APP CENTRAL
--------------------------------------------------------
local function enviarParaAppCentral(nome, valor, jobId)
	print(string.format("📤 [SEND] Enviando %s | Generation %s", nome, valor))

	local payload = {
		jobId = jobId or game.JobId,
		nome = nome,
		valor = valor,
		vps = VPS_ID,
		timestamp = os.time()
	}

	enviarViaWS({ type = "server_update", server = payload })

	performRequest({
		Url = APP_URL,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode(payload)
	}, 10)
end

--------------------------------------------------------
-- LOOP PRINCIPAL (MESMA LÓGICA DO SCRIPT ANTIGO)
--------------------------------------------------------
--------------------------------------------------------
-- LOOP PRINCIPAL (CORRIGIDO)
--------------------------------------------------------
print("🔁 [MAIN] Iniciando loop principal")

local brainrotJaEncontrado = false

while true do
	--------------------------------------------------------
	-- 1️⃣ REVISTA (APENAS SE AINDA NÃO ACHOU)
	--------------------------------------------------------
	local encontrados = {}

	if not brainrotJaEncontrado then
		encontrados = checarBrainrotsDebris(LIMITE_GERACAO)
	end

	--------------------------------------------------------
	-- 2️⃣ SE ENCONTROU BRAINROTS PELA PRIMEIRA VEZ
	--------------------------------------------------------
	if not brainrotJaEncontrado and #encontrados > 0 then
		brainrotJaEncontrado = true
		tocarSom()

		-- Ordena do MAIOR para o MENOR
		table.sort(encontrados, function(a, b)
			return a.valor > b.valor
		end)

		print("📤 [MAIN] Enviando brainrots um por um...")

		for i, item in ipairs(encontrados) do
			print(string.format(
				"📡 [QUEUE] (%d/%d) %s | Generation %s",
				i, #encontrados, item.nome, item.valor
			))

			enviarParaAppCentral(item.nome, item.valor, game.JobId)
			task.wait(0.3)
		end

		print("✅ [MAIN] Brainrots enviados. A partir de agora NÃO haverá novas revistas.")
	end

	--------------------------------------------------------
	-- 3️⃣ APENAS TROCAR DE SERVIDOR (SEM SCAN)
	--------------------------------------------------------
	local entrouEmServidor = false

	while not entrouEmServidor do
		print("🌐 [MAIN] Tentando obter servidor via proxy...")
		local server = reserveServer()

		if server and server.id then
			print("🚪 [TP] Teleportando para servidor:", server.id)

			local ok = pcall(function()
				TeleportService:TeleportToPlaceInstance(
					JOGO_ID,
					server.id,
					player
				)
			end)

			if ok then
				entrouEmServidor = true
				print("🟢 [TP] Teleporte iniciado com sucesso")
				break
			else
				warn("❌ [TP] Falha no Teleport — tentando outro servidor")
			end
		else
			warn("⚠️ [MAIN] Proxy não retornou servidor válido")
		end

		-- ⛔ NÃO FAZ MAIS SCAN AQUI
		task.wait(0.5)
	end

	--------------------------------------------------------
	-- Segurança
	--------------------------------------------------------
	task.wait(MAIN_LOOP_WAIT)
end



--------------------------------------------------------
-- CONFIGURAÇÕES
--------------------------------------------------------
local LIMITE_GERACAO = 10_000_000 -- 10M/s
local JOGO_ID = game.PlaceId
local SOM_ID = "rbxassetid://9118823101"
local PROXY_URL = "http://127.0.0.1:8081"
local APP_URL = "https://sticker-fundamentals-statutes-mason.trycloudflare.com/api/report"
local VPS_ID = "vps_" .. game.JobId
local REQUEST_DELAY = 2.0
local MAIN_LOOP_WAIT = 0.5

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

print("🚀 [VPS] Script iniciado | JobId:", game.JobId)

--------------------------------------------------------
-- LISTA DE BRAINROTS IMPORTANTES
--------------------------------------------------------
local BRAINROTS_IMPORTANTES = {
	["Bunito Bunito Spinito"] = true,
}

--------------------------------------------------------
-- LISTA DE BRAINROTS BLOQUEADOS (NUNCA ENVIAR)
--------------------------------------------------------
local BRAINROTS_BLOQUEADOS = {
	["Lucky Block"] = true,
}

--------------------------------------------------------
-- SERVIÇOS & REQ
--------------------------------------------------------
local req = request or http_request
if not req then
	warn("❌ [VPS] Exploit não suporta request")
	return
end

--------------------------------------------------------
-- SAFE REQUEST
--------------------------------------------------------
local function performRequest(options, timeoutSeconds)
	timeoutSeconds = timeoutSeconds or 10
	local done = false
	local ok, result, err

	task.spawn(function()
		local success, res = pcall(function()
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

	local waited = 0
	while not done and waited < timeoutSeconds do
		task.wait(0.1)
		waited += 0.1
	end

	if not done then
		warn("⏱️ [HTTP] Timeout")
		return false, "timeout"
	end

	return ok, ok and result or err
end

--------------------------------------------------------
-- 🔌 WEBSOCKET
--------------------------------------------------------
local WS_URL = "wss://sticker-fundamentals-statutes-mason.trycloudflare.com"
local wsLib = (websocket and websocket.connect) or (WebSocket and WebSocket.connect)
local ws

local function conectarWS()
	if not wsLib then
		warn("❌ [WS] Exploit sem suporte a WebSocket")
		return
	end

	print("🔌 [WS] Conectando...")

	local ok, socket = pcall(function()
		return wsLib(WS_URL)
	end)

	if not ok or not socket then
		warn("⚠️ [WS] Falha ao conectar. Tentando novamente em 5s...")
		task.wait(5)
		return conectarWS()
	end

	ws = socket
	print("🟢 [WS] Conectado com sucesso")

	ws.OnClose:Connect(function()
		warn("🔴 [WS] Conexão encerrada. Reconectando em 3s...")
		task.wait(0.1)
		conectarWS()
	end)
end

task.spawn(conectarWS)

local function enviarViaWS(payload)
	if not ws or not ws.Send then
		warn("⚠️ [WS] Não conectado — envio ignorado")
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			ws:Send(HttpService:JSONEncode(payload))
		end)

		if ok then
			print("📡 [WS] Dados enviados")
		else
			warn("❌ [WS] Falha no envio:", err)
		end
	end)
end

--------------------------------------------------------
-- ESPERAR PLAYER
--------------------------------------------------------
print("⏳ [PLAYER] Aguardando LocalPlayer...")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("Humanoid")
print("✅ [PLAYER] Jogador pronto:", player.Name)
task.wait(2)

--------------------------------------------------------
-- CONVERSÃO (GENERATION)
--------------------------------------------------------
local function converterTextoGerado(texto)
	texto = texto:upper()
	local valor = texto:match("([%d%.]+)")
	local sufixo = texto:match("([KMB])/S") or texto:match("([KMB])$")
	valor = tonumber(valor)
	if not valor then return 0 end
	if sufixo == "K" then valor *= 1e3
	elseif sufixo == "M" then valor *= 1e6
	elseif sufixo == "B" then valor *= 1e9 end
	return valor
end

--------------------------------------------------------
-- 🔍 REVISTA (DEBRIS) - NOVA ESTRUTURA
--------------------------------------------------------
local function checarBrainrotsDebris(limite)
	print("🔍 [SCAN] Iniciando varredura em Debris...")
	local encontrados = {}

	local debris = Workspace:FindFirstChild("Debris")
	if not debris then
		warn("⚠️ [SCAN] Pasta Debris não encontrada")
		return encontrados
	end

	for _, obj in ipairs(debris:GetDescendants()) do
		if obj.Name == "FastOverheadTemplate" then
			local overhead = obj:FindFirstChild("AnimalOverhead")
			if not overhead then continue end

			local displayName = overhead:FindFirstChild("DisplayName")
			local generation = overhead:FindFirstChild("Generation")

			if displayName and generation
				and displayName:IsA("TextLabel")
				and generation:IsA("TextLabel") then

				local nome = displayName.Text
				local valor = converterTextoGerado(generation.Text)

				-- ⛔ BLOQUEIO ABSOLUTO
				if BRAINROTS_BLOQUEADOS[nome] then
					print(string.format("🚫 [SKIP] %s bloqueado (blacklist)", nome))
					continue
				end

				-- ✅ REGRA DE ENVIO
				if valor >= limite or BRAINROTS_IMPORTANTES[nome] then
					print(string.format("💰 [FOUND] %s | Valor: %s", nome, valor))
					table.insert(encontrados, { nome = nome, valor = valor })
				end
			end
		end
	end

	print("📊 [SCAN] Total encontrados:", #encontrados)
	return encontrados
end

--------------------------------------------------------
-- SOM
--------------------------------------------------------
local function tocarSom()
	print("🔔 [SOUND] Tocando alerta sonoro")
	local som = Instance.new("Sound")
	som.SoundId = SOM_ID
	som.Volume = 2
	som.PlayOnRemove = true
	som.Parent = Workspace
	som:Destroy()
end

--------------------------------------------------------
-- RESERVAR SERVIDOR
--------------------------------------------------------
local function reserveServer()
	print("🌐 [SERVER] Solicitando novo servidor...")
	local url = string.format(
		"%s/reserveServer?placeId=%s&sessionId=%s&minPlayers=1&maxPlayers=8",
		PROXY_URL, JOGO_ID, "session_" .. game.JobId
	)

	local ok, res = performRequest({ Url = url, Method = "GET" }, 10)
	if not ok or not res then
		warn("❌ [SERVER] Falha ao reservar servidor")
		return nil
	end

	local body =
		res.Body
		or res.body
		or res.ResponseBody
		or res.response
		or res.Response

	if type(body) ~= "string" then
		warn("❌ [SERVER] Corpo da resposta inválido:", typeof(body))
		return nil
	end

	print("🧪 [DEBUG] Body recebido:", body)

	local success, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	if not success then
		warn("❌ [SERVER] Falha ao decodificar JSON do proxy")
		return nil
	end

	if not data.success then
		warn("⚠️ [SERVER] Proxy recusou servidor:", data.message or "sem mensagem")
		return nil
	end


	print("✅ [SERVER] Servidor reservado:", data.server.id)
	return data.server

end

--------------------------------------------------------
-- ENVIAR PARA APP CENTRAL
--------------------------------------------------------
local function enviarParaAppCentral(nome, valor, jobId)
	print(string.format("📤 [SEND] Enviando %s | Generation %s", nome, valor))

	local payload = {
		jobId = jobId or game.JobId,
		nome = nome,
		valor = valor,
		vps = VPS_ID,
		timestamp = os.time()
	}

	enviarViaWS({ type = "server_update", server = payload })

	performRequest({
		Url = APP_URL,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode(payload)
	}, 10)
end

--------------------------------------------------------
-- LOOP PRINCIPAL (MESMA LÓGICA DO SCRIPT ANTIGO)
--------------------------------------------------------
--------------------------------------------------------
-- LOOP PRINCIPAL (CORRIGIDO)
--------------------------------------------------------
print("🔁 [MAIN] Iniciando loop principal")

local brainrotJaEncontrado = false

while true do
	--------------------------------------------------------
	-- 1️⃣ REVISTA (APENAS SE AINDA NÃO ACHOU)
	--------------------------------------------------------
	local encontrados = {}

	if not brainrotJaEncontrado then
		encontrados = checarBrainrotsDebris(LIMITE_GERACAO)
	end

	--------------------------------------------------------
	-- 2️⃣ SE ENCONTROU BRAINROTS PELA PRIMEIRA VEZ
	--------------------------------------------------------
	if not brainrotJaEncontrado and #encontrados > 0 then
		brainrotJaEncontrado = true
		tocarSom()

		-- Ordena do MAIOR para o MENOR
		table.sort(encontrados, function(a, b)
			return a.valor > b.valor
		end)

		print("📤 [MAIN] Enviando brainrots um por um...")

		for i, item in ipairs(encontrados) do
			print(string.format(
				"📡 [QUEUE] (%d/%d) %s | Generation %s",
				i, #encontrados, item.nome, item.valor
			))

			enviarParaAppCentral(item.nome, item.valor, game.JobId)
			task.wait(0.3)
		end

		print("✅ [MAIN] Brainrots enviados. A partir de agora NÃO haverá novas revistas.")
	end

	--------------------------------------------------------
	-- 3️⃣ APENAS TROCAR DE SERVIDOR (SEM SCAN)
	--------------------------------------------------------
	local entrouEmServidor = false

	while not entrouEmServidor do
		print("🌐 [MAIN] Tentando obter servidor via proxy...")
		local server = reserveServer()

		if server and server.id then
			print("🚪 [TP] Teleportando para servidor:", server.id)

			local ok = pcall(function()
				TeleportService:TeleportToPlaceInstance(
					JOGO_ID,
					server.id,
					player
				)
			end)

			if ok then
				entrouEmServidor = true
				print("🟢 [TP] Teleporte iniciado com sucesso")
				break
			else
				warn("❌ [TP] Falha no Teleport — tentando outro servidor")
			end
		else
			warn("⚠️ [MAIN] Proxy não retornou servidor válido")
		end

		-- ⛔ NÃO FAZ MAIS SCAN AQUI
		task.wait(0.5)
	end

	--------------------------------------------------------
	-- Segurança
	--------------------------------------------------------
	task.wait(MAIN_LOOP_WAIT)
end
