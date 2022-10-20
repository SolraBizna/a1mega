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
