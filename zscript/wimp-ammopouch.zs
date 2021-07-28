extend class UaS_AmmoPouch_Replacer {
	override void WorldThingSpawned(WorldEvent e) {
		let T = e.Thing;

		if (
			T &&
			T.GetClassName() == "UaS_AmmoPouch" &&
			HDBackpack(T).Owner
		) {
			HDBackpack hdb = HDBackpack(T);
			hdb.Owner.GiveInventory("WIMP_AmmoPouch", 1);

			WIMP_AmmoPouch wimp = WIMP_AmmoPouch(hdb.Owner.FindInventory("WIMP_AmmoPouch"));
			wimp.Storage = hdb.Storage;
			wimp.MaxCapacity = hdb.MaxCapacity;

			hdb.Destroy();
		}
	}
}

class WIMP_AmmoPouch : UaS_AmmoPouch replaces UaS_AmmoPouch {
	WIMPack WP;

	override void BeginPlay() {
		Super.BeginPlay();
		WP = new("WIMPack");
		WP.WIMP = new("WIMPItemStorage");
		WP.WOMP = new("WOMPItemStorage");
		WP.SortMode = 0;
	}

	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl) {
		WP.DrawHUDStuff(sb, hdw, hpl, Storage, "\c[Tan]Ammo Pouch");
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

				if (W.HijackMouseInput(Owner, S)) {
					A_UpdateStorage();
				} else {
					A_BPReady();
				}
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
