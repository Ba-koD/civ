-- ============================
-- CIV Utility Functions
-- ============================

CIV = CIV or {}
CIV.Utils = CIV.Utils or {}

local game = Game()

local function GetDimension(room)
    local success, result = pcall(function()
        local level = game:GetLevel()
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

function CIV.Utils:IsDeathCertificateFloor()
    local dimension = GetDimension()
    return dimension == 2
end

function CIV.Utils:GetPedestalItems()
    local pedestalItems = {}
    local entities = Isaac.GetRoomEntities()
    
    for i = 1, #entities do
        local entity = entities[i]
        if entity.Type == EntityType.ENTITY_PICKUP and 
           entity.Variant == PickupVariant.PICKUP_COLLECTIBLE and
           entity.SubType > 0 then
            table.insert(pedestalItems, entity)
        end
    end
    
    return pedestalItems
end 