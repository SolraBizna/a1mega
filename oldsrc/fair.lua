local function make_living_player_hat(exclude)
   local hat = {}
   for player in Players() do
      if player ~= exclude and not player.dead then
         hat[#hat+1] = player
      end
   end
   return hat
end

local function shuffle_hat(hat)
   local shat = {}
   while #hat > 1 do
      table.insert(shat, table.remove(hat, Game.random(#hat)+1))
   end
   if #hat == 1 then
      table.insert(shat, hat[1])
   end
   return shat
end

local WEAPONS = {}
for _,v in ipairs{"pistol","fusion pistol","assault rifle","missile launcher",
                  "alien weapon","flamethrower","shotgun","smg"} do
   WEAPONS[#WEAPONS+1] = assert(Items[v])
end
local AMMO = {}
for _,v in ipairs{"pistol ammo","fusion pistol ammo","assault rifle ammo",
                  "assault rifle grenades","missile launcher ammo",
                  "alien weapon ammo","flamethrower ammo","shotgun ammo",
                  "smg ammo"} do
   AMMO[#AMMO+1] = assert(Items[v])
end
local SPECIALS = {}
for _,v in ipairs{"key","uplink chip"} do
   SPECIALS[#SPECIALS+1] = assert(Items[v])
end

function Triggers.idle()
   if Game.type ~= "cooperative play" then return end
   for player in Players() do
      if player.dead then
         local hat
         for _,weapon in ipairs(WEAPONS) do
            if player.items[weapon] > 0 then
               if not hat then hat = make_living_player_hat(player) end
               if #hat == 0 then break end
               hat = shuffle_hat(hat)
               for _,other in ipairs(hat) do
                  if other.items[weapon] == 0 then
                     other.items[weapon] = 1
                     player.items[weapon] = player.items[weapon] - 1
                     if player.items[weapon] == 0 then break end
                  end
               end
            end
         end
         -- TODO: item maxes
         for _,ammo in ipairs(AMMO) do
            if player.items[ammo] > 0 then
               if not hat then hat = make_living_player_hat(player) end
               if #hat == 0 then break end
               hat = shuffle_hat(hat)
               local sort_hat = {}
               for i,player in ipairs(hat) do
                  sort_hat[i] = player
                  player._shuffle_index = i
               end
               while player.items[ammo] > 0 do
                  table.sort(sort_hat,
                             function(a,b)
                                if a.items[ammo] < b.items[ammo] then
                                   return true
                                elseif a.items[ammo] == b.items[ammo] then
                                   return a._shuffle_index < b._shuffle_index
                                else
                                   return false
                                end
                  end)
                  sort_hat[1].items[ammo] = sort_hat[1].items[ammo] + 1
                  player.items[ammo] = player.items[ammo] - 1
               end
               for i,player in ipairs(hat) do
                  player._shuffle_index = nil
               end
            end
         end
         -- TODO: handle specials
      end
   end
end
