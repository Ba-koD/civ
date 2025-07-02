local ConnectedItemsMod = RegisterMod("Connected Items Visualizer", 1)
local game = Game()
local json = require("json")

local function CIVPrintAlways(message)
    Isaac.ConsoleOutput(tostring(message or "nil") .. "\n")
end

local function CIVPrint(message)
    local success, err = pcall(function()
        local shouldShow = false
        if CIV and CIV.Config and CIV.Config["showConsole"] ~= nil then
            shouldShow = CIV.Config["showConsole"]
        end
        
        if shouldShow then
            Isaac.ConsoleOutput("CIV: " .. tostring(message or "nil") .. "\n")
        end
    end)
    
    if not success then
        Isaac.ConsoleOutput("ERROR in CIVPrint: " .. tostring(err) .. "\n")
        Isaac.ConsoleOutput("FALLBACK: CIV: " .. tostring(message or "nil") .. "\n")
    end
end

local CIVUserConfig = {
    ["enabled"] = true,       -- mod enabled
    ["showDebug"] = false,    -- debug info display
    ["showConsole"] = false,  -- console output display
    ["numberOffsetY"] = -17,   -- number overlay Y offset (-50 to 50)
    ["numberOffsetX"] = 10,   -- number overlay X offset (-50 to 50)
}

local CIV = ConnectedItemsMod

CIV.Config = CIVUserConfig
CIV.Config.Version = "2.1"

CIVPrintAlways("CIV: Connected Items Visualizer v" .. CIV.Config.Version .. " initializing...")

CIV.DefaultConfig = {}
for key, value in pairs(CIV.Config) do
    CIV.DefaultConfig[key] = value
end
CIV.DefaultConfig.Version = CIV.Config.Version

local CIVMCMLoaded, MCM = pcall(require, "scripts.modconfig")

CIV.SaveData = Isaac.SaveModData

function CIV:HasData()
    return Isaac.HasModData(self)
end

CIVPrint("=== CIV INIT DEBUG ===")
CIVPrint("ConnectedItemsMod: " .. tostring(ConnectedItemsMod))
CIVPrint("CIVUserConfig created: " .. tostring(CIVUserConfig))
CIVPrint("CIV assigned: " .. tostring(CIV))
CIVPrint("CIV.Config assigned: " .. tostring(CIV.Config))
CIVPrint("CIV.Config.enabled: " .. tostring(CIV.Config.enabled))
CIVPrint("CIV.Config.showConsole: " .. tostring(CIV.Config.showConsole))
CIVPrint("CIV.Config.Version: " .. tostring(CIV.Config.Version))
CIVPrint("=====================")

local function GetDimension(room)
    local success, result = pcall(function()
        local level = Game():GetLevel()
        if not level then return nil end
        
        local roomIndex = room or level:GetCurrentRoomIndex()
        if not roomIndex then return nil end
        
        for i = 0, 2 do
            local roomByIdx = level:GetRoomByIdx(roomIndex, i)
            local currentRoom = level:GetRoomByIdx(roomIndex, -1)
            if roomByIdx and currentRoom and GetPtrHash(roomByIdx) == GetPtrHash(currentRoom) then
                return i
            end
        end
        
        return nil
    end)
    
    if success then
        return result
    else
        return nil
    end
end

local function IsDeathCertificateFloor()
    local dimension = GetDimension()
    return dimension == 2
end

-- 숫자 표시용 간단한 색상 배열
local NUMBER_COLORS = {
    Color(1.0, 0.3, 0.3, 1.0),   -- red
    Color(0.3, 1.0, 0.3, 1.0),   -- green
    Color(0.3, 0.3, 1.0, 1.0),   -- blue
    Color(1.0, 1.0, 0.3, 1.0),   -- yellow
    Color(1.0, 0.3, 1.0, 1.0),   -- magenta
    Color(0.3, 1.0, 1.0, 1.0),   -- cyan
    Color(1.0, 0.5, 0.0, 1.0),   -- orange
    Color(0.5, 0.0, 1.0, 1.0),   -- purple
    Color(0.0, 1.0, 0.5, 1.0),   -- teal
    Color(1.0, 0.0, 0.5, 1.0),   -- pink
}

local connectedItemsInRoom = {}
local lastEntityCount = 0
local renderCallCount = 0

local persistentConnections = {}
local roomConnectedItems = {}

-- 그룹 번호 매핑 시스템
local groupNumberMapping = {}  -- OptionsPickupIndex -> 표시번호 매핑
local nextDisplayNumber = 1    -- 다음에 할당할 표시번호
local roomKey = ""             -- 현재 방 키

-- function to inspect all properties of a pickup entity
function ConnectedItemsMod:InspectPickupEntity(pickup)
    CIVPrint("=== PICKUP ENTITY INSPECTION ===")
    CIVPrint("SubType (Item ID): " .. tostring(pickup.SubType))
    CIVPrint("Index: " .. tostring(pickup.Index))
    CIVPrint("InitSeed: " .. tostring(pickup.InitSeed))
    CIVPrint("DropSeed: " .. tostring(pickup.DropSeed))
    CIVPrint("Price: " .. tostring(pickup.Price))
    CIVPrint("AutoUpdateDiff: " .. tostring(pickup.AutoUpdateDiff))
    CIVPrint("Charge: " .. tostring(pickup.Charge))
    CIVPrint("State: " .. tostring(pickup.State))
    CIVPrint("Timeout: " .. tostring(pickup.Timeout))
    CIVPrint("Touched: " .. tostring(pickup.Touched))
    CIVPrint("Wait: " .. tostring(pickup.Wait))
    CIVPrint("OptionsPickupIndex: " .. tostring(pickup.OptionsPickupIndex))
    CIVPrint("Position: " .. tostring(pickup.Position))
    
    -- check special properties of EntityPickup
    if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
        CIVPrint("*** FOUND OPTIONS PICKUP INDEX: " .. pickup.OptionsPickupIndex .. " ***")
    end
    
    -- try additional properties
    local success, result = pcall(function() return pickup.ShopItemId end)
    if success then CIVPrint("ShopItemId: " .. tostring(result)) end
    
    success, result = pcall(function() return pickup.TheresOptionsPickup end)
    if success then CIVPrint("TheresOptionsPickup: " .. tostring(result)) end
    
    CIVPrint("================================")
end

-- function to find connected items by OptionsPickupIndex
function ConnectedItemsMod:FindConnectedItems()
    local entities = Isaac.GetRoomEntities()
    local optionsGroups = {}
    
    -- group by OptionsPickupIndex
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup and pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
                local index = pickup.OptionsPickupIndex
                if not optionsGroups[index] then
                    optionsGroups[index] = {}
                end
                table.insert(optionsGroups[index], {
                    entity = pickup,
                    position = pickup.Position,
                    itemId = pickup.SubType
                })
            end
        end
    end
    
    return optionsGroups
end

-- function to update connected items
function ConnectedItemsMod:UpdateConnectedItems()
    connectedItemsInRoom = {}
    
    local optionsGroups = self:FindConnectedItems()
    local groupCount = 0
    
    if not optionsGroups then
        self:RestorePersistentConnections()
        return self:CountConnectedGroups()
    end
    
    -- 현재 방 키 업데이트
    local currentRoomKey = tostring(Game():GetLevel():GetCurrentRoomIndex())
    if roomKey ~= currentRoomKey then
        -- 새로운 방에 들어갔으면 매핑 초기화
        roomKey = currentRoomKey
        groupNumberMapping = {}
        nextDisplayNumber = 1
    end
    
    for index, items in pairs(optionsGroups) do
        if items and #items >= 2 then
            local colorIndex = ((index - 1) % #NUMBER_COLORS) + 1
            local groupColor = NUMBER_COLORS[colorIndex]
            
            -- 그룹 번호 매핑 (새로운 그룹이면 새 번호 할당)
            if not groupNumberMapping[index] then
                groupNumberMapping[index] = nextDisplayNumber
                nextDisplayNumber = nextDisplayNumber + 1
            end
            local displayNumber = groupNumberMapping[index]
            
            connectedItemsInRoom["options_" .. index] = {
                items = items,
                color = groupColor,
                colorIndex = colorIndex,
                groupNumber = displayNumber,  -- 매핑된 번호 사용
                originalIndex = index,        -- 원본 인덱스 보관
                name = "Connected Items (Index: " .. index .. ")"
            }
            groupCount = groupCount + 1
            
            self:AddToPersistentConnections(index, items, colorIndex, displayNumber)
        end
    end
    
    self:RestorePersistentConnections()
    
    return self:CountConnectedGroups()
end

-- function to add items to persistent connections
function ConnectedItemsMod:AddToPersistentConnections(index, items, colorIndex, displayNumber)
    local roomKey = tostring(Game():GetLevel():GetCurrentRoomIndex())
    
    if not persistentConnections[roomKey] then
        persistentConnections[roomKey] = {}
    end
    
    for _, item in ipairs(items) do
        if item.entity and item.entity:Exists() then
            local itemKey = tostring(item.itemId) .. "_" .. tostring(item.entity.InitSeed)
            persistentConnections[roomKey][itemKey] = {
                itemId = item.itemId,
                position = item.position,
                colorIndex = colorIndex,
                optionsIndex = index,
                displayNumber = displayNumber  -- 표시번호도 저장
            }
            
            roomConnectedItems[itemKey] = {
                entity = item.entity,
                itemId = item.itemId,
                position = item.position,
                colorIndex = colorIndex,
                optionsIndex = index,
                displayNumber = displayNumber  -- 표시번호도 저장
            }
        end
    end
end

-- function to restore persistent connections
function ConnectedItemsMod:RestorePersistentConnections()
    local roomKey = tostring(Game():GetLevel():GetCurrentRoomIndex())
    local roomPersistent = persistentConnections[roomKey]
    
    if not roomPersistent then return end
    
    -- 현재 방의 모든 아이템 확인
    local entities = Isaac.GetRoomEntities()
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup then
                local itemKey = tostring(pickup.SubType) .. "_" .. tostring(pickup.InitSeed)
                local persistentData = roomPersistent[itemKey]
                
                if persistentData then
                    local groupKey = "persistent_" .. persistentData.optionsIndex
                    
                    if not connectedItemsInRoom[groupKey] then
                        connectedItemsInRoom[groupKey] = {
                            items = {},
                            color = NUMBER_COLORS[persistentData.colorIndex],
                            colorIndex = persistentData.colorIndex,
                            groupNumber = persistentData.displayNumber,  -- 저장된 표시번호 사용
                            originalIndex = persistentData.optionsIndex,
                            name = "Persistent Connected Items (Index: " .. persistentData.optionsIndex .. ")"
                        }
                    end
                    
                    table.insert(connectedItemsInRoom[groupKey].items, {
                        entity = pickup,
                        position = pickup.Position,
                        itemId = pickup.SubType
                    })
                    
                    roomConnectedItems[itemKey] = {
                        entity = pickup,
                        itemId = pickup.SubType,
                        position = pickup.Position,
                        colorIndex = persistentData.colorIndex,
                        optionsIndex = persistentData.optionsIndex,
                        displayNumber = persistentData.displayNumber  -- 저장된 표시번호 사용
                    }
                end
            end
        end
    end
end

-- function to count connected groups
function ConnectedItemsMod:CountConnectedGroups()
    local count = 0
    for _, _ in pairs(connectedItemsInRoom) do
        count = count + 1
    end
    return count
end

-- function to find connected items when entering a room
function ConnectedItemsMod:OnNewRoom()
    if IsDeathCertificateFloor() then
        if CIV.Config["showDebug"] and CIV.Config["showConsole"] then
            CIVPrint("Death Certificate floor detected - mod disabled")
        end
        return
    end
    
    connectedItemsInRoom = {}
    roomConnectedItems = {}
    
    -- 방 변경 시 그룹 번호 매핑 초기화
    groupNumberMapping = {}
    nextDisplayNumber = 1
    roomKey = tostring(Game():GetLevel():GetCurrentRoomIndex())
    
    local groupCount = self:UpdateConnectedItems()
    
    lastEntityCount = #Isaac.GetRoomEntities()
    renderCallCount = 0
end

-- function to detect item additions/removals in real-time
function ConnectedItemsMod:CheckForItemChanges()
    local success = pcall(function()
        local entities = Isaac.GetRoomEntities()
        local currentEntityCount = #entities
        
        if currentEntityCount ~= lastEntityCount then
            if CIV.Config["showDebug"] then
                if CIV.Config["showConsole"] then
                    CIVPrint("Entity count changed: " .. tostring(lastEntityCount) .. " -> " .. tostring(currentEntityCount))
                end
            end
            
            local oldConnectedItems = connectedItemsInRoom
            
            self:UpdateConnectedItems()
            
            local connectionsChanged = self:CompareConnectedItems(oldConnectedItems, connectedItemsInRoom)
            
            if connectionsChanged then
                if CIV.Config["showDebug"] and CIV.Config["showConsole"] then
                    CIVPrint("Connection layout changed - updating display")
                end
            end
            
            lastEntityCount = currentEntityCount
        end
    end)
    
    if not success then
        if CIV.Config["showDebug"] and CIV.Config["showConsole"] then
            CIVPrint("Error in CheckForItemChanges - using safe fallback")
        end
    end
end

-- function to check for new connections
function ConnectedItemsMod:CheckForNewConnections()
    local success = pcall(function()
        local oldConnectedItems = connectedItemsInRoom
        
        self:UpdateConnectedItems()
        
        local connectionsChanged = self:CompareConnectedItems(oldConnectedItems, connectedItemsInRoom)
        
        if connectionsChanged then
            if CIV.Config["showDebug"] and CIV.Config["showConsole"] then
                CIVPrint("New connections detected - updating display")
            end
        end
    end)
    
    if not success and CIV.Config["showDebug"] and CIV.Config["showConsole"] then
        CIVPrint("Error in CheckForNewConnections")
    end
end

-- function to compare connected items configuration
function ConnectedItemsMod:CompareConnectedItems(oldItems, newItems)
    local success, result = pcall(function()
        if not oldItems or not newItems then
            return true
        end
        
        local oldCount = 0
        local newCount = 0
        
        for _ in pairs(oldItems) do oldCount = oldCount + 1 end
        for _ in pairs(newItems) do newCount = newCount + 1 end
        
        if oldCount ~= newCount then
            return true
        end
        
        for groupKey, newData in pairs(newItems) do
            local oldData = oldItems[groupKey]
            if not oldData or not oldData.items or not newData.items then
                return true
            end
            if #oldData.items ~= #newData.items then
                return true
            end
        end
        
        return false
    end)
    
    if not success then
        return true
    end
    
    return result
end

-- function to get all connected items
function ConnectedItemsMod:GetAllConnectedItems()
    local allConnectedItems = {}
    
    local entities = Isaac.GetRoomEntities()
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup then
                local itemKey = tostring(pickup.SubType) .. "_" .. tostring(pickup.InitSeed)
                local colorIndex = nil
                local groupId = nil
                local groupNumber = nil
                
                if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
                    colorIndex = ((pickup.OptionsPickupIndex - 1) % #NUMBER_COLORS) + 1
                    groupId = "current_" .. pickup.OptionsPickupIndex
                    -- 매핑된 번호 사용
                    groupNumber = groupNumberMapping[pickup.OptionsPickupIndex] or pickup.OptionsPickupIndex
                elseif roomConnectedItems[itemKey] then
                    colorIndex = roomConnectedItems[itemKey].colorIndex
                    groupId = "persistent_" .. roomConnectedItems[itemKey].optionsIndex
                    groupNumber = roomConnectedItems[itemKey].displayNumber  -- 저장된 표시번호 사용
                end
                
                if colorIndex and groupId and groupNumber then
                    if not allConnectedItems[groupId] then
                        allConnectedItems[groupId] = {
                            items = {},
                            color = NUMBER_COLORS[colorIndex],
                            colorIndex = colorIndex,
                            groupNumber = groupNumber,  -- 매핑된 번호 사용
                            name = "Connected Items (" .. groupId .. ")"
                        }
                    end
                    
                    table.insert(allConnectedItems[groupId].items, {
                        entity = pickup,
                        position = pickup.Position,
                        itemId = pickup.SubType
                    })
                end
            end
        end
    end
    return allConnectedItems
end

-- function to render connected items
function ConnectedItemsMod:OnRender()
    local success = pcall(function()
        local currentFrame = Game():GetFrameCount()
        if currentFrame % 7200 == 0 then
            self:SaveSettings()
        end
    end)
    
    if not CIV.Config then 
        if CIV.Config and CIV.Config["showDebug"] then
            Isaac.RenderText("CIV: CIV.Config is nil", 10, 10, 255, 0, 0, 255)
        end
        return 
    end
    
    if not CIV.Config["enabled"] then 
        if CIV.Config["showDebug"] then
            Isaac.RenderText("CIV: Mod disabled", 10, 10, 255, 100, 100, 255)
        end
        return 
    end
    
    if CIV.Config["showDebug"] then
        Isaac.RenderText("CIV: Enabled=" .. tostring(CIV.Config["enabled"]), 10, 25, 255, 255, 255, 255)
        Isaac.RenderText("CIV: Default_Enabled=" .. tostring(CIV.DefaultConfig["enabled"]), 10, 40, 255, 255, 255, 255)
        Isaac.RenderText("CIV: MCM=" .. tostring(ModConfigMenu and ModConfigMenu.IsVisible), 10, 55, 255, 255, 255, 255)
        Isaac.RenderText("CIV: Paused=" .. tostring(Game():IsPaused()), 10, 70, 255, 255, 255, 255)
        Isaac.RenderText("CIV: HUD=" .. tostring(Game():GetHUD():IsVisible()), 10, 85, 255, 255, 255, 255)
        
        local yPos = 100
        Isaac.RenderText("=== All Config Values ===", 10, yPos, 255, 255, 0, 255)
        yPos = yPos + 15
        for key, value in pairs(CIV.Config) do
            Isaac.RenderText(key .. " = " .. tostring(value), 10, yPos, 200, 200, 200, 255)
            yPos = yPos + 12
            if yPos > 400 then break end
        end
    end
    
    if (ModConfigMenu and ModConfigMenu.IsVisible) or Game():IsPaused() then
        return
    end
    
    if not Game():GetHUD():IsVisible() then
        return
    end
    
    local deathCertSafe, isDeathCert = pcall(function() return IsDeathCertificateFloor() end)
    if deathCertSafe and isDeathCert then
        return
    end
    
    renderCallCount = renderCallCount + 1
    
    if CIV.Config["showDebug"] then
        Isaac.RenderText("Connected Items Mod Active", 10, 85, 255, 255, 255, 255)
        Isaac.RenderText("Render Count: " .. renderCallCount, 10, 100, 255, 255, 255, 255)
        Isaac.RenderText("Mode: NUMBER_OVERLAY", 10, 115, 255, 255, 100, 255)
        Isaac.RenderText("Frame: " .. Game():GetFrameCount() % 100, 10, 130, 100, 100, 255, 255)
    end
    
    local allConnectedItems = nil
    local getAllSuccess = pcall(function()
        allConnectedItems = self:GetAllConnectedItems()
    end)
    
    if not getAllSuccess or not allConnectedItems then 
        if CIV.Config["showDebug"] then
            Isaac.RenderText("allConnectedItems failed", 10, 260, 255, 100, 100, 255)
        end
        return 
    end
    
    local groupCount = 0
    for _, _ in pairs(allConnectedItems) do
        groupCount = groupCount + 1
    end
    
    if CIV.Config["showDebug"] then
        Isaac.RenderText("Groups: " .. groupCount, 10, 275, 255, 255, 255, 255)
    end
    
    if groupCount == 0 then
        if CIV.Config["showDebug"] then
            Isaac.RenderText("No connected groups", 10, 290, 255, 200, 100, 255)
        end
        return
    end
    
    local sortedGroups = {}
    for groupKey, data in pairs(allConnectedItems) do
        if data and data.items and data.color and #data.items >= 2 then
            table.insert(sortedGroups, {key = groupKey, data = data})
        end
    end
    
    table.sort(sortedGroups, function(a, b) return a.key < b.key end)
    
    local groupsRendered = 0
    
    if CIV.Config["showDebug"] then
        Isaac.RenderText("Sorted groups: " .. #sortedGroups, 10, 305, 255, 255, 255, 255)
    end
    
    local success, err = pcall(function()
        for i, groupInfo in ipairs(sortedGroups) do
            local groupKey = groupInfo.key
            local data = groupInfo.data
            local items = data.items
            local color = data.color
            local groupNumber = data.groupNumber
            
            groupsRendered = groupsRendered + 1
            
            if CIV.Config["showDebug"] then
                Isaac.RenderText("Group " .. groupsRendered .. ": " .. #items .. " items (" .. groupKey .. ")", 10, 320 + (groupsRendered * 15), 
                               color.R * 255, color.G * 255, color.B * 255, 255)
            end
            
            -- 숫자 오버레이 렌더링
            if CIV.Config["showDebug"] then
                Isaac.RenderText("Rendering numbers for group " .. groupsRendered, 10, 415, 255, 255, 0, 255)
                Isaac.RenderText("Items in group: " .. #items, 10, 430, 255, 255, 0, 255)
            end
            self:RenderNumberOverlay(items, color, groupNumber)
        end
    end)
    
    if not success then
        if CIV.Config["showDebug"] then
            Isaac.RenderText("Render Error: " .. tostring(err), 10, 445, 255, 0, 0, 255)
        end
    end
    
    if CIV.Config["showDebug"] then
        Isaac.RenderText("Groups rendered: " .. groupsRendered, 10, 475, 100, 255, 100, 255)
    end
end

-- function to render number overlay
function ConnectedItemsMod:RenderNumberOverlay(items, color, groupNumber)
    if not items or not color or not groupNumber then
        if CIV.Config and CIV.Config["showDebug"] then
            Isaac.RenderText("RenderNumberOverlay: Invalid params", 10, 320, 255, 0, 0, 255)
        end
        return
    end
    
    -- Number offset 사용
    local offsetX = (CIV.Config["numberOffsetX"] or CIV.DefaultConfig["numberOffsetX"]) or 10
    local offsetY = (CIV.Config["numberOffsetY"] or CIV.DefaultConfig["numberOffsetY"]) or -17
    
    if CIV.Config and CIV.Config["showDebug"] then
        Isaac.RenderText("Rendering " .. #items .. " numbers, offset: " .. offsetX .. "," .. offsetY, 10, 330, 255, 255, 0, 255)
    end
    
    -- 숫자 렌더링
    for i, item in ipairs(items) do
        if item and item.entity and item.entity:Exists() then
            local success, err = pcall(function()
                local screenPos = Isaac.WorldToScreen(item.entity.Position)
                local numberText = tostring(groupNumber)
                
                local finalOffsetX = offsetX - (#numberText - 1) * 2
                local finalOffsetY = offsetY

                -- 숫자 테두리 (검은색)
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            Isaac.RenderText(numberText, 
                                           screenPos.X + finalOffsetX + dx, 
                                           screenPos.Y + finalOffsetY + dy,
                                           0, 0, 0, 150)
                        end
                    end
                end
                
                -- 메인 숫자 텍스트
                Isaac.RenderText(numberText, 
                               screenPos.X + finalOffsetX, 
                               screenPos.Y + finalOffsetY,
                               color.R * 255, color.G * 255, color.B * 255, 255)
                
                if CIV.Config and CIV.Config["showDebug"] then
                    Isaac.RenderText("NUM " .. numberText, screenPos.X + 30, screenPos.Y - 20, 0, 255, 0, 255)
                    Isaac.RenderText("Pos: " .. math.floor(screenPos.X) .. "," .. math.floor(screenPos.Y), screenPos.X + 30, screenPos.Y - 5, 0, 255, 0, 255)
                end
            end)
            
            if not success and CIV.Config and CIV.Config["showDebug"] then
                Isaac.RenderText("Number render error for item " .. i .. ": " .. tostring(err), 10, 340 + i*10, 255, 0, 0, 255)
            end
        elseif CIV.Config and CIV.Config["showDebug"] then
            Isaac.RenderText("Invalid item " .. i, 10, 360 + i*10, 255, 100, 0, 255)
        end
    end
    
    if CIV.Config and CIV.Config["showDebug"] then
        Isaac.RenderText("RenderNumberOverlay completed for group " .. groupNumber, 10, 350, 0, 255, 0, 255)
    end
end

-- function to update
function ConnectedItemsMod:OnUpdate()
    if not CIV.Config then return end
    if not CIV.Config["enabled"] then return end
    
    local deathCertSafe = pcall(function() return IsDeathCertificateFloor() end)
    if deathCertSafe and IsDeathCertificateFloor() then
        return
    end
    
    local success, err = pcall(function()
        local game = Game()
        if not game then return end
        
        local currentFrame = game:GetFrameCount()
        if not currentFrame then return end
        
        if currentFrame % 15 == 0 then
            if ConnectedItemsMod.CheckForItemChanges then
                ConnectedItemsMod:CheckForItemChanges()
            end
        end
        
        if currentFrame % 10 == 0 then
            if ConnectedItemsMod.CheckForNewConnections then
                ConnectedItemsMod:CheckForNewConnections()
            end
        end
    end)
    
    if not success then
        CIVPrint("OnUpdate error (safe handling)")
    end
end

-- function to reset settings to default values
function ConnectedItemsMod:ResetToDefaults()
    for key, value in pairs(CIV.DefaultConfig) do
        CIV.Config[key] = value
    end
    
    CIV.SaveData(CIV, json.encode(CIV.Config))
    
    CIVPrint("All settings reset to defaults")
end

-- Mod Config Menu settings
if ModConfigMenu then
    local CIVCategory = "CIV"
    ModConfigMenu.UpdateCategory(CIVCategory, {
        Info = {"CIV - Connected Items Visualizer"}
    })

    -- === General 서브카테고리 ===
    ModConfigMenu.AddText(CIVCategory, "General", function() return "General Settings" end)
    ModConfigMenu.AddSpace(CIVCategory, "General")

    -- On/Off 설정
    ModConfigMenu.AddSetting(CIVCategory, "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            local enabled = CIV.Config["enabled"]
            if enabled == nil then
                enabled = CIV.DefaultConfig["enabled"]
            end
            return enabled == true
        end,
        Display = function()
            local enabled = CIV.Config["enabled"]
            if enabled == nil then
                enabled = CIV.DefaultConfig["enabled"]
            end
            local isEnabled = enabled == true
            return 'Mod Status: ' .. (isEnabled and "On" or "Off")
        end,
        OnChange = function(currentBool)
            CIV.Config["enabled"] = currentBool
            CIV.SaveData(CIV, json.encode(CIV.Config))
        end,
        Info = {"Enable or disable the mod."}
    })

    -- Reset Config 버튼
    ModConfigMenu.AddSpace(CIVCategory, "General")
    ModConfigMenu.AddSetting(CIVCategory, "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return false
        end,
        Display = function()
            return "Reset Config"
        end,
        OnChange = function(currentBool)
            if currentBool then
                ConnectedItemsMod:ResetToDefaults()
            end
        end,
        Info = {"Reset all settings to default values."}
    })

    -- === Numbers 서브카테고리 ===
    ModConfigMenu.AddText(CIVCategory, "Numbers", function() return "Number Display Settings" end)
    ModConfigMenu.AddSpace(CIVCategory, "Numbers")

    -- Number Offset Y 설정
    ModConfigMenu.AddSetting(CIVCategory, "Numbers", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
            return CIV.Config["numberOffsetY"] or CIV.DefaultConfig["numberOffsetY"]
        end,
        Minimum = -50,
        Maximum = 50,
        Display = function()
            local offsetY = CIV.Config["numberOffsetY"] or CIV.DefaultConfig["numberOffsetY"]
            return "Number Y Offset: " .. offsetY
        end,
        OnChange = function(currentNum)
            CIV.Config["numberOffsetY"] = currentNum
            CIV.SaveData(CIV, json.encode(CIV.Config))
        end,
        Info = {"Adjust vertical position of number overlay.", "Negative = up, Positive = down"}
    })

    -- Number Offset X 설정
    ModConfigMenu.AddSetting(CIVCategory, "Numbers", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
            return CIV.Config["numberOffsetX"] or CIV.DefaultConfig["numberOffsetX"]
        end,
        Minimum = -50,
        Maximum = 50,
        Display = function()
            local offsetX = CIV.Config["numberOffsetX"] or CIV.DefaultConfig["numberOffsetX"]
            return "Number X Offset: " .. offsetX
        end,
        OnChange = function(currentNum)
            CIV.Config["numberOffsetX"] = currentNum
            CIV.SaveData(CIV, json.encode(CIV.Config))
        end,
        Info = {"Adjust horizontal position of number overlay.", "Negative = left, Positive = right"}
    })

    -- === Color 서브카테고리 (빈 화면) ===
    ModConfigMenu.AddText(CIVCategory, "Color", function() return "Color Effect Settings" end)
    ModConfigMenu.AddSpace(CIVCategory, "Color")
    ModConfigMenu.AddText(CIVCategory, "Color", function() 
        return "Coming Soon..."
    end)

    -- === Pedestal 서브카테고리 (빈 화면) ===
    ModConfigMenu.AddText(CIVCategory, "Pedestal", function() return "Pedestal Color Settings" end)
    ModConfigMenu.AddSpace(CIVCategory, "Pedestal")
    ModConfigMenu.AddText(CIVCategory, "Pedestal", function() 
        return "Coming Soon..."
    end)

    -- === Debug 서브카테고리 ===
    ModConfigMenu.AddText(CIVCategory, "Debug", function() return "Debug & Developer Settings" end)
    ModConfigMenu.AddSpace(CIVCategory, "Debug")

    -- Debug Info 표시
    ModConfigMenu.AddSetting(CIVCategory, "Debug", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return CIV.Config["showDebug"] or CIV.DefaultConfig["showDebug"]
        end,
        Display = function()
            local showDebug = CIV.Config["showDebug"] or CIV.DefaultConfig["showDebug"]
            local onOff = showDebug and "Show" or "Hide"
            return 'Debug Info: ' .. onOff
        end,
        OnChange = function(currentBool)
            CIV.Config["showDebug"] = currentBool
            CIV.SaveData(CIV, json.encode(CIV.Config))
        end,
        Info = {"Show debug information on screen."}
    })

    -- Console Output 표시
    ModConfigMenu.AddSetting(CIVCategory, "Debug", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return CIV.Config["showConsole"] or CIV.DefaultConfig["showConsole"]
        end,
        Display = function()
            local showConsole = CIV.Config["showConsole"] or CIV.DefaultConfig["showConsole"]
            local onOff = showConsole and "Show" or "Hide"
            return 'Console Output: ' .. onOff
        end,
        OnChange = function(currentBool)
            CIV.Config["showConsole"] = currentBool
            CIV.SaveData(CIV, json.encode(CIV.Config))
        end,
        Info = {"Show console output messages."}
    })
end

-- save/load system
local SaveState = {}

function CIV:OnGameStart(isSave)
    --Loading Moddata--
    if CIV:HasData() then
        local savedCIVConfig = json.decode(Isaac.LoadModData(CIV))
        
        if savedCIVConfig.Version == CIV.Config.Version then
            local isDefaultConfig = true
            for key, value in pairs(CIV.Config) do
                if type(value) ~= type(CIV.DefaultConfig[key]) then
                    CIVPrint("Warning: Config value '"..key.."' has wrong data-type. Resetting it to default...")
                    CIV.Config[key] = CIV.DefaultConfig[key]
                end
                if CIV.DefaultConfig[key] ~= value then
                    isDefaultConfig = false
                end
            end
            
            if isDefaultConfig or CIVMCMLoaded then
                for key, value in pairs(CIV.Config) do
                    if savedCIVConfig[key] ~= nil and type(value) == type(savedCIVConfig[key]) then
                        CIV.Config[key] = savedCIVConfig[key]
                    end
                end
            end
        end
    end
end

function CIV:OnGameExit()
    CIV.SaveData(CIV, json.encode(CIV.Config))
end

CIVPrint("")
CIVPrint("=== REGISTERING CALLBACKS ===")
CIVPrint("Starting callback registration")

local success, err

success, err = pcall(function()
    CIV:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, ConnectedItemsMod.OnNewRoom)
end)
if success then
    CIVPrint("MC_POST_NEW_ROOM registered")
else
    CIVPrint("ERROR: MC_POST_NEW_ROOM failed - " .. tostring(err))
end

success, err = pcall(function()
    CIV:AddCallback(ModCallbacks.MC_POST_RENDER, ConnectedItemsMod.OnRender)
end)
if success then
    CIVPrint("MC_POST_RENDER registered")
else
    CIVPrint("ERROR: MC_POST_RENDER failed - " .. tostring(err))
end

success, err = pcall(function()
    CIV:AddCallback(ModCallbacks.MC_POST_UPDATE, ConnectedItemsMod.OnUpdate)
end)
if success then
    CIV:AddCallback(ModCallbacks.MC_POST_UPDATE, ConnectedItemsMod.OnUpdate)
    CIVPrint("MC_POST_UPDATE registered")
else
    CIVPrint("ERROR: MC_POST_UPDATE failed - " .. tostring(err))
end

success, err = pcall(function()
    CIV:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, CIV.OnGameExit)
end)
if success then
    CIVPrint("MC_PRE_GAME_EXIT registered")
else
    CIVPrint("ERROR: MC_PRE_GAME_EXIT failed - " .. tostring(err))
end

success, err = pcall(function()
    CIV:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, CIV.OnGameStart)
end)
if success then
    CIVPrint("MC_POST_GAME_STARTED registered")
else
    CIVPrint("ERROR: MC_POST_GAME_STARTED failed - " .. tostring(err))
end

CIVPrint("=== CALLBACKS REGISTRATION COMPLETE ===")

-- 게임 시작 시 저장 상태 확인
CIVPrint("=== CIV Load Status ===")
CIVPrint("Has Saved Data: " .. tostring(CIV:HasData()))
CIVPrint("Current Enabled: " .. tostring(CIV.Config["enabled"]))

if CIV:HasData() then
    local success, savedData = pcall(function()
        return json.decode(Isaac.LoadModData(CIV))
    end)
    if success and savedData then
        CIVPrint("--- Saved Data Found ---")
        CIVPrint("Saved Data Found - Enabled: " .. tostring(savedData["enabled"]))
    else
        CIVPrint("ERROR: Could not read saved data!")
    end
end

CIVPrint("No saved data found")
CIVPrint("======================")