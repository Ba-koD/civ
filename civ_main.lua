-- ============================
-- CIV Main Logic
-- ============================

local mod = RegisterMod("Connected Items Visualizer", 1)
local game = Game()

-- ============================
-- Main Functions
-- ============================

local lastEntityCount = 0
local renderCallCount = 0

local function OnNewRoom()
    if CIV.Utils:IsDeathCertificateFloor() then
        CIV.Debug:Debug(mod, "Death Certificate floor - mod disabled")
        return
    end
    
    CIV.Connection:UpdateConnectedItems(mod)
    lastEntityCount = #Isaac.GetRoomEntities()
    renderCallCount = 0
end

local function CheckForItemChanges()
    local entities = Isaac.GetRoomEntities()
    local currentEntityCount = #entities
    
    if currentEntityCount ~= lastEntityCount then
        CIV.Debug:Debug(mod, "Entity count changed: " .. lastEntityCount .. " -> " .. currentEntityCount)
        CIV.Connection:UpdateConnectedItems(mod)
        lastEntityCount = currentEntityCount
    end
end

local function OnRender()
    renderCallCount = renderCallCount + 1
    CIV.Render:RenderConnectedItems(mod)
end

local function OnUpdate()
    if not mod.Config["enabled"] then return end
    if CIV.Utils:IsDeathCertificateFloor() then return end
    
    local currentFrame = game:GetFrameCount()
    
    if currentFrame % 15 == 0 then
        CheckForItemChanges()
    end
    
    if currentFrame % 10 == 0 then
        CIV.Connection:UpdateConnectedItems(mod)
    end
end

local function OnGameStart(isSave)
    if CIV.Config:LoadSavedData(mod) then
        CIV.Debug:Print(mod, "Settings loaded")
    end
end

local function OnGameExit()
    CIV.Config:SaveData(mod)
    CIV.Debug:Print(mod, "Settings saved")
end

-- ============================
-- Initialization
-- ============================

-- 설정 초기화
CIV.Config:Init(mod)

CIV.Debug:Info("Connected Items Visualizer v" .. CIV.VERSION .. " loading...")

-- 콜백 등록
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, OnNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, OnRender)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, OnUpdate)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, OnGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, OnGameExit)

-- MCM 설정
CIV.MCM:Setup(mod)

CIV.Debug:Info("Connected Items Visualizer v" .. CIV.VERSION .. " loaded successfully!")

-- API 객체 설정
local API = {
    Version = CIV.VERSION,
    GetConnectedGroups = function() return CIV.Connection:GetConnectedGroups() end,
    GetGroupCount = function() return CIV.Connection:GetGroupCount() end,
    IsEnabled = function() return mod.Config["enabled"] end,
    Config = CIV.Config,
    Debug = CIV.Debug,
    Utils = CIV.Utils,
    Connection = CIV.Connection,
    Render = CIV.Render,
    MCM = CIV.MCM,
}

CIV = CIV or {}
CIV.API = API 