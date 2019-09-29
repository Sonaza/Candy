------------------------------------------------------------
-- Candy by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, addon = ...;
local E = addon.E;

local AceConfig = LibStub("AceConfig-3.0");
local AceDialog = LibStub("AceConfigDialog-3.0");

local LibDataBroker = LibStub("LibDataBroker-1.1");

local ICON_PATTERN = "|T%s:12:12:0:0|t ";

function addon:AddMessage(msg, ...)
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cfff54497Candy|r %s", string.format(msg, ...)));
end

local ValidateVisibilityCallback = function(script, broker)
	if (script and strtrim(script) == "") then
		addon:AddMessage("Script is empty. Visibility callback will be cleared.");
		return;
	end
	
	local script = string.format('return (function(text, icon) %s end)(...)', script or "return true;");
	local compiled, scriptError = loadstring(script, "Candy-Visibility-" .. broker);
	
	if (not compiled) then
		addon:AddMessage("Error: %s", scriptError);
	else
		local _, module = addon:GetCandy(broker);
		if (not module) then return end
		
		local text = module.text or module.label or broker or "";
		
		local success, result = pcall(compiled, text, module.icon or "");
		if (success) then
			addon:AddMessage("No script syntax errors. Yay!");
			
			if (type(result) == "string") then
				addon:AddMessage("Visibility callback returns a string but it may not be intentional. Did you mean to set text filter instead?");
			elseif (type(result) ~= "boolean" and type(result) ~= "nil") then
				addon:AddMessage("Visibility callback returns a %s but it may not be intentional. Please re-check the callback script.", type(result));
			end
		else
			addon:AddMessage("Error: %s", result);
		end
	end
end

StaticPopupDialogs["CANDY_LUA_VISIBILITY_EDIT"] = {
	text = "Edit Custom Lua Visibility Callback for \"%s\":\124n\124nFunction receives two parameters: text (without color) and icon. It must return a boolean or nil. True is visible.",
	button1 = SAVE,
	button2 = "Validate",
	button3 = CANCEL,
	OnAccept = function(self, data)
		data.options.visibility.customLua = strtrim(self.editBox:GetText());
		if (data.options.visibility.customLua and data.options.visibility.customLua ~= "") then
			ValidateVisibilityCallback(data.options.visibility.customLua, data.broker);
		else
			addon:AddMessage("Cleared custom visibility condition.");
			data.options.visibility.customLua = nil;
		end
		
		addon:MarkForRecompile(data.broker);
		
		self.editBox:SetText("");
	end,
	OnCancel = function(self, data)
		local script = strtrim(self.editBox:GetText());
		ValidateVisibilityCallback(script, data.broker);
		
		addon:MarkForRecompile(data.broker);
		
		return true;
	end,
	OnShow = function(self, data)
		self.defaultWidth = self.editBox:GetWidth();
		self.editBox:SetWidth(350);
		self.editBox:SetMaxLetters(0);
		self.editBox:SetText(data.options.visibility.customLua or "");
	end,
	OnHide = function(self, data)
		self.editBox:SetWidth(self.defaultWidth);
		ChatEdit_FocusActiveWindow();
		self.editBox:SetText("");
		self.defaultWidth = nil;
		
		addon:MarkForRecompile(data.broker);
	end,
	
	hasEditBox = 1,
	whileDead = 1,
	timeout = 0,
};

local ValidateTextFilter = function(script, broker)
	if (script and strtrim(script) == "") then
		addon:AddMessage("Script is empty. Text filter will be cleared.");
		return;
	end
	
	local script = string.format('return (function(text) %s end)(...)', script or "return text;");
	local compiled, scriptError = loadstring(script, "Candy-TextFilter-" .. broker);
	
	if (not compiled) then
		addon:AddMessage("Error: %s", scriptError);
	else
		local _, module = addon:GetCandy(broker);
		if (not module) then return end
		
		local text = module.text or module.label or broker or "";
		
		local success, result = pcall(compiled, text);
		if (success) then
			addon:AddMessage("No script syntax errors. Yay!");
			
			if (type(result) == "boolean") then
				addon:AddMessage("Text filter returns a boolean but it may not be intentional. Did you mean to set visibility condition instead?");
			elseif (type(result) ~= "string" and type(result) ~= "number") then
				addon:AddMessage("Text filter returns a %s but it may not be intentional. Please re-check the callback script.", type(result));
			end
		
			addon:AddMessage("Resulting output: %s", tostring(result));
		else
			addon:AddMessage("Error: %s", result);
		end
	end
end

StaticPopupDialogs["CANDY_LUA_TEXT_EDIT"] = {
	text = "Edit Lua Text Filter for \"%s\":\124n\124nFunction receives one parameter: text. It must return new output text (string or number).",
	button1 = SAVE,
	button2 = "Validate",
	button3 = CANCEL,
	OnAccept = function(self, data)
		data.options.luaTextFilter = strtrim(self.editBox:GetText());
		if (data.options.luaTextFilter and data.options.luaTextFilter ~= "") then
			ValidateTextFilter(data.options.luaTextFilter, data.broker);
		else
			addon:AddMessage("Cleared custom text filter.");
			data.options.luaTextFilter = nil;
		end
		
		addon:MarkForRecompile(data.broker);
		
		self.editBox:SetText("");
		addon:UpdateCandyBars();
	end,
	OnCancel = function(self, data)
		local script = strtrim(self.editBox:GetText());
		ValidateTextFilter(script, data.broker);
		
		addon:MarkForRecompile(data.broker);
		
		return true;
	end,
	OnShow = function(self, data)
		self.defaultWidth = self.editBox:GetWidth();
		self.editBox:SetWidth(350);
		self.editBox:SetMaxLetters(0);
		self.editBox:SetText(data.options.luaTextFilter or "");
	end,
	OnHide = function(self, data)
		self.editBox:SetWidth(self.defaultWidth);
		ChatEdit_FocusActiveWindow();
		self.editBox:SetText("");
		self.defaultWidth = nil;
		
		addon:MarkForRecompile(data.broker);
	end,
	
	hasEditBox = 1,
	whileDead = 1,
	timeout = 0,
};

StaticPopupDialogs["CANDY_SET_FIXED_WIDTH"] = {
	text = "Edit width for \"%s\":",
	button1 = SAVE,
	button3 = CANCEL,
	OnAccept = function(self, data)
		local widthValue = tonumber(self.editBox:GetText()) or 0;
		data.options.fixedWidth = widthValue;
		
		if (widthValue == 0) then
			print("Using invalid or zero width reverts back to dynamic width.");
		end
		
		addon:UpdateCandyBars();
		addon:UpdateCandyText(data.broker);
	end,
	EditBoxOnEnterPressed = function(self, data)
		local parent = self:GetParent();
		
		local widthValue = tonumber(parent.editBox:GetText()) or 0;
		data.options.fixedWidth = widthValue;
		
		if (widthValue == 0) then
			print("Using invalid or zero width reverts back to dynamic width.");
		end
		
		addon:UpdateCandyBars();
		addon:UpdateCandyText(data.broker);
		
		parent:Hide();
	end,
	OnCancel = function(self, data)
		return true;
	end,
	OnShow = function(self, data)
		self.editBox:SetText(data.options.fixedWidth or "0");
	end,
	OnHide = function(self, data)
		ChatEdit_FocusActiveWindow();
		self.editBox:SetText("");
	end,
	hasEditBox = 1,
	whileDead = 1,
	timeout = 0,
};

StaticPopupDialogs["CANDY_RESET_ANCHORS"] = {
	text = "Are you sure you want to reset anchors? This action cannot be reversed.",
	button1 = YES,
	button2 = CANCEL,
	OnAccept = function()
		addon:ResetAnchors();
	end,
	whileDead = 1,
	timeout = 0,
};

local selectedBroker = nil;

local options = {
	type = "group",
	name = "Candy",
	desc = "Candy Options",
	args = {
		unlock = {
			type = "execute",
			order = 1,
			name = "Unlock",
			desc = "Unlock Candy Bars",
			width = "half",
			func = function()
				addon:UnlockBars();
			end,
		},
		lock = {
			type = "execute",
			order = 2,
			name = "Lock",
			desc = "Lock Candy Bars",
			width = "half",
			func = function()
				addon:LockBars();
			end,
		},
		
		candybars_group = {
			type = "group",
			name = "Candy Bars",
			desc = "General Options",
			inline = true,
			order = 10,
			args = {
				add_candy_select = {
					type = "select",
					order = 10,
					name = "Create a New Candy Bar",
					desc = "Select a Broker module to be added.",
					style = "dropdown",
					values = function() return addon:GetAddableBrokers(); end,
					set = function(self, value)
						selectedBroker = value;
					end,
					get = function(self) return selectedBroker; end,
				},
				add_selected = {
					type = "execute",
					order = 20,
					name = "Create",
					desc = "Creates a Candy bar for the selected DataBroker module.",
					width = "half",
					func = function()
						if (selectedBroker) then
							addon:AddCandy(selectedBroker);
							selectedBroker = nil;
						end
					end,
				},
				
				remove_candy_select = {
					type = "select",
					order = 40,
					name = "Remove a New Candy Bar",
					desc = "Select a Broker module to be removed.",
					style = "dropdown",
					values = function() return addon:GetActiveBrokers(); end,
					set = function(self, value)
						selectedBroker = value;
					end,
					get = function(self) return selectedBroker; end,
				},
				remove_selected = {
					type = "execute",
					order = 50,
					name = "Remove",
					desc = "Removes a Candy bar for the selected DataBroker module.",
					width = "half",
					func = function()
						if (selectedBroker) then
							addon:RemoveCandy(selectedBroker);
							selectedBroker = nil;
						end
					end,
				},
			},
		},
		
		font_options_group = {
			type = "group",
			name = "Font Options",
			desc = "Font Options",
			inline = true,
			order = 30,
			args = {
				font_face = {
	                name = "Set Font Face",
	                desc = "Set the text font face for all Candy bars.",
	                type = "select",
					dialogControl = 'LSM30_Font',
					values = AceGUIWidgetLSMlists.font,
	                order = 10,
	                set = function(self, key)
	                	addon.db.global.fontFace = key;
	                	addon:UpdateCandyBars();
	                end,
	                get = function()
	                	return addon.db.global.fontFace;
	                end,
	            },
				font_size = {
					type = "select",
					order = 20,
					name = "Change Font Size",
					desc = "Globally set the font size of all current and future Candy bars.|n|nNote: This will override any bar-specific changes you have made!",
					style = "dropdown",
					values = function()
						local fsize = {};
						for i = 8, 16 do fsize[i] = i; end
						return fsize;
					end,
					set = function(self, value)
						addon:SetGlobalFontSize(value);
					end,
					get = function(self) return addon.db.global.fontSize end,
				},
				font_outline = {
					type = "select",
					order = 30,
					name = "Change Font Outline",
					desc = "Globally sets the font outline of all current and future Candy bars.|n|nNote: This will override any bar-specific changes you have made!",
					style = "dropdown",
					values = function()
						return {
							[""]				= "None",
							["OUTLINE"]			= "Thin Outline",
							["THICKOUTLINE"]	= "Thick Outline",
						};
					end,
					set = function(self, value)
						addon:SetGlobalFontOutline(value);
					end,
					get = function(self)
						return addon.db.global.fontOutline or "";
					end,
				},
			},
		},
				
		frame_options_group = {
			type = "group",
			name = "Frame Options",
			desc = "Frame Options",
			inline = true,
			order = 30,
			args = {
				frame_strata = {
					type = "select",
					order = 10,
					name = "Set Frame Strata",
					desc = "Globally set frame strata of all current and future Candy bars.|n|nNote: This will override any bar-specific changes you have made!",
					style = "dropdown",
					values = function() return addon.frameStrata; end,
					set = function(self, value)
						addon:SetGlobalFrameStrata(addon.frameStrata[value]);
					end,
					get = function(self)
						for k, v in ipairs(addon.frameStrata) do
							if (addon.db.global.frameStrata == v) then return k end;
						end
						
						return 0;
					end,
				},
				reset_anchors = {
					type = "execute",
					order = 30,
					name = "Reset Anchors",
					desc = "Reposition all Candy bars to the middle of screen.",
					func = function()
						StaticPopup_Show("CANDY_RESET_ANCHORS");
					end,
				},
				background_color = {
					type = "color",
					order = 50,
					name = "Background Color",
					desc = "Set a global background color for all the current and new bars.|n|nChanging the value overrides all current colors but the color can be set per bar basis after.",
					set = function(self, r, g, b, a)
						if (addon.db.global.locked) then
							addon:UnlockBars();
							addon:ToggleConfigBackground(false);
						end
						addon:SetGlobalBackgroundColor(r, g, b, a);
					end,
					get = function(self)
						local r, g, b, a = unpack(addon.db.global.backgroundColor);
						return r, g, b, a;
					end,
					hasAlpha = true,
				},
			},
		},
	},
};

AceConfig:RegisterOptionsTable("Candy", options);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Candy", "Candy", nil);

function addon:GetAddableBrokers()
	local brokers = {};
	
	for broker, data in LibDataBroker:DataObjectIterator() do
		if (not addon.ActiveBars[broker]) then
			brokers[broker] = string.format("%s%s", data.icon and ICON_PATTERN:format(data.icon) or "", broker);
		end
	end
	
	return brokers;
end

function addon:GetActiveBrokers()
	local brokers = {};
	
	for broker, candyBar in pairs(addon.ActiveBars) do
		local _, data = addon:GetCandy(broker);
		brokers[broker] = string.format("%s%s", data.icon and ICON_PATTERN:format(data.icon) or "", broker);
	end
	
	return brokers;
end

function addon:ShowOptions()
	AceDialog:SetDefaultSize("Candy", 570, 380);
	AceDialog:Open("Candy");
end

function addon:CloseOptions()
	AceDialog:Close("Candy");
	GameTooltip:Hide();
end

function addon:SetGlobalFontSize(newSize)
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar.data.fontSize = newSize;
		addon:UpdateCandyText(broker);
	end
	
	self.db.global.fontSize = newSize;
end

function addon:SetGlobalFontOutline(newOutline)
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar.data.fontOutline = newOutline;
		addon:UpdateCandyText(broker);
	end
	
	self.db.global.fontOutline = newOutline;
end

function addon:SetGlobalFrameStrata(newFrameStrata)
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar.data.frameStrata = newFrameStrata;
	end
	
	addon:UpdateCandyBars();
	
	self.db.global.frameStrata = newFrameStrata;
end

function addon:ColorPicker_OnShow()
	if (not self.db.global.locked) then
		addon:ToggleConfigBackground(false);
	end
end

function addon:ColorPicker_OnHide()
	if (not self.db.global.locked) then
		addon:ToggleConfigBackground(true);
	end
end

function addon:SetGlobalBackgroundColor(r, g, b, a)
	addon.db.global.backgroundColor = { r, g, b, a };
	
	for broker, candyBar in pairs(addon.ActiveBars) do
		candyBar.data.backgroundColor = { r, g, b, a };
		candyBar.background:SetVertexColor(r, g, b, a);
	end
end

function addon:SetBarBackgroundColor(candyBar, r, g, b, a)
	if (candyBar) then
		candyBar.data.backgroundColor = { r, g, b, a };
		candyBar.background:SetVertexColor(r, g, b, a);
	end
end

function addon:OpenCandyOptions(frame, broker)
	if (not addon.ContextMenu) then
		addon.ContextMenu = CreateFrame("Frame", "CandyMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	CloseMenus();
	
	local point, relative = addon:GetAnchors(frame, false);
	local candyBar, module = addon:GetCandy(broker);
	
	local frameStrataMenu = {
		{
			text = "Frame Strata", isTitle = true, notCheckable = true,
		},
	};
	
	for _, frameStrata in ipairs(addon.frameStrata) do
		tinsert(frameStrataMenu, {
			text = frameStrata,
			func = function() candyBar.data.frameStrata = frameStrata; candyBar:SetFrameStrata(frameStrata); CloseMenus(); end,
			checked = function() return candyBar.data.frameStrata == frameStrata; end,
		});
	end
	
	local fixedWidthLabel = "|cffffd100Use fixed width|r";
	if (candyBar.data.fixedWidth > 0) then
		fixedWidthLabel = string.format("|cffffd100Use fixed width|r (currently %d pixels)", candyBar.data.fixedWidth);
	end
	
	local contextMenuData = {
		{
			text = string.format("Candy Options: |cffffffff%s|r", broker), isTitle = true, notCheckable = true,
		},
		{
			text = "Show tooltip on hover",
			func = function() candyBar.data.showTooltip = not candyBar.data.showTooltip; end,
			checked = function() return candyBar.data.showTooltip; end,
			isNotRadio = true,
		},
		{
			text = "Make click-through",
			func = function() candyBar.data.isClickthrough = not candyBar.data.isClickthrough; end,
			checked = function() return candyBar.data.isClickthrough; end,
			isNotRadio = true,
		},
		{
			text = "Show icon",
			func = function()
				candyBar.data.showIcon = not candyBar.data.showIcon;
				if (not candyBar.data.showText) then
					candyBar.data.showText = true;
					addon:AddMessage("Toggling text back on for '%s' candy bar.", candyBar.broker);
				end
				addon:UpdateCandyText(candyBar.broker);
			end,
			checked = function() return candyBar.data.showIcon; end,
			isNotRadio = true,
		},
		{
			text = "Show text",
			func = function()
				candyBar.data.showText = not candyBar.data.showText;
				if (not candyBar.data.showIcon) then
					candyBar.data.showIcon = true;
					addon:AddMessage("Toggling icon back on for '%s' candy bar.", candyBar.broker);
				end
				addon:UpdateCandyText(candyBar.broker);
			end,
			checked = function() return candyBar.data.showText; end,
			isNotRadio = true,
		},
		{
			text = "Force white text color",
			func = function() candyBar.data.stripColor = not candyBar.data.stripColor; addon:UpdateCandyText(candyBar.broker); end,
			checked = function() return candyBar.data.stripColor; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Lua text filter",
			func = function()
				StaticPopup_Show("CANDY_LUA_TEXT_EDIT", candyBar.broker, nil, {
					broker = candyBar.broker,
					options = candyBar.data,
				});
			end,
			checked = function() return candyBar.data.luaTextFilter ~= nil; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "|cffffd100Width options|r",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Width options", isTitle = true, notCheckable = true,
				},
				{
					text = "|cffffd100Dynamic width|r (fit to text)",
					func = function()
						candyBar.data.fixedWidth = 0;
						addon:UpdateCandyText(candyBar.broker);
						CloseMenus();
					end,
					checked = function() return candyBar.data.fixedWidth == 0; end,
				},
				{
					text = fixedWidthLabel,
					func = function()
						StaticPopup_Show("CANDY_SET_FIXED_WIDTH", candyBar.broker, nil, {
							broker = candyBar.broker,
							options = candyBar.data,
						});
						CloseMenus();
					end,
					checked = function() return candyBar.data.fixedWidth > 0; end,
				},
			},
		},
		{
			text = "Background color",
			extraInfo = "very",
			func = UIDropDownMenuButton_OpenColorPicker,
			hasColorSwatch = true,
			hasOpacity = true,
			swatchFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB();
				local a = 1 - OpacitySliderFrame:GetValue();
				addon:SetBarBackgroundColor(candyBar, r, g, b, a);
			end,
			opacityFunc = function()
				local r, g, b = ColorPickerFrame:GetColorRGB();
				local a = 1 - OpacitySliderFrame:GetValue();
				addon:SetBarBackgroundColor(candyBar, r, g, b, a);
			end,
			cancelFunc = function(pv)
				addon:SetBarBackgroundColor(candyBar, pv.r, pv.g, pv.b, pv.opacity);
			end,
			r = candyBar.data.backgroundColor[1] or 0,
			g = candyBar.data.backgroundColor[2] or 0,
			b = candyBar.data.backgroundColor[3] or 0,
			opacity = 1 - (candyBar.data.backgroundColor[4] or 0),
			notCheckable = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "|cffffd100Visiblity Options|r",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Combat Status", isTitle = true, notCheckable = true,
				},
				{
					text = "Show in and out of combat",
					func = function() candyBar.data.visibility.mode = E.VISIBILITY_ALWAYS; end,
					checked = function() return candyBar.data.visibility.mode == E.VISIBILITY_ALWAYS; end,
				},
				{
					text = "Show only in combat",
					func = function() candyBar.data.visibility.mode = E.VISIBILITY_IN_COMBAT; end,
					checked = function() return candyBar.data.visibility.mode == E.VISIBILITY_IN_COMBAT; end,
				},
				{
					text = "Show only out of combat",
					func = function() candyBar.data.visibility.mode = E.VISIBILITY_OUT_OF_COMBAT; end,
					checked = function() return candyBar.data.visibility.mode == E.VISIBILITY_OUT_OF_COMBAT; end,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Instance Status", isTitle = true, notCheckable = true,
				},
				{
					text = "Show everywhere",
					func = function() candyBar.data.visibility.instanceMode = E.INSTANCEMODE_EVERYWHERE; end,
					checked = function() return candyBar.data.visibility.instanceMode == E.INSTANCEMODE_EVERYWHERE; end,
				},
				{
					text = "Show only while in instances",
					func = function() candyBar.data.visibility.instanceMode = E.INSTANCEMODE_INSIDE; end,
					checked = function() return candyBar.data.visibility.instanceMode == E.INSTANCEMODE_INSIDE; end,
				},
				{
					text = "Do not show while in instances",
					func = function() candyBar.data.visibility.instanceMode = E.INSTANCEMODE_OUTSIDE; end,
					checked = function() return candyBar.data.visibility.instanceMode == E.INSTANCEMODE_OUTSIDE; end,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Group Status", isTitle = true, notCheckable = true,
				},
				{
					text = "Show always",
					func = function() candyBar.data.visibility.groupMode = E.GROUPMODE_ALWAYS; end,
					checked = function() return candyBar.data.visibility.groupMode == E.GROUPMODE_ALWAYS; end,
				},
				{
					text = "Only when solo",
					func = function() candyBar.data.visibility.groupMode = E.GROUPMODE_SOLO; end,
					checked = function() return candyBar.data.visibility.groupMode == E.GROUPMODE_SOLO; end,
				},
				{
					text = "Only when in party or raid",
					func = function() candyBar.data.visibility.groupMode = E.GROUPMODE_INPARTY; end,
					checked = function() return candyBar.data.visibility.groupMode == E.GROUPMODE_INPARTY; end,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Show only when holding", isTitle = true, notCheckable = true,
				},
				{
					text = "CTRL",
					func = function() candyBar.data.visibility.showCtrl = not candyBar.data.visibility.showCtrl; end,
					checked = function() return candyBar.data.visibility.showCtrl; end,
					isNotRadio = true,
				},
				{
					text = "SHIFT",
					func = function() candyBar.data.visibility.showShift = not candyBar.data.visibility.showShift; end,
					checked = function() return candyBar.data.visibility.showShift; end,
					isNotRadio = true,
				},
				{
					text = "ALT",
					func = function() candyBar.data.visibility.showAlt = not candyBar.data.visibility.showAlt; end,
					checked = function() return candyBar.data.visibility.showAlt; end,
					isNotRadio = true,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Miscellaneous", isTitle = true, notCheckable = true,
				},
				{
					text = "Hide when pet battling",
					func = function() candyBar.data.visibility.hideInPetBattle = not candyBar.data.visibility.hideInPetBattle; end,
					checked = function() return candyBar.data.visibility.hideInPetBattle; end,
					isNotRadio = true,
				},
				{
					text = "Custom Lua condition",
					func = function()
						StaticPopup_Show("CANDY_LUA_VISIBILITY_EDIT", candyBar.broker, nil, {
							broker = candyBar.broker,
							options = candyBar.data,
						});
					end,
					checked = function() return candyBar.data.visibility.customLua ~= nil; end,
					isNotRadio = true,
				},
			},
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = string.format("|cffffd100Font Size:|r %d", candyBar.data.fontSize),
			notCheckable = true,
			hasArrow = true,
			menuList = (function()
				local fontSizeMenu = {
					{
						text = "Font Size", isTitle = true, notCheckable = true,
					},
				};
				
				for size = 8, 16 do
					tinsert(fontSizeMenu, {
						text = tostring(size),
						func = function() candyBar.data.fontSize = size; addon:UpdateCandyText(broker); CloseMenus(); end,
						checked = function() return candyBar.data.fontSize == size; end,
					});
				end
				
				return fontSizeMenu;
			end)(),
		},
		{
			text = string.format("|cffffd100Font Outline:|r %s", candyBar.data.fontOutline or "None"),
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Font Outline", isTitle = true, notCheckable = true,
				},
				{
					text = "None",
					func = function() candyBar.data.fontOutline = nil; addon:UpdateCandyText(candyBar.broker);CloseMenus(); end,
					checked = function() return candyBar.data.fontOutline == nil; end,
				},
				{
					text = "Thin Outline",
					func = function() candyBar.data.fontOutline = "OUTLINE"; addon:UpdateCandyText(candyBar.broker); CloseMenus(); end,
					checked = function() return candyBar.data.fontOutline == "OUTLINE"; end,
				},
				{
					text = "Thick Outline",
					func = function() candyBar.data.fontOutline = "THICKOUTLINE"; addon:UpdateCandyText(candyBar.broker); CloseMenus(); end,
					checked = function() return candyBar.data.fontOutline == "THICKOUTLINE"; end,
				},
			},
		},
		{
			text = string.format("|cffffd100Justify Text:|r %s", candyBar.data.justify),
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Justify Text", isTitle = true, notCheckable = true,
				},
				{
					text = "Left",
					func = function() addon:ChangeJustify(candyBar, "LEFT"); CloseMenus(); end,
					checked = function() return candyBar.data.justify == "LEFT"; end,
				},
				{
					text = "Center",
					func = function() addon:ChangeJustify(candyBar, "CENTER"); CloseMenus(); end,
					checked = function() return candyBar.data.justify == "CENTER"; end,
				},
				{
					text = "Right",
					func = function() addon:ChangeJustify(candyBar, "RIGHT"); CloseMenus(); end,
					checked = function() return candyBar.data.justify == "RIGHT"; end,
				},
			},
		},
		{
			text = string.format("|cffffd100Frame Strata:|r %s", candyBar.data.frameStrata),
			notCheckable = true,
			hasArrow = true,
			menuList = frameStrataMenu,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Remove Candy Bar",
			func = function() addon:RemoveCandy(candyBar.broker); end,
			notCheckable = true,
		},
	};
	
	addon.ContextMenu:ClearAllPoints();
	addon.ContextMenu:SetPoint(point, frame, relative, 0, 0);
	EasyMenu(contextMenuData, addon.ContextMenu, frame, 0, 0, "MENU");
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, frame, relative, 0, 0);
	DropDownList1:SetClampedToScreen(true);
end
