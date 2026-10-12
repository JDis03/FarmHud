local fixture = assert(loadfile("tests/widget_fixture.lua"))();

for _,case in ipairs({{18,16001,true},{18,16001,false},{1,120100,true},{2,11509,true}}) do
	local env,ns,button,widths,counters=fixture(unpack(case));
	local map,hud=env.Minimap,env.FarmHud;
	local originalClick=function() error("stock click should not execute during lifecycle"); end;
	map:SetScript("OnMouseUp",originalClick);
	for round=1,3 do
		hud:Toggle(true);
		assert(map.parent==hud and map.alpha==0 and map.mouse==false);
		assert(select(2,env.MinimapCompassTexture:GetPoint())==env.FarmHudMinimapDummy);
		assert(select(2,env.MinimapCluster.InstanceDifficulty:GetPoint())==env.FarmHudMinimapDummy);
		if case[1]==18 then assert(env.MinimapCompassTexture:IsShown(), "Forever compass is not a legacy border"); end;
		button:GetScript("OnEnter")(button);
		assert(widths[#widths]==140, "foreign hover must see original minimap size");
		button:GetScript("OnLeave")(button);
		assert(map:GetWidth()>140, "dummy-size lock must release after hover");
		if case[1]==18 or case[1]==1 then
			map:GetScript("OnMouseUp")(map); -- Must warn, not call PingLocation.
		end;
		hud:Toggle(false);
		assert(map.parent==env.MinimapCluster.MinimapContainer);
		assert(map.width==140 and map.height==140 and map.scale==0.9 and map.alpha==0.85);
		assert(map.zoom==2 and map.mouse==true and map.wheel==true);
		assert(map:GetScript("OnMouseUp")==originalClick, "restore stock handler even when HUD pings disabled");
		assert(env.MinimapBackdrop.mouse==case[3], "restore saved mouse boolean");
		assert(select(2,env.MinimapCompassTexture:GetPoint())==map, "restore anchor-only move");
		assert(select(2,env.MinimapCluster.InstanceDifficulty:GetPoint())==map, "restore dotted path frame");
		assert(select(2,map:GetPoint())==env.MinimapCluster.MinimapContainer);
		assert(button.parent==map and select(2,button:GetPoint())==map);
		assert(env.C_CVar.GetCVar("rotateMinimap")=="0");
	end;
	local leaves,restores=counters();
	assert(leaves==3 and restores==3);
	assert(#env.fixtureStats.trackingCalls==0, "default HUD must not change Find Minerals");
	if case[1]==18 then assert(ns.GetTrackingTypes()[136025].name=="Find Minerals"); end;
end
print("HUD lifecycle regression tests passed");

-- Nil handlers and the OnMouseDown-only layout (e.g. another minimap addon)
-- must also round-trip. Closing the HUD must preserve the dummy XML scripts.
for _,clickMode in ipairs({"none","down","both"}) do
	local env=fixture(18,16001,true);
	local map,hud=env.Minimap,env.FarmHud;
	local up=clickMode=="both" and function() end or nil;
	local down=clickMode~="none" and function() end or nil;
	map:SetScript("OnMouseUp",up); map:SetScript("OnMouseDown",down);
	local dummyUp=function() end;
	env.FarmHudMinimapDummy:SetScript("OnMouseUp",dummyUp);
	for round=1,2 do
		hud:Toggle(true); hud:Toggle(false);
		assert(map:GetScript("OnMouseUp")==up and map:GetScript("OnMouseDown")==down);
		assert(env.FarmHudMinimapDummy:GetScript("OnMouseUp")==dummyUp);
	end;
end
print("Mouse handler regression tests passed");

-- The dummy must not forward unknown native/foreign click wrappers on clients
-- where HUD pings are disabled. Normal click behavior returns after closing.
do
	local env=fixture(18,16001,true);
	local map,hud=env.Minimap,env.FarmHud;
	local count=0;
	local stock=function() count=count+1; end;
	map:SetScript("OnMouseUp",stock); map:SetScript("OnMouseDown",stock);
	hud:Toggle(true);
	env.FarmHudMinimapDummyMixin.OnMouseUp(env.FarmHudMinimapDummy);
	env.FarmHudMinimapDummyMixin.OnMouseDown(env.FarmHudMinimapDummy);
	assert(count==0,"dummy HUD must not forward potentially protected clicks");
	hud:Toggle(false);
	map:GetScript("OnMouseUp")(map);
	assert(count==1,"normal stock click is restored");
end
print("Dummy click safety regression test passed");
