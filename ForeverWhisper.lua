local ADDON, NS = ...
local FW = CreateFrame("Frame")
local db, window, settings, transcript, input, palette, copyWindow, copyBox
local current, contactOffset = nil, 0
local wasOpenAtCombat, queuedInCombat = false, false
local contactButtons, styledButtons, styledLabels = {}, {}, {}
local sidebar, conversationView
local minimapButton
local guildPresence, guildPresenceDirty = {}, true
local searchView, searchInput, searchStatus, searchButtons = nil, nil, nil, {}
local searchResults, searchOffset, searchJump = {}, 0, nil
local activeView = "chat"
local showView
local CONTENT_LEFT = 232
local drafts, contactQuery = {}, ""
local actionMenu, newChat, refreshPalette
local contactMenu, customEditor, openContactMenu
local mapPinMarker
local combatPreview
local social
local replyDrafts = {}
local updateReplyPreview
local messageMenu, contactEditor
local watchedPresence = {}
local pendingLinkClick
local contactPresence

local function contactLabel(c)
    return type(c.nickname) == "string" and c.nickname ~= "" and c.nickname or c.name
end
local function contactMatches(c, query)
    return string.find(string.lower((c.name or "") .. " " .. (c.nickname or "") .. " " .. (c.note or "")), query, 1, true)
end

local defaults = {
    width = 820, height = 560, fontSize = 14, scale = 1,
    opacity = 0.94, historyLimit = 80, x = 0, y = 0,
    font = 5, theme = 9, timestamps = true, sound = false,
    keepChat = false, showMinimap = true, minimapAngle = 225,
    conversations = {}, artwork = true, artBrightness = 0.95, combatPreview = true, typing = true,
    contactSort = "recent", popupDuration = 7, popupFontSize = 13, popupNameOnly = false, popupLocked = false,
    onlineNotifyMode = "popup",
    language = "auto", soundChoice = 1,
}

NS.AlertSounds = {
    {"Default whisper", "TELL_MESSAGE", 3081}, {"Ready check", "READY_CHECK", 8960},
    {"Raid warning", "RAID_WARNING", 8959}, {"Map ping", "MAP_PING", 3175},
    {"Friend alert", "UI_BNET_TOAST", 18019},
    {"Drum hit", "file", 566027}, {"Troll gong", "file", 565564},
    {"Hunting horn", "file", 567084}, {"Hunting horn", "file", 567084, true},
    {"Alarm clock", "ALARM_CLOCK_WARNING_1", 18871}, {"Alarm bell", "ALARM_CLOCK_WARNING_2", 12867},
    {"Urgent alarm", "ALARM_CLOCK_WARNING_3", 12889}, {"Boss warning", "RAID_BOSS_EMOTE_WARNING", 12197},
    {"Boss whisper", "UI_RAID_BOSS_WHISPER_WARNING", 37666},
    {"Hello (human)", "file", 540674}, {"Hello (gnome)", "file", 540490},
    {"Beware (voice)", "file", 543587}, {"Run away (voice)", "file", 552035},
}
function NS.SharedMedia()
    if not LibStub then return end
    local ok, media=pcall(function() return LibStub("LibSharedMedia-3.0",true) end)
    if ok then return media end
end
function NS.SoundLabel(value)
    if type(value)=="string" and value:sub(1,4)=="lsm:" then return "SharedMedia: "..value:sub(5) end
    local choice=NS.AlertSounds[tonumber(value) or 1] or NS.AlertSounds[1]
    return NS.L[choice[1]]
end
function NS.PlayAlertSound(value, preview)
    if type(value)~="number" and type(value)~="string" then value=db.soundChoice end
    local play, id
    if type(value)=="string" and value:sub(1,4)=="lsm:" then
        local media=NS.SharedMedia()
        id=media and media:Fetch("sound",value:sub(5),true)
        play=PlaySoundFile
    else
        local choice=NS.AlertSounds[tonumber(value) or 1] or NS.AlertSounds[1]
        id=choice[2]=="file" and choice[3] or (SOUNDKIT and SOUNDKIT[choice[2]] or choice[3])
        play=choice[2]=="file" and PlaySoundFile or PlaySound
    end
    if preview and NS.previewSound and StopSound then pcall(StopSound,NS.previewSound);NS.previewSound=nil end
    local ok,played,handle=false,false,nil
    if play and id then ok,played,handle=pcall(play,id,"SFX") end
    if ok and played~=false then
        if preview then NS.previewSound=handle end
        return true
    end
    if preview then DEFAULT_CHAT_FRAME:AddMessage("Forever Whisper: "..NS.L["This sound is unavailable on this client."])
    elseif PlaySound then pcall(PlaySound,SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081,"SFX") end
    return false
end
function NS.SoundOptions()
    local entries={}
    local function add(text,value)
        entries[#entries+1]={text=text,value=value,preview=function() NS.PlayAlertSound(value,true) end}
    end
    -- Keep retired indices reserved so saved selections do not shift.
    for i,choice in ipairs(NS.AlertSounds) do if not choice[4] then add(NS.L[choice[1]],i) end end
    local media=NS.SharedMedia()
    if media then
        local names={}
        for name,data in pairs(media:HashTable("sound") or {}) do
            if name~="None" and data~=1 then names[#names+1]=name end
        end
        table.sort(names)
        for _,name in ipairs(names) do add("SharedMedia: "..name,"lsm:"..name) end
    end
    return entries
end

local fonts = {
    { "Classic", "Fonts\\FRIZQT__.TTF" },
    { "Arial", "Fonts\\ARIALN.TTF" },
    { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "Skurri", "Fonts\\SKURRI.TTF" },
    { "Atkinson", "Interface\\AddOns\\ForeverWhisper\\Fonts\\AtkinsonHyperlegible-Regular.ttf" },
    { "Instrument Serif", "Interface\\AddOns\\ForeverWhisper\\Fonts\\InstrumentSerif-Regular.ttf" },
    { "Questrial", "Interface\\AddOns\\ForeverWhisper\\Fonts\\Questrial-Regular.ttf" },
    { "Gentium Book Plus", "Interface\\AddOns\\ForeverWhisper\\Fonts\\GentiumBookPlus-Regular.ttf" },
    { "Rajdhani", "Interface\\AddOns\\ForeverWhisper\\Fonts\\Rajdhani-Regular.ttf" },
    { "Asap Condensed", "Interface\\AddOns\\ForeverWhisper\\Fonts\\AsapCondensed-Regular.ttf" },
    { "Almendra", "Interface\\AddOns\\ForeverWhisper\\Fonts\\Almendra-Regular.ttf" },
    { "Carter One", "Interface\\AddOns\\ForeverWhisper\\Fonts\\CarterOne.ttf" },
}
local themes = {
    { "Slate", 0.055, 0.075, 0.105, 0.65, 0.78, 0.95 },
    { "Arthas", 0.035, 0.075, 0.135, 0.48, 0.77, 1.00 },
    { "Minimal", 0.09, 0.10, 0.12, 0.72, 0.77, 0.84 },
    { "Wildwood", 0.055, 0.095, 0.085, 0.40, 0.84, 0.68 },
    { "Doom", 0.13, 0.035, 0.040, 0.98, 0.32, 0.28 },
    { "Graphite", 0.075, 0.083, 0.095, 0.74, 0.79, 0.89 },
    { "Moonstone", 0.075, 0.085, 0.115, 0.55, 0.78, 0.98 },
    { "Starlight", 0.085, 0.070, 0.115, 0.78, 0.68, 0.99 },
    { "Sakura", 0.13, 0.075, 0.15, 0.91, 0.68, 0.82 },
}
local themeArtwork = {
    { "IronCorner", false, 0.50 },       -- Slate
    { "FrostCorner", false, 0.60 },      -- Arthas
    { false, false, 0 },                -- Minimal: no decorative textures
    { "ForestCorner", true, 0.58 },      -- Wildwood
    { "DoomCorner", false, 0.65 },       -- Doom
    { "IronCorner", true, 0.55 },        -- Graphite
    { "CelestialCorner", true, 0.56 },   -- Moonstone
    { "CelestialCorner", true, 0.56 },   -- Starlight
    { "SakuraCorner", true, 0.48 },      -- Sakura
}

local function styleBrand()
    if not window or not window.brand then return end
    local font, size = fonts[db.font][2], 19
    if db.theme == 5 then font, size = fonts[4][2], 21
    elseif db.theme == 2 then font, size = fonts[1][2], 20
    elseif db.theme == 9 or db.theme == 4 then font, size = fonts[6][2], 24 end
    window.brand:SetFont(font, size, "")
end

local function currentStyle()
    return fonts[db.font][2], db.fontSize, themes[db.theme], db.opacity
end

local function replyPayload(text)
    local reply = current and replyDrafts[current]
    if reply then return "[Reply to: " .. reply.quote .. "] " .. text end
    return text
end

-- BEGIN BUNDLED EMOJI
local emoji = {
    { "grin", "1f600", "Grin", "Faces" },
    { "laugh", "1f602", "Laugh tears lol", "Faces" },
    { "rofl", "1f923", "Rolling laughing lmao", "Faces" },
    { "smile", "1f604", "Smile happy", "Faces" },
    { "wink", "1f609", "Wink", "Faces" },
    { "love", "1f60d", "Heart eyes love", "Faces" },
    { "kiss", "1f618", "Kiss", "Faces" },
    { "wow", "1f62e", "Surprised wow", "Faces" },
    { "sad", "1f622", "Sad crying", "Faces" },
    { "sob", "1f62d", "Sobbing crying", "Faces" },
    { "angry", "1f621", "Angry rage", "Faces" },
    { "think", "1f914", "Thinking hmm", "Faces" },
    { "cool", "1f60e", "Cool sunglasses", "Faces" },
    { "sweat", "1f605", "Nervous sweat", "Faces" },
    { "sleep", "1f634", "Sleeping tired", "Faces" },
    { "nerd", "1f913", "Nerd glasses", "Faces" },
    { "partyface", "1f973", "Party celebration", "Faces" },
    { "smirk", "1f60f", "Smirk", "Faces" },
    { "eyeroll", "1f644", "Eye roll whatever", "Faces" },
    { "zip", "1f910", "Zipped lips secret", "Faces" },
    { "sick", "1f922", "Sick nauseous", "Faces" },
    { "woozy", "1f974", "Woozy drunk", "Faces" },
    { "plead", "1f97a", "Pleading please", "Faces" },
    { "salute", "1fae1", "Salute respect", "Faces" },
    { "melt", "1fae0", "Melting", "Faces" },
    { "peek", "1fae3", "Peeking shy", "Faces" },
    { "teary", "1f972", "Happy tear", "Faces" },
    { "angel", "1f607", "Angel innocent", "Faces" },
    { "devil", "1f608", "Devil mischievous", "Faces" },
    { "dead", "1f635", "Dizzy knocked out", "Faces" },
    { "yes", "1f44d", "Thumbs up yes", "Hands" },
    { "no", "1f44e", "Thumbs down no", "Hands" },
    { "thanks", "1f64f", "Thanks pray", "Hands" },
    { "clap", "1f44f", "Clap applause", "Hands" },
    { "wave", "1f44b", "Wave hello goodbye", "Hands" },
    { "ok", "1f44c", "OK perfect", "Hands" },
    { "peace", "270c", "Peace victory", "Hands" },
    { "fist", "1f44a", "Fist bump", "Hands" },
    { "strong", "1f4aa", "Strong muscle", "Hands" },
    { "raised", "1f64c", "Raised hands celebration", "Hands" },
    { "point", "1f449", "Point right", "Hands" },
    { "crossed", "1f91e", "Fingers crossed luck", "Hands" },
    { "handshake", "1f91d", "Handshake deal", "Hands" },
    { "rock", "1f918", "Rock on", "Hands" },
    { "heart_hands", "1faf6", "Heart hands", "Hands" },
    { "heart", "2764", "Red heart", "Hearts" },
    { "blueheart", "1f499", "Blue heart", "Hearts" },
    { "purpleheart", "1f49c", "Purple heart", "Hearts" },
    { "greenheart", "1f49a", "Green heart", "Hearts" },
    { "blackheart", "1f5a4", "Black heart", "Hearts" },
    { "brokenheart", "1f494", "Broken heart", "Hearts" },
    { "sparkleheart", "1f496", "Sparkling heart", "Hearts" },
    { "twohearts", "1f495", "Two hearts", "Hearts" },
    { "kissmark", "1f48b", "Kiss lips", "Hearts" },
    { "rose", "1f339", "Rose flower", "Hearts" },
    { "sparkles", "2728", "Sparkles magic", "Hearts" },
    { "star", "2b50", "Star", "Hearts" },
    { "fire", "1f525", "Fire hot", "Game" },
    { "hundred", "1f4af", "100 perfect", "Game" },
    { "party", "1f389", "Party popper", "Game" },
    { "gg", "1f3c6", "GG trophy winner", "Game" },
    { "medal", "1f947", "Gold medal first", "Game" },
    { "gaming", "1f3ae", "Gaming controller", "Game" },
    { "dice", "1f3b2", "Dice roll rng", "Game" },
    { "target", "1f3af", "Target aim bullseye", "Game" },
    { "swords", "2694", "Crossed swords combat", "Game" },
    { "shield", "1f6e1", "Shield tank", "Game" },
    { "bow", "1f3f9", "Bow hunter", "Game" },
    { "magic", "1fa84", "Magic wand", "Game" },
    { "gem", "1f48e", "Gem diamond loot", "Game" },
    { "gold", "1fa99", "Gold coin money", "Game" },
    { "potion", "1f9ea", "Potion vial", "Game" },
    { "heal", "1fa79", "Heal bandage", "Game" },
    { "lightning", "26a1", "Lightning fast", "Game" },
    { "rocket", "1f680", "Rocket go", "Game" },
    { "hourglass", "23f3", "Wait hourglass", "Game" },
    { "crown", "1f451", "Crown king queen", "Game" },
    { "check", "2705", "Check ready", "Game" },
    { "cross", "274c", "Cross no cancel", "Game" },
    { "skull", "1f480", "Skull dead dying rip", "Memes" },
    { "clown", "1f921", "Clown", "Memes" },
    { "eyes", "1f440", "Eyes watching sus", "Memes" },
    { "moai", "1f5ff", "Moai bruh stone face", "Memes" },
    { "brain", "1f9e0", "Big brain galaxy smart", "Memes" },
    { "mindblown", "1f92f", "Mind blown", "Memes" },
    { "poop", "1f4a9", "Poop", "Memes" },
    { "ghost", "1f47b", "Ghost boo", "Memes" },
    { "alien", "1f47d", "Alien", "Memes" },
    { "robot", "1f916", "Robot bot", "Memes" },
    { "popcorn", "1f37f", "Popcorn drama", "Memes" },
    { "tea", "1f375", "Tea gossip", "Memes" },
    { "coffee", "2615", "Coffee", "Memes" },
    { "shrug", "1f937", "Shrug idk", "Memes" },
    { "facepalm", "1f926", "Facepalm fail", "Memes" },
    { "shrimp", "1f990", "Shrimp", "Memes" },
    { "goat", "1f410", "GOAT greatest", "Memes" },
    { "rat", "1f400", "Rat", "Memes" },
    { "snake", "1f40d", "Snake", "Memes" },
    { "monkey", "1f648", "See no evil monkey", "Memes" },
    { "catcry", "1f63f", "Crying cat", "Memes" },
    { "catsmirk", "1f63c", "Smirking cat", "Memes" },
    { "catlaugh", "1f639", "Laughing cat", "Memes" },
    { "unamused", "1f612", "Unamused really nope", "Memes" },
}
-- END BUNDLED EMOJI
local emojiPaths, emojiByCode = {}, {}
for _, entry in ipairs(emoji) do
    emojiPaths[entry[1]] = "Interface\\AddOns\\ForeverWhisper\\Emoji\\" .. entry[2] .. ".png"
    emojiByCode[entry[1]] = entry
end
local aliases = { lol = "laugh", lmao = "rofl", bruh = "moai", rip = "skull",
    sus = "eyes", rage = "angry", nope = "unamused", goat = "goat",
    thumbsup = "yes", thumbsdown = "no", ["+1"] = "yes", ["-1"] = "no" }
for code, target in pairs(aliases) do emojiPaths[code] = emojiPaths[target] end

local function clamp(n, low, high)
    n = tonumber(n) or low
    return math.max(low, math.min(high, n))
end

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function normalize(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" then return nil end
    return NS.PeerKey(name)
end

-- Simple native surfaces; the old shape system has been removed.
local function surface(parent, layer)
    return parent:CreateTexture(nil, layer or "BACKGROUND")
end

local function fill(parent, r, g, b, a, _, layer)
    local t = surface(parent, layer)
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function label(parent, text, size, anchor, x, y)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(fonts[db.font][2], size)
    f:SetPoint(anchor or "LEFT", parent, anchor or "LEFT", x or 0, y or 0)
    f:SetText(text)
    f:SetJustifyH("LEFT")
    styledLabels[#styledLabels + 1] = { frame = f, size = size }
    return f
end

local function button(parent, text, width, height, click)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.bg = fill(b, 0.17, 0.22, 0.29, 1, true)
    b.hover = surface(b, "ARTWORK")
    b.hover:SetAllPoints()
    b.hover:SetColorTexture(1, 1, 1, 0.09)
    b.hover:Hide()
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    b:SetScript("OnMouseDown", function(self) self.fontText:SetPoint("CENTER", 0, -1) end)
    b:SetScript("OnMouseUp", function(self) self.fontText:SetPoint("CENTER", 0, 0) end)
    local title = b:CreateFontString(nil, "OVERLAY")
    title:SetFont(fonts[db.font][2], 13, "")
    title:SetTextColor(0.91, 0.95, 1)
    title:SetPoint("CENTER")
    -- Keep the label independent of Button's native normal/pushed font states.
    -- Native state changes can hide an attached custom FontString.
    b.fontText = title
    function b:SetText(value)
        self.text = tostring(value or "")
        self.fontText:SetText(self.text)
    end
    function b:GetText() return self.fontText:GetText() end
    b:SetText(text)
    b:SetScript("OnClick", click)
    styledButtons[#styledButtons + 1] = b
    return b
end


local function validPin(mapID, x, y)
    return type(mapID) == "number" and mapID > 0 and mapID <= 100000
        and mapID == math.floor(mapID) and type(x) == "number" and type(y) == "number"
        and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

function NS.UpdateDropdownArrow(control, expanded, hovered)
    if not control or not control.dropdownArrow then return end
    control.dropdownExpanded=not not expanded
    local t=themes[db.theme]
    for i,line in ipairs(control.dropdownArrow) do
        local rotation=i==1 and -math.pi/4 or math.pi/4
        line:SetRotation(expanded and -rotation or rotation)
        if expanded or hovered then line:SetColorTexture(t[5],t[6],t[7],1)
        else line:SetColorTexture(0.78,0.86,0.92,0.95) end
    end
end

function NS.MarkDropdown(control)
    if control.dropdownArrow then return end
    control.dropdownArrow={}
    for i=1,2 do
        local line=control:CreateTexture(nil,"OVERLAY")
        line:SetColorTexture(0.78,0.86,0.92,0.95)
        line:SetSize(7,2)
        line:SetPoint("CENTER",control,"RIGHT",i==1 and -17 or -12,0)
        line:SetRotation(i==1 and -math.pi/4 or math.pi/4)
        control.dropdownArrow[i]=line
    end
    control.fontText:ClearAllPoints()
    control.fixedFont = "Fonts\\ARIALN.TTF"
    control.fontText:SetFont(control.fixedFont, control.fontSize or 13, "")
    control.fontText:SetPoint("TOPLEFT",8,-2)
    control.fontText:SetPoint("BOTTOMRIGHT",-28,2)
    control.fontText:SetJustifyV("MIDDLE")
    control.fontText:SetJustifyH("LEFT")
    control.fontText:SetWordWrap(false)
    control:SetScript("OnMouseDown",function() end)
    control:SetScript("OnMouseUp",function() end)
    control:HookScript("OnEnter",function(self) NS.UpdateDropdownArrow(self,self.dropdownExpanded,true) end)
    control:HookScript("OnLeave",function(self) NS.UpdateDropdownArrow(self,self.dropdownExpanded,false) end)
end

function NS.OpenDropdown(owner, entries, selected, choose)
    local menu = NS.dropdownMenu
    if menu and menu:IsShown() and menu.owner == owner then menu:Hide(); return end
    if not menu then
        menu = CreateFrame("Frame", "ForeverWhisperDropdown", window)
        NS.dropdownMenu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        menu.bg = fill(menu, 0.05, 0.08, 0.12, 1)
        menu.rows = {}
        menu.search = NS.TrackEditBox(CreateFrame("EditBox", nil, menu))
        menu.search:SetPoint("TOPLEFT", 8, -8)
        menu.search:SetPoint("TOPRIGHT", -8, -8)
        menu.search:SetHeight(26)
        menu.search:SetAutoFocus(false)
        menu.search:SetFont("Fonts\\ARIALN.TTF", 12, "")
        menu.search:SetTextInsets(8, 8, 0, 0)
        fill(menu.search, 0.12, 0.16, 0.21, 1)
        menu.search.hint = label(menu.search, NS.L["Filter options..."], 11, "LEFT", 8, 0)
        menu.footer = label(menu, "", 10, "BOTTOMLEFT", 10, 7)
        function menu:Refresh()
            local query = self.search:GetText():lower()
            local filtered = {}
            for _, entry in ipairs(self.entries or {}) do
                if query == "" or entry.text:lower():find(query, 1, true) then filtered[#filtered+1] = entry end
            end
            self.offset = clamp(self.offset or 0, 0, math.max(0, #filtered-10))
            local top = self.search:IsShown() and 40 or 8
            local visible = math.min(10, #filtered)
            self:SetHeight(top + visible*28 + 24)
            self.footer:SetText(#filtered==0 and NS.L["No matches"] or (#filtered>10 and NS.L["Mouse wheel to scroll"] or ""))
            for i, row in ipairs(self.rows) do
                local entry = filtered[i+self.offset]
                row.entry = entry
                row:SetShown(entry ~= nil and i<=visible)
                if entry then
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", 6, -top-(i-1)*28)
                    row:SetPoint("TOPRIGHT", -6, -top-(i-1)*28)
                    row:SetHeight(26)
                    row:SetText((entry.value==self.selected and "* " or "  ") .. entry.text)
                    row.preview:SetShown(entry.preview ~= nil)
                    row.preview.entry = entry
                end
            end
        end
        menu.search:SetScript("OnTextChanged", function(self)
            self.hint:SetShown(self:GetText()=="")
            menu.offset=0;menu:Refresh()
        end)
        menu.search:SetScript("OnEscapePressed", function() menu:Hide() end)
        for i=1,10 do
            local row = button(menu, "", 200, 26, function(self)
                local entry = self.entry
                if entry then local callback=menu.choose; menu:Hide();callback(entry.value) end
            end)
            row.fontText:ClearAllPoints()
            row.fixedFont = "Fonts\\ARIALN.TTF"
            row.fontText:SetFont(row.fixedFont, 13, "")
            row.fontText:SetPoint("TOPLEFT", 8, -2)
            row.fontText:SetPoint("BOTTOMRIGHT", -36, 2)
            row.fontText:SetJustifyV("MIDDLE")
            row.fontText:SetJustifyH("LEFT")
            row.fontText:SetWordWrap(false)
            row:SetScript("OnMouseDown", function() end)
            row:SetScript("OnMouseUp", function() end)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_,delta) menu:GetScript("OnMouseWheel")(menu,delta) end)
            row.preview=button(row, ">", 24, 22, function(self)
                if self.entry and self.entry.preview then self.entry.preview() end
            end)
            row.preview:SetPoint("RIGHT", -2, 0)
            menu.rows[i]=row
        end
        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseWheel", function(self, delta)
            if delta==0 then return end
            self.offset=self.offset+(delta>0 and -3 or 3);self:Refresh()
        end)
        menu:SetScript("OnHide", function(self)
            NS.UpdateDropdownArrow(self.owner,false,false)
            self.search:ClearFocus();self.owner=nil
            if NS.previewSound and StopSound then pcall(StopSound,NS.previewSound);NS.previewSound=nil end
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ForeverWhisperDropdown" end
    end
    menu:Hide()
    if not owner.dropdownHideHook then
        owner.dropdownHideHook=true
        owner:HookScript("OnHide",function(self) if menu.owner==self then menu:Hide() end end)
    end
    menu.owner,menu.entries,menu.selected,menu.choose=owner,entries,selected,choose
    menu.offset=0
    menu.search:SetText("")
    for index, entry in ipairs(entries) do if entry.value==selected then menu.offset=math.max(0,index-5);break end end
    menu.search:SetShown(#entries>10)
    menu:SetWidth(math.min(440, math.max(220, owner:GetWidth())))
    local t=themes[db.theme]
    menu.bg:SetColorTexture(t[2],t[3],t[4],1)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-4)
    menu:Show();menu:Refresh()
    NS.UpdateDropdownArrow(owner,true,false)
end

local function renderMapPins(text)
    return (text:gsub("%[Pin: ([^%]\r\n]+)%]%s*{fwmap:(%d+):(%d+):(%d+)}", function(title, map, px, py)
        local id, x, y = tonumber(map), tonumber(px) / 10000, tonumber(py) / 10000
        if not validPin(id, x, y) then return NS.L["[Invalid map pin]"] end
        title = title:gsub("|", "")
        return "|cffffb7d6|Hfwmap:" .. map .. ":" .. px .. ":" .. py .. "|h[Pin: " .. title .. "]|h|r"
    end))
end

local function renderEmoji(text)
    local size = db.fontSize + 7
    return (text:gsub(":([%w_+-]+):", function(code)
        local path = emojiPaths[string.lower(code)]
        if path then return "|T" .. path .. ":" .. size .. ":" .. size .. "|t" end
        return ":" .. code .. ":"
    end))
end

local function names()
    local result = {}
    for key, conversation in pairs(db.conversations) do
        local entry = { key = key, data = conversation }
        if db.contactSort == "online" then
            local online = contactPresence(conversation.name, conversation)
            entry.rank = online == true and 1 or (online == false and 3 or 2)
        end
        result[#result + 1] = entry
    end
    table.sort(result, function(a, b)
        if not not a.data.pinned ~= not not b.data.pinned then
            return not not a.data.pinned
        end
        if db.contactSort == "online" then
            local ar, br = a.rank, b.rank
            if ar ~= br then return ar < br end
        end
        if db.contactSort == "name" or db.contactSort == "online" then
            local an, bn = contactLabel(a.data):lower(), contactLabel(b.data):lower()
            if an ~= bn then return an < bn end
        end
        if a.data.last == b.data.last then return a.key < b.key end
        return a.data.last > b.data.last
    end)
    return result
end

local function refreshMinimap()
    if not minimapButton or not db then return end
    minimapButton:SetShown(db.showMinimap)
    local unread = 0
    for _, c in pairs(db.conversations) do
        unread = unread + (tonumber(c.unread) or 0)
    end
    minimapButton.badge:SetShown(unread > 0)
    minimapButton.badgeText:SetShown(unread > 0)
    minimapButton.badgeText:SetText(unread > 9 and "9+" or tostring(unread))
end

local function trimContacts(keep)
    local sorted = names()
    local count = #sorted
    for i = #sorted, 1, -1 do
        if count <= 40 then break end
        if sorted[i].key ~= current and sorted[i].key ~= keep
            and not sorted[i].data.pinned and not sorted[i].data.notifyOnline then
            db.conversations[sorted[i].key] = nil
            count = count - 1
        end
    end
end

local function conversation(name, bnetID)
    local record = bnetID and NS.ResolveBNetID(bnetID)
    if not bnetID and type(name) == "string" and name:match("#%d+$") then
        record = NS.FindBNet(name)
        if not record then return nil end
    end
    if bnetID and not record then return nil end
    local key = record and record.key or normalize(name)
    if not key then return nil end
    local c = db.conversations[key]
    if not c then
        c = { name = record and NS.BNetDisplayName(record.info.battleTag) or NS.DisplayName(name), last = time(), unread = 0, messages = {} }
        db.conversations[key] = c
        trimContacts(key)
    else
        c.name = record and NS.BNetDisplayName(record.info.battleTag) or NS.DisplayName(name)
    end
    if record then c.kind, c.battleTag = "bnet", record.info.battleTag end
    return key, c
end

local function addMessage(name, message, outgoing, lineID, guid, bnetID)
    local key, c = conversation(name, bnetID)
    if not c then return end
    c.last = time()
    if not outgoing then
        if type(guid) == "string" and guid:match("^Player%-") then c.guid = guid end
        if type(lineID) == "number" then c.lineID = lineID end
    end
    c.messages[#c.messages + 1] = { text = message, outgoing = outgoing, at = c.last }
    while #c.messages > db.historyLimit do
        table.remove(c.messages, 1)
    end
    if not outgoing and (key ~= current or not window or not window:IsShown() or activeView ~= "chat"
        or (transcript and transcript:GetScrollOffset() > 0)) then
        c.unread = (c.unread or 0) + 1
        if key == current and not NS.unreadBoundary then NS.unreadBoundary = c.messages[#c.messages] end
    end
    refreshMinimap()
    return key, c
end

local function rebuildGuildPresence()
    local roster = {}
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        local realm = GetRealmName and GetRealmName()
        realm = realm and string.lower(realm:gsub("%s", ""))
        for i = 1, GetNumGuildMembers() do
            local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
            if type(name) == "string" and type(online) == "boolean" then
                roster[normalize(name)] = online
                local short, memberRealm = name:match("^([^%-]+)%-(.+)$")
                if not memberRealm then
                    roster[normalize(name)] = online
                elseif realm and string.lower(memberRealm:gsub("%s", "")) == realm then
                    roster[normalize(short)] = online
                end
            end
        end
    end
    guildPresence = roster
    guildPresenceDirty = false
end

contactPresence = function(name, c)
    if c and c.kind == "bnet" then return NS.BNetPresence(c) end
    if guildPresenceDirty then rebuildGuildPresence() end
    local status, area = NS.FriendPresence(name)
    if status ~= nil then return status, NS.L["friend"], area end
    local known = guildPresence[normalize(name)]
    if known ~= nil then return known, NS.L["guild"] end
end

local function refreshWatchedPresence(baseline)
    for key, c in pairs(db.conversations) do
        if c.notifyOnline then
            local online = contactPresence(c.name, c)
            if not baseline and not c.muted and watchedPresence[key] == false and online == true then
                if db.onlineNotifyMode == "chat" or db.onlineNotifyMode == "both" then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff72eadbForever Whisper: " .. contactLabel(c) .. NS.L[" is now online.|r"])
                end
                if db.onlineNotifyMode ~= "chat" and combatPreview then combatPreview:QueueOnline(key, contactLabel(c)) end
                if db.sound then NS.PlayAlertSound() end
            end
            watchedPresence[key] = online
        else watchedPresence[key] = nil end
    end
end

local function refreshPresence()
    if not window or not window.presence then return end
    if guildPresenceDirty then rebuildGuildPresence() end
    local c = current and db.conversations[current]
    if not c then
        window.presence:SetText(NS.L["Select a conversation"])
        window.presence:SetTextColor(0.58, 0.70, 0.79)
        return
    end
    local status, source, area = contactPresence(c.name, c)
    if window.inviteButton then window.inviteButton:SetEnabled(c.kind ~= "bnet" or NS.CanInviteBNet(c)) end
    if window.ignoreButton then
        window.ignoreButton:SetEnabled(c.kind ~= "bnet")
        window.ignoreButton:SetText(c.kind == "bnet" and NS.L["Character ignore only"] or NS.L["Ignore player..."])
    end
    if social and social:IsTyping(c.name) then
        window.presence:SetText(NS.L["Typing..."])
        window.presence:SetTextColor(0.42, 0.90, 0.80)
    elseif status == true then
        window.presence:SetText(NS.L["Online ("] .. source .. ")")
        if area and area ~= "" then window.presence:SetText((c.kind == "bnet" and NS.L["Online  ·  Battle.net  ·  "] or NS.L["Online  ·  "]) .. area) end
        window.presence:SetTextColor(0.42, 0.90, 0.64)
    elseif status == false then
        window.presence:SetText(NS.L["Offline ("] .. source .. ")")
        window.presence:SetTextColor(0.66, 0.72, 0.78)
    else
        window.presence:SetText(c.kind == "bnet" and NS.L["Battle.net status unavailable"] or NS.L["Status: friends and guild only"])
        window.presence:SetTextColor(0.63, 0.73, 0.80)
    end
end

local function applyFont()
    local path = fonts[db.font][2]
    for _, item in ipairs(styledLabels) do
        item.frame:SetFont(path, item.size, "")
    end
    for _, b in ipairs(styledButtons) do
        b.fontText:SetFont(b.fixedFont or path, b.fontSize or 13, "")
    end
    if transcript then transcript:SetFont(fonts[db.font][2], db.fontSize, "") end
    if input then input:SetFont(fonts[db.font][2], db.fontSize + 1, "") end
    if input and input.hint then input.hint:SetFont(fonts[db.font][2], db.fontSize + 1, "") end
    if window and window.heading then window.heading:SetFont(fonts[db.font][2], db.fontSize + 3) end
    for _, b in ipairs(contactButtons) do
        b.name:SetFont(fonts[db.font][2], math.min(db.fontSize, 15), "")
        b.preview:SetFont(fonts[db.font][2], 11, "")
    end
    for _, b in ipairs(searchButtons) do
        b.title:SetFont(path, 13, "")
        b.preview:SetFont(path, 12, "")
    end
    if settings and settings.previewText then
        settings.previewText:SetFont(path, db.fontSize + 2, "")
    end
    if customEditor then
        for _, row in ipairs(customEditor.fields) do
            row.label:SetFont(path, 12, "")
            row.template:SetFont(path, 12, "")
        end
    end
    styleBrand()
end

local function applyTheme()
    if not window then return end
    if transcript and transcript.Restyle then transcript:Restyle() end
    local t = themes[db.theme]
    local art = themeArtwork[db.theme]
    local hasArt = art and type(art[1]) == "string"
    local enabled = db.artwork and hasArt
    if window.artCorner then
        if enabled then
            local path = "Interface\\AddOns\\ForeverWhisper\\UI\\" .. art[1] .. ".tga"
            local atmosphere = "Interface\\AddOns\\ForeverWhisper\\UI\\" .. art[1]:gsub("Corner", "Atmosphere") .. ".tga"
            window.artCorner:SetTexture(path)
            window.artSide:SetTexture(path)
            window.artAmbient:SetTexture(atmosphere)
            window.artHeader:SetTexture(atmosphere)
            window.artCorner:SetVertexColor(1, 1, 1, db.artBrightness)
            window.artSide:SetVertexColor(1, 1, 1, db.artBrightness * 0.90)
            window.artAmbient:SetVertexColor(1, 1, 1, db.artBrightness * 0.30)
            window.artHeader:SetVertexColor(1, 1, 1, db.artBrightness * 0.60)
        elseif not hasArt then
            window.artCorner:SetTexture(nil)
            window.artSide:SetTexture(nil)
            window.artAmbient:SetTexture(nil)
            window.artHeader:SetTexture(nil)
        end
        window.artCorner:SetShown(enabled)
        window.artSide:SetShown(enabled and art[2])
        window.artAmbient:SetShown(enabled)
        window.artHeader:SetShown(enabled)
    end
    styleBrand()
    if window.brand then
        window.brand:SetTextColor(db.theme == 9 and 0.96 or 0.92, db.theme == 9 and 0.82 or 0.96, db.theme == 9 and 0.90 or 1)
    end
    if contactMenu then contactMenu.bg:SetColorTexture(t[2], t[3], t[4], 1) end
    if customEditor then customEditor.bg:SetColorTexture(t[2], t[3], t[4], 1) end
    -- Keep the base transparent; each visible panel supplies one opacity layer.
    window.background:SetColorTexture(t[2], t[3], t[4], 0)
    window.headerBackground:SetColorTexture(t[2] * 0.45, t[3] * 0.45, t[4] * 0.45, db.opacity)
    window.sideBackground:SetColorTexture(t[2] * 0.50, t[3] * 0.50, t[4] * 0.50, db.opacity)
    window.chatBackground:SetColorTexture(t[2] * 0.70, t[3] * 0.70, t[4] * 0.70, db.opacity)
    window.actionBackground:SetColorTexture(t[2] * 0.85, t[3] * 0.85, t[4] * 0.85, db.opacity)
    window.composeBackground:SetColorTexture(t[2] * 1.8, t[3] * 1.8, t[4] * 1.8, db.opacity)
    window.searchBackground:SetColorTexture(t[2] * 0.8, t[3] * 0.8, t[4] * 0.8, db.opacity)
    window.searchFieldBackground:SetColorTexture(t[2] * 1.8, t[3] * 1.8, t[4] * 1.8, 1)
    window.paletteBackground:SetColorTexture(t[2] * 1.2, t[3] * 1.2, t[4] * 1.2, 1)
    if window.filterBackground then
        window.filterBackground:SetColorTexture(t[2] * 1.4, t[3] * 1.4, t[4] * 1.4, 1)
    end
    if window.composeLine then
        window.composeLine:SetColorTexture(t[5], t[6], t[7], 0.65)
    end
    if actionMenu then actionMenu.bg:SetColorTexture(t[2], t[3], t[4], 1) end
    if newChat then newChat.bg:SetColorTexture(t[2], t[3], t[4], 1) end
    window.accent:SetColorTexture(t[5], t[6], t[7], 1)
    window.accent:SetShown(hasArt)
    window.heading:SetTextColor(t[5], t[6], t[7])
    for _, b in ipairs(styledButtons) do
        b.bg:SetColorTexture(t[2] * 1.55, t[3] * 1.55, t[4] * 1.55, 0.96)
        b.hover:SetColorTexture(t[5], t[6], t[7], 0.15)
    end
    for _, b in ipairs(contactButtons) do
        b.highlight:SetColorTexture(t[5] * 0.28, t[6] * 0.28, t[7] * 0.28, 0.95)
        b.hover:SetColorTexture(t[5], t[6], t[7], 0.12)
        b.rail:SetColorTexture(t[5], t[6], t[7], 1)
        b.avatarBackground:SetColorTexture(t[5] * 0.18, t[6] * 0.18, t[7] * 0.18, 1)
        b.initial:SetTextColor(t[5], t[6], t[7])
        b.unreadBackground:SetColorTexture(t[5] * 0.45, t[6] * 0.45, t[7] * 0.45, 1)
    end
    for _, b in ipairs(searchButtons) do
        b.bg:SetColorTexture(t[2] * 1.6, t[3] * 1.6, t[4] * 1.6, 1)
    end
    if window.ignoreButton then
        window.ignoreButton.bg:SetColorTexture(0.23, 0.19, 0.22, 1)
        window.clearButton.bg:SetColorTexture(0.27, 0.16, 0.19, 1)
    end
    if window.sendButton then
        window.sendButton.bg:SetColorTexture(t[5] * 0.42, t[6] * 0.42, t[7] * 0.42, 1)
    end
    if settings and settings.previewText then
        if settings.artworkChoice then
            settings.artworkChoice:SetEnabled(hasArt)
            settings.artworkChoice:SetText(hasArt and (NS.L["Artwork: "] .. (db.artwork and NS.L["On"] or NS.L["Off"])) or NS.L["No artwork"])
        end
        settings.background:SetColorTexture(t[2] * 0.8, t[3] * 0.8, t[4] * 0.8, db.opacity)
        settings.previewBackground:SetColorTexture(t[2] * 1.45, t[3] * 1.45, t[4] * 1.45, 1)
        for _, background in ipairs(settings.selectorBackgrounds) do
            background:SetColorTexture(t[2] * 1.65, t[3] * 1.65, t[4] * 1.65, 1)
        end
        settings.previewText:SetTextColor(t[5], t[6], t[7])
        settings.previewAccent:SetColorTexture(t[5], t[6], t[7], 1)
        if settings.artPreview then
            local p = settings.artPreview
            p.bg:SetColorTexture(t[2] * 0.7, t[3] * 0.7, t[4] * 0.7, 1)
            p.themeName:SetText(NS.L[t[1]])
            if p:IsShown() and hasArt then
                p.image:SetTexture("Interface\\AddOns\\ForeverWhisper\\UI\\" .. art[1] .. ".tga")
                local atmosphere = "Interface\\AddOns\\ForeverWhisper\\UI\\" .. art[1]:gsub("Corner", "Atmosphere") .. ".tga"
                p.ambient:SetTexture(atmosphere)
                p.headerArt:SetTexture(atmosphere)
            elseif not hasArt then
                p.image:SetTexture(nil); p.ambient:SetTexture(nil); p.headerArt:SetTexture(nil)
            end
            p.image:SetShown(hasArt); p.ambient:SetShown(hasArt); p.headerArt:SetShown(hasArt)
            if p.emptyMessage then p.emptyMessage:SetShown(not hasArt) end
            if p.brightnessRow then p.brightnessRow:SetShown(hasArt) end
            p.image:SetVertexColor(1, 1, 1, db.artBrightness)
            p.ambient:SetVertexColor(1, 1, 1, db.artBrightness * 0.30)
            p.headerArt:SetVertexColor(1, 1, 1, db.artBrightness * 0.60)
            p.notice:SetText(not hasArt and NS.L["Minimal has no decorative artwork"] or (db.artwork and NS.L["Preview updates your chat style"] or NS.L["Artwork is off in chat; preview only"]))
        end
        for _, thumb in ipairs(settings.sliderThumbs) do thumb:SetColorTexture(t[5], t[6], t[7], 1) end
        for _, marker in ipairs(settings.checkMarkers) do marker:SetColorTexture(t[5], t[6], t[7], 1) end
    end
end

local function firstUnread(c)
    local remaining, first = tonumber(c.unread) or 0
    if remaining <= 0 then return end
    for i = #c.messages, 1, -1 do
        if not c.messages[i].outgoing then
            first = c.messages[i]
            remaining = remaining - 1
            if remaining <= 0 then break end
        end
    end
    return first
end

local function refreshTranscript(preserveScroll, newMessage)
    if not transcript then return end
    local offset = preserveScroll and transcript.GetScrollOffset and transcript:GetScrollOffset() or 0
    local scrollTop = offset > 0 and transcript:GetVerticalScroll() or nil
    transcript:Clear()
    local c = current and db.conversations[current]
    if window.empty then window.empty:SetShown(not c or #c.messages == 0) end
    if input and input.hint then
        input.hint:SetText(c and NS.L["Write a message..."] or NS.L["Select a chat to write a message"])
    end
    if not c then
        window.heading:SetText(settings and settings:IsShown() and NS.L["Preferences"] or "Forever Whisper")
        refreshPresence()
        if window.pinButton then window.pinButton:SetText(NS.L["Pin"]) end
        return
    end
    if not settings or not settings:IsShown() then window.heading:SetText(contactLabel(c)) end
    refreshPresence()
    if window.pinButton then window.pinButton:SetText(c.pinned and NS.L["Unpin"] or NS.L["Pin"]) end
    local previous, dividerIndex
    if NS.unreadBoundary then
        local found
        for _, item in ipairs(c.messages) do if item == NS.unreadBoundary then found = true; break end end
        if not found then NS.unreadBoundary = firstUnread(c) end
    end
    for i, item in ipairs(c.messages) do
        local stamp = db.timestamps and ("   |cff778899" .. date("%H:%M", item.at) .. "|r") or ""
        local color = item.outgoing and "|cff89cfff" or "|cffffcf83"
        local speaker = "[" .. (item.outgoing and NS.L["You"] or contactLabel(c)) .. "]"
        local prefix = searchJump and searchJump.key == current and searchJump.index == i
            and "|cff72eadb>> |r" or ""
        local day = date("%d %b", item.at)
        local newDay = not previous or date("%d %b", previous.at) ~= day
        local isNew = item == NS.unreadBoundary
        if isNew then dividerIndex = i end
        local group = isNew or newDay or previous.outgoing ~= item.outgoing or item.at - previous.at > 120
        local linkedSpeaker = not item.outgoing and ("|Hfwplayer:" .. current .. "|h" .. speaker .. "|h") or speaker
        local heading = group and (color .. linkedSpeaker .. "|r" .. stamp .. "\n") or ""
        local dateLine = newDay and ("|cff778899" .. day .. "|r\n") or ""
        local body, who, quote = NS.DecodeReply(item.text)
        if who and c.kind == "bnet" then who = NS.BNetDisplayName(who) end
        local quoted = who and (NS.L["|cff7fcbbbReply to:|r\n|cff98aaa9"] .. NS.Excerpt(quote) .. "|r\n") or ""
        local rendered = NS.URLs(body, function(text) return renderEmoji(renderMapPins(text)) end)
        transcript:AddMessage(dateLine .. heading .. quoted .. prefix .. "|cffd6e1eb  " .. rendered .. "|r", item.outgoing, isNew)
        previous = item
    end
    transcript:ScrollToBottom()
    if offset > 0 and transcript.SetScrollOffset then transcript:SetScrollOffset(offset + (newMessage and 1 or 0)) end
    if scrollTop then transcript:SetVerticalScroll(math.max(0, math.min(scrollTop, transcript.totalHeight - transcript:GetHeight()))) end
    if NS.jumpToUnread and dividerIndex then transcript:ScrollToMessage(dividerIndex) end
    NS.jumpToUnread = nil
    if searchJump and searchJump.key == current and transcript.SetScrollOffset then
        transcript:SetScrollOffset(math.max(0, #c.messages - searchJump.index))
    end
    if window.latest then window.latest:SetShown(transcript:GetScrollOffset() > 0) end
end

local function refreshContacts()
    if not window then return end
    local sorted = names()
    if contactQuery ~= "" then
        local filtered = {}
        for _, item in ipairs(sorted) do
            if contactMatches(item.data, contactQuery) then
                filtered[#filtered + 1] = item
            end
        end
        sorted = filtered
    end
    local visible = math.min(#contactButtons, math.floor((db.height - 145) / 58))
    contactOffset = clamp(contactOffset, 0, math.max(0, #sorted - visible))
    for i, b in ipairs(contactButtons) do
        local item = sorted[i + contactOffset]
        if item and i <= visible then
            b.key = item.key
            local unread = tonumber(item.data.unread) or 0
            b.name:SetText(contactLabel(item.data))
            local status, source, area = contactPresence(item.data.name, item.data)
            b.statusDot:SetTexture(status == true and "Interface\\FriendsFrame\\StatusIcon-Online"
                or "Interface\\FriendsFrame\\StatusIcon-Offline")
            if status == nil then b.statusDot:SetDesaturated(true) else b.statusDot:SetDesaturated(false) end
            b.statusDot:SetVertexColor(1, 1, 1, 1)
            local detail = status == true and NS.L["Online"] or (status == false and NS.L["Offline"] or NS.L["Unknown"])
            if item.data.kind == "bnet" then detail = detail .. "  ·  Battle.net" end
            if status == true and area and area ~= "" then detail = detail .. "  ·  " .. area end
            b.detail:SetText(detail)
            if status == true then b.detail:SetTextColor(0.42, 0.90, 0.64)
            else b.detail:SetTextColor(0.57, 0.68, 0.74) end
            local last = item.data.messages[#item.data.messages]
            local preview = last and ((last.outgoing and NS.L["You: "] or "") .. last.text) or NS.L["Start the conversation"]
            if item.data.kind == "bnet" and last then
                preview = (last.outgoing and NS.L["You: "] or "") .. NS.BNetDisplayMessage(last.text)
            end
            preview = preview:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "[image]"):gsub("[\r\n]", " ")
            b.preview:SetText((item.data.pinned and NS.L["|cff9ab5cbPIN  |r"] or "") .. preview)
            if social and social:IsTyping(item.data.name) then
                b.preview:SetText(NS.L["|cff70dcccTyping...|r"])
            end
            b.initial:SetText(string.upper(contactLabel(item.data):match("^.[\128-\191]*") or "?"))
            b.unread:SetText(unread > 99 and "99+" or tostring(unread))
            b.unreadBadge:SetShown(unread > 0)
            b.highlight:SetShown(item.key == current)
            b.rail:SetShown(item.key == current)
            b:Show()
        else
            b.key = nil
            b:Hide()
        end
    end
    if window.contactCount then
        local title = db.contactSort == "name" and "A-Z" or (db.contactSort == "online" and NS.L["Online"] or NS.L["Recent"])
        window.contactCount:SetText(title .. " / " .. #sorted)
    end
end

local function selectConversation(key)
    local c = db.conversations[key]
    if not c then return end
    local sameConversation = current == key
    if not sameConversation and window and window.urlCopy then window.urlCopy:Hide() end
    searchJump = nil
    if current ~= key then NS.unreadBoundary = nil end
    local first = firstUnread(c)
    if first then NS.unreadBoundary, NS.jumpToUnread = first, true end
    if current and input then drafts[current] = input:GetText() end
    if social then social:Stop() end
    current = key
    if contactQuery ~= "" and not contactMatches(c, contactQuery)
        and window.contactFilter then window.contactFilter:SetText("") end
    if input then input:SetText(drafts[key] or "") end
    if updateReplyPreview then updateReplyPreview() end
    if social and c.kind ~= "bnet" and contactPresence(c.name, c) == true then social:Probe(c.name) end
    if palette then palette:Hide() end
    if actionMenu then actionMenu:Hide() end
    c.unread = 0
    refreshContacts()
    refreshTranscript(sameConversation)
    refreshMinimap()
end


local function pinNotice(message)
    DEFAULT_CHAT_FRAME:AddMessage("Forever Whisper: " .. message)
end

local function openMapPin(mapID, x, y)
    if not validPin(mapID, x, y) then return end
    if C_Map and C_Map.GetMapInfo and not C_Map.GetMapInfo(mapID) then
        pinNotice(NS.L["This map is unavailable on your client."])
        return
    end
    local pointType = UiMapPoint or UIMapPoint
    local native = false
    if C_Map and C_Map.SetUserWaypoint and pointType and pointType.CreateFromCoordinates then
        if not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(mapID) then
            local ok, set = pcall(C_Map.SetUserWaypoint, pointType.CreateFromCoordinates(mapID, x, y))
            native = ok and set == true
            if native and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end
    end
    if not WorldMapFrame and UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_WorldMap") end
    local map = WorldMapFrame
    if not map then pinNotice(string.format("Map pin: %.1f, %.1f (map %d).", x * 100, y * 100, mapID)); return end
    if ShowUIPanel then ShowUIPanel(map) else map:Show() end
    if map.SetMapID then map:SetMapID(mapID)
    elseif SetMapByID then SetMapByID(mapID) end
    if native then
        if mapPinMarker then mapPinMarker:Hide() end
        return
    end
    local canvas = map.GetCanvas and map:GetCanvas() or
        (map.ScrollContainer and map.ScrollContainer.Child) or WorldMapDetailFrame
    if not canvas then pinNotice(string.format("Pin coordinates: %.1f, %.1f.", x * 100, y * 100)); return end
    if not mapPinMarker then
        mapPinMarker = CreateFrame("Frame", "ForeverWhisperMapPin", canvas)
        mapPinMarker:SetSize(28, 28)
        mapPinMarker:SetFrameLevel(canvas:GetFrameLevel() + 30)
        mapPinMarker:EnableMouse(true)
        local icon = mapPinMarker:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture("Interface\AddOns\ForeverWhisper\Emoji\1f3af.png")
        mapPinMarker:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format(NS.L["Shared pin: %.1f, %.1f"], self.x * 100, self.y * 100))
            GameTooltip:Show()
        end)
        mapPinMarker:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local function updateMarker()
            local currentMap = map.GetMapID and map:GetMapID() or (GetCurrentMapAreaID and GetCurrentMapAreaID())
            local shown = mapPinMarker.mapID ~= nil and currentMap == mapPinMarker.mapID
            mapPinMarker:SetShown(shown)
            if shown then
                mapPinMarker:ClearAllPoints()
                mapPinMarker:SetPoint("CENTER", canvas, "TOPLEFT", canvas:GetWidth() * mapPinMarker.x,
                    -canvas:GetHeight() * mapPinMarker.y)
            end
        end
        mapPinMarker.update = updateMarker
        if canvas.HookScript then canvas:HookScript("OnSizeChanged", updateMarker) end
        if map.HookScript then map:HookScript("OnShow", updateMarker) end
        if hooksecurefunc and map.SetMapID then hooksecurefunc(map, "SetMapID", updateMarker)
        elseif map.HookScript then map:HookScript("OnEvent", updateMarker) end
    end
    mapPinMarker.mapID, mapPinMarker.x, mapPinMarker.y = mapID, x, y
    mapPinMarker.update()
end

local function prepareMapPin(key, activeWaypoint)
    if inCombat() or not db.conversations[key] then return end
    local mapID, x, y, nativeLink
    if activeWaypoint and C_Map and C_Map.GetUserWaypoint then
        local point = C_Map.GetUserWaypoint()
        if point and point.position then
            mapID = point.uiMapID
            x, y = point.position:GetXY()
            if C_Map.GetUserWaypointHyperlink then nativeLink = C_Map.GetUserWaypointHyperlink() end
        end
    elseif C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        mapID = C_Map.GetBestMapForUnit("player")
        local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if position then x, y = position:GetXY() end
    elseif GetPlayerMapPosition and GetCurrentMapAreaID then
        -- Do not change the user's selected map simply to obtain coordinates.
        mapID = GetCurrentMapAreaID()
        x, y = GetPlayerMapPosition("player")
    end
    if not validPin(mapID, x, y) or (x == 0 and y == 0) then
        pinNotice(activeWaypoint and NS.L["No active map pin to share."] or NS.L["Coordinates are unavailable here. Try outdoors."])
        return
    end
    -- Native clients can generate a standard clickable worldmap link. Preserve
    -- the existing waypoint; older clients use the readable addon pin token.
    local pointType = UiMapPoint or UIMapPoint
    if not nativeLink and C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypointHyperlink
        and C_Map.SetUserWaypoint and C_Map.ClearUserWaypoint and pointType and pointType.CreateFromCoordinates
        and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(mapID)) then
        local previous = C_Map.GetUserWaypoint()
        local ok, result = pcall(function()
            if C_Map.SetUserWaypoint(pointType.CreateFromCoordinates(mapID, x, y)) then
                return C_Map.GetUserWaypointHyperlink()
            end
        end)
        if previous then C_Map.SetUserWaypoint(previous) else C_Map.ClearUserWaypoint() end
        if ok and type(result) == "string" then nativeLink = result end
    end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local zone = info and info.name or (GetRealZoneText and GetRealZoneText()) or "Map"
    zone = zone:gsub("[|%[%]\r\n]", "")
    local text = nativeLink or string.format("[Pin: %s %.1f, %.1f] {fwmap:%d:%d:%d}", zone,
        x * 100, y * 100, mapID, math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5))
    selectConversation(key)
    showView("chat")
    local draft = input:GetText()
    input:SetText(draft .. (draft:match("%S") and " " or "") .. text)
    input:SetFocus()
end

local function refreshSearchResults()
    if not searchView then return end
    searchOffset = clamp(searchOffset, 0, math.max(0, #searchResults - #searchButtons))
    for i, b in ipairs(searchButtons) do
        local result = searchResults[i + searchOffset]
        b.result = result
        if result then
            if result.kind == "person" then
                b.title:SetText(NS.L["|cff72eadbPERSON|r  "] .. result.name)
                b.preview:SetText(NS.L["Open conversation  |cff8198a8"] .. result.saved .. NS.L[" saved messages|r"])
            else
                b.title:SetText(result.name .. "  |cff8198a8" .. date("%d %b %H:%M", result.at) .. "|r")
                b.preview:SetText(result.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
            end
            b:Show()
        else
            b:Hide()
        end
    end
    if searchView.page then
        if #searchResults == 0 then
            searchView.page:SetText("")
        else
            searchView.page:SetText((searchOffset + 1) .. "-" ..
                math.min(#searchResults, searchOffset + #searchButtons) ..
                NS.L[" of "] .. #searchResults)
        end
    end
end

local function performSearch()
    if not searchInput then return end
    local query = searchInput:GetText():match("^%s*(.-)%s*$")
    searchResults, searchOffset = {}, 0
    if #query < 2 then
        searchStatus:SetText(NS.L["Type at least 2 characters, then press Enter."])
        refreshSearchResults()
        return
    end
    query = string.lower(query)
    local people, messageMatches = {}, {}
    local peopleCount, messageCount = 0, 0
    for key, c in pairs(db.conversations) do
        if contactMatches(c, query) then
            peopleCount = peopleCount + 1
            people[#people + 1] = { kind = "person", key = key, name = contactLabel(c),
                saved = #c.messages, at = c.last }
        end
        for i, item in ipairs(c.messages) do
            if string.find(string.lower(item.text), query, 1, true) then
                messageCount = messageCount + 1
                local result = { kind = "message", key = key, name = contactLabel(c), index = i,
                    text = c.kind == "bnet" and NS.BNetDisplayMessage(item.text) or item.text, at = item.at }
                if #messageMatches < 60 then
                    messageMatches[#messageMatches + 1] = result
                else
                    local oldest = 1
                    for j = 2, #messageMatches do
                        if messageMatches[j].at < messageMatches[oldest].at then oldest = j end
                    end
                    if result.at > messageMatches[oldest].at then messageMatches[oldest] = result end
                end
            end
        end
    end
    table.sort(people, function(a, b)
        if a.at == b.at then return a.key < b.key end
        return a.at > b.at
    end)
    table.sort(messageMatches, function(a, b)
        if a.at == b.at then return a.key < b.key end
        return a.at > b.at
    end)
    for _, result in ipairs(people) do
        if #searchResults >= 60 then break end
        searchResults[#searchResults + 1] = result
    end
    for _, result in ipairs(messageMatches) do
        if #searchResults >= 60 then break end
        searchResults[#searchResults + 1] = result
    end
    if peopleCount + messageCount == 0 then
        searchStatus:SetText(NS.L["No matching people or saved messages."])
    else
        local summary = peopleCount .. (peopleCount == 1 and NS.L[" person, "] or NS.L[" people, "]) ..
            messageCount .. (messageCount == 1 and NS.L[" message"] or NS.L[" messages"])
        if peopleCount + messageCount > 60 then summary = summary .. NS.L[" (showing 60)"] end
        searchStatus:SetText(summary .. ".")
    end
    refreshSearchResults()
end

local function savePosition()
    if not window then return end
    local x, y = window:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not x or not y or not parentX or not parentY then return end
    local ratio = UIParent:GetEffectiveScale() / window:GetEffectiveScale()
    db.x, db.y = x - parentX * ratio, y - parentY * ratio
end

local function copyHistory(key)
    local c = db.conversations[type(key) == "string" and key or current]
    if not c then return end
    if not copyWindow then
        copyWindow = CreateFrame("Frame", "ForeverWhisperCopyWindow", UIParent)
        copyWindow:SetSize(560, 360)
        copyWindow:SetPoint("CENTER")
        copyWindow:SetFrameStrata("FULLSCREEN_DIALOG")
        copyWindow:EnableMouse(true)
        fill(copyWindow, 0.09, 0.12, 0.18, 0.99)
        label(copyWindow, NS.L["Select text, then press Ctrl+C"], 15, "TOPLEFT", 16, -14)
        local close = button(copyWindow, NS.L["Close"], 66, 23, function() copyWindow:Hide() end)
        close:SetPoint("TOPRIGHT", -12, -11)
        local scroll = CreateFrame("ScrollFrame", nil, copyWindow)
        scroll:SetPoint("TOPLEFT", 17, -45)
        scroll:SetPoint("BOTTOMRIGHT", -17, 16)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetWidth(510)
        scroll:SetScrollChild(child)
        copyBox = NS.TrackEditBox(CreateFrame("EditBox", nil, child))
        copyBox:SetPoint("TOPLEFT")
        copyBox:SetWidth(510)
        copyBox:SetMultiLine(true)
        copyBox:SetAutoFocus(false)
        copyBox:SetFont("Fonts\\ARIALN.TTF", 13, "")
        copyBox:SetTextColor(0.92, 0.94, 1)
        copyBox:SetScript("OnEscapePressed", function() copyWindow:Hide() end)
        copyWindow:SetScript("OnHide", function() copyBox:ClearFocus() end)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * 35))
        end)
        copyWindow.child = child
        copyWindow.scroll = scroll
    end
    local lines, size = {}, 0
    for _, item in ipairs(c.messages) do
        local line = date("%Y-%m-%d %H:%M", item.at) .. "  " ..
            (item.outgoing and NS.L["You"] or c.name) .. ": " .. (c.kind == "bnet" and NS.BNetDisplayMessage(item.text) or item.text)
        -- Chat color/texture codes are not useful in a copied transcript.
        line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        line = line:gsub("{rt([1-8])}", "[marker %1]")
        lines[#lines + 1] = line
        size = size + #line
    end
    copyBox:SetText(table.concat(lines, "\n"))
    local height = math.max(295, #lines * 18 + math.ceil(size / 75) * 14)
    copyBox:SetHeight(height)
    copyWindow.child:SetHeight(height)
    copyWindow.scroll:SetVerticalScroll(0)
    copyWindow:Show()
    copyBox:SetFocus()
    copyBox:HighlightText()
end


function NS.CopyURLText(text)
    if not current or not db.conversations[current] then return end
    if not window.urlCopy then
        local strip = CreateFrame("Frame", "ForeverWhisperLinkCopy", conversationView)
        window.urlCopy = strip
        strip:SetFrameLevel(conversationView:GetFrameLevel() + 12)
        strip:EnableMouse(true)
        strip.bg = fill(strip, 0.08, 0.13, 0.19, 0.99)
        strip.hint = label(strip, NS.L["Link selected - Ctrl+C to copy"], 11, "TOPLEFT", 10, -6)
        strip.hint:SetTextColor(0.60, 0.82, 0.95)
        local close = button(strip, NS.L["Close"], 48, 20, function() NS.CloseURLCopy() end)
        close:SetPoint("TOPRIGHT", -6, -4)
        strip.scroll = CreateFrame("ScrollFrame", nil, strip)
        strip.scroll:SetPoint("TOPLEFT", 8, -29)
        strip.scroll:SetPoint("BOTTOMRIGHT", -8, 7)
        fill(strip.scroll, 0.035, 0.065, 0.10, 1)
        strip.scroll:EnableMouseWheel(true)
        strip.box = NS.TrackEditBox(CreateFrame("EditBox", nil, strip.scroll))
        strip.box:SetAutoFocus(false)
        strip.box:SetFont("Fonts\\ARIALN.TTF", 13, "")
        strip.box:SetTextColor(0.88, 0.95, 1)
        strip.box:SetTextInsets(7, 7, 0, 0)
        strip.box:SetPoint("TOPLEFT")
        strip.scroll:SetScrollChild(strip.box)
        strip.scroll:SetScript("OnMouseWheel", function(self, delta)
            self:SetVerticalScroll(math.max(0, math.min(strip.box:GetHeight()-self:GetHeight(), self:GetVerticalScroll()-delta*20)))
        end)
        strip.box:SetScript("OnEscapePressed", function() NS.CloseURLCopy() end)
        strip.box:SetScript("OnKeyDown", function(self, key)
            self.copyShortcut = key == "C" and IsControlKeyDown and IsControlKeyDown() or nil
        end)
        strip.box:SetScript("OnKeyUp", function(self, key)
            if key == "C" and self.copyShortcut then self.copyShortcut = nil; NS.CloseURLCopy() end
        end)
        strip:SetScript("OnSizeChanged", function(self)
            strip.box:SetWidth(math.max(160, self:GetWidth()-16))
        end)
        strip:SetScript("OnHide", function()
            strip.box:ClearFocus()
            if updateReplyPreview then updateReplyPreview() end
        end)
    end
    local strip = window.urlCopy
    local multiple = text:find("\n", 1, true) ~= nil
    strip:SetHeight(multiple and 90 or 60)
    strip.box:SetMultiLine(multiple)
    strip.hint:SetText(multiple and NS.L["Links selected - Ctrl+C to copy all"] or NS.L["Link selected - Ctrl+C to copy"])
    local t = themes[db.theme]
    strip.bg:SetColorTexture(t[2], t[3], t[4], 0.99)
    strip:Show()
    if updateReplyPreview then updateReplyPreview() end
    strip.box:SetWidth(math.max(160, window:GetWidth()-CONTENT_LEFT-41))
    local lines = 1
    for _ in text:gmatch("\n") do lines = lines + 1 end
    strip.box:SetHeight(multiple and math.max(54, (lines+math.ceil(#text/60))*18) or 24)
    strip.scroll:SetVerticalScroll(0)
    strip.box:SetText(text)
    strip.box:SetFocus()
    strip.box:HighlightText()
end

function NS.CloseURLCopy()
    if window and window.urlCopy then window.urlCopy:Hide() end
end

local function editContact(key)
    local c = db.conversations[key]
    if not c then return end
    if not contactEditor then
        contactEditor = CreateFrame("Frame", "ForeverWhisperContactDetails", window)
        contactEditor:SetSize(360, 228)
        contactEditor:SetPoint("CENTER")
        contactEditor:SetFrameLevel(window:GetFrameLevel() + 65)
        contactEditor:EnableMouse(true)
        fill(contactEditor, 0.05, 0.08, 0.12, 1)
        contactEditor.title = label(contactEditor, "", 14, "TOPLEFT", 16, -14)
        label(contactEditor, NS.L["Nickname (only you see this)"], 11, "TOPLEFT", 16, -44)
        label(contactEditor, NS.L["Private note"], 11, "TOPLEFT", 16, -108)
        local function field(y, max)
            local box = NS.TrackEditBox(CreateFrame("EditBox", nil, contactEditor))
            box:SetPoint("TOPLEFT", 16, y)
            box:SetSize(328, 32)
            box:SetAutoFocus(false)
            box:SetMaxLetters(max)
            box:SetTextInsets(8, 8, 0, 0)
            box:SetFont("Fonts\\ARIALN.TTF", 13, "")
            fill(box, 0.12, 0.18, 0.23, 1)
            box:SetScript("OnEscapePressed", function() contactEditor:Hide() end)
            return box
        end
        contactEditor.nickname = field(-62, 32)
        contactEditor.note = field(-126, 160)
        local save = button(contactEditor, NS.L["Save details"], 110, 28, function()
            local target = db.conversations[contactEditor.key]
            if target then
                local nickname = NS.Excerpt(contactEditor.nickname:GetText(), 96):match("^%s*(.-)%s*$")
                local note = NS.Excerpt(contactEditor.note:GetText(), 480):match("^%s*(.-)%s*$")
                target.nickname, target.note = nickname ~= "" and nickname or nil, note ~= "" and note or nil
                refreshContacts(); refreshTranscript(true)
                if searchInput then performSearch() end
            end
            contactEditor:Hide()
        end)
        save:SetPoint("BOTTOMLEFT", 16, 14)
        local cancel = button(contactEditor, NS.L["Cancel"], 78, 28, function() contactEditor:Hide() end)
        cancel:SetPoint("BOTTOMRIGHT", -16, 14)
        contactEditor:SetScript("OnHide", function()
            contactEditor.nickname:ClearFocus(); contactEditor.note:ClearFocus()
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ForeverWhisperContactDetails" end
    end
    contactEditor.key = key
    contactEditor.title:SetText(c.name)
    contactEditor.nickname:SetText(c.nickname or "")
    contactEditor.note:SetText(c.note or "")
    contactEditor:Show()
    contactEditor.nickname:SetFocus()
end

local function openMessageMenu(index, owner)
    if inCombat() then return end
    local key, c = current, current and db.conversations[current]
    local message = c and c.messages[index]
    if not message then return end
    if contactMenu then contactMenu:Hide() end
    if not messageMenu then
        messageMenu = CreateFrame("Frame", "ForeverWhisperMessageMenu", window)
        messageMenu:SetSize(150, 78)
        messageMenu:SetFrameLevel(window:GetFrameLevel() + 50)
        messageMenu:SetClampedToScreen(true)
        messageMenu:EnableMouse(true)
        fill(messageMenu, 0.05, 0.08, 0.12, 1)
        local copy = button(messageMenu, NS.L["Copy text"], 134, 26, function()
            local target = db.conversations[messageMenu.key]
            if target then
                local text = messageMenu.text
                copyHistory(messageMenu.key)
                copyBox:SetText(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
                copyBox:HighlightText()
            end
            messageMenu:Hide()
        end)
        copy:SetPoint("TOPLEFT", 8, -8)
        local reply = button(messageMenu, NS.L["Reply"], 134, 26, function()
            local target = db.conversations[messageMenu.key]
            if target and current == messageMenu.key then
                for i, item in ipairs(target.messages) do
                    if item == messageMenu.message then transcript.onReply(transcript, i); break end
                end
            end
            messageMenu:Hide()
        end)
        reply:SetPoint("TOPLEFT", 8, -42)
        messageMenu.copyLink = button(messageMenu, NS.L["Copy link"], 134, 26, function()
            if db.conversations[messageMenu.key] then
                NS.CopyURLText(table.concat(messageMenu.urls, "\n"))
            end
            messageMenu:Hide()
        end)
        messageMenu.copyLink:SetPoint("TOPLEFT", 8, -76)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ForeverWhisperMessageMenu" end
    end
    messageMenu.key, messageMenu.message = key, message
    messageMenu.text = c.kind == "bnet" and NS.BNetDisplayMessage(message.text) or message.text
    local _, urls = NS.URLs((NS.DecodeReply(messageMenu.text)))
    messageMenu.urls = urls
    messageMenu.copyLink:SetShown(#urls > 0)
    messageMenu.copyLink:SetText(#urls > 1 and NS.L["Copy links"] or NS.L["Copy link"])
    messageMenu:SetHeight(#urls > 0 and 112 or 78)
    messageMenu:ClearAllPoints()
    messageMenu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
    messageMenu:Show()
end

local function togglePin(key)
    local c = db.conversations[key]
    if not c then return end
    if not c.pinned then
        local count = 0
        for _, item in pairs(db.conversations) do if item.pinned then count = count + 1 end end
        if count >= 10 then
            DEFAULT_CHAT_FRAME:AddMessage(NS.L["Forever Whisper: you can pin up to 10 chats."])
            return
        end
    end
    c.pinned = not c.pinned
    refreshContacts()
    if key == current then refreshTranscript(true) end
end

local function editCustomActions()
    if not customEditor then
        customEditor = CreateFrame("Frame", "ForeverWhisperCustomActions", window)
        customEditor:SetSize(550, 310)
        customEditor:SetPoint("CENTER")
        customEditor:SetFrameLevel(window:GetFrameLevel() + 65)
        customEditor:EnableMouse(true)
        customEditor.bg = fill(customEditor, 0.055, 0.075, 0.105, 1, true)
        customEditor.fields = {}
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ForeverWhisperCustomActions" end
        label(customEditor, NS.L["Your right-click shortcuts"], 18, "TOPLEFT", 20, -18)
        local close = button(customEditor, "X", 26, 26, function() customEditor:Hide() end)
        close:SetPoint("TOPRIGHT", -12, -12)
        label(customEditor, NS.L["Label"], 11, "TOPLEFT", 20, -58)
        label(customEditor, NS.L["Message or /command"], 11, "TOPLEFT", 182, -58)
        for i = 1, 3 do
            local row = {}
            for column, field in ipairs({ "label", "template" }) do
                local edit = NS.TrackEditBox(CreateFrame("EditBox", nil, customEditor))
                edit:SetPoint("TOPLEFT", column == 1 and 20 or 182, -79 - (i - 1) * 44)
                edit:SetSize(column == 1 and 150 or 348, 32)
                edit:SetFont(fonts[db.font][2], 12, "")
                edit:SetTextInsets(8, 8, 0, 0)
                edit:SetAutoFocus(false)
                edit:SetMaxLetters(column == 1 and 24 or 200)
                fill(edit, 0.13, 0.17, 0.23, 1, true)
                edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); customEditor:Hide() end)
                row[field] = edit
            end
            customEditor.fields[i] = row
        end
        local help = label(customEditor, NS.L["Use {name} and {zone}. Messages fill your whisper draft.\n/commands fill WoW chat; press Enter there to run them.\nLeave a row empty to remove it."], 11, "TOPLEFT", 20, -216)
        help:SetTextColor(0.65, 0.76, 0.85)
        local save = button(customEditor, NS.L["Save shortcuts"], 126, 30, function()
            local actions = {}
            for _, row in ipairs(customEditor.fields) do
                local name = row.label:GetText():gsub("[\r\n|]", ""):match("^%s*(.-)%s*$")
                local template = row.template:GetText():gsub("[\r\n]", " "):match("^%s*(.-)%s*$")
                if name ~= "" and template ~= "" then actions[#actions + 1] = { label = name, template = template } end
            end
            db.customActions = actions
            customEditor:Hide()
        end)
        save:SetPoint("BOTTOMRIGHT", -20, 16)
        customEditor:SetScript("OnHide", function()
            for _, row in ipairs(customEditor.fields) do row.label:ClearFocus(); row.template:ClearFocus() end
        end)
        applyTheme()
    end
    for i, row in ipairs(customEditor.fields) do
        local action = db.customActions[i]
        row.label:SetText(action and action.label or "")
        row.template:SetText(action and action.template or "")
    end
    customEditor:Show()
end

openContactMenu = function(key, owner)
    local c = db.conversations[key]
    if not c or inCombat() then return end
    GameTooltip:Hide()
    if messageMenu then messageMenu:Hide() end
    if palette then palette:Hide() end
    if actionMenu then actionMenu:Hide() end
    if not contactMenu then
        contactMenu = CreateFrame("Frame", "ForeverWhisperContactMenu", window)
        contactMenu:SetWidth(244)
        contactMenu:SetFrameLevel(window:GetFrameLevel() + 45)
        contactMenu:SetClampedToScreen(true)
        contactMenu:EnableMouse(true)
        contactMenu.bg = fill(contactMenu, 0.055, 0.075, 0.105, 1, true)
        contactMenu.title = label(contactMenu, "", 14, "TOPLEFT", 14, -13)
        contactMenu.title:SetWidth(216)
        contactMenu.title:SetWordWrap(false)
        contactMenu.rows = {}
        contactMenu.blocker = CreateFrame("Frame", nil, window)
        contactMenu.blocker:SetAllPoints()
        contactMenu.blocker:SetFrameLevel(window:GetFrameLevel() + 44)
        contactMenu.blocker:EnableMouse(true)
        contactMenu.blocker:SetScript("OnMouseDown", function() contactMenu:Hide() end)
        for i = 1, 24 do
            local b = button(contactMenu, "", 224, 27, function() end)
            -- The action closure is replaced each time the menu opens; it never
            -- resolves the recipient from the currently selected conversation.
            b:SetScript("OnClick", function(self)
                local action = self.action
                contactMenu:Hide()
                if action then action() end
            end)
            b:SetPoint("TOPLEFT", 10, -39 - (i - 1) * 29)
            b.fontSize = 12
            b.fontText:SetFont(fonts[db.font][2], 12, "")
            contactMenu.rows[i] = b
        end
        contactMenu:SetScript("OnHide", function() contactMenu.blocker:Hide() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ForeverWhisperContactMenu" end
        applyTheme()
    end
    local entries = {}
    local function add(text, action)
        entries[#entries + 1] = { text = text, action = function()
            if db.conversations[key] and not inCombat() then action() end
        end }
    end
    add(NS.L["Whisper"], function() selectConversation(key); showView("chat"); input:SetFocus() end)
    if c.kind == "bnet" then
        if NS.CanInviteBNet(c) then add(NS.L["Invite to group"], function() NS.InviteBNet(c) end) end
    else
    add(NS.L["Invite to group"], function()
        if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(c.name)
        elseif InviteUnit then InviteUnit(c.name) end
    end)
    if (C_FriendList and C_FriendList.AddFriend) or AddFriend then
        add(NS.L["Add friend"], function()
            if C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(c.name)
            elseif AddFriend then AddFriend(c.name) end
        end)
    end
    add(NS.L["Ignore player..."], function() StaticPopup_Show("FOREVERWHISPER_IGNORE", c.name, nil, c.name) end)
    if UnitPopup_OpenMenu or SetItemRef then
        add(NS.L["Report / WoW player menu..."], function()
            if UnitPopup_OpenMenu then
                UnitPopup_OpenMenu("FRIEND", { name = c.name, guid = c.guid, lineID = c.lineID,
                    chatType = "WHISPER", chatTarget = c.name })
            else
                SetItemRef("player:" .. c.name .. ":" .. (c.lineID or 0) .. ":WHISPER:" .. c.name,
                    "[" .. c.name .. "]", "RightButton", DEFAULT_CHAT_FRAME)
            end
        end)
    end
    end -- Character-only friend/ignore/report actions must never target a BattleTag.
    add(c.pinned and NS.L["Unpin conversation"] or NS.L["Pin conversation"], function() togglePin(key) end)
    add(c.muted and NS.L["Unmute notifications"] or NS.L["Mute notifications"], function()
        c.muted = not c.muted or nil
        if c.muted and combatPreview then combatPreview:DropOnline(key) end
    end)
    add(NS.L["Nickname / private note..."], function() editContact(key) end)
    add(c.notifyOnline and NS.L["Disable online notification"] or NS.L["Notify when online"], function()
        c.notifyOnline = not c.notifyOnline or nil
        if c.notifyOnline then watchedPresence[key] = contactPresence(c.name, c)
        else
            watchedPresence[key] = nil
            if combatPreview then combatPreview:DropOnline(key) end
        end
    end)
    add(c.kind == "bnet" and NS.L["Copy name"] or NS.L["Copy character name"], function()
        copyHistory(key)
        copyBox:SetText(c.name)
        copyBox:HighlightText()
    end)
    add(NS.L["Copy conversation"], function() copyHistory(key) end)
    add(NS.L["Share my position pin"], function() prepareMapPin(key) end)
    if C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint() then
        add(NS.L["Share active map pin"], function() prepareMapPin(key, true) end)
    end
    add(NS.L["Clear history..."], function() StaticPopup_Show("FOREVERWHISPER_CLEAR", c.name, nil, key) end)
    add(NS.L["Delete conversation..."], function() StaticPopup_Show("FOREVERWHISPER_DELETE", c.name, nil, key) end)
    for _, item in ipairs(db.customActions) do
        local action = item
        if c.kind ~= "bnet" or action.template:sub(1, 1) ~= "/" then
        add(action.label, function()
            local text = action.template:gsub("{name}", function() return c.name end)
                :gsub("{zone}", function() return GetRealZoneText and GetRealZoneText() or "" end)
            if text:sub(1, 1) == "/" then
                if ChatFrame_OpenChat then ChatFrame_OpenChat(text, DEFAULT_CHAT_FRAME) end
            else
                selectConversation(key)
                showView("chat")
                input:SetText(text)
                input:SetFocus()
            end
        end)
        end
    end
    add(NS.L["Customize actions..."], editCustomActions)
    contactMenu.title:SetText(contactLabel(c))
    for i, row in ipairs(contactMenu.rows) do
        local entry = entries[i]
        row:SetShown(entry ~= nil)
        row.action = entry and entry.action
        if entry then row:SetText(entry.text) end
    end
    contactMenu:SetHeight(44 + #entries * 29)
    contactMenu:ClearAllPoints()
    if GetCursorPosition then
        local x, y = GetCursorPosition()
        local scale = contactMenu:GetEffectiveScale()
        contactMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    else
        contactMenu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
    end
    contactMenu.blocker:Show()
    contactMenu:Show()
end

local function makeWindow()
    if window then return end
    window = CreateFrame("Frame", "ForeverWhisperWindow", UIParent)
    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = "ForeverWhisperWindow"
    end
    window:SetSize(db.width, db.height)
    window:SetScale(db.scale)
    window:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    if window.SetResizable then window:SetResizable(true) end
    if window.SetResizeBounds then
        window:SetResizeBounds(700, 480, 1200, 850)
    else
        if window.SetMinResize then window:SetMinResize(700, 480) end
        if window.SetMaxResize then window:SetMaxResize(1200, 850) end
    end
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    NS.AttachCursorDrag(window, savePosition, function() return not inCombat() and not window.sizing end)
    window.background = fill(window, 0.05, 0.07, 0.12, db.opacity)
    local header = surface(window, "BORDER")
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(54)
    header:SetColorTexture(0.025, 0.045, 0.075, 0.94)
    window.headerBackground = header
    window.artHeader = window:CreateTexture(nil, "ARTWORK")
    window.artHeader:SetPoint("TOP", 0, -3)
    window.artHeader:SetSize(240, 48)
    window.artHeader:SetTexCoord(0, 1, 0, 0.20)
    window.accent = window:CreateTexture(nil, "BORDER")
    window.accent:SetPoint("TOPLEFT", 0, 0)
    window.accent:SetPoint("TOPRIGHT", 0, 0)
    window.accent:SetHeight(3)
    window.heading = label(window, "Forever Whisper", db.fontSize + 3, "TOPLEFT", CONTENT_LEFT, -14)
    window.heading:SetPoint("TOPRIGHT", window, "TOPRIGHT", -230, -14)
    window.heading:SetJustifyH("LEFT")
    window.presence = label(window, "", 11, "TOPLEFT", CONTENT_LEFT, -36)
    window.presence:SetWidth(210)
    window.presence:SetJustifyH("LEFT")
    window.presence:SetTextColor(0.63, 0.73, 0.80)
    local nameTarget = CreateFrame("Button", nil, window)
    window.nameTarget = nameTarget
    nameTarget:SetPoint("TOPLEFT", CONTENT_LEFT, -5)
    nameTarget:SetPoint("TOPRIGHT", -230, -5)
    nameTarget:SetHeight(44)
    nameTarget:RegisterForClicks("RightButtonUp")
    nameTarget:RegisterForDrag("LeftButton")
    nameTarget:SetScript("OnClick", function(self) if activeView == "chat" and current then openContactMenu(current, self) end end)
    nameTarget:SetScript("OnDragStart", function() window:BeginCursorDrag() end)
    nameTarget:SetScript("OnDragStop", function() window:EndCursorDrag() end)
    nameTarget:SetScript("OnEnter", function(self)
        if activeView ~= "chat" or not current then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(NS.L["Right-click for player actions"])
        GameTooltip:Show()
    end)
    nameTarget:SetScript("OnLeave", function() GameTooltip:Hide() end)
    window.brand = label(window, "WHISPER", 19, "TOPLEFT", 18, -10)
    window.brand:SetTextColor(0.92, 0.96, 1)
    label(window, "F O R E V E R", 9, "TOPLEFT", 19, -33):SetTextColor(0.52, 0.65, 0.77)
    local close = button(window, "X", 28, 26, function() window:Hide() end)
    close:SetPoint("TOPRIGHT", -14, -12)
    local settingsButton = button(window, NS.L["Settings"], 76, 26, function()
        showView(activeView == "settings" and "chat" or "settings")
    end)
    settingsButton:SetPoint("TOPRIGHT", close, "TOPLEFT", -8, 0)
    window.settingsButton = settingsButton
    local searchButton = button(window, NS.L["Search"], 68, 26, function()
        showView(activeView == "search" and "chat" or "search")
    end)
    searchButton:SetPoint("RIGHT", settingsButton, "LEFT", -8, 0)
    window.searchButton = searchButton
    conversationView = CreateFrame("Frame", nil, window)
    conversationView:SetAllPoints()
    window.chatBackground = surface(conversationView, "BACKGROUND")
    window.chatBackground:SetPoint("TOPLEFT", CONTENT_LEFT - 12, -102)
    window.chatBackground:SetPoint("BOTTOMRIGHT", 0, 0)
    window.actionBackground = surface(conversationView, "BORDER")
    window.actionBackground:SetPoint("TOPLEFT", CONTENT_LEFT - 12, -55)
    window.actionBackground:SetPoint("TOPRIGHT", 0, -55)
    window.actionBackground:SetHeight(47)
    local actionDivider = conversationView:CreateTexture(nil, "ARTWORK")
    actionDivider:SetPoint("TOPLEFT", CONTENT_LEFT - 12, -102)
    actionDivider:SetPoint("TOPRIGHT", 0, -102)
    actionDivider:SetHeight(1)
    actionDivider:SetColorTexture(0.22, 0.31, 0.37, 0.65)
    local copyButton = button(conversationView, NS.L["Copy"], 66, 25, copyHistory)
    copyButton:SetPoint("TOPLEFT", CONTENT_LEFT, -66)
    local inviteButton = button(conversationView, NS.L["Invite"], 66, 25, function()
        local c = current and db.conversations[current]
        if not c then return end
        if c.kind == "bnet" then NS.InviteBNet(c); return end
        if C_PartyInfo and C_PartyInfo.InviteUnit then
            C_PartyInfo.InviteUnit(c.name)
        elseif InviteUnit then
            InviteUnit(c.name)
        end
    end)
    window.inviteButton = inviteButton
    inviteButton:SetPoint("LEFT", copyButton, "RIGHT", 5, 0)
    actionMenu = CreateFrame("Frame", nil, conversationView)
    actionMenu:SetSize(180, 88)
    actionMenu:SetFrameLevel(conversationView:GetFrameLevel() + 25)
    actionMenu:EnableMouse(true)
    actionMenu.bg = fill(actionMenu, 0.07, 0.08, 0.11, 1, true)
    local more = button(conversationView, NS.L["More ..."], 76, 28, function()
        actionMenu:SetShown(not actionMenu:IsShown())
        palette:Hide()
    end)
    more:SetPoint("TOPRIGHT", -18, -64)
    actionMenu:SetPoint("TOPRIGHT", more, "BOTTOMRIGHT", 0, -5)
    local ignoreButton = button(actionMenu, NS.L["Ignore player..."], 160, 30, function()
        actionMenu:Hide()
        local c = current and db.conversations[current]
        if c and c.kind ~= "bnet" then StaticPopup_Show("FOREVERWHISPER_IGNORE", c.name, nil, c.name) end
    end)
    local clearButton = button(actionMenu, NS.L["Clear history..."], 160, 30, function()
        actionMenu:Hide()
        local c = current and db.conversations[current]
        if c then StaticPopup_Show("FOREVERWHISPER_CLEAR", c.name, nil, current) end
    end)
    local pinButton = button(conversationView, NS.L["Pin"], 66, 25, function()
        if current then togglePin(current) end
    end)
    pinButton:SetPoint("LEFT", inviteButton, "RIGHT", 5, 0)
    ignoreButton:SetPoint("TOPLEFT", 10, -10)
    clearButton:SetPoint("TOPLEFT", 10, -48)
    actionMenu:Hide()
    window.ignoreButton = ignoreButton
    window.clearButton = clearButton
    window.pinButton = pinButton

    sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT", 0, -55)
    sidebar:SetPoint("BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(CONTENT_LEFT - 12)
    window.sideBackground = fill(sidebar, 0.04, 0.05, 0.08, db.opacity, true)
    local sideDivider = sidebar:CreateTexture(nil, "BORDER")
    sideDivider:SetPoint("TOPRIGHT", -1, 0)
    sideDivider:SetPoint("BOTTOMRIGHT", -1, 0)
    sideDivider:SetWidth(1)
    sideDivider:SetColorTexture(0.23, 0.34, 0.40, 0.65)
    local filter = NS.TrackEditBox(CreateFrame("EditBox", nil, sidebar))
    filter:SetPoint("TOPLEFT", 12, -12)
    filter:SetPoint("TOPRIGHT", -12, -12)
    filter:SetHeight(30)
    filter:SetAutoFocus(false)
    filter:SetTextInsets(10, 10, 0, 0)
    filter:SetFont(fonts[db.font][2], 12, "")
    window.filterBackground = fill(filter, 0.1, 0.14, 0.19, 1, true)
    local filterHint = label(filter, NS.L["Filter conversations..."], 12, "LEFT", 10, 0)
    filterHint:SetTextColor(0.53, 0.64, 0.74)
    filter:SetScript("OnTextChanged", function(self)
        contactQuery = string.lower(self:GetText())
        filterHint:SetShown(contactQuery == "")
        contactOffset = 0
        refreshContacts()
    end)
    filter:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    window.contactFilter = filter
    window.contactCount = button(sidebar, NS.L["Recent"], 124, 24, function()
        NS.OpenDropdown(window.contactCount, {
            {text=NS.L["Recent"],value="recent"}, {text="A-Z",value="name"}, {text=NS.L["Online first"],value="online"},
        }, db.contactSort, function(value) db.contactSort=value;contactOffset=0;refreshContacts() end)
    end)
    window.contactCount:SetPoint("TOPLEFT", 12, -49)
    NS.MarkDropdown(window.contactCount)
    window.contactCount.fontSize=11
    window.contactCount.fontText:SetFont(fonts[db.font][2],11,"")
    window.contactCount:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(NS.L["Sort: Recent / A-Z / Online first"])
        GameTooltip:AddLine(NS.L["Pinned conversations stay first"], 0.7, 0.8, 0.9)
        GameTooltip:Show()
    end)
    window.contactCount:SetScript("OnLeave", function() GameTooltip:Hide() end)
    newChat = CreateFrame("Frame", nil, sidebar)
    newChat:SetSize(204, 122)
    newChat:SetPoint("TOPLEFT", 8, -78)
    newChat:SetFrameLevel(sidebar:GetFrameLevel() + 24)
    newChat:EnableMouse(true)
    newChat.bg = fill(newChat, 0.07, 0.08, 0.11, 1, true)
    label(newChat, NS.L["NEW CONVERSATION"], 11, "TOPLEFT", 12, -12)
    local player = NS.TrackEditBox(CreateFrame("EditBox", nil, newChat))
    player:SetPoint("TOPLEFT", 12, -36)
    player:SetSize(180, 28)
    player:SetAutoFocus(false)
    player:SetMaxLetters(80)
    player:SetTextInsets(8, 8, 0, 0)
    player:SetFont(fonts[db.font][2], 13, "")
    fill(player, 0.14, 0.18, 0.23, 1)
    local nameHint = label(player, NS.L["Name-Realm or BattleTag"], 11, "LEFT", 8, 0)
    nameHint:SetTextColor(0.58, 0.68, 0.78)
    player:SetScript("OnTextChanged", function(self) nameHint:SetShown(self:GetText() == "") end)
    local function openChat()
        local name = player:GetText():match("^%s*(.-)%s*$")
        if name == "" or inCombat() then return end
        local key = conversation(name)
        if not key then
            DEFAULT_CHAT_FRAME:AddMessage(NS.L["Forever Whisper: Battle.net friend unavailable. Start a whisper from WoW's friends list first."])
            return
        end
        filter:SetText("")
        selectConversation(key)
        showView("chat")
        newChat:Hide()
        player:ClearFocus()
        input:SetFocus()
    end
    player:SetScript("OnEnterPressed", openChat)
    player:SetScript("OnEscapePressed", function(self) self:ClearFocus(); newChat:Hide() end)
    local open = button(newChat, NS.L["Open chat"], 180, 30, openChat)
    open:SetPoint("BOTTOMLEFT", 12, 12)
    newChat:SetScript("OnHide", function() player:ClearFocus() end)
    local add = button(sidebar, NS.L["+ New"], 62, 26, function()
        newChat:SetShown(not newChat:IsShown())
        if newChat:IsShown() then player:SetText(""); player:SetFocus() end
    end)
    add:SetPoint("TOPRIGHT", -12, -48)
    newChat:Hide()
    sidebar:EnableMouseWheel(true)
    sidebar:SetScript("OnMouseWheel", function(_, delta)
        contactOffset = contactOffset - delta
        refreshContacts()
    end)
    for i = 1, 14 do
        local b = CreateFrame("Button", nil, sidebar)
        b:SetPoint("TOPLEFT", 8, -82 - (i - 1) * 58)
        b:SetPoint("TOPRIGHT", -8, -82 - (i - 1) * 58)
        b:SetHeight(54)
        b.highlight = fill(b, 0.13, 0.27, 0.34, 0.95, true)
        b.rail = b:CreateTexture(nil, "BORDER")
        b.rail:SetPoint("TOPLEFT", 0, -8)
        b.rail:SetPoint("BOTTOMLEFT", 0, 8)
        b.rail:SetWidth(2)
        b.hover = surface(b, "ARTWORK")
        b.hover:SetAllPoints()
        b.hover:SetColorTexture(0.30, 0.50, 0.59, 0.16)
        b.hover:Hide()
        b:SetScript("OnEnter", function(self)
            self.hover:Show()
            local c = self.key and db.conversations[self.key]
            if c and (c.nickname or c.note or c.notifyOnline) then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(c.name)
                if c.note then GameTooltip:AddLine(c.note, 0.75, 0.83, 0.90, true) end
                if c.notifyOnline then GameTooltip:AddLine(NS.L["Online notification enabled"], 0.45, 0.90, 0.70) end
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta)
            contactOffset = contactOffset - delta
            refreshContacts()
        end)
        local avatar = CreateFrame("Frame", nil, b)
        avatar:SetPoint("LEFT", 10, 0)
        avatar:SetSize(30, 34)
        b.avatarBackground = fill(avatar, 0.12, 0.19, 0.25, 1, true)
        b.initial = label(avatar, "?", 16, "CENTER", 0, 0)
        b.name = b:CreateFontString(nil, "OVERLAY")
        b.name:SetPoint("TOPLEFT", 49, -5)
        b.name:SetPoint("TOPRIGHT", -28, -5)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.name:SetFont(fonts[db.font][2], math.min(db.fontSize, 15), "")
        b.preview = b:CreateFontString(nil, "OVERLAY")
        b.detail = label(b, "", 10, "TOPLEFT", 49, -23)
        b.detail:SetPoint("TOPRIGHT", -9, -23)
        b.detail:SetWordWrap(false)
        b.detail:SetTextColor(0.57, 0.68, 0.74)
        b.statusDot = avatar:CreateTexture(nil, "OVERLAY")
        b.statusDot:SetPoint("BOTTOMRIGHT", avatar, "BOTTOMRIGHT", 2, -2)
        b.statusDot:SetSize(12, 12)
        b.preview:SetPoint("TOPLEFT", 49, -37)
        b.preview:SetPoint("TOPRIGHT", -9, -37)
        b.preview:SetJustifyH("LEFT")
        b.preview:SetWordWrap(false)
        b.preview:SetFont(fonts[db.font][2], 11, "")
        b.preview:SetTextColor(0.58, 0.68, 0.77)
        b.unreadBadge = CreateFrame("Frame", nil, b)
        b.unreadBadge:SetSize(22, 18)
        b.unreadBadge:SetPoint("TOPRIGHT", -5, -7)
        b.unreadBackground = fill(b.unreadBadge, 0.2, 0.4, 0.6, 1, true)
        b.unread = label(b.unreadBadge, "", 10, "CENTER", 0, 0)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then openContactMenu(self.key, self)
            else selectConversation(self.key); newChat:Hide() end
        end)
        contactButtons[i] = b
    end

    window.artAmbient = conversationView:CreateTexture(nil, "BORDER")
    window.artAmbient:SetPoint("TOPLEFT", CONTENT_LEFT, -118)
    window.artAmbient:SetPoint("BOTTOMRIGHT", -23, 80)
    window.artAmbient:SetTexCoord(0, 1, 0.20, 1)
    window.artCorner = conversationView:CreateTexture(nil, "ARTWORK")
    window.artCorner:SetPoint("TOPRIGHT", -8, -105)
    window.artCorner:SetSize(300, 300)
    window.artSide = sidebar:CreateTexture(nil, "ARTWORK")
    window.artSide:SetPoint("BOTTOMLEFT", 0, 0)
    window.artSide:SetSize(208, 208)
    window.artSide:SetTexCoord(1, 0, 1, 0)

    transcript = NS.CreateTranscript(conversationView, currentStyle)
    window.transcript = transcript
    transcript:SetPoint("TOPLEFT", CONTENT_LEFT, -118)
    transcript:SetPoint("BOTTOMRIGHT", -23, 80)
    transcript:SetFont(fonts[db.font][2], db.fontSize, "")
    transcript:EnableMouseWheel(true)
    transcript:SetScript("OnMouseWheel", function(self, delta)
        self:ScrollPixels(delta)
        if self:GetScrollOffset() == 0 and current and db.conversations[current] then
            db.conversations[current].unread = 0
            refreshContacts(); refreshMinimap()
        end
        if window.latest and self.GetScrollOffset then window.latest:SetShown(self:GetScrollOffset() > 0) end
    end)

    transcript:EnableMouse(true)
    if transcript.SetHyperlinksEnabled then transcript:SetHyperlinksEnabled(true) end
    transcript.onHyperlinkClick = function(self, link, text, mouseButton)
        if messageMenu then messageMenu:Hide() end
        local encoded = link:match("^fwurl:(.*)$")
        if encoded then
            local url = NS.DecodeURL(encoded)
            if url then NS.CopyURLText(url) end
            return
        end
        local key = link:match("^fwplayer:(.+)$")
        if key then
            if mouseButton == "RightButton" then openContactMenu(key, self) end
        else
            local map, px, py = link:match("^fwmap:(%d+):(%d+):(%d+)$")
            if map then openMapPin(tonumber(map), tonumber(px) / 10000, tonumber(py) / 10000)
            elseif SetItemRef then SetItemRef(link, text, mouseButton) end
        end
    end
    transcript:SetScript("OnMouseDown", function()
        if messageMenu then messageMenu:Hide() end
        if contactMenu then contactMenu:Hide() end
        actionMenu:Hide()
    end)
    transcript.onMessageMenu = function(_, index, owner) openMessageMenu(index, owner) end
    window.empty = label(conversationView, NS.L["A little closer to your people.\n\nChoose a chat on the left, or click + New."], 15, "CENTER", 95, 12)
    window.empty:SetJustifyH("CENTER")
    window.empty:SetTextColor(0.57, 0.69, 0.79)
    window.latest = button(conversationView, NS.L["Latest messages"], 132, 26, function()
        transcript:ScrollToBottom()
        if current and db.conversations[current] then db.conversations[current].unread = 0 end
        refreshContacts(); refreshMinimap()
        searchJump = nil
        window.latest:Hide()
    end)
    -- Transcript rows have mouse-enabled children above their scroll frame.
    -- Keep the floating button above those children across the whole surface.
    window.latest:SetFrameLevel(transcript:GetFrameLevel() + 8)
    window.latest:SetPoint("BOTTOMRIGHT", -25, 76)
    window.latest:Hide()
    local compose = CreateFrame("Frame", nil, conversationView)
    compose:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 20)
    compose:SetPoint("BOTTOMRIGHT", -139, 20)
    compose:SetHeight(44)
    window.composeBackground = fill(compose, 0.12, 0.17, 0.23, 1, true)
    local replyBar = CreateFrame("Frame", nil, conversationView)
    window.replyBar = replyBar
    replyBar:SetPoint("BOTTOMLEFT", CONTENT_LEFT, 70)
    replyBar:SetPoint("BOTTOMRIGHT", -25, 70)
    replyBar:SetHeight(44)
    fill(replyBar, 0.08, 0.15, 0.17, 0.97)
    replyBar.title = label(replyBar, "", 10, "TOPLEFT", 10, -5)
    replyBar.quote = label(replyBar, "", 11, "BOTTOMLEFT", 10, 7)
    replyBar.quote:SetPoint("BOTTOMRIGHT", -35, 7)
    replyBar.quote:SetWordWrap(false)
    replyBar.title:SetTextColor(0.5, 0.85, 0.82)
    local cancelReply = button(replyBar, "X", 24, 24, function()
        replyDrafts[current] = nil
        updateReplyPreview()
    end)
    cancelReply:SetPoint("RIGHT", -6, 0)
    updateReplyPreview = function()
        local reply = current and replyDrafts[current]
        local base = reply and 130 or 80
        local strip = window.urlCopy
        local copyHeight = strip and strip:IsShown() and (strip:GetHeight() + 6) or 0
        if strip then
            strip:ClearAllPoints()
            strip:SetPoint("BOTTOMLEFT", CONTENT_LEFT, base)
            strip:SetPoint("BOTTOMRIGHT", -25, base)
        end
        replyBar:SetShown(reply ~= nil)
        if reply then
            replyBar.title:SetText(NS.L["Replying to "] .. reply.who)
            replyBar.quote:SetText(reply.quote)
        end
        transcript:ClearAllPoints()
        transcript:SetPoint("TOPLEFT", CONTENT_LEFT, -118)
        transcript:SetPoint("BOTTOMRIGHT", -23, base + copyHeight)
        window.latest:ClearAllPoints()
        window.latest:SetPoint("BOTTOMRIGHT", -25, base + copyHeight - 4)
        if input and input:GetScript("OnTextChanged") then input:GetScript("OnTextChanged")(input, false) end
    end
    replyBar:Hide()
    transcript.onReply = function(_, index)
        local c = current and db.conversations[current]
        local message = c and c.messages[index]
        if not message or inCombat() then return end
        local who = message.outgoing and ((UnitName and UnitName("player")) or NS.L["You"]) or c.name
        local body = NS.DecodeReply(message.text)
        replyDrafts[current] = { who = NS.Excerpt(who, 40), quote = NS.Excerpt(body, 48) }
        updateReplyPreview()
        if input then input:SetFocus() end
    end
    input = NS.TrackEditBox(CreateFrame("EditBox", nil, compose))
    input:SetPoint("TOPLEFT", 12, 0)
    input:SetPoint("BOTTOMRIGHT", -10, 0)
    input:SetAutoFocus(false)
    input:SetFont(fonts[db.font][2], db.fontSize + 1, "")
    input:SetTextColor(0.95, 0.97, 1)
    input.hint = label(compose, NS.L["Write a message..."], db.fontSize + 1, "LEFT", 12, 0)
    input.hint:SetTextColor(0.54, 0.65, 0.72)
    window.composeLine = compose:CreateTexture(nil, "BORDER")
    window.composeLine:SetPoint("BOTTOMLEFT")
    window.composeLine:SetPoint("BOTTOMRIGHT")
    window.composeLine:SetHeight(2)
    window.composeLine:Hide()
    input:SetScript("OnEditFocusGained", function() window.composeLine:Show() end)
    input:SetScript("OnEditFocusLost", function()
        window.composeLine:Hide()
        if social then social:Stop() end
    end)
    window.byteCount = label(conversationView, "", 10, "BOTTOMRIGHT", -26, 6)
    window.byteCount:SetTextColor(0.5, 0.62, 0.72)
    label(conversationView, NS.L["ENTER  Send    /    ESC  Release keyboard"], 10, "BOTTOMLEFT", CONTENT_LEFT, 6)
        :SetTextColor(0.5, 0.62, 0.72)
    input:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText()
        local bytes = #replyPayload(text)
        self.hint:SetShown(text == "")
        if current then drafts[current] = text end
        window.byteCount:SetText(bytes > 0 and (bytes .. " / 255") or "")
        window.byteCount:SetTextColor(bytes > 255 and 1 or 0.5, bytes > 255 and 0.4 or 0.62, bytes > 255 and 0.4 or 0.72)
        if window.sendButton then
            window.sendButton:SetEnabled(current ~= nil and text:match("%S") ~= nil and bytes <= 255)
        end
        if social and current and db.conversations[current].kind ~= "bnet" then
            if userInput then social:Touch(db.conversations[current].name, text:match("%S") ~= nil)
            elseif text == "" then social:Stop() end
        end
    end)
    -- Hyperlink markup counts toward the send limit; never truncate its closing tags.
    input:SetMaxLetters(0)
    NS.InstallLinkInsertion(function(text)
        if type(text) ~= "string" or text == "" or not current or activeView ~= "chat"
            or not input:IsShown() or inCombat() then return false end
        local focused = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focused and focused ~= input then return false end
        local pending = pendingLinkClick and pendingLinkClick.key == current
            and IsModifiedClick and IsModifiedClick("CHATLINK")
        if not input:HasFocus() and not pending then return false end
        pendingLinkClick = nil
        if #replyPayload(input:GetText() .. text) > 255 then
            DEFAULT_CHAT_FRAME:AddMessage(NS.L["|cffff8080Forever Whisper: message is too long.|r"])
            return true
        end
        input:Insert(text)
        input:SetFocus()
        return true
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function send()
        local c = current and db.conversations[current]
        if not c then return end
        local message = input:GetText():match("^%s*(.-)%s*$")
        if message == "" then return end
        message = replyPayload(message)
        if #message > 255 then
            DEFAULT_CHAT_FRAME:AddMessage(NS.L["|cffff8080Forever Whisper: message is too long.|r"])
            return
        end
        if c.kind == "bnet" then
            local ok, reason = NS.SendBNet(c, message)
            if not ok then DEFAULT_CHAT_FRAME:AddMessage("Forever Whisper: " .. reason); return end
        else
            SendChatMessage(message, "WHISPER", nil, c.name)
        end
        replyDrafts[current] = nil
        input:SetText("")
        updateReplyPreview()
        input:SetFocus()
    end
    input:SetScript("OnEnterPressed", send)
    local sendButton = button(conversationView, NS.L["Send"], 62, 44, send)
    sendButton:SetPoint("BOTTOMRIGHT", -25, 20)
    window.sendButton = sendButton
    local emoteButton = button(conversationView, "", 50, 44, function()
        palette:SetShown(not palette:IsShown())
        actionMenu:Hide()
        if palette:IsShown() and refreshPalette then refreshPalette() end
    end)
    emoteButton:SetPoint("RIGHT", sendButton, "LEFT", -6, 0)
    local emojiIcon = emoteButton:CreateTexture(nil, "OVERLAY")
    emojiIcon:SetSize(25, 25)
    emojiIcon:SetPoint("CENTER")
    emojiIcon:SetTexture(emojiPaths.grin)
    sendButton:SetEnabled(false)

    palette = CreateFrame("Frame", nil, conversationView)
    palette:SetSize(354, 340)
    palette:SetPoint("BOTTOMRIGHT", emoteButton, "TOPRIGHT", 0, 7)
    palette:SetFrameLevel(conversationView:GetFrameLevel() + 20)
    palette:EnableMouse(true)
    palette:SetClampedToScreen(true)
    window.paletteBackground = fill(palette, 0.10, 0.15, 0.20, 1, true)
    label(palette, NS.L["Emoji & reactions"], 16, "TOPLEFT", 14, -13):SetTextColor(0.91, 0.95, 1)
    local paletteClose = button(palette, "X", 26, 26, function() palette:Hide() end)
    paletteClose:SetPoint("TOPRIGHT", -10, -9)
    local emojiSearch = NS.TrackEditBox(CreateFrame("EditBox", nil, palette))
    emojiSearch:SetPoint("TOPLEFT", 14, -44)
    emojiSearch:SetPoint("TOPRIGHT", -14, -44)
    emojiSearch:SetHeight(30)
    emojiSearch:SetAutoFocus(false)
    emojiSearch:SetMaxLetters(40)
    emojiSearch:SetTextInsets(10, 10, 0, 0)
    emojiSearch:SetFont(fonts[db.font][2], 12, "")
    fill(emojiSearch, 0.13, 0.17, 0.23, 1)
    local emojiHint = label(emojiSearch, NS.L["Search: happy, skull, gg..."], 12, "LEFT", 10, 0)
    emojiHint:SetTextColor(0.57, 0.67, 0.77)
    local category, page, matches, slots, tabs = "All", 0, {}, {}, {}
    local paletteStatus = label(palette, "", 10, "BOTTOMLEFT", 14, 18)
    paletteStatus:SetTextColor(0.65, 0.76, 0.85)
    refreshPalette = function()
        local query = string.lower(emojiSearch:GetText()):match("^%s*(.-)%s*$")
        matches = {}
        local candidates = emoji
        if category == "Recent" and query == "" then
            candidates = {}
            for _, code in ipairs(db.recentEmoji) do
                if emojiByCode[code] then candidates[#candidates + 1] = emojiByCode[code] end
            end
        end
        for _, entry in ipairs(candidates) do
            -- A search spans all categories, so there are no hidden matches.
            if query ~= "" or category == "All" or category == "Recent" or entry[4] == category then
                local searchable = string.lower(entry[1] .. " " .. entry[3] .. " " .. NS.L[entry[3]] .. " " .. entry[4] .. " " .. NS.L[entry[4]])
                if query == "" or string.find(searchable, query, 1, true) then matches[#matches + 1] = entry end
            end
        end
        page = clamp(page, 0, math.max(0, math.ceil(#matches / 28) - 1))
        for i, slot in ipairs(slots) do
            local entry = matches[page * 28 + i]
            slot.entry = entry
            slot:SetShown(entry ~= nil)
            if entry then slot.art:SetTexture(emojiPaths[entry[1]]) end
        end
        for name, tab in pairs(tabs) do
            tab.marker:SetShown(query == "" and name == category)
        end
        paletteStatus:SetText(#matches == 0 and NS.L["No matches"] or
            (#matches .. NS.L[" emojis  /  "] .. (page + 1) .. NS.L[" of "] .. math.max(1, math.ceil(#matches / 28))))
    end
    for i, name in ipairs({ "All", "Faces", "Hands", "Hearts", "Game", "Memes", "Recent" }) do
        local caption = NS.language == "es" and (name == "Hearts" or name == "Recent") and NS.L[name .. " short"] or NS.L[name]
        local tab = button(palette, caption, 46, 27, function()
            category, page = name, 0
            emojiSearch:SetText("")
            refreshPalette()
        end)
        tab:SetPoint("TOPLEFT", 13 + (i - 1) * 47, -84)
        tab.fontSize = 10
        tab.fontText:SetFont(fonts[db.font][2], 10, "")
        tab.marker = tab:CreateTexture(nil, "ARTWORK")
        tab.marker:SetPoint("BOTTOMLEFT")
        tab.marker:SetPoint("BOTTOMRIGHT")
        tab.marker:SetHeight(2)
        tab.marker:SetColorTexture(0.62, 0.82, 1, 1)
        tabs[name] = tab
    end
    for i = 1, 28 do
        local b = CreateFrame("Button", nil, palette)
        b:SetSize(44, 42)
        b:SetPoint("TOPLEFT", 14 + ((i - 1) % 7) * 46, -119 - math.floor((i - 1) / 7) * 44)
        b.art = b:CreateTexture(nil, "ARTWORK")
        b.art:SetSize(30, 30)
        b.art:SetPoint("CENTER")
        local hover = b:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.12)
        hover:Hide()
        b:SetScript("OnEnter", function(self)
            if not self.entry then return end
            hover:Show()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(NS.L[self.entry[3]])
            GameTooltip:AddLine(":" .. self.entry[1] .. ":", 0.60, 0.80, 1)
            GameTooltip:AddLine(NS.L["Shift-click to keep the picker open"], 0.65, 0.72, 0.80)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() hover:Hide(); GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if not self.entry or not current then return end
            local code = self.entry[1]
            input:Insert(":" .. code .. ": ")
            for j = #db.recentEmoji, 1, -1 do
                if db.recentEmoji[j] == code then table.remove(db.recentEmoji, j) end
            end
            table.insert(db.recentEmoji, 1, code)
            while #db.recentEmoji > 16 do table.remove(db.recentEmoji) end
            GameTooltip:Hide()
            if not IsShiftKeyDown() then palette:Hide() end
            input:SetFocus()
        end)
        slots[i] = b
    end
    local older = button(palette, "<", 28, 26, function() page = page - 1; refreshPalette() end)
    older:SetPoint("BOTTOMRIGHT", -48, 10)
    local newer = button(palette, ">", 28, 26, function() page = page + 1; refreshPalette() end)
    newer:SetPoint("BOTTOMRIGHT", -14, 10)
    palette:EnableMouseWheel(true)
    palette:SetScript("OnMouseWheel", function(_, delta) page = page - delta; refreshPalette() end)
    palette:SetScript("OnHide", function() emojiSearch:ClearFocus(); GameTooltip:Hide() end)
    emojiSearch:SetScript("OnTextChanged", function(self)
        emojiHint:SetShown(self:GetText() == "")
        page = 0
        if palette:IsShown() then refreshPalette() end
    end)
    emojiSearch:SetScript("OnEscapePressed", function(self) self:ClearFocus(); palette:Hide() end)

    searchView = CreateFrame("Frame", nil, window)
    searchView:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -54)
    searchView:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    searchView:EnableMouse(true)
    window.searchBackground = fill(searchView, 0.075, 0.105, 0.145, 0.99)
    local searchField = CreateFrame("Frame", nil, searchView)
    searchField:SetPoint("TOPLEFT", 25, -23)
    searchField:SetPoint("TOPRIGHT", -113, -23)
    searchField:SetHeight(36)
    window.searchFieldBackground = fill(searchField, 0.12, 0.17, 0.23, 1, true)
    searchInput = NS.TrackEditBox(CreateFrame("EditBox", nil, searchField))
    searchInput:SetPoint("TOPLEFT", 11, 0)
    searchInput:SetPoint("BOTTOMRIGHT", -8, 0)
    searchInput:SetAutoFocus(false)
    searchInput:SetFont("Fonts\\ARIALN.TTF", 14, "")
    searchInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchInput:SetScript("OnEnterPressed", performSearch)
    local findButton = button(searchView, NS.L["Find"], 76, 36, performSearch)
    findButton:SetPoint("TOPRIGHT", -25, -23)
    searchStatus = label(searchView, NS.L["Search people or saved messages. Press Enter to find matches."],
        12, "TOPLEFT", 27, -72)
    searchStatus:SetTextColor(0.60, 0.74, 0.83)
    for i = 1, 6 do
        local b = CreateFrame("Button", nil, searchView)
        b:SetPoint("TOPLEFT", 25, -101 - (i - 1) * 44)
        b:SetPoint("TOPRIGHT", -25, -101 - (i - 1) * 44)
        b:SetHeight(40)
        b.bg = fill(b, 0.12, 0.17, 0.22, 1, true)
        local hover = b:CreateTexture(nil, "ARTWORK")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.07)
        hover:Hide()
        b:SetScript("OnEnter", function() hover:Show() end)
        b:SetScript("OnLeave", function() hover:Hide() end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta)
            searchOffset = searchOffset - delta * 3
            refreshSearchResults()
        end)
        b.title = b:CreateFontString(nil, "OVERLAY")
        b.title:SetFont("Fonts\\ARIALN.TTF", 13, "")
        b.title:SetPoint("TOPLEFT", 10, -4)
        b.title:SetPoint("TOPRIGHT", -10, -4)
        b.title:SetJustifyH("LEFT")
        b.title:SetWordWrap(false)
        b.preview = b:CreateFontString(nil, "OVERLAY")
        b.preview:SetFont("Fonts\\ARIALN.TTF", 12, "")
        b.preview:SetTextColor(0.73, 0.81, 0.86)
        b.preview:SetPoint("BOTTOMLEFT", 10, 5)
        b.preview:SetPoint("BOTTOMRIGHT", -10, 5)
        b.preview:SetJustifyH("LEFT")
        b.preview:SetWordWrap(false)
        b:SetScript("OnClick", function(self)
            local result = self.result
            if not result or not db.conversations[result.key] then return end
            selectConversation(result.key)
            if result.kind == "person" then
                showView("chat")
                return
            end
            local index = result.index
            local messages = db.conversations[result.key].messages
            if not messages[index] or messages[index].text ~= result.text
                or messages[index].at ~= result.at then
                index = nil
                for j, item in ipairs(messages) do
                    if item.text == result.text and item.at == result.at then
                        index = j
                        break
                    end
                end
            end
            if index then searchJump = { key = result.key, index = index } end
            showView("chat")
        end)
        searchButtons[i] = b
    end
    searchView:EnableMouseWheel(true)
    searchView:SetScript("OnMouseWheel", function(_, delta)
        searchOffset = searchOffset - delta * 3
        refreshSearchResults()
    end)
    local previous = button(searchView, NS.L["Previous"], 82, 24, function()
        searchOffset = searchOffset - #searchButtons
        refreshSearchResults()
    end)
    previous:SetPoint("BOTTOMLEFT", 25, 15)
    local nextPage = button(searchView, NS.L["Next"], 62, 24, function()
        searchOffset = searchOffset + #searchButtons
        refreshSearchResults()
    end)
    nextPage:SetPoint("LEFT", previous, "RIGHT", 7, 0)
    searchView.page = label(searchView, "", 12, "BOTTOMRIGHT", -26, 20)
    searchView.page:SetTextColor(0.65, 0.76, 0.84)
    searchView:Hide()
    local resizing, resize
    local function finishResize()
        if not resizing then return end
        resizing = nil
        window.sizing = nil
        resize:SetScript("OnUpdate", nil)
        db.width = clamp(window:GetWidth(), 700, 1200)
        db.height = clamp(window:GetHeight(), 480, 850)
        window:SetSize(db.width, db.height)
        if settings and settings.widthSlider then
            settings.syncingSize = true
            settings.widthSlider:SetValue(db.width)
            settings.heightSlider:SetValue(db.height)
            settings.syncingSize = nil
        end
        refreshContacts()
        savePosition()
    end
    resize = CreateFrame("Button", nil, window)
    window.resizeGrip = resize
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetFrameLevel(window:GetFrameLevel() + 30)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(NS.L["Drag to resize"], 1, 1, 1)
        GameTooltip:Show()
    end)
    resize:SetScript("OnLeave", function() GameTooltip:Hide() end)
    resize:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" and not inCombat() then
            window:EndCursorDrag()
            local x, y = GetCursorPosition()
            local left, top = window:GetLeft(), window:GetTop()
            if not left or not top then return end
            resizing = { x = x, y = y, width = window:GetWidth(), height = window:GetHeight(),
                scale = window:GetEffectiveScale() }
            window.sizing = true
            local parentScale = UIParent:GetEffectiveScale() / resizing.scale
            resizing.maxWidth = math.max(resizing.width, math.min(1200, UIParent:GetWidth() * parentScale - left))
            resizing.maxHeight = math.max(resizing.height, math.min(850, top))
            -- StartSizing snaps the frame's outer edge to a cursor inside the grip.
            -- Anchor the opposite corner and apply cursor deltas instead.
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            resize:SetScript("OnUpdate", function()
                if inCombat() or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then
                    finishResize()
                    return
                end
                local cursorX, cursorY = GetCursorPosition()
                local width = clamp(resizing.width + (cursorX - resizing.x) / resizing.scale, 700, resizing.maxWidth)
                local height = clamp(resizing.height - (cursorY - resizing.y) / resizing.scale, 480, resizing.maxHeight)
                if width ~= window:GetWidth() or height ~= window:GetHeight() then window:SetSize(width, height) end
            end)
        end
    end)
    resize:SetScript("OnMouseUp", finishResize)
    palette:Hide()
    window:SetScript("OnHide", function()
        if NS.dropdownMenu then NS.dropdownMenu:Hide() end
        window:EndCursorDrag()
        if window.urlCopy then window.urlCopy:Hide() end
        NS.unreadBoundary, NS.jumpToUnread = nil, nil
        finishResize()
        palette:Hide()
        actionMenu:Hide()
        newChat:Hide()
        if window.contactFilter then window.contactFilter:ClearFocus() end
        if input then input:ClearFocus() end
        if searchInput then searchInput:ClearFocus() end
        if contactMenu then contactMenu:Hide() end
        if customEditor then customEditor:Hide() end
        if contactEditor then contactEditor:Hide() end
        if messageMenu then messageMenu:Hide() end
        if settings and settings.artPreview then settings.artPreview:Hide() end
    end)
    applyTheme()
    refreshContacts()
    refreshTranscript()
    window:Hide()
end

local function makeSettings()
    if settings then return end
    settings = CreateFrame("Frame", "ForeverWhisperSettings", window)
    settings:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -54)
    settings:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    settings:EnableMouse(true)
    settings.sliderThumbs, settings.checkMarkers = {}, {}
    settings.background = fill(settings, 0.075, 0.105, 0.145, 0.99)
    label(settings, NS.L["LOOK & FEEL"], 11, "TOPLEFT", 26, -18):SetTextColor(0.60, 0.77, 0.86)
    label(settings, NS.L["Drag the bottom-right corner to resize"], 11, "TOPRIGHT", -26, -18)
        :SetTextColor(0.55, 0.68, 0.76)
    local left = CreateFrame("Frame", nil, settings)
    left:SetPoint("TOPLEFT", 26, -42)
    left:SetPoint("TOPRIGHT", settings, "TOP", -9, -42)
    left:SetHeight(170)
    local right = CreateFrame("Frame", nil, settings)
    right:SetPoint("TOPLEFT", settings, "TOP", 9, -42)
    right:SetPoint("TOPRIGHT", -26, -42)
    right:SetHeight(170)
    local function slider(parent, rowIndex, title, field, low, high, step, apply)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", 0, -(rowIndex - 1) * 55)
        row:SetPoint("TOPRIGHT", 0, -(rowIndex - 1) * 55)
        row:SetHeight(47)
        label(row, title, 13, "TOPLEFT", 0, 0)
        local value = label(row, "", 13, "TOPRIGHT", -2, 0)
        value:SetJustifyH("RIGHT")
        local s = CreateFrame("Slider", nil, row)
        s:SetPoint("BOTTOMLEFT", 7, 4)
        s:SetPoint("BOTTOMRIGHT", -7, 4)
        s:SetHeight(16)
        s:SetOrientation("HORIZONTAL")
        local rail = s:CreateTexture(nil, "BACKGROUND")
        rail:SetPoint("LEFT")
        rail:SetPoint("RIGHT")
        rail:SetHeight(3)
        rail:SetColorTexture(0.23, 0.29, 0.36, 1)
        local thumb = s:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(10, 16)
        thumb:SetColorTexture(0.6, 0.8, 1, 1)
        s:SetThumbTexture(thumb)
        settings.sliderThumbs[#settings.sliderThumbs + 1] = thumb
        s:SetMinMaxValues(low, high)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        s:SetValue(db[field])
        local function formatValue(v)
            if field == "opacity" or field == "artBrightness" then return math.floor(v * 100 + 0.5) .. "%" end
            return step < 1 and string.format("%.2f", v) or tostring(v)
        end
        s:SetScript("OnValueChanged", function(_, v)
            if settings.syncingSize and (field == "width" or field == "height") then
                value:SetText(formatValue(db[field]))
                return
            end
            v = math.floor(v / step + 0.5) * step
            db[field] = v
            value:SetText(formatValue(v))
            apply()
        end)
        value:SetText(formatValue(db[field]))
        return s
    end
    settings.widthSlider = slider(left, 1, NS.L["Width"], "width", 700, 1200, 10,
        function() window:SetWidth(db.width) end)
    settings.heightSlider = slider(left, 2, NS.L["Height"], "height", 480, 850, 10, function()
        window:SetHeight(db.height)
        refreshContacts()
    end)
    slider(left, 3, NS.L["Window scale"], "scale", 0.7, 1.4, 0.05,
        function() window:SetScale(db.scale) end)
    slider(right, 1, NS.L["Text size"], "fontSize", 10, 20, 1,
        function() applyFont(); refreshTranscript() end)
    slider(right, 2, NS.L["Opacity"], "opacity", 0.2, 1, 0.05, applyTheme)
    slider(right, 3, NS.L["History per person"], "historyLimit", 20, 200, 10, function()
        for _, c in pairs(db.conversations) do
            while #c.messages > db.historyLimit do table.remove(c.messages, 1) end
        end
        refreshTranscript()
    end)
    label(settings, NS.L["CHOOSE A STYLE"], 11, "TOPLEFT", 26, -211)
        :SetTextColor(0.60, 0.77, 0.86)
    settings.selectorBackgrounds = {}
    local function selector(parent, field, choices, title, apply)
        local box
        local function change(delta, selected)
            db[field] = selected or ((db[field] - 1 + delta + #choices) % #choices + 1)
            box:SetText(title .. ": " .. NS.L[choices[db[field]][1]])
            apply()
        end
        box = button(parent, "", 200, 31, function()
            local entries={}
            for i,choice in ipairs(choices) do entries[#entries+1]={text=NS.L[choice[1]],value=i} end
            NS.OpenDropdown(box,entries,db[field],function(value) change(0,value) end)
        end)
        box:SetPoint("TOPLEFT")
        box:SetPoint("TOPRIGHT")
        box:SetHeight(31)
        NS.MarkDropdown(box)
        settings.selectorBackgrounds[#settings.selectorBackgrounds + 1] = box.bg
        settings[field .. "Selector"] = box
        box:SetText(title .. ": " .. NS.L[choices[db[field]][1]])
        return function(delta) change(delta) end
    end
    local fontChoice = CreateFrame("Frame", nil, settings)
    fontChoice:SetPoint("TOPLEFT", 26, -233)
    fontChoice:SetPoint("TOPRIGHT", settings, "TOP", -9, -233)
    fontChoice:SetHeight(31)
    selector(fontChoice, "font", fonts, NS.L["Font"], function()
        applyFont()
        refreshTranscript()
    end)
    local themeChoice = CreateFrame("Frame", nil, settings)
    themeChoice:SetPoint("TOPLEFT", settings, "TOP", 9, -233)
    themeChoice:SetPoint("TOPRIGHT", -26, -233)
    themeChoice:SetHeight(31)
    local changeTheme = selector(themeChoice, "theme", themes, NS.L["Theme"], applyTheme)
    local generalButton = button(settings, NS.L["Sound / language"], 150, 23, function()
        if settings.popupOptions then settings.popupOptions:Hide() end
        if not settings.generalOptions then
            local panel = CreateFrame("Frame", "ForeverWhisperGeneralOptions", settings)
            settings.generalOptions = panel
            panel:SetSize(400, 218)
            panel:SetPoint("CENTER", window, "CENTER")
            panel:SetFrameLevel(window:GetFrameLevel() + 66)
            panel:EnableMouse(true)
            fill(panel, 0.05, 0.08, 0.12, 1)
            label(panel, NS.L["Sound and language"], 15, "TOPLEFT", 16, -14)
            local function soundCaption()
                panel.soundChoice:SetText(NS.L["Whisper sound"] .. ": " .. NS.SoundLabel(db.soundChoice))
            end
            panel.soundChoice = button(panel, "", 280, 28, function()
                NS.OpenDropdown(panel.soundChoice,NS.SoundOptions(),db.soundChoice,function(value)
                    db.soundChoice=value;soundCaption()
                end)
            end)
            panel.soundChoice:SetPoint("TOPLEFT", 16, -48)
            NS.MarkDropdown(panel.soundChoice)
            soundCaption()
            local listen = button(panel, NS.L["Listen"], 80, 28, function() NS.PlayAlertSound(db.soundChoice,true) end)
            listen:SetPoint("TOPRIGHT", -16, -48)
            local function languageCaption()
                local name = db.language == "es" and "Español" or (db.language == "en" and "English" or NS.L["Automatic"])
                panel.languageChoice:SetText(NS.L["Language"] .. ": " .. name)
            end
            panel.languageChoice = button(panel, "", 240, 28, function()
                NS.OpenDropdown(panel.languageChoice,{
                    {text=NS.L["Automatic"],value="auto"}, {text="Español",value="es"}, {text="English",value="en"},
                },db.language,function(value) db.language=value;languageCaption() end)
            end)
            panel.languageChoice:SetPoint("TOPLEFT", 16, -92)
            NS.MarkDropdown(panel.languageChoice)
            languageCaption()
            local reload = button(panel, NS.L["Reload UI"], 120, 28, function() if ReloadUI then ReloadUI() end end)
            reload:SetPoint("TOPRIGHT", -16, -92)
            label(panel, NS.L["Applies after reloading the interface"], 11, "TOPLEFT", 16, -132)
            local close = button(panel, NS.L["Done"], 72, 28, function() panel:Hide() end)
            close:SetPoint("BOTTOMRIGHT", -16, 16)
            if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ForeverWhisperGeneralOptions" end
        end
        settings.generalOptions:Show()
    end)
    generalButton:SetPoint("TOPLEFT", 26, -278)
    local arrangePopup = button(settings, NS.L["Arrange popup"], 120, 23, function()
        if combatPreview then combatPreview:Arrange() end
    end)
    arrangePopup:SetPoint("TOPRIGHT", -154, -278)
    local function check(parent, rowIndex, text, field, apply)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", 0, -(rowIndex - 1) * 25)
        row:SetPoint("TOPRIGHT", 0, -(rowIndex - 1) * 25)
        row:SetHeight(24)
        local b = CreateFrame("CheckButton", nil, row)
        b:SetAllPoints()
        local box = b:CreateTexture(nil, "BACKGROUND")
        box:SetPoint("LEFT", 2, 0)
        box:SetSize(20, 20)
        box:SetColorTexture(0.18, 0.23, 0.29, 1)
        local marker = b:CreateTexture(nil, "ARTWORK")
        marker:SetPoint("LEFT", 7, 0)
        marker:SetSize(10, 10)
        marker:SetColorTexture(0.6, 0.8, 1, 1)
        settings.checkMarkers[#settings.checkMarkers + 1] = marker
        b:SetChecked(db[field])
        marker:SetShown(db[field])
        label(row, text, 13, "LEFT", 31, 0)
        b:SetScript("OnClick", function(self)
            db[field] = not not self:GetChecked()
            marker:SetShown(db[field])
            if apply then apply() end
        end)
        return b
    end
    local leftChecks = CreateFrame("Frame", nil, settings)
    leftChecks:SetPoint("TOPLEFT", 26, -308)
    leftChecks:SetPoint("TOPRIGHT", settings, "TOP", -9, -308)
    leftChecks:SetHeight(75)
    local rightChecks = CreateFrame("Frame", nil, settings)
    rightChecks:SetPoint("TOPLEFT", settings, "TOP", 9, -308)
    rightChecks:SetPoint("TOPRIGHT", -26, -308)
    rightChecks:SetHeight(61)
    check(leftChecks, 1, NS.L["Show timestamps"], "timestamps", refreshTranscript)
    check(leftChecks, 2, NS.L["Play sound for whispers"], "sound")
    check(leftChecks, 3, NS.L["Combat message previews"], "combatPreview", function()
        if not db.combatPreview and combatPreview and combatPreview.kind == "whisper" then combatPreview:Reset(true) end
    end)
    check(rightChecks, 1, NS.L["Also show whispers in WoW chat"], "keepChat")
    check(rightChecks, 2, NS.L["Show minimap button"], "showMinimap", refreshMinimap)
    check(rightChecks, 3, NS.L["Share typing indicators"], "typing", function()
        if social and not db.typing then social:Disable() end
        refreshContacts()
        refreshPresence()
    end)
    local popupOptions = button(settings, NS.L["Popup options"], 120, 23, function()
        if settings.generalOptions then settings.generalOptions:Hide() end
        if not settings.popupOptions then
            local panel = CreateFrame("Frame", "ForeverWhisperPopupOptions", settings)
            settings.popupOptions = panel
            panel:SetSize(360, 330)
            panel:SetPoint("CENTER", window, "CENTER")
            panel:SetFrameLevel(window:GetFrameLevel() + 66)
            panel:EnableMouse(true)
            fill(panel, 0.05, 0.08, 0.12, 1)
            label(panel, NS.L["Combat popup"], 15, "TOPLEFT", 16, -14)
            local fields = CreateFrame("Frame", nil, panel)
            fields:SetPoint("TOPLEFT", 16, -48)
            fields:SetSize(328, 110)
            local function apply()
                if combatPreview then combatPreview:ApplyOptions(); combatPreview:ArmTimer() end
            end
            panel.durationSlider = slider(fields, 1, NS.L["Duration (seconds)"], "popupDuration", 3, 30, 1, apply)
            panel.fontSlider = slider(fields, 2, NS.L["Text size"], "popupFontSize", 10, 20, 1, apply)
            local checks = CreateFrame("Frame", nil, panel)
            checks:SetPoint("TOPLEFT", 16, -170)
            checks:SetSize(328, 60)
            panel.nameOnly = check(checks, 1, NS.L["Show name only (hide message)"], "popupNameOnly", apply)
            panel.locked = check(checks, 2, NS.L["Lock position and size"], "popupLocked", apply)
            local modeNames = { popup = NS.L["Popup"], chat = NS.L["Chat"], both = NS.L["Popup + Chat"] }
            panel.onlineMode = button(panel, "", 328, 26, function()
                NS.OpenDropdown(panel.onlineMode,{
                    {text=modeNames.popup,value="popup"}, {text=modeNames.chat,value="chat"}, {text=modeNames.both,value="both"},
                },db.onlineNotifyMode,function(value)
                    db.onlineNotifyMode=value
                    panel.onlineMode:SetText(NS.L["Online notifications: "] .. modeNames[value])
                end)
            end)
            panel.onlineMode:SetPoint("TOPLEFT", 16, -230)
            NS.MarkDropdown(panel.onlineMode)
            panel.onlineMode:SetText(NS.L["Online notifications: "] .. (modeNames[db.onlineNotifyMode] or NS.L["Popup"]))
            local previewButton = button(panel, NS.L["Preview / move"], 124, 28, function()
                panel:Hide()
                if combatPreview then combatPreview:Arrange() end
            end)
            previewButton:SetPoint("BOTTOMLEFT", 16, 16)
            local close = button(panel, NS.L["Done"], 72, 28, function() panel:Hide() end)
            close:SetPoint("BOTTOMRIGHT", -16, 16)
            if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ForeverWhisperPopupOptions" end
        end
        settings.popupOptions:Show()
    end)
    popupOptions:SetPoint("TOPRIGHT", -26, -278)
    local preview = CreateFrame("Frame", nil, settings)
    preview:SetPoint("TOPLEFT", 26, -388)
    preview:SetPoint("TOPRIGHT", -26, -388)
    preview:SetHeight(31)
    settings.previewBackground = fill(preview, 0.10, 0.15, 0.20, 1, true)
    settings.previewAccent = preview:CreateTexture(nil, "ARTWORK")
    settings.previewAccent:SetPoint("TOPLEFT")
    settings.previewAccent:SetPoint("BOTTOMLEFT")
    settings.previewAccent:SetWidth(3)
    settings.previewText = label(preview, NS.L["Aa  Hello there!  123"], db.fontSize + 2, "LEFT", 15, 0)
    local artworkChoice = button(preview, NS.L["Artwork: "] .. (db.artwork and NS.L["On"] or NS.L["Off"]), 120, 27, function(self)
        db.artwork = not db.artwork
        self:SetText(NS.L["Artwork: "] .. (db.artwork and NS.L["On"] or NS.L["Off"]))
        applyTheme()
    end)
    settings.artworkChoice = artworkChoice
    artworkChoice:SetPoint("RIGHT", -8, 0)
    local artPreview = CreateFrame("Frame", "ForeverWhisperArtPreview", settings)
    settings.artPreview = artPreview
    artPreview:SetSize(344, 412)
    artPreview:SetPoint("CENTER", window, "CENTER", 0, 0)
    artPreview:SetFrameLevel(settings:GetFrameLevel() + 40)
    artPreview:SetClampedToScreen(true)
    artPreview:EnableMouse(true)
    artPreview.bg = fill(artPreview, 0.1, 0.1, 0.15, 1)
    label(artPreview, NS.L["ARTWORK PREVIEW"], 11, "TOPLEFT", 18, -15)
    local closeArt = button(artPreview, "X", 26, 24, function() artPreview:Hide() end)
    closeArt:SetPoint("TOPRIGHT", -8, -8)
    artPreview.themeName = label(artPreview, "", 16, "TOP", 0, -43)
    local prevArt = button(artPreview, "<", 30, 26, function() changeTheme(-1) end)
    prevArt:SetPoint("TOPLEFT", 22, -37)
    local nextArt = button(artPreview, ">", 30, 26, function() changeTheme(1) end)
    nextArt:SetPoint("TOPRIGHT", -22, -37)
    artPreview.ambient = artPreview:CreateTexture(nil, "BORDER")
    artPreview.ambient:SetPoint("TOP", 0, -72)
    artPreview.ambient:SetSize(256, 256)
    artPreview.ambient:SetTexCoord(0, 1, 0.20, 1)
    artPreview.headerArt = artPreview:CreateTexture(nil, "BORDER")
    artPreview.headerArt:SetPoint("TOP", 0, -32)
    artPreview.headerArt:SetSize(170, 34)
    artPreview.headerArt:SetTexCoord(0, 1, 0, 0.20)
    artPreview.image = artPreview:CreateTexture(nil, "ARTWORK")
    artPreview.image:SetPoint("TOP", 0, -72)
    artPreview.image:SetSize(256, 256)
    artPreview.emptyMessage = label(artPreview, NS.L["No artwork"], 15, "CENTER", 0, 0)
    local brightnessRow = CreateFrame("Frame", nil, artPreview)
    artPreview.brightnessRow = brightnessRow
    brightnessRow:SetPoint("TOPLEFT", 22, -337)
    brightnessRow:SetPoint("TOPRIGHT", -22, -337)
    brightnessRow:SetHeight(47)
    artPreview.brightness = slider(brightnessRow, 1, NS.L["Artwork brightness"], "artBrightness", 0.25, 1, 0.05, applyTheme)
    artPreview.notice = label(artPreview, "", 10, "BOTTOM", 0, 10)
    artPreview.notice:SetTextColor(0.65, 0.73, 0.81)
    artPreview:Hide()
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "ForeverWhisperArtPreview" end
    local previewArtButton = button(preview, NS.L["Preview art"], 108, 27, function()
        artPreview:Show()
        applyTheme()
    end)
    previewArtButton:SetPoint("RIGHT", artworkChoice, "LEFT", -8, 0)
    local t = themes[db.theme]
    settings.previewText:SetTextColor(t[5], t[6], t[7])
    settings.previewAccent:SetColorTexture(t[5], t[6], t[7], 1)
    applyTheme()
    settings:Hide()
end

showView = function(view)
    if NS.dropdownMenu then NS.dropdownMenu:Hide() end
    activeView = view
    if view ~= "chat" and window.urlCopy then window.urlCopy:Hide() end
    if view ~= "settings" and settings and settings.popupOptions then settings.popupOptions:Hide() end
    if view ~= "settings" and settings and settings.generalOptions then settings.generalOptions:Hide() end
    if settings and settings.artPreview then settings.artPreview:Hide() end
    if contactMenu then contactMenu:Hide() end
    if customEditor then customEditor:Hide() end
    if view ~= "chat" then NS.unreadBoundary, NS.jumpToUnread = nil, nil end
    if view ~= "chat" and input then input:ClearFocus() end
    if view ~= "search" and searchInput then searchInput:ClearFocus() end
    sidebar:SetShown(view == "chat")
    conversationView:SetShown(view == "chat")
    if settings then settings:SetShown(view == "settings") end
    if searchView then searchView:SetShown(view == "search") end
    if window.presence then window.presence:SetShown(view == "chat") end
    if palette then palette:Hide() end
    if actionMenu then actionMenu:Hide() end
    if newChat then newChat:Hide() end
    if window.contactFilter then window.contactFilter:ClearFocus() end
    window.settingsButton:SetText(view == "settings" and NS.L["Back"] or NS.L["Settings"])
    window.searchButton:SetText(view == "search" and NS.L["Back"] or NS.L["Search"])
    if view == "chat" then
        if current and db.conversations[current] then
            local c = db.conversations[current]
            local first = firstUnread(c)
            if first then NS.unreadBoundary, NS.jumpToUnread = first, true end
            c.unread = 0
        end
        refreshContacts()
        refreshMinimap()
        refreshTranscript(true)
    elseif view == "settings" then
        window.heading:SetText(NS.L["Preferences"])
    else
        window.heading:SetText(NS.L["Search"])
        if searchInput then searchInput:SetFocus() end
    end
end

local function showConversation(name, selectedKey)
    if inCombat() then
        DEFAULT_CHAT_FRAME:AddMessage(NS.L["Forever Whisper opens after combat; whispers remain in WoW chat for now."])
        return
    end
    makeWindow()
    local key = selectedKey or (name and conversation(name))
    if key then
        selectConversation(key)
    elseif current and db.conversations[current] then
        selectConversation(current)
    else
        local recent = names()
        if recent[1] then selectConversation(recent[1].key) end
    end
    showView("chat")
    window:Show()
end

local function chatFilter(_, event, ...)
    if not db or db.keepChat or inCombat() then return false end
    if event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM" then
        return NS.ResolveBNetID(select(13, ...)) ~= nil
    end
    return event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM"
end

SLASH_FOREVERWHISPER1 = "/fw"
SLASH_FOREVERWHISPER2 = "/foreverwhisper"
SlashCmdList.FOREVERWHISPER = function(command)
    command = (command or ""):match("^%s*(.-)%s*$")
    if command == "minimap" then
        db.showMinimap = not db.showMinimap
        refreshMinimap()
        DEFAULT_CHAT_FRAME:AddMessage(NS.L["Forever Whisper minimap button "] ..
            (db.showMinimap and NS.L["shown."] or NS.L["hidden. Use /fw minimap to show it again."]))
    elseif command == "popup" or command == "popup reset" then
        if combatPreview then
            if command == "popup reset" then combatPreview:ResetGeometry() end
            combatPreview:Arrange()
        end
    elseif command == "settings" or command == "config" then
        if inCombat() then
            DEFAULT_CHAT_FRAME:AddMessage(NS.L["Forever Whisper settings are available after combat."])
            return
        end
        makeWindow()
        makeSettings()
        showView("settings")
        window:Show()
    elseif command ~= "" then
        showConversation(command)
    else
        showConversation()
    end
end

local function positionMinimapButton()
    if not minimapButton then return end
    local angle = math.rad(db.minimapAngle)
    -- Place the speech bubble just beyond the minimap edge.
    local radius = (Minimap:GetWidth() or 140) / 2 + 12
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * radius, math.sin(angle) * radius)
end

local function makeMinimapButton()
    if minimapButton or not Minimap then return end
    minimapButton = CreateFrame("Button", "ForeverWhisperMinimapButton", Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\ForeverWhisper\\UI\\WhisperMark.tga")
    local badge = minimapButton:CreateTexture(nil, "OVERLAY")
    badge:SetSize(18, 16)
    badge:SetPoint("TOPRIGHT", 3, 3)
    badge:SetColorTexture(0.78, 0.19, 0.21, 1)
    minimapButton.badge = badge
    local badgeText = minimapButton:CreateFontString(nil, "OVERLAY")
    badgeText:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badgeText:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
    minimapButton.badgeText = badgeText
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Whisper", 0.45, 0.86, 0.90)
        GameTooltip:AddLine(NS.L["Left-click: open chats"], 1, 1, 1)
        GameTooltip:AddLine(NS.L["Right-click: settings"], 1, 1, 1)
        GameTooltip:AddLine(NS.L["Drag: move around minimap"], 0.75, 0.81, 0.87)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    minimapButton:SetScript("OnMouseDown", function(self)
        self.moved = false
    end)
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local centerX, centerY = Minimap:GetCenter()
            if not centerX or not centerY or not scale or scale == 0 then return end
            local dx, dy = x / scale - centerX, y / scale - centerY
            local angle
            if math.atan2 then
                angle = math.deg(math.atan2(dy, dx))
            elseif dx == 0 then
                angle = dy >= 0 and 90 or 270
            else
                angle = math.deg(math.atan(dy / dx))
                if dx < 0 then angle = angle + 180 end
            end
            db.minimapAngle = (angle + 360) % 360
            self.moved = true
            positionMinimapButton()
        end)
    end)
    minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    minimapButton:SetScript("OnClick", function(self, mouseButton)
        if self.moved then self.moved = false; return end
        if mouseButton == "RightButton" then
            SlashCmdList.FOREVERWHISPER("settings")
        elseif window and window:IsShown() then
            window:Hide()
        else
            showConversation()
        end
    end)
    positionMinimapButton()
    refreshMinimap()
end

FW:RegisterEvent("ADDON_LOADED")
StaticPopupDialogs["FOREVERWHISPER_IGNORE"] = {
    text = NS.L["Ignore %s? You will stop receiving their whispers."],
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, name)
        if C_FriendList and C_FriendList.AddIgnore then
            C_FriendList.AddIgnore(name)
        elseif AddIgnore then
            AddIgnore(name)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
StaticPopupDialogs["FOREVERWHISPER_CLEAR"] = {
    text = NS.L["Clear saved chat history with %s?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, key)
        local c = db and db.conversations[key]
        if c then
            c.messages = {}
            c.unread = 0
            if current == key then NS.unreadBoundary, NS.jumpToUnread = nil, nil end
            refreshTranscript()
            refreshContacts()
            refreshMinimap()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
StaticPopupDialogs["FOREVERWHISPER_DELETE"] = {
    text = NS.L["Delete the conversation with %s and all its saved messages? A new whisper will create it again."],
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, key)
        if not db or not db.conversations[key] then return end
        db.conversations[key], drafts[key], replyDrafts[key] = nil, nil, nil
        watchedPresence[key] = nil
        if combatPreview then combatPreview:DropOnline(key) end
        if contactEditor and contactEditor.key == key then contactEditor:Hide() end
        if messageMenu and messageMenu.key == key then messageMenu:Hide() end
        if searchJump and searchJump.key == key then searchJump = nil end
        if current == key then
            NS.unreadBoundary, NS.jumpToUnread = nil, nil
            if social then social:Stop() end
            current = nil
            if input then input:SetText(""); input:ClearFocus() end
            if updateReplyPreview then updateReplyPreview() end
        end
        if copyWindow then copyWindow:Hide(); copyBox:SetText("") end
        refreshContacts()
        refreshTranscript(true)
        refreshMinimap()
        if searchInput then performSearch() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
FW:SetScript("OnEvent", function(_, event, ...)
    if event == "GLOBAL_MOUSE_DOWN" then
        local menu=NS.dropdownMenu
        if menu and menu:IsShown() and not NS.MouseInsideRoots({menu,menu.owner}) then menu:Hide() end
        -- Outside clicks still release movement keys immediately. Remember only this
        -- Shift-click until its item OnClick runs, then discard the one-click intent.
        pendingLinkClick = nil
        if ... == "LeftButton" and input and input:IsShown() and input:HasFocus()
            and IsModifiedClick and IsModifiedClick("CHATLINK") and C_Timer and C_Timer.After then
            local click = {key=current}
            pendingLinkClick = click
        end
        NS.ReleaseOutsideFocus({window, copyWindow})
    elseif event == "GLOBAL_MOUSE_UP" then
        local click = pendingLinkClick
        if click then
            -- Item buttons run OnClick on release; expire after those handlers.
            C_Timer.After(0, function() if pendingLinkClick == click then pendingLinkClick = nil end end)
        end
    elseif event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        ForeverWhisperDB = type(ForeverWhisperDB) == "table" and ForeverWhisperDB or {}
        db = ForeverWhisperDB
        NS.SetLanguage(db.language)
        local dialogTexts = {
            FOREVERWHISPER_IGNORE = "Ignore %s? You will stop receiving their whispers.",
            FOREVERWHISPER_CLEAR = "Clear saved chat history with %s?",
            FOREVERWHISPER_DELETE = "Delete the conversation with %s and all its saved messages? A new whisper will create it again.",
        }
        for key, text in pairs(dialogTexts) do
            StaticPopupDialogs[key].text = NS.L[text]
            StaticPopupDialogs[key].button1, StaticPopupDialogs[key].button2 = NS.L["Yes"], NS.L["No"]
        end
        if db.artwork == nil and db.blossoms ~= nil then db.artwork = db.blossoms ~= false end
        db.blossoms = nil
        for key, value in pairs(defaults) do
            if db[key] == nil then db[key] = value end
        end
        if not db.schema or db.schema < 2 then
            if db.width == 650 then db.width = 720 end
            if db.height == 430 then db.height = 500 end
            if db.font == 1 then db.font = 2 end
            if db.theme == 1 then db.theme = 2 end
            db.schema = 2
        end
        if db.schema == 2 then
            if db.font == 2 then db.font = 5 end
            if db.theme == 2 then db.theme = 7 end
            db.schema = 3
        end
        db.shape = nil
        if not db.sakuraMigration then
            db.previousTheme = db.theme
            db.theme = 9
            db.sakuraMigration = true
        end
        if type(db.customActions) ~= "table" then db.customActions = {} end
        local valid = {}
        for _, action in ipairs(db.customActions) do
            if #valid >= 3 then break end
            local stock = type(action) == "table" and (
                (action.label == "Ask to group" and action.template == "Want to group up, {name}?") or
                (action.label == "Send my location" and action.template == "I'm in {zone}."))
            if not stock and type(action) == "table" and type(action.label) == "string" and type(action.template) == "string" then
                valid[#valid + 1] = { label = action.label:sub(1, 24), template = action.template:sub(1, 200) }
            end
        end
        db.customActions = valid
        db.recentEmoji = type(db.recentEmoji) == "table" and db.recentEmoji or {}
        while #db.recentEmoji > 16 do table.remove(db.recentEmoji) end
        db.width = clamp(db.width, 700, 1200)
        db.height = clamp(db.height, 480, 850)
        db.fontSize = clamp(db.fontSize, 10, 20)
        db.scale = clamp(db.scale, 0.7, 1.4)
        db.opacity = clamp(db.opacity, 0.2, 1)
        db.artBrightness = clamp(db.artBrightness, 0.25, 1)
        db.historyLimit = clamp(db.historyLimit, 20, 200)
        db.font = clamp(db.font, 1, #fonts)
        if db.soundChoice == 9 then db.soundChoice = 8 end -- Retired war horn: use the hunting horn.
        db.theme = clamp(db.theme, 1, #themes)
        db.minimapAngle = clamp(db.minimapAngle, 0, 360)
        db.conversations = type(db.conversations) == "table" and db.conversations or {}
        if db.identitySchema ~= 2 then
            db.conversations = NS.CanonicalConversations(db.conversations)
            db.identitySchema = 2
        end
        makeWindow()
        makeSettings()
        combatPreview = NS.CreateCombatPreview(currentStyle, db)
        combatPreview.onlineAllowed = function(key)
            local c = db.conversations[key]
            return c and c.notifyOnline and not c.muted and db.onlineNotifyMode ~= "chat" and contactPresence(c.name, c) == true
        end
        social = NS.NewSocial(function(name)
            local key = NS.PeerKey(name)
            for _, c in pairs(db.conversations) do if c.kind ~= "bnet" and NS.PeerKey(c.name) == key then return true end end
            return false
        end, function() return db.typing end, function()
            if window and window:IsShown() and activeView == "chat" and not inCombat() then
                refreshPresence()
                refreshContacts()
            end
        end)
        makeMinimapButton()
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", chatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", chatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", chatFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", chatFilter)
        FW:RegisterEvent("CHAT_MSG_WHISPER")
        FW:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
        FW:RegisterEvent("FRIENDLIST_UPDATE")
        if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("GLOBAL_MOUSE_DOWN") then
            FW:RegisterEvent("GLOBAL_MOUSE_DOWN")
        end
        if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("GLOBAL_MOUSE_UP") then
            FW:RegisterEvent("GLOBAL_MOUSE_UP")
        end
        FW:RegisterEvent("GUILD_ROSTER_UPDATE")
        FW:RegisterEvent("PLAYER_GUILD_UPDATE")
        FW:RegisterEvent("PLAYER_ENTERING_WORLD")
        FW:RegisterEvent("PLAYER_REGEN_DISABLED")
        FW:RegisterEvent("PLAYER_REGEN_ENABLED")
        FW:RegisterEvent("CHAT_MSG_ADDON")
        FW:RegisterEvent("CHAT_MSG_BN_WHISPER")
        FW:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")
        FW:RegisterEvent("BN_CONNECTED")
        FW:RegisterEvent("BN_DISCONNECTED")
        FW:RegisterEvent("BN_FRIEND_INFO_CHANGED")
        FW:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
        FW:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
        FW:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
        FW:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        NS.InvalidateBNet(false)
        NS.InvalidateFriends()
        makeMinimapButton()
        positionMinimapButton()
        guildPresenceDirty = true
        refreshWatchedPresence(true)
        if IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
            C_GuildInfo.GuildRoster()
        end
        if window and window:IsShown() and activeView == "chat" then refreshPresence(); refreshContacts() end
    elseif event == "BN_CONNECTED" or event == "BN_DISCONNECTED" or event == "BN_FRIEND_INFO_CHANGED" or event == "BN_FRIEND_LIST_SIZE_CHANGED"
        or event == "BN_FRIEND_ACCOUNT_ONLINE" or event == "BN_FRIEND_ACCOUNT_OFFLINE" then
        NS.InvalidateBNet(event == "BN_DISCONNECTED")
        refreshWatchedPresence(event == "BN_CONNECTED" or event == "BN_DISCONNECTED")
        if window and window:IsShown() and activeView == "chat" and not inCombat() then
            refreshPresence()
            refreshContacts()
        end
    elseif event == "CHAT_MSG_ADDON" then
        if social then social:Receive(...) end
    elseif event == "FRIENDLIST_UPDATE" then
        NS.InvalidateFriends()
        refreshWatchedPresence()
        if not inCombat() and window and window:IsShown() and activeView == "chat" then
            refreshPresence()
            refreshContacts()
        end
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        guildPresenceDirty = true
        refreshWatchedPresence()
        if not inCombat() and window and window:IsShown() and activeView == "chat" then
            refreshPresence()
            refreshContacts()
        end
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM"
        or event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM" then
        local message, author = ...
        if type(message) ~= "string" or type(author) ~= "string" then return end
        local bnet = event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM"
        local outgoing = event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM"
        local lineID, guid = select(11, ...)
        local bnetID = bnet and select(13, ...) or nil
        if bnet and not NS.ResolveBNetID(bnetID) then return end
        local key = addMessage(author, message, outgoing, lineID, guid, bnetID)
        if not key then return end
        if social and not bnet then
            if not outgoing then social:ClearTyping(author) end
            social:Probe(author)
        end
        if inCombat() then
            if not outgoing then
                if not db.conversations[key].muted then queuedInCombat = true end
                if db.combatPreview and combatPreview and not db.conversations[key].muted then
                    combatPreview:ShowWhisper(db.conversations[key].name,
                        renderEmoji(renderMapPins(bnet and NS.BNetDisplayMessage(message) or message)))
                end
            end
        else
            if window and window:IsShown() then
                if outgoing and (current ~= key or activeView ~= "chat") then
                    selectConversation(key)
                    showView("chat")
                elseif not current and activeView == "chat" then
                    selectConversation(key)
                elseif current == key and activeView == "chat" then
                    if transcript:GetScrollOffset() == 0 then db.conversations[key].unread = 0 end
                    refreshTranscript(true, true)
                end
                refreshContacts()
                refreshMinimap()
            else
                if outgoing or not db.conversations[key].muted then showConversation(nil, key) end
            end
            if not outgoing and db.sound and not db.conversations[key].muted then
                NS.PlayAlertSound()
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if social then social:Stop() end
        if combatPreview and combatPreview.kind ~= "online" then combatPreview:Reset(true) end
        wasOpenAtCombat = window and window:IsShown() or false
        if window then window:Hide() end
        if settings then settings:Hide() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if combatPreview and combatPreview.kind ~= "online" then combatPreview:Reset(true) end
        if queuedInCombat or wasOpenAtCombat then
            if queuedInCombat then
                local sorted = names()
                for _, item in ipairs(sorted) do
                    if not item.data.muted and item.data.unread and item.data.unread > 0 then
                        current = item.key
                        break
                    end
                end
            end
            showConversation()
            if current then selectConversation(current) end
        end
        queuedInCombat, wasOpenAtCombat = false, false
    end
end)
