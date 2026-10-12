-- Lua5.1, run from the addon root. FOREVER_UI_SOURCE=/tmp/farmhud-forever-ui
-- executes that checkout's unmodified Camelot/Skin.lua; otherwise the fixture
-- uses a small offline contract. See widget_fixture.lua for mock limitations.
local fixture=assert(loadfile("tests/widget_fixture.lua"))();
local mask="ui-hud-minimap-frame-generic-mask";

local function contains(list, target)
	for _,object in ipairs(list) do if object==target then return true; end end
	return false;
end
local function snapshot(object)
	local state={parent=object:GetParent(),points={}};
	for i=1,object:GetNumPoints() do state.points[i]={object:GetPoint(i)}; end
	return state;
end
local function assertAnchors(object, state, from, to)
	assert(object:GetNumPoints()==#state.points,object:GetDebugName()..": lost anchors");
	for i,expected in ipairs(state.points) do
		local actual={object:GetPoint(i)};
		for j=1,5 do
			local value=expected[j]; if j==2 and value==from then value=to; end
			assert(actual[j]==value,object:GetDebugName()..": anchor "..i.." component "..j.." not restored/moved");
		end
	end
end
local function assertSize(object, info)
	local width,height=object:GetSize();
	assert(width==info.width and height==info.height,object:GetDebugName()..": wrong skin dimensions");
end
local function assertSkin(env, rotated)
	local atlas=rotated and "UI-HUD-Minimap-Frame-Pointer" or "UI-HUD-Minimap-Frame";
	local info=env.C_Texture.GetAtlasInfo(atlas);
	assert(env.Minimap:GetMaskTexture()==mask,"native mask must survive HUD hooks");
	assert(env.MinimapCompassTexture:GetAtlas()==atlas,"native compass atlas must follow rotation");
	assert(env.MinimapCompassTexture:IsShown(),"modern compass must not be hidden as a legacy border");
	assertSize(env.MinimapCluster.MinimapContainer,info);
	assertSize(env.MinimapBackdrop,info);
	assertSize(env.MinimapCompassTexture,info);
	local underlay=env.MinimapCompassTextureUnderlay;
	assert(underlay:IsShown()==rotated,"native underlay visibility must follow rotation");
	if rotated then
		assert(underlay:GetAtlas()=="UI-HUD-Minimap-Frame-Circle");
		-- Skin.lua sizes the circle with the pointer's dimensions, not the circle atlas.
		assertSize(underlay,info);
	end
end

local reported=false;
for _,initialize in ipairs({false,true}) do
	for _,initialRotation in ipairs({"0","1"}) do
		for _,hudRotation in ipairs({false,true}) do
			for _,backdropMouse in ipairs({false,true}) do
				local env,ns,button,widths,counters=fixture(18,16001,backdropMouse,
					{initialize=initialize,nativeSkin=true,initialRotation=initialRotation});
				if not reported then
					if os.getenv("FOREVER_UI_SOURCE") then
						local expected=os.getenv("FOREVER_UI_SOURCE"):gsub("/+$","")
							.."/Interface/AddOns/Blizzard_Minimap/Camelot/Skin.lua";
						assert(env.nativeSkinSource==expected);
						print("Native skin coverage: REAL Camelot/Skin.lua executed: "..env.nativeSkinSource);
					else
						assert(env.nativeSkinSource=="offline contract");
						print("Native skin coverage: OFFLINE contract executed; real Camelot/Skin.lua did NOT run (set FOREVER_UI_SOURCE)");
					end
					reported=true;
				end
				assert(ns.IsForever() and ns.HasModernMinimapSkin());
				local map,hud,dummy=env.Minimap,env.FarmHud,env.FarmHudMinimapDummy;
				local backdrop,compass,underlay=env.MinimapBackdrop,env.MinimapCompassTexture,env.MinimapCompassTextureUnderlay;
				local container=env.MinimapCluster.MinimapContainer;
				env.FarmHudDB.rotation=hudRotation;
				assertSkin(env,initialRotation=="1");
				assert(backdrop:GetParent()==map,"fixture must use native backdrop parent");
				assert(contains({map:GetChildren()},backdrop) and contains({map:GetChildren()},button));
				assert(contains({backdrop:GetRegions()},compass) and contains({backdrop:GetRegions()},underlay));
				assert(contains({backdrop:GetChildren()},env.ExpansionLandingPageMinimapButton));
				assert(not contains({map:GetChildren()},compass),"textures must be regions, not children");

				map:SetPoint("TOPLEFT",container,"TOPLEFT",11,-13);
				map:SetPoint("BOTTOMRIGHT",container,"BOTTOMRIGHT",-17,19);
				-- Replace one point without losing the others (the previous fixture lost them).
				map:SetPoint("TOPLEFT",container,"TOPLEFT",23,-29);
				assert(map:GetNumPoints()==3 and select(4,map:GetPoint(2))==23);
				backdrop:SetPoint("BOTTOMRIGHT",map,"BOTTOMRIGHT",1,2);
				compass:SetPoint("TOPLEFT",map,"TOPLEFT",3,4);
				compass:SetPoint("BOTTOMRIGHT",env.UIParent,"BOTTOMRIGHT",5,6);
				env.MinimapCluster.InstanceDifficulty:SetPoint("TOPRIGHT",map,"TOPRIGHT",7,8);
				button:SetPoint("TOPRIGHT",map,"TOPRIGHT",9,10);
				local extra=env.CreateFrame("Button",nil,map);
				extra:SetPoint("TOPLEFT",map,"TOPLEFT",12,14);
				extra:SetPoint("BOTTOMRIGHT",env.UIParent,"BOTTOMRIGHT",16,18);
				local region=map:CreateTexture(nil,"ARTWORK");
				region:SetPoint("TOPLEFT",map,"TOPLEFT",20,22);
				region:SetPoint("BOTTOMRIGHT",map,"BOTTOMRIGHT",24,26);
				local originalMap=snapshot(map);
				local originals={};
				for _,object in ipairs({backdrop,compass,underlay,button,extra,region,
					env.MinimapCluster.InstanceDifficulty,env.ExpansionLandingPageMinimapButton}) do
					originals[object]=snapshot(object);
				end
				local changed=hudRotation~=(initialRotation=="1");
				local expectedRotation=hudRotation and "1" or "0";
				local expectedCallbacks=0;
				env.CVarCallbackRegistry:RegisterCallback("rotateMinimap",function()
					expectedCallbacks=expectedCallbacks+1;
					if hud:IsShown() then
						assert(map:GetParent()==hud,"native callback should see HUD parent on entry");
						assert(backdrop:GetParent()==dummy);
						assertAnchors(compass,originals[compass],map,dummy);
					else
						assert(map:GetParent()==originalMap.parent,"restore parent before native callback");
						assertAnchors(map,originalMap);
						for object,state in pairs(originals) do
							assert(object:GetParent()==state.parent,"restore widget parent before native callback");
							assertAnchors(object,state);
						end
					end
				end);
				for visit=1,3 do
					hud:Toggle(true);
					assert(env.C_CVar.GetCVar("rotateMinimap")==expectedRotation);
					assertSkin(env,hudRotation);
					assert(map:GetParent()==hud and map:GetNumPoints()==1);
					assertAnchors(dummy,originalMap);
					for object,state in pairs(originals) do
						assert(object:GetParent()==(state.parent==map and dummy or state.parent));
						assertAnchors(object,state,map,dummy);
					end
					assert(backdrop:IsMouseEnabled()==false);
					assert(contains({dummy:GetChildren()},backdrop) and not contains({map:GetChildren()},backdrop));
					button:GetScript("OnEnter")(button); assert(widths[#widths]==140);
					button:GetScript("OnLeave")(button); assert(map:GetWidth()>140);
					if initialize and changed then assert(dummy.bg.mask==mask,"native mask callback must reach dummy hook"); end
					hud:Toggle(false);
					assert(env.C_CVar.GetCVar("rotateMinimap")==initialRotation);
					assertSkin(env,initialRotation=="1");
					assertAnchors(map,originalMap);
					assert(map:GetParent()==originalMap.parent);
					for object,state in pairs(originals) do
						assert(object:GetParent()==state.parent); assertAnchors(object,state);
					end
					assert(backdrop:IsMouseEnabled()==backdropMouse);
					assert(contains({map:GetChildren()},backdrop) and not contains({dummy:GetChildren()},backdrop));
					assert(map.width==140 and map.height==140 and map.scale==0.9 and map.alpha==0.85);
					assert(map.zoom==2 and map.mouse and map.wheel);
					local transitions=changed and visit*2 or 0;
					assert(expectedCallbacks==transitions and env.fixtureStats.nativeSkinUpdates==transitions);
					assert(#env.fixtureStats.cvarWrites==transitions,"unchanged CVar must not be rewritten");
					assert(env.fixtureStats.rotationUpdates==transitions);
				end
				-- Fixed mode hides, but does not clear the atlas/size left by rotated mode.
				if initialRotation=="0" and changed then
					assert(underlay:GetAtlas()=="UI-HUD-Minimap-Frame-Circle");
					assertSize(underlay,env.C_Texture.GetAtlasInfo("UI-HUD-Minimap-Frame-Pointer"));
				end
				local leaves,restores=counters(); assert(leaves==3 and restores==(changed and 3 or 0));
				assert(#env.fixtureStats.trackingCalls==0,"default HUD must not change Find Minerals");
			end
		end
	end
end
print("Native skin rotation, multiple-anchor and parent restoration tests passed");

-- Exercise OnLoad and its hooks in addition to the non-initialized legacy
-- fixture. Direct native calls matter: the addon often bypasses object methods.
do
	local env=fixture(18,16001,true,{initialize=true,nativeSkin=true,initialRotation="1"});
	local map,hud,dummy=env.Minimap,env.FarmHud,env.FarmHudMinimapDummy;
	local native=getmetatable(map).__index;
	assert(dummy.bg.mask=="interface/CHARACTERFRAME/TempPortraitAlphaMask");
	for _,method in ipairs({"SetMaskTexture","SetZoom","SetAlpha","EnableMouse"}) do
		assert(#map.methodHooks[method]==1,"OnLoad must install "..method.." hook");
	end
	assert(hud.events.ADDON_LOADED and hud.events.PLAYER_LOGIN and hud.events.PLAYER_LOGOUT);
	native.SetMaskTexture(map,"fixture-test-mask"); assert(dummy.bg.mask=="fixture-test-mask");
	map:SetMaskTexture(mask); assert(dummy.bg.mask==mask);
	env.FarmHudDB["tracking^136025"]="false";
	hud:Toggle(true);
	assert(env.C_Minimap.GetTrackingInfo(1).active==false,"tracking override must apply");
	native.SetZoom(map,4); assert(map:GetZoom()==0,"native zoom calls must invoke secure hook");
	native.SetAlpha(map,0.73); assert(map:GetAlpha()==0,"native alpha calls must invoke secure hook");
	local prints=#env.fixtureStats.prints;
	native.EnableMouse(map,true); assert(#env.fixtureStats.prints==prints+1,"native mouse call must invoke diagnostic hook");
	hud:ToggleMouse(true); assert(not map:IsMouseEnabled());
	hud:Toggle(false);
	assert(env.C_Minimap.GetTrackingInfo(1).active==true,"tracking override must restore original preference");
	assert(#env.fixtureStats.trackingCalls==2);
	hud:Toggle(true);
	assert(env.C_Minimap.GetTrackingInfo(1).active==false);
	-- A client-side tracking change updates the saved value, not the HUD option.
	env.C_Minimap.SetTracking(1,false);
	hud:Toggle(false);
	assert(env.C_Minimap.GetTrackingInfo(1).active==false,"tracking hook must preserve changed client preference");
	assert(map:GetMaskTexture()==mask and dummy.bg.mask==mask);
	map:SetZoom(3); map:SetAlpha(0.64); assert(map:GetZoom()==3 and map:GetAlpha()==0.64);
	local nextEnv=fixture(18,16001,true,{initialize=true});
	assert(getmetatable(nextEnv.Minimap).__index~=native,"native method tables must not leak between fixtures");
	assert(#nextEnv.Minimap.methodHooks.SetZoom==1,"secure hooks must not accumulate between fixtures");
	local isolated=env.CreateFrame("Frame",nil,env.UIParent);
	local hookCalls=0;
	env.hooksecurefunc(isolated,"SetAlpha",function() hookCalls=hookCalls+1; end);
	native.SetAlpha(isolated,0.2); assert(hookCalls==1 and isolated:GetAlpha()==0.2);
	native.SetAlpha(map,0.3); assert(hookCalls==1,"object hooks must not leak to siblings");
	local uninitialized=fixture(18,16001,true);
	assert(not uninitialized.Minimap.methodHooks.SetAlpha,"hooks must not leak into uninitialized fixture");
end
print("Initialization and native-method hook smoke tests passed");
