local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local cachedGardenSyncController = nil
local currentLockedTarget = nil
local currentLockedPrompt = nil

task.spawn(function()
    local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 10)
    if playerScripts then
        for _, obj in ipairs(playerScripts:GetDescendants()) do
            if obj:IsA("ModuleScript") and obj.Name == "GardenSyncController" then
                local success, result = pcall(require, obj)
                if success then cachedGardenSyncController = result end
                break
            end
        end
    end
end)

local function checkBackpackIsMax()
    local isMax = false
    
    pcall(function()
        local currentFruits = LocalPlayer:GetAttribute("FruitCount") or LocalPlayer:GetAttribute("Fruits") or LocalPlayer:GetAttribute("CurrentFruits") or 0
        local maxFruits = LocalPlayer:GetAttribute("MaxFruits") or LocalPlayer:GetAttribute("MaxFruit") or LocalPlayer:GetAttribute("FruitCapacity") or 0
        
        if currentFruits == 0 or maxFruits == 0 then
            for key, val in pairs(LocalPlayer:GetAttributes()) do
                local lowerKey = tostring(key):lower()
                if lowerKey:find("fruit") then
                    if lowerKey:find("max") or lowerKey:find("cap") then
                        maxFruits = tonumber(val) or maxFruits
                    else
                        currentFruits = tonumber(val) or currentFruits
                    end
                end
            end
        end
        
        if maxFruits > 0 and currentFruits >= maxFruits then
            isMax = true
        end
    end)

    if not isMax then
        pcall(function()
            local mainGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MainGui")
            if mainGui then
                local weightBar = mainGui:FindFirstChild("Frames") 
                    and mainGui.Frames:FindFirstChild("Inventory") 
                    and mainGui.Frames.Inventory:FindFirstChild("WeightBar") 
                    and mainGui.Frames.Inventory.WeightBar:FindFirstChild("TextLabel")
                    
                if weightBar and weightBar.Text then
                    local cleanText = weightBar.Text:gsub("%s+", "")
                    local current, max = cleanText:match("(%d+)/(%d+)")
                    if current and max and tonumber(current) >= tonumber(max) then
                        isMax = true
                    end
                    if weightBar.Text:upper():find("FULL") or weightBar.Text:upper():find("MAX") then
                        isMax = true
                    end
                end
            end
        end)
    end
    
    if not isMax then
        pcall(function()
            local sharedMod = ReplicatedStorage:FindFirstChild("SharedModules")
            local networkingMod = sharedMod and sharedMod:FindFirstChild("Networking")
            if networkingMod then
                local success, network = pcall(require, networkingMod)
                if success and network and network.NPCS and network.NPCS.PreviewSellAll then
                    local preview = network.NPCS.PreviewSellAll:Fire()
                    if preview and preview.FruitCount and preview.FruitCount >= 100 then
                        isMax = true
                    end
                end
            end
        end)
    end
   
    return isMax
end

local function getUnharvestedFruitKg(instanceObject)
    local kg = 0
    pcall(function()
        local plantModules = ReplicatedStorage:WaitForChild("PlantGenerationModules")
        if instanceObject:GetAttribute("CorePartName") then
            local fruitName = instanceObject:GetAttribute("CorePartName") or instanceObject.Name
            local fruitFolder = plantModules:WaitForChild("Fruits")
            local module = fruitFolder:FindFirstChild(fruitName)
            if not module then return end
            local data = require(module)
            local baseWeight = data.GrowData and data.GrowData.BaseWeight or 0
            local sizeMulti = instanceObject:GetAttribute("SizeMulti") or 1
            local overtimeGrowth = instanceObject:GetAttribute("OvertimeGrowth") or instanceObject:GetAttribute("GrowRateMulti") or 1
            kg = baseWeight * sizeMulti * overtimeGrowth
            return
        end
        local seedName = instanceObject:GetAttribute("SeedName") or instanceObject.Name
        local plantFolder = plantModules:WaitForChild("Plants")
        local module = plantFolder:FindFirstChild(seedName)
        if not module then return end
        local data = require(module)
        local baseWeight = data.GrowData and data.GrowData.BaseWeight
        if not baseWeight then return end
        local sizeMultiplier = 1
        local overtimeGrowth = 1
        local userId = tonumber(instanceObject:GetAttribute("UserId"))
        local plantId = instanceObject:GetAttribute("PlantId")
        
        if userId and plantId and cachedGardenSyncController then
            pcall(function()
                local plantData = cachedGardenSyncController:GetPlant(userId, tostring(plantId))
                if plantData then
                    sizeMultiplier = plantData.SizeMultiplier or 1
                    overtimeGrowth = plantData.OvertimeGrowth or 1
                end
            end)
        end
        kg = baseWeight * sizeMultiplier * overtimeGrowth
    end)
    return kg
end

local function harvestAllFruits()
    local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
    if not Configs then return end

    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return end

    pcall(function()
        local validPromptsToTrigger = {}
        local promptCount = 0
        local localPlayerName = LocalPlayer.Name
        local localPlayerUserId = LocalPlayer.UserId

        for _, plot in ipairs(gardens:GetChildren()) do
            
            local isMyPlot = (plot.Name == localPlayerName) 
                or (plot:GetAttribute("Owner") == localPlayerName) 
                or (plot:GetAttribute("OwnerId") == localPlayerUserId)
                or (plot:FindFirstChild("Owner") and plot.Owner.Value == localPlayerName)
            if not isMyPlot then continue end

            local plantsFolder = plot:FindFirstChild("Plants")
            if not plantsFolder then continue end

            for _, plant in ipairs(plantsFolder:GetChildren()) do
                
                local plantSeedName = plant:GetAttribute("SeedName") or plant.Name
                local rawPlantMutation = plant:GetAttribute("Mutation")
                local plantMutation = (rawPlantMutation and rawPlantMutation ~= "") and tostring(rawPlantMutation) or "Normal"
                local fruitsFolder = plant:FindFirstChild("Fruits")
                
                if fruitsFolder then
                    for _, fruit in ipairs(fruitsFolder:GetChildren()) do

                        local rawFruitName = fruit:GetAttribute("CorePartName") or plantSeedName or fruit.Name
                        local rawFruitMutation = fruit:GetAttribute("Mutation")
                        local fruitMutation = (rawFruitMutation and rawFruitMutation ~= "") and tostring(rawFruitMutation) or "Normal"

                        local shouldHarvest = false
                        if Configs.HarvestAllFruits then
                            shouldHarvest = true
                        elseif Configs.HarvestFruits then
                            local matchFruit = Configs.HarvestFruitFilter and table.find(Configs.HarvestFruitFilter, rawFruitName)
                            local matchMut = Configs.HarvestMutationFilter and table.find(Configs.HarvestMutationFilter, fruitMutation)
                            if matchFruit or matchMut then shouldHarvest = true end
                        end

                        if shouldHarvest and Configs.ThresholdMode and Configs.ThresholdMode ~= "" then
                            local targetValue = tonumber(Configs.WeightThreshold) or 0
                            if targetValue > 0 then
                                local currentFruitKg = getUnharvestedFruitKg(fruit)
                                if Configs.ThresholdMode == "Below" and currentFruitKg > targetValue then shouldHarvest = false
                                elseif Configs.ThresholdMode == "Above" and currentFruitKg < targetValue then shouldHarvest = false end
                            end
                        end

                        if shouldHarvest then
                            local harvestPart = fruit:FindFirstChild("HarvestPart")
                            local prompt = harvestPart and harvestPart:FindFirstChild("HarvestPrompt")
                            if prompt and prompt:IsA("ProximityPrompt") then
                                promptCount = promptCount + 1
                                validPromptsToTrigger[promptCount] = prompt
                            end
                        end
                    end
                else
                    if plant:GetAttribute("PlantGrowthReady") == true then
                        local shouldHarvest = false

                        if Configs.HarvestAllFruits then
                            shouldHarvest = true
                        elseif Configs.HarvestFruits then
                            local matchFruit = Configs.HarvestFruitFilter and table.find(Configs.HarvestFruitFilter, plantSeedName)
                            local matchMut = Configs.HarvestMutationFilter and table.find(Configs.HarvestMutationFilter, plantMutation)
                            if matchFruit or matchMut then shouldHarvest = true end
                        end

                        if shouldHarvest and Configs.ThresholdMode and Configs.ThresholdMode ~= "" then
                            local targetValue = tonumber(Configs.WeightThreshold) or 0
                            if targetValue > 0 then
                                local currentFruitKg = getUnharvestedFruitKg(plant)
                                if Configs.ThresholdMode == "Below" and currentFruitKg > targetValue then shouldHarvest = false
                                elseif Configs.ThresholdMode == "Above" and currentFruitKg < targetValue then shouldHarvest = false end
                            end
                        end

                        if shouldHarvest then
                            local harvestPart = plant:FindFirstChild("HarvestPart") or plant
                            local prompt = harvestPart:FindFirstChildOfClass("ProximityPrompt") or plant:FindFirstChildOfClass("ProximityPrompt")
                            if prompt and prompt:IsA("ProximityPrompt") then
                                promptCount = promptCount + 1
                                validPromptsToTrigger[promptCount] = prompt
                            end
                        end
                    end
                end
            end
        end

        if promptCount > 0 then
            local rawEnv = getfenv()
            local triggerPrompt = rawEnv["fireproximityprompt"] or _G.fireproximityprompt
            for i = 1, promptCount do
                local prompt = validPromptsToTrigger[i]
                if triggerPrompt then
                    triggerPrompt(prompt)
                else
                    prompt:InputHoldBegin()
                    prompt:InputHoldEnd()
                end
            end
        end
    end)
end

local function fireSellRemote()
    local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
    if not Configs then return end
    local sharedMod = ReplicatedStorage:FindFirstChild("SharedModules")
    local networkingMod = sharedMod and sharedMod:FindFirstChild("Networking")
    
    if networkingMod then
        local success, network = pcall(require, networkingMod)
        if success and network and network.NPCS then
            local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:FindFirstChildOfClass("Backpack")
            local character = LocalPlayer.Character
            
            if backpack and character then
                local itemsToProcess = {}
                for _, item in ipairs(backpack:GetChildren()) do table.insert(itemsToProcess, item) end
                for _, item in ipairs(character:GetChildren()) do table.insert(itemsToProcess, item) end
                
                if Configs.SellAllFruits then
                    if Configs.SellThresholdMode == "" or (tonumber(Configs.SellWeightThreshold) or 0) == 0 then
                        if network.NPCS.SellAll then
                            local preview = network.NPCS.PreviewSellAll:Fire()
                            if preview and (preview.FruitCount or 0) > 0 then network.NPCS.SellAll:Fire() end
                        end
                        return
                    end
                end

                for _, item in ipairs(itemsToProcess) do
                    local trueServerIdToken = item:GetAttribute("Id")
                    if trueServerIdToken and trueServerIdToken ~= "" then
                        local shouldSellThisItem = false
                        
                        if Configs.SellAllFruits then
                            shouldSellThisItem = true
                        elseif Configs.SellFruits then
                            local rawFruitName = item:GetAttribute("Fruit") or item.Name
                            local targetFruitLower = tostring(rawFruitName):lower()
                            local rawMutation = item:GetAttribute("Mutation")
                            local fruitMutation = (rawMutation and rawMutation ~= "") and tostring(rawMutation):lower():gsub("%s+", "") or "normal"
                            
                            if Configs.SellMutationFilter and #Configs.SellMutationFilter > 0 then
                                for _, allowedMut in ipairs(Configs.SellMutationFilter) do
                                    if fruitMutation == tostring(allowedMut):lower():gsub("%s+", "") then
                                        shouldSellThisItem = true
                                        break
                                    end
                                end
                            end
                            if not shouldSellThisItem and Configs.SellFruitFilter and #Configs.SellFruitFilter > 0 then
                                for _, allowedFruit in ipairs(Configs.SellFruitFilter) do
                                    if targetFruitLower == tostring(allowedFruit):lower() then
                                        shouldSellThisItem = true
                                        break
                                    end
                                end
                            end
                        end

                        if shouldSellThisItem and Configs.SellThresholdMode and Configs.SellThresholdMode ~= "" then
                            local targetValue = tonumber(Configs.SellWeightThreshold) or 0
                            if targetValue > 0 then
                                local currentItemKg = tonumber(item:GetAttribute("Weight")) or 0
                                if Configs.SellThresholdMode == "Below" and currentItemKg > targetValue then shouldSellThisItem = false
                                elseif Configs.SellThresholdMode == "Above" and currentItemKg < targetValue then shouldSellThisItem = false end
                            end
                        end

                        if shouldSellThisItem and network.NPCS.SellFruit then
                            task.spawn(function()
                                pcall(function() network.NPCS.SellFruit:Fire(trueServerIdToken, LocalPlayer) end)
                            end)
                        end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
        if Configs and (Configs.HarvestAllFruits or Configs.HarvestFruits) then
            if Configs.StopCollectIfFull and checkBackpackIsMax() then
                task.wait(0.1)
            else
                task.spawn(harvestAllFruits)
                local harvestDelay = tonumber(Configs.CollectDelay) or 0.01
                task.wait(math.max(harvestDelay, 0.01))
            end
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
        if Configs and (Configs.SellAllFruits or Configs.SellFruits) then
            if Configs.AllowSellIfFull and checkBackpackIsMax() then
                task.spawn(fireSellRemote)
                local sellDelay = tonumber(Configs.SellDelay) or 0.01
                task.wait(math.max(sellDelay, 0.01))
            elseif not Configs.AllowSellIfFull then
                task.spawn(fireSellRemote)
                local sellDelay = tonumber(Configs.SellDelay) or 0.01
                task.wait(math.max(sellDelay, 0.01))
            else
                task.wait(0.1)
            end
        else
            task.wait(0.5)
        end
    end
end)

local function getActiveFilterSignature()
    local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
    if not Configs then return "" end
    
    local signature = tostring(Configs.AutoBuyPets) .. tostring(Configs.PetTweenSpeed)
    if Configs.SelectedPetsFilter then
        for _, val in ipairs(Configs.SelectedPetsFilter) do signature = signature .. tostring(val) end
    end
    if Configs.SelectedPetSizeFilter then
        for _, val in ipairs(Configs.SelectedPetSizeFilter) do signature = signature .. tostring(val) end
    end
    return signature
end

local function processAutoWalkPurchaseLoop()
    while true do
        local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
        if not Configs or not Configs.AutoBuyPets then 
            task.wait(0.5)
            continue 
        end
        
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local rootPart = character:WaitForChild("HumanoidRootPart", 5)
        local humanoid = character:WaitForChild("Humanoid", 5)
        
        if not rootPart or not humanoid then 
            task.wait(0.5)
            continue 
        end
        
        local startingFilterSignature = getActiveFilterSignature()
        local mapFolder = workspace:FindFirstChild("Map")
        local wildPetSpawns = mapFolder and mapFolder:FindFirstChild("WildPetSpawns")
        local wildPetRef = mapFolder and mapFolder:FindFirstChild("WildPetRef")
        local targetPrompt = nil
        local targetPart = nil
        
        if wildPetSpawns then
            for _, spawnInstance in ipairs(wildPetSpawns:GetChildren()) do
                local prompt = spawnInstance:FindFirstChild("BuyPrompt", true) or spawnInstance:FindFirstChildOfClass("ProximityPrompt", true)
                
                if prompt and prompt:IsA("ProximityPrompt") then
                    local root = prompt.Parent:IsA("BasePart") and prompt.Parent or spawnInstance:FindFirstChildOfClass("BasePart")
                    
                    if root then
                        local spawnedGuid = spawnInstance.Name:match("([%x%-]+)$")
                        local companionRefInstance = spawnedGuid and wildPetRef and wildPetRef:FindFirstChild("WildPet_" .. spawnedGuid)
                        
                        local currentSize = ""
                        local currentType = ""
                        
                        if companionRefInstance then
                            local rawSize = companionRefInstance:GetAttribute("PetSize") or companionRefInstance:GetAttribute("Size")
                            local rawType = companionRefInstance:GetAttribute("PetType") or companionRefInstance:GetAttribute("Type")
                            
                            if rawSize and tostring(rawSize) ~= "" and tostring(rawSize):lower() ~= "normal" then 
                                currentSize = tostring(rawSize):lower() 
                            end
                            if rawType and tostring(rawType) ~= "" and tostring(rawType):lower() ~= "normal" then 
                                currentType = tostring(rawType):lower() 
                            end
                        end
                        
                        local petFilterActive = Configs.SelectedPetsFilter and #Configs.SelectedPetsFilter > 0
                        local sizeTypeFilterActive = Configs.SelectedPetSizeFilter and #Configs.SelectedPetSizeFilter > 0
                        
                        local matchesPet = false
                        local matchesSizeOrType = false
                        
                        local rawSpawnNameLower = spawnInstance.Name:lower()

                        if petFilterActive then
                            for _, whitelistedName in ipairs(Configs.SelectedPetsFilter) do
                                if string.find(rawSpawnNameLower, tostring(whitelistedName):lower(), 1, true) then
                                    matchesPet = true
                                    break
                                end
                            end
                        end
                        
                        if sizeTypeFilterActive then
                            for _, allowedCriteria in ipairs(Configs.SelectedPetSizeFilter) do
                                local lowerCriteria = tostring(allowedCriteria):lower()
                                -- Completely case-insensitive check to guarantee matching across obfuscation boundaries
                                if currentSize:lower() == lowerCriteria or currentType:lower() == lowerCriteria then
                                    matchesSizeOrType = true
                                    break
                                end
                            end
                        end
                        
                        local shouldTargetPet = false
                        
                        if petFilterActive or sizeTypeFilterActive then
                            local matchesPetCondition = petFilterActive and matchesPet
                            local matchesSizeCondition = sizeTypeFilterActive and matchesSizeOrType
                            
                            if matchesPetCondition or matchesSizeCondition then 
                                shouldTargetPet = true 
                            end
                        else
                            shouldTargetPet = false
                        end
                        
                        if shouldTargetPet then
                            targetPrompt = prompt
                            targetPart = root
                            break
                        end
                    end
                end
            end
        end

        if targetPart and targetPrompt then
            local originalCollisions = {}
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    originalCollisions[part] = part.CanCollide
                    part.CanCollide = false
                end
            end
            
            local currentHeightOffset = 3.2
            local currentPos = rootPart.Position
            local targetPos = targetPart.Position + Vector3.new(0, currentHeightOffset, 0)
            
            local distance = (targetPos - currentPos).Magnitude
            local speed = tonumber(Configs.PetTweenSpeed) or 50
            if speed <= 0 then speed = 50 end
            local duration = distance / speed
            
            rootPart.CFrame = CFrame.lookAt(currentPos, Vector3.new(targetPos.X, currentPos.Y, targetPos.Z))
            
            local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
            local targetCFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(rootPart.Orientation.Y), 0)
            local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
            
            tween:Play()
            
            local wasCancelled = false

            while tween.PlaybackState == Enum.PlaybackState.Playing do
                if startingFilterSignature ~= getActiveFilterSignature() or not Configs.AutoBuyPets then
                    tween:Cancel()
                    wasCancelled = true
                    break
                end
                task.wait()
            end

            if wasCancelled or not Configs.AutoBuyPets then
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                for part, originalState in pairs(originalCollisions) do
                    if part and part.Parent then part.CanCollide = originalState end
                end
                humanoid.Jump = true
                if startingFilterSignature ~= getActiveFilterSignature() then
                    task.wait(0.1)
                    continue
                end
                break
            end
            
            if Configs.AutoBuyPets and targetPart:IsDescendantOf(workspace) then
                targetPrompt.RequiresLineOfSight = false 
                targetPrompt.ClickablePrompt = true       
                
                while Configs.AutoBuyPets and targetPart:IsDescendantOf(workspace) and targetPrompt:IsDescendantOf(workspace) do
                    if startingFilterSignature ~= getActiveFilterSignature() or not Configs.AutoBuyPets then 
                        targetPrompt:InputHoldEnd()
                        break 
                    end

                    local escortPetCFrame = targetPart.CFrame
                    local balancedEscortPos = escortPetCFrame.Position + Vector3.new(0, 3.2, 0)
                    rootPart.CFrame = CFrame.new(balancedEscortPos) * CFrame.Angles(0, math.rad(escortPetCFrame.Rotation.Y), 0)
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

                    targetPrompt:InputHoldBegin()
                    local rawEnv = getfenv()
                    local triggerPrompt = rawEnv["fireproximityprompt"] or _G.fireproximityprompt
                    if triggerPrompt then
                        triggerPrompt(targetPrompt)
                    else
                        targetPrompt:InputHoldEnd()
                    end
                    
                    task.wait() 
                end
            end
            
            rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            
            for part, originalState in pairs(originalCollisions) do
                if part and part.Parent then
                    part.CanCollide = originalState
                end
            end
            
            humanoid.Jump = true
            task.wait(0.1)
        else
            task.wait(0.3)
        end
    end
end

task.spawn(function()
    pcall(processAutoWalkPurchaseLoop)
end)

task.spawn(function()
    while true do
        local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
        if Configs and Configs.AutoCollectEventSeeds == true then
            pcall(function()
                local mapFolder = workspace:FindFirstChild("Map")
                local clientFolder = mapFolder and mapFolder:FindFirstChild("SeedPackSpawnClient")
                local serverLocations = mapFolder and mapFolder:FindFirstChild("SeedPackSpawnServerLocations")
                
                if not clientFolder or not serverLocations then return end
                
                local localCharacter = LocalPlayer.Character
                local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
                local localHumanoid = localCharacter and localCharacter:FindFirstChildOfClass("Humanoid")
                
                if not localRoot or not localHumanoid or localHumanoid.Health <= 0 then return end
                
                local stillValid = false
                if currentLockedTarget and currentLockedTarget.Parent and currentLockedPrompt and currentLockedPrompt.Parent then
                    stillValid = true
                else
                    currentLockedTarget = nil
                    currentLockedPrompt = nil
                end
                
                if not stillValid then
                    local activeDrops = clientFolder:GetChildren()
                    local closestDistance = math.huge
                    
                    for idx = 1, #activeDrops do
                        local container = activeDrops[idx]
                        local visualPart = container:IsA("BasePart") and container or container:FindFirstChildOfClass("BasePart", true)
                        
                        if visualPart then
                            local dropPosition = visualPart.Position
                            local distanceToPlayer = (dropPosition - localRoot.Position).Magnitude
                            
                            if distanceToPlayer < closestDistance then
                                local closestPrompt = nil
                                local shortestPromptDistance = math.huge
                                
                                for _, locationPart in ipairs(serverLocations:GetChildren()) do
                                    if locationPart:IsA("BasePart") then
                                        local prompt = locationPart:FindFirstChildOfClass("ProximityPrompt")
                                        if prompt then
                                            local distanceToPrompt = (locationPart.Position - dropPosition).Magnitude
                                            if distanceToPrompt < shortestPromptDistance and distanceToPrompt < 8 then
                                                shortestPromptDistance = distanceToPrompt
                                                closestPrompt = prompt
                                            end
                                        end
                                    end
                                end
                                
                                if closestPrompt then
                                    closestDistance = distanceToPlayer
                                    currentLockedTarget = visualPart
                                    currentLockedPrompt = closestPrompt
                                end
                            end
                        end
                    end
                end

                if currentLockedTarget and currentLockedPrompt then
                    local targetPosition = currentLockedTarget.Position
                    local distance = (targetPosition - localRoot.Position).Magnitude
                    local speed = tonumber(Configs.CollectTweenSpeed) or 16
                    
                    if distance > 3 then
                        if speed > 50 then
                            localRoot.CFrame = CFrame.new(targetPosition)
                            task.wait(0.05)
                        else
                            if speed <= 5 then speed = 16 end
                            local startCFrame = localRoot.CFrame
                            local targetCFrame = CFrame.new(targetPosition)
                            local duration = distance / speed
                            local elapsed = 0
                            
                            local antiGravityConn
                            antiGravityConn = game:GetService("RunService").PostSimulation:Connect(function()
                                if localRoot then 
                                    localRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0) 
                                end
                            end)
                            
                            while elapsed < duration and Configs.AutoCollectEventSeeds == true and localHumanoid.Health > 0 do
                                if not currentLockedTarget or not currentLockedTarget.Parent or not currentLockedPrompt or not currentLockedPrompt.Parent then
                                    currentLockedTarget = nil
                                    currentLockedPrompt = nil
                                    break
                                end
                                
                                elapsed = elapsed + task.wait()
                                local alpha = math.clamp(elapsed / duration, 0, 1)
                                localRoot.CFrame = startCFrame:Lerp(targetCFrame, alpha)
                            end
                            
                            if antiGravityConn then antiGravityConn:Disconnect() end
                        end
                    end

                    if currentLockedTarget and currentLockedTarget.Parent and currentLockedPrompt and currentLockedPrompt.Parent and Configs.AutoCollectEventSeeds == true and localHumanoid.Health > 0 then
                        currentLockedPrompt.RequiresLineOfSight = false
                        currentLockedPrompt.ClickablePrompt = true
                        
                        local oldHold = currentLockedPrompt.HoldDuration
                        currentLockedPrompt.HoldDuration = 0
                        
                        currentLockedPrompt.Enabled = false
                        task.wait()
                        currentLockedPrompt.Enabled = true

                        local maximumRetryTimeout = 0
                        while currentLockedTarget and currentLockedTarget.Parent and currentLockedPrompt and currentLockedPrompt.Parent and maximumRetryTimeout < 15 do
                            if Configs.AutoCollectEventSeeds ~= true or localHumanoid.Health <= 0 then break end
                            
                            local rawEnv = getfenv()
                            local triggerPrompt = rawEnv["fireproximityprompt"] or _G.fireproximityprompt
                            if triggerPrompt then
                                triggerPrompt(currentLockedPrompt, 1)
                            else
                                currentLockedPrompt:InputHoldBegin()
                                task.wait(0.01)
                                currentLockedPrompt:InputHoldEnd()
                            end
                            
                            maximumRetryTimeout = maximumRetryTimeout + 1
                            task.wait(0.03)
                        end
                        
                        pcall(function() currentLockedPrompt.HoldDuration = oldHold end)
                        
                        currentLockedTarget = nil
                        currentLockedPrompt = nil
                        task.wait(0.1) 
                    end
                end
            end)
            task.wait(0.05)
        else
            currentLockedTarget = nil
            currentLockedPrompt = nil
            task.wait(1.0)
        end
    end
end)

task.spawn(function()
    while true do
        local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
        if Configs and Configs.SendMailEnabled == true then
            local processingSuccess = false
            
            pcall(function()
                local targetUser = tostring(Configs.MailTargetUser or ""):gsub("%s+", "")
                local maxQuantity = math.floor(tonumber(Configs.MailSendQuantity) or 1)
                
                if targetUser == "" or targetUser == "username" or targetUser == "@Username" then
                    return
                end
                
                local sharedMod = ReplicatedStorage:FindFirstChild("SharedModules")
                local networkingMod = sharedMod and sharedMod:FindFirstChild("Networking")
                if networkingMod then
                    local netSuccess, network = pcall(require, networkingMod)
                    if netSuccess and network and network.Mailbox and network.Mailbox.LookupPlayer and network.Mailbox.SendBatch then
                        
                        local uidLookup = network.Mailbox.LookupPlayer:Fire(targetUser)
                        if not uidLookup or uidLookup <= 0 then
                            return
                        end
                        
                        local targetItemToProcess = nil
                        local itemsToBatch = {}
                        local currentBatchCount = 0
                        
                        local scanningBlueprint = {}
                        if Configs.MailPetsFilter then for _, v in ipairs(Configs.MailPetsFilter) do table.insert(scanningBlueprint, {ItemKey = v, Category = "Pets"}) end end
                        if Configs.MailFruitsFilter then for _, v in ipairs(Configs.MailFruitsFilter) do table.insert(scanningBlueprint, {ItemKey = v, Category = "HarvestedFruits"}) end end
                        if Configs.MailSeedsFilter then for _, v in ipairs(Configs.MailSeedsFilter) do table.insert(scanningBlueprint, {ItemKey = v, Category = "Seeds"}) end end
                        if Configs.MailSprinklersFilter then for _, v in ipairs(Configs.MailSprinklersFilter) do table.insert(scanningBlueprint, {ItemKey = v, Category = "Sprinklers"}) end end
                        if Configs.MailWateringCansFilter then for _, v in ipairs(Configs.MailWateringCansFilter) do table.insert(scanningBlueprint, {ItemKey = v, Category = "WateringCans"}) end end
                        if Configs.MailCratesFilter then for _, v in ipairs(Configs.MailCratesFilter) do table.insert(scanningBlueprint, {ItemKey = v, Category = "Crates"}) end end
                        if Configs.MailSeedPacksFilter then for _, v in ipairs(Configs.MailSeedPacksFilter) do table.insert(scanningBlueprint, {ItemKey = v, Category = "SeedPacks"}) end end
                        if Configs.MailEggsFilter then for _, v in ipairs(Configs.MailEggsFilter) do table.insert(scanningBlueprint, {ItemKey = v, Category = "Eggs"}) end end
                        if Configs.MailToolsFilter then 
                            for _, v in ipairs(Configs.MailToolsFilter) do 
                                local assignedCategory = "Tools"
                                if v == "Trowel" then assignedCategory = "Trowels"
                                elseif v == "Basic Pot" then assignedCategory = "EmptyPots" end
                                table.insert(scanningBlueprint, {ItemKey = v, Category = assignedCategory}) 
                            end 
                        end
                        for _, giftConfig in pairs(scanningBlueprint) do
                            if Configs.SendMailEnabled ~= true then break end
                            local itemName = giftConfig.ItemKey
                            local serverCategory = giftConfig.Category
                            
                            if serverCategory == "Pets" or serverCategory == "HarvestedFruits" then
                                maxQuantity = math.min(maxQuantity, 20)
                                
                                local targetFolder = LocalPlayer:FindFirstChild("Backpack") 
                                    or LocalPlayer:FindFirstChild(serverCategory)
                                    or LocalPlayer:FindFirstChild("Pets")
                                
                                if targetFolder then
                                    local children = targetFolder:GetChildren()
                                    local cleanNamePattern = itemName:gsub("([^%w])", "%%%1")
                                    
                                    for cIdx = 1, #children do
                                        if currentBatchCount >= maxQuantity then break end
                                        local instanceObj = children[cIdx]
                                        
                                        if string.find(instanceObj.Name, "^" .. cleanNamePattern) then
                                            local isFavorited = instanceObj:GetAttribute("isFavorite") or instanceObj:GetAttribute("IsFavorite") or instanceObj:GetAttribute("favorite") or instanceObj:GetAttribute("Locked")
                                            if isFavorited ~= true then
                                                local extractedUniqueKey = nil
                                                if serverCategory == "Pets" then
                                                    extractedUniqueKey = instanceObj:GetAttribute("PetId")
                                                else
                                                    extractedUniqueKey = instanceObj:GetAttribute("Id") or instanceObj:GetAttribute("UUID")
                                                end
                                                
                                                if extractedUniqueKey then
                                                    local uniqueStrKey = tostring(extractedUniqueKey)
                                                    local alreadyInBatch = false
                                                    for bIdx = 1, #itemsToBatch do
                                                        if itemsToBatch[bIdx].ItemKey == uniqueStrKey then
                                                            alreadyInBatch = true
                                                            break
                                                        end
                                                    end
                                                    
                                                    if not alreadyInBatch then
                                                        targetItemToProcess = {Name = itemName, Category = serverCategory}
                                                        table.insert(itemsToBatch, {
                                                            ["Category"] = serverCategory,
                                                            ["ItemKey"] = uniqueStrKey,
                                                            ["Count"] = 1
                                                        })
                                                        currentBatchCount = currentBatchCount + 1
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            else
                                local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:FindFirstChild(serverCategory .. "Inventory") or LocalPlayer:FindFirstChild(serverCategory)
                                if backpack then
                                    local foundTool = backpack:FindFirstChild(itemName)
                                    if foundTool then
                                        local isToolFavorited = foundTool:GetAttribute("isFavorite") or foundTool:GetAttribute("IsFavorite") or foundTool:GetAttribute("favorite") or foundTool:GetAttribute("Locked")
                                        if isToolFavorited ~= true then
                                            local totalAvailableToPull = 0
                                            local countAttr = foundTool:GetAttribute("Count") or foundTool:GetAttribute("Amount") or foundTool:GetAttribute("Quantity")
                                            if countAttr then
                                                totalAvailableToPull = tonumber(countAttr) or 1
                                            else
                                                totalAvailableToPull = 1
                                            end
                                            
                                            local actualToSendCount = math.min(maxQuantity, totalAvailableToPull)
                                            targetItemToProcess = {Name = itemName, Category = serverCategory}
                                            table.insert(itemsToBatch, {
                                                ["Category"] = serverCategory,
                                                ["ItemKey"] = itemName,
                                                ["Count"] = actualToSendCount
                                            })
                                            currentBatchCount = actualToSendCount
                                        end
                                    end
                                end
                            end
                            if targetItemToProcess and #itemsToBatch > 0 then break end
                        end
                        
                        if not targetItemToProcess or #itemsToBatch == 0 then return end
                        
                        local batchSuccess, responseMsg = network.Mailbox.SendBatch:Fire(uidLookup, itemsToBatch, "")
                        if batchSuccess then
                            processingSuccess = true
                            if _G.PostMailboxTerminalAlert then
                                _G.PostMailboxTerminalAlert("Mailbox", "Sent " .. tostring(currentBatchCount) .. "x " .. tostring(targetItemToProcess and targetItemToProcess.Name or "Items") .. " successfully!", false) 
                            end
                        else
                            if _G.PostMailboxTerminalAlert then _G.PostMailboxTerminalAlert("Mailbox", tostring(responseMsg or "Failed"), true) end
                        end
                    end
                end
            end)
            local sleepDuration = tonumber(Configs.MailSendInterval) or 5
            if processingSuccess then
                task.wait(math.max(sleepDuration, 0.5))
            else
                task.wait(math.max(sleepDuration, 1.0))
            end
        else
            task.wait(1.0)
        end
    end
end)

task.spawn(function()
    while true do
        local Configs = _G.DecodeAPI and _G.DecodeAPI.Configs
        if Configs and Configs.ClaimMailEnabled == true then
            pcall(function()
                local sharedMod = ReplicatedStorage:FindFirstChild("SharedModules")
                local networkingMod = sharedMod and sharedMod:FindFirstChild("Networking")
                if networkingMod then
                    local success, network = pcall(require, networkingMod)
                    if success and network and network.Mailbox and network.Mailbox.OpenInbox and network.Mailbox.Claim then
                        local inboxData = network.Mailbox.OpenInbox:Fire()
                        if inboxData and type(inboxData) == "table" then
                            for mailId, _ in pairs(inboxData) do
                                if Configs.ClaimMailEnabled ~= true then break end
                                network.Mailbox.Claim:Fire(tostring(mailId))
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end)
            task.wait(2.0)
        else
            task.wait(1.0)
        end
    end
end)

print("Decode: Function Loaded.")
