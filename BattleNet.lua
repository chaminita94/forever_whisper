local _, NS = ...
local roster, loaded, disconnected = {}, false, false

function NS.BNetKey(tag)
    if type(tag) ~= "string" or not tag:match("^.+#%d+$") then return nil end
    return "bnet:" .. tag:lower()
end

function NS.InvalidateBNet(offline)
    roster, loaded, disconnected = {}, false, not not offline
end

local function connected()
    return not disconnected and (not BNConnected or BNConnected())
end

local function remember(info, id)
    local key = info and NS.BNetKey(info.battleTag)
    id = info and (info.bnetAccountID or id)
    if not key or type(id) ~= "number" or id <= 0 then return nil end
    local record = { id = id, info = info, key = key }
    roster[key] = record
    return record
end

function NS.ResolveBNetID(id)
    if not connected() or type(id) ~= "number" or id <= 0 then return nil end
    if C_BattleNet and C_BattleNet.GetAccountInfoByID then
        return remember(C_BattleNet.GetAccountInfoByID(id), id)
    end
end

local function loadRoster()
    loaded = true
    if not connected() or not BNGetNumFriends or not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then return end
    for i = 1, BNGetNumFriends() do remember(C_BattleNet.GetFriendAccountInfo(i)) end
end

function NS.FindBNet(tag)
    if not loaded then loadRoster() end
    return connected() and roster[NS.BNetKey(tag)] or nil
end

function NS.BNetPresence(c)
    if not connected() then return false, "Battle.net" end
    local record = NS.FindBNet(c.battleTag)
    if not record then return nil, "Battle.net" end
    local info, game = record.info, record.info.gameAccountInfo
    local online
    if type(info.isOnline) == "boolean" then online = info.isOnline end
    if online == nil and game and type(game.isOnline) == "boolean" then online = game.isOnline end
    local area = game and (game.areaName or game.richPresence)
    return online, "Battle.net", area
end

-- Account IDs are session-local. Validate the tag again immediately before sending.
local function recipient(c)
    local record = NS.FindBNet(c.battleTag)
    local live = record and NS.ResolveBNetID(record.id)
    if not live or live.key ~= NS.BNetKey(c.battleTag) then
        NS.InvalidateBNet(false)
        record = NS.FindBNet(c.battleTag)
        live = record and NS.ResolveBNetID(record.id)
    end
    if live and live.key == NS.BNetKey(c.battleTag) then return live end
end

function NS.SendBNet(c, text)
    local record = recipient(c)
    if not record then return false, "Battle.net recipient unavailable. Your draft was kept." end
    local send = C_BattleNet and C_BattleNet.SendWhisper or BNSendWhisper
    if not send then return false, "Battle.net whispers are unavailable on this client. Your draft was kept." end
    local ok, result = pcall(send, record.id, text)
    if not ok or result == false then return false, "Battle.net could not send the message. Your draft was kept." end
    return true
end

function NS.CanInviteBNet(c)
    local record = NS.FindBNet(c.battleTag)
    local game = record and record.info.gameAccountInfo
    return C_BattleNet and C_BattleNet.InviteFriend and game and game.isOnline
        and game.clientProgram == "WoW" and type(game.gameAccountID) == "number"
        and (not WOW_PROJECT_ID or not game.wowProjectID or game.wowProjectID == WOW_PROJECT_ID) or false
end

function NS.InviteBNet(c)
    local record = recipient(c)
    local game = record and record.info.gameAccountInfo
    if not game or not game.isOnline or game.clientProgram ~= "WoW" or not C_BattleNet or not C_BattleNet.InviteFriend then return end
    if WOW_PROJECT_ID and game.wowProjectID and game.wowProjectID ~= WOW_PROJECT_ID then return end
    local ok = pcall(C_BattleNet.InviteFriend, game.gameAccountID)
    if not ok then DEFAULT_CHAT_FRAME:AddMessage("Forever Whisper: this Battle.net friend cannot be invited here.") end
end
