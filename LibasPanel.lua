-- Cliente GUI: Libas Joiner (com Auto Joiner funcional)
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
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
local FIXED_PLACE_ID = 109983668079237
local startTimestamp = os.time()

print("[LibasFinder] Finder iniciado.")

--------------------------------------------------------
-- UTILITÁRIOS
--------------------------------------------------------
local function formatValor(valor)
	if not tonumber(valor) then return tostring(valor) end
	valor = tonumber(valor)
	if valor >= 1e9 then
		return string.format("%.1fB", valor / 1e9)
	elseif valor >= 1e6 then
		return string.format("%.1fM", valor / 1e6)
	elseif valor >= 1e3 then
		return string.format("%.1fK", valor / 1e3)
	else
		return tostring(valor)
	end
end

local function playNotifSound()
	local som = Instance.new("Sound")
	som.SoundId = "rbxassetid://9118823101"
	som.Volume = 1
	som.PlayOnRemove = true
	som.Parent = workspace
	som:Destroy()
end

--------------------------------------------------------
-- GUI PRINCIPAL
--------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 370, 0, 480)
mainFrame.Position = UDim2.new(0.65, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(0, 15)
uicorner.Parent = mainFrame

mainFrame.Active = true
mainFrame.Draggable = true

--------------------------------------------------------
-- BOTÃO FECHAR
--------------------------------------------------------
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
closeButton.MouseButton1Click:Connect(function() screenGui:Destroy() end)

--------------------------------------------------------
-- TÍTULO
--------------------------------------------------------
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 40)
title.Position = UDim2.new(0, 15, 0, 0)
title.Text = "Libas Finder"
title.TextColor3 = Color3.fromRGB(230, 230, 230)
title.BackgroundTransparency = 1
title.TextScaled = true
title.Font = Enum.Font.GothamSemibold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

--------------------------------------------------------
-- ABAS
--------------------------------------------------------
local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -20, 0, 35)
tabsFrame.Position = UDim2.new(0, 10, 0, 45)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = mainFrame

local uiListTabs = Instance.new("UIListLayout")
uiListTabs.FillDirection = Enum.FillDirection.Horizontal
uiListTabs.Padding = UDim.new(0, 8)
uiListTabs.Parent = tabsFrame

local tabs, activeTab = {}, nil
local function createTabButton(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.5, -4, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	btn.TextColor3 = Color3.fromRGB(220, 220, 230)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamSemibold
	btn.Text = name
	btn.AutoButtonColor = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn
	btn.Parent = tabsFrame
	tabs[name] = btn
	return btn
end

local finderTab = createTabButton("Finder")
local autoJoinerTab = createTabButton("Auto Joiner")

--------------------------------------------------------
-- FRAMES DE CONTEÚDO
--------------------------------------------------------
local finderFrame = Instance.new("Frame")
finderFrame.Size = UDim2.new(1, -20, 1, -130)
finderFrame.Position = UDim2.new(0, 10, 0, 85)
finderFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
finderFrame.BorderSizePixel = 0
finderFrame.Visible = true
finderFrame.Parent = mainFrame

local autoJoinerFrame = Instance.new("Frame")
autoJoinerFrame.Size = finderFrame.Size
autoJoinerFrame.Position = finderFrame.Position
autoJoinerFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
autoJoinerFrame.BorderSizePixel = 0
autoJoinerFrame.Visible = false
autoJoinerFrame.Parent = mainFrame

local function switchTab(name)
	for tabName, btn in pairs(tabs) do
		local active = (tabName == name)
		btn.BackgroundColor3 = active and Color3.fromRGB(200, 180, 50) or Color3.fromRGB(50, 50, 60)
		btn.TextColor3 = active and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(230, 230, 230)
	end
	finderFrame.Visible = (name == "Finder")
	autoJoinerFrame.Visible = (name == "Auto Joiner")
	activeTab = name
end

finderTab.MouseButton1Click:Connect(function() switchTab("Finder") end)
autoJoinerTab.MouseButton1Click:Connect(function() switchTab("Auto Joiner") end)
switchTab("Finder")

--------------------------------------------------------
-- FINDER
--------------------------------------------------------
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -10, 1, -10)
scrollFrame.Position = UDim2.new(0, 5, 0, 5)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 12
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200)
scrollFrame.Parent = finderFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, BUTTON_PADDING)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = scrollFrame

--------------------------------------------------------
-- AUTO JOINER UI APRIMORADA
--------------------------------------------------------
local autoJoinEnabled = false
local autoJoinThreshold = 100 * 1_000_000
local selectedNames = {}

-- Checkbox estilizado
local autoCheckFrame = Instance.new("Frame")
autoCheckFrame.Size = UDim2.new(0, 330, 0, 35)
autoCheckFrame.Position = UDim2.new(0, 10, 0, 10)
autoCheckFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
autoCheckFrame.BorderSizePixel = 0
autoCheckFrame.Parent = autoJoinerFrame
Instance.new("UICorner", autoCheckFrame).CornerRadius = UDim.new(0, 8)

local autoCheckLabel = Instance.new("TextLabel")
autoCheckLabel.Size = UDim2.new(1, -40, 1, 0)
autoCheckLabel.Position = UDim2.new(0, 10, 0, 0)
autoCheckLabel.BackgroundTransparency = 1
autoCheckLabel.Text = "Auto Joiner"
autoCheckLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
autoCheckLabel.Font = Enum.Font.Gotham
autoCheckLabel.TextScaled = true
autoCheckLabel.TextXAlignment = Enum.TextXAlignment.Left
autoCheckLabel.Parent = autoCheckFrame

local autoCheckButton = Instance.new("Frame")
autoCheckButton.Size = UDim2.new(0, 25, 0, 25)
autoCheckButton.Position = UDim2.new(1, -35, 0.5, -12)
autoCheckButton.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
autoCheckButton.BorderSizePixel = 0
autoCheckButton.Parent = autoCheckFrame
Instance.new("UICorner", autoCheckButton).CornerRadius = UDim.new(0, 6)

local autoCheckInner = Instance.new("Frame")
autoCheckInner.Size = UDim2.new(0.7, 0, 0.7, 0)
autoCheckInner.Position = UDim2.new(0.15, 0, 0.15, 0)
autoCheckInner.BackgroundColor3 = Color3.fromRGB(255, 225, 100)
autoCheckInner.Visible = false
autoCheckInner.Parent = autoCheckButton
Instance.new("UICorner", autoCheckInner).CornerRadius = UDim.new(1, 0)

autoCheckFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		autoJoinEnabled = not autoJoinEnabled
		autoCheckInner.Visible = autoJoinEnabled
	end
end)

-- Valor mínimo (textbox)
local minFrame = Instance.new("Frame")
minFrame.Size = UDim2.new(0, 330, 0, 40)
minFrame.Position = UDim2.new(0, 10, 0, 55)
minFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
minFrame.BorderSizePixel = 0
minFrame.Parent = autoJoinerFrame
Instance.new("UICorner", minFrame).CornerRadius = UDim.new(0, 8)

local minLabel = Instance.new("TextLabel")
minLabel.Size = UDim2.new(0.6, 0, 1, 0)
minLabel.Position = UDim2.new(0, 10, 0, 0)
minLabel.BackgroundTransparency = 1
minLabel.Text = "Minimum generation (M/s):"
minLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
minLabel.Font = Enum.Font.Gotham
minLabel.TextScaled = true
minLabel.TextXAlignment = Enum.TextXAlignment.Left
minLabel.Parent = minFrame

local thresholdBox = Instance.new("TextBox")
thresholdBox.Size = UDim2.new(0.3, 0, 0.8, 0)
thresholdBox.Position = UDim2.new(0.65, 0, 0.1, 0)
thresholdBox.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
thresholdBox.TextColor3 = Color3.fromRGB(255, 255, 255)
thresholdBox.Font = Enum.Font.GothamSemibold
thresholdBox.TextScaled = true
thresholdBox.Text = "100"
thresholdBox.Parent = minFrame

thresholdBox.FocusLost:Connect(function()
	local num = tonumber(thresholdBox.Text)
	if num then
		autoJoinThreshold = num * 1_000_000
	else
		thresholdBox.Text = tostring(autoJoinThreshold / 1_000_000)
	end
end)

-- Lista de nomes em grid
local listTitle = Instance.new("TextLabel")
listTitle.Size = UDim2.new(1, -20, 0, 25)
listTitle.Position = UDim2.new(0, 10, 0, 105)
listTitle.BackgroundTransparency = 1
listTitle.Text = "Brainrots always allowed:"
listTitle.TextColor3 = Color3.fromRGB(255, 225, 100)
listTitle.Font = Enum.Font.GothamBold
listTitle.TextScaled = true
listTitle.TextXAlignment = Enum.TextXAlignment.Left
listTitle.Parent = autoJoinerFrame

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -135)
scroll.Position = UDim2.new(0, 10, 0, 135)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 8
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = autoJoinerFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.48, 0, 0, 30)
grid.CellPadding = UDim2.new(0, 10, 0, 10)
grid.FillDirectionMaxCells = 2
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll

local names = {
	"Nuclearo Dinossauro", "Money Money Puggy", "La Spooky Grande", "Chillin Chili",
	"Chipso and Queso", "Eviledon", "Los Tacoritas", "Tang Tang Keletang",
	"Ketupat Kepat", "La Taco Combinasion", "Tictac Sahur", "La Supreme Combinasion",
	"Ketchuru and Musturu", "Garama and Madundung", "Spaghetti Tualetti", "Spooky and Pumpky"
}

for _, nome in ipairs(names) do
	local btnFrame = Instance.new("Frame")
	btnFrame.Size = UDim2.new(1, 0, 0, 30)
	btnFrame.BackgroundTransparency = 1
	btnFrame.Parent = scroll

	local radioOuter = Instance.new("Frame")
	radioOuter.Size = UDim2.new(0, 22, 0, 22)
	radioOuter.Position = UDim2.new(0, 5, 0.5, -11)
	radioOuter.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
	radioOuter.BorderSizePixel = 0
	radioOuter.Parent = btnFrame
	Instance.new("UICorner", radioOuter).CornerRadius = UDim.new(1, 0)

	local radioInner = Instance.new("Frame")
	radioInner.Size = UDim2.new(0.6, 0, 0.6, 0)
	radioInner.Position = UDim2.new(0.2, 0, 0.2, 0)
	radioInner.BackgroundColor3 = Color3.fromRGB(255, 225, 100)
	radioInner.Visible = false -- ← 🔹 alteraremos isso logo abaixo
	radioInner.Parent = radioOuter
	Instance.new("UICorner", radioInner).CornerRadius = UDim.new(1, 0)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -40, 1, 0)
	nameLabel.Position = UDim2.new(0, 35, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = nome
	nameLabel.Parent = btnFrame

	-- ✅ Adicione estas duas linhas aqui:
	selectedNames[nome] = true
	radioInner.Visible = true

	btnFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if selectedNames[nome] then
				selectedNames[nome] = nil
				radioInner.Visible = false
			else
				selectedNames[nome] = true
				radioInner.Visible = true
			end
		end
	end)
end



scroll.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y)
grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y)
end)

--------------------------------------------------------
-- DISCORD LINK
--------------------------------------------------------
local discordLink = Instance.new("TextButton")
discordLink.Size = UDim2.new(1, -20, 0, 30)
discordLink.Position = UDim2.new(0, 10, 1, -40)
discordLink.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
discordLink.TextColor3 = Color3.fromRGB(200, 200, 255)
discordLink.Text = "Discord: https://discord.gg/kPn2czPJs5"
discordLink.Font = Enum.Font.GothamSemibold
discordLink.TextScaled = true
discordLink.Parent = mainFrame

discordLink.MouseEnter:Connect(function()
	TweenService:Create(discordLink, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 150)}):Play()
end)
discordLink.MouseLeave:Connect(function()
	TweenService:Create(discordLink, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(70, 70, 80)}):Play()
end)

--------------------------------------------------------
-- FINDER LÓGICA
--------------------------------------------------------
local brainrotButtons, seenBrainrots = {}, {}

local function removeOldestIfNeeded()
	while #brainrotButtons > MAX_BUTTONS do
		local oldBtn = table.remove(brainrotButtons)
		if oldBtn then oldBtn:Destroy() end
	end
end

local function teleportToBrainrot(brainrot)
	pcall(function()
		print("[AutoJoiner] Teleportando automaticamente:", brainrot.jobId)
		TeleportService:TeleportToPlaceInstance(FIXED_PLACE_ID, brainrot.jobId, Players.LocalPlayer)
	end)
end

local function criarBotao(brainrot)
	if not brainrot or not brainrot.jobId then return end
	local signature = string.format("%s|%s|%s", tostring(brainrot.jobId), tostring(brainrot.nome), tostring(brainrot.valor))
	if seenBrainrots[signature] then return end
	seenBrainrots[signature] = true

	playNotifSound()

	-- Auto Joiner check
	if autoJoinEnabled then
		local valor = tonumber(brainrot.valor or 0)
		local nome = tostring(brainrot.nome or "")
		if (valor >= autoJoinThreshold) or selectedNames[nome] then
			teleportToBrainrot(brainrot)
		end
	end

	-- Botão normal
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

	if tonumber(brainrot.valor) and brainrot.valor >= 10_000_000 then
		btn.BackgroundColor3 = Color3.fromRGB(200, 180, 50)
		btn.TextColor3 = Color3.fromRGB(20, 20, 20)
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		pcall(function()
			print("Teleportando para:", brainrot.jobId)
			TeleportService:TeleportToPlaceInstance(FIXED_PLACE_ID, brainrot.jobId, Players.LocalPlayer)
		end)
	end)

	table.insert(brainrotButtons, 1, btn)
	removeOldestIfNeeded()
end

uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 10)
end)

--------------------------------------------------------
-- FETCH LOOP
--------------------------------------------------------
local function fetchFromApp()
	local ok, res = pcall(function()
		return req({Url = APP_URL, Method = "GET"})
	end)
	if not ok or not res or not res.Body then return end
	local success, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not success or type(data) ~= "table" then return end
	for _, item in ipairs(data) do
		if item and item.jobId and tonumber(item.timestamp) > startTimestamp then
			criarBotao(item)
		end
	end
end

spawn(function()
	while screenGui.Parent do
		fetchFromApp()
		task.wait(POLL_INTERVAL)
	end
end)

--------------------------------------------------------
-- SISTEMA DE REDIMENSIONAMENTO DO MAINFRAME
--------------------------------------------------------
local resizing = false
local resizeCornerSize = 15  -- área clicável na borda inferior direita
local startPos, startSize

mainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mousePos = UserInputService:GetMouseLocation()
		local framePos = mainFrame.AbsolutePosition
		local frameSize = mainFrame.AbsoluteSize

		-- Verifica se clicou na borda inferior direita
		if mousePos.X >= framePos.X + frameSize.X - resizeCornerSize
			and mousePos.Y >= framePos.Y + frameSize.Y - resizeCornerSize then
			resizing = true
			startPos = mousePos
			startSize = frameSize
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = UserInputService:GetMouseLocation() - startPos
		local newWidth = math.max(300, startSize.X + delta.X)
		local newHeight = math.max(350, startSize.Y + delta.Y)

		mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)

		-- Ajuste automático dos frames do Auto Joiner
		autoCheckFrame.Size = UDim2.new(0, newWidth - 40, 0, 35)
		minFrame.Size = UDim2.new(0, newWidth - 40, 0, 40)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		resizing = false
	end
end)

-- Indicação visual opcional (cursor de redimensionamento)
mainFrame.MouseEnter:Connect(function(x, y)
	local mousePos = UserInputService:GetMouseLocation()
	local framePos = mainFrame.AbsolutePosition
	local frameSize = mainFrame.AbsoluteSize
	if mousePos.X >= framePos.X + frameSize.X - resizeCornerSize
		and mousePos.Y >= framePos.Y + frameSize.Y - resizeCornerSize then
		UserInputService.MouseIconEnabled = true
	end
end)



print("[LibasFinder] Auto Joiner ativo.")

