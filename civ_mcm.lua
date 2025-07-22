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
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["displayMode"] end,
        Minimum = 1,
        Maximum = 2,
        Display = function() 
            local mode = mod.Config["displayMode"]
            if mode == 1 then
                return "Display Mode: Numbers"
            elseif mode == 2 then
                return "Display Mode: Arrows"
            else
                return "Display Mode: Unknown"
            end
        end,
        OnChange = function(n) mod.Config["displayMode"] = n end,
        Info = {"Choose how to display connected items.", "1 = Numbers only", "2 = Arrow pointers only"}
    })
    
    ModConfigMenu.AddSetting(categoryName, "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showNearbyOnly"] end,
        Display = function() return "Show Nearby Only: " .. (mod.Config["showNearbyOnly"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showNearbyOnly"] = b end,
        Info = {"When OFF, shows all connected items.", "When ON, shows only items within detection radius."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["highlighting"] end,
        Display = function() return "Highlighting: " .. (mod.Config["highlighting"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["highlighting"] = b end,
        Info = {"Enable highlighting effect (scaling) for closest group.", "When ON, closest group will appear larger.", "When OFF, all items have the same size."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "General", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["detectionRadius"] end,
        Minimum = 50,
        Maximum = 500,
        Display = function() return "Detection Radius: " .. mod.Config["detectionRadius"] end,
        OnChange = function(n) mod.Config["detectionRadius"] = n end,
        Info = {"Detection radius for nearby items (pixels).", "Only affects display when 'Show Nearby Only' is ON."}
    })
    
    ModConfigMenu.AddSpace(categoryName, "General")
    
    ModConfigMenu.AddSetting(categoryName, "General", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return false end,
        Display = function() return "Reset All Settings" end,
        OnChange = function(b) 
            if b then
                CIV.Config:ResetToDefaults(mod)
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
        Info = {"Horizontal position for number display.", "Negative = left, Positive = right"}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Number", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["numberOffsetY"] end,
        Minimum = -50,
        Maximum = 50,
        Display = function() return "Number Y Offset: " .. mod.Config["numberOffsetY"] end,
        OnChange = function(n) mod.Config["numberOffsetY"] = n end,
        Info = {"Vertical position for number display.", "Negative = up, Positive = down"}
    })
    
    -- Arrow Pointer Settings
    ModConfigMenu.AddSpace(categoryName, "Arrow")
    ModConfigMenu.AddText(categoryName, "Arrow", "--- Arrow Settings ---")
    ModConfigMenu.AddSetting(categoryName, "Arrow", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["arrowOffsetX"] end,
        Minimum = -50,
        Maximum = 50,
        Display = function() return "Arrow X Offset: " .. mod.Config["arrowOffsetX"] end,
        OnChange = function(n) mod.Config["arrowOffsetX"] = n end,
        Info = {"Horizontal position for arrows.", "Negative = left, Positive = right"}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Arrow", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["arrowOffsetY"] end,
        Minimum = -50,
        Maximum = 50,
        Display = function() return "Arrow Y Offset: " .. mod.Config["arrowOffsetY"] end,
        OnChange = function(n) mod.Config["arrowOffsetY"] = n end,
        Info = {"Vertical position for arrows.", "Negative = up, Positive = down"}
    })
    
    -- PedestalColor Settings (future extension)
    ModConfigMenu.AddSpace(categoryName, "Pedestal")
    ModConfigMenu.AddText(categoryName, "Pedestal", "--- Pedestal Settings ---")
    ModConfigMenu.AddText(categoryName, "Pedestal", "Pedestal options coming soon!")
    
    -- Debug Settings
    ModConfigMenu.AddSpace(categoryName, "Debug")
    ModConfigMenu.AddText(categoryName, "Debug", "--- Debug Settings ---")
    
    ModConfigMenu.AddSetting(categoryName, "Debug", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showScreenDebug"] end,
        Display = function() return "Show Screen Debug: " .. (mod.Config["showScreenDebug"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showScreenDebug"] = b end,
        Info = {"Show debug information on screen.", "Turn this ON to see debug details."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Debug", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showConsole"] end,
        Display = function() return "Show Console Debug: " .. (mod.Config["showConsole"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showConsole"] = b end,
        Info = {"Show debug information in console.", "Turn this ON to see debug messages in console."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Debug", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showDebug"] end,
        Display = function() return "Show Error Debug: " .. (mod.Config["showDebug"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showDebug"] = b end,
        Info = {"Show error debug information.", "Turn this ON to see error messages."}
    })
    
    -- Debug Options
    ModConfigMenu.AddSpace(categoryName, "Screen")
    ModConfigMenu.AddText(categoryName, "Screen", "--- Screen Debug Options ---")
    
    ModConfigMenu.AddSetting(categoryName, "Screen", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showDebugInfo"] end,
        Display = function() return "Show Debug Info: " .. (mod.Config["showDebugInfo"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showDebugInfo"] = b end,
        Info = {"Show CIV Debug Info section.", "Displays mod status and basic information."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Screen", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showRenderConditions"] end,
        Display = function() return "Show Render Conditions: " .. (mod.Config["showRenderConditions"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showRenderConditions"] = b end,
        Info = {"Show Render Conditions section.", "Displays rendering blocking conditions."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Screen", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showConfigValues"] end,
        Display = function() return "Show Config Values: " .. (mod.Config["showConfigValues"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showConfigValues"] = b end,
        Info = {"Show Config Values section.", "Displays current configuration settings."}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Screen", {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function() return mod.Config["showGroupDetails"] end,
        Display = function() return "Show Group Details: " .. (mod.Config["showGroupDetails"] and "ON" or "OFF") end,
        OnChange = function(b) mod.Config["showGroupDetails"] = b end,
        Info = {"Show Group Details section.", "Displays connected group information."}
    })
    
    ModConfigMenu.AddSpace(categoryName, "Screen")
    ModConfigMenu.AddText(categoryName, "Screen", "Note: Screen Debug must be ON")
    
    ModConfigMenu.AddSetting(categoryName, "Screen", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["debugOffsetX"] end,
        Minimum = 0,
        Maximum = 800,
        Display = function() return "Debug X Offset: " .. mod.Config["debugOffsetX"] end,
        OnChange = function(n) mod.Config["debugOffsetX"] = n end,
        Info = {"Horizontal position of screen debug info.", "0 = left side, 800 = right side"}
    })
    
    ModConfigMenu.AddSetting(categoryName, "Screen", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return mod.Config["debugOffsetY"] end,
        Minimum = 0,
        Maximum = 400,
        Display = function() return "Debug Y Offset: " .. mod.Config["debugOffsetY"] end,
        OnChange = function(n) mod.Config["debugOffsetY"] = n end,
        Info = {"Vertical position of screen debug info.", "0 = top of screen, 400 = bottom"}
    })
    
    if CIV.Debug then
        CIV.Debug:Info("MCM setup complete")
    end
end 