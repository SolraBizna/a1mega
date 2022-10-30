a1megas_enabled = {
  fair=true,
  hardcore=true,
  iff=true,
}

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
load([=[
local SHARED_ITEMS = {}
for _,v in ipairs{"pistol","fusion pistol","assault rifle","missile launcher",
                  --[["alien weapon",]]"flamethrower","shotgun","smg",
                  "pistol ammo","fusion pistol ammo","assault rifle ammo",
                  "assault rifle grenades","missile launcher ammo",
                  --[["alien weapon ammo",]]"flamethrower ammo","shotgun ammo",
                  "smg ammo"} do
   local item = assert(ItemTypes[v], v)
   SHARED_ITEMS[item] = #SHARED_ITEMS+1
   SHARED_ITEMS[#SHARED_ITEMS+1] = item
end
local DEFAULT_ITEMS = {
   [ItemTypes["pistol"]] = 1,
   [ItemTypes["pistol ammo"]] = 3,
}

a1mega = a1mega or {}
a1mega.SHARED_ITEMS = SHARED_ITEMS

function a1mega.shallow_clone(i)
   local o = {}
   for key,value in pairs(i) do o[key]=value end
   return o
end

local function force_inventory_sync()
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   for player in Players() do
      for _,item in ipairs(SHARED_ITEMS) do
         if player.items[item] ~= Game._global_inventory[item] then
            player.items[item] = Game._global_inventory[item]
         end
      end
   end
   Triggers.got_item = old_got_item
end
a1mega.force_inventory_sync = force_inventory_sync

function Triggers.init(restoring_game)
   if not restoring_game and Level.rebellion then
      Game._global_inventory = {}
      for _,item in ipairs(SHARED_ITEMS) do
         Game._global_inventory[item] = 0
      end
   elseif not restoring_game and a1megas_enabled.hardcore and Game._checkpointed_global_inventory and a1mega.forcing_restart() then
      Game._global_inventory = a1mega.shallow_clone(Game._checkpointed_global_inventory)
      force_inventory_sync()
   elseif Game._global_inventory == nil or not Game._gi_ticks
   or Game._gi_ticks < Game.ticks - 5 then
      Game._global_inventory = {}
      for _,item in ipairs(SHARED_ITEMS) do
         Game._global_inventory[item] = 0
      end
      -- only bit of nondeterminism
      for k,v in pairs(DEFAULT_ITEMS) do
         Game._global_inventory[k] = v
      end      
      for player in Players() do
         for _,item in ipairs(SHARED_ITEMS) do
            if player.items[item] > (DEFAULT_ITEMS[item] or 0) then
               Game._global_inventory[item] = Game._global_inventory[item]
                  + (player.items[item] - (DEFAULT_ITEMS[item] or 0))
            end
         end
      end
      force_inventory_sync()
   end
end

function Triggers.idle()
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   local lost_items = {}
   for player in Players() do
      if not player.dead then
         if player.items["knife"] < 2 then
            player.items["knife"] = 2
         end
         for _,item in ipairs(SHARED_ITEMS) do
            if player.items[item] < Game._global_inventory[item] then
               lost_items[item] = (lost_items[item] or 0)
                  + (Game._global_inventory[item] - player.items[item])
            elseif (player.items[item] or 0) > Game._global_inventory[item]
            then
               Players.print("Shenanigans! "..player.name.." had too many "..item.mnemonic.."!")
               player.items[item] = Game._global_inventory[item]
            end
         end
      end
   end
   for _,item in ipairs(SHARED_ITEMS) do
      local count = lost_items[item]
      if count then
         if Game._global_inventory[item] < count then
            Players.print("Got a freebie "..item.mnemonic.."!")
            Game._global_inventory[item] = 0
         else
            Game._global_inventory[item] = Game._global_inventory[item] - 1
         end
      end
   end
   for player in Players() do
      if not player.dead then
         for _,item in ipairs(SHARED_ITEMS) do
            local count = lost_items[item]
            if count then
               player.items[item] = Game._global_inventory[item]
            end
         end
      end
   end
   Triggers.got_item = old_got_item
   Game._gi_ticks = Game.ticks
end

function Triggers.got_item(item, player)
   if not SHARED_ITEMS[item] then return end
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   Game._global_inventory[item] = (Game._global_inventory[item] or 0) + 1
   for other in Players() do
      if other ~= player and not other.dead then
         other.items[item] = Game._global_inventory[item]
      end
   end
   Triggers.got_item = old_got_item
end

function Triggers.player_revived(player)
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   for item,amount in pairs(Game._global_inventory) do
      if player.items[item] ~= amount then
         player.items[item] = amount
      end
   end
   Triggers.got_item = old_got_item
   player.weapons.active = true
end

function Triggers.player_killed(player)
   for _,item in ipairs(SHARED_ITEMS) do
      player.items[item] = 0
   end
   player.weapons.active = false
end
]=], "@fair.lua")()
load([[
local COUNTDOWN_OVERLAY = 3

local RESTART_COUNTDOWN = 15 * 30

a1mega = a1mega or {}
a1mega.SHARED_ITEMS = a1mega.SHARED_ITEMS or {}

local function get_level_id()
   return Level.map_checksum .. "_" .. Level.index
end

function a1mega.forcing_restart()
   return Game._forcing_restart == get_level_id()
end

local keys_to_backup = {}
if a1megas_enabled.aw then
   for weapon in WeaponTypes() do
      keys_to_backup["_weapon"..weapon.index.."_firemode"] = true
   end
   for _,v in ipairs{"_auto_spread","_burst_decay"} do keys_to_backup[v] = true end
end
if a1megas_enabled.shld then
   for _,v in ipairs{"_health","_max_shield","_shield","_damage_timeout","_health_regen_timeout","_recharging_health","_bleeding","_bleed_timeout","_oxygen_tank","_oxygen_gauge","_virtual"} do keys_to_backup[v] = true end
else
   for _,v in ipairs{"life","oxygen"} do keys_to_backup[v] = true end
end
for _,v in ipairs{"extravision_duration","infravision_duration","invincibility_duration","invisibility_duration"} do keys_to_backup[v] = true end

local function restore_player(player)
   local src = assert(Game._checkpointed_players[player.name])
   Game._marked_for_delayed_restore = nil
   for key in pairs(keys_to_backup) do
      player[key] = src[key]
   end
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   for type in ItemTypes() do
      player.items["knife"] = 2
      if not a1mega.SHARED_ITEMS[type.mnemonic] and type.mnemonic ~= "knife" then
         -- this will refill weapons
         player.items[type] = 0
         player.items[type] = src.items[type.index]
      end
   end
   Triggers.got_item = old_got_item
end

local go

function Triggers.init(restoring_game)
   go = Game.type.index == 0 or Game.type.index == 1
   if not go then return end
   if not restoring_game then
      for player in Players() do
         if player.dead then player._marked_for_revival = true end
      end
   end
   if restoring_game then
      -- do nothing
   elseif Game._checkpointed_players and a1mega.forcing_restart() then
      for player in Players() do
         local src = Game._checkpointed_players[player.name]
         if player.dead then
            player._marked_for_revival = true
            player._marked_for_delayed_restore = true
            goto continue
         end
         if not src then goto continue end
         restore_player(player)
         ::continue::
      end
      Game._forcing_restart = nil
   else
      Game._checkpointed_players = {}
      for player in Players() do
         if player.dead then
            player._marked_for_revival = true
         else
            local tab = {}
            for key in pairs(keys_to_backup) do
               tab[key] = player[key]
            end
            tab.dead = player.dead
            tab.items = {}
            for itemtype in ItemTypes() do
               tab.items[itemtype.index] = player.items[itemtype]
            end
            Game._checkpointed_players[player.name] = tab
         end
      end
      if a1megas_enabled.fair then
         Game._checkpointed_global_inventory = a1mega.shallow_clone(Game._global_inventory)
      end
      Game._checkpointed_level = get_level_id() -- TODO: unused?
   end
end

local did_disappoint = false
function Triggers.idle()
   if not go then return end
   local any_left_alive = false
   for player in Players() do
      if player._marked_for_revival then
         -- they are supposed to be alive, it's not their fault if their
         -- teammates all died before they could finish respawning
         any_left_alive = true
         if player.totally_dead then
            player:revive()
            player._marked_for_revival = false
            if player._marked_for_delayed_restore then
               restore_player(player)
            end
         end
      elseif player.dead then
         -- ded
         player.action_flags.action_trigger = false
      else
         -- aleve
         any_left_alive = true
      end
   end
   if any_left_alive then
      for player in Players() do
         player.overlays[COUNTDOWN_OVERLAY]:clear()
      end
   else
      if RESTART_COUNTDOWN == nil then
         for player in Players() do
            player:fade_screen("long bright")
         end
         -- nothing to do
      elseif RESTART_COUNTDOWN > 0 then
         RESTART_COUNTDOWN = RESTART_COUNTDOWN - 1
         for player in Players() do
            player.overlays[COUNTDOWN_OVERLAY].text = ("Restart in %is..."):format(math.ceil(RESTART_COUNTDOWN/30))
            player.overlays[COUNTDOWN_OVERLAY].color = "cyan"
            if not did_disappoint then
               player:play_sound("you are it", 0.25)
            end
         end
         did_disappoint = true
      else
         for player in Players() do
            player.overlays[COUNTDOWN_OVERLAY].text = "Waiting to restart..."
            if not player.totally_dead then
               return
            end
         end
         for player in Players() do
            player:fade_screen("long bright")
            player.overlays[COUNTDOWN_OVERLAY].text = "Restarting..."
            if not Game._checkpointed_players or not Game._checkpointed_players[player.name] or not Game._checkpointed_players[player.name].dead then
               player:revive()
            end
         end
         RESTART_COUNTDOWN = nil
         Game._forcing_restart = get_level_id()
         Players[0]:teleport_to_level(Level.index)
      end
   end
end
]], "@hardcore.lua")()
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
