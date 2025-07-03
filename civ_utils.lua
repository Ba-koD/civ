-- ============================
-- CIV Utility Functions
-- ============================

CIV = CIV or {}
CIV.Utils = CIV.Utils or {}

local game = Game()

CIV.Utils.NUMBER_COLORS = {
    {255, 100, 100}, -- 빨강
    {100, 255, 100}, -- 초록  
    {100, 150, 255}, -- 파랑
    {255, 255, 100}, -- 노랑
    {255, 150, 255}, -- 자홍
    {150, 255, 255}, -- 청록
    {255, 200, 100}, -- 주황
    {200, 100, 255}, -- 보라
    {100, 255, 200}, -- 연두
    {255, 100, 200}, -- 핑크
}

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
    -- Death Certificate = dimension 2, Genesis = dimension 1
    -- 특수 dimension들에서는 모드 비활성화
    return dimension == 1 or dimension == 2
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