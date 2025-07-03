-- ============================
-- CIV Configuration System  
-- ============================

-- ⚠️  VERSION 업데이트 가이드  ⚠️
-- 1. metadata.xml에서 <version>값</version> 확인
-- 2. 아래 VERSION을 동일하게 변경
-- 3. 두 파일이 항상 같은 버전을 유지하세요!

local VERSION = "1.5"  -- ← metadata.xml과 동일하게 유지!

CIV = CIV or {}
CIV.Config = CIV.Config or {}
CIV.VERSION = VERSION

local DefaultConfig = {
    ["enabled"] = true,
    ["showDebug"] = false,
    ["showConsole"] = false,
    ["showScreenDebug"] = false,   -- 화면 디버그 정보 표시
    ["numberOffsetY"] = 0,
    ["numberOffsetX"] = 0,
    ["debugOffsetX"] = 60,        -- EID 피하기 위해 오른쪽으로
    ["debugOffsetY"] = 40,         -- 상단에서 약간 아래
}

-- JSON 처리
local json = nil
pcall(function() json = require("json") end)
if not json then
    json = {
        encode = function(data) return tostring(data) end,
        decode = function(str) return {} end
    }
end

CIV.JSON = json

function CIV.Config:Init(mod)
    mod.Config = {}
    for key, value in pairs(DefaultConfig) do
        mod.Config[key] = value
    end
    mod.Config.Version = CIV.VERSION
    
    Isaac.ConsoleOutput("CIV: Configuration initialized\n")
    return mod.Config
end

function CIV.Config:LoadSavedData(mod)
    if mod:HasData() then
        local data = CIV.JSON.decode(Isaac.LoadModData(mod))
        if data then
            for key, value in pairs(data) do
                if mod.Config[key] ~= nil then
                    mod.Config[key] = value
                end
            end
            return true
        end
    end
    return false
end

function CIV.Config:SaveData(mod)
    Isaac.SaveModData(mod, CIV.JSON.encode(mod.Config))
end

function CIV.Config:ResetToDefaults(mod)
    -- 설정을 기본값으로 리셋
    for key, value in pairs(DefaultConfig) do
        mod.Config[key] = value
    end
    mod.Config.Version = CIV.VERSION
    
    -- 즉시 저장
    CIV.Config:SaveData(mod)
    
    if CIV.Debug then
        CIV.Debug:Info("All settings reset to defaults")
    end
end 