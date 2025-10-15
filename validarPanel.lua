-- validator.lua
-- Script de validação sem GUI. Lê a variável global `key` e valida no app; se autorizado, baixa e executa o loader.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ==== CONFIGURE AQUI ANTES DE SUBIR AO GITHUB ====
local APP_VERIFY_URL = "https://renderbots.onrender.com/api/verify" -- <--- troque para seu endpoint real
local LOADER_URL     = "https://raw.githubusercontent.com/iJotha/scriptAutoJoiner/refs/heads/main/LibasPanel.lua" -- loader final
-- ==================================================

local req = request or http_request
if not req then
	warn("[Auth] Exploit não expõe 'request' nem 'http_request'. Abortando.")
	return
end

-- tenta obter KEY definida globalmente pelo usuário
local function getKeyFromGlobal()
	if type(key) == "string" and key ~= "" then return key end
	if type(_G) == "table" and type(_G.key) == "string" and _G.key ~= "" then return _G.key end
	return nil
end

local KEY = getKeyFromGlobal()
if not KEY then
	warn("[Auth] Nenhuma key encontrada. O usuário deve executar primeiro: key = \"sua_key\";")
	return
end

-- tenta obter HWID estável (prefere RbxAnalyticsService:GetClientId)
local function getHWID()
	local ok, id = pcall(function()
		local svc = game:GetService("RbxAnalyticsService")
		if svc and svc.GetClientId then
			return svc:GetClientId()
		end
	end)
	if ok and id and tostring(id) ~= "" then
		return tostring(id)
	end
	-- fallback não persistente
	return HttpService:GenerateGUID(false)
end

local HWID = getHWID()
print(string.format("[Auth] Key='%s' — verificando...", tostring(KEY)))

local function verifyKeyOnce(key, hwid)
	local body = HttpService:JSONEncode({ key = key, hwid = hwid })
	local ok, resp = pcall(function()
		return req({
			Url = APP_VERIFY_URL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body
		})
	end)
	if not ok or not resp then
		return false, "Falha na requisição ao servidor"
	end

	local respBody = resp.Body or resp.body
	if not respBody then
		return false, "Resposta vazia do servidor"
	end

	local success, data = pcall(function() return HttpService:JSONDecode(respBody) end)
	if not success or type(data) ~= "table" then
		return false, "Resposta do servidor inválida"
	end

	if data.success then
		return true, data.message or "Autorizado"
	else
		-- mensagens específicas vindas do backend
		local msg = tostring(data.message or "Key inválida ou HWID mismatch")
		if msg:lower():find("hwid") then
			return false, "Invalid HWID."
		elseif msg:lower():find("key") then
			return false, "Invalid key."
		else
			return false, msg
		end
	end
end

local ok, msg = verifyKeyOnce(KEY, HWID)
if not ok then
	warn("[Auth] Verificação falhou: " .. tostring(msg))
	
	-- expulsa o jogador com a mensagem correspondente
	local player = Players.LocalPlayer
	if player then
		player:Kick(msg)
	end

	return
end

print("[Auth] Verificação bem-sucedida: " .. tostring(msg))
print("[Auth] Executando...")

local loader_ok, loader_err = pcall(function()
	local code = game:HttpGet(LOADER_URL)
	local f, err = loadstring(code)
	if not f then
		error("Falha ao compilar loader: " .. tostring(err))
	end
	return f()
end)

if not loader_ok then
	warn("[Auth] Erro ao executar.")
else
	print("[Auth] Executado com sucesso.")
end
