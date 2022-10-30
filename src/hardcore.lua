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
            if not Game._checkpointed_players[player.name].dead then
               player:revive()
            end
         end
         RESTART_COUNTDOWN = nil
         Game._forcing_restart = get_level_id()
         Players[0]:teleport_to_level(Level.index)
      end
   end
end
