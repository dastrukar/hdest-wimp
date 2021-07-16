// The backpack from vanilla HDest

extend HDBackpackReplacer {
	override void WorldThingSpawned(WorldEvent e) {
		let T = e.Thing;

		if (
			T &&
			T.GetClassName() == "HDBackpack" &&
			HDBackpack(T).Owner
		) {
			HDBackpack hdb = HDBackpack(T);
			hdb.Owner.GiveInventory("WIMPHDBackpack", 1);

			WIMPHDBackpack wimp = WIMPHDBackpack(hdb.Owner.FindInventory("WIMPHDBackpack"));
			wimp.Storage = hdb.Storage;
			wimp.MaxCapacity = hdb.MaxCapacity;

			hdb.Destroy();
		}
	}
}

class WIMPHDBackpack : HDBackpack replaces HDBackpack {
	WIMPack WP;

	override void BeginPlay() {
		Super.BeginPlay();
		WP = new("WIMPack");
		WP.WIMP = new("WIMPItemStorage");
		WP.WOMP = new("WOMPItemStorage");
		WP.SortMode = 0;
	}

	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl) {
		WP.DrawHUDStuff(sb, hdw, hpl, Storage, "Backpack");
	}

	States {
		Ready:
			TNT1 A 1 {
				ItemStorage S = Invoker.Storage;
				WIMPack W = Invoker.WP;
				HDPlayerPawn Owner = HDPlayerPawn(Invoker.Owner);
				if (W.CheckSwitch(Owner, S)) {
					return;
				}

				A_BPReady();
				W.SyncStorage(S);

				switch (W.SortMode) {
					case 1:
						W.DoWIMP(Owner, S);
						break;

					case 2:
						W.DoWOMP(Owner, S);
						break;
				}
			}
			Goto ReadyEnd;
	}
}

// Random backpacks
class WildWIMPack : IdleDummy replaces WildBackpack {
	override void PostBeginPlay() {
		Super.PostBeginPlay();
		let aaa = WIMPHDBackpack(Spawn("WIMPHDBackpack", pos, ALLOW_REPLACE));
		aaa.RandomContents();
		Destroy();
	}
}
