-- ============================
-- CIV Debug System
-- ============================

CIV = CIV or {}
CIV.Debug = CIV.Debug or {}

function CIV.Debug:Print(mod, message)
    if mod.Config and mod.Config["showConsole"] then
        Isaac.ConsoleOutput("CIV: " .. tostring(message) .. "\n")
    end
end

function CIV.Debug:Debug(mod, message)
    if mod.Config and mod.Config["showDebug"] and mod.Config["showConsole"] then
        Isaac.ConsoleOutput("CIV-DEBUG: " .. tostring(message) .. "\n")
    end
end

function CIV.Debug:Error(message)
    Isaac.ConsoleOutput("CIV-ERROR: " .. tostring(message) .. "\n")
end

function CIV.Debug:Info(message)
    Isaac.ConsoleOutput("CIV-INFO: " .. tostring(message) .. "\n")
end 