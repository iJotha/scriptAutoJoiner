-- Cliente GUI: Libas Joiner (com formatação abreviada de valor)
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local req = request or http_request

-- URL do app-central
local APP_URL = "https://renderbots.onrender.com/api/list"

local player = Players.LocalPlayer

-- CONFIG
local POLL_INTERVAL = 1
local MAX_BUTTONS = 50
local BUTTON_HEIGHT = 50
local BUTTON_PADDING = 8
local FIXED_PLACE_ID = 109983668079237 -- 🔒 ID fixo

-- apenas entradas lançadas após o início do script
local startTimestamp = os.time()
print("[LibasJoiner] Iniciado.")

-- ======== FUNÇÃO PARA FORMATAR NÚMEROS GRANDES ========
local function formatValor(valor)
	if not tonumber(valor) then return tostring(valor) end
	valor = tonumber(valor)
	if valor >= 1e9 then
		return string.format("%.2fB", valor / 1e9)
	elseif valor >= 1e6 then
		return string.format("%.2fM", valor / 1e6)
	elseif valor >= 1e3 then
		return string.format("%.2fK", valor / 1e3)
	else
		return tostring(valor)
	end
end

-- ======== CRIA GUI PRINCIPAL ========
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 450)
mainFrame.Position = UDim2.new(0.65, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 15)
uicorner.Parent = mainFrame

-- Arrastar
mainFrame.Active = true
mainFrame.Draggable = true

-- Redimensionar
local resizeCorner = Instance.new("Frame")
resizeCorner.Size = UDim2.new(0, 20, 0, 20)
resizeCorner.Position = UDim2.new(1, -20, 1, -20)
resizeCorner.BackgroundTransparency = 1
resizeCorner.Parent = mainFrame

local resizing = false
local startMousePos, startSize

resizeCorner.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		resizing = true
		startMousePos = input.Position
		startSize = mainFrame.Size
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				resizing = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - startMousePos
		mainFrame.Size = UDim2.new(0, math.clamp(startSize.X.Offset + delta.X, 250, 1000),
			0, math.clamp(startSize.Y.Offset + delta.Y, 200, 1200))
	end
end)

-- Botão fechar
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamSemibold
closeButton.TextScaled = true
closeButton.Parent = mainFrame
closeButton.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

-- Título
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 40)
title.Position = UDim2.new(0, 15, 0, 0)
title.Text = "Libas Joiner"
title.TextColor3 = Color3.fromRGB(230, 230, 230)
title.BackgroundTransparency = 1
title.TextScaled = true
title.Font = Enum.Font.GothamSemibold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- ======== FRAME SCROLL ========
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -90)
scrollFrame.Position = UDim2.new(0, 10, 0, 50)
scrollFrame.BackgroundTransparency = 0.3
scrollFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 12
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
scrollFrame.Parent = mainFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, BUTTON_PADDING)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = scrollFrame

-- ======== LINK DISCORD ========
local discordLink = Instance.new("TextButton")
discordLink.Size = UDim2.new(1, -20, 0, 30)
discordLink.Position = UDim2.new(0, 10, 1, -40)
discordLink.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
discordLink.TextColor3 = Color3.fromRGB(200, 200, 255)
discordLink.Text = "Discord: https://discord.gg/HnbHeDpURG"
discordLink.Font = Enum.Font.GothamSemibold
discordLink.TextScaled = true
discordLink.Parent = mainFrame

discordLink.MouseEnter:Connect(function()
	TweenService:Create(discordLink, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 150)}):Play()
end)
discordLink.MouseLeave:Connect(function()
	TweenService:Create(discordLink, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(70, 70, 80)}):Play()
end)

-- ======== BOTÕES / CONTROLE ========
local brainrotButtons = {}
local seenBrainrots = {} -- ⚡ tabela global para rastrear todos já adicionados

local function removeOldestIfNeeded()
	while #brainrotButtons > MAX_BUTTONS do
		local oldBtn = table.remove(brainrotButtons)
		if oldBtn then oldBtn:Destroy() end
	end
end

local function criarBotao(brainrot)
	if not brainrot or not brainrot.jobId then return end

	-- ⚡ cria assinatura única (jobId + nome + valor)
	local signature = string.format("%s|%s|%s", tostring(brainrot.jobId), tostring(brainrot.nome), tostring(brainrot.valor))

	-- se já vimos essa combinação, não criar novamente
	if seenBrainrots[signature] then
		return
	end

	-- marca como visto
	seenBrainrots[signature] = true

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, BUTTON_HEIGHT)
	btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamSemibold

	local valorFormatado = formatValor(brainrot.valor or 0)
	btn.Text = string.format("%s - $%s/s", brainrot.nome or "Desconhecido", valorFormatado)
	btn.LayoutOrder = -tick()
	btn.Parent = scrollFrame

	if tonumber(brainrot.valor) and brainrot.valor >= 10000000 then
		btn.BackgroundColor3 = Color3.fromRGB(200, 180, 50)
		btn.TextColor3 = Color3.fromRGB(20, 20, 20)
	end

	local uicornerBtn = Instance.new("UICorner")
	uicornerBtn.CornerRadius = UDim.new(0, 10)
	uicornerBtn.Parent = btn

	btn.MouseEnter:Connect(function()
		local bg = btn.BackgroundColor3
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = bg:Lerp(Color3.fromRGB(100,100,120), 0.5)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		local target = (tonumber(brainrot.valor) and brainrot.valor >= 10000000) and Color3.fromRGB(200,180,50) or Color3.fromRGB(60,60,70)
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = target}):Play()
	end)

	btn.MouseButton1Click:Connect(function()
		pcall(function()
			print("Teleportando para:", brainrot.jobId)
			-- 🔒 usa ID fixo no lugar de game.PlaceId
			TeleportService:TeleportToPlaceInstance(FIXED_PLACE_ID, brainrot.jobId, Players.LocalPlayer)
		end)
	end)

	table.insert(brainrotButtons, 1, btn)
	removeOldestIfNeeded()
end

uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0,0,0, uiListLayout.AbsoluteContentSize.Y + 10)
end)

-- ======== POLL AO APP ========
local function fetchFromApp()
	local ok, res = pcall(function()
		return req({ Url = APP_URL, Method = "GET" })
	end)
	if not ok or not res or not res.Body then return end

	local success, data = pcall(function()
		return HttpService:JSONDecode(res.Body)
	end)
	if not success or type(data) ~= "table" then return end

	for _, item in ipairs(data) do
		if item and item.jobId and tonumber(item.timestamp) and tonumber(item.timestamp) > startTimestamp then
			criarBotao(item)
		end
	end
end

-- ======== LOOP ========
spawn(function()
	while screenGui.Parent do
		fetchFromApp()
		task.wait(POLL_INTERVAL)
	end
end)

print("[LibasJoiner] GUI carregada. Aguardando novas entradas...")
