local _, NS = ...

NS.editBoxes = {}
function NS.TrackEditBox(box)
    NS.editBoxes[#NS.editBoxes + 1] = box
    return box
end
function NS.ReleaseOutsideFocus(roots)
    local foci
    if GetMouseFoci then foci = GetMouseFoci()
    elseif GetMouseFocus then foci = { GetMouseFocus() }
    else
        for _, root in ipairs(roots) do if root and root:IsShown() and root:IsMouseOver() then return end end
    end
    if foci and (type(foci) ~= "table" or foci.GetParent) then foci = {foci} end
    for _, focus in ipairs(foci or {}) do
        for _ = 1, 64 do
            if not focus then break end
            for _, root in ipairs(roots) do if focus == root then return end end
            focus = focus.GetParent and focus:GetParent() or nil
        end
    end
    for _, box in ipairs(NS.editBoxes) do if box:HasFocus() then box:ClearFocus() end end
end

function NS.PeerKey(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$"):lower()
    if name == "" then return nil end
    local short, realm = name:match("^([^%-]+)%-(.+)$")
    local home = GetRealmName and GetRealmName()
    if realm and home and realm:gsub("%s", "") == home:lower():gsub("%s", "") then return short end
    return realm and (short .. "-" .. realm:gsub("%s", "")) or name
end

function NS.DisplayName(name)
    local short = name:match("^([^%-]+)%-")
    return short and NS.PeerKey(short) == NS.PeerKey(name) and short or name
end

function NS.CanonicalConversations(saved)
    local merged, keys = {}, {}
    for key in pairs(saved) do if type(key) == "string" then keys[#keys + 1] = key end end
    table.sort(keys)
    for _, oldKey in ipairs(keys) do
        local c = saved[oldKey]
        if type(c) == "table" then
            local name = type(c.name) == "string" and c.name or oldKey
            local key
            if c.kind == "bnet" then key = NS.BNetKey(c.battleTag or name) or oldKey
            else key = NS.PeerKey(name) end
            if key then
                local target = merged[key]
                if not target then
                    target = {}
                    for field, value in pairs(c) do target[field] = value end
                    target.name, target.messages, target.unread, target.last = c.kind == "bnet" and NS.BNetDisplayName(name) or NS.DisplayName(name), {}, 0, 0
                    if c.kind == "bnet" then target.battleTag = c.battleTag or name end
                    merged[key] = target
                end
                for field, value in pairs(c) do
                    if field ~= "messages" and target[field] == nil then target[field] = value end
                end
                if (tonumber(c.last) or 0) >= target.last then
                    target.last = tonumber(c.last) or 0
                    target.name = c.kind == "bnet" and NS.BNetDisplayName(name) or NS.DisplayName(name)
                    target.guid, target.lineID = c.guid or target.guid, c.lineID or target.lineID
                end
                target.pinned = target.pinned or c.pinned
                target.unread = target.unread + (tonumber(c.unread) or 0)
                for _, message in ipairs(type(c.messages) == "table" and c.messages or {}) do
                    target.messages[#target.messages + 1] = message
                end
            end
        end
    end
    for _, c in pairs(merged) do
        local ordered = {}
        for index, message in ipairs(c.messages) do ordered[index] = { index = index, message = message } end
        table.sort(ordered, function(a, b)
            local at, bt = tonumber(a.message.at) or 0, tonumber(b.message.at) or 0
            return at < bt or (at == bt and a.index < b.index)
        end)
        for index, entry in ipairs(ordered) do c.messages[index] = entry.message end
    end
    return merged
end

function NS.Excerpt(text, limit)
    text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "(emoji)"):gsub("|", "")
        :gsub("[%c]", " "):gsub("%[", "("):gsub("%]", ")")
    limit = limit or 72
    if #text <= limit then return text end
    local last = limit - 3
    while last > 0 and text:byte(last + 1) >= 128 and text:byte(last + 1) <= 191 do last = last - 1 end
    return text:sub(1, last) .. "..."
end

function NS.DecodeReply(text)
    local excerpt, answer = text:match("^%[Reply to: (.-)%] (.*)$")
    if excerpt and #excerpt <= 72 then return answer, "", excerpt end
    local who, quote, body = text:match("^%[Reply to ([^:]+): (.-)%] (.*)$")
    if who and #who <= 80 and #quote <= 72 then return body, who, quote end
    return text
end

-- URLs stay plain text in saved/sent messages; only the local display gets links.
local function urlSegments(text, plain, link)
    local output, position = {}, 1
    while position <= #text do
        local start, finish = text:find("%f[%w]https?://[^%s<>|\"']+", position)
        local ws, we = text:find("%f[%w]www%.[^%s<>|\"']+", position)
        if ws and (not start or ws < start) then start, finish = ws, we end
        if not start then output[#output + 1] = plain(text:sub(position)); break end
        output[#output + 1] = plain(text:sub(position, start - 1))
        local url = text:sub(start, finish):gsub("[.,;!]+$", "")
        for _, pair in ipairs({ {"(", ")"}, {"[", "]"}, {"{", "}"} }) do
            local function count(character)
                local n = 0
                for i = 1, #url do if url:sub(i,i) == character then n = n + 1 end end
                return n
            end
            while url:sub(-1) == pair[2] and count(pair[2]) > count(pair[1]) do url = url:sub(1,-2) end
        end
        if url:match("^https?://[^/]+") or url:match("^www%.[^%.]+%.") then
            output[#output + 1] = link(url)
        else output[#output + 1] = plain(url) end
        output[#output + 1] = plain(text:sub(start + #url, finish))
        position = finish + 1
    end
    return table.concat(output)
end

function NS.URLs(text, renderPlain)
    local found, output, position = {}, {}, 1
    local function plain(value) return renderPlain and renderPlain(value) or value end
    local function link(url)
        found[#found + 1] = url
        if not renderPlain then return url end
        local encoded = url:gsub(".", function(c) return string.format("%02x", c:byte()) end)
        return "|cff72cfff|Hfwurl:" .. encoded .. "|h" .. url .. "|h|r"
    end
    -- Do not rewrite Blizzard item/player links, texture escapes, or atlas escapes.
    while position <= #text do
        local pipe = text:find("|", position, true)
        if not pipe then output[#output + 1] = urlSegments(text:sub(position), plain, link); break end
        output[#output + 1] = urlSegments(text:sub(position, pipe-1), plain, link)
        local tail = text:sub(pipe)
        local token = tail:match("^|H.-|h.-|h") or tail:match("^|T.-|t") or tail:match("^|A.-|a")
        output[#output + 1] = token or "|"
        position = pipe + (token and #token or 1)
    end
    return table.concat(output), found
end

function NS.DecodeURL(encoded)
    if #encoded == 0 or #encoded > 4096 or #encoded % 2 ~= 0 or encoded:find("[^%x]") then return end
    local url = encoded:gsub("%x%x", function(byte) return string.char(tonumber(byte,16)) end)
    if url:find("[%c%s|]") then return end
    if url:match("^https?://[^/]+") or url:match("^www%.[^%.]+%.") then return url end
end

local friends
function NS.InvalidateFriends() friends = nil end
function NS.FriendPresence(name)
    local api = C_FriendList
    if not friends then
        friends = {}
        if api and api.GetNumFriends and api.GetFriendInfoByIndex then
            for i = 1, api.GetNumFriends() do
                local info = api.GetFriendInfoByIndex(i)
                if info and type(info.name) == "string" then friends[NS.PeerKey(info.name)] = info end
            end
        end
    end
    local key = NS.PeerKey(name)
    local info = friends[key]
    if info == nil and api and api.GetFriendInfo then
        info = api.GetFriendInfo(name)
        friends[key] = info or false
    end
    if type(info) == "table" and type(info.connected) == "boolean" then return info.connected, info.area end
end

-- Only one negotiated protocol prefix; never send keystrokes or message content.
function NS.NewSocial(isKnown, enabled, changed)
    local self = { peers = {}, prefix = "FWCHAT1" }
    local function now() return GetTime and GetTime() or time() end
    local function available()
        if not enabled() or (InCombatLockdown and InCombatLockdown()) then return false end
        local api = C_ChatInfo
        if not api or not api.SendAddonMessage then return false end
        if api.InChatMessagingLockdown and api.InChatMessagingLockdown() then return false end
        if api.AreOutgoingAddonChatMessagesRestricted and api.AreOutgoingAddonChatMessagesRestricted() then return false end
        return true
    end
    local function send(target, value)
        if not available() then return false end
        local ok, result = pcall(C_ChatInfo.SendAddonMessage, self.prefix, value, "WHISPER", target)
        return ok and (result == nil or result == true or result == 0)
    end
    local function later(delay, fn)
        if C_Timer and C_Timer.NewTimer then return C_Timer.NewTimer(delay, fn) end
        if C_Timer and C_Timer.After then C_Timer.After(delay, fn) end
    end
    local function peer(name)
        if not isKnown(name) then return end
        local key = NS.PeerKey(name)
        if not self.peers[key] then self.peers[key] = { name = name } end
        return self.peers[key]
    end
    function self:Probe(name)
        if not available() then return end
        local p = peer(name)
        if not p or (p.probe and now() - p.probe < 60) then return end
        p.probe = now()
        send(name, "H")
    end
    function self:IsTyping(name)
        local p = self.peers[NS.PeerKey(name)]
        return enabled() and p and p.typingUntil and p.typingUntil > now() or false
    end
    function self:ClearTyping(name)
        local p = self.peers[NS.PeerKey(name)]
        if p then
            p.typingUntil = nil
            p.serial = (p.serial or 0) + 1
            if p.timer then p.timer:Cancel(); p.timer = nil end
            changed()
        end
    end
    function self:Receive(prefix, value, channel, author)
        if prefix ~= self.prefix or channel ~= "WHISPER" or not enabled() then return end
        if value ~= "H" and value ~= "A" and value ~= "T" and value ~= "0" then return end
        local p = peer(author)
        if not p then return end
        if value == "H" then
            p.compatible = true
            if not p.ack or now() - p.ack >= 3 then p.ack = now(); send(author, "A") end
        elseif value == "A" then
            if p.probe and now() - p.probe < 60 then p.compatible = true end
        elseif value == "T" and p.compatible then
            if p.incoming and now() - p.incoming < 1 then return end
            p.incoming, p.typingUntil = now(), now() + 6
            p.serial = (p.serial or 0) + 1
            local serial = p.serial
            if p.timer then p.timer:Cancel() end
            p.timer = later(6, function()
                if p.serial == serial then p.typingUntil = nil; changed() end
            end)
            changed()
        elseif value == "0" and p.compatible then self:ClearTyping(author) end
    end
    function self:Stop()
        if self.active then send(self.active.name, "0") end
        self.active = nil
        if self.idle then self.idle:Cancel(); self.idle = nil end
    end
    local function idleCheck()
        self.idle = nil
        if not self.active then return end
        local remaining = 2 - (now() - self.active.lastKey)
        if remaining <= 0 then self:Stop() else self.idle = later(remaining, idleCheck) end
    end
    function self:Touch(name, hasText)
        if not hasText or not available() then self:Stop(); return end
        local p = peer(name)
        if not p then return end
        if not p.compatible then return end
        if self.active and self.active ~= p then self:Stop() end
        self.active, p.lastKey = p, now()
        if not p.sent or now() - p.sent >= 3 then
            if send(p.name, "T") then p.sent = now() end
        end
        if not self.idle then self.idle = later(2, idleCheck) end
    end
    function self:Disable()
        self:Stop()
        for name in pairs(self.peers) do self:ClearTyping(name) end
        changed()
    end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    end
    return self
end
