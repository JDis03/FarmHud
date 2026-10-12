local addon, ns = ...;

-- Forever 1.60.1 is Camelot, not Era and not Mainline. Do not change the
-- game's project globals: libraries must still see the real client.
function ns.IsForever()
	return WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18);
end

function ns.HasModernMinimapSkin()
	local _, _, _, interfaceVersion = GetBuildInfo();
	return ns.IsForever() or (interfaceVersion or 0) >= 100000;
end

function ns.ResolveGlobalFrame(path)
	local object = _G;
	for key in path:gmatch("[^.]+") do
		if type(object) ~= "table" then return nil; end
		object = object[key];
	end
	return object;
end

-- Read-only diagnostics; this does not toggle tracking, move the HUD, or ping.
SLASH_FARMHUDCOMPAT1 = "/farmhudcompat";
SlashCmdList.FARMHUDCOMPAT = function()
	local version, build, _, interfaceVersion = GetBuildInfo();
	print(addon..": version="..tostring(version).." build="..tostring(build)
		.." interface="..tostring(interfaceVersion).." project="..tostring(WOW_PROJECT_ID)
		.." Forever="..tostring(ns.IsForever()));
	print(addon..": tracking="..tostring(C_Minimap and type(C_Minimap.GetTrackingInfo) == "function")
		.." playerTexture="..tostring(Minimap and type(Minimap.SetPlayerTexture) == "function")
		.." blipTexture="..tostring(Minimap and type(Minimap.SetBlipTexture) == "function")
		.." combat="..tostring(InCombatLockdown and InCombatLockdown() or false));
end
