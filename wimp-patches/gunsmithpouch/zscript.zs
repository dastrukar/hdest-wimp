version 4.6.0

class WIMP_GunsmithPouchReplacer : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		let pack = GunsmithPouch(e.Thing);

		if (!(
			pack &&
			pack.GetClassName() == "GunsmithPouch" &&
			pack.Owner
		)) return;

		let wimp = WIMP_GunsmithPouch(pack.Owner.FindInventory("WIMP_GunsmithPouch"));

		if (wimp) WIMP_GunsmithPouch.AddPouch(wimp, pack, 0);
		else
		{
			wimp = WIMP_GunsmithPouch(pack.Owner.GiveInventoryType("WIMP_GunsmithPouch"));
			wimp.Storage = pack.Storage;
			wimp.MaxCapacity = pack.MaxCapacity;
			wimp.WeaponStatus[0] = pack.WeaponStatus[0];
		}

		pack.Destroy();
	}
}

class WIMP_GunsmithPouch : GunsmithPouch replaces GunsmithPouch
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
			"\c[DarkBrown][] [] [] \c[DarkGreen]Gunsmith Pouch \c[DarkBrown][] [] []",
			"Total Bulk: \c[Gold]"..int(Storage.TotalBulk).."\c- --- Pouches: \c[Gold]"..WeaponStatus[GSP_AMOUNT].."\c-",
			"In pouch:"
		);
	}

	// Handle extra pouches
	override void ActualPickup(Actor other, bool silent)
	{
		let heldPouch = WIMP_GunsmithPouch(other.FindInventory("WIMP_GunsmithPouch"));
		if (!heldPouch)
		{
			Super.ActualPickup(other, silent);
			return;
		}

		AddPouch(heldPouch, Self, 0);
		Destroy();
	}

	static void AddPouch(WIMP_GunsmithPouch heldPouch, GunsmithPouch pouch, int index)
	{
		heldPouch.WeaponStatus[index]++;
		heldPouch.UpdateCapacity();

		for (int i = 0; i < pouch.Storage.Items.Size(); i++)
		{
			StorageItem item = pouch.Storage.Items[i];
			int amountToMove = (item.Amounts.Size() > 0)? item.Amounts[0] : 0;
			heldPouch.Storage.AddAmount(item.ItemClass, amountToMove);
		}
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
