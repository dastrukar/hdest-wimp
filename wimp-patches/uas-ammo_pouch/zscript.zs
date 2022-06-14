version 4.6.0

class UaS_AmmoPouch_Replacer : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		let pack = UaS_AmmoPouch(e.Thing);

		if (!(
			pack &&
			pack.GetClassName() == "UaS_AmmoPouch" &&
			pack.Owner
		)) return;

		let wimp = WIMP_AmmoPouch(pack.Owner.FindInventory("WIMP_AmmoPouch"));

		if (wimp) WIMP_AmmoPouch.AddPouch(wimp, pack, 0);
		else
		{
			wimp = WIMP_AmmoPouch(pack.Owner.GiveInventoryType("WIMP_AmmoPouch"));
			wimp.Storage = pack.Storage;
			wimp.MaxCapacity = pack.MaxCapacity;
			wimp.WeaponStatus[0] = pack.WeaponStatus[0];
		}

		pack.Destroy();
	}
}

class WIMP_AmmoPouch : UaS_AmmoPouch replaces UaS_AmmoPouch
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
			"\c[DarkBrown][] [] [] \c[Tan]Ammo Pouch \c[DarkBrown][] [] []",
			"Total Bulk: \c[Gold]"..int(Storage.TotalBulk).."\c- --- Pouches: \c[Gold]"..WeaponStatus[APS_AMOUNT].."\c-"
		);
	}

	// Handle extra pouches
	override void ActualPickup(Actor other, bool silent)
	{
		let heldPouch = WIMP_AmmoPouch(other.FindInventory("WIMP_AmmoPouch"));
		if (!heldPouch)
		{
			Super.ActualPickup(other, silent);
			return;
		}

		AddPouch(heldPouch, Self, 0);
		Destroy();
	}

	static void AddPouch(WIMP_AmmoPouch heldPouch, UaS_AmmoPouch pouch, int index)
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
