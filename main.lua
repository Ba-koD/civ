local ConnectedItemsMod = RegisterMod("Connected Items Visualizer", 1)
local game = Game()

-- mod config
local ConnectedItemsConfig = {
    ["displayMode"] = 1,      -- 1-3: display mode (number/color/pedestal color) - default to color
    ["enabled"] = true,       -- mod enabled
    ["showDebug"] = false,    -- debug info display
    ["colorIntensity"] = 2,   -- color intensity (1-5) - default to 1
    ["showConsole"] = false,  -- console output display - default to false
    ["numberOffsetY"] = -4,   -- number overlay Y offset (-50 to 50) - default to -3
    ["numberOffsetX"] = -3,   -- number overlay X offset (-50 to 50) - default to -4
}

-- color palette
local COLOR_PALETTE = {
    Color(1.0, 0.3, 0.3, 0.8),   -- red
    Color(0.3, 1.0, 0.3, 0.8),   -- green
    Color(0.3, 0.3, 1.0, 0.8),   -- blue
    Color(1.0, 1.0, 0.3, 0.8),   -- yellow
    Color(1.0, 0.3, 1.0, 0.8),   -- magenta
    Color(0.3, 1.0, 1.0, 0.8),   -- cyan
    Color(1.0, 0.5, 0.0, 0.8),   -- orange
    Color(0.5, 0.0, 1.0, 0.8),   -- purple
    Color(0.0, 1.0, 0.5, 0.8),   -- teal
    Color(1.0, 0.0, 0.5, 0.8),   -- pink
}

-- display mode options
local DISPLAY_MODES = {
    "NUMBER_OVERLAY", -- 1. number display
    "COLOR_AREA",     -- 2. color effect (아이템 자체)
    "PEDESTAL_COLOR", -- 3. pedestal color effect
}

-- track connected items groups
local connectedItemsInRoom = {}
local lastEntityCount = 0 -- for detecting entity count changes
local renderCallCount = 0 -- for checking render calls

-- 영구 연결 추적 시스템
local persistentConnections = {} -- 이전에 연결되었던 아이템들을 영구 추적
local roomConnectedItems = {} -- 현재 방의 모든 연결 기록

-- track colored entities (to avoid duplicate application)
local coloredEntities = {}

-- 색깔 검증을 위한 추가 변수
local colorValidationCache = {}
local lastColorCheckFrame = 0

-- pedestal 효과를 위한 추가 변수
local pedestalEffects = {}

-- 로그 버퍼
local CIVLogBuffer = {}

-- 이미 색상이 교체된 받침대를 추적하기 위한 캐시
pedestalColored = {}

local PEDESTAL_SPRITES = {
    [1] = "gfx/items/slots/pedestal_red.png",
    [2] = "gfx/items/slots/pedestal_green.png",
    [3] = "gfx/items/slots/pedestal_blue.png",
    [4] = "gfx/items/slots/pedestal_yellow.png",
    [5] = "gfx/items/slots/pedestal_magenta.png",
    [6] = "gfx/items/slots/pedestal_cyan.png",
    [7] = "gfx/items/slots/pedestal_orange.png",
    [8] = "gfx/items/slots/pedestal_purple.png",
    [9] = "gfx/items/slots/pedestal_teal.png",
    [10] = "gfx/items/slots/pedestal_pink.png",
}

-- track global pedestal replacements
local globalPedestalReplacements = {}
-- 엔진 레벨 스프라이트 가로채기
local engineSpriteOverrides = {}
local originalSpriteLoad = nil

local function CIVLog(str)
    Isaac.ConsoleOutput("CIV: " .. tostring(str) .. "\n")
    table.insert(CIVLogBuffer, str)
    if #CIVLogBuffer > 10 then table.remove(CIVLogBuffer, 1) end -- 최근 10줄 유지
end

-- helper to safely tint sprite
local function TintSprite(spr, col)
    if spr.SetColor then      -- Repentance 이상
        spr:SetColor(col)
    else                      -- Afterbirth+ 등
        spr.Color = col
    end
end

-- deprecated glow functions (kept as stubs)
function ConnectedItemsMod:RemoveGlowFromPickup() end

-- function to assign color to each OptionsPickupIndex
function ConnectedItemsMod:GetColorForIndex(index)
    -- cycle through color palette using modulo operation
    local colorIndex = ((index - 1) % #COLOR_PALETTE) + 1
    return COLOR_PALETTE[colorIndex]
end

-- function to inspect all properties of a pickup entity
function ConnectedItemsMod:InspectPickupEntity(pickup)
    Isaac.ConsoleOutput("=== PICKUP ENTITY INSPECTION ===")
    Isaac.ConsoleOutput("SubType (Item ID): " .. tostring(pickup.SubType))
    Isaac.ConsoleOutput("Index: " .. tostring(pickup.Index))
    Isaac.ConsoleOutput("InitSeed: " .. tostring(pickup.InitSeed))
    Isaac.ConsoleOutput("DropSeed: " .. tostring(pickup.DropSeed))
    Isaac.ConsoleOutput("Price: " .. tostring(pickup.Price))
    Isaac.ConsoleOutput("AutoUpdateDiff: " .. tostring(pickup.AutoUpdateDiff))
    Isaac.ConsoleOutput("Charge: " .. tostring(pickup.Charge))
    Isaac.ConsoleOutput("State: " .. tostring(pickup.State))
    Isaac.ConsoleOutput("Timeout: " .. tostring(pickup.Timeout))
    Isaac.ConsoleOutput("Touched: " .. tostring(pickup.Touched))
    Isaac.ConsoleOutput("Wait: " .. tostring(pickup.Wait))
    Isaac.ConsoleOutput("OptionsPickupIndex: " .. tostring(pickup.OptionsPickupIndex))
    Isaac.ConsoleOutput("Position: " .. tostring(pickup.Position))
    
    -- check special properties of EntityPickup
    if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
        Isaac.ConsoleOutput("*** FOUND OPTIONS PICKUP INDEX: " .. pickup.OptionsPickupIndex .. " ***")
    end
    
    -- try additional properties
    local success, result = pcall(function() return pickup.ShopItemId end)
    if success then Isaac.ConsoleOutput("ShopItemId: " .. tostring(result)) end
    
    success, result = pcall(function() return pickup.TheresOptionsPickup end)
    if success then Isaac.ConsoleOutput("TheresOptionsPickup: " .. tostring(result)) end
    
    Isaac.ConsoleOutput("================================")
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
    -- safely initialize
    connectedItemsInRoom = {}
    
    local optionsGroups = self:FindConnectedItems()
    local groupCount = 0
    
    -- check if optionsGroups is not nil
    if not optionsGroups then
        -- 현재 연결이 없어도 이전 연결 기록을 유지
        self:RestorePersistentConnections()
        return self:CountConnectedGroups()
    end
    
    for index, items in pairs(optionsGroups) do
        if items and #items >= 2 then
            -- 색상 및 해당 팔레트 인덱스 계산
            local colorIndex = ((index - 1) % #COLOR_PALETTE) + 1
            local groupColor = COLOR_PALETTE[colorIndex]
            
            connectedItemsInRoom["options_" .. index] = {
                items = items,
                color = groupColor,
                colorIndex = colorIndex,
                name = "Connected Items (Index: " .. index .. ")"
            }
            groupCount = groupCount + 1
            
            -- 영구 연결 기록에 추가
            self:AddToPersistentConnections(index, items, colorIndex)
        end
    end
    
    -- 현재 연결이 없는 이전 연결들도 복원
    self:RestorePersistentConnections()
    
    return self:CountConnectedGroups()
end

-- function to add items to persistent connections
function ConnectedItemsMod:AddToPersistentConnections(index, items, colorIndex)
    local roomKey = tostring(Game():GetLevel():GetCurrentRoomIndex())
    
    if not persistentConnections[roomKey] then
        persistentConnections[roomKey] = {}
    end
    
    -- 각 아이템을 영구 기록에 추가
    for _, item in ipairs(items) do
        if item.entity and item.entity:Exists() then
            local itemKey = tostring(item.itemId) .. "_" .. tostring(item.entity.InitSeed)
            persistentConnections[roomKey][itemKey] = {
                itemId = item.itemId,
                position = item.position,
                colorIndex = colorIndex,
                optionsIndex = index
            }
            
            -- 현재 방 기록에도 추가
            roomConnectedItems[itemKey] = {
                entity = item.entity,
                itemId = item.itemId,
                position = item.position,
                colorIndex = colorIndex,
                optionsIndex = index
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
                
                -- 이전에 연결되었던 아이템이면 연결 상태 복원
                if persistentData then
                    local groupKey = "persistent_" .. persistentData.optionsIndex
                    
                    if not connectedItemsInRoom[groupKey] then
                        connectedItemsInRoom[groupKey] = {
                            items = {},
                            color = COLOR_PALETTE[persistentData.colorIndex],
                            colorIndex = persistentData.colorIndex,
                            name = "Persistent Connected Items (Index: " .. persistentData.optionsIndex .. ")"
                        }
                    end
                    
                    -- 아이템을 연결 그룹에 추가
                    table.insert(connectedItemsInRoom[groupKey].items, {
                        entity = pickup,
                        position = pickup.Position,
                        itemId = pickup.SubType
                    })
                    
                    -- 현재 방 기록 업데이트
                    roomConnectedItems[itemKey] = {
                        entity = pickup,
                        itemId = pickup.SubType,
                        position = pickup.Position,
                        colorIndex = persistentData.colorIndex,
                        optionsIndex = persistentData.optionsIndex
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

-- function to verify if entity has correct color applied
function ConnectedItemsMod:VerifyEntityColor(entity, expectedColor)
    if not entity or not entity:Exists() then return false end
    
    local currentColor = entity:GetColor()
    local tolerance = 0.1
    
    -- 예상되는 색깔의 강도 계산
    local intensity = ConnectedItemsConfig["colorIntensity"] * 0.15
    local expectedR = expectedColor.R * intensity
    local expectedG = expectedColor.G * intensity  
    local expectedB = expectedColor.B * intensity
    
    -- 허용 오차 범위 내에서 색깔이 맞는지 확인
    return math.abs(currentColor.RO - expectedR) < tolerance and
           math.abs(currentColor.GO - expectedG) < tolerance and
           math.abs(currentColor.BO - expectedB) < tolerance
end

-- function to apply color with verification
function ConnectedItemsMod:ApplyColorWithVerification(entity, color)
    if not entity or not entity:Exists() then return false end
    
    local intensity = ConnectedItemsConfig["colorIntensity"] * 0.15
    local entityColor = Color(1, 1, 1, 1, 
                            color.R * intensity, 
                            color.G * intensity, 
                            color.B * intensity)
    
    -- 더 강한 색깔 적용 (duration을 늘리고 priority 증가)
    entity:SetColor(entityColor, 10, 1, false, false)
    
    -- 추가적인 색깔 적용 (안정성을 위해)
    entity.Color = entityColor
    
    return true
end

-- function to find connected items when entering a room (fast color application)
function ConnectedItemsMod:OnNewRoom()
    -- safely initialize
    connectedItemsInRoom = {}
    coloredEntities = {} -- initialize color tracking
    colorValidationCache = {} -- 색깔 검증 캐시도 초기화
    pedestalEffects = {} -- pedestal 효과 초기화
    globalPedestalReplacements = {} -- 전역 pedestal 교체 초기화
    roomConnectedItems = {} -- 방별 연결 기록 초기화
    
    local groupCount = self:UpdateConnectedItems()
    
    -- initialize entity count
    lastEntityCount = #Isaac.GetRoomEntities()
    renderCallCount = 0
    
    -- 엔진 레벨 스프라이트 가로채기 설정
    self:SetupEngineSpriteMod()
    
    -- apply effects immediately based on mode
    if ConnectedItemsConfig["displayMode"] == 2 then
        self:ForceApplyColors()
    elseif ConnectedItemsConfig["displayMode"] == 3 then
        self:ForceApplyPedestalColors()
        self:SetupGlobalPedestalReplacements()
        -- 극단적 해결책: 전역 스프라이트 교체
        self:ApplyGlobalSpriteReplacements()
        -- 궁극 해결책: 엔진 레벨 가로채기
        self:ApplyEngineSpriteMod()
    end
end

-- function to setup global pedestal replacements
function ConnectedItemsMod:SetupGlobalPedestalReplacements()
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    
    -- 모든 연결된 아이템에 대해 전역 스프라이트 교체 설정
    for groupKey, data in pairs(connectedItemsInRoom) do
        if data and data.items and data.colorIndex then
            local sheetPath = PEDESTAL_SPRITES[data.colorIndex] or "gfx/items/slots/pedestals.png"
            
            for _, item in ipairs(data.items) do
                if item.entity and item.entity:Exists() then
                    local hash = GetPtrHash(item.entity)
                    globalPedestalReplacements[hash] = {
                        colorIndex = data.colorIndex,
                        sheetPath = sheetPath
                    }
                end
            end
        end
    end
end

-- function to apply global sprite replacements (극단적 해결책)
function ConnectedItemsMod:ApplyGlobalSpriteReplacements()
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    
    -- 모든 pickup 엔티티에 대해 즉시 전역 교체 적용
    local entities = Isaac.GetRoomEntities()
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup and pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 and self:IsPickupOnPedestal(pickup) then
                local colorIndex = ((pickup.OptionsPickupIndex - 1) % #COLOR_PALETTE) + 1
                local sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
                
                -- 즉시 10번 연속 적용 (확실히 하기 위해)
                local spr = pickup:GetSprite()
                for i = 1, 10 do
                    for layer = 4, 5 do
                        spr:ReplaceSpritesheet(layer, sheetPath)
                    end
                    spr:LoadGraphics()
                end
                
                -- 스프라이트 강제 새로고침
                spr:Update()
                
                -- 전역 교체 정보에 추가
                local hash = GetPtrHash(pickup)
                globalPedestalReplacements[hash] = {
                    colorIndex = colorIndex,
                    sheetPath = sheetPath
                }
            end
        end
    end
end

-- function to setup engine-level sprite modification
function ConnectedItemsMod:SetupEngineSpriteMod()
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    
    -- 모든 연결된 아이템에 대해 엔진 레벨 교체 설정
    local entities = Isaac.GetRoomEntities()
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup and self:IsPickupOnPedestal(pickup) then
                local colorIndex = nil
                local sheetPath = nil
                
                -- 현재 연결 또는 영구 연결 확인
                if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
                    colorIndex = ((pickup.OptionsPickupIndex - 1) % #COLOR_PALETTE) + 1
                    sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
                else
                    local itemKey = tostring(pickup.SubType) .. "_" .. tostring(pickup.InitSeed)
                    local roomData = roomConnectedItems[itemKey]
                    if roomData then
                        colorIndex = roomData.colorIndex
                        sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
                    end
                end
                
                if sheetPath then
                    local hash = GetPtrHash(pickup)
                    engineSpriteOverrides[hash] = sheetPath
                end
            end
        end
    end
end

-- function to apply engine-level sprite modification
function ConnectedItemsMod:ApplyEngineSpriteMod()
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    
    -- 모든 등록된 엔진 오버라이드 적용
    local entities = Isaac.GetRoomEntities()
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup and self:IsPickupOnPedestal(pickup) then
                local hash = GetPtrHash(pickup)
                local overridePath = engineSpriteOverrides[hash]
                
                if overridePath then
                    -- 엔진 레벨에서 강제 교체
                    self:EngineForceReplace(pickup, overridePath)
                end
            end
        end
    end
end

-- function to force replace at engine level
function ConnectedItemsMod:EngineForceReplace(pickup, sheetPath)
    if not pickup or not pickup:Exists() then return end
    
    local spr = pickup:GetSprite()
    
    -- 50번 연속 적용 + 모든 가능한 강제 처리
    for i = 1, 50 do
        -- 기본 교체
        for layer = 4, 5 do
            spr:ReplaceSpritesheet(layer, sheetPath)
        end
        spr:LoadGraphics()
        spr:Update()
        
        -- 매 10번째마다 추가 강제 처리
        if i % 10 == 0 then
            spr:Play("Idle", true)
            spr:Update()
            spr:SetFrame("Idle", 0)
            spr:Update()
        end
        
        -- 매 25번째마다 완전 리셋
        if i % 25 == 0 then
            spr:Reset()
            for layer = 4, 5 do
                spr:ReplaceSpritesheet(layer, sheetPath)
            end
            spr:LoadGraphics()
            spr:Play("Idle", true)
            spr:Update()
        end
    end
    
    -- 최종 안전장치: 스프라이트 완전 재구성
    spr:Reset()
    for layer = 4, 5 do
        spr:ReplaceSpritesheet(layer, sheetPath)
    end
    spr:LoadGraphics()
    spr:Play("Idle", true)
    spr:SetFrame("Idle", 0)
    spr:Update()
end

-- function to detect item additions/removals in real-time (improved response)
function ConnectedItemsMod:CheckForItemChanges()
    local success = pcall(function()
        local entities = Isaac.GetRoomEntities()
        local currentEntityCount = #entities
        
        -- if entity count changed, check connection state
        if currentEntityCount ~= lastEntityCount then
            if ConnectedItemsConfig["showDebug"] then
                if ConnectedItemsConfig["showConsole"] then
                    Isaac.ConsoleOutput("Entity count changed: " .. tostring(lastEntityCount) .. " -> " .. tostring(currentEntityCount))
                end
            end
            
            -- keep old connection group info
            local oldConnectedItems = connectedItemsInRoom
            
            -- check new connection state
            self:UpdateConnectedItems()
            
            -- check if actual connection configuration has changed
            local connectionsChanged = self:CompareConnectedItems(oldConnectedItems, connectedItemsInRoom)
            
            if connectionsChanged then
                -- if connection changed, reset color tracking and apply immediately
                coloredEntities = {}
                if ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
                    Isaac.ConsoleOutput("Connection layout changed - immediate color reset")
                end
                
                -- apply effects immediately based on mode
                if ConnectedItemsConfig["displayMode"] == 2 then
                    self:ForceApplyColors()
                elseif ConnectedItemsConfig["displayMode"] == 3 then
                    self:ForceApplyPedestalColors()
                end
            end
            
            lastEntityCount = currentEntityCount
        end
    end)
    
    if not success then
        if ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
            Isaac.ConsoleOutput("Error in CheckForItemChanges - using safe fallback")
        end
        -- if error, simply reset colors
        coloredEntities = {}
    end
end

-- function to force apply colors immediately
function ConnectedItemsMod:ForceApplyColors()
    -- pedestal glow 모드일 때는 색깔 적용하지 않음 (Golden Items와 충돌 방지)
    if ConnectedItemsConfig["displayMode"] == 3 then return end
    if ConnectedItemsConfig["displayMode"] ~= 2 then return end -- if not color mode, ignore
    
    local success = pcall(function()
        -- 모든 연결된 아이템 가져오기 (현재 + 영구)
        local allConnectedItems = self:GetAllConnectedItems()
        
        for groupKey, data in pairs(allConnectedItems) do
            if data and data.items and data.color then
                local items = data.items
                local color = data.color
                
                -- apply colors immediately
                for _, item in ipairs(items) do
                    if item.entity and item.entity:Exists() then
                        local entityIndex = GetPtrHash(item.entity)
                        
                        -- 새로운 강화된 색깔 적용 방식 사용
                        self:ApplyColorWithVerification(item.entity, color)
                        coloredEntities[entityIndex] = color
                        
                        -- 색깔 검증 캐시 업데이트
                        colorValidationCache[entityIndex] = {
                            color = color,
                            lastApplied = Game():GetFrameCount()
                        }
                    end
                end
            end
        end
    end)
    
    if not success and ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Error in ForceApplyColors")
    end
end

-- function to compare connected items configuration (improved safety)
function ConnectedItemsMod:CompareConnectedItems(oldItems, newItems)
    local success, result = pcall(function()
        -- check for nil
        if not oldItems or not newItems then
            return true
        end
        
        -- if group count is different, it changed
        local oldCount = 0
        local newCount = 0
        
        for _ in pairs(oldItems) do oldCount = oldCount + 1 end
        for _ in pairs(newItems) do newCount = newCount + 1 end
        
        if oldCount ~= newCount then
            return true
        end
        
        -- if item count in each group is different, it changed
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
        -- if error, assume it changed (safely)
        return true
    end
    
    return result
end

-- function to get all connected items (현재 + 영구 연결 모두 포함)
function ConnectedItemsMod:GetAllConnectedItems()
    local allConnectedItems = {}
    
    -- 현재 방의 모든 아이템 확인
    local entities = Isaac.GetRoomEntities()
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup then
                local itemKey = tostring(pickup.SubType) .. "_" .. tostring(pickup.InitSeed)
                local colorIndex = nil
                local groupId = nil
                
                -- 현재 연결 확인
                if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
                    colorIndex = ((pickup.OptionsPickupIndex - 1) % #COLOR_PALETTE) + 1
                    groupId = "current_" .. pickup.OptionsPickupIndex
                -- 영구 연결 확인
                elseif roomConnectedItems[itemKey] then
                    colorIndex = roomConnectedItems[itemKey].colorIndex
                    groupId = "persistent_" .. roomConnectedItems[itemKey].optionsIndex
                end
                
                -- 연결된 아이템이면 추가
                if colorIndex and groupId then
                    if not allConnectedItems[groupId] then
                        allConnectedItems[groupId] = {
                            items = {},
                            color = COLOR_PALETTE[colorIndex],
                            colorIndex = colorIndex,
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
    -- if mod is disabled, don't render
    if not ConnectedItemsConfig["enabled"] then
        return
    end
    
    -- remove render frequency limit (to avoid flickering)
    renderCallCount = renderCallCount + 1
    
    -- debug: display mode status on top left (only if enabled in settings)
    if ConnectedItemsConfig["showDebug"] then
        Isaac.RenderText("Connected Items Mod Active", 10, 10, 255, 255, 255, 255)
        Isaac.RenderText("Render Count: " .. renderCallCount, 10, 25, 255, 255, 255, 255)
        Isaac.RenderText("Mode: " .. DISPLAY_MODES[ConnectedItemsConfig["displayMode"]], 10, 120, 255, 255, 100, 255)
        Isaac.RenderText("Frame: " .. Game():GetFrameCount() % 100, 10, 245, 100, 100, 255, 255)
        -- 로그 버퍼 표시
        local y = 260
        for i, msg in ipairs(CIVLogBuffer) do
            Isaac.RenderText(msg, 10, y + (i-1)*12, 200, 200, 50, 255)
        end
    end
    
    -- 모든 연결된 아이템 가져오기 (현재 + 영구)
    local allConnectedItems = self:GetAllConnectedItems()
    
    if not allConnectedItems then 
        if ConnectedItemsConfig["showDebug"] then
            Isaac.RenderText("allConnectedItems is nil", 10, 40, 255, 100, 100, 255)
        end
        return 
    end
    
    local groupCount = 0
    for _, _ in pairs(allConnectedItems) do
        groupCount = groupCount + 1
    end
    
    if ConnectedItemsConfig["showDebug"] then
        Isaac.RenderText("Groups: " .. groupCount, 10, 40, 255, 255, 255, 255)
    end
    
    if groupCount == 0 then
        if ConnectedItemsConfig["showDebug"] then
            Isaac.RenderText("No connected groups", 10, 55, 255, 200, 100, 255)
        end
        return
    end
    
    -- 그룹을 정렬된 순서로 처리하기 위해 키를 수집하고 정렬
    local sortedGroups = {}
    for groupKey, data in pairs(allConnectedItems) do
        if data and data.items and data.color and #data.items >= 2 then
            table.insert(sortedGroups, {key = groupKey, data = data})
        end
    end
    
    -- 그룹 키 기준으로 정렬 (일관된 순서 보장)
    table.sort(sortedGroups, function(a, b) return a.key < b.key end)
    
    local groupsRendered = 0
    local linesDrawn = 0
    
    -- safe rendering (to avoid conflicts with other mods)
    local success, err = pcall(function()
        for i, groupInfo in ipairs(sortedGroups) do
            local groupKey = groupInfo.key
            local data = groupInfo.data
            local items = data.items
            local color = data.color
            
            groupsRendered = groupsRendered + 1
            
            if ConnectedItemsConfig["showDebug"] then
                Isaac.RenderText("Group " .. groupsRendered .. ": " .. #items .. " items (" .. groupKey .. ")", 10, 55 + (groupsRendered * 15), 
                               color.R * 255, color.G * 255, color.B * 255, 255)
            end
            
            -- use different rendering methods based on current display mode
            local mode = DISPLAY_MODES[ConnectedItemsConfig["displayMode"]]
            
            if mode == "NUMBER_OVERLAY" then
                -- 1부터 시작하는 일관된 번호 사용
                self:RenderNumberOverlay(items, color, groupsRendered)
            elseif mode == "COLOR_AREA" then
                self:RenderColorArea(items, color)
            elseif mode == "PEDESTAL_COLOR" then
                self:RenderPedestalColor(items, data.colorIndex)
            end
        end
    end)
    
    if not success then
        CIVLog("Render error: " .. tostring(err))
        if ConnectedItemsConfig["showDebug"] then
            Isaac.RenderText("Render Error!", 10, 240, 255, 0, 0, 255)
        end
    end
    
    if ConnectedItemsConfig["showDebug"] then
        Isaac.RenderText("Lines: " .. linesDrawn, 10, 70 + (groupsRendered * 15), 100, 255, 100, 255)
    end
end

-- function to render number overlay (apply color)
function ConnectedItemsMod:RenderNumberOverlay(items, color, groupNumber)
    for _, item in ipairs(items) do
        if item.entity and item.entity:Exists() then
            local screenPos = Isaac.WorldToScreen(item.entity.Position)
            local numberText = tostring(groupNumber)
            
            -- adjust position based on number size (설정에서 조정 가능)
            local offsetX = ConnectedItemsConfig["numberOffsetX"] - (#numberText - 1) * 3
            local offsetY = ConnectedItemsConfig["numberOffsetY"]
            
            -- background (black border effect)
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        Isaac.RenderText(numberText, 
                                       screenPos.X + offsetX + dx, 
                                       screenPos.Y + offsetY + dy,
                                       0, 0, 0, 200) -- black border effect
                    end
                end
            end
            
            -- main number (displayed in group color)
            Isaac.RenderText(numberText, 
                           screenPos.X + offsetX, 
                           screenPos.Y + offsetY,
                           color.R * 255, color.G * 255, color.B * 255, 255)
        end
    end
end

-- function to render color effect (enhanced with constant verification)
function ConnectedItemsMod:RenderColorArea(items, color)
    -- Glitched Crown 대응을 위해 매 프레임 색깔을 재적용하여 깜빡임을 방지
    local currentFrame = Game():GetFrameCount()
    for _, item in ipairs(items) do
        if item.entity and item.entity:Exists() then
            local entityIndex = GetPtrHash(item.entity)
            -- 항상 색깔 재적용
            self:ApplyColorWithVerification(item.entity, color)
            -- 캐시 갱신
            colorValidationCache[entityIndex] = {
                color = color,
                lastApplied = currentFrame
            }
            if ConnectedItemsConfig["showDebug"] then
                local screenPos = Isaac.WorldToScreen(item.entity.Position)
                Isaac.RenderText("CLR", screenPos.X + 20, screenPos.Y - 10, 0, 255, 255, 255)
            end
        end
    end
end

-- function to get accurate pedestal information
function ConnectedItemsMod:GetPedestalInfo(pickup)
    if not pickup or not pickup:Exists() then return nil end
    
    local sprite = pickup:GetSprite()
    local position = pickup.Position

    -- 일부 게임 버전(Afterbirth+ 등)에서는 GetTexel1 메서드가 존재하지 않을 수 있음
    local texel = nil
    if sprite.GetTexel1 then
        local ok, res = pcall(function() return sprite:GetTexel1() end)
        if ok then texel = res end
    end

    -- GetOffset 역시 버전에 따라 없을 수 있음
    local offset = Vector(0,0)
    if sprite.GetOffset then
        local ok2, res2 = pcall(function() return sprite:GetOffset() end)
        if ok2 and res2 then offset = res2 end
    end

    -- pedestal의 정확한 정보 수집
    local pedestalInfo = {
        worldPos = position,
        spriteSize = texel,          -- nil 가능; 후속 계산에서 체크함
        spriteOffset = offset,
        pedestalBase = Vector(position.X, position.Y + 20), -- pedestal 바닥 추정
        pedestalCenter = Vector(position.X, position.Y + 10), -- pedestal 중심 추정
    }
    
    -- 스프라이트 레이어 정보 분석 (Item Pedestal Overhaul 참고)
    local layerInfo = {}
    for i = 0, 7 do
        local success = pcall(function()
            local layerFrame = sprite:GetLayerFrame(i)
            if layerFrame >= 0 then
                layerInfo[i] = layerFrame
            end
        end)
    end
    pedestalInfo.layers = layerInfo
    
    return pedestalInfo
end

-- function to calculate precise glow position and size
function ConnectedItemsMod:CalculatePreciseGlowTransform(pedestalInfo, offsetY)
    if not pedestalInfo then return nil end
    
    -- pedestal 바닥을 기준으로 glow 위치 계산
    local glowWorldPos = Vector(
        pedestalInfo.worldPos.X,
        pedestalInfo.pedestalBase.Y + offsetY
    )
    
    -- pedestal 크기에 맞는 glow 스케일 계산
    local baseScale = pedestalInfo.spriteSize and math.max(0.4,
                     math.min(1.0, pedestalInfo.spriteSize.X / 64))
                 or 0.5         -- ← 기본값 0.5 (64px → 32px)
    
    return {
        position = glowWorldPos,
        scale = baseScale,
        layers = pedestalInfo.layers
    }
end

-- helper: pickup이 실제 pedestal 위에 놓여 있는지(레이어 4 또는 5가 존재) 확인
function ConnectedItemsMod:IsPickupOnPedestal(pickup)
    if not pickup or not pickup:Exists() then return false end
    if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return false end

    -- IPO 로직과 동일
    local sprite = pickup:GetSprite()
    return sprite:GetOverlayFrame() == 0
end

-- function to render pedestal with colored spritesheet (no glow overlay)
function ConnectedItemsMod:RenderPedestalColor(items, colorIdx)
    local sheetPath = PEDESTAL_SPRITES[colorIdx]
    if not sheetPath then
        sheetPath = "gfx/items/slots/pedestals.png"
    end

    for _, it in ipairs(items) do
        if it.entity and it.entity:Exists() and self:IsPickupOnPedestal(it.entity) then
            local spr = it.entity:GetSprite()
            -- 매 렌더마다 시트 교체 (Glitched Crown 대응)
            for layer = 4, 5 do
                spr:ReplaceSpritesheet(layer, sheetPath)
            end
            spr:LoadGraphics()
            
            -- 즉시 한 번 더 적용 (더블 체크)
            for layer = 4, 5 do
                spr:ReplaceSpritesheet(layer, sheetPath)
            end
        end
    end
end

-- function to pre-render pedestal protection (렌더 직전 보호)
function ConnectedItemsMod:OnPreRender()
    if not ConnectedItemsConfig["enabled"] then return end
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    
    -- 모든 연결된 아이템에 대해 pedestal 색상 재확인
    local allConnectedItems = self:GetAllConnectedItems()
    if not allConnectedItems then return end
    
    for groupKey, data in pairs(allConnectedItems) do
        if data and data.items and data.colorIndex then
            local sheetPath = PEDESTAL_SPRITES[data.colorIndex] or "gfx/items/slots/pedestals.png"
            
            for _, item in ipairs(data.items) do
                if item.entity and item.entity:Exists() and self:IsPickupOnPedestal(item.entity) then
                    local spr = item.entity:GetSprite()
                    for layer = 4, 5 do
                        spr:ReplaceSpritesheet(layer, sheetPath)
                    end
                    spr:LoadGraphics()
                end
            end
        end
    end
end

-- function to clean up colored entities (improved safety)
function ConnectedItemsMod:CleanupColoredEntities()
    local success = pcall(function()
        local entities = Isaac.GetRoomEntities()
        local existingEntities = {}
        
        -- collect currently existing entities
        for _, entity in ipairs(entities) do
            if entity then
                local hash = GetPtrHash(entity)
                if hash then
                    existingEntities[hash] = true
                end
            end
        end
        
        -- remove entities that don't exist from tracking
        for entityIndex, _ in pairs(coloredEntities) do
            if not existingEntities[entityIndex] then
                coloredEntities[entityIndex] = nil
            end
        end
    end)
    
    if not success and ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Error in CleanupColoredEntities - resetting all")
        coloredEntities = {}
    end
end

-- function to update (improved response with color verification)
function ConnectedItemsMod:OnUpdate()
    if not ConnectedItemsConfig["enabled"] then
        return
    end
    
    local success = pcall(function()
        local currentFrame = Game():GetFrameCount()
        
        -- check more frequently (5 frames for pedestal mode, 15 frames for others)
        local checkInterval = ConnectedItemsConfig["displayMode"] == 3 and 5 or 15
        if currentFrame % checkInterval == 0 then
            self:CheckForItemChanges()
        end
        
        -- 추가: 더 자주 연결 상태 확인 (number 모드에서 새 그룹 감지 향상)
        if ConnectedItemsConfig["displayMode"] == 1 and currentFrame % 10 == 0 then
            self:CheckForNewConnections()
        end
        
        -- 색깔 검증을 더 자주 수행 (5프레임마다) - color 모드일 때만
        if ConnectedItemsConfig["displayMode"] == 2 and currentFrame % 5 == 0 then
            self:PerformColorVerification()
        end
        
        -- pedestal 검증을 더 자주 수행 (매 프레임) - pedestal 모드일 때만
        if ConnectedItemsConfig["displayMode"] == 3 then
            self:PerformPedestalVerification()
        end
        
        -- clean up every 5 minutes
        if currentFrame % 18000 == 0 then
            self:CleanupColoredEntities()
            -- 색깔 검증 캐시도 정리
            self:CleanupColorValidationCache()
        end
    end)
    
    if not success and ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Error in OnUpdate")
    end
end

-- function to perform periodic color verification
function ConnectedItemsMod:PerformColorVerification()
    local success = pcall(function()
        -- 모든 연결된 아이템 가져오기 (현재 + 영구)
        local allConnectedItems = self:GetAllConnectedItems()
        if not allConnectedItems then return end
        
        for groupKey, data in pairs(allConnectedItems) do
            if data and data.items and data.color then
                for _, item in ipairs(data.items) do
                    if item.entity and item.entity:Exists() then
                        local entityIndex = GetPtrHash(item.entity)
                        
                        -- 색깔이 잘못되었거나 없는 경우 즉시 수정
                        if not self:VerifyEntityColor(item.entity, data.color) then
                            self:ApplyColorWithVerification(item.entity, data.color)
                            
                            colorValidationCache[entityIndex] = {
                                color = data.color,
                                lastApplied = Game():GetFrameCount()
                            }
                            
                            if ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
                                Isaac.ConsoleOutput("Color verification: Reapplied color to entity " .. entityIndex)
                            end
                        end
                    end
                end
            end
        end
    end)
    
    if not success and ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Error in PerformColorVerification")
    end
end

-- function to perform periodic pedestal verification
function ConnectedItemsMod:PerformPedestalVerification()
    local success = pcall(function()
        -- 모든 연결된 아이템 가져오기 (현재 + 영구)
        local allConnectedItems = self:GetAllConnectedItems()
        if not allConnectedItems then return end
        
        for groupKey, data in pairs(allConnectedItems) do
            if data and data.items and data.colorIndex then
                for _, item in ipairs(data.items) do
                    if item.entity and item.entity:Exists() and self:IsPickupOnPedestal(item.entity) then
                        local spr = item.entity:GetSprite()
                        local sheetPath = PEDESTAL_SPRITES[data.colorIndex] or "gfx/items/slots/pedestals.png"
                        
                        -- 매 프레임 스프라이트시트 재적용 (깜빡임 방지)
                        for layer = 4, 5 do
                            spr:ReplaceSpritesheet(layer, sheetPath)
                        end
                        spr:LoadGraphics()
                    end
                end
            end
        end
    end)
    
    if not success and ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Error in PerformPedestalVerification")
    end
end

-- function to clean up color validation cache
function ConnectedItemsMod:CleanupColorValidationCache()
    local success = pcall(function()
        local entities = Isaac.GetRoomEntities()
        local existingEntities = {}
        
        -- collect currently existing entities
        for _, entity in ipairs(entities) do
            if entity then
                local hash = GetPtrHash(entity)
                if hash then
                    existingEntities[hash] = true
                end
            end
        end
        
        -- remove entities that don't exist from validation cache
        for entityIndex, _ in pairs(colorValidationCache) do
            if not existingEntities[entityIndex] then
                colorValidationCache[entityIndex] = nil
            end
        end
    end)
    
    if not success and ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Error in CleanupColorValidationCache - resetting all")
        colorValidationCache = {}
    end
end

-- function to reset settings to default values
function ConnectedItemsMod:ResetToDefaults()
    ConnectedItemsConfig["displayMode"] = 2
    ConnectedItemsConfig["enabled"] = true
    ConnectedItemsConfig["showDebug"] = false
    ConnectedItemsConfig["colorIntensity"] = 1
    ConnectedItemsConfig["showConsole"] = false
    ConnectedItemsConfig["numberOffsetY"] = -3
    ConnectedItemsConfig["numberOffsetX"] = -4
    
    if ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Connected Items Config reset to defaults")
    end

    -- 변경사항을 즉시 저장
    ConnectedItemsMod:SaveGame()
end

-- Mod Config Menu settings
if ModConfigMenu then
    local ConnectedItems = "CIV"  -- change name to CIV

    ModConfigMenu.UpdateCategory(ConnectedItems, {
        Info = {"CIV - Shows connections between related items."}
    })

    -- title
    ModConfigMenu.AddText(ConnectedItems, "Settings", function() return "CIV Settings" end)
    ModConfigMenu.AddSpace(ConnectedItems, "Settings")

    -- enable/disable mode
    ModConfigMenu.AddSetting(ConnectedItems, "Settings", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return ConnectedItemsConfig["enabled"]
        end,
        Display = function()
            local onOff = ConnectedItemsConfig["enabled"] and "On" or "Off"
            return 'Mod Status: ' .. onOff
        end,
        OnChange = function(currentBool)
            ConnectedItemsConfig["enabled"] = currentBool
            ConnectedItemsMod:SaveGame()
        end,
        Info = {"Enable or disable the mod."}
    })

    -- display mode selection
    ModConfigMenu.AddSetting(ConnectedItems, "Settings", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
            return ConnectedItemsConfig["displayMode"]
        end,
        Minimum = 1,
        Maximum = 3,
        Display = function()
            local modeNames = {"Numbers", "Color Effect", "Pedestal Color"}
            return "Display Mode: " .. modeNames[ConnectedItemsConfig["displayMode"]]
        end,
        OnChange = function(currentNum)
            ConnectedItemsConfig["displayMode"] = currentNum
            ConnectedItemsMod:SaveGame()
        end,
        Info = {"1. Numbers", "2. Color Effect (Not compatible with Golden Items)", "3. Pedestal Color (Golden Items compatible)"}
    })

    -- color intensity setting
    ModConfigMenu.AddSetting(ConnectedItems, "Settings", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
            return ConnectedItemsConfig["colorIntensity"]
        end,
        Minimum = 1,
        Maximum = 5,
        Display = function()
            return "Color Intensity: " .. ConnectedItemsConfig["colorIntensity"]
        end,
        OnChange = function(currentNum)
            ConnectedItemsConfig["colorIntensity"] = currentNum
            ConnectedItemsMod:SaveGame()
        end,
        Info = {"Adjust intensity of color effects."}
    })

    -- number offset Y setting
    ModConfigMenu.AddSetting(ConnectedItems, "Settings", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
            return ConnectedItemsConfig["numberOffsetY"]
        end,
        Minimum = -50,
        Maximum = 50,
        Display = function()
            return "Number Y Offset: " .. ConnectedItemsConfig["numberOffsetY"]
        end,
        OnChange = function(currentNum)
            ConnectedItemsConfig["numberOffsetY"] = currentNum
            ConnectedItemsMod:SaveGame()
        end,
        Info = {"Adjust vertical position of number overlay.", "Negative = up, Positive = down"}
    })

    -- number offset X setting
    ModConfigMenu.AddSetting(ConnectedItems, "Settings", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function()
            return ConnectedItemsConfig["numberOffsetX"]
        end,
        Minimum = -50,
        Maximum = 50,
        Display = function()
            return "Number X Offset: " .. ConnectedItemsConfig["numberOffsetX"]
        end,
        OnChange = function(currentNum)
            ConnectedItemsConfig["numberOffsetX"] = currentNum
            ConnectedItemsMod:SaveGame()
        end,
        Info = {"Adjust horizontal position of number overlay.", "Negative = left, Positive = right"}
    })

    -- debug info display
    ModConfigMenu.AddSetting(ConnectedItems, "Settings", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return ConnectedItemsConfig["showDebug"]
        end,
        Display = function()
            local onOff = ConnectedItemsConfig["showDebug"] and "Show" or "Hide"
            return 'Debug Info: ' .. onOff
        end,
        OnChange = function(currentBool)
            ConnectedItemsConfig["showDebug"] = currentBool
            ConnectedItemsMod:SaveGame()
        end,
        Info = {"Show debug information on screen."}
    })

    -- console output display
    ModConfigMenu.AddSetting(ConnectedItems, "Settings", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
            return ConnectedItemsConfig["showConsole"]
        end,
        Display = function()
            local onOff = ConnectedItemsConfig["showConsole"] and "Show" or "Hide"
            return 'Console Output: ' .. onOff
        end,
        OnChange = function(currentBool)
            ConnectedItemsConfig["showConsole"] = currentBool
            ConnectedItemsMod:SaveGame()
        end,
        Info = {"Show console output messages."}
    })

    -- add Reset Config button
    ModConfigMenu.AddSpace(ConnectedItems, "Settings")
    ModConfigMenu.AddSetting(ConnectedItems, "Settings", {
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
            ConnectedItemsMod:SaveGame()
        end,
        Info = {"Reset all settings to default values."}
    })
end

-- save/load system
local json = require("json")
local SaveState = {}

function ConnectedItemsMod:SaveGame()
    SaveState.Settings = {}
    
    for i, v in pairs(ConnectedItemsConfig) do
        SaveState.Settings[tostring(i)] = ConnectedItemsConfig[i]
    end
    ConnectedItemsMod:SaveData(json.encode(SaveState))
end

function ConnectedItemsMod:OnGameStart(isSave)
    if ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("=== Connected Items Mod: Game Started ===")
        Isaac.ConsoleOutput("Loading settings...")
    end
    
    if ConnectedItemsMod:HasData() then    
        local success, result = pcall(function()
            return json.decode(ConnectedItemsMod:LoadData())
        end)
        
        if success and result and result.Settings then
            SaveState = result
            if ConnectedItemsConfig["showConsole"] then
                Isaac.ConsoleOutput("Settings loaded successfully")
            end
            
            for i, v in pairs(SaveState.Settings) do
                if ConnectedItemsConfig[tostring(i)] ~= nil then
                    ConnectedItemsConfig[tostring(i)] = SaveState.Settings[i]
                    if ConnectedItemsConfig["showConsole"] then
                        Isaac.ConsoleOutput("Loaded setting: " .. tostring(i) .. " = " .. tostring(SaveState.Settings[i]))
                    end
                end
            end
        else
            if ConnectedItemsConfig["showConsole"] then
                Isaac.ConsoleOutput("Failed to load settings, using defaults")
            end
        end
    else
        -- set default values when no save data exists
        local defaultConfig = {
            ["displayMode"] = 3,
            ["enabled"] = true,
            ["showDebug"] = false,
            ["colorIntensity"] = 1,
            ["showConsole"] = false,
            ["numberOffsetY"] = -3,
            ["numberOffsetX"] = -4,
        }
        
        for key, value in pairs(defaultConfig) do
            ConnectedItemsConfig[key] = value
        end
        
        if ConnectedItemsConfig["showConsole"] then
            Isaac.ConsoleOutput("No saved data found, using defaults")
        end
    end
    
    -- log final settings state
    if ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("=== Final Settings ===")
        for key, value in pairs(ConnectedItemsConfig) do
            Isaac.ConsoleOutput(key .. ": " .. tostring(value))
        end
        Isaac.ConsoleOutput("======================")
    end
end

-- register events
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, ConnectedItemsMod.OnNewRoom)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_RENDER, ConnectedItemsMod.OnRender)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_PRE_RENDER, ConnectedItemsMod.OnPreRender)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, ConnectedItemsMod.OnPickupCollision)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_UPDATE, ConnectedItemsMod.OnUpdate)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, ConnectedItemsMod.SaveGame)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, ConnectedItemsMod.OnGameStart)
-- 아이템 생성 즉시 pedestal 색상 적용 (깜빡임 완전 방지)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, ConnectedItemsMod.OnPickupInit)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, ConnectedItemsMod.OnPickupUpdate)
-- 최강 보호: 각 pickup의 렌더 직전에 개별 처리
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_PICKUP_RENDER, ConnectedItemsMod.OnPickupRender)
-- 엔티티 스폰 즉시 처리 (가장 빠른 대응)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_ENTITY_SPAWN, ConnectedItemsMod.OnEntitySpawn)
-- 궁극의 해결책: 모든 가능한 콜백에서 동시 적용
ConnectedItemsMod:AddCallback(ModCallbacks.MC_POST_ENTITY_RENDER, ConnectedItemsMod.OnEntityRender)
ConnectedItemsMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, ConnectedItemsMod.OnInputAction)

-- function to handle entity render (모든 엔티티 렌더 시 강제 적용)
function ConnectedItemsMod:OnEntityRender(entity, renderOffset)
    if not ConnectedItemsConfig["enabled"] then return end
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    if entity.Type ~= EntityType.ENTITY_PICKUP then return end
    if entity.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
    
    local pickup = entity:ToPickup()
    if not pickup or not self:IsPickupOnPedestal(pickup) then return end
    
    -- 무조건 브루트포스 적용
    self:BruteForcePedestalColor(pickup)
end

-- function to handle input action (입력 시에도 강제 적용)
function ConnectedItemsMod:OnInputAction(entity, inputHook, buttonAction)
    if not ConnectedItemsConfig["enabled"] then return end
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    
    -- 입력이 있을 때마다 모든 연결된 아이템에 브루트포스 적용
    self:ApplyBruteForceToAllConnected()
end

-- function to apply brute force pedestal color
function ConnectedItemsMod:BruteForcePedestalColor(pickup)
    if not pickup or not pickup:Exists() then return end
    
    local colorIndex = nil
    local sheetPath = nil
    
    -- 현재 연결 확인
    if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
        colorIndex = ((pickup.OptionsPickupIndex - 1) % #COLOR_PALETTE) + 1
        sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
    else
        -- 영구 연결 확인
        local itemKey = tostring(pickup.SubType) .. "_" .. tostring(pickup.InitSeed)
        local roomData = roomConnectedItems[itemKey]
        if roomData then
            colorIndex = roomData.colorIndex
            sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
        end
    end
    
    if sheetPath then
        -- 엔진 레벨 강제 교체 사용
        self:EngineForceReplace(pickup, sheetPath)
        
        -- 추가: 기존 브루트포스도 병행
        local spr = pickup:GetSprite()
        -- 30번 연속 적용 + 다중 강제 업데이트
        for i = 1, 30 do
            for layer = 4, 5 do
                spr:ReplaceSpritesheet(layer, sheetPath)
            end
            spr:LoadGraphics()
            spr:Update()
            
            -- 추가 강제 처리
            if i % 5 == 0 then
                spr:Play("Idle", true)
                spr:Update()
            end
            
            -- 매 15번째마다 완전 리셋
            if i % 15 == 0 then
                spr:Reset()
                for layer = 4, 5 do
                    spr:ReplaceSpritesheet(layer, sheetPath)
                end
                spr:LoadGraphics()
                spr:Play("Idle", true)
                spr:Update()
            end
        end
    end
end

-- function to apply brute force to all connected items
function ConnectedItemsMod:ApplyBruteForceToAllConnected()
    -- 현재 방의 모든 아이템에 브루트포스 적용
    local entities = Isaac.GetRoomEntities()
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup then
                self:BruteForcePedestalColor(pickup)
            end
        end
    end
end

-- function to handle individual pickup rendering (최강 보호)
function ConnectedItemsMod:OnPickupRender(pickup, renderOffset)
    if not ConnectedItemsConfig["enabled"] then return end
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
    if not self:IsPickupOnPedestal(pickup) then return end
    
    -- 브루트포스 적용
    self:BruteForcePedestalColor(pickup)
    
    local hash = GetPtrHash(pickup)
    local replacement = globalPedestalReplacements[hash]
    
    -- 현재 연결 확인
    if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
        local colorIndex = ((pickup.OptionsPickupIndex - 1) % #COLOR_PALETTE) + 1
        local sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
        
        local spr = pickup:GetSprite()
        -- 15번 연속 적용 + 강제 업데이트 (확실히 하기 위해)
        for i = 1, 15 do
            for layer = 4, 5 do
                spr:ReplaceSpritesheet(layer, sheetPath)
            end
            spr:LoadGraphics()
            spr:Update() -- 강제 스프라이트 업데이트
            
            -- 매 5번째마다 추가 처리
            if i % 5 == 0 then
                spr:Play("Idle", true)
                spr:Update()
            end
            
            -- 매 15번째마다 완전 리셋
            if i % 15 == 0 then
                spr:Reset()
                for layer = 4, 5 do
                    spr:ReplaceSpritesheet(layer, sheetPath)
                end
                spr:LoadGraphics()
                spr:Play("Idle", true)
                spr:Update()
            end
        end
        
        -- 전역 교체 정보에 추가
        globalPedestalReplacements[hash] = {
            colorIndex = colorIndex,
            sheetPath = sheetPath
        }
    -- 영구 연결 확인
    else
        local itemKey = tostring(pickup.SubType) .. "_" .. tostring(pickup.InitSeed)
        local roomData = roomConnectedItems[itemKey]
        if roomData then
            local colorIndex = roomData.colorIndex
            local sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
            
            local spr = pickup:GetSprite()
            -- 15번 연속 적용 + 강제 업데이트 (확실히 하기 위해)
            for i = 1, 15 do
                for layer = 4, 5 do
                    spr:ReplaceSpritesheet(layer, sheetPath)
                end
                spr:LoadGraphics()
                spr:Update() -- 강제 스프라이트 업데이트
                
                -- 매 5번째마다 추가 처리
                if i % 5 == 0 then
                    spr:Play("Idle", true)
                    spr:Update()
                end
                
                -- 매 15번째마다 완전 리셋
                if i % 15 == 0 then
                    spr:Reset()
                    for layer = 4, 5 do
                        spr:ReplaceSpritesheet(layer, sheetPath)
                    end
                    spr:LoadGraphics()
                    spr:Play("Idle", true)
                    spr:Update()
                end
            end
            
            -- 전역 교체 정보에 추가
            globalPedestalReplacements[hash] = {
                colorIndex = colorIndex,
                sheetPath = sheetPath
            }
        -- 전역 교체 정보가 있으면 즉시 적용
        elseif replacement then
            local spr = pickup:GetSprite()
            -- 15번 연속 적용 + 강제 업데이트 (확실히 하기 위해)
            for i = 1, 15 do
                for layer = 4, 5 do
                    spr:ReplaceSpritesheet(layer, replacement.sheetPath)
                end
                spr:LoadGraphics()
                spr:Update() -- 강제 스프라이트 업데이트
                
                -- 매 5번째마다 추가 처리
                if i % 5 == 0 then
                    spr:Play("Idle", true)
                    spr:Update()
                end
                
                -- 매 15번째마다 완전 리셋
                if i % 15 == 0 then
                    spr:Reset()
                    for layer = 4, 5 do
                        spr:ReplaceSpritesheet(layer, replacement.sheetPath)
                    end
                    spr:LoadGraphics()
                    spr:Play("Idle", true)
                    spr:Update()
                end
            end
        end
    end
end

-- function to handle entity spawn (엔티티 생성 즉시 처리)
function ConnectedItemsMod:OnEntitySpawn(entity)
    if not ConnectedItemsConfig["enabled"] then return end
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    if entity.Type ~= EntityType.ENTITY_PICKUP then return end
    if entity.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
    
    local pickup = entity:ToPickup()
    if not pickup then return end
    
    -- 스폰 즉시 색상 적용 시도 (다음 프레임에)
    pickup:GetData().civSpawnFrame = Game():GetFrameCount()
    pickup:GetData().civNeedsColorApplication = true
end

-- function to handle pickup initialization (즉시 pedestal 색상 적용)
function ConnectedItemsMod:OnPickupInit(pickup)
    if not ConnectedItemsConfig["enabled"] then return end
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
    
    -- 초기화 시점 기록
    pickup:GetData().civInitFrame = Game():GetFrameCount()
    pickup:GetData().civNeedsColorApplication = true
end

-- function to handle pickup updates (지속적인 pedestal 색상 유지)
function ConnectedItemsMod:OnPickupUpdate(pickup)
    if not ConnectedItemsConfig["enabled"] then return end
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end
    if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
    if not self:IsPickupOnPedestal(pickup) then return end
    
    local data = pickup:GetData()
    local currentFrame = Game():GetFrameCount()
    
    -- 스폰 후 색상 적용이 필요한 경우
    if data.civNeedsColorApplication and data.civSpawnFrame and currentFrame >= data.civSpawnFrame + 1 then
        local colorIndex = nil
        local sheetPath = nil
        
        -- 현재 연결 확인
        if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
            colorIndex = ((pickup.OptionsPickupIndex - 1) % #COLOR_PALETTE) + 1
            sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
        else
            -- 영구 연결 확인
            local itemKey = tostring(pickup.SubType) .. "_" .. tostring(pickup.InitSeed)
            local roomData = roomConnectedItems[itemKey]
            if roomData then
                colorIndex = roomData.colorIndex
                sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
            end
        end
        
        if sheetPath then
            local spr = pickup:GetSprite()
            -- 5번 연속 적용 (확실히 하기 위해)
            for i = 1, 5 do
                for layer = 4, 5 do
                    spr:ReplaceSpritesheet(layer, sheetPath)
                end
                spr:LoadGraphics()
                spr:Update()
            end
            
            data.civNeedsColorApplication = false
        end
    end
    
    -- 연결된 아이템인지 확인하고 색상 적용 (더 적극적으로)
    local colorIndex = nil
    local sheetPath = nil
    
    -- 현재 연결 확인
    if pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
        colorIndex = ((pickup.OptionsPickupIndex - 1) % #COLOR_PALETTE) + 1
        sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
    else
        -- 영구 연결 확인
        local itemKey = tostring(pickup.SubType) .. "_" .. tostring(pickup.InitSeed)
        local roomData = roomConnectedItems[itemKey]
        if roomData then
            colorIndex = roomData.colorIndex
            sheetPath = PEDESTAL_SPRITES[colorIndex] or "gfx/items/slots/pedestals.png"
        end
    end
    
    if sheetPath then
        local spr = pickup:GetSprite()
        -- 매 업데이트마다 5번 강제 적용 (Glitched Crown 대응)
        for i = 1, 5 do
            for layer = 4, 5 do
                spr:ReplaceSpritesheet(layer, sheetPath)
            end
            spr:LoadGraphics()
            spr:Update()
        end
        
        -- 데이터에 색상 정보 저장 (지속적 추적)
        data.civColorIndex = colorIndex
        data.civSheetPath = sheetPath
    end
end

-- function to remove other connected items when an item is picked up (glow 기능 제거됨)
function ConnectedItemsMod:OnPickupCollision(pickup, collider, low)
    if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
    if collider.Type ~= EntityType.ENTITY_PLAYER then return end

    -- check if the picked up item is in a connected group
    for groupKey, data in pairs(connectedItemsInRoom) do
        local items = data.items
        for _, item in ipairs(items) do
            if item.entity == pickup then
                -- remove other items in the same group
                for _, otherItem in ipairs(items) do
                    if otherItem.entity ~= pickup and otherItem.entity:Exists() then
                        otherItem.entity:Remove()
                    end
                end
                connectedItemsInRoom[groupKey] = nil
                break
            end
        end
    end
end

-- function to force apply pedestal colors immediately
function ConnectedItemsMod:ForceApplyPedestalColors()
    if ConnectedItemsConfig["displayMode"] ~= 3 then return end -- if not pedestal mode, ignore
    
    local success = pcall(function()
        -- 모든 연결된 아이템 가져오기 (현재 + 영구)
        local allConnectedItems = self:GetAllConnectedItems()
        
        for groupKey, data in pairs(allConnectedItems) do
            if data and data.items and data.colorIndex then
                local items = data.items
                local colorIdx = data.colorIndex
                
                -- apply pedestal colors immediately
                for _, item in ipairs(items) do
                    if item.entity and item.entity:Exists() and self:IsPickupOnPedestal(item.entity) then
                        local spr = item.entity:GetSprite()
                        local sheetPath = PEDESTAL_SPRITES[colorIdx] or "gfx/items/slots/pedestals.png"
                        
                        for layer = 4, 5 do
                            spr:ReplaceSpritesheet(layer, sheetPath)
                        end
                        spr:LoadGraphics()
                    end
                end
            end
        end
    end)
    
    if not success and ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Error in ForceApplyPedestalColors")
    end
end

-- function to check for new connections (새 연결 감지 향상)
function ConnectedItemsMod:CheckForNewConnections()
    local success = pcall(function()
        -- 기존 그룹 수 저장
        local oldGroupCount = 0
        for _, _ in pairs(connectedItemsInRoom) do
            oldGroupCount = oldGroupCount + 1
        end
        
        -- 연결 상태 업데이트
        local newGroupCount = self:UpdateConnectedItems()
        
        -- 그룹 수가 변경되었으면 즉시 적용
        if newGroupCount ~= oldGroupCount then
            if ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
                Isaac.ConsoleOutput("New connection detected: " .. oldGroupCount .. " -> " .. newGroupCount)
            end
            
            -- 모드에 따라 즉시 적용
            if ConnectedItemsConfig["displayMode"] == 2 then
                self:ForceApplyColors()
            elseif ConnectedItemsConfig["displayMode"] == 3 then
                self:ForceApplyPedestalColors()
                self:SetupGlobalPedestalReplacements()
                self:ApplyGlobalSpriteReplacements()
                self:ApplyEngineSpriteMod()
            end
        end
    end)
    
    if not success and ConnectedItemsConfig["showDebug"] and ConnectedItemsConfig["showConsole"] then
        Isaac.ConsoleOutput("Error in CheckForNewConnections")
    end
end