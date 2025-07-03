-- ============================
-- CIV Configuration System  
-- ============================

-- ⚠️  VERSION update guide  ⚠️
-- 1. Check <version> value in metadata.xml
-- 2. Update VERSION below to match
-- 3. Keep both files at the same version!

local VERSION = "1.6"

CIV = CIV or {}
CIV.Config = CIV.Config or {}
CIV.VERSION = VERSION

local DefaultConfig = {
    -- general
    ["enabled"] = true,
    ["displayMode"] = 1,           -- 1=number, 2=arrow
    ["showNearbyOnly"] = true,     -- show nearby only
    ["highlighting"] = false,       -- enable highlighting (scaling effect)
    ["detectionRadius"] = 100,     -- detection radius (pixels)

    -- number display settings
    ["numberOffsetY"] = 0,
    ["numberOffsetX"] = 0,
    
    -- arrow display settings
    ["arrowOffsetX"] = 0,          -- arrow X offset 
    ["arrowOffsetY"] = 0,          -- arrow Y offset 
    
    -- debug
    ["showDebug"] = false,
    ["showConsole"] = false,
    ["showScreenDebug"] = false,   -- screen debug info
    
    -- screen debug
    ["showDebugInfo"] = true,      -- CIV Debug Info 섹션
    ["showRenderConditions"] = true, -- Render Conditions 섹션
    ["showConfigValues"] = true,   -- Config Values 섹션
    ["showGroupDetails"] = true,   -- Group Details 섹션

    ["debugOffsetX"] = 60,        -- avoid EID
    ["debugOffsetY"] = 40,         -- slightly below top
}

-- JSON processing
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
    for key, value in pairs(DefaultConfig) do
        mod.Config[key] = value
    end
    mod.Config.Version = CIV.VERSION
    
    CIV.Config:SaveData(mod)
    
    if CIV.Debug then
        CIV.Debug:Info("All settings reset to defaults")
    end
end 