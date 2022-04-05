version "4.2.4"

/*
	Grappling Hook by Agent_Ash aka Jekyll Grim Payne
	Free to use in your projects.
	Credits are appreciated but not required.
	
	How to use: give yourself GrapplingHook item by any means, then press User 3 key.
*/


/*	This inventory token handles firing the hook. Firing it from Inventory
	is not a must; this code can be moved into a weapon, to be used
	as one of the weapon's attacks for example.
*/
Class GrapplingHook : Inventory {
	HookProjectile hook; //pointer to the spawned hook
	Default {
		//These properties/flags just make sure the token doesn't get
		//removed from player's inventory:
		+INVENTORY.UNDROPPABLE;
		+INVENTORY.UNTOSSABLE;
		+INVENTORY.UNCLEARABLE;
		+INVENTORY.PERSISTENTPOWER;
		inventory.maxamount 1;
	}
	
	/*	The hook is supposed to have a tiny bit of autoaim when fired at 
		a monster, otherwise it'd be rather frustrating to use. So, I use
		this function to check how far the possible hook target (monster)
		is from the player's crosshair.
		The function checks the angle and pitch offsets from the player
		to the potential hook target. Returns a vector2 value where
		X is the horizontal offset (angle) and Y is the vertical offset
		(pitch).
		Check distance is 320 by default.
	*/
	vector2 FindHooktargetOfs(int atkdist = 320, double maxangofs = 11, double maxpitchofs = 11) {
		vector2 ofs;
		double closestDist = double.infinity; //We'll find the closest possible target
		BlockThingsIterator itr = BlockThingsIterator.Create(owner,atkdist);
		while (itr.next()) {
			//Get a pointer to the found object:
			let next = itr.thing;
			//Skip if it's the same as the owner:
			if (next == owner)
				continue; 
			//Skip if the object is not shootable and neither a monster or a player:
			if (!next.bShootable || !(next.bIsMonster || (next is "PlayerPawn")))
				continue;
			//Check distance to the object:
			double dist = owner.Distance3D(next);
			//Skip if the distance is too large:
			if (dist > atkdist)
				continue;
			//Record distance to target:
			if (dist < closestDist)
				closestDist = dist;
			//Check the player can see it:
			if (!owner.CheckSight(next,SF_IGNOREWATERBOUNDARY))
				continue;
			//SphericalCoords gets us the offsets themselves:
			vector3 targetpos = LevelLocals.SphericalCoords((owner.pos.x,owner.pos.y,owner.player.viewz),next.pos+(0,0,next.default.height*0.5),(owner.angle,owner.pitch));
			//If either hozital or vertical offsets are too large, do nothing:
			if (abs(targetpos.x) > maxangofs || abs(targetpos.y) > maxpitchofs)
				continue;
			ofs = targetpos.xy;
		}
		return ofs;
	}
	
	//Inventory tokens don't need to Tick, so we'll make it empty:
	override void Tick() {}
	
	//We'll check for +user3 being pressed here:
	override void DoEffect() {
		super.DoEffect();
		if (!owner || !owner.player)
			return;
		if (owner.health <= 0)
			return;
		if (!hook && (owner.player.buttons & BT_USER3)) {
			//console.printf("Firing grappling hook");
			owner.A_StartSound("ghook/fire",CHAN_AUTO);
			vector2 ofs = FindHooktargetOfs();
			hook = HookProjectile(owner.A_SpawnProjectile("HookProjectile",angle:ofs.x,flags:CMF_AIMDIRECTION,pitch:owner.pitch+ofs.y));
		}
	}
}

/*	This is a rather generic fading-out trail for the hook projectile. 
	Feel free to use something else in your project.
*/
Class HookProjectileTrail : Actor {
	Default {
		renderstyle 'Translucent';
		alpha 0.8;
		scale 0.3;
	}
	override void Tick() {
		if (isFrozen())
			return;
		A_FadeOut(0.1);
	}
	states {
	Spawn:
		BAL1 A -1;
		stop;
	}
}

/*	The hook projectile itself. Looks like a small DoomImpBall.
*/
Class HookProjectile : Actor {
	vector3 spawnPos;
	int maxdistance;
	int flytime;
	HookControl control;
	protected double prevspeed;
	double dragspeed;
	property dragspeed : dragspeed;
	property maxdistance : maxdistance;
	Default {
		HookProjectile.maxdistance 720; //Max distance the hook can cover
		HookProjectile.dragspeed 25; //How fast the hook drags the player
		projectile;
		damage 0;
		speed 25;
		+HITTRACER //The hook gets a tracer pointer to the monster it hits
		+BLOODLESSIMPACT
		scale 0.4;
		deathsound "ghook/hit";
	}
	override void PostBeginPlay() {
		super.PostBeginPlay();
		spawnPos = pos; //record the spawn coordinates
	}
	override void Tick() {
		super.Tick();
		if (isFrozen())
			return;
		// Spawn the trail:
		Spawn("HookProjectileTrail",pos);
		// If the hook flew too far from the spawnpos, return it:
		if (level.Vec3Diff(pos, spawnPos).length() > maxdistance && !inStateSequence(curstate,FindState("Flyback")))
			SetStateLabel("Flyback");
	}
	states {
	Spawn:
		BAL1 A 1;
		loop;
	// The hook hits a wall:
	Death:
		TnT1 A 0 A_Scream();
		BAL1 A 1 {
			// If the hook hit something, stop the player's movement:
			if (target && target.player) {
				prevspeed = target.speed; //record player's current speed
				target.speed = 0; //set it to 0
				// Now set the player's velocity to make them fly towards the wall:
				target.vel = target.Vec3To(self).Unit() * dragspeed;
				// Check if the player is close enough to the hook:
				if (Distance3D(target) <= 64) {
					target.speed = prevspeed; //reset the player's speed
					destroy(); //destroy the hook
				}
			}
		}
		wait;
	// The hook hits a monster:
	XDeath:
		TNT1 A 0 A_Scream();
		BAL1 A 1 {
			// Give the monster a control item that handles what happens to them:
			if (tracer) {
				tracer.GiveInventory("HookControl",1);
				control = HookControl(tracer.FindInventory("HookControl"));
				
				control.master = self;
			}
		}
		goto Flyback;
	Flyback:
		BAL1 A 1 {
			if (target) {
				flytime++;
				//if (tracer)
				vel = Vec3To(target).Unit() * 30;
				if (Distance3D(target) <= 64 || flytime > 35*5) {
					if (tracer)
						tracer.TakeInventory("HookControl",1);						
					destroy();
				}
			}
		}
		loop;
	}
}
		

Class HookControl : Inventory {
	Default {
		+INVENTORY.UNDROPPABLE;
		+INVENTORY.UNTOSSABLE;
		+INVENTORY.UNCLEARABLE;
		+INVENTORY.PERSISTENTPOWER;
		inventory.maxamount 1;
	}	
	override void Tick() {}
	override void DoEffect() {
		super.DoEffect();
		if (!owner || !master) {
			destroy();
			return;	
		}
		owner.SetOrigin(master.pos-(0,0,owner.default.height*0.5),true);
	}
}