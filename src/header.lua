--! configuration 1.0
--! toggle enable_port "Allow Teleporting to Teammates"
local enable_port = false
--! toggle enable_navi "Announce Mission Completion"
local enable_navi = false
--! toggle enable_iff "Disable Friendly Fire"
local enable_iff = false
--! toggle enable_aw "Enhance Automatic Weapons"
local enable_aw = true
--! toggle enable_shld "Halo-Style Shields"
local enable_shld = true
--! toggle enable_hardcore "Hardcore Co-op Mode"
local enable_hardcore = true
--! select inventory_mode "Inventory Mode" "Normal" "Shared" "Fisto!"
local inventory_mode = 2
--! end configuration

a1megas_enabled = {
   aw=enable_aw,
   fair=inventory_mode == 2,
   fisto=inventory_mode == 3,
   hardcore=enable_hardcore,
   iff=enable_iff,
   navi=enable_navi,
   port=enable_port,
   shld=enable_shld,
}

Triggers = {}
TriggerHandlers = {}

local function newindex(t,k,v)
   assert(type(v) == "function")
   local th = TriggerHandlers[k]
   if not th then
      th = {}
      TriggerHandlers[k] = th
   end
   th[#th+1] = v
end

setmetatable(Triggers, {__newindex=newindex})

function Triggers.init(restoring_game)
   Game.proper_item_accounting = true
   if restoring_game then
      Game.restore_saved()
   else
      Game.restore_passed()
   end
end

