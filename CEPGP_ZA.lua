local addonName, addon = ...

local origAddRaidEP;

CEPGP_ZA = {

	enabled = true,
	zoneAward = true,
	suppressMessages = false,
	includeKills = false,

};

-- Hook original AddRaidEP function

function CEPGP_ZA_hook()
	origAddRaidEP = CEPGP_AddRaidEP;
	CEPGP_AddRaidEP = function(...)
		local amount, msg, encounter = ...;
		local ZA_GuildRoster = "";
		local ZA_RaidRoster = "";
		local notInZone = {};
		if CEPGP_Info.Guild then
			ZA_GuildRoster = CEPGP_Info.Guild.Roster or CEPGP_roster;
		else
			ZA_GuildRoster = CEPGP_roster;
		end
		if CEPGP_Info.Raid then
			ZA_RaidRoster = CEPGP_Info.Raid.Roster or CEPGP_raidRoster;
		else
			ZA_RaidRoster = CEPGP_raidRoster;
		end
		
		if CEPGP_ZA.enabled and ((CEPGP_ZA.zoneAward and not encounter) or (encounter and CEPGP_ZA.includeKills)) then
			amount = math.floor(amount);
			local success, failMsg = pcall(function()
				
				local myzone = GetRealZoneText();

				local function update()
					if msg ~= "" and msg ~= nil or encounter then
						if encounter then -- a boss was killed
							CEPGP_addTraffic("Raid", PLAYER_NAME, "Add Raid EP +" .. amount .. " to those in " ..myzone .. " - " .. encounter, "", "", "", "", "", time());
							CEPGP_sendChatMessage(msg, CEPGP.Channel);
						else -- EP was manually given, could be either positive or negative, and a message was written
							if tonumber(amount) <= 0 then
								CEPGP_addTraffic("Raid", PLAYER_NAME, "Subtract Raid EP " .. amount .. " from those in " .. myzone .. " (" .. msg .. ")", "", "", "", "", "", time());
								CEPGP_sendChatMessage(amount .. " EP taken from all raid members in " .. myzone .. "(" .. msg .. ")", CEPGP.Channel);
							else
								CEPGP_addTraffic("Raid", PLAYER_NAME, "Add Raid EP +" .. amount .. " to those in " .. myzone .. " (" .. msg .. ")", "", "", "", "", "", time());
								CEPGP_sendChatMessage(amount .. " EP awarded to all raid members in " .. myzone .. " (" .. msg .. ")", CEPGP.Channel);
							end
						end
					else -- no message was written
						if tonumber(amount) <= 0 then
							amount = string.sub(amount, 2, string.len(amount));
							CEPGP_addTraffic("Raid", PLAYER_NAME, "Subtract Raid EP " .. amount .. " to those in " .. myzone, "", "", "", "", "", time());
							CEPGP_sendChatMessage(amount .. " EP taken from all raid members in " .. myzone, CEPGP.Channel);
						else
							CEPGP_addTraffic("Raid", PLAYER_NAME, "Add Raid EP +" .. amount .. " to those in " .. myzone, "", "", "", "", "", time());
							CEPGP_sendChatMessage(amount .. " EP awarded to all raid members in " .. myzone, CEPGP.Channel);
						end
					end
					if not CEPGP_ZA.suppressMessages and #notInZone > 0 then
						local msgtable = {};
						msgtable[1] = "People who didn't qualify for award: ";
						local j = 1;
						for _, v in ipairs(notInZone) do
							if strlen(msgtable[j] .. v .. ", ") > 255 then
								j = j +1;
								msgtable[j] = v;
							else
								msgtable[j] = msgtable[j] .. v .. ", ";
							end					
						end
						msgtable[#msgtable] = strtrim(msgtable[#msgtable], ", ");
						for _, v in ipairs(msgtable) do
							CEPGP_sendChatMessage(v, CEPGP.Channel);
						end
					end
					if _G["CEPGP_traffic"]:IsVisible() then
						CEPGP_UpdateTrafficScrollBar();
					end
				end
			
				local alts = {};
				local roster = {};
				local syncEP, syncGP = CEPGP.Alt.SyncEP, CEPGP.Alt.SyncGP;
				
				for main, data in pairs(CEPGP.Alt.Links) do
					for _, alt in ipairs(data) do
						alts[alt] = main;
					end
				end
				
				for _, data in pairs(ZA_RaidRoster) do
					local name = data[1];
					if ZA_GuildRoster[name] then
						local EP, GP = CEPGP_getEPGP(name, index);
						roster[name] = {
							[1] = ZA_GuildRoster[name][1],
							[2] = EP + amount,
							[3] = GP
						}
						if alts[name] then
							for alt, main in pairs(alts) do
								if alt ~= name and roster[alt] and main == alts[name] and syncEP then
									roster[name] = nil;	--	Ensures no sibling alts are present in the roster
								end
								if roster[alt] and roster[main] then
									roster[alt] = nil;	--	Ensures no alt and main pairs exist within the raid roster
								end
							end
						end
					end
				end

				local raidsize = GetNumGroupMembers();

				for i = 1, raidsize do
					local rname, _, _, _, _, _, zone = GetRaidRosterInfoCrossRealm(i);
					if roster[rname] then
						roster[rname][4] = zone;
					end
				end
			
				for name, data in pairs(roster) do
					--local zoneIndex = CEPGP_getIndex(name, ZA_GuildRoster[name][1]);
					--local zone = select(6, GetGuildRosterInfo(zoneIndex));
					if myzone == data[4] then
						if alts[name] then
							if not CEPGP.Alt.BlockAwards then
								local main = alts[name];
								local mainIndex = CEPGP_getIndex(main, ZA_GuildRoster[main][1]);
								local mEP, mGP = CEPGP_getEPGP(main, mainIndex);
								mEP = mEP + amount;
								
								if syncEP then
									GuildRosterSetOfficerNote(mainIndex, mEP .. "," .. mGP);
									
									for _, alt in pairs(CEPGP.Alt.Links[main]) do
										if ZA_GuildRoster[alt] then
											local altIndex = CEPGP_getIndex(alt, ZA_GuildRoster[alt][1]);
											local EP, GP = CEPGP_getEPGP(alt, altIndex);
											
											if syncEP and syncGP then
												GuildRosterSetOfficerNote(altIndex, mEP .. "," .. mGP);
											elseif syncEP then
												GuildRosterSetOfficerNote(altIndex, mEP .. "," .. GP);
											elseif syncGP then
												GuildRosterSetOfficerNote(altIndex, EP .. "," .. mGP);
											end
										end
									end
								else
									local index = CEPGP_getIndex(name, roster[name][1]);
									local EP, GP = CEPGP_getEPGP(name, index);
									EP = EP + amount;
									GuildRosterSetOfficerNote(index, EP .. "," .. GP);
								end
							end
						else
							local index, EP, GP = CEPGP_getIndex(name, data[1]), data[2], data[3];
							GuildRosterSetOfficerNote(index, EP..","..GP);
							
							if CEPGP.Alt.Links[name] then
								if syncEP or syncGP then

									for _, alt in pairs(CEPGP.Alt.Links[name]) do
										if ZA_GuildRoster[alt] then
											local altIndex = CEPGP_getIndex(alt, ZA_GuildRoster[alt][1]);
											local aEP, aGP = CEPGP_getEPGP(alt, altIndex);
											
											if syncEP and syncGP then
												GuildRosterSetOfficerNote(altIndex, EP .. "," .. GP);
											elseif syncEP then
												GuildRosterSetOfficerNote(altIndex, EP .. "," .. aGP);
											elseif syncGP then
												GuildRosterSetOfficerNote(altIndex, aEP .. "," .. GP);
											end
										end
									end
								end
							end
						end
					else
						table.insert(notInZone, name);
					end
				end
			
				update();
			end);

			if not success then
				CEPGP_print("A problem was encountered while awarding EP to the raid", true);
				CEPGP_print(failMsg, true);
			end

		else
			origAddRaidEP(amount, msg, encounter);
		end
	end	
end

function CEPGP_ZA_initialise()

	-- Initialise saved variables

	if CEPGP_ZA.enabled == nil then
		CEPGP_ZA.enabled = true;
	end

	if CEPGP_ZA.enabled then
		_G["CEPGP_ZA_award_raid_popup"]:Show();
	else
		_G["CEPGP_ZA_award_raid_popup"]:Hide();
	end

	CEPGP_ZA_award_raid_popup_zone_check:SetChecked(CEPGP_ZA.zoneAward);

	-- Create interface options panel

	local panel = CreateFrame("FRAME");
	panel.name = "CEPGP Zone Awards";

	local titleText = panel:CreateFontString("CEPGP_ZA_titleText", "OVERLAY", "GameFontNormalLarge");
	titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -15);
	titleText:SetText("CEPGP Zone Awards");

	local suppressMessagesCheck = CreateFrame("CheckButton", "CEPGP_ZA_suppressMessagesCheck", panel, "UIOptionsCheckButtonTemplate");
	suppressMessagesCheck:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -10);
	suppressMessagesCheck:SetScript("OnClick", function()
													CEPGP_ZA.suppressMessages = CEPGP_ZA_suppressMessagesCheck:GetChecked();
											   end);
	
	suppressMessagesCheck:SetChecked(CEPGP_ZA.suppressMessages);

	local supressMessagesText = panel:CreateFontString("CEPGP_ZA_suppressMessagesText", "OVERLAY", "GameFontNormal");
	supressMessagesText:SetPoint("LEFT", suppressMessagesCheck, "RIGHT", 5, 0);
	supressMessagesText:SetTextColor(1,1,1);
	supressMessagesText:SetText("Supress 'Not in zone' messages");

	local includeKillsCheck = CreateFrame("CheckButton", "CEPGP_ZA_includeKillsCheck", panel, "UIOptionsCheckButtonTemplate");
	includeKillsCheck:SetPoint("TOPLEFT", suppressMessagesCheck, "BOTTOMLEFT", 0, -10);
	includeKillsCheck:SetScript("OnClick", function()
													CEPGP_ZA.includeKills = CEPGP_ZA_includeKillsCheck:GetChecked();
											   end);
	
	includeKillsCheck:SetChecked(CEPGP_ZA.includeKills);

	local includeKillsText = panel:CreateFontString("CEPGP_ZA_includeKillsText", "OVERLAY", "GameFontNormal");
	includeKillsText:SetPoint("LEFT", includeKillsCheck, "RIGHT", 5, 0);
	includeKillsText:SetTextColor(1,1,1);
	includeKillsText:SetText("Include boss kill auto awards");

	InterfaceOptions_AddCategory(panel);

	-- Register plugin with CEPGP

	CEPGP_addPlugin(addonName, panel, CEPGP_ZA.enabled, function()
		if CEPGP_ZA.enabled then
			_G["CEPGP_ZA_award_raid_popup"]:Hide();
		else
			_G["CEPGP_ZA_award_raid_popup"]:Show();
		end
		CEPGP_ZA.enabled = not CEPGP_ZA.enabled;
	end);

	CEPGP_ZA_hook();
end

function CEPGP_ZA_OnEvent(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "CEPGP_ZA" then
		self:UnregisterEvent("ADDON_LOADED");
		CEPGP_ZA_initialise();
	end
end

local function CEPGP_ZA_createFrames()
	local CEPGP_ZA_frame = CreateFrame("Frame", "CEPGP_ZA_award_raid_popup", _G["CEPGP_award_raid_popup"]);
	CEPGP_ZA_frame:SetScale(1.0);
	local fontString = CEPGP_ZA_frame:CreateFontString("CEPGP_ZA_textFrame", "OVERLAY", "GameFontNormal");
	fontString:SetPoint("LEFT", "CEPGP_award_raid_popup_standby_check", "RIGHT", 5, 0);
	fontString:SetText("Award to Zone: ");

	local checkFrame = CreateFrame("CheckButton", "CEPGP_ZA_award_raid_popup_zone_check", CEPGP_ZA_frame, "UIOptionsCheckButtonTemplate");
	checkFrame:SetPoint("LEFT", "CEPGP_ZA_textFrame", "RIGHT", 5, 0);
	checkFrame:SetScript("OnClick",function() 
										if _G["CEPGP_ZA_award_raid_popup_zone_check"]:GetChecked() then
											CEPGP_ZA.zoneAward = true;
										else
											CEPGP_ZA.zoneAward = false;
										end
								   end);
	
	CEPGP_ZA_frame:RegisterEvent("ADDON_LOADED");
	CEPGP_ZA_frame:SetScript("OnEvent", CEPGP_ZA_OnEvent);
end

CEPGP_ZA_createFrames();

