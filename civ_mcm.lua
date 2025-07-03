-- ============================
-- CIV ModConfigMenu Integration
-- ============================

CIV = CIV or {}
CIV.MCM = CIV.MCM or {}

function CIV.MCM:Setup(mod)
    if not ModConfigMenu then return end
    
    local categoryName = "CIV v" .. CIV.VERSION
    
    ModConfigMenu.RemoveCategory(categoryName)
    
    -- General Settings
    ModConfigMenu.AddSpace(categoryName, "General")
    ModConfigMenu.AddText(categoryName, "General", "--- General Settings ---")
    ModConfigMenu.AddSetting(categoryName, "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["enabled"] end,
        Display = function() return "Mod Enabled: " .. (mod.Config["enabled"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["enabled"] = b end,
        Info = {"Enable or disable the Connected Items Visualizer mod."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return false end,
        Display = function() return "Reset All Settings" end,
        OnChange = function(b) 
            if b then
                CIV.Config:ResetToDefaults(mod)
                -- 즉시 false로 되돌림
                return false
            end
        end,
        Info = {"Reset all settings to their default values.", "Click to restore factory defaults."}
    })
    
    -- Number Settings
    ModConfigMenu.AddSpace(categoryName, "Number")
    ModConfigMenu.AddText(categoryName, "Number", "--- Number Display Settings ---")
    ModConfigMenu.AddSetting(categoryName, "Number", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["numberOffsetX"] end,
        Minimum = -50,
        Maximum = 50,
        Display = function() return "Number X Offset: " .. mod.Config["numberOffsetX"] end,
        OnChange = function(n) mod.Config["numberOffsetX"] = n end,
        Info = {"Horizontal position for number display.", "Negative = left, Positive = right", "Default: 0"}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Number", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["numberOffsetY"] end,
        Minimum = -50,
        Maximum = 50,
        Display = function() return "Number Y Offset: " .. mod.Config["numberOffsetY"] end,
        OnChange = function(n) mod.Config["numberOffsetY"] = n end,
        Info = {"Vertical position for number display.", "Negative = up, Positive = down", "Default: 0"}
    })
    
    -- Color Settings (미래 확장용)
    ModConfigMenu.AddSpace(categoryName, "Color")
    ModConfigMenu.AddText(categoryName, "Color", "--- Color Settings ---")
    ModConfigMenu.AddText(categoryName, "Color", "Color customization coming soon!")
    
    -- PedestalColor Settings (미래 확장용)
    ModConfigMenu.AddSpace(categoryName, "PedestalColor")
    ModConfigMenu.AddText(categoryName, "PedestalColor", "--- Pedestal Color Settings ---")
    ModConfigMenu.AddText(categoryName, "PedestalColor", "Pedestal color options coming soon!")
    
    -- Debug Settings
    ModConfigMenu.AddSpace(categoryName, "Debug")
    ModConfigMenu.AddText(categoryName, "Debug", "--- Debug Settings ---")
    ModConfigMenu.AddSetting(categoryName, "Debug", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showConsole"] end,
        Display = function() return "Console Output: " .. (mod.Config["showConsole"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showConsole"] = b end,
        Info = {"Show debug messages in game console.", "Open console with ~ key to see debug output.", "Useful for troubleshooting."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Debug", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showDebug"] end,
        Display = function() return "Debug Info: " .. (mod.Config["showDebug"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showDebug"] = b end,
        Info = {"Enable debug mode for detailed logging.", "Shows internal mod state information.", "For developers and advanced users."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Debug", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showScreenDebug"] end,
        Display = function() return "Screen Debug Info: " .. (mod.Config["showScreenDebug"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showScreenDebug"] = b end,
        Info = {"Display debug information on game screen.", "Shows mod status, frame count, connected groups."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Debug", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["debugOffsetX"] end,
        Minimum = 0,
        Maximum = 800,
        Display = function() return "Debug X Position: " .. mod.Config["debugOffsetX"] end,
        OnChange = function(n) mod.Config["debugOffsetX"] = n end,
        Info = {"Horizontal position of screen debug info.", "0 = left side, 800 = right side", "Default: 60"}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Debug", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["debugOffsetY"] end,
        Minimum = 0,
        Maximum = 400,
        Display = function() return "Debug Y Position: " .. mod.Config["debugOffsetY"] end,
        OnChange = function(n) mod.Config["debugOffsetY"] = n end,
        Info = {"Vertical position of screen debug info.", "0 = top of screen, 400 = bottom", "Default: 40"}
    })
    
    if CIV.Debug then
        CIV.Debug:Info("MCM setup complete")
    end
end 