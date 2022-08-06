version 4.6.0

class WIMP_PurseReplacer : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		let pack = Purse(e.Thing);

		if (!(
			pack &&
			pack.GetClassName() == "Purse" &&
			pack.Owner
		)) return;

		let wimp = WIMP_Purse(pack.Owner.FindInventory("WIMP_Purse"));

		if (wimp) WIMP_Purse.AddPouch(wimp, pack, 0);
		else
		{
			wimp = WIMP_Purse(pack.Owner.GiveInventoryType("WIMP_Purse"));
			wimp.Storage = pack.Storage;
			wimp.MaxCapacity = pack.MaxCapacity;
			wimp.WeaponStatus[0] = pack.WeaponStatus[0];
		}

		pack.Destroy();
	}
}

class WIMP_Purse : Purse replaces Purse
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
		string title = "\c[DarkBrown][] [] [] \c[Purple]Purse \c[DarkBrown][] [] []";
		string subtitle = "Total Bulk: \c[Gold]"..int(Storage.TotalBulk).."\c- --- Purses: \c[Gold]"..WeaponStatus[PRS_AMOUNT].."\c-";

		Vector2 uiScale = (hdwimp_ui_scale, hdwimp_ui_scale);

		float textHeight = sb.pSmallFont.mFont.GetHeight() * uiScale.y;
		float textPadding = textHeight / 2;
		float textOffset = textHeight + textPadding;
		float baseOffset = textOffset * -6;

		Vector2 wompListPos = (-16 * uiScale.x, baseOffset + (textOffset * 5));
		Vector2 itemInfoPos = (0, wompListPos.y + (textOffset * 4));

		if (Storage.Items.Size() == 0)
		{
			// Header
			sb.DrawString(
				sb.pSmallFont,
				title,
				(0, baseOffset - textHeight),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				scale: uiScale
			);
			sb.DrawString(
				sb.pSmallFont,
				subtitle,
				(0, baseOffset),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				scale: uiScale
			);

			sb.DrawString(
				sb.pSmallFont,
				"\c[Gold]Ha ha! You're \c[Red]POOR!",
				(0, wompListPos.y),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				Font.CR_DARKGRAY,
				scale: uiScale
			);
			return;
		}

		WP.DrawHUDStuff(
			sb,
			hpl,
			Storage,
			title,
			subtitle,
			"In pouch:"
		);
	}

	// Handle extra pouches
	override void ActualPickup(Actor other, bool silent)
	{
		let heldPouch = WIMP_Purse(other.FindInventory("WIMP_Purse"));
		if (!heldPouch)
		{
			Super.ActualPickup(other, silent);
			return;
		}

		AddPouch(heldPouch, Self, 0);
		Destroy();
	}

	static void AddPouch(WIMP_Purse heldPouch, Purse pouch, int index)
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
