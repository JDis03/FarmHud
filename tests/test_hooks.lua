local fixture=dofile("tests/widget_fixture.lua");

local function setup(handlers)
	local env=fixture(18,16001,true);
	local map,hud=env.Minimap,env.FarmHud;
	local widget=env.CreateFrame("Frame", "HookTest", map);
	widget:SetPoint("CENTER",map,"CENTER",0,0);
	local present=false;
	for _,child in ipairs(map.children) do if child==widget then present=true; end; end;
	if not present then map.children[#map.children+1]=widget; end;
	for event,fn in pairs(handlers) do widget:SetScript(event,fn); end;
	return env,map,hud,widget;
end

-- Both missing release handlers must receive a cleanup wrapper.
for _,pair in ipairs({{"OnEnter","OnLeave"},{"OnDragStart","OnDragStop"}}) do
	local env,map,hud,widget=setup({[pair[1]]=function() end});
	hud:Toggle(true);
	widget:GetScript(pair[1])(widget);
	assert(map:GetWidth()==140);
	assert(type(widget:GetScript(pair[2]))=="function");
	widget:GetScript(pair[2])(widget);
	assert(map:GetWidth()>140, "missing original release must not leak a lock");
	widget:GetScript(pair[1])(widget);
	hud:Toggle(false); hud:Toggle(true);
	assert(map:GetWidth()>140, "a new HUD visit must reset outstanding ownership");
	hud:Toggle(false);
end

-- All original callbacks see the same geometry and receive exact arguments.
local calls={};
local env,map,hud,widget;
local handlers={};
for _,event in ipairs({"OnEnter","OnLeave","OnDragStart","OnDragStop"}) do
	handlers[event]=function(self,first,second)
		assert(self==widget and first=="payload" and second==42);
		assert(map:GetWidth()==140, event.." must see dummy geometry");
		calls[event]=(calls[event] or 0)+1;
		return "result",nil,42;
	end;
end
env,map,hud,widget=setup(handlers);
hud:Toggle(true);
local function dispatch(event)
	local a,b,c=widget:GetScript(event)(widget,"payload",42);
	assert(a=="result" and b==nil and c==42, "preserve callback results");
end
dispatch("OnEnter"); dispatch("OnDragStart"); dispatch("OnLeave");
assert(map:GetWidth()==140, "leaving during drag must not release drag ownership");
dispatch("OnDragStop"); assert(map:GetWidth()>140);
dispatch("OnEnter"); dispatch("OnDragStart"); dispatch("OnDragStop");
assert(map:GetWidth()==140, "stopping drag while hovered must keep hover ownership");
dispatch("OnLeave"); assert(map:GetWidth()>140);
for _,event in ipairs({"OnEnter","OnLeave","OnDragStart","OnDragStop"}) do assert(calls[event]==2); end;
hud:Toggle(false);

-- Errors in acquire/release callbacks must not leak either ownership/context.
for _,event in ipairs({"OnEnter","OnLeave","OnDragStart","OnDragStop"}) do
	local e,m,h,w=setup({[event]=function() error("intentional callback failure"); end});
	h:Toggle(true);
	local ok,message=pcall(w:GetScript(event),w);
	assert(not ok and message:find("intentional callback failure",1,true));
	assert(m:GetWidth()>140, "callback exception must release dummy context");
	h:Toggle(false); h:Toggle(true);
	assert(m:GetWidth()>140);
	h:Toggle(false);
end
print("Hover/drag ownership regression tests passed");

-- Release-only configurations synthesize acquire, and reentrant release
-- callbacks must not erase a new acquisition for the same widget.
for _,pair in ipairs({{"OnEnter","OnLeave"},{"OnDragStart","OnDragStop"}}) do
	local e,m,h,w;
	local calls=0;
	e,m,h,w=setup({[pair[2]]=function()
		calls=calls+1;
		assert(m:GetWidth()==140);
		if calls==1 then w:GetScript(pair[1])(w); end;
	end});
	h:Toggle(true);
	w:GetScript(pair[1])(w);
	w:GetScript(pair[2])(w);
	assert(m:GetWidth()==140, "release must preserve a reentrant acquisition");
	w:GetScript(pair[2])(w);
	assert(m:GetWidth()>140 and calls==2);
	h:Toggle(false);
end

-- Different widgets own their contexts independently.
local e,m,h,w=setup({OnEnter=function() end,OnLeave=function() end});
local other=e.CreateFrame("Frame","OtherHookTest",m);
other:SetPoint("CENTER",m,"CENTER",0,0);
other:SetScript("OnEnter",function() end); other:SetScript("OnLeave",function() end);
local present=false;
for _,child in ipairs(m.children) do if child==other then present=true; end; end;
if not present then m.children[#m.children+1]=other; end;
h:Toggle(true);
w:GetScript("OnEnter")(w); other:GetScript("OnEnter")(other);
w:GetScript("OnLeave")(w);
assert(m:GetWidth()==140, "releasing one widget must not release another");
other:GetScript("OnLeave")(other);
assert(m:GetWidth()>140);
h:Toggle(false);
print("Reentrant/multiple-widget regression tests passed");
