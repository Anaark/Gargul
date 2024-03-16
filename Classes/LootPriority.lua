local L = Gargul_L;

---@type GL
local _, GL = ...;

GL.AceGUI = GL.AceGUI or LibStub("AceGUI-3.0");
local AceGUI = GL.AceGUI;

---@type Data
local CommActions = GL.Data.Constants.Comm.Actions;

---@type DB
local DB = GL.DB;

---@class LootPriority
GL.LootPriority = {};

---@type LootPriority
local LootPriority = GL.LootPriority;

--- Fetch an item's prio
---
---@param itemLink string
---@param itemName string|nil
---@return string|nil
function LootPriority:getPriority(itemLink, itemName)
    local itemID = GL:getItemIDFromLink(itemLink);
    itemName = itemName or GL:getItemNameFromLink(itemLink);

    return DB:get("LootPriority", {})[itemID]
        or DB:get("LootPriority", {})[itemName];
end

--- Append the loot prio as defined in DB:get("LootPriority to an item's tooltip
---
---@param itemLink string
---@return table
function LootPriority:tooltipLines(itemLink)
    local itemPriority = self:getPriority(itemLink, itemName);

    -- No prio defined for this item
    if (not itemPriority) then
        return {};
    end

    -- Add the header
    local Lines = { ("\n|c00efb8cd%s|r"):format(L.LOOTPRIORITY_TOOLTIP_HEADER) };

    -- Add the actual item prio
    for priorityLevel, value in pairs(itemPriority) do
        tinsert(Lines, string.format("|c008aecff    %s: %s", priorityLevel, value));
    end

    return Lines;
end

---@return void
function LootPriority:drawImporter()
    -- Create a container/parent frame
    local LootPriorityFrame = AceGUI:Create("Frame");
    LootPriorityFrame:SetTitle((L.WINDOW_HEADER):format(GL.version));
    LootPriorityFrame:SetStatusText(L.VERSION_ABBR ..GL.version);
    LootPriorityFrame:SetLayout("Flow");
    LootPriorityFrame:SetWidth(600);
    LootPriorityFrame:SetHeight(450);
    LootPriorityFrame.statustext:GetParent():Hide(); -- Hide the statustext bar

    -- Large edit box
    local LootPriorityBoxContent = "";
    local LootPriorityBox = AceGUI:Create("MultiLineEditBox");
    LootPriorityBox:SetFullWidth(true);
    LootPriorityBox:DisableButton(true);
    LootPriorityBox:SetFocus();
    LootPriorityBox:SetLabel(L.LOOTPRIORITY_FORMAT_EXPLANATION);
    LootPriorityBox:SetNumLines(22);
    LootPriorityBox:SetMaxLetters(999999999);
    LootPriorityFrame:AddChild(LootPriorityBox);
    LootPriorityBox:SetText(self:toCSV());

    LootPriorityBox:SetCallback("OnTextChanged", function(_, _, text)
        LootPriorityBoxContent = text;
    end)

    --[[
        FOOTER BUTTON PARENT FRAME
    ]]
    local FooterFrame = AceGUI:Create("SimpleGroup");
    FooterFrame:SetLayout("Flow");
    FooterFrame:SetFullWidth(true);
    FooterFrame:SetHeight(50);
    LootPriorityFrame:AddChild(FooterFrame);

    local SaveButton = AceGUI:Create("Button");
    SaveButton:SetText("Save");
    SaveButton:SetWidth(140);
    SaveButton:SetCallback("OnClick", function()
        self:save(LootPriorityBoxContent);
    end);
    FooterFrame:AddChild(SaveButton);

    local ClearButton = AceGUI:Create("Button");
    ClearButton:SetText("Clear");
    ClearButton:SetWidth(140);
    ClearButton:SetCallback("OnClick", function()
        LootPriorityBox:SetText("");
    end);
    FooterFrame:AddChild(ClearButton);

    local ShareButton = AceGUI:Create("Button");
    ShareButton:SetText("Share");
    ShareButton:SetWidth(140);
    ShareButton:SetCallback("OnClick", function()
        self:broadcast();
    end);
    FooterFrame:AddChild(ShareButton);
end

--- Translate the lootpriority table to CSV
---
---@return string
function LootPriority:toCSV()
    local LootPriorityCSV = "";

    for item, priority in pairs(DB:get("LootPriority", {}) or {}) do
        local priorityString = "";

        for index = 1, #priority do
            priorityString = string.format("%s > %s", priorityString, priority[index]);
        end

        LootPriorityCSV = string.format("%s%s %s\n", LootPriorityCSV, item, priorityString);
    end

    return LootPriorityCSV;
end

--- Save a given loot priority string
---
---@param data string
---@return void
function LootPriority:save(data)
    if (type(data) ~= "string") then
        return GL:warning(L.LOOTPRIORITY_INVALID_DATA);
    end

    -- Some TMB users use newlines in their item priority notes, let's remove those!
    data = data:gsub("\r\n", "");

    -- The user wishes to clear the loot priorities
    if (GL:empty(data)) then
        GL:success(L.LOOTPRIORITY_CLEAR_SUCCESSFUL);
        DB:set("LootPriority", {});
        return;
    end

    local LootPriorityData = {};
    for line in data:gmatch("[^\n]+") do
        local segments = GL:explode(line, ">");
        local segmentCount = #segments;

        if (segmentCount < 2) then
            return GL:warning((L.LOOTPRIORITY_INVALID_LINE):format(line));
        end

        local key = strtrim(segments[1]);

        if (tonumber(key) ~= nil) then
            key = tonumber(key);
        end

        LootPriorityData[key] = {};

        for segment = 2, segmentCount do
            local priority = strtrim(segments[segment]);

            tinsert(LootPriorityData[key], priority);
        end
    end

    DB:set("LootPriority", LootPriorityData);

    GL:success(L.LOOTPRIORITY_IMPORT_SUCCESSFUL);
end

--- Broadcast the loot priorities to the RAID / PARTY
---@return boolean
function LootPriority:broadcast()
    if (self.broadcastInProgress) then
        GL:error(L.BROADCAST_IN_PROGRESS_ERROR);
        return false;
    end

    if (GL.User.isInGroup and not GL.User.hasAssist
        and not GL.User.isMasterLooter
    ) then
        GL:warning(L.LM_OR_ASSIST_REQUIRED);
        return false;
    end

    local LootPriorityCSV = self:toCSV();
    -- Check if there's anything to share
    if (GL:empty(LootPriorityCSV)) then
        return false;
    end

    self.broadcastInProgress = true;
    GL.Events:fire("GL.LOOT_PRIORITY_BROADCAST_STARTED");

    local Broadcast = function ()
        GL:message(L.BROADCASTING_NOTIFICATION);

        local Label = GL.Interface:get(GL.LootPriority, "Label.BroadcastProgress");

        if (Label) then
            Label:SetText(L.BROADCASTING_NOTIFICATION);
        end

        GL.CommMessage.new{
            action = CommActions.broadcastLootPriorities,
            content = LootPriorityCSV,
            channel = "GROUP",
        }:send(function ()
            GL:success(L.BROADCAST_FINISHED);
            self.broadcastInProgress = false;
            GL.Events:fire("GL.LOOT_PRIORITY_BROADCAST_ENDED");

            Label = GL.Interface:get(GL.LootPriority, "Label.BroadcastProgress");
            if (Label) then
                Label:SetText(L.BROADCAST_FINISHED);
            end
        end, function (sent, total)
            Label = GL.Interface:get(GL.LootPriority, "Label.BroadcastProgress");
            if (Label) then
                Label:SetText(string.format(L.COMM_PROGRESS, sent, total));
            end
        end);
    end

    -- We're about to send a lot of data which will put strain on CTL
    -- Make sure we're out of combat before doing so!
    GL:afterCombatDo(function ()
        Broadcast();
    end, function ()
        GL:notice(L.BROADCAST_DELAYED_BY_COMBAT);
    end);

    return true;
end

--- Broadcast the loot priorities to the given player
---
---@param playerName string
---@return boolean
function LootPriority:broadcastToPlayer(playerName)
    local LootPriorityCSV = self:toCSV();
    -- Check if there's anything to share
    if (GL:empty(LootPriorityCSV)) then
        return false;
    end

    GL.CommMessage.new {
        action = CommActions.broadcastLootPriorities,
        content = LootPriorityCSV,
        channel = "WHISPER",
        recipient = playerName,
    }:send();
end

--- Process an incoming loot priority broadcast
---
---@param CommMessage CommMessage
function LootPriority:receiveBroadcast(CommMessage)
    -- No need to update our priorities if we broadcasted them ourselves
    if (CommMessage.Sender.isSelf) then
        GL:debug("LootPriority:receiveBroadcast received by self, skip");
        return true;
    end

    local priorities = CommMessage.content;
    if (type(priorities) == "string"
        and not GL:empty(priorities)
    ) then
        GL:warning((L.LOOTPRIORITY_PROCESS_INCOMING):format(CommMessage.Sender.name));

        self:save(priorities);
    end
end
