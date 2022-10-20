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

function Triggers.init(restoring_game)
   if not restoring_game and Level.rebellion then
      Game._global_inventory = {}
      for _,item in ipairs(SHARED_ITEMS) do
         Game._global_inventory[item] = 0
      end
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
end

function Triggers.idle()
   local old_got_item = Triggers.got_item
   Triggers.got_item = nil
   local lost_items = {}
   for player in Players() do
      if not player.dead then
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
