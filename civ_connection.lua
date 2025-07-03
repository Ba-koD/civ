-- ============================
-- CIV Connection Logic
-- ============================

CIV = CIV or {}
CIV.Connection = CIV.Connection or {}

local connectedItemGroups = {}

-- group number mapping system (same as old code)
local groupNumberMapping = {}  -- OptionsPickupIndex -> display number mapping
local nextDisplayNumber = 1    -- next display number to assign
local roomKey = ""             -- current room key

local function FindConnectedItemsByOptionsIndex()
    local entities = Isaac.GetRoomEntities()
    local optionsGroups = {}
    
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
    
    -- update current room key
    local currentRoomKey = tostring(Game():GetLevel():GetCurrentRoomIndex())
    if roomKey ~= currentRoomKey then
        -- if new room, reset mapping
        roomKey = currentRoomKey
        groupNumberMapping = {}
        nextDisplayNumber = 1
    end
    
    for index, items in pairs(optionsGroups) do
        if items and #items >= 2 then
            -- map group number (new group = new number)
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