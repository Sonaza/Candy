------------------------------------------------------------
-- Candy by Sonaza
------------------------------------------------------------

local ADDON_NAME, SHARED_DATA = ...;
local A, E = unpack(SHARED_DATA);

local AceConfig = LibStub("AceConfig-3.0");
local AceDialog = LibStub("AceConfigDialog-3.0");

local ldb = LibStub("LibDataBroker-1.1");

local ICON_PATTERN = "|T%s:12:12:0:0|t ";

function A:AddMessage(msg, ...)
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cfff54497Candy|r %s", string.format(msg, ...)));
end

local ValidateVisibilityCallback = function(script, broker)
	local f, scriptError = loadstring(string.format('return (function(text, icon) %s end)(...)', script or "return true;"), "Candy-Visibility-" .. broker);
	if(not f) then
		A:AddMessage("Error: %s", scriptError);
	else
		A:AddMessage("No script errors. Yay!");
	end
end

StaticPopupDialogs["CANDY_LUA_VISIBILITY_EDIT"] = {
	text = "Edit Custom Lua Visibility Callback for \"%s\":\124n\124nFunction receives two parameters: text and icon. It must return a boolean.",
	button1 = SAVE,
	button2 = "Validate",
	button3 = CANCEL,
	OnAccept = function(self, data)
		data.options.visibility.customLua = strtrim(self.editBox:GetText());
		ValidateVisibilityCallback(data.options.visibility.customLua, data.broker);
		
		self.editBox:SetText("");
	end,
	OnCancel = function(self, data)
		local script = strtrim(self.editBox:GetText());
		ValidateVisibilityCallback(script, data.broker);
		
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
	end,
	OnAlt = function(self, data)
		-- data.options.visibility.customLua = nil;
		-- A:UpdateCandy();
	end,
	
	hasEditBox = 1,
	whileDead = 1,
	timeout = 0,
};

local ValidateTextFilter = function(script, broker)
	local f, scriptError = loadstring(string.format('return (function(text) %s end)(...)', script or "return text;"), "Candy-TextFilter-" .. broker);
	if(not f) then
		A:AddMessage("Error: %s", scriptError);
	else
		A:AddMessage("No script errors. Yay!");
	end
end

StaticPopupDialogs["CANDY_LUA_TEXT_EDIT"] = {
	text = "Edit Lua Text Filter for \"%s\":\124n\124nFunction receives one parameter: text. It must return new output text.",
	button1 = SAVE,
	button2 = "Validate",
	button3 = CANCEL,
	OnAccept = function(self, data)
		data.options.luaTextFilter = strtrim(self.editBox:GetText());
		ValidateTextFilter(data.options.luaTextFilter, data.broker);
		
		self.editBox:SetText("");
		A:UpdateCandy();
	end,
	OnCancel = function(self, data)
		local script = strtrim(self.editBox:GetText());
		ValidateTextFilter(script, data.broker);
		
		return true;
	end,
	OnShow = function(self, data)
		self.defaultWidth = self.editBox:GetWidth();
		self.editBox:SetWidth(350);
		self.editBox:SetMaxLetters(0);
		self.editBox:SetText(data.options.luaTextFilter or "");
	end,
	OnHide = function(self)
		self.editBox:SetWidth(self.defaultWidth);
		ChatEdit_FocusActiveWindow();
		self.editBox:SetText("");
		self.defaultWidth = nil;
	end,
	OnAlt = function(self, data)
		-- data.options.luaTextFilter = nil;
		-- A:UpdateCandy();
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
		A:ResetAnchors();
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
				A:UnlockBars();
			end,
		},
		lock = {
			type = "execute",
			order = 2,
			name = "Lock",
			desc = "Lock Candy Bars",
			width = "half",
			func = function()
				A:LockBars();
			end,
		},
		-- enabled = {
		-- 	type = "toggle",
		-- 	order = 5,
		-- 	name = "Enable Candy Bars",
		-- 	desc = "Toggle all bars",
		-- 	width = "normal",
		-- 	set = function(self, value) A.db.global.enabled = value; end,
		-- 	get = function(self) return A.db.global.enabled; end,
		-- },
		
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
					values = function() return A:GetAddableBrokers(); end,
					set = function(self, value)
						selectedBroker = value;
					end,
					get = function(self) return selectedBroker; end,
				},
				add_selected = {
					type = "execute",
					order = 30,
					name = "Create",
					desc = "Creates a Candy bar for the selected DataBroker module.",
					width = "half",
					func = function()
						if(selectedBroker) then
							A:AddCandy(selectedBroker);
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
	                	A.db.global.fontFace = key;
	                	A:UpdateCandyBars();
	                end,
	                get = function()
	                	return A.db.global.fontFace;
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
						A:SetGlobalFontSize(value);
					end,
					get = function(self) return A.db.global.fontSize end,
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
						A:SetGlobalFontOutline(value);
					end,
					get = function(self)
						return A.db.global.fontOutline or "";
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
					values = function() return A.frameStrata; end,
					set = function(self, value)
						A:SetGlobalFrameStrata(A.frameStrata[value]);
					end,
					get = function(self)
						for k, v in ipairs(A.frameStrata) do
							if(A.db.global.frameStrata == v) then return k end;
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
			},
		},
	},
};

AceConfig:RegisterOptionsTable("Candy", options);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Candy", "Candy", nil);

function A:GetAddableBrokers()
	local brokers = {};
	
	for broker, data in ldb:DataObjectIterator() do
		if(not A.ActiveBars[broker]) then
			brokers[broker] = string.format("%s%s", ICON_PATTERN:format(data.icon), broker);
		end
	end
	
	return brokers;
end

function A:ShowOptions()
	PlaySound("igCharacterInfoOpen");
	
	-- /run ad=LibStub("AceConfigDialog-3.0");ad:SetDefaultSize("Candy", 580, 380);ad:Open("Candy");
	AceDialog:SetDefaultSize("Candy", 570, 380);
	AceDialog:Open("Candy");
end

function A:CloseOptions()
	AceDialog:Close("Candy");
	PlaySound("igCharacterInfoClose");
	
	GameTooltip:Hide();
end

function A:SetGlobalFontSize(newSize)
	for broker, candyBar in pairs(A.ActiveBars) do
		candyBar.data.fontSize = newSize;
		A:UpdateCandyText(broker);
	end
	
	self.db.global.fontSize = newSize;
end

function A:SetGlobalFontOutline(newOutline)
	for broker, candyBar in pairs(A.ActiveBars) do
		candyBar.data.fontOutline = newOutline;
		A:UpdateCandyText(broker);
	end
	
	self.db.global.fontOutline = newOutline;
end

function A:SetGlobalFrameStrata(newFrameStrata)
	for broker, candyBar in pairs(A.ActiveBars) do
		candyBar.data.frameStrata = newFrameStrata;
	end
	
	A:UpdateCandyBars();
	
	self.db.global.frameStrata = newFrameStrata;
end

function A:OpenCandyOptions(frame, broker)
	if(not A.ContextMenu) then
		A.ContextMenu = CreateFrame("Frame", "CandyMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	CloseMenus();
	
	local point, relative = A:GetAnchors(frame, false);
	local candyBar, module = A:GetCandy(broker);
	
	local frameStrataMenu = {
		{
			text = "Frame Strata", isTitle = true, notCheckable = true,
		},
	};
	
	for _, frameStrata in ipairs(A.frameStrata) do
		tinsert(frameStrataMenu, {
			text = frameStrata,
			func = function() candyBar.data.frameStrata = frameStrata; candyBar:SetFrameStrata(frameStrata); CloseMenus(); end,
			checked = function() return candyBar.data.frameStrata == frameStrata; end,
		});
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
			func = function() candyBar.data.showIcon = not candyBar.data.showIcon; A:UpdateCandyText(candyBar.broker); end,
			checked = function() return candyBar.data.showIcon; end,
			isNotRadio = true,
		},
		{
			text = "Force white text color",
			func = function() candyBar.data.stripColor = not candyBar.data.stripColor; A:UpdateCandyText(candyBar.broker); end,
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
					text = "Show only when Holding", isTitle = true, notCheckable = true,
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
						func = function() candyBar.data.fontSize = size; A:UpdateCandyText(broker); CloseMenus(); end,
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
					func = function() candyBar.data.fontOutline = nil; A:UpdateCandyText(candyBar.broker);CloseMenus(); end,
					checked = function() return candyBar.data.fontOutline == nil; end,
				},
				{
					text = "Thin Outline",
					func = function() candyBar.data.fontOutline = "OUTLINE"; A:UpdateCandyText(candyBar.broker); CloseMenus(); end,
					checked = function() return candyBar.data.fontOutline == "OUTLINE"; end,
				},
				{
					text = "Thick Outline",
					func = function() candyBar.data.fontOutline = "THICKOUTLINE"; A:UpdateCandyText(candyBar.broker); CloseMenus(); end,
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
					func = function() A:ChangeJustify(candyBar, "LEFT"); CloseMenus(); end,
					checked = function() return candyBar.data.justify == "LEFT"; end,
				},
				{
					text = "Center",
					func = function() A:ChangeJustify(candyBar, "CENTER"); CloseMenus(); end,
					checked = function() return candyBar.data.justify == "CENTER"; end,
				},
				{
					text = "Right",
					func = function() A:ChangeJustify(candyBar, "RIGHT"); CloseMenus(); end,
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
			func = function() A:RemoveCandy(candyBar.broker); end,
			notCheckable = true,
		},
	};
	
	A.ContextMenu:ClearAllPoints();
	A.ContextMenu:SetPoint(point, frame, relative, 0, 0);
	EasyMenu(contextMenuData, A.ContextMenu, frame, 0, 0, "MENU");
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, frame, relative, 0, 0);
	DropDownList1:SetClampedToScreen(true);
end
