// The backpack from vanilla HDest

class HDBackpackReplacer : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		let pack = HDBackpack(e.Thing);
		if (!(
			pack &&
			pack.GetClassName() == "HDBackpack"
		)) return;

		WIMPHDBackpack wimp;

		if (pack.Owner) wimp = WIMPHDBackpack(pack.Owner.GiveInventoryType("WIMPHDBackpack"));
		else
		{
			wimp = WIMPHDBackpack(Actor.Spawn("WIMPHDBackpack", pack.Pos));

			wimp.Angle = pack.Angle;
			wimp.A_ChangeVelocity(1.5, 0, 1, CVF_RELATIVE);
			wimp.Vel += pack.Vel;
		}

		wimp.Storage = pack.Storage;
		wimp.MaxCapacity = pack.MaxCapacity;

		pack.Destroy();
	}
}

class WIMPHDBackpack : HDBackpack replaces HDBackpack
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
			"\c[DarkBrown][] [] [] \c[Tan]Backpack \c[DarkBrown][] [] []",
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
				else {Console.PrintF("wimp: %d", Invoker.Storage.SelItemIndex);}
			}
			Goto ReadyEnd;
	}
}

// Random backpacks
class WildWIMPack : IdleDummy replaces WildBackpack
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let wimp = WIMPHDBackpack(Spawn("WIMPHDBackpack", pos, ALLOW_REPLACE));
		wimp.RandomContents();
		Destroy();
	}
}
