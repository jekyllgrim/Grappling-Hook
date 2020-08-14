version "4.2.4"

/*
	Grappling Hook by Agent_Ash aka Jekyll Grim Payne
	Free to use in your projects.
	Credits are appreciated but not required.
	
	How to use: give yourself GrapplingHook item by any means, then press User 3 key.
*/

Class GrapplingHook : Inventory {
	HookProjectile hook;
	Default {
		+INVENTORY.UNDROPPABLE;
		+INVENTORY.UNTOSSABLE;
		+INVENTORY.UNCLEARABLE;
		+INVENTORY.PERSISTENTPOWER;
		inventory.maxamount 1;
	}
	bool hookFired;
	bool draggingPlayer;

	vector2 FindHooktargetOfs(int atkdist = 320) {
		vector2 ofs;			
		double closestDist = double.infinity;
		actor hooktarget;
		BlockThingsIterator itr = BlockThingsIterator.Create(owner,atkdist);
		while (itr.next()) {
			let next = itr.thing;
			if (next == owner)
				continue; 
			if (!next.bShootable || !(next.bIsMonster || (next is "PlayerPawn")))
				continue;
			double dist = owner.Distance3D(next);
			if (dist > atkdist)
				continue;
			if (dist < closestDist)
				closestDist = dist;
			if (!owner.CheckSight(next,SF_IGNOREWATERBOUNDARY))
				continue;
			vector3 targetpos = LevelLocals.SphericalCoords((owner.pos.x,owner.pos.y,owner.player.viewz),next.pos+(0,0,next.default.height*0.5),(owner.angle,owner.pitch));	
			if (abs(targetpos.x) > 11 || abs(targetpos.y) > 11) {
				continue;
			}
			ofs = targetpos.xy;
		}
		return ofs;
	}
	override void Tick() {}
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

Class HookProjectile : Actor {
	vector3 spawnPos;
	int maxdistance;
	int flytime;
	HookControl control;
	property maxdistance : maxdistance;
	Default {
		HookProjectile.maxdistance 720;
		projectile;
		damage 0;
		speed 25;
		+HITTRACER
		+BLOODLESSIMPACT
		scale 0.4;
		deathsound "ghook/hit";
	}
	override void PostBeginPlay() {
		super.PostBeginPlay();
		spawnPos = pos;
	}
	override void Tick() {
		super.Tick();
		if (isFrozen())
			return;
		Spawn("HookProjectileTrail",pos);
		if (level.Vec3Diff(pos, spawnPos).length() > maxdistance && !inStateSequence(curstate,FindState("Flyback")))
			SetStateLabel("Flyback");
	}
	states {
	Spawn:
		BAL1 A 1;
		loop;
	Death:
		TnT1 A 0 A_Scream();
		BAL1 A 1 {
			if (target && target.player) {
				target.speed = 0;
				target.vel = target.Vec3To(self).Unit() * 25;
				if (Distance3D(target) <= 64) {
					target.speed = target.default.speed;					
					destroy();
				}
			}
		}
		wait;
	XDeath:
		TnT1 A 0 A_Scream();
		BAL1 A 1 {
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