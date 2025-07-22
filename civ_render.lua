-- ============================
-- CIV Rendering System
-- ============================

CIV = CIV or {}
CIV.Render = CIV.Render or {}

local game = Game()
local renderCallCount = 0

-- Rendering Offsets
local BASE_OFFSET_X = 10
local BASE_OFFSET_Y = -17
local ARROW_BASE_OFFSET_X = 8
local ARROW_BASE_OFFSET_Y = -40

-- Scale Animation System
local itemScales = {}
local SCALE_SPEED = 0.05
local MAX_SCALE = 2.0
local MIN_SCALE = 1.0

-- MCM Preview Sprites are now created locally in the function to avoid state issues.

-- MCM Preview sprite (persistent for proper loading)
local mcmItemSprite = nil
local mcmPedestalSprite = nil

-- ============================
-- Utility Functions
-- ============================

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function getItemKey(pickup)
    if not pickup or not pickup:Exists() then
        return "invalid_pickup"
    end
    
    local pos = pickup.Position
    local posKey = string.format("%.1f_%.1f", pos.X, pos.Y)
    local seed = pickup.InitSeed or 0
    local subtype = pickup.SubType or 0
    local variant = pickup.Variant or 0
    local type = pickup.Type or 0
    
    return seed .. "_" .. type .. "_" .. variant .. "_" .. subtype .. "_" .. posKey
end

local function updateItemScale(pickup, isNearby)
    local key = getItemKey(pickup)
    local targetScale = isNearby and MAX_SCALE or MIN_SCALE
    
    if not itemScales[key] then
        itemScales[key] = MIN_SCALE
    end
    
    itemScales[key] = lerp(itemScales[key], targetScale, SCALE_SPEED)
    return itemScales[key]
end

-- Safe Name field extraction function
local function getName(val)
    if type(val) == "table" and val.Name then
        return val.Name
    end
    return tostring(val)
end

-- ============================
-- Rendering Functions
-- ============================

local function RenderNumber(number, position, mod, pickup, forceScreenPos)
    if not number or (not position and not forceScreenPos) or not mod then return end
    
    local success, err = pcall(function()
        local screenPos = forceScreenPos or Isaac.WorldToScreen(position)
        local numberText = tostring(number)
        
        local offsetX = mod.Config["numberOffsetX"] + BASE_OFFSET_X
        local offsetY = mod.Config["numberOffsetY"] + BASE_OFFSET_Y
        local finalOffsetX = offsetX - (#numberText - 1) * 2
        local finalOffsetY = offsetY
        
        -- Scale calculation
        local scale = MIN_SCALE
        local key = "no_pickup"
        if pickup then
            key = getItemKey(pickup)
            local foundScale = itemScales[key]
            if foundScale then
                scale = foundScale
            end
            
            if mod.Config["showDebug"] and renderCallCount % 60 == 0 and scale > MIN_SCALE then
                Isaac.DebugString("CIV RenderNumber: key=" .. key .. ", scale=" .. string.format("%.2f", scale) .. ", number=" .. numberText)
            end
        end
        
        local scaleX = scale * 0.8
        local scaleY = scale * 0.8
        
        -- Glow effect for highlighted items
        if scale > MIN_SCALE then
            local glowIntensity = (scale - MIN_SCALE) / (MAX_SCALE - MIN_SCALE)
            local glowAlpha = glowIntensity * 0.4
            
            Isaac.RenderScaledText(numberText, 
                                 screenPos.X + finalOffsetX, 
                                 screenPos.Y + finalOffsetY, 
                                 scaleX + 0.2, scaleY + 0.2, 
                                 1.0, 1.0, 1.0, glowAlpha)
        end
        
        -- Black border effect
        local borderScale = scaleX * 0.98
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    Isaac.RenderScaledText(numberText, 
                                         screenPos.X + finalOffsetX + dx, 
                                         screenPos.Y + finalOffsetY + dy,
                                         borderScale, borderScale,
                                         0.0, 0.0, 0.0, 0.7)
                end
            end
        end
        
        -- Main number text
        Isaac.RenderScaledText(numberText, 
                             screenPos.X + finalOffsetX, 
                             screenPos.Y + finalOffsetY,
                             scaleX, scaleY,
                             1.0, 1.0, 1.0, 1.0)
    end)
    
    if not success and mod.Config and mod.Config["showDebug"] then
        Isaac.RenderText("Number render error: " .. tostring(err), 10, 400, 255, 0, 0, 255)
    end
end

local function RenderArrowPointer(groupNumber, position, mod, itemIndex, totalItems, pickup, forceScreenPos)
    if not groupNumber or (not position and not forceScreenPos) then return end
    
    local success, err = pcall(function()
        local screenPos = forceScreenPos or Isaac.WorldToScreen(position)
        
        local arrowOffsetX = mod.Config["arrowOffsetX"] + ARROW_BASE_OFFSET_X
        local arrowOffsetY = mod.Config["arrowOffsetY"] + ARROW_BASE_OFFSET_Y
        local arrowX = screenPos.X + arrowOffsetX
        local arrowY = screenPos.Y + arrowOffsetY
        local arrowChar = "↙"
        
        -- Scale calculation
        local scale = MIN_SCALE
        local key = "no_pickup"
        if pickup then
            key = getItemKey(pickup)
            local foundScale = itemScales[key]
            if foundScale then
                scale = foundScale
            end
            
            if mod.Config["showDebug"] and renderCallCount % 60 == 0 and scale > MIN_SCALE then
                Isaac.DebugString("CIV RenderArrow: key=" .. key .. ", scale=" .. string.format("%.2f", scale) .. ", group=" .. groupNumber)
            end
        end
        
        local scaleX = scale * 0.8
        local scaleY = scale * 0.8
        
        -- Glow effect for highlighted items
        if scale > MIN_SCALE then
            local glowIntensity = (scale - MIN_SCALE) / (MAX_SCALE - MIN_SCALE)
            local glowAlpha = glowIntensity * 0.4
            
            Isaac.RenderScaledText(arrowChar, 
                                 arrowX, arrowY, 
                                 scaleX + 0.2, scaleY + 0.2, 
                                 1.0, 1.0, 1.0, glowAlpha)
        end
        
        -- Main arrow
        Isaac.RenderScaledText(arrowChar, 
                             arrowX, arrowY, 
                             scaleX, scaleY, 
                             1.0, 1.0, 1.0, 1.0)
    end)
    
    if not success and mod.Config and mod.Config["showDebug"] then
        Isaac.RenderText("Arrow render error: " .. tostring(err), 10, 420, 255, 0, 0, 255)
    end
end

-- ============================
-- MCM Preview Rendering
-- ============================

function CIV.Render:RenderMCMPreview(mod, previewMode)
    if not ModConfigMenu then return end
    if not mod.Config["enabled"] then return end
    if not ModConfigMenu.IsVisible then return end

    -- previewMode: 1(Number), 2(Arrow)

    -- Initialize sprites if not already done
    if not mcmItemSprite then
        mcmItemSprite = Sprite()
        mcmItemSprite:Load("gfx/005.100_collectible.anm2", true)

        mcmPedestalSprite = Sprite()
        mcmPedestalSprite:Load("gfx/005.100_collectible.anm2", true)
        mcmPedestalSprite:ReplaceSpritesheet(1, "gfx/items/collectibles/collectibles_098_thenegative.png")
        mcmPedestalSprite:LoadGraphics()
        mcmPedestalSprite:SetFrame("Idle", 0)
    end

    local previewX = Isaac.GetScreenWidth() * 0.6
    local previewY = Isaac.GetScreenHeight() * 0.65

    Isaac.RenderText("Preview:", previewX - 25, previewY - 50, 255, 255, 255, 255)

    local pedestalPos = Vector(previewX, previewY + 20)
    mcmPedestalSprite.Color = Color(0.3, 0.3, 0.3, 1)
    mcmPedestalSprite.Scale = Vector(0.8, 0.8)
    mcmPedestalSprite:Render(pedestalPos, Vector(0,0), Vector(0,0))

    local itemConfig = Isaac.GetItemConfig():GetCollectible(12)
    if itemConfig and itemConfig.GfxFileName ~= "" then
        mcmItemSprite:ReplaceSpritesheet(1, itemConfig.GfxFileName)
        mcmItemSprite:LoadGraphics()
        mcmItemSprite:SetFrame("Idle", 0)

        local itemPos = Vector(previewX, previewY)
        mcmItemSprite:Render(itemPos, Vector(0,0), Vector(0,0))

        local currentOffsetX, currentOffsetY

        if previewMode == 1 then
            local numberText = "1"
            local offsetX = mod.Config["numberOffsetX"] + BASE_OFFSET_X
            local offsetY = mod.Config["numberOffsetY"] + BASE_OFFSET_Y
            local finalOffsetX = offsetX - (#numberText - 1) * 2
            local finalOffsetY = offsetY

            currentOffsetX = mod.Config["numberOffsetX"]
            currentOffsetY = mod.Config["numberOffsetY"]

            local screenX = previewX + finalOffsetX
            local screenY = previewY + finalOffsetY

            for dx = -1, 1 do
                for dy = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        Isaac.RenderScaledText(numberText, 
                                             screenX + dx, 
                                             screenY + dy,
                                             0.8 * 0.98, 0.8 * 0.98,
                                             0.0, 0.0, 0.0, 0.7)
                    end
                end
            end

            Isaac.RenderScaledText(numberText, 
                                 screenX, 
                                 screenY,
                                 0.8, 0.8,
                                 1.0, 1.0, 1.0, 1.0)

        elseif previewMode == 2 then
            local arrowOffsetX = mod.Config["arrowOffsetX"] + ARROW_BASE_OFFSET_X
            local arrowOffsetY = mod.Config["arrowOffsetY"] + ARROW_BASE_OFFSET_Y
            local arrowX = previewX + arrowOffsetX
            local arrowY = previewY + arrowOffsetY
            local arrowChar = "↙"

            currentOffsetX = mod.Config["arrowOffsetX"]
            currentOffsetY = mod.Config["arrowOffsetY"]

            Isaac.RenderScaledText(arrowChar, 
                                 arrowX, arrowY, 
                                 0.8, 0.8, 
                                 1.0, 1.0, 1.0, 1.0)
        end

        local offsetText = string.format("X: %d, Y: %d", currentOffsetX, currentOffsetY)
        Isaac.RenderText(offsetText, previewX - 30, previewY, 200, 200, 200, 255)
    end
end

-- ============================
-- Debug Information Rendering
-- ============================

local function RenderScreenDebugInfo(mod)
    if not mod.Config["showScreenDebug"] then return end
    
    local debugX = mod.Config["debugOffsetX"]
    local debugY = mod.Config["debugOffsetY"]
    local lineHeight = 15
    local yPos = debugY
    
    -- Debug Info Section
    if mod.Config["showDebugInfo"] then
        Isaac.RenderText("=== CIV Debug Info ===", debugX, yPos, 255, 255, 0, 255)
        yPos = yPos + lineHeight
        
        local enabledColor = mod.Config["enabled"] and {255, 255, 255} or {255, 100, 100}
        Isaac.RenderText("Enabled: " .. tostring(mod.Config["enabled"]), debugX, yPos, enabledColor[1], enabledColor[2], enabledColor[3], 255)
        yPos = yPos + lineHeight

        Isaac.RenderText("MCM Visible: " .. tostring(ModConfigMenu and ModConfigMenu.IsVisible), debugX, yPos, 255, 255, 255, 255)
        yPos = yPos + lineHeight
        
        Isaac.RenderText("Game Paused: " .. tostring(game:IsPaused()), debugX, yPos, 255, 255, 255, 255)
        yPos = yPos + lineHeight
        
        Isaac.RenderText("HUD Visible: " .. tostring(game:GetHUD():IsVisible()), debugX, yPos, 255, 255, 255, 255)
        yPos = yPos + lineHeight
        
        Isaac.RenderText("Render Count: " .. renderCallCount, debugX, yPos, 255, 255, 255, 255)
        yPos = yPos + lineHeight
        
        Isaac.RenderText("Frame: " .. (game:GetFrameCount() % 1000), debugX, yPos, 100, 100, 255, 255)
        yPos = yPos + lineHeight
        
        local isDeathCert = CIV.Utils:IsDeathCertificateFloor()
        local deathColor = isDeathCert and {255, 100, 100} or {100, 255, 100}
        Isaac.RenderText("Death Cert Floor: " .. tostring(isDeathCert), debugX, yPos, deathColor[1], deathColor[2], deathColor[3], 255)
        yPos = yPos + lineHeight
        
        if not mod.Config["enabled"] then
            Isaac.RenderText(">>> MOD DISABLED <<<", debugX, yPos, 255, 0, 0, 255)
            yPos = yPos + lineHeight
            return
        end
        
        yPos = yPos + lineHeight
    end
    
    -- Render Conditions Section
    if mod.Config["showRenderConditions"] then
        Isaac.RenderText("=== Render Conditions ===", debugX, yPos, 255, 255, 0, 255)
        yPos = yPos + lineHeight
        
        if ModConfigMenu and ModConfigMenu.IsVisible then
            local catName, subName, optName = nil, nil, nil
            if ModConfigMenu.GetCurrentFocus then
                local focus = ModConfigMenu.GetCurrentFocus()
                catName = getName(focus.category)
                subName = getName(focus.subcategory)
                optName = focus.option
            end

            local optText = "nil"
            if optName then
                if type(optName) == "table" and type(optName.Display) == "function" then
                    optText = optName:Display()
                elseif type(optName) == "table" and optName.Name then
                    optText = optName.Name
                else
                    optText = tostring(optName)
                end
            end
            Isaac.RenderText("MCM Focus: " .. tostring(catName) .. " / " .. tostring(subName), debugX, yPos, 200, 200, 255, 255)
            yPos = yPos + lineHeight
            Isaac.RenderText("MCM Option: " .. optText, debugX, yPos, 200, 200, 255, 255)
            yPos = yPos + lineHeight
        end
        
        local isDeathCert = CIV.Utils:IsDeathCertificateFloor()
        if isDeathCert then
            Isaac.RenderText("BLOCKED: Special Floor", debugX, yPos, 255, 0, 0, 255)
            yPos = yPos + lineHeight
        end
        
        if (ModConfigMenu and ModConfigMenu.IsVisible) then
            Isaac.RenderText("BLOCKED: MCM Open", debugX, yPos, 255, 150, 0, 255)
            yPos = yPos + lineHeight
        end
        
        if game:IsPaused() then
            Isaac.RenderText("BLOCKED: Game Paused", debugX, yPos, 255, 150, 0, 255)
            yPos = yPos + lineHeight
        end
        
        if not game:GetHUD():IsVisible() then
            Isaac.RenderText("BLOCKED: HUD Hidden", debugX, yPos, 255, 150, 0, 255)
            yPos = yPos + lineHeight
        end
        
        local canRender = not isDeathCert and 
                         not (ModConfigMenu and ModConfigMenu.IsVisible) and 
                         not game:IsPaused() and 
                         game:GetHUD():IsVisible()
        
        local renderColor = canRender and {100, 255, 100} or {255, 100, 100}
        Isaac.RenderText("Can Render: " .. tostring(canRender), debugX, yPos, renderColor[1], renderColor[2], renderColor[3], 255)
        yPos = yPos + lineHeight
        
        -- Connection and scale information
        local connectedGroups = CIV.Connection:GetConnectedGroups()
        local groupCount = 0
        for _ in pairs(connectedGroups) do
            groupCount = groupCount + 1
        end
        
        Isaac.RenderText("Connected Groups: " .. groupCount, debugX, yPos, 100, 255, 100, 255)
        yPos = yPos + lineHeight
        
        local scaledItemCount = 0
        for key, scale in pairs(itemScales) do
            if scale > MIN_SCALE then
                scaledItemCount = scaledItemCount + 1
            end
        end
        
        local actualClosestGroup = nil
        local player = Isaac.GetPlayer(0)
        local playerPos = player and player.Position or nil
        
        if playerPos then
            local closestDistance = math.huge
            for groupNumber, items in pairs(connectedGroups) do
                if items and #items >= 2 then
                    for _, pickup in ipairs(items) do
                        if pickup and pickup:Exists() and not pickup:IsDead() and not pickup:IsShopItem() then
                            local distance = playerPos:Distance(pickup.Position)
                            if distance <= mod.Config["detectionRadius"] and distance < closestDistance then
                                closestDistance = distance
                                actualClosestGroup = groupNumber
                            end
                        end
                    end
                end
            end
        end
        
        Isaac.RenderText("Scaled Items: " .. scaledItemCount, debugX, yPos, 100, 255, 255, 255)
        yPos = yPos + lineHeight
        
        Isaac.RenderText("Highlighted Group: " .. (actualClosestGroup or "None"), debugX, yPos, 255, 255, 100, 255)
        yPos = yPos + lineHeight
        
        local maxScaleCount = 0
        local minScaleCount = 0
        local totalItemScales = 0
        local totalConnectedItems = 0
        
        for key, scale in pairs(itemScales) do
            totalItemScales = totalItemScales + 1
            if scale >= MAX_SCALE * 0.9 then
                maxScaleCount = maxScaleCount + 1
            elseif scale <= MIN_SCALE * 1.1 then
                minScaleCount = minScaleCount + 1
            end
        end
        
        for groupNumber, items in pairs(connectedGroups) do
            if items and #items >= 2 then
                totalConnectedItems = totalConnectedItems + #items
            end
        end
        
        Isaac.RenderText("MAX Scaled: " .. maxScaleCount .. " | MIN Scaled: " .. minScaleCount, debugX, yPos, 255, 200, 100, 255)
        yPos = yPos + lineHeight
        
        Isaac.RenderText("Table Size: " .. totalItemScales .. " | Total Items: " .. totalConnectedItems, debugX, yPos, 150, 150, 255, 255)
        yPos = yPos + lineHeight
        
        yPos = yPos + lineHeight
    end
    
    -- Config Values Section
    if mod.Config["showConfigValues"] then
        Isaac.RenderText("=== Config Values ===", debugX, yPos, 255, 255, 0, 255)
        yPos = yPos + lineHeight
        
        local displayModeText = "Unknown"
        if mod.Config["displayMode"] == 1 then
            displayModeText = "Numbers Only"
        elseif mod.Config["displayMode"] == 2 then
            displayModeText = "Arrows Only"
        end
        Isaac.RenderText("Display Mode: " .. displayModeText .. " (" .. mod.Config["displayMode"] .. ")", debugX, yPos, 200, 200, 200, 255)
        yPos = yPos + lineHeight

        Isaac.RenderText("Show Nearby Only: " .. tostring(mod.Config["showNearbyOnly"]), debugX, yPos, 200, 200, 200, 255)
        yPos = yPos + lineHeight

        Isaac.RenderText("Highlighting: " .. tostring(mod.Config["highlighting"]), debugX, yPos, 200, 200, 200, 255)
        yPos = yPos + lineHeight

        Isaac.RenderText("Detection Radius: " .. mod.Config["detectionRadius"], debugX, yPos, 200, 200, 200, 255)
        yPos = yPos + lineHeight

        Isaac.RenderText("Number Offset: " .. mod.Config["numberOffsetX"] .. ", " .. mod.Config["numberOffsetY"], debugX, yPos, 200, 200, 200, 255)
        yPos = yPos + lineHeight

        Isaac.RenderText("Arrow Offset: " .. mod.Config["arrowOffsetX"] .. ", " .. mod.Config["arrowOffsetY"], debugX, yPos, 200, 200, 200, 255)
        yPos = yPos + lineHeight
        
        Isaac.RenderText("Debug Offset: " .. mod.Config["debugOffsetX"] .. ", " .. mod.Config["debugOffsetY"], debugX, yPos, 200, 200, 200, 255)
        yPos = yPos + lineHeight
        
        Isaac.RenderText("Console Debug: " .. tostring(mod.Config["showDebug"]), debugX, yPos, 200, 200, 200, 255)
        yPos = yPos + lineHeight
        
        yPos = yPos + lineHeight
    end
    
    -- Group Details Section
    if mod.Config["showGroupDetails"] then
        local connectedGroups = CIV.Connection:GetConnectedGroups()
        local groupCount = 0
        for _ in pairs(connectedGroups) do
            groupCount = groupCount + 1
        end
        
        if groupCount > 0 then
            Isaac.RenderText("=== Group Details ===", debugX, yPos, 255, 255, 0, 255)
            yPos = yPos + lineHeight
            
            local groupsShown = 0
            for groupNumber, items in pairs(connectedGroups) do
                if groupsShown >= 5 then
                    Isaac.RenderText("... and more", debugX, yPos, 150, 150, 150, 255)
                    yPos = yPos + lineHeight
                    break
                end
                
                Isaac.RenderText("Group " .. groupNumber .. ": " .. #items .. " items", debugX, yPos, 150, 255, 150, 255)
                yPos = yPos + lineHeight
                groupsShown = groupsShown + 1
            end
        end
    end
end

-- ============================
-- Main Rendering Function
-- ============================

function CIV.Render:RenderConnectedItems(mod)
    if not mod.Config["enabled"] then 
        return 
    end
    
    RenderScreenDebugInfo(mod)

    -- Handle MCM preview separately
    if ModConfigMenu and ModConfigMenu.IsVisible then
        local catName, subName, optName = nil, nil, nil
        if ModConfigMenu.GetCurrentFocus then
            local focus = ModConfigMenu.GetCurrentFocus()
            catName = getName(focus.category)
            subName = getName(focus.subcategory)
            optName = focus.option
        end
        local civCategoryName = "CIV v" .. (CIV.VERSION or "?")
        local catNameStr = tostring(catName)
        local civCategoryNameStr = tostring(civCategoryName)
        local subNameStr = tostring(subName)

        if catNameStr == civCategoryNameStr and (subNameStr == "Number" or subNameStr == "Arrow") then
            local previewMode = subNameStr == "Number" and 1 or 2
            CIV.Render:RenderMCMPreview(mod, previewMode)
            return
        end
        return
    end
    
    if CIV.Utils:IsDeathCertificateFloor() then return end
    if game:IsPaused() then return end
    if not game:GetHUD():IsVisible() then return end
    
    renderCallCount = renderCallCount + 1
    
    local connectedGroups = CIV.Connection:GetConnectedGroups()
    local displayMode = mod.Config["displayMode"]
    local player = Isaac.GetPlayer(0)
    local playerPos = player and player.Position or nil
    
    -- Register all connected items and reset scales
    local totalRegistered = 0
    local debugKeys = {}
    
    for groupNumber, items in pairs(connectedGroups) do
        if items and #items >= 2 then
            for _, pickup in ipairs(items) do
                if pickup and pickup:Exists() and not pickup:IsDead() and not pickup:IsShopItem() then
                    local key = getItemKey(pickup)
                    itemScales[key] = MIN_SCALE
                    totalRegistered = totalRegistered + 1
                    table.insert(debugKeys, "G" .. groupNumber .. ":" .. key)
                end
            end
        end
    end
    
    -- Find closest group (needed for both highlighting and showNearbyOnly)
    local closestGroup = nil
    local closestDistance = math.huge
    local highlightedCount = 0
    
    if playerPos then
        for groupNumber, items in pairs(connectedGroups) do
            if items and #items >= 2 then
                for _, pickup in ipairs(items) do
                    if pickup and pickup:Exists() and not pickup:IsDead() and not pickup:IsShopItem() then
                        local distance = playerPos:Distance(pickup.Position)
                        if distance <= mod.Config["detectionRadius"] and distance < closestDistance then
                            closestDistance = distance
                            closestGroup = groupNumber
                        end
                    end
                end
            end
        end
        
        -- Apply highlighting only if highlighting is enabled
        if mod.Config["highlighting"] and closestGroup then
            local selectedItems = connectedGroups[closestGroup]
            if selectedItems then
                for _, pickup in ipairs(selectedItems) do
                    if pickup and pickup:Exists() and not pickup:IsDead() and not pickup:IsShopItem() then
                        local key = getItemKey(pickup)
                        itemScales[key] = MAX_SCALE
                        highlightedCount = highlightedCount + 1
                    end
                end
            end
        end
    end
    
    -- Debug logging
    if mod.Config["showDebug"] then
        Isaac.DebugString("CIV: Registered " .. totalRegistered .. " items, Highlighted " .. highlightedCount .. " items")
        Isaac.DebugString("CIV: Highlighting " .. (mod.Config["highlighting"] and "ENABLED" or "DISABLED"))
        if #debugKeys <= 5 then
            Isaac.DebugString("CIV: Keys: " .. table.concat(debugKeys, ", "))
        else
            Isaac.DebugString("CIV: Keys (first 5): " .. table.concat({debugKeys[1], debugKeys[2], debugKeys[3], debugKeys[4], debugKeys[5]}, ", ") .. "...")
        end
        
        local scaleDistribution = {min = 0, max = 0, other = 0}
        for key, scale in pairs(itemScales) do
            if scale <= MIN_SCALE * 1.1 then
                scaleDistribution.min = scaleDistribution.min + 1
            elseif scale >= MAX_SCALE * 0.9 then
                scaleDistribution.max = scaleDistribution.max + 1
            else
                scaleDistribution.other = scaleDistribution.other + 1
            end
        end
        Isaac.DebugString("CIV: Scale distribution - MIN: " .. scaleDistribution.min .. ", MAX: " .. scaleDistribution.max .. ", OTHER: " .. scaleDistribution.other)
    end
    
    -- Render items
    if mod.Config["showNearbyOnly"] then
        -- Show only closest group
        if closestGroup then
            local groupItems = connectedGroups[closestGroup]
            if groupItems then
                for _, pickup in ipairs(groupItems) do
                    if pickup and pickup:Exists() and not pickup:IsDead() and not pickup:IsShopItem() then
                        if displayMode == 1 then
                            RenderNumber(closestGroup, pickup.Position, mod, pickup)
                        elseif displayMode == 2 then
                            RenderArrowPointer(closestGroup, pickup.Position, mod, 0, #groupItems, pickup)
                        end
                    end
                end
            end
        end
    else
        -- Show all groups with highlighting
        for groupNumber, items in pairs(connectedGroups) do
            if items and #items >= 2 then
                local totalItems = #items
                
                for itemIndex, pickup in ipairs(items) do
                    if pickup and pickup:Exists() and not pickup:IsDead() and not pickup:IsShopItem() then
                        if displayMode == 1 then
                            RenderNumber(groupNumber, pickup.Position, mod, pickup)
                        elseif displayMode == 2 then
                            RenderArrowPointer(groupNumber, pickup.Position, mod, itemIndex - 1, totalItems, pickup)
                        end
                    end
                end
            end
        end
    end
    
    -- Cleanup unused scale data
    if renderCallCount % 300 == 0 then
        local currentItems = {}
        for groupNumber, items in pairs(connectedGroups) do
            if items then
                for _, pickup in ipairs(items) do
                    if pickup and pickup:Exists() and not pickup:IsDead() then
                        currentItems[getItemKey(pickup)] = true
                    end
                end
            end
        end
        
        for key in pairs(itemScales) do
            if not currentItems[key] then
                itemScales[key] = nil
            end
        end
    end
end 