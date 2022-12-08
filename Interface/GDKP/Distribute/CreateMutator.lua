---@type GL
local _, GL = ...;

GL.AceGUI = GL.AceGUI or LibStub("AceGUI-3.0");
local AceGUI = GL.AceGUI;

---@type Events
local Events = GL.Events;

---@type GDKPSession
local GDKPSession = GL.GDKP.Session;

---@type GDKPPot
local GDKPPot = GL.GDKP.Pot;

---@type GDKPOverview
local Overview = GL.Interface.GDKP.Distribute.Overview;

---@type Interface
local Interface = GL.Interface;

---@class CreateMutator
GL.Interface.GDKP.Distribute.CreateMutator = {
    isVisible = false,
    session = nil,
};

---@type CreateMutator
local CreateMutator = GL.Interface.GDKP.Distribute.CreateMutator;

---@return Frame
function CreateMutator:build()
    GL:debug("Interface.GDKP.CreateMutator:build");

    local Window = AceGUI:Create("InlineGroup");
    Window:SetLayout("Flow");
    Window:SetWidth(200);
    Window:SetHeight(280);
    Window.frame:SetFrameStrata("HIGH");
    Window.frame:Show();
    Interface:set(self, "Window", Window);

    local Label = GL.AceGUI:Create("Label");
    Label:SetHeight(20);
    Label:SetFullWidth(true);
    Label:SetText("Create a new GDKP mutator");
    Window:AddChild(Label);

    local StorePermanently = AceGUI:Create("CheckBox");
    StorePermanently:SetValue(false);
    StorePermanently:SetLabel("Store for future sessions");
    StorePermanently:SetFullWidth(true);
    StorePermanently.text:SetTextColor(.99, .85, .06);
    StorePermanently.text:SetFontObject(_G["GameFontHighlightSmall"]);
    Interface:set(self, "StorePermanently", StorePermanently);
    Window:AddChild(StorePermanently);

    local Name = GL.AceGUI:Create("EditBox");
    Name:DisableButton(true);
    Name:SetHeight(20);
    Name:SetFullWidth(true);
    Name:SetLabel("Name [example: Tanks]");
    Interface:set(self, "Name", Name);
    Window:AddChild(Name);

    local Percentage = GL.AceGUI:Create("EditBox");
    Percentage:DisableButton(true);
    Percentage:SetHeight(20);
    Percentage:SetFullWidth(true);
    Percentage:SetLabel("Percentage [example: 10]");
    Interface:set(self, "Percentage", Percentage);
    Window:AddChild(Percentage);

    local Flat = GL.AceGUI:Create("EditBox");
    Flat:DisableButton(true);
    Flat:SetHeight(20);
    Flat:SetFullWidth(true);
    Flat:SetLabel("Flat gold rate [example: 250]");
    Interface:set(self, "Flat", Flat);
    Window:AddChild(Flat);

    local AutoApplyTo = GL.AceGUI:Create("EditBox");
    AutoApplyTo:DisableButton(true);
    AutoApplyTo:SetHeight(20);
    AutoApplyTo:SetFullWidth(true);
    AutoApplyTo:SetLabel("     Auto apply to");
    Interface:set(self, "AutoApplyTo", AutoApplyTo);
    Window:AddChild(AutoApplyTo);

    local HelpIcon = AceGUI:Create("Icon");
    HelpIcon:SetWidth(12);
    HelpIcon:SetHeight(12);
    HelpIcon:SetImageSize(12, 12);
    HelpIcon:SetImage("interface/friendsframe/informationicon");
    HelpIcon.frame:SetParent(Window.frame);
    HelpIcon.frame:SetPoint("BOTTOMLEFT", AutoApplyTo.frame, "BOTTOMLEFT", 2, 22);
    HelpIcon.frame:Show();

    HelpIcon:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(HelpIcon.frame, "ANCHOR_RIGHT");
        GameTooltip:AddLine(" ");
        GameTooltip:AddLine("You can automatically apply this mutator to raiders using keywords:");
        GameTooltip:AddLine(" ");

        for _, placeholder in pairs (GDKPPot.ValidAutoApplyPlaceholders) do
            GameTooltip:AddLine(string.format("|c00967FD2%s|r", placeholder));
        end

        GameTooltip:AddLine(" ");
        GameTooltip:AddLine("Example:");
        GameTooltip:AddLine("|c00967FD2SELF,RL,HEALER|r");
        GameTooltip:AddLine(" ");
        GameTooltip:Show();
    end);

    HelpIcon:SetCallback("OnLeave", function()
        GameTooltip:Hide();
    end);

    local Save = AceGUI:Create("Button");
    Save:SetText("Save");
    Save:SetFullWidth(true);
    Save:SetCallback("OnClick", function()
        local name = strtrim(Name:GetText());
        if (GL:empty(name)) then
            GL:warning("Add a mutator name");
            return;
        end

        local percentage = strtrim(Percentage:GetText());
        if (not GL:empty(percentage)
            and GL:empty(tonumber(percentage))
        ) then
            GL:warning("The percentage needs to be a number");
            return;
        end

        local flat = strtrim(Flat:GetText());
        if (not GL:empty(flat)
                and GL:empty(tonumber(flat))
        ) then
            GL:warning("The flat rate needs to be a number");
            return;
        end

        local autoApplyTo = strtrim(AutoApplyTo:GetText());
        local Session = GDKPSession:byID(self.sessionID);

        if (not Session) then
            GL:warning("Something went wrong while creating the session!");
            return;
        end

        local MutatorObj = {
            autoApplyTo = autoApplyTo,
            flat = flat,
            name = string.lower(name), -- We want name to be unique
            percentage = percentage,
        };

        local mutatorAdded = GDKPPot:addMutator(self.sessionID, MutatorObj);

        -- Something went wrong, no need to close the window
        if (not mutatorAdded) then
            GL:error("Something went wrong adding your mutator, fill the form out correctly!")
            return;
        end

        -- Store the mutator permanently so that we can use it in future sessions
        if (StorePermanently:GetValue()) then
            GL.Settings:set("GDKP.Mutators." .. name, MutatorObj);
        end

        Events:fire("GL.GDKP_MUTATOR_CREATED", MutatorObj);

        self:close();
    end);
    Window:AddChild(Save);

    local Cancel = AceGUI:Create("Button");
    Cancel:SetText("Cancel");
    Cancel:SetFullWidth(true);
    Cancel:SetCallback("OnClick", function()
        self:close();
    end);
    Window:AddChild(Cancel);

    return Window;
end

---@return Frame
function CreateMutator:window()
    GL:debug("Interface.GDKP.CreateMutator:window");

    local Window = Interface:get(self, "Window");

    if (not Window) then
        Window = self:build();
    end

    return Window;
end

--- Toggle the create session window that's anchored to the right side of the GDKP overview window
---
---@return void
function CreateMutator:toggle()
    GL:debug("Interface.GDKP.CreateMutator:toggle");

    if (self.isVisible) then
        return self:close();
    end

    self:open();
end

---@return void
function CreateMutator:open(sessionID)
    GL:debug("Interface.GDKP.CreateMutator:open");

    -- It seems our GDKP overview window is not opened
    if (not Overview.isVisible) then
        return;
    end

    self.sessionID = sessionID;

    local Window = self:window();

    self.isVisible = true;
    Interface:get(self, "CheckBox.StorePermanently"):SetValue(false);
    Window.frame:SetPoint("TOPLEFT", Interface:get(Overview, "GDKPDistribute").frame, "TOPRIGHT", 2, 16);
    Window.frame:Show();
end

---@return void
function CreateMutator:close()
    GL:debug("Interface.GDKP.CreateMutator:close");

    local Window = self:window();

    if (self.isVisible) then
        Window.frame:Hide();
        self.isVisible = false;
    end
end

GL:debug("Interface.GDKP.CreateMutator.lua");