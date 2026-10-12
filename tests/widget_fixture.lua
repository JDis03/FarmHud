-- Return a fresh widget environment for each test. Run from the addon root.
-- Limits: no secure/protected execution, taint, anchor-family validation, layout
-- solver, rendering, inherited visibility, or real atlas assets. CVar callbacks
-- are synchronous. Atlas dimensions below are deliberately distinct test data.
-- Native methods dispatch per-object post-hooks even when called through __index;
-- method tables and hook registries are private to each fixture (not global WoW).
return function(project, interfaceVersion, backdropMouse, opts)
	opts = opts or {};
	local env=setmetatable({}, {__index=_G}); env._G=env;
	local Frame = {}; Frame.__index = Frame;
	local function remove(list, object)
		for i=#list,1,-1 do if list[i]==object then table.remove(list,i); end end
	end
	local function frame(name, parent, objectType)
		local object=setmetatable({name=name,points={},scripts={},children={},regions={},
			shown=true,mouse=true,wheel=true,width=140,height=140,scale=1,alpha=1,
			strata="LOW",level=3,zoom=2,objectType=objectType or "Frame",events={},
			methodHooks={},methodCalls={}}, Frame);
		object:SetParent(parent);
		if name then env[name]=object; end
		return object;
	end
	function Frame:GetName() return self.name; end
	function Frame:GetDebugName() return self.name or "unnamed"; end
	function Frame:GetObjectType() return self.objectType; end
	function Frame:SetParent(parent)
		if type(parent)=="string" then parent=assert(env[parent],parent); end
		local region=self.objectType=="Texture" or self.objectType=="FontString";
		local key=region and "regions" or "children";
		if self.parent then remove(self.parent[key],self); end
		self.parent=parent;
		if parent then parent[key][#parent[key]+1]=self; end
	end
	function Frame:GetParent() return self.parent; end
	function Frame:SetPoint(point, relativeTo, relativePoint, x, y)
		-- SetPoint updates the same anchor by point name, retaining other anchors.
		-- Support the native shorthand (point, x, y) and parent-relative anchors.
		if type(relativeTo)=="number" then x,y,relativeTo,relativePoint=relativeTo,relativePoint,self.parent,point; end
		if type(relativeTo)=="string" then relativeTo=assert(env[relativeTo],relativeTo); end
		relativeTo=relativeTo or self.parent; relativePoint=relativePoint or point;
		local anchor={point,relativeTo,relativePoint,x or 0,y or 0};
		for i,v in ipairs(self.points) do if v[1]==point then self.points[i]=anchor; return; end end
		self.points[#self.points+1]=anchor;
	end
	function Frame:GetPoint(i) return unpack(self.points[i or 1] or {}); end
	function Frame:GetNumPoints() return #self.points; end
	function Frame:ClearAllPoints() self.points={}; end
	function Frame:SetAllPoints(parent)
		self:ClearAllPoints();
		self:SetPoint("TOPLEFT",parent or self.parent,"TOPLEFT",0,0);
		self:SetPoint("BOTTOMRIGHT",parent or self.parent,"BOTTOMRIGHT",0,0);
	end
	function Frame:GetChildren() return unpack(self.children); end
	function Frame:GetRegions() return unpack(self.regions); end
	function Frame:GetNumChildren() return #self.children; end
	function Frame:GetNumRegions() return #self.regions; end
	function Frame:SetScript(key, fn) self.scripts[key]=fn; end
	function Frame:GetScript(key) return self.scripts[key]; end
	function Frame:HookScript(key, fn)
		local original=self:GetScript(key);
		self:SetScript(key,function(...) if original then original(...); end; fn(...); end);
	end
	function Frame:GetSize() return self.width,self.height; end
	function Frame:SetSize(w,h) self.width,self.height=w,h; end
	function Frame:SetWidth(w) self.width=w; end
	function Frame:SetHeight(h) self.height=h; end
	function Frame:GetWidth() return self.width; end
	function Frame:GetHeight() return self.height; end
	function Frame:GetCenter() return 100,100; end
	function Frame:GetLeft() return 0; end
	function Frame:GetRight() return self.width; end
	function Frame:GetTop() return self.height; end
	function Frame:GetBottom() return 0; end
	function Frame:SetScale(s) self.scale=s; end
	function Frame:GetScale() return self.scale; end
	function Frame:GetEffectiveScale() return self.scale; end
	function Frame:SetFrameStrata(s) self.strata=s; end
	function Frame:GetFrameStrata() return self.strata; end
	function Frame:SetFrameLevel(n) self.level=n; end
	function Frame:GetFrameLevel() return self.level; end
	function Frame:SetAlpha(a) self.alpha=a; end
	function Frame:GetAlpha() return self.alpha; end
	function Frame:EnableMouse(b) assert(type(b)=="boolean", "mouse state erased"); self.mouse=b; end
	function Frame:IsMouseEnabled() return self.mouse; end
	function Frame:EnableMouseWheel(b) self.wheel=b; end
	function Frame:IsMouseWheelEnabled() return self.wheel; end
	function Frame:SetZoom(n) self.zoom=n; end
	function Frame:GetZoom() return self.zoom; end
	function Frame:GetZoomLevels() return 5; end
	function Frame:IsShown() return self.shown; end
	Frame.IsVisible=Frame.IsShown;
	function Frame:SetShown(state)
		local old=self.shown; self.shown=not not state;
		if old~=self.shown then
			local key=self.shown and "OnShow" or "OnHide";
			local fn=self:GetScript(key) or self[key];
			if fn then fn(self); end
		end
	end
	function Frame:Show() self:SetShown(true); end
	function Frame:Hide() self:SetShown(false); end
	function Frame:SetText(text) self.text=text; end
	function Frame:GetText() return self.text; end
	function Frame:SetFormattedText(...) self.text=string.format(...); end
	function Frame:SetTextColor(...) self.textColor={...}; end
	function Frame:SetMask(texture) self.mask=texture; end
	function Frame:SetMaskTexture(texture) self.mask=texture; end
	function Frame:GetMaskTexture() return self.mask; end
	function Frame:SetAtlas(atlas, useAtlasSize)
		self.atlas=atlas;
		if useAtlasSize then local info=env.C_Texture.GetAtlasInfo(atlas); self:SetSize(info.width,info.height); end
	end
	function Frame:GetAtlas() return self.atlas; end
	function Frame:SetTexture(texture) self.texture=texture; end
	function Frame:GetTexture() return self.texture; end
	function Frame:SetDrawLayer(layer, sublevel) self.drawLayer,self.drawSublevel=layer,sublevel; end
	-- Only regions expose GetDrawLayer, as the addon distinguishes them this way.
	local function getDrawLayer(self) return self.drawLayer or "OVERLAY",self.drawSublevel or 0; end
	function Frame:CreateTexture(name, layer, _, sublevel)
		local texture=frame(name,self,"Texture"); texture.GetDrawLayer=getDrawLayer;
		texture:SetDrawLayer(layer or "OVERLAY",sublevel or 0); return texture;
	end
	function Frame:CreateFontString(name, layer)
		local region=frame(name,self,"FontString"); region.GetDrawLayer=getDrawLayer;
		region:SetDrawLayer(layer or "OVERLAY",0); return region;
	end
	function Frame:RegisterEvent(event) self.events[event]=true; end
	function Frame:UnregisterEvent(event) self.events[event]=nil; end
	function Frame:SetBlipTexture(texture) self.blipTexture=texture; end
	-- SetPlayerTexture is intentionally absent: like current native clients, this
	-- mock cannot change the player texture. It does not certify that hook path.
	local function pack(...) return {n=select("#",...),...}; end
	local nativeMethods={};
	for key,fn in pairs(Frame) do
		if type(fn)=="function" then
			local method=key;
			local wrapped=function(self,...)
				self.methodCalls[method]=(self.methodCalls[method] or 0)+1;
				local result=pack(fn(self,...));
				for _,hook in ipairs(self.methodHooks[method] or {}) do hook(self,...); end
				return unpack(result,1,result.n);
			end;
			Frame[key]=wrapped; nativeMethods[key]=wrapped;
		end
	end
	env.CreateFrame=function(objectType,name,parent) return frame(name,parent,objectType); end;
	env.hooksecurefunc=function(object,key,hook)
		if type(object)=="string" then hook,key,object=key,object,env; end
		assert(type(object[key])=="function" and type(hook)=="function", "invalid secure hook");
		if getmetatable(object)==Frame and object[key]==nativeMethods[key] then
			local hooks=object.methodHooks[key] or {}; object.methodHooks[key]=hooks; hooks[#hooks+1]=hook;
		else
			local original=object[key];
			object[key]=function(...)
				local result=pack(original(...)); hook(...); return unpack(result,1,result.n);
			end;
		end
	end;
	env.WOW_PROJECT_ID=project; env.WOW_PROJECT_MAINLINE=1; env.WOW_PROJECT_CLASSIC=2; env.WOW_PROJECT_CAMELOT=18;
	env.GetBuildInfo=function() return "1.60.1","70235","",interfaceVersion; end;
	env.SlashCmdList={};
	env.wipe=function(t) for k in pairs(t) do t[k]=nil; end end;
	env.min=math.min;
	env.debugstack=function() return "widget_fixture mock stack"; end;
	env.C_Map={};
	env.C_Timer={NewTicker=function(_,fn) return {Cancel=function(self) self.cancelled=true; end,callback=fn}; end,
		After=function(_,fn) fn(); end};
	env.UIParent=frame("UIParent"); env.WorldFrame=frame("WorldFrame"); env.WorldFrame:SetSize(1920,1080);
	env.MinimapCluster=frame("MinimapCluster",env.UIParent);
	env.MinimapCluster:SetPoint("TOPRIGHT",env.UIParent,"TOPRIGHT",0,0);
	env.MinimapCluster.MinimapContainer=frame("Container",env.MinimapCluster);
	local map=frame("Minimap",env.MinimapCluster.MinimapContainer); env.Minimap=map;
	env.MinimapCluster.MinimapContainer.Minimap=map;
	map:SetPoint("CENTER",map.parent,"CENTER",5,7); map:SetScale(0.9); map:SetAlpha(0.85);
	-- Mainline/Camelot XML shape: backdrop is a Minimap child, compass textures
	-- are backdrop regions; the underlay is anchored to its parent, not the map.
	env.MinimapBackdrop=frame("MinimapBackdrop",map);
	env.MinimapBackdrop.mouse=backdropMouse;
	env.MinimapBackdrop:SetPoint("CENTER",map,"CENTER",0,0);
	env.MinimapCompassTexture=env.MinimapBackdrop:CreateTexture("MinimapCompassTexture","OVERLAY",nil,2);
	env.MinimapCompassTexture:SetPoint("CENTER",map,"CENTER",0,0);
	env.MinimapCompassTextureUnderlay=env.MinimapBackdrop:CreateTexture("MinimapCompassTextureUnderlay","OVERLAY",nil,1);
	env.MinimapCompassTextureUnderlay:SetPoint("CENTER",env.MinimapBackdrop,"CENTER",0,0);
	env.MinimapBackdrop.StaticOverlayTexture=env.MinimapBackdrop:CreateTexture(nil,"OVERLAY");
	env.MinimapBackdrop.StaticOverlayTexture:SetAllPoints(env.MinimapBackdrop);
	env.MinimapBackdrop.StaticOverlayTexture:Hide();
	local compassChild=frame("ExpansionLandingPageMinimapButton",env.MinimapBackdrop,"Button");
	compassChild:SetPoint("TOPLEFT",env.MinimapBackdrop,"TOPLEFT",-3,-150); compassChild:Hide();
	env.MinimapCluster.InstanceDifficulty=frame("Difficulty",env.MinimapCluster);
	env.MinimapCluster.InstanceDifficulty:SetPoint("CENTER",map,"CENTER",8,9);
	local enterWidths, leaveCalls={},0;
	local button=frame("ForeignButton",map);
	button:SetPoint("CENTER",map,"CENTER",0,0);
	button:SetScript("OnEnter",function() enterWidths[#enterWidths+1]=map:GetWidth(); end);
	button:SetScript("OnLeave",function() leaveCalls=leaveCalls+1; end);
	local hud=frame("FarmHud",env.UIParent); env.FarmHud=hud; hud.shown=false;
	hud.cluster=frame("HudCluster",hud); hud.TextFrame=frame("HudText",hud);
	for _,name in ipairs({"coords","time","mouseWarn"}) do hud.TextFrame[name]=frame(name,hud.TextFrame); end;
	env.FarmHudMinimapDummy=frame("Dummy",env.UIParent); env.FarmHudMinimapDummy.bg=frame("DummyBg");
	env.FarmHudWarning=frame("Warning");
	local initialRotation=opts.initialRotation or "0";
	assert(initialRotation=="0" or initialRotation=="1", "initialRotation must be a CVar string");
	local cvar=initialRotation; local restores=0;
	local stats={cvarWrites={},nativeSkinUpdates=0,trackingCalls={},prints={},rotationUpdates=0}; env.fixtureStats=stats;
	local callbacks={};
	env.CVarCallbackRegistry={
		SetCVarCachable=function(_,key) assert(key=="rotateMinimap"); end,
		GetCVarValueBool=function(_,key) assert(key=="rotateMinimap"); return cvar=="1"; end,
		RegisterCallback=function(_,key,fn) assert(key=="rotateMinimap"); callbacks[#callbacks+1]=fn; end,
	};
	env.C_CVar={GetCVar=function(key) assert(key=="rotateMinimap"); return cvar; end,
		SetCVar=function(key,value)
			assert(key=="rotateMinimap"); value=tostring(value);
			stats.cvarWrites[#stats.cvarWrites+1]=value;
			if value==initialRotation and not hud:IsShown() then
				assert(map.parent==env.MinimapCluster.MinimapContainer, "restore rotation after reparenting");
				assert(select(2,env.MinimapCompassTexture:GetPoint())==map, "restore rotation after anchors");
				restores=restores+1;
			end;
			local changed=cvar~=value; cvar=value;
			if changed then for _,fn in ipairs(callbacks) do fn(); end end
		end};
	env.GetCVar=env.C_CVar.GetCVar; env.SetCVar=env.C_CVar.SetCVar;
	env.Minimap_UpdateRotationSetting=function() stats.rotationUpdates=stats.rotationUpdates+1; end;
	local atlasSizes={
		["UI-HUD-Minimap-Frame"]={width=215,height=226},
		["UI-HUD-Minimap-Frame-Pointer"]={width=223,height=234},
		["UI-HUD-Minimap-Frame-Circle"]={width=215,height=226},
	};
	env.C_Texture={GetAtlasInfo=function(atlas) return assert(atlasSizes[atlas],"unexpected atlas: "..tostring(atlas)); end};
	if opts.nativeSkin then
		-- Count actual callback invocations without instrumenting Blizzard's source.
		local register=env.CVarCallbackRegistry.RegisterCallback;
		env.CVarCallbackRegistry.RegisterCallback=function(self,key,fn)
			register(self,key,function() stats.nativeSkinUpdates=stats.nativeSkinUpdates+1; fn(); end);
		end;
		local sourceRoot=os.getenv("FOREVER_UI_SOURCE");
		if sourceRoot then
			assert(sourceRoot=="/tmp/farmhud-forever-ui", "FOREVER_UI_SOURCE must select the audited /tmp/farmhud-forever-ui source");
			local path=sourceRoot.."/Interface/AddOns/Blizzard_Minimap/Camelot/Skin.lua";
			local chunk=assert(loadfile(path)); setfenv(chunk,env); chunk(); env.nativeSkinSource=path;
		else
			-- Offline contract, NOT evidence that Blizzard's current source ran.
			local function update()
				local rotated=env.CVarCallbackRegistry:GetCVarValueBool("rotateMinimap");
				local atlas=rotated and "UI-HUD-Minimap-Frame-Pointer" or "UI-HUD-Minimap-Frame";
				local info=env.C_Texture.GetAtlasInfo(atlas);
				env.MinimapCluster.MinimapContainer:SetSize(info.width,info.height);
				map:SetMaskTexture("ui-hud-minimap-frame-generic-mask");
				env.MinimapBackdrop:SetSize(info.width,info.height);
				env.MinimapCompassTexture:SetAtlas(atlas); env.MinimapCompassTexture:SetSize(info.width,info.height);
				if rotated then
					env.MinimapCompassTextureUnderlay:SetAtlas("UI-HUD-Minimap-Frame-Circle");
					env.MinimapCompassTextureUnderlay:SetSize(info.width,info.height);
				end
				env.MinimapCompassTextureUnderlay:SetShown(rotated);
			end
			env.CVarCallbackRegistry:SetCVarCachable("rotateMinimap");
			env.CVarCallbackRegistry:RegisterCallback("rotateMinimap",update); update();
			env.nativeSkinSource="offline contract";
		end
		env.CVarCallbackRegistry.RegisterCallback=register;
	end
	local trackingActive=true;
	env.C_Minimap={GetNumTrackingTypes=function() return 1; end,
		GetTrackingInfo=function() return {texture=136025,name="Find Minerals",active=trackingActive,subType=0}; end,
		SetTracking=function(index,active)
			assert(index==1 and type(active)=="boolean", "invalid tracking update");
			stats.trackingCalls[#stats.trackingCalls+1]={index,active}; trackingActive=active;
		end};
	env.FarmHudDB={hud_size=1,hud_scale=1.4,text_scale=1,coords_radius=0.5,time_radius=0.5,
		rotation=true,showDummy=true,showDummyBg=true,strata="L1",player_dot="blizz",
		background_alpha=0,background_alpha2=0.5,background_alpha_toggle=true,
		coords_show=false,time_show=false};
	local ns={L={PingLocationForbidden="HUD pings disabled"}};
	local libs={};
	libs["HizurosSharedTools"]={RegisterPrint=function(n)
		n.print=function(_,...) stats.prints[#stats.prints+1]={...}; end; n.debug=function() end;
	end};
	libs["AceConfigDialog-3.0"]={OpenFrames={}};
	libs["HereBeDragons-Pins-2.0"]={minimapPins={}};
	env.LibStub=setmetatable({libs=libs},{__call=function(_,name) return assert(libs[name],name); end});
	for _,file in ipairs({"FarmHud_Compat.lua","FarmHud.lua"}) do
		local chunk=assert(loadfile(file)); setfenv(chunk,env); chunk("FarmHud",ns);
	end;
	for k,v in pairs(env.FarmHudMixin) do hud[k]=v; end;
	if opts.initialize then hud:OnLoad(); else hud:RegisterForeignAddOnObject(map,"FarmHud"); end;
	return env,ns,button,enterWidths,function() return leaveCalls,restores; end;
end
