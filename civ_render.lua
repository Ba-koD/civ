-- ============================
-- CIV Rendering System
-- ============================

CIV = CIV or {}
CIV.Render = CIV.Render or {}

local game = Game()
local renderCallCount = 0

-- 기존 코드와 동일한 베이스 오프셋 (사용자 오프셋 0,0일 때 기존과 같은 위치)
local BASE_OFFSET_X = 10
local BASE_OFFSET_Y = -17  -- 양수로 변경하여 우측 하단에 표시

local function RenderNumber(number, position, mod)
    if not number or not position or not mod then return end
    
    local success, err = pcall(function()
        -- 기존 코드와 동일하게 Isaac.WorldToScreen 사용
        local screenPos = Isaac.WorldToScreen(position)
        local numberText = tostring(number)
        
        -- 사용자 설정 오프셋 + 베이스 오프셋
        local offsetX = (mod.Config["numberOffsetX"] or 0) + BASE_OFFSET_X
        local offsetY = (mod.Config["numberOffsetY"] or 0) + BASE_OFFSET_Y
        
        -- 기존 코드와 동일한 텍스트 길이 조정
        local finalOffsetX = offsetX - (#numberText - 1) * 2
        local finalOffsetY = offsetY
        
        -- 색상 정보 추출 (기존 코드 호환성을 위해)
        local colorIndex = ((number - 1) % #CIV.Utils.NUMBER_COLORS) + 1
        local color = CIV.Utils.NUMBER_COLORS[colorIndex]
        
        -- 기존 코드와 동일한 테두리 효과 (검은색)
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
                       color[1], color[2], color[3], 255)
    end)
    
    if not success and mod.Config and mod.Config["showDebug"] then
        Isaac.RenderText("Number render error: " .. tostring(err), 10, 400, 255, 0, 0, 255)
    end
end

local function RenderScreenDebugInfo(mod)
    if not mod.Config["showScreenDebug"] then return end
    
    local debugX = mod.Config["debugOffsetX"] or 400
    local debugY = mod.Config["debugOffsetY"] or 10
    local lineHeight = 15
    local yPos = debugY
    
    -- 기본 모드 상태 정보
    Isaac.RenderText("=== CIV Debug Info ===", debugX, yPos, 255, 255, 0, 255)
    yPos = yPos + lineHeight
    
    -- 모드 상태를 색상으로 구분하여 표시
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
    
    -- Death Certificate / 특수 방 체크
    local isDeathCert = CIV.Utils:IsDeathCertificateFloor()
    local deathColor = isDeathCert and {255, 100, 100} or {100, 255, 100}
    Isaac.RenderText("Death Cert Floor: " .. tostring(isDeathCert), debugX, yPos, deathColor[1], deathColor[2], deathColor[3], 255)
    yPos = yPos + lineHeight
    
    -- 모드가 비활성화되어 있으면 경고 표시
    if not mod.Config["enabled"] then
        Isaac.RenderText(">>> MOD DISABLED <<<", debugX, yPos, 255, 0, 0, 255)
        yPos = yPos + lineHeight
        return  -- 모드가 비활성화되면 나머지 정보는 표시하지 않음
    end
    
    -- 렌더링 중단 조건들 체크
    Isaac.RenderText("=== Render Conditions ===", debugX, yPos, 255, 255, 0, 255)
    yPos = yPos + lineHeight
    
    -- 각 조건별로 상태 표시
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
    
    -- 렌더링이 가능한 상태인지 표시
    local canRender = not isDeathCert and 
                     not (ModConfigMenu and ModConfigMenu.IsVisible) and 
                     not game:IsPaused() and 
                     game:GetHUD():IsVisible()
    
    local renderColor = canRender and {100, 255, 100} or {255, 100, 100}
    Isaac.RenderText("Can Render: " .. tostring(canRender), debugX, yPos, renderColor[1], renderColor[2], renderColor[3], 255)
    yPos = yPos + lineHeight
    
    -- 연결된 그룹 정보
    local connectedGroups = CIV.Connection:GetConnectedGroups()
    local groupCount = 0
    for _ in pairs(connectedGroups) do
        groupCount = groupCount + 1
    end
    
    Isaac.RenderText("Connected Groups: " .. groupCount, debugX, yPos, 100, 255, 100, 255)
    yPos = yPos + lineHeight
    
    -- 설정 값들 표시 (간략화)
    Isaac.RenderText("=== Config Values ===", debugX, yPos, 255, 255, 0, 255)
    yPos = yPos + lineHeight
    
    Isaac.RenderText("Number Offset: " .. (mod.Config["numberOffsetX"] or 0) .. ", " .. (mod.Config["numberOffsetY"] or 0), debugX, yPos, 200, 200, 200, 255)
    yPos = yPos + lineHeight
    
    Isaac.RenderText("Debug Offset: " .. (mod.Config["debugOffsetX"] or 400) .. ", " .. (mod.Config["debugOffsetY"] or 10), debugX, yPos, 200, 200, 200, 255)
    yPos = yPos + lineHeight
    
    Isaac.RenderText("Console Debug: " .. tostring(mod.Config["showDebug"]), debugX, yPos, 200, 200, 200, 255)
    yPos = yPos + lineHeight
    
    -- 그룹별 아이템 상세 정보 (최대 3개 그룹만)
    if groupCount > 0 then
        Isaac.RenderText("=== Group Details ===", debugX, yPos, 255, 255, 0, 255)
        yPos = yPos + lineHeight
        
        local groupsShown = 0
        for groupNumber, items in pairs(connectedGroups) do
            if groupsShown >= 3 then break end
            
            Isaac.RenderText("Group " .. groupNumber .. ": " .. #items .. " items", debugX, yPos, 150, 255, 150, 255)
            yPos = yPos + lineHeight
            groupsShown = groupsShown + 1
        end
    end
end

function CIV.Render:RenderConnectedItems(mod)
    -- 화면 디버그 정보는 항상 최우선으로 표시 (MCM에서도 보이도록)
    RenderScreenDebugInfo(mod)
    
    if not mod.Config["enabled"] then 
        return 
    end
    
    if CIV.Utils:IsDeathCertificateFloor() then return end
    if (ModConfigMenu and ModConfigMenu.IsVisible) or game:IsPaused() then return end
    if not game:GetHUD():IsVisible() then return end
    
    renderCallCount = renderCallCount + 1
    
    local connectedGroups = CIV.Connection:GetConnectedGroups()
    
    -- 새로운 구조: connectedGroups[groupNumber] = pickup entities 배열
    for groupNumber, items in pairs(connectedGroups) do
        if items and #items >= 2 then
            for _, pickup in ipairs(items) do
                if pickup and pickup:Exists() then
                    RenderNumber(groupNumber, pickup.Position, mod)
                end
            end
        end
    end
end 