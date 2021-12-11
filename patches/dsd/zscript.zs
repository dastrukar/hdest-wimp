class WIMP_DSDHandler : DSDHandler {
	override void WorldThingSpawned(WorldEvent e) {
		let T = e.Thing;

		if (
			T &&
			T.GetClassName() == "DSDInterface" &&
			HDBackpack(T).Owner
		) {
			HDBackpack hdb = HDBackpack(T);
			hdb.Owner.GiveInventory("WIMP_DSDInterface", 1);

			WIMP_DSDInterface wimp = WIMP_DSDInterface(hdb.Owner.FindInventory("WIMP_DSDInterface"));
			wimp.Storage = hdb.Storage;
			wimp.MaxCapacity = hdb.MaxCapacity;

			hdb.Destroy();
		}
	}

	override void WorldTick() {
		// There can only be one.
		DSDHandler DSDH = DSDHandler(EventHandler.Find("DSDHandler"));

		if (DSDH) {
			DSDH.Destroy();
		}
	}

	override void NetworkProcess(ConsoleEvent e) {
		DSDStorage DSD = Storages[e.Player];
		WIMP_DSDInterface WSD = WIMP_DSDInterface(players[e.Player].mo.FindInventory("WIMP_DSDInterface"));

		if (e.Name ~== "DSD_ApplySearch") {
			// Hacky method to get stuff
			int PrevSortMode = WSD.WP.SortMode;
			WSD.WP.SortMode = 0; // Temporarily change back to using the actual storage

			DSD.ApplySearch();

			if (PrevSortMode != 0) {
				WSD.WP.SyncStorage(DSD);
				if (DSD.GetSelectedItem().HaveNone()) {
					WSD.WP.SortMode = 2;
				} else {
					WSD.WP.SortMode = 1;
				}
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
		WP.SortMode = 0;
	}

	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl) {
		WP.DrawHUDStuff(sb, hdw, hpl, Storage, "\c[Cyan]Dimensional Storage Device");

		int BaseOffset = -80;
		int TextHeight = sb.pSmallFont.mFont.GetHeight();
		int TextPadding = TextHeight / 2;
		int TextOffset = TextHeight + TextPadding;
		int DisplayOffset = TextHeight * 6;
		int OnBackpackOffset = (hdwimp_ui_type == 2)? (DisplayOffset + 1 + (TextOffset * 4)) : (DisplayOffset + (TextOffset * 6));
		int OnPersonOffset = TextHeight + OnBackpackOffset;

		// DSD UI stuff
		int ItemCount = Storage.Items.Size();
		if (ItemCount != 0) {
			if (DSDStorage(Storage).InSearchMode) {
				sb.DrawString(
					sb.pSmallFont,
					"Searching: "..DSDStorage(Storage).SearchString.."_",
					(-60, BaseOffset + OnPersonOffset + TextHeight),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT,
					Font.CR_WHITE
				);
			}
		}
	}

	// Need to override this, else you can't upgrade your DSD
	override void ActualPickup(Actor other, bool silent) {
		let DSD = WIMP_DSDInterface(other.FindInventory("WIMP_DSDInterface"));
		if (DSD && DSD.Storage) {
			other.A_StartSound("weapons/pocket");
			other.A_Log("Your storage has expanded.", true);
			DSD.Storage.MaxBulk += 1000;
			Destroy();
			return;
		}

		Super.ActualPickup(other, silent);
	}

	// Because A_BPReady isn't really used
	action void A_DSDReady() {
		if (PressingFiremode()) {
			if (JustPressed(BT_ATTACK)) {
				Invoker.OperationAmount++;
			} else if (JustPressed(BT_ALTATTACK)) {
				Invoker.OperationAmount--;
			}

			int InputAmount = GetMouseY(true);
			if (InputAmount != 0) {
				Invoker.OperationAmount += InputAmount / 64;
			}

			Invoker.OperationAmount = clamp(invoker.OperationAmount, 1, 100);
		} else {
			invoker.RepeatTics--;
			A_WeaponReady(WRF_ALLOWUSER3);
			if (Invoker.RepeatTics <= 0) {
				if (PressingReload()) {
					A_UpdateStorage();
					StorageItem SelItem = Invoker.Storage.GetSelectedItem();
					if (SelItem) {
						Invoker.Storage.TryInsertItem(SelItem.InvRef, self, Invoker.OperationAmount);
						Invoker.RepeatTics = Invoker.Storage.GetOperationSpeed(SelItem.ItemClass, true);
					}
				} else if (PressingUnload()) {
					A_UpdateStorage();
					StorageItem SelItem = Invoker.Storage.GetSelectedItem();
					if (SelItem) {
						Invoker.Storage.RemoveItem(SelItem, self, null, Invoker.OperationAmount);
						Invoker.RepeatTics = Invoker.Storage.GetOperationSpeed(SelItem.ItemClass, true);
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
			TNT1 A 10 {
				Invoker.OperationAmount = 1;
				A_UpdateStorage();
				Invoker.WP.SyncStorage(invoker.Storage);
				A_StartSound("weapons/pocket", CHAN_WEAPON);
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

				A_DSDReady();
				W.SyncStorage(S);
			}
			Goto ReadyEnd;
	}
}
