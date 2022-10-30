This is my "Aleph One Mega Script". It consists of multiple sub-scripts, designed to play nicely together. Install by copying the `A1mega Scripts` directory to your Aleph One data folder. You choose which sub-scripts to enable by choosing the appropriate composite script from that directory. For example, to enable only the `aw` and `shld` scripts, you would choose `a1mega.aw+shld.lua` as your netscript or solo script.

Other than `hardcore`, these scripts are ancient. While I've done a lot of solo and netplay with every one of them, most of that play was more than a decade ago. Caveat player.

# `aw`: Automatic weapon improvements

Makes automatic weapons have selective fire, and makes them more accurate when fired in short bursts.

Weapons default to automatic mode, making them fire the same way as in vanilla. Change firing modes by pulling the trigger **while holding the microphone key** (default \`).

The default configuration gives the Assault Rifle a two-round burst mode and a single-shot mode, and the Submachine Gun a two-round burst mode, in addition to their vanilla automatic modes. It will apply its accuracy bonus/penalty to any weapon firing "rifle bullet" or "smg bullet".

**Modes**: Compatible with all game modes.

**Scenarios**: This is fully compatible with the original Trilogy, and with any scenario that uses those weapon and projectile slots for similar purposes. You can adjust the script for other scenarios by changing the `AUTOMATIC_PROJECTILES` and `WEAPON_MODE_SELECTIONS` tables at the top of the script. (Note that the `burst` is given in *ticks*, as in, number of ticks to force the trigger to be held down.)

# `fair`: Shared ("fair") co-op inventory

Alters item pickup mechanics so that every player has an (almost) shared inventory for weapons and ammunition. Uplink chip, etc. are *not* shared, nor is the number of bullets per weapon synchronized. The Alien Weapon is not synchronized either, since its mechanics differ.

This is great if you're playing co-op, and one player is a lot more familiar with the scenario than the others, and that player hogs all the secret ammo. It's also great if you die a lot and would otherwise suffer from the "disappearing ammo problem".

**Modes**: Co-op. Technically works in other netplay modes, but since all players share one global inventory, it would only be worth doing for laughs.

**Scenarios**: This is fully compatible with the original trilogy, and with any scenario that uses the weapon and ammo item slots the same way and has the same starting inventory. You can add or remove shared status from individual items by editing the `SHARED_ITEMS` at the top of the script, and change the default inventory (so that it knows which items to un-duplicate) by editing the `DEFAULT_ITEMS` table.

# `hardcore`: Consequences for death

This script is designed for use in co-op. It prevents players from respawning manually; instead, they will respawn at the next level transition. In addition, if all players die, it will restart the level, restoring everyone's inventories, health, powerups, etc. to what they were when they entered the level.

Consider combining with `fair` so that dead players don't lose all their weapons.

**Modes**: Solo or co-op. Not very useful in solo, but maybe automatically restarting at the beginning of the level instead of at your last save is your jam.

**Scenarios**: Compatible with most scenarios. Persistent script effects added by scenarios (such as Marathon: Phoenix's regenerator powerup) will not be restored when a level is restarted.

Note: When restoring a level, all weapons will be refilled. There is no way to work around this in the current version of the engine.

# `iff`: Identify Friend and Foe, prevents friendly fire

Prevents any player from directly damaging any other player on the same team. All other damage sources are unchanged.

**Modes**: Any multiplayer mode.

**Scenarios**: Compatible with all scenarios, unless the scenario has strange things like projectiles that create monsters.

# `navi`: Inform players of mission success

Prints a message when the level's completion status changes from unfinished to finished, or from unfinished to failed. (Does nothing on changes between finished and failed, or from anything to unfinished.)

Why is it called `navi`? You'll just have to try it and find out.

**Modes**: Singleplayer and co-op.

**Scenarios**: Compatible with all scenarios. Scenarios that modify the "adjust volume" sound may have an unpleasant fanfare.

# `port`: Controlled teleport to friends while out of combat

Allows players to teleport to their teammates during calm situations. Created to reduce frustration with *a certain Marathon 1 level*, though it doesn't fully prevent that softlock. Also useful when one player knows the scenario a lot better than the others, or some players have a very poor sense of direction.

Activate the system by holding the microphone key (default \`). While holding the key down, use the next and previous weapon keys to select which player to teleport to, and quickly press the map key (default M) three times to teleport to them.

Warranty void when used to maliciously tele-bump your soon-to-be-ex friends.

**Modes**: Netplay.

**Scenarios**: Compatible with all scenarios. Scenarios that extensively modify the sounds may give strange audible feedback.

# `shld`: The infamous shield script (or one of them)

This script significantly alters the mechanics of the game regarding damage taken and oxygen consumed.

Players are given separate health and shields, just like in Halo. Shield strength is shown on the life meter in the HUD, while your current health value is shown on what is normally the oxygen meter. Players are slightly more fragile on average than in vanilla, but the game becomes more forgiving of incidental damage.

When relevant, an oxygen meter will appear as a HUD overlay in the upper left corner of the screen. The player can "hold their breath" for up to ten seconds, after which they will begin consuming oxygen from their tank exactly like in vanilla. (This means you won't consume oxygen from the tank during brief surface swims, and makes little difference otherwise.)

**Modes**: Any mode.

**Scenarios**: Compatible with most scenarios, except those that:

- ...extensively modify sounds, in which case some or all audio feedback will be wrong. (Marathon 1 counts as one of these.)
- ...add new shield pickups, or edit the existing ones to some other purpose.
- ...use Lua or MML to change shield or oxygen mechanics. (Minor changes to MML may be okay.)

## Overly long description of shield mechanics

Skip this description if you don't want the nitty gritty details.

At full health, you can absorb 75 damage. One layer of shield can also absorb 75 damage. This means that the amount of damage you can survive at full health and "red shield" is the same as in vanilla (150), whereas having full health and "purple shield" lets you absorb the same amount of damage as a vanilla "yellow shield" (300).

In a "Rebellion" level, you start with no shield and damaged health. Starting on any other level gives you full health and one layer of shield.

Any damage will be applied to your shield until it is depleted, and only then applied to your health. Melee damage (such as fists and claws) is an exception, if you have only one shield layer (red), half of melee damage will pass through the shield and affect your health. A second layer of shield (yellow or better) prevents this, fully protecting against all damage.

You will regenerate damaged health slowly over time, unless you are bleeding. Bleeding occurs if you are hit by a bullet or a claw attack and any of the damage gets through your shield. Bleeding causes you to lose health over time. Bleeding will never kill you, but it can bring you down to zero health and keep you there indefinitely. Stop bleeding by interacting with any shield recharger or by activating a pattern buffer. (F'lick'ta and Devlins are especially dangerous, as their claw attacks can partly penetrate a single layer of shield and cause bleeding!)

You can add layers to your shield by using a recharger or picking up an appropriate pickup. A 1x/red recharger gives you one layer, 2x/yellow gives two layers, and 3x/purple gives three layers.

If your shield is entirely depleted (not *destroyed*), it loses the ability to self-recharge. Reactivate your shields by interacting with a shield recharger. Fret not upon losing your precious 3x/purple shield, for even a 1x/red shield recharger can jump start it back into full operation. Unless electric damage is involved...

Electric damage does double damage to shields, and can even destroy layers of shield. Sources of electric damage include S'pht weapons, Pfhor shock staves, and the Fusion Pistol. Taking a hit from electric damage while your top layer of shield is depleted will *destroy* that layer. Only an appropriate recharger or shield pickup can restore destroyed layers of shield. Be especially careful about electric damage while your shields are down, as this can leave you completely shieldless!

# Legalese

These scripts and all associated source code are licensed under the zlib license (see [`LICENSE.md`](LICENSE.md)). You are basically free to do anything reasonable to them, as long as you don't pretend that your changes are the original.

I encourage you to contribute any worthwhile changes you might make back to this repository. If you do, you agree to license any contributions under the same license, and assign copyright to me.
