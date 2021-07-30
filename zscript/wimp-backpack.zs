// The backpack from vanilla HDest

extend class HDBackpackReplacer {
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
		WP.DrawHUDStuff(sb, hdw, hpl, Storage, "\c[Tan]Backpack");
	}

	action bool A_HandleWIMP() {
		ItemStorage S = Invoker.Storage;
		WIMPack W = Invoker.WP;
		HDPlayerPawn Owner = HDPlayerPawn(Invoker.Owner);
		switch (W.SortMode) {
			case 1:
				return W.DoWIMP(Owner, S);

			case 2:
				return W.DoWOMP(Owner, S);
		}
		return false;
	}

	States {
		Select0:
			// Initialize shit to (try) prevent reading from address zero
			TNT1 A 10 {
				A_UpdateStorage();
				Invoker.WP.SyncStorage(invoker.Storage);
				A_StartSound("weapons/pocket", CHAN_WEAPON);
				if (invoker.Storage.TotalBulk > (HDBPC_CAPACITY * 0.7)) {
					A_SetTics(20);
				}
			}
			TNT1 A 0 A_Raise(999);
			Wait;

		Ready:
			TNT1 A 1 {
				ItemStorage S = Invoker.Storage;
				WIMPack W = Invoker.WP;
				HDPlayerPawn Owner = HDPlayerPawn(Invoker.Owner);
				if (!Owner.Player) {
					return;
				}
				W.GetCVars(Owner.Player);

				if (W.CheckSwitch(Owner, S)) {
					return;
				}

				if (
					A_HandleWIMP() ||
					W.HijackMouseInput(Owner, S)
				) {
					A_UpdateStorage();
				} else {
					A_BPReady();
				}

				W.SyncStorage(S);
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
