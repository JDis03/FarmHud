-- Run from the repository root: lua5.1 tests/test_buttons.lua
local frames = {}
local ns = {L = {}, modules = {}}

FarmHud = {}
FarmHudDB = {}

function CreateFrame(frameType,name,parent,template)
	local frame = {
		frameType = frameType,
		parent = parent,
		template = template,
		scripts = {},
		pushedTexture = {},
	}
	function frame:SetPoint(...)
		self.point = {...}
	end
	function frame:SetNormalTexture(texture)
		self.normalTexture = texture
	end
	function frame:SetPushedTexture(texture)
		self.pushedTexture.path = texture
	end
	function frame:GetPushedTexture()
		return self.pushedTexture
	end
	function frame.pushedTexture:SetDesaturated(state)
		self.desaturated = state
	end
	function frame:SetScript(script,func)
		self.scripts[script] = func
	end
	frames[#frames+1] = frame
	return frame
end

assert(loadfile("modules/OnScreenButtons.lua"))("FarmHud",ns)
local module = assert(ns.modules.OnScreenButtons)
local eventFrame = {
	registered = {ADDON_LOADED = true, PLAYER_LOGIN = true},
	unregisterCount = 0,
}
function eventFrame:UnregisterEvent(event)
	assert(event=="ADDON_LOADED", "only ADDON_LOADED should be unregistered")
	self.registered[event] = nil
	self.unregisterCount = self.unregisterCount+1
end
module.eventFrame = eventFrame

-- Match moduleEventFunc's arguments, even when forcing a duplicate event
-- after unregistration to exercise the initialization guard independently.
local function dispatch(event,...)
	module.events[event](module.eventFrame,...)
end

dispatch("ADDON_LOADED","OtherAddon")
dispatch("ADDON_LOADED","FarmHud_Extra")
assert(#frames==0, "unrelated addon events must not allocate frames")
assert(FarmHud.onScreenButtons==nil, "unrelated addon events must not initialize buttons")
assert(eventFrame.registered.ADDON_LOADED, "keep listening until FarmHud loads")
assert(eventFrame.unregisterCount==0)

dispatch("ADDON_LOADED","FarmHud")
assert(#frames==5, "initialize exactly one container and four buttons")
local container = FarmHud.onScreenButtons
assert(container==frames[1])
assert(container.frameType=="Frame" and container.parent==FarmHud)
assert(container.template=="FarmHudOnScreenButtonsTemplate")
local buttonNames = {"mouseButton", "backgroundButton", "optionsButton", "closeButton"}
local seen = {}
for _,name in ipairs(buttonNames)do
	local button = assert(container[name], "missing button: "..name)
	assert(not seen[button], "each button must be a distinct frame")
	seen[button] = true
	assert(button.frameType=="Button" and button.parent==container)
	assert(button.template=="FarmHudonScreenButtonTemplate")
	assert(button.point[1]=="CENTER")
	assert(button.normalTexture and button.pushedTexture.path)
	assert(type(button.scripts.OnClick)=="function")
end
for i=2,#frames do
	assert(seen[frames[i]], "unexpected button frame")
end
assert(not eventFrame.registered.ADDON_LOADED, "stop listening after initialization")
assert(eventFrame.registered.PLAYER_LOGIN, "preserve other event registrations")
assert(eventFrame.unregisterCount==1)

dispatch("ADDON_LOADED","FarmHud")
dispatch("ADDON_LOADED","AnotherAddon")
assert(#frames==5, "duplicate and unrelated events must not allocate more frames")
assert(FarmHud.onScreenButtons==container, "keep the original container")
assert(eventFrame.unregisterCount==1, "unregister only once")
for _,name in ipairs(buttonNames)do
	assert(seen[container[name]], "keep the original buttons")
end

assert(module.dbDefaults.buttons_bottom==false, "use the option's correct default key")
assert(module.dbDefaults.buttons_buttom==nil, "remove the misspelled default key")
dispatch("PLAYER_LOGIN")
assert(FarmHudDB.buttons_bottom==false)
FarmHudDB.buttons_bottom = true
dispatch("PLAYER_LOGIN")
assert(FarmHudDB.buttons_bottom==true, "preserve an existing bottom-position setting")

print("OnScreenButtons regression tests passed")
