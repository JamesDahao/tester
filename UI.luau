local Decode = {}

local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local env = getfenv()
local getcustomasset = env.getcustomasset or function() return "" end
local isfile = env.isfile or function() return false end
local isfolder = env.isfolder or function() return false end
local makefolder = env.makefolder or function() end
local readfile = env.readfile or function() return "" end
local writefile = env.writefile or function() end

local folderPath = "Decode by ItzYumi"
local assetFolder = "Decode by ItzYumi/Assets"
local assetPath = assetFolder .. "/icon.png"
local filePath = folderPath .. "/Save System/Grow a Garden 2/config.json"

local LocalPlayer = Players.LocalPlayer

local Configurations = { 
    SpeedEnabled = false,
    Speed = 0,
    NoClipEnabled = false,
    InfiniteJumpEnabled = false,
    StopCollectIfFull = false,
    CollectDelay = 0,
    DisableCollectPrompt = false,
    HarvestFruitFilter = {},
    HarvestMutationFilter = {},
    ThresholdMode = "",
    WeightThreshold = 0,
    HarvestFruits = false,
    HarvestAllFruits = false,
    AllowSellIfFull = false,
    SellDelay = 0,
    SellFruitFilter = {},
    SellMutationFilter = {},
    SellThresholdMode = "",
    SellWeightThreshold = 0,
    SellFruits = false,
    SellAllFruits = false,
    PetTweenSpeed = 16,
    SelectedPetsFilter = {},
    SelectedPetSizeFilter = {},
    AutoBuyPets = false
}

local UI = {
    Tabs = {},
    FirstTab = nil,
    PageList = {"Home", "Main", "Assist", "Shop", "Misc"},
    CreatedPages = {},
    PlayerTracker = { OriginalSpeed = 16 }
}

Decode.Theme = {
    MainBackground = Color3.fromRGB(10, 18, 30),
    SidebarBackground = Color3.fromRGB(15, 27, 44),
    AccentColor = Color3.fromRGB(14, 165, 233),
    ElementBackground = Color3.fromRGB(22, 38, 62),
    TextMain = Color3.fromRGB(255, 255, 255),
    TextMuted = Color3.fromRGB(140, 160, 185)
}

local function saveConfig()
    local success, str = pcall(function()
        return HttpService:JSONEncode(Configurations)
    end)
    if success and str then
        local split = string.split(filePath, "/")
        local currentPath = ""
        for i = 1, #split - 1 do
            currentPath = currentPath == "" and split[i] or currentPath .. "/" .. split[i]
            if not isfolder(currentPath) then
                makefolder(currentPath)
            end
        end
        writefile(filePath, str)
    end
end

local function loadConfig()
    if isfile(filePath) then
        local success, content = pcall(function()
            return readfile(filePath)
        end)
        if success and content then
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if decodeSuccess and type(data) == "table" then
                for k, v in pairs(data) do
                    if Configurations[k] ~= nil then
                        Configurations[k] = v
                    end
                end
            end
        end
    end
end

loadConfig()
_G.DecodeAPI = { Configs = Configurations }

if not isfolder(folderPath) then makefolder(folderPath) end
if not isfolder(assetFolder) then makefolder(assetFolder) end

if not isfile(assetPath) then
    pcall(function()
        local g = game
        local content = g["HttpGet"](g, "https://raw.githubusercontent.com/ItzYumi/Decode/refs/heads/main/de_code_logo.png")
        if content then
            writefile(assetPath, content)
        end
    end)
end

function Decode:GetAssetCategory(categoryName)
    local items = {}
    local repStorage = game:GetService("ReplicatedStorage")
    local assets = repStorage:FindFirstChild("Assets")
    local folder = assets and assets:FindFirstChild(categoryName)
    
    if folder then
        for _, child in pairs(folder:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then 
                table.insert(items, child.Name) 
            end
        end
    end
    table.sort(items)
    return items
end

function Decode:GetGameMutations()
    local mutations = {}
    local repStorage = game:GetService("ReplicatedStorage")
    local shared = repStorage:FindFirstChild("SharedModules")
    local module = shared and shared:FindFirstChild("MutationData")
    
    if module then
        for _, child in pairs(module:GetChildren()) do
            if child:IsA("ModuleScript") then
                table.insert(mutations, child.Name)
            end
        end
    end
    
    table.sort(mutations)
    return mutations
end

function Decode:GetPetTypesAndSizes()
    local combinedList = {}
    local repStorage = game:GetService("ReplicatedStorage")
    local sharedData = repStorage:FindFirstChild("SharedData")

    local typeMod = sharedData and sharedData:FindFirstChild("PetTypes")
    if typeMod and typeMod:IsA("ModuleScript") then
        local success, data = pcall(require, typeMod)
        if success and type(data) == "table" then
            local getupvalue = debug["getupvalue"]
            if getupvalue then
                local counter = 1
                while true do
                    local name, value = getupvalue(data.IsValid or function() end, counter)
                    if not name then break end
                    if type(value) == "table" and (value["Rainbow"] ~= nil) then
                        for typeName, _ in pairs(value) do
                            table.insert(combinedList, tostring(typeName))
                        end
                        break
                    end
                    counter = counter + 1
                end
            end
        end
    end
    
    local sizeMod = sharedData and sharedData:FindFirstChild("PetSizes")
    if sizeMod and sizeMod:IsA("ModuleScript") then
        local success, data = pcall(require, sizeMod)
        if success and type(data) == "table" and data.Scales then
            for sizeName, _ in pairs(data.Scales) do
                table.insert(combinedList, tostring(sizeName))
            end
        end
    end

    table.sort(combinedList)
    return combinedList
end

UI.ScreenGui = Instance.new("ScreenGui")
UI.ScreenGui.Name = "Decode_UI"
UI.ScreenGui.ResetOnSpawn = false
UI.ScreenGui.Parent = CoreGui

UI.FrameMain = Instance.new("Frame")
UI.FrameMain.Name = "MainContainer"
UI.FrameMain.Size = UDim2.new(0, 520, 0, 340)
UI.FrameMain.Position = UDim2.new(0.5, -260, 0.5, -170)
UI.FrameMain.BackgroundColor3 = Decode.Theme.MainBackground
UI.FrameMain.BackgroundTransparency = 0.15
UI.FrameMain.BorderSizePixel = 0
UI.FrameMain.Active = true
UI.FrameMain.Draggable = true
UI.FrameMain.Parent = UI.ScreenGui

UI.CornerMain = Instance.new("UICorner")
UI.CornerMain.CornerRadius = UDim.new(0, 10)
UI.CornerMain.Parent = UI.FrameMain

UI.TopHeader = Instance.new("Frame")
UI.TopHeader.Name = "TopHeader"
UI.TopHeader.Size = UDim2.new(1, 0, 0, 35)
UI.TopHeader.BackgroundTransparency = 1
UI.TopHeader.Parent = UI.FrameMain

UI.TitleLabel = Instance.new("TextLabel")
UI.TitleLabel.Size = UDim2.new(0, 200, 1, 0)
UI.TitleLabel.Position = UDim2.new(0, 14, 0, 0)
UI.TitleLabel.BackgroundTransparency = 1
UI.TitleLabel.Text = "Decode"
UI.TitleLabel.TextColor3 = Decode.Theme.TextMuted
UI.TitleLabel.TextSize = 14
UI.TitleLabel.Font = Enum.Font.SourceSansBold
UI.TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.TitleLabel.Parent = UI.TopHeader

UI.CloseButton = Instance.new("TextButton")
UI.CloseButton.Size = UDim2.new(0, 35, 0, 35)
UI.CloseButton.Position = UDim2.new(1, -40, 0, 0)
UI.CloseButton.BackgroundTransparency = 1
UI.CloseButton.Text = "X"
UI.CloseButton.TextColor3 = Decode.Theme.TextMuted
UI.CloseButton.TextSize = 14
UI.CloseButton.Font = Enum.Font.SourceSansBold
UI.CloseButton.Parent = UI.TopHeader

UI.MinimizeButton = Instance.new("TextButton")
UI.MinimizeButton.Size = UDim2.new(0, 35, 0, 35)
UI.MinimizeButton.Position = UDim2.new(1, -75, 0, 0)
UI.MinimizeButton.BackgroundTransparency = 1
UI.MinimizeButton.Text = "-"
UI.MinimizeButton.TextColor3 = Decode.Theme.TextMuted
UI.MinimizeButton.TextSize = 18
UI.MinimizeButton.Font = Enum.Font.SourceSansBold
UI.MinimizeButton.Parent = UI.TopHeader

UI.MinimizeLogo = Instance.new("ImageButton")
UI.MinimizeLogo.Name = "MinimizeLogo"
UI.MinimizeLogo.Size = UDim2.new(0, 36, 0, 36)
UI.MinimizeLogo.Position = UDim2.new(0.05, 0, 0.05, 0)
UI.MinimizeLogo.BackgroundColor3 = Decode.Theme.SidebarBackground
UI.MinimizeLogo.BackgroundTransparency = 0.2
UI.MinimizeLogo.Image = isfile(assetPath) and getcustomasset(assetPath) or ""
UI.MinimizeLogo.Visible = false
UI.MinimizeLogo.Active = true
UI.MinimizeLogo.Draggable = true
UI.MinimizeLogo.Parent = UI.ScreenGui

UI.LogoCorner = Instance.new("UICorner")
UI.LogoCorner.CornerRadius = UDim.new(1, 0)
UI.LogoCorner.Parent = UI.MinimizeLogo

UI.LogoStroke = Instance.new("UIStroke")
UI.LogoStroke.Color = Decode.Theme.MainBackground
UI.LogoStroke.Thickness = 1.5
UI.LogoStroke.Parent = UI.MinimizeLogo

UI.MinimizeButton.MouseButton1Click:Connect(function()
    UI.FrameMain.Visible = false
    UI.MinimizeLogo.Visible = true
end)

UI.MinimizeLogo.MouseButton1Click:Connect(function()
    UI.MinimizeLogo.Visible = false
    UI.FrameMain.Visible = true
end)

UI.Sidebar = Instance.new("Frame")
UI.Sidebar.Name = "Sidebar"
UI.Sidebar.Size = UDim2.new(0, 160, 1, -35)
UI.Sidebar.Position = UDim2.new(0, 0, 0, 35)
UI.Sidebar.BackgroundColor3 = Decode.Theme.SidebarBackground
UI.Sidebar.BackgroundTransparency = 0.2
UI.Sidebar.BorderSizePixel = 0
UI.Sidebar.Parent = UI.FrameMain

UI.CornerSidebar = Instance.new("UICorner")
UI.CornerSidebar.CornerRadius = UDim.new(0, 10)
UI.CornerSidebar.Parent = UI.Sidebar

UI.NavScroll = Instance.new("ScrollingFrame")
UI.NavScroll.Size = UDim2.new(1, -12, 1, -20)
UI.NavScroll.Position = UDim2.new(0, 12, 0, 10)
UI.NavScroll.BackgroundTransparency = 1
UI.NavScroll.BorderSizePixel = 0
UI.NavScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.NavScroll.ScrollBarThickness = 0
UI.NavScroll.Parent = UI.Sidebar

UI.NavLayout = Instance.new("UIListLayout")
UI.NavLayout.Parent = UI.NavScroll
UI.NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
UI.NavLayout.Padding = UDim.new(0, 4)

UI.NavLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    UI.NavScroll.CanvasSize = UDim2.new(0, 0, 0, UI.NavLayout.AbsoluteContentSize.Y)
end)

UI.ContentContainer = Instance.new("Frame")
UI.ContentContainer.Name = "ContentContainer"
UI.ContentContainer.Size = UDim2.new(1, -185, 1, -50)
UI.ContentContainer.Position = UDim2.new(0, 175, 0, 40)
UI.ContentContainer.BackgroundTransparency = 1
UI.ContentContainer.Parent = UI.FrameMain

UI.PageHeaderLabel = Instance.new("TextLabel")
UI.PageHeaderLabel.Name = "PageHeaderLabel"
UI.PageHeaderLabel.Size = UDim2.new(1, 0, 0, 30)
UI.PageHeaderLabel.Position = UDim2.new(0, 0, 0, -5)
UI.PageHeaderLabel.BackgroundTransparency = 1
UI.PageHeaderLabel.Text = "Home"
UI.PageHeaderLabel.TextColor3 = Decode.Theme.TextMain
UI.PageHeaderLabel.TextSize = 22
UI.PageHeaderLabel.Font = Enum.Font.SourceSansBold
UI.PageHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.PageHeaderLabel.Parent = UI.ContentContainer

function Decode:CreateTab(tabName)
    local Temp = {}
    Temp.Page = Instance.new("ScrollingFrame")
    Temp.Page.Name = tabName .. "_Page"
    Temp.Page.Size = UDim2.new(1, 0, 1, -30)
    Temp.Page.Position = UDim2.new(0, 0, 0, 30)
    Temp.Page.BackgroundTransparency = 1
    Temp.Page.BorderSizePixel = 0
    Temp.Page.Visible = false
    Temp.Page.ScrollBarThickness = 0
    Temp.Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Temp.Page.Parent = UI.ContentContainer

    Temp.Layout = Instance.new("UIListLayout")
    Temp.Layout.Parent = Temp.Page
    Temp.Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Temp.Layout.Padding = UDim.new(0, 6)
    
    Temp.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Temp.Page.CanvasSize = UDim2.new(0, 0, 0, Temp.Layout.AbsoluteContentSize.Y + 10)
    end)

    Temp.Button = Instance.new("TextButton")
    Temp.Button.Name = tabName .. "_Btn"
    Temp.Button.Size = UDim2.new(1, 0, 0, 34)
    Temp.Button.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Button.BackgroundTransparency = 1
    Temp.Button.Text = "  " .. tabName
    Temp.Button.TextColor3 = Decode.Theme.TextMuted
    Temp.Button.TextSize = 14
    Temp.Button.Font = Enum.Font.SourceSansBold
    Temp.Button.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Button.Parent = UI.NavScroll

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Button

    UI.Tabs[tabName] = Temp

    Temp.Button.MouseButton1Click:Connect(function()
        for _, tab in pairs(UI.Tabs) do
            tab.Page.Visible = false
            tab.Button.BackgroundTransparency = 1
            tab.Button.TextColor3 = Decode.Theme.TextMuted
        end
        Temp.Page.Visible = true
        Temp.Button.BackgroundTransparency = 0.8
        Temp.Button.TextColor3 = Decode.Theme.TextMain
        UI.PageHeaderLabel.Text = tabName
    end)

    if not UI.FirstTab then
        UI.FirstTab = Temp
    end

    return Temp.Page
end

function Decode:CreateDropdown(parentPage, dropdownText)
    local Temp = {}
    Temp.Container = Instance.new("Frame")
    Temp.Container.Name = dropdownText .. "_DropdownContainer"
    Temp.Container.Size = UDim2.new(1, 0, 0, 36)
    Temp.Container.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Container.BackgroundTransparency = 0.4
    Temp.Container.ClipsDescendants = true
    Temp.Container.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Container

    Temp.Header = Instance.new("TextButton")
    Temp.Header.Name = "Header"
    Temp.Header.Size = UDim2.new(1, 0, 0, 36)
    Temp.Header.BackgroundTransparency = 1
    Temp.Header.Text = "  " .. dropdownText
    Temp.Header.TextColor3 = Decode.Theme.TextMain
    Temp.Header.TextSize = 14
    Temp.Header.Font = Enum.Font.SourceSansSemibold
    Temp.Header.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Header.Parent = Temp.Container

    Temp.Arrow = Instance.new("TextLabel")
    Temp.Arrow.Name = "Arrow"
    Temp.Arrow.Size = UDim2.new(0, 36, 0, 36)
    Temp.Arrow.Position = UDim2.new(1, -36, 0, 0)
    Temp.Arrow.BackgroundTransparency = 1
    Temp.Arrow.Text = ">"
    Temp.Arrow.TextColor3 = Decode.Theme.TextMuted
    Temp.Arrow.TextSize = 13
    Temp.Arrow.Font = Enum.Font.SourceSansBold
    Temp.Arrow.Parent = Temp.Header

    Temp.ItemsFrame = Instance.new("Frame")
    Temp.ItemsFrame.Name = "Items"
    Temp.ItemsFrame.Size = UDim2.new(1, -12, 1, -40)
    Temp.ItemsFrame.Position = UDim2.new(0, 6, 0, 40)
    Temp.ItemsFrame.BackgroundTransparency = 1
    Temp.ItemsFrame.Parent = Temp.Container

    Temp.Layout = Instance.new("UIListLayout")
    Temp.Layout.Parent = Temp.ItemsFrame
    Temp.Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Temp.Layout.Padding = UDim.new(0, 5)

    Temp.Open = false
    Temp.Header.MouseButton1Click:Connect(function()
        Temp.Open = not Temp.Open
        local targetHeight = Temp.Open and (Temp.Layout.AbsoluteContentSize.Y + 45) or 36
        local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(Temp.Container, info, {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(Temp.Arrow, info, {Rotation = Temp.Open and 90 or 0}):Play()
        
        task.wait(0.2)
        if Temp.Open and parentPage:IsA("ScrollingFrame") then
            parentPage.CanvasSize = UDim2.new(0, 0, 0, parentPage.UIListLayout.AbsoluteContentSize.Y + 10)
        end
    end)

    return Temp.ItemsFrame
end

function Decode:AddSlider(parentPage, sliderText, defaultValue, callback, subtext)
    local Temp = {}
    Temp.Frame = Instance.new("Frame")
    Temp.Frame.Size = UDim2.new(1, 0, 0, 36)
    Temp.Frame.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Frame.BackgroundTransparency = 0.6
    Temp.Frame.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Frame

    Temp.Label = Instance.new("TextLabel")
    Temp.Label.Size = UDim2.new(0, 180, subtext and 0.5 or 1, 0)
    Temp.Label.Position = UDim2.new(0, 10, 0, subtext and 2 or 0)
    Temp.Label.BackgroundTransparency = 1
    Temp.Label.Text = sliderText
    Temp.Label.TextColor3 = Decode.Theme.TextMain
    Temp.Label.TextSize = 13
    Temp.Label.Font = Enum.Font.SourceSansBold
    Temp.Label.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Label.Parent = Temp.Frame

    if subtext then
        Temp.SubLabel = Instance.new("TextLabel")
        Temp.SubLabel.Size = UDim2.new(0, 220, 0.5, 0)
        Temp.SubLabel.Position = UDim2.new(0, 10, 0.5, -2)
        Temp.SubLabel.BackgroundTransparency = 1
        Temp.SubLabel.Text = subtext
        Temp.SubLabel.TextColor3 = Decode.Theme.TextMuted
        Temp.SubLabel.TextSize = 11
        Temp.SubLabel.Font = Enum.Font.SourceSans
        Temp.SubLabel.TextXAlignment = Enum.TextXAlignment.Left
        Temp.SubLabel.Parent = Temp.Frame
    end

    Temp.ValueBox = Instance.new("TextBox")
    Temp.ValueBox.Size = UDim2.new(0, 55, 0, 24)
    Temp.ValueBox.Position = UDim2.new(1, -65, 0.5, -12)
    Temp.ValueBox.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.ValueBox.Text = tostring(defaultValue)
    Temp.ValueBox.TextColor3 = Decode.Theme.TextMain
    Temp.ValueBox.TextSize = 12
    Temp.ValueBox.Font = Enum.Font.SourceSansBold
    Temp.ValueBox.Parent = Temp.Frame

    Temp.CornerBox = Instance.new("UICorner")
    Temp.CornerBox.CornerRadius = UDim.new(0, 4)
    Temp.CornerBox.Parent = Temp.ValueBox

    Temp.ValueBox.FocusLost:Connect(function()
        local num = tonumber(Temp.ValueBox.Text)
        if num and callback then
            callback(num)
        elseif callback then
            callback(defaultValue)
        end
    end)
    return Temp
end

function Decode:AddToggle(parentPage, toggleText, callback)
    local Temp = {}
    Temp.Frame = Instance.new("Frame")
    Temp.Frame.Size = UDim2.new(1, 0, 0, 36)
    Temp.Frame.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Frame.BackgroundTransparency = 0.6
    Temp.Frame.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Frame

    Temp.Label = Instance.new("TextLabel")
    Temp.Label.Size = UDim2.new(1, -60, 1, 0)
    Temp.Label.Position = UDim2.new(0, 10, 0, 0)
    Temp.Label.BackgroundTransparency = 1
    Temp.Label.Text = toggleText
    Temp.Label.TextColor3 = Decode.Theme.TextMain
    Temp.Label.TextSize = 13
    Temp.Label.Font = Enum.Font.SourceSans
    Temp.Label.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Label.Parent = Temp.Frame

    Temp.SwitchBg = Instance.new("Frame")
    Temp.SwitchBg.Size = UDim2.new(0, 32, 0, 16)
    Temp.SwitchBg.Position = UDim2.new(1, -45, 0.5, -8)
    Temp.SwitchBg.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.SwitchBg.Parent = Temp.Frame

    Temp.SwitchCorner = Instance.new("UICorner")
    Temp.SwitchCorner.CornerRadius = UDim.new(1, 0)
    Temp.SwitchCorner.Parent = Temp.SwitchBg

    Temp.SliderNode = Instance.new("Frame")
    Temp.SliderNode.Size = UDim2.new(0, 12, 0, 12)
    Temp.SliderNode.Position = UDim2.new(0, 2, 0.5, -6)
    Temp.SliderNode.BackgroundColor3 = Decode.Theme.TextMuted
    Temp.SliderNode.Parent = Temp.SwitchBg

    Temp.NodeCorner = Instance.new("UICorner")
    Temp.NodeCorner.CornerRadius = UDim.new(1, 0)
    Temp.NodeCorner.Parent = Temp.SliderNode

    Temp.ClickBtn = Instance.new("TextButton")
    Temp.ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    Temp.ClickBtn.BackgroundTransparency = 1
    Temp.ClickBtn.Text = ""
    Temp.ClickBtn.Parent = Temp.Frame

    Temp.IsToggled = false
    Temp.ClickBtn.MouseButton1Click:Connect(function()
        Temp.IsToggled = not Temp.IsToggled
        local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if Temp.IsToggled then
            TweenService:Create(Temp.SwitchBg, info, {BackgroundColor3 = Decode.Theme.AccentColor}):Play()
            TweenService:Create(Temp.SliderNode, info, {Position = UDim2.new(1, -14, 0.5, -6), BackgroundColor3 = Decode.Theme.TextMain}):Play()
        else
            TweenService:Create(Temp.SwitchBg, info, {BackgroundColor3 = Decode.Theme.MainBackground}):Play()
            TweenService:Create(Temp.SliderNode, info, {Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = Decode.Theme.TextMuted}):Play()
        end
        if callback then callback(Temp.IsToggled) end
    end)
    return Temp
end

function Decode:AddLabel(parentPage, text)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 24)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Decode.Theme.TextMuted
    Label.TextSize = 13
    Label.Font = Enum.Font.SourceSansBold
    Label.TextXAlignment = Enum.TextXAlignment.Center
    Label.Parent = parentPage
end

function Decode:AddSelector(parentPage, text, options, onSelect)
    local Temp = {}
    Temp.Frame = Instance.new("Frame")
    Temp.Frame.Size = UDim2.new(1, 0, 0, 36)
    Temp.Frame.BackgroundColor3 = Decode.Theme.ElementBackground
    Temp.Frame.BackgroundTransparency = 0.6
    Temp.Frame.Parent = parentPage

    Temp.Corner = Instance.new("UICorner")
    Temp.Corner.CornerRadius = UDim.new(0, 6)
    Temp.Corner.Parent = Temp.Frame

    Temp.Label = Instance.new("TextLabel")
    Temp.Label.Size = UDim2.new(0, 150, 1, 0)
    Temp.Label.Position = UDim2.new(0, 10, 0, 0)
    Temp.Label.BackgroundTransparency = 1
    Temp.Label.Text = text
    Temp.Label.TextColor3 = Decode.Theme.TextMain
    Temp.Label.TextSize = 13
    Temp.Label.Font = Enum.Font.SourceSansBold
    Temp.Label.TextXAlignment = Enum.TextXAlignment.Left
    Temp.Label.Parent = Temp.Frame

    Temp.SelectBtn = Instance.new("TextButton")
    Temp.SelectBtn.Size = UDim2.new(0, 120, 0, 26)
    Temp.SelectBtn.Position = UDim2.new(1, -130, 0.5, -13)
    Temp.SelectBtn.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.SelectBtn.Text = "Select Options"
    Temp.SelectBtn.TextColor3 = Decode.Theme.TextMuted
    Temp.SelectBtn.TextSize = 12
    Temp.SelectBtn.Font = Enum.Font.SourceSans
    Temp.SelectBtn.Parent = Temp.Frame

    Temp.SelectCorner = Instance.new("UICorner")
    Temp.SelectCorner.CornerRadius = UDim.new(0, 6)
    Temp.SelectCorner.Parent = Temp.SelectBtn

    Temp.Popup = Instance.new("Frame")
    Temp.Popup.Size = UDim2.new(0, 160, 0, 240)
    Temp.Popup.Position = UDim2.new(1, -175, 0, 45)
    Temp.Popup.BackgroundColor3 = Decode.Theme.SidebarBackground
    Temp.Popup.BorderSizePixel = 0
    Temp.Popup.Visible = false
    Temp.Popup.ZIndex = 50
    Temp.Popup.Parent = UI.FrameMain

    Temp.PopupCorner = Instance.new("UICorner")
    Temp.PopupCorner.CornerRadius = UDim.new(0, 8)
    Temp.PopupCorner.Parent = Temp.Popup

    Temp.PopupStroke = Instance.new("UIStroke")
    Temp.PopupStroke.Color = Decode.Theme.MainBackground
    Temp.PopupStroke.Thickness = 1
    Temp.PopupStroke.Parent = Temp.Popup

    Temp.SearchBox = Instance.new("TextBox")
    Temp.SearchBox.Size = UDim2.new(1, -20, 0, 24)
    Temp.SearchBox.Position = UDim2.new(0, 10, 0, 10)
    Temp.SearchBox.BackgroundColor3 = Decode.Theme.MainBackground
    Temp.SearchBox.Text = ""
    Temp.SearchBox.PlaceholderText = "Search"
    Temp.SearchBox.PlaceholderColor3 = Decode.Theme.TextMuted
    Temp.SearchBox.TextColor3 = Decode.Theme.TextMain
    Temp.SearchBox.TextSize = 12
    Temp.SearchBox.Font = Enum.Font.SourceSans
    Temp.SearchBox.ZIndex = 51
    Temp.SearchBox.Parent = Temp.Popup

    Temp.SearchCorner = Instance.new("UICorner")
    Temp.SearchCorner.CornerRadius = UDim.new(0, 4)
    Temp.SearchCorner.Parent = Temp.SearchBox

    Temp.Scroll = Instance.new("ScrollingFrame")
    Temp.Scroll.Size = UDim2.new(1, -10, 1, -50)
    Temp.Scroll.Position = UDim2.new(0, 5, 0, 45)
    Temp.Scroll.BackgroundTransparency = 1
    Temp.Scroll.BorderSizePixel = 0
    Temp.Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Temp.Scroll.ScrollBarThickness = 2
    Temp.Scroll.ScrollBarImageColor3 = Decode.Theme.AccentColor
    Temp.Scroll.ZIndex = 51
    Temp.Scroll.Parent = Temp.Popup

    Temp.Layout = Instance.new("UIListLayout")
    Temp.Layout.Padding = UDim.new(0, 4)
    Temp.Layout.Parent = Temp.Scroll

    Temp.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Temp.Scroll.CanvasSize = UDim2.new(0, 0, 0, Temp.Layout.AbsoluteContentSize.Y)
    end)

    function Temp:UpdateSelectionText(val)
        Temp.SelectBtn.TextWrapped = true
        if type(val) == "table" then
            if #val > 0 then
                local textStr = ""
                for i, option in ipairs(val) do
                    textStr = textStr .. (i == 1 and "" or ", ") .. option
                end
                Temp.SelectBtn.Text = textStr
                Temp.SelectBtn.TextColor3 = Decode.Theme.TextMain
                Temp.SelectBtn.TextSize = #textStr > 22 and 10 or 12
            else
                Temp.SelectBtn.Text = "Select Options"
                Temp.SelectBtn.TextColor3 = Decode.Theme.TextMuted
                Temp.SelectBtn.TextSize = 12
            end
        else
            if val and val ~= "" then
                Temp.SelectBtn.Text = tostring(val)
                Temp.SelectBtn.TextColor3 = Decode.Theme.TextMain
                Temp.SelectBtn.TextSize = string.len(tostring(val)) > 22 and 10 or 12
            else
                Temp.SelectBtn.Text = "Select Options"
                Temp.SelectBtn.TextColor3 = Decode.Theme.TextMuted
                Temp.SelectBtn.TextSize = 12
            end
        end
        
        for _, btn in pairs(Temp.Scroll:GetChildren()) do
            if btn:IsA("TextButton") then
                local btnText = string.gsub(btn.Text, "^%s+", "")
                if Temp.SelectBtn.Text == btnText or string.find(Temp.SelectBtn.Text, btnText .. ",") or string.find(Temp.SelectBtn.Text, ", " .. btnText) then
                    btn.BackgroundTransparency = 0.4
                else
                    btn.BackgroundTransparency = 1
                end
            end
        end
    end

    function Temp:Populate(list)
        for _, obj in pairs(Temp.Scroll:GetChildren()) do
            if obj:IsA("TextButton") then obj:Destroy() end
        end
        for _, optName in ipairs(list) do
            local OptBtn = Instance.new("TextButton")
            OptBtn.Size = UDim2.new(1, -5, 0, 28)
            OptBtn.BackgroundColor3 = Decode.Theme.AccentColor
            OptBtn.BackgroundTransparency = 1
            OptBtn.Text = "  " .. optName
            OptBtn.TextColor3 = Decode.Theme.TextMain
            OptBtn.TextSize = 13
            OptBtn.Font = Enum.Font.SourceSans
            OptBtn.TextXAlignment = Enum.TextXAlignment.Left
            OptBtn.ZIndex = 52
            OptBtn.Parent = Temp.Scroll

            local OptCorner = Instance.new("UICorner")
            OptCorner.CornerRadius = UDim.new(0, 4)
            OptCorner.Parent = OptBtn

            local currentText = Temp.SelectBtn.Text
            if currentText == optName or string.find(currentText, optName .. ",") or string.find(currentText, ", " .. optName) then
                OptBtn.BackgroundTransparency = 0.4
            end

            OptBtn.MouseButton1Click:Connect(function()
                if onSelect then
                    onSelect(optName, Temp)
                else
                    if Temp.SelectBtn.Text == optName then
                        Temp:UpdateSelectionText("")
                    else
                        Temp:UpdateSelectionText(optName)
                    end
                end
            end)
        end
    end

    if options then Temp:Populate(options) end

    Temp.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(Temp.SearchBox.Text)
        for _, btn in pairs(Temp.Scroll:GetChildren()) do
            if btn:IsA("TextButton") then
                if query == "" or string.find(string.lower(btn.Text), query) then
                    btn.Visible = true
                else
                    btn.Visible = false
                end
            end
        end
    end)

    local UserInputService = game:GetService("UserInputService")
    
    Temp.SelectBtn.MouseButton1Click:Connect(function()
        Temp.Popup.Visible = not Temp.Popup.Visible
    end)

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if Temp.Popup.Visible then
                local pos = input.Position
                local popupPos = Temp.Popup.AbsolutePosition
                local popupSize = Temp.Popup.AbsoluteSize
                local btnPos = Temp.SelectBtn.AbsolutePosition
                local btnSize = Temp.SelectBtn.AbsoluteSize

                local inPopup = pos.X >= popupPos.X and pos.X <= (popupPos.X + popupSize.X) and pos.Y >= popupPos.Y and pos.Y <= (popupPos.Y + popupSize.Y)
                local inBtn = pos.X >= btnPos.X and pos.X <= (btnPos.X + btnSize.X) and pos.Y >= btnPos.Y and pos.Y <= (btnPos.Y + btnSize.Y)

                if not inPopup and not inBtn then
                    Temp.Popup.Visible = false
                end
            end
        end
    end)
    
    return Temp
end

for _, name in ipairs(UI.PageList) do
    UI.CreatedPages[name] = Decode:CreateTab(name)
end

UI.DiscordDrop = Decode:CreateDropdown(UI.CreatedPages["Home"], "Discord")

UI.DiscordRow = Instance.new("Frame")
UI.DiscordRow.Name = "DiscordInviteRow"
UI.DiscordRow.Size = UDim2.new(1, 0, 0, 36)
UI.DiscordRow.BackgroundColor3 = Decode.Theme.ElementBackground
UI.DiscordRow.BackgroundTransparency = 0.6
UI.DiscordRow.Parent = UI.DiscordDrop

UI.DiscordRowCorner = Instance.new("UICorner")
UI.DiscordRowCorner.CornerRadius = UDim.new(0, 6)
UI.DiscordRowCorner.Parent = UI.DiscordRow

UI.DiscordLabel = Instance.new("TextLabel")
UI.DiscordLabel.Size = UDim2.new(0, 150, 1, 0)
UI.DiscordLabel.Position = UDim2.new(0, 10, 0, 0)
UI.DiscordLabel.BackgroundTransparency = 1
UI.DiscordLabel.Text = "Discord Invite"
UI.DiscordLabel.TextColor3 = Decode.Theme.TextMain
UI.DiscordLabel.TextSize = 13
UI.DiscordLabel.Font = Enum.Font.SourceSans
UI.DiscordLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.DiscordLabel.Parent = UI.DiscordRow

UI.CopyButton = Instance.new("TextButton")
UI.CopyButton.Name = "CopyBtn"
UI.CopyButton.Size = UDim2.new(0, 55, 0, 24)
UI.CopyButton.Position = UDim2.new(1, -65, 0.5, -12)
UI.CopyButton.BackgroundColor3 = Decode.Theme.MainBackground
UI.CopyButton.Text = "COPY"
UI.CopyButton.TextColor3 = Decode.Theme.TextMain
UI.CopyButton.TextSize = 12
UI.CopyButton.Font = Enum.Font.SourceSansBold
UI.CopyButton.Parent = UI.DiscordRow

UI.CopyCorner = Instance.new("UICorner")
UI.CopyCorner.CornerRadius = UDim.new(0, 4)
UI.CopyCorner.Parent = UI.CopyButton

UI.CopyButton.MouseButton1Click:Connect(function()
    local invite = "https://discord.gg/Q6SqhpEKGZ"
    local clipboard = env["setclipboard"] or env["toclipboard"]
    if clipboard then
        pcall(clipboard, invite)
    elseif env["request"] then
        pcall(env["request"], {
            Url = "http://localhost:24892/copy",
            Method = "POST",
            Body = invite
        })
    end
end)

UI.LocalPlayerDrop = Decode:CreateDropdown(UI.CreatedPages["Home"], "LocalPlayer")
UI.HarvestDrop = Decode:CreateDropdown(UI.CreatedPages["Main"], "Harvest")

function UI:UpdateCharacterSpeed()
    local Character = LocalPlayer.Character
    if Character then
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            if Configurations.SpeedEnabled then
                Humanoid.WalkSpeed = Configurations.Speed
            else
                Humanoid.WalkSpeed = UI.PlayerTracker.OriginalSpeed
            end
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function(Char)
    local Hum = Char:WaitForChild("Humanoid", 5)
    if Hum then
        UI.PlayerTracker.OriginalSpeed = Hum.WalkSpeed
        if Configurations.SpeedEnabled then
            Hum.WalkSpeed = Configurations.Speed
        end
    end
end)

RunService.Stepped:Connect(function()
    if Configurations.NoClipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Configurations.InfiniteJumpEnabled and LocalPlayer.Character then
        local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

UI.SpeedSlider = Decode:AddSlider(UI.LocalPlayerDrop, "Set Speed", Configurations.Speed, function(value)
    Configurations.Speed = value
    saveConfig()
    UI:UpdateCharacterSpeed()
end)

UI.WalkspeedToggle = Decode:AddToggle(UI.LocalPlayerDrop, "Enable Walkspeed", function(state)
    Configurations.SpeedEnabled = state
    saveConfig()
    if not state then
        local Character = LocalPlayer.Character
        if Character then
            local Humanoid = Character:FindFirstChildOfClass("Humanoid")
            if Humanoid then
                Humanoid.WalkSpeed = UI.PlayerTracker.OriginalSpeed
            end
        end
    else
        UI:UpdateCharacterSpeed()
    end
end)

UI.NoClipToggle = Decode:AddToggle(UI.LocalPlayerDrop, "No Clip", function(state)
    Configurations.NoClipEnabled = state
    saveConfig()
    if not state and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end)

UI.InfJumpToggle = Decode:AddToggle(UI.LocalPlayerDrop, "Infinite Jump", function(state)
    Configurations.InfiniteJumpEnabled = state
    saveConfig()
    if not state and LocalPlayer.Character then
        local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            Humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end)

Decode:AddLabel(UI.HarvestDrop, "- [ Configs ] -")

UI.StopCollectToggle = Decode:AddToggle(UI.HarvestDrop, "Stop Harvest If Backpack Is Full Max", function(state)
    Configurations.StopCollectIfFull = state
    saveConfig()
end)

UI.DelayCollectSlider = Decode:AddSlider(UI.HarvestDrop, "Delay To Harvest", Configurations.CollectDelay or 0, function(value)
    Configurations.CollectDelay = value
    saveConfig()
end)

UI.DisablePromptToggle = Decode:AddToggle(UI.HarvestDrop, "Disable Harvest Prompt", function(state)
    Configurations.DisableCollectPrompt = state
    saveConfig()
end)

Decode:AddLabel(UI.HarvestDrop, "- [ Options ] -")

UI.FruitSelector = Decode:AddSelector(UI.HarvestDrop, "Select Fruit", Decode:GetAssetCategory("Plants"), function(chosen, selectorObj)
    Configurations.HarvestFruitFilter = Configurations.HarvestFruitFilter or {}
    local idx = table.find(Configurations.HarvestFruitFilter, chosen)
    if idx then table.remove(Configurations.HarvestFruitFilter, idx) else table.insert(Configurations.HarvestFruitFilter, chosen) end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.HarvestFruitFilter)
end)

UI.MutationSelector = Decode:AddSelector(UI.HarvestDrop, "Select Mutation", Decode:GetGameMutations(), function(chosen, selectorObj)
    Configurations.HarvestMutationFilter = Configurations.HarvestMutationFilter or {}
    local idx = table.find(Configurations.HarvestMutationFilter, chosen)
    if idx then table.remove(Configurations.HarvestMutationFilter, idx) else table.insert(Configurations.HarvestMutationFilter, chosen) end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.HarvestMutationFilter)
end)

UI.ThresholdSelector = Decode:AddSelector(UI.HarvestDrop, "Select Threshold Mode", {"Above", "Below"}, function(chosen, selectorObj)
    if selectorObj.SelectBtn.Text == chosen then
        Configurations.ThresholdMode = ""
    else
        Configurations.ThresholdMode = chosen
    end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.ThresholdMode)
end)

UI.WeightSlider = Decode:AddSlider(UI.HarvestDrop, "Weight Threshold", Configurations.WeightThreshold or 0, function(value)
    Configurations.WeightThreshold = value
    saveConfig()
end, "if you don't want use this, just input '0'")

Decode:AddLabel(UI.HarvestDrop, "- [ Functions ] -")

UI.HarvestFruitsToggle = {}
UI.HarvestAllFruitsToggle = {}

UI.HarvestFruitsToggle = Decode:AddToggle(UI.HarvestDrop, "Harvest Fruits", function(state)
    Configurations.HarvestFruits = state
    saveConfig()
    if state and Configurations.HarvestAllFruits then
        Configurations.HarvestAllFruits = false
        saveConfig()
        if UI.HarvestAllFruitsToggle and type(UI.HarvestAllFruitsToggle) == "table" and UI.HarvestAllFruitsToggle.SwitchBg then
            UI.HarvestAllFruitsToggle.IsToggled = false
            TweenService:Create(UI.HarvestAllFruitsToggle.SwitchBg, TweenInfo.new(0.15), {BackgroundColor3 = Decode.Theme.MainBackground}):Play()
            TweenService:Create(UI.HarvestAllFruitsToggle.SliderNode, TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = Decode.Theme.TextMuted}):Play()
        end
    end
end)

UI.HarvestAllFruitsToggle = Decode:AddToggle(UI.HarvestDrop, "Harvest All Fruits", function(state)
    Configurations.HarvestAllFruits = state
    saveConfig()
    if state and Configurations.HarvestFruits then
        Configurations.HarvestFruits = false
        saveConfig()
        if UI.HarvestFruitsToggle and type(UI.HarvestFruitsToggle) == "table" and UI.HarvestFruitsToggle.SwitchBg then
            UI.HarvestFruitsToggle.IsToggled = false
            TweenService:Create(UI.HarvestFruitsToggle.SwitchBg, TweenInfo.new(0.15), {BackgroundColor3 = Decode.Theme.MainBackground}):Play()
            TweenService:Create(UI.HarvestFruitsToggle.SliderNode, TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = Decode.Theme.TextMuted}):Play()
        end
    end
end)

UI.SellDrop = Decode:CreateDropdown(UI.CreatedPages["Main"], "Sell")

Decode:AddLabel(UI.SellDrop, "- [ Configs ] -")

UI.AllowSellIfFullToggle = Decode:AddToggle(UI.SellDrop, "Allow Sell If Backpack Is Full Max", function(state)
    Configurations.AllowSellIfFull = state
    saveConfig()
end)

UI.DelaySellSlider = Decode:AddSlider(UI.SellDrop, "Delay To Sell", Configurations.SellDelay or 0, function(value)
    Configurations.SellDelay = value
    saveConfig()
end)

Decode:AddLabel(UI.SellDrop, "- [ Options ] -")

UI.SellFruitSelector = Decode:AddSelector(UI.SellDrop, "Select Fruit", Decode:GetAssetCategory("Plants"), function(chosen, selectorObj)
    Configurations.SellFruitFilter = Configurations.SellFruitFilter or {}
    local idx = table.find(Configurations.SellFruitFilter, chosen)
    if idx then 
        table.remove(Configurations.SellFruitFilter, idx) 
    else 
        table.insert(Configurations.SellFruitFilter, chosen) 
    end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.SellFruitFilter)
end)

UI.SellMutationSelector = Decode:AddSelector(UI.SellDrop, "Select Mutation", Decode:GetGameMutations(), function(chosen, selectorObj)
    Configurations.SellMutationFilter = Configurations.SellMutationFilter or {}
    local idx = table.find(Configurations.SellMutationFilter, chosen)
    if idx then 
        table.remove(Configurations.SellMutationFilter, idx) 
    else 
        table.insert(Configurations.SellMutationFilter, chosen) 
    end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.SellMutationFilter)
end)

UI.SellThresholdSelector = Decode:AddSelector(UI.SellDrop, "Select Threshold Mode", {"Above", "Below"}, function(chosen, selectorObj)
    if selectorObj.SelectBtn.Text == chosen then
        Configurations.SellThresholdMode = ""
    else
        Configurations.SellThresholdMode = chosen
    end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.SellThresholdMode)
end)

UI.SellWeightSlider = Decode:AddSlider(UI.SellDrop, "Weight Threshold", Configurations.SellWeightThreshold or 0, function(value)
    Configurations.SellWeightThreshold = value
    saveConfig()
end, "if you don't want use this, just input '0'")

Decode:AddLabel(UI.SellDrop, "- [ Functions ] -")

UI.SellFruitsToggle = {}
UI.SellAllFruitsToggle = {}

UI.SellFruitsToggle = Decode:AddToggle(UI.SellDrop, "Sell Fruits", function(state)
    Configurations.SellFruits = state
    saveConfig()
    if state and Configurations.SellAllFruits then
        Configurations.SellAllFruits = false
        saveConfig()
        if UI.SellAllFruitsToggle and type(UI.SellAllFruitsToggle) == "table" and UI.SellAllFruitsToggle.SwitchBg then
            UI.SellAllFruitsToggle.IsToggled = false
            TweenService:Create(UI.SellAllFruitsToggle.SwitchBg, TweenInfo.new(0.15), {BackgroundColor3 = Decode.Theme.MainBackground}):Play()
            TweenService:Create(UI.SellAllFruitsToggle.SliderNode, TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = Decode.Theme.TextMuted}):Play()
        end
    end
end)

UI.SellAllFruitsToggle = Decode:AddToggle(UI.SellDrop, "Sell All Fruits", function(state)
    Configurations.SellAllFruits = state
    saveConfig()
    if state and Configurations.SellFruits then
        Configurations.SellFruits = false
        saveConfig()
        if UI.SellFruitsToggle and type(UI.SellFruitsToggle) == "table" and UI.SellFruitsToggle.SwitchBg then
            UI.SellFruitsToggle.IsToggled = false
            TweenService:Create(UI.SellFruitsToggle.SwitchBg, TweenInfo.new(0.15), {BackgroundColor3 = Decode.Theme.MainBackground}):Play()
            TweenService:Create(UI.SellFruitsToggle.SliderNode, TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = Decode.Theme.TextMuted}):Play()
        end
    end
end)

UI.PetsDrop = Decode:CreateDropdown(UI.CreatedPages["Main"], "Pets")

Decode:AddLabel(UI.PetsDrop, "- [ Configs ] -")

UI.PetTweenSlider = Decode:AddSlider(UI.PetsDrop, "Tween Speed", Configurations.PetTweenSpeed or 0, function(value)
    Configurations.PetTweenSpeed = value
    saveConfig()
end)

Decode:AddLabel(UI.PetsDrop, "- [ Options ] -")

UI.PetsSelector = Decode:AddSelector(UI.PetsDrop, "Select Pets", {}, function(chosen, selectorObj)
    Configurations.SelectedPetsFilter = Configurations.SelectedPetsFilter or {}
    local idx = table.find(Configurations.SelectedPetsFilter, chosen)
    if idx then 
        table.remove(Configurations.SelectedPetsFilter, idx) 
    else 
        table.insert(Configurations.SelectedPetsFilter, chosen) 
    end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.SelectedPetsFilter)
end)

UI.PetSizeSelector = Decode:AddSelector(UI.PetsDrop, "Select Size/Type", {}, function(chosen, selectorObj)
    Configurations.SelectedPetSizeFilter = Configurations.SelectedPetSizeFilter or {}
    local idx = table.find(Configurations.SelectedPetSizeFilter, chosen)
    if idx then 
        table.remove(Configurations.SelectedPetSizeFilter, idx) 
    else 
        table.insert(Configurations.SelectedPetSizeFilter, chosen) 
    end
    saveConfig()
    selectorObj:UpdateSelectionText(Configurations.SelectedPetSizeFilter)
end)

Decode:AddLabel(UI.PetsDrop, "- [ Functions ] -")

UI.BuyPetsToggle = Decode:AddToggle(UI.PetsDrop, "Buy Pets", function(state)
    Configurations.AutoBuyPets = state
    saveConfig()
end)

task.spawn(function()
    task.wait(0.1)

    if Configurations.HarvestFruitFilter then
        UI.FruitSelector:UpdateSelectionText(Configurations.HarvestFruitFilter)
    end

    if Configurations.HarvestMutationFilter then
        UI.MutationSelector:UpdateSelectionText(Configurations.HarvestMutationFilter)
    end

    if Configurations.ThresholdMode and Configurations.ThresholdMode ~= "" then
        UI.ThresholdSelector:UpdateSelectionText(Configurations.ThresholdMode)
    end

    if Configurations.SpeedEnabled and UI.WalkspeedToggle then
        UI.WalkspeedToggle.IsToggled = true
        UI.WalkspeedToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.WalkspeedToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.WalkspeedToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
        UI:UpdateCharacterSpeed()
    end

    if Configurations.NoClipEnabled and UI.NoClipToggle then
        UI.NoClipToggle.IsToggled = true
        UI.NoClipToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.NoClipToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.NoClipToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.InfiniteJumpEnabled and UI.InfJumpToggle then
        UI.InfJumpToggle.IsToggled = true
        UI.InfJumpToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.InfJumpToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.InfJumpToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.StopCollectIfFull and UI.StopCollectToggle then
        UI.StopCollectToggle.IsToggled = true
        UI.StopCollectToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.StopCollectToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.StopCollectToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.DisableCollectPrompt and UI.DisablePromptToggle then
        UI.DisablePromptToggle.IsToggled = true
        UI.DisablePromptToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.DisablePromptToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.DisablePromptToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.HarvestFruits and UI.HarvestFruitsToggle then
        UI.HarvestFruitsToggle.IsToggled = true
        UI.HarvestFruitsToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.HarvestFruitsToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.HarvestFruitsToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.HarvestAllFruits and UI.HarvestAllFruitsToggle then
        UI.HarvestAllFruitsToggle.IsToggled = true
        UI.HarvestAllFruitsToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.HarvestAllFruitsToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.HarvestAllFruitsToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.SellFruitFilter then
        UI.SellFruitSelector:UpdateSelectionText(Configurations.SellFruitFilter)
    end

    if Configurations.SellMutationFilter then
        UI.SellMutationSelector:UpdateSelectionText(Configurations.SellMutationFilter)
    end

    if Configurations.SellThresholdMode and Configurations.SellThresholdMode ~= "" then
        UI.SellThresholdSelector:UpdateSelectionText(Configurations.SellThresholdMode)
    end

    if Configurations.AllowSellIfFull and UI.AllowSellIfFullToggle then
        UI.AllowSellIfFullToggle.IsToggled = true
        UI.AllowSellIfFullToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.AllowSellIfFullToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.AllowSellIfFullToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.SellFruits and UI.SellFruitsToggle then
        UI.SellFruitsToggle.IsToggled = true
        UI.SellFruitsToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.SellFruitsToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.SellFruitsToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

    if Configurations.SellAllFruits and UI.SellAllFruitsToggle then
        UI.SellAllFruitsToggle.IsToggled = true
        UI.SellAllFruitsToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.SellAllFruitsToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.SellAllFruitsToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end

        if Configurations.SelectedPetsFilter then
        UI.PetsSelector:UpdateSelectionText(Configurations.SelectedPetsFilter)
    end

    if Configurations.SelectedPetSizeFilter then
        UI.PetSizeSelector:UpdateSelectionText(Configurations.SelectedPetSizeFilter)
    end

    if Configurations.AutoBuyPets and UI.BuyPetsToggle then
        UI.BuyPetsToggle.IsToggled = true
        UI.BuyPetsToggle.SwitchBg.BackgroundColor3 = Decode.Theme.AccentColor
        UI.BuyPetsToggle.SliderNode.Position = UDim2.new(1, -14, 0.5, -6)
        UI.BuyPetsToggle.SliderNode.BackgroundColor3 = Decode.Theme.TextMain
    end
end)

task.spawn(function()
    local petAssetList = Decode:GetAssetCategory("Pets")
    local sizeAndTypeList = Decode:GetPetTypesAndSizes()
    
    if UI.PetsSelector and UI.PetsSelector.Populate then
        pcall(function() UI.PetsSelector:Populate(petAssetList) end)
    end
    
    if UI.PetSizeSelector and UI.PetSizeSelector.Populate then
        pcall(function() UI.PetSizeSelector:Populate(sizeAndTypeList) end)
    end
end)

UI.CloseTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
UI.ExitModal = Instance.new("Frame")
UI.ExitModal.Name = "ExitConfirmation"
UI.ExitModal.Size = UDim2.new(0, 320, 0, 200)
UI.ExitModal.Position = UDim2.new(0.5, -160, 0.5, -100)
UI.ExitModal.BackgroundColor3 = Decode.Theme.SidebarBackground
UI.ExitModal.BackgroundTransparency = 0.05
UI.ExitModal.BorderSizePixel = 0
UI.ExitModal.Visible = false
UI.ExitModal.ZIndex = 10
UI.ExitModal.Parent = UI.FrameMain

UI.ModalCorner = Instance.new("UICorner")
UI.ModalCorner.CornerRadius = UDim.new(0, 12)
UI.ModalCorner.Parent = UI.ExitModal

UI.ModalStroke = Instance.new("UIStroke")
UI.ModalStroke.Color = Decode.Theme.AccentColor
UI.ModalStroke.Thickness = 1
UI.ModalStroke.Parent = UI.ExitModal

UI.WarnIcon = Instance.new("TextLabel")
UI.WarnIcon.Size = UDim2.new(1, 0, 0, 40)
UI.WarnIcon.Position = UDim2.new(0, 0, 0, 15)
UI.WarnIcon.BackgroundTransparency = 1
UI.WarnIcon.Text = "⚠️"
UI.WarnIcon.TextSize = 28
UI.WarnIcon.ZIndex = 11
UI.WarnIcon.Parent = UI.ExitModal

UI.ConfirmHeader = Instance.new("TextLabel")
UI.ConfirmHeader.Size = UDim2.new(1, 0, 0, 25)
UI.ConfirmHeader.Position = UDim2.new(0, 0, 0, 60)
UI.ConfirmHeader.BackgroundTransparency = 1
UI.ConfirmHeader.Text = "Exit Confirmation"
UI.ConfirmHeader.TextColor3 = Decode.Theme.TextMain
UI.ConfirmHeader.TextSize = 16
UI.ConfirmHeader.Font = Enum.Font.SourceSansBold
UI.ConfirmHeader.ZIndex = 11
UI.ConfirmHeader.Parent = UI.ExitModal

UI.ConfirmDesc = Instance.new("TextLabel")
UI.ConfirmDesc.Size = UDim2.new(1, -40, 0, 35)
UI.ConfirmDesc.Position = UDim2.new(0, 20, 0, 85)
UI.ConfirmDesc.BackgroundTransparency = 1
UI.ConfirmDesc.Text = "Are you sure you want to close the UI?"
UI.ConfirmDesc.TextColor3 = Decode.Theme.TextMuted
UI.ConfirmDesc.TextSize = 13
UI.ConfirmDesc.Font = Enum.Font.SourceSans
UI.ConfirmDesc.TextWrapped = true
UI.ConfirmDesc.ZIndex = 11
UI.ConfirmDesc.Parent = UI.ExitModal

UI.YesBtn = Instance.new("TextButton")
UI.YesBtn.Name = "YesButton"
UI.YesBtn.Size = UDim2.new(0, 125, 0, 35)
UI.YesBtn.Position = UDim2.new(0, 25, 1, -50)
UI.YesBtn.BackgroundColor3 = Decode.Theme.ElementBackground
UI.YesBtn.Text = "Yes"
UI.YesBtn.TextColor3 = Decode.Theme.TextMain
UI.YesBtn.TextSize = 14
UI.YesBtn.Font = Enum.Font.SourceSansBold
UI.YesBtn.ZIndex = 11
UI.YesBtn.Parent = UI.ExitModal

UI.YesCorner = Instance.new("UICorner")
UI.YesCorner.CornerRadius = UDim.new(0, 6)
UI.YesCorner.Parent = UI.YesBtn

UI.NoBtn = Instance.new("TextButton")
UI.NoBtn.Name = "NoButton"
UI.NoBtn.Size = UDim2.new(0, 125, 0, 35)
UI.NoBtn.Position = UDim2.new(1, -150, 1, -50)
UI.NoBtn.BackgroundColor3 = Decode.Theme.ElementBackground
UI.NoBtn.Text = "No"
UI.NoBtn.TextColor3 = Decode.Theme.TextMain
UI.NoBtn.TextSize = 14
UI.NoBtn.Font = Enum.Font.SourceSansBold
UI.NoBtn.ZIndex = 11
UI.NoBtn.Parent = UI.ExitModal

UI.NoCorner = Instance.new("UICorner")
UI.NoCorner.CornerRadius = UDim.new(0, 6)
UI.NoCorner.Parent = UI.NoBtn

UI.CloseButton.MouseButton1Click:Connect(function()
    UI.ExitModal.Size = UDim2.new(0, 0, 0, 0)
    UI.ExitModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    UI.ExitModal.Visible = true
    local OpenTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(UI.ExitModal, OpenTweenInfo, {
        Size = UDim2.new(0, 320, 0, 200),
        Position = UDim2.new(0.5, -160, 0.5, -100)
    }):Play()
end)

local function closePopup()
    local tween = TweenService:Create(UI.ExitModal, UI.CloseTweenInfo, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    })
    tween:Play()
    tween.Completed:Connect(function()
        UI.ExitModal.Visible = false
    end)
end

UI.NoBtn.MouseButton1Click:Connect(closePopup)

UI.YesBtn.MouseButton1Click:Connect(function()
    UI.ScreenGui:Destroy()
end)

function Decode:Init()
    if UI.FirstTab then
        UI.FirstTab.Page.Visible = true
        UI.FirstTab.Button.BackgroundTransparency = 0.8
        UI.FirstTab.Button.TextColor3 = Decode.Theme.TextMain
    end
end


print("Decode: UI Loaded.")
Decode:Init()
return Decode
