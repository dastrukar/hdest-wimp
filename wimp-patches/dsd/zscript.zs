version 4.6.0

class WIMP_DSDHandler : DSDHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		let T = e.Thing;

		if (
			T &&
			T.GetClassName() == "DSDInterface" &&
			HDBackpack(T).Owner
		)
		{
			HDBackpack hdb = HDBackpack(T);
			hdb.Owner.GiveInventory("WIMP_DSDInterface", 1);

			WIMP_DSDInterface wimp = WIMP_DSDInterface(hdb.Owner.FindInventory("WIMP_DSDInterface"));
			wimp.Storage = hdb.Storage;
			wimp.MaxCapacity = hdb.MaxCapacity;

			hdb.Destroy();
		}
	}

	override void WorldTick()
	{
		// There can only be one.
		DSDHandler DSDH = DSDHandler(EventHandler.Find("DSDHandler"));

		if (DSDH) {
			DSDH.Destroy();
		}
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		DSDStorage DSD = Storages[e.Player];
		WIMP_DSDInterface WSD = WIMP_DSDInterface(players[e.Player].mo.FindInventory("WIMP_DSDInterface"));

		if (e.Name ~== "DSD_ApplySearch")
		{
			DSD.ApplySearch();

			int itemIndex = WSD.WP.WIMP.Items.Find(DSD.GetSelectedItem());
			if (itemIndex != WSD.WP.WIMP.Items.Size())
			{
				WSD.WP.WIMPMode = true;
				WSD.WP.WIMP.SelItemIndex = itemIndex;
				WSD.WP.SyncStorage(DSD);
			}
			return;
		}
		// Why type out code that has already been written :]
		Super.NetworkProcess(e);
	}
}

class WIMP_DSDInterface : DSDInterface replaces DSDInterface {
	private int OperationAmount;
	WIMPack WP;

	override void BeginPlay() {
		Super.BeginPlay();
		WP = new("WIMPack");
		WP.WIMP = new("WIMPItemStorage");
		WP.WOMP = new("WOMPItemStorage");
	}

	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl) {
		WP.DrawHUDStuff(
			sb,
			hpl,
			Storage,
			"\c[DarkGray][] [] [] \c[Cyan]Dimensional Storage Device \c[DarkGray][] [] []",
			"Total Bulk: \cf"..int(Storage.TotalBulk).."/"..int(Storage.MaxBulk).."\c-"
		);

		Vector2 uiScale = (hdwimp_ui_scale, hdwimp_ui_scale);

		float textHeight = sb.pSmallFont.mFont.GetHeight() * uiScale.y;
		float textPadding = textHeight / 2;
		float textOffset = textHeight + textPadding;
		float baseOffset = textOffset * -6;

		Vector2 itemInfoPos = (0, baseOffset + textHeight + (textOffset * 10));

		// DSD UI stuff
		// Insert/Remove amount
		let selItem = DSDStorage(Storage).GetSelectedItem();
		if (
			selItem &&
			selItem.ItemClass is "HDPickup" &&
			!(selItem.ItemClass is "HDArmour")
		)
		{
			sb.DrawString(
				sb.pSmallFont,
				"Insert/remove:  "..sb.FormatNumber(OperationAmount, 1, 3),
				itemInfoPos,
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				Font.CR_SAPPHIRE
			);
			itemInfoPos += (0, textOffset);
		}

		// Search text
		int ItemCount = Storage.Items.Size();
		if (ItemCount != 0) {
			if (DSDStorage(Storage).InSearchMode) {
				sb.DrawString(
					sb.pSmallFont,
					"Searching:  "..DSDStorage(Storage).SearchString.."_",
					itemInfoPos,
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
					Font.CR_WHITE
				);
			}
		}
	}

	// Need to override this, else you can't upgrade your DSD
	override void ActualPickup(Actor other, bool silent)
	{
		let DSD = WIMP_DSDInterface(other.FindInventory("WIMP_DSDInterface"));
		if (DSD && DSD.Storage)
		{
			other.A_StartSound("weapons/pocket");
			other.A_Log("Your storage has expanded.", true);
			DSD.Storage.MaxBulk += 1000;
			Destroy();
			return;
		}

		Super.ActualPickup(other, silent);
	}

	// Because A_BPReady isn't really used
	action void A_DSDReady()
	{
		if (PressingFiremode())
		{
			if (JustPressed(BT_ATTACK))
			{
				Invoker.OperationAmount++;
			}
			else if (JustPressed(BT_ALTATTACK))
			{
				Invoker.OperationAmount--;
			}

			int InputAmount = GetMouseY(true);
			if (InputAmount != 0) Invoker.OperationAmount += int(ceil(InputAmount / 64));

			Invoker.OperationAmount = clamp(invoker.OperationAmount, 1, 100);
		}
		else
		{
			invoker.RepeatTics--;
			A_WeaponReady(WRF_ALLOWUSER3);
			if (Invoker.RepeatTics <= 0)
			{
				if (PressingReload())
				{
					A_UpdateStorage();
					StorageItem selItem = Invoker.Storage.GetSelectedItem();
					if (SelItem)
					{
						Invoker.Storage.TryInsertItem(selItem.InvRef, self, Invoker.OperationAmount);
						Invoker.RepeatTics = Invoker.Storage.GetOperationSpeed(selItem.ItemClass, SIIAct_Insert);
					}
				}
				else if (PressingUnload())
				{
					A_UpdateStorage();
					StorageItem selItem = Invoker.Storage.GetSelectedItem();
					if (SelItem)
					{
						Invoker.Storage.RemoveItem(selItem, self, null, Invoker.OperationAmount);
						Invoker.RepeatTics = Invoker.Storage.GetOperationSpeed(selItem.ItemClass, SIIAct_Extract);
					}
				}
			}

			if (
				Invoker.WP.HandleWIMP(HDPlayerPawn(Invoker.Owner), Invoker.Storage) ||
				Invoker.WP.HijackMouseInput(HDPlayerPawn(Invoker.Owner), Invoker.Storage)
			) {
				A_UpdateStorage();
			}
		}
	}

	States {
		Select0:
			// Initialize shit to (try) prevent reading from address zero
			TNT1 A 10
			{
				Invoker.OperationAmount = 1;
				A_UpdateStorage();
				Invoker.WP.SyncStorage(invoker.Storage);
				A_StartSound("weapons/pocket", CHAN_WEAPON);
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

				A_DSDReady();
			}
			Goto ReadyEnd;
	}
}
