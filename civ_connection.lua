-- ============================
-- CIV Connection Logic
-- ============================

CIV = CIV or {}
CIV.Connection = CIV.Connection or {}

local connectedItemGroups = {}

-- 그룹 번호 매핑 시스템 (기존 코드와 동일)
local groupNumberMapping = {}  -- OptionsPickupIndex -> 표시번호 매핑
local nextDisplayNumber = 1    -- 다음에 할당할 표시번호
local roomKey = ""             -- 현재 방 키

local function FindConnectedItemsByOptionsIndex()
    local entities = Isaac.GetRoomEntities()
    local optionsGroups = {}
    
    -- OptionsPickupIndex로 그룹화 (기존 996줄 코드와 동일)
    for _, entity in ipairs(entities) do
        if entity.Type == EntityType.ENTITY_PICKUP and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            local pickup = entity:ToPickup()
            if pickup and pickup.OptionsPickupIndex and pickup.OptionsPickupIndex ~= 0 then
                local index = pickup.OptionsPickupIndex
                if not optionsGroups[index] then
                    optionsGroups[index] = {}
                end
                table.insert(optionsGroups[index], pickup)
            end
        end
    end
    
    return optionsGroups
end

function CIV.Connection:UpdateConnectedItems(mod)
    local optionsGroups = FindConnectedItemsByOptionsIndex()
    connectedItemGroups = {}
    
    if not optionsGroups then
        return
    end
    
    -- 현재 방 키 업데이트 (기존 코드와 동일)
    local currentRoomKey = tostring(Game():GetLevel():GetCurrentRoomIndex())
    if roomKey ~= currentRoomKey then
        -- 새로운 방에 들어갔으면 매핑 초기화
        roomKey = currentRoomKey
        groupNumberMapping = {}
        nextDisplayNumber = 1
    end
    
    for index, items in pairs(optionsGroups) do
        if items and #items >= 2 then
            -- 그룹 번호 매핑 (새로운 그룹이면 새 번호 할당)
            if not groupNumberMapping[index] then
                groupNumberMapping[index] = nextDisplayNumber
                nextDisplayNumber = nextDisplayNumber + 1
            end
            local displayNumber = groupNumberMapping[index]
            
            connectedItemGroups[displayNumber] = items
            
            if CIV.Debug then
                CIV.Debug:Debug(mod, "Found connected group " .. displayNumber .. " with " .. #items .. " items (OptionsIndex: " .. index .. ")")
            end
        end
    end
    
    if CIV.Debug then
        CIV.Debug:Debug(mod, "Found " .. (#connectedItemGroups) .. " connected groups")
    end
end

function CIV.Connection:GetConnectedGroups()
    return connectedItemGroups
end

function CIV.Connection:GetGroupCount()
    local count = 0
    for _ in pairs(connectedItemGroups) do
        count = count + 1
    end
    return count
end 