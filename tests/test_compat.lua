local function loadAddon(env, ns, file)
	local chunk = assert(loadfile(file));
	setfenv(chunk, env);
	chunk("FarmHud", ns);
end

local function environment(project, interfaceVersion)
	local env = setmetatable({}, {__index = _G});
	env._G = env;
	env.WOW_PROJECT_ID = project;
	env.WOW_PROJECT_MAINLINE = 1;
	env.WOW_PROJECT_CLASSIC = 2;
	env.WOW_PROJECT_CAMELOT = 18;
	env.GetBuildInfo = function() return "1.60.1", "70235", "", interfaceVersion; end;
	env.SlashCmdList = {};
	return env;
end

for _, case in ipairs({{18,16001,true,true}, {2,11509,false,false}, {1,120100,false,true}, {5,20506,false,false}}) do
	local env, ns = environment(case[1], case[2]), {};
	loadAddon(env, ns, "FarmHud_Compat.lua");
	assert(ns.IsForever() == case[3], "client classification");
	assert(ns.HasModernMinimapSkin() == case[4], "minimap skin classification");
	assert(env.WOW_PROJECT_ID == case[1], "must not spoof the game project");
	env.Root = {Container = {Frame = {}}};
	assert(ns.ResolveGlobalFrame("Root.Container.Frame") == env.Root.Container.Frame);
	assert(ns.ResolveGlobalFrame("Root.Missing.Frame") == nil);
	assert(ns.ResolveGlobalFrame("Absent.Frame") == nil);
	assert(ns.ResolveGlobalFrame("WOW_PROJECT_ID.Frame") == nil);
end

-- Diagnostic command tolerates unavailable optional APIs and is read-only.
local env, ns = environment(18, 16001), {};
local lines = {};
env.print = function(line) lines[#lines+1] = line; end;
loadAddon(env, ns, "FarmHud_Compat.lua");
env.SlashCmdList.FARMHUDCOMPAT();
assert(#lines == 2 and lines[1]:find("interface=16001", 1, true));
assert(lines[2]:find("tracking=nil", 1, true));
print("Client compatibility tests passed");
