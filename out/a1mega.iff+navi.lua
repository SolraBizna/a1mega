load([[
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
]], "@header.lua")()
load([[
function Triggers.player_damaged(victim, aggressor_player, aggressor_monster,
                                 damage_type, damage_amount, projectile)
   if aggressor_player and aggressor_player ~= victim
      and (Game.type == "cooperative play"
           or aggressor_player.team == victim.team) then
      -- this will either take effect, or...
      victim.life = victim.life + damage_amount
      -- this will prevent shield from noticing the damage
      return false
   end
end
]], "@iff.lua")()
load([[
local completion_status

local fanfare = {
   1.1224846163807,
   1.0033587084638,
   0.68461715641451,
   0.1912042150039,
   0.12434705970034,
   0.78478970534567,
   1.2486941194007,
   1.8331770558077
}
local fanfare_n, fanfare_tick
local FANFARE_TICKRATE = 4

function Triggers.init()
   completion_status = Level.calculate_completion_state()
end

function Triggers.idle()
   if completion_status == "unfinished" then
      completion_status = Level.calculate_completion_state()
      if completion_status == "finished" then
         Players.print("Mission complete!")
         fanfare_tick = 1
         fanfare_n = 1
      elseif completion_status == "failed" then
         Players.print("Mission failed!")
      end
   end
   if fanfare_tick then
      fanfare_tick = fanfare_tick - 1
      if fanfare_tick <= 0 then
         for player in Players() do
            player:play_sound("adjust volume", fanfare[fanfare_n])
         end
         fanfare_n = fanfare_n + 1
         if fanfare[fanfare_n] then
            fanfare_tick = FANFARE_TICKRATE
         else
            fanfare_tick = nil
         end
      end
   end
end
]], "@navi.lua")()
load([[
function Triggers.idle()
   for player in Players() do
      if player.action_flags.microphone_button then
         player.action_flags.microphone_button = false
      end
   end
end

Triggers = TriggerHandlers
for k,v in pairs(Triggers) do
   if #v == 1 then
      Triggers[k] = v[1]
   else
      local t = v
      Triggers[k] = function(...)
         local errors = {}
         for n=1,#t do
            local s,e = pcall(t[n], ...)
            if not s then
               errors[#errors+1] = e
            elseif e == false then
               break
            end
         end
         if #errors > 0 then
            for _,e in ipairs(errors) do
               Players.print(e)
            end
         end
      end
   end
end
]], "@footer.lua")()
