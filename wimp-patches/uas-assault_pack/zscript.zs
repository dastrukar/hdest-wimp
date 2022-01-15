version 4.6.0

class UaS_AssaultPack_Replacer : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		let T = e.Thing;

		if (
			T &&
			T.GetClassName() == "UaS_AssaultPack" &&
			HDBackpack(T).Owner
		)
		{
			HDBackpack hdb = HDBackpack(T);
			hdb.Owner.GiveInventory("WIMP_AssaultPack", 1);

			WIMP_AssaultPack wimp = WIMP_AssaultPack(hdb.Owner.FindInventory("WIMP_AssaultPack"));
			wimp.Storage = hdb.Storage;
			wimp.MaxCapacity = hdb.MaxCapacity;

			hdb.Destroy();
		}
	}
}

class WIMP_AssaultPack : UaS_AssaultPack replaces UaS_AssaultPack
{
	WIMPack WP;

	override void BeginPlay()
	{
		Super.BeginPlay();
		WP = new("WIMPack");
		WP.WIMP = new("WIMPItemStorage");
		WP.WOMP = new("WOMPItemStorage");
	}

	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl)
	{
		WP.DrawHUDStuff(
			sb,
			hpl,
			Storage,
			"\c[DarkBrown][] [] [] \c[Tan]Assault Pack \c[DarkBrown][] [] []",
			"Total Bulk: \cf"..int(Storage.TotalBulk).."\c-"
		);
	}

	States
	{
		Select0:
			// Initialize shit to (try) prevent reading from address zero
			TNT1 A 10
			{
				A_UpdateStorage();
				Invoker.WP.SyncStorage(invoker.Storage);
				A_StartSound("weapons/pocket", CHAN_WEAPON);
				if (invoker.Storage.TotalBulk > (HDCONST_BPMAX * 0.7))
				{
					A_SetTics(20);
				}
			}
			TNT1 A 0 A_Raise(999);
			Wait;

		Ready:
			TNT1 A 1
			{
				ItemStorage S = Invoker.Storage;
				WIMPack W = Invoker.WP;
				HDPlayerPawn Owner = HDPlayerPawn(Invoker.Owner);
				if (!Owner.Player) return;

				W.GetCVars(Owner.Player);
				W.SyncStorage(S);
				A_UpdateStorage();

				if (W.CheckSwitch(Owner, S)) return;

				if (
					!(
					W.HandleWIMP(Owner, S) ||
					W.HijackMouseInput(Owner, S)
					)
				)
				{
					A_BPReady();
				}
			}
			Goto ReadyEnd;
	}
}
