version 4.6.0


// Does what it says
class HDBackpackReplacer : EventHandler {
	override void WorldThingSpawned(WorldEvent e) {
		let T = e.Thing;

		if (T.GetClassName() == "HDBackpack" && HDBackpack(T).Owner) {
			HDBackpack hdb = HDBackpack(T);
			hdb.Owner.GiveInventory("WIMPack", 1);

			WIMPack wimp = WIMPack(hdb.Owner.FindInventory("WIMPack"));
			wimp.Storage = hdb.Storage;
			wimp.MaxCapacity = hdb.MaxCapacity;

			hdb.Destroy();
		}
	}
}

class WIMPItemStorage play {
	Array<StorageItem> Items; // Stores items for sorting
	Array<int> ActualIndex;   // Used for referring back to the original index in Storage
	int SelItemIndex;

	clearscope StorageItem GetSelectedItem() {
		if (!(SelItemIndex > Items.Size())) {
			return Items[SelItemIndex];
		}

		return null;
	}

	virtual void UpdateStorage(ItemStorage Storage) {
		if (!Storage) {
			return;
		}

		// just clear it
		Items.Clear();
		ActualIndex.Clear();

		for (int i = 0; i < Storage.Items.Size(); i++) {
			StorageItem Item = Storage.Items[i];

			// Is the item in the backpack AND not already in Items?
			if (
				Item &&
				!Item.HaveNone() &&
				Items.Find(Item) == Items.Size()
			) {
				Items.Push(Item);
				ActualIndex.Push(i);
			}
		}

		if (Items.Size()) {
			ClampSelItemIndex();
		}
	}

	void ClampSelItemIndex() {
		if (SelItemIndex >= Items.Size()) {
			SelItemIndex = 0;
		} else if (SelItemIndex < 0) {
			SelItemIndex = Items.Size() - 1;
		}
	}

	void NextItem() {
		SelItemIndex++;
		ClampSelItemIndex();
	}

	void PrevItem() {
		SelItemIndex--;
		ClampSelItemIndex();
	}
}

class WOMPItemStorage : WIMPItemStorage {
	override void UpdateStorage(ItemStorage Storage) {
		if (!Storage) {
			return;
		}

		// just clear it
		Items.Clear();
		ActualIndex.Clear();

		for (int i = 0; i < Storage.Items.Size(); i++) {
			StorageItem Item = Storage.Items[i];

			// Is the item in the backpack AND not already in Items?
			if (
				Item &&
				Item.HaveNone()
			) {
				Items.Push(Item);
				ActualIndex.Push(i);
			}
		}

		if (Items.Size()) {
			ClampSelItemIndex();
		}
	}
}

class WIMPack : HDBackpack replaces HDBackpack {
	// 0 - All: Shows all items
	// 1 - WIMP(What's In My Pack): Shows items in backpack
	// 2 - WOMP(What's Outside My Pack): Does the opposite of WIMP
	static const string WIMPModes[] = {"All", "WIMP", "WOMP"};
	int SortMode;
	WIMPItemStorage WIMP;
	WOMPItemStorage WOMP;

	override void BeginPlay() {
		Super.BeginPlay();
		SortMode = 0;
		WIMP = New("WIMPItemStorage");
		WOMP = New("WOMPItemStorage");
	}

	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl) {
		int BaseOffset = -80;
		int TextHeight = sb.pSmallFont.mFont.GetHeight();
		int TextPadding = TextHeight / 2;
		int TextOffset = TextHeight + TextPadding;
		Vector2 Offset = (0, TextHeight * 6);

		// Get modes
		string Modes[3];
		for (int i = 0; i < Modes.Size(); i++) {
			int Mode = (SortMode + (i - 1)) % Modes.Size();
			if (Mode < 0) {
				Mode = Modes.Size() - Abs(Mode);
			}

			Modes[i] = WIMPModes[Mode];
		}

		WIMPItemStorage WIS;
		if (SortMode == 1) {
			WIS = WIMP;
		} else {
			WIS = WOMP;
		}
		int ItemCount = (SortMode > 0)? WIS.Items.Size() : Storage.Items.Size();

		if (ItemCount == 0) {
			sb.DrawString(sb.pSmallFont, "No items found.", (0, BaseOffset + 30), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER, Font.CR_DARKGRAY);
			return;
		}

		StorageItem SelItem = (SortMode > 0)? WIS.GetSelectedItem() : Storage.GetSelectedItem();
		if (!SelItem) {
			return;
		}

		for (int i = 0; i < (ItemCount > 1 ? 5 : 1); ++i) {
			int ItemIndex = (SortMode > 0)? WIS.SelItemIndex : Storage.SelItemIndex;
			int RealIndex = (ItemIndex + (i - 2)) % ItemCount;
			if (RealIndex < 0) {
				RealIndex = ItemCount - abs(RealIndex);
			}
			StorageItem CurItem = (SortMode > 0)? WIS.Items[RealIndex] : Storage.Items[RealIndex];

			// Overwrite i?
			if (ItemCount == 1) {
				i = 2;
			}

			Vector2 ListOffset = ((i == 2)? 10 : 20, BaseOffset + Offset.y + (TextOffset * i));
			Vector2 IconOffset = (-30, ListOffset.y);

			int FontColour = 0;
			if (i == 2) {
				// Is selected
				FontColour = Font.CR_FIRE;
			} else if (CurItem.Amounts.Size() > 0) {
				// In backpack
				FontColour = Font.CR_CYAN;
			}

			// Draw list of items
			// Icons
			if (i != 2) {
				sb.DrawImage(
					CurItem.Icons[0],
					IconOffset,
					sb.DI_SCREEN_CENTER | sb.DI_ITEM_CENTER,
					(!CurItem.HaveNone())? 0.8 : 0.6,
					(30, 20),
					getdefaultbytype(CurItem.ItemClass).scale * 2.0
				);
			}

			// Text
			sb.DrawString(
				sb.pSmallFont,
				CurItem.NiceName,
				ListOffset,
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT,
				FontColour
			);
		}

		// Selected icon
		sb.DrawImage(
			SelItem.Icons[0],
			(-40, BaseOffset + Offset.y + (TextOffset * 2)),
			sb.DI_SCREEN_CENTER | sb.DI_ITEM_CENTER,
			(!SelItem.HaveNone())? 1.0 : 0.8,
			(50, 30),
			getdefaultbytype(SelItem.ItemClass).scale * 3.0
		);

		// Header
		sb.DrawString(
			sb.pSmallFont,
			"\c[DarkBrown][] [] [] \c[Tan]Backpack\c[DarkBrown][] [] []",
			(0, BaseOffset),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER
		);
		sb.DrawString(
			sb.pSmallFont,
			"Total Bulk: \cf"..int(Storage.TotalBulk).."\c-",
			(0, BaseOffset + TextHeight),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER
		);

		// Modes
		sb.DrawString(
			sb.pSmallFont,
			"Current Mode:",
			(0, BaseOffset + TextHeight * 3),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER
		);
		sb.DrawString(
			sb.pSmallFont,
			"\c[Cyan]<\c[Gold]"..Modes[1].."\c[Cyan]>",
			(0, BaseOffset + TextHeight * 4),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER
		);
		sb.DrawString(
			sb.pSmallFont,
			"\c[DarkGray]["..Modes[0].."]",
			(-50, BaseOffset + TextHeight * 4),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT
		);
		sb.DrawString(
			sb.pSmallFont,
			"\c[DarkGray]["..Modes[2].."]",
			(50, BaseOffset + TextHeight * 4),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT
		);

		int AmountInBackpack = (SelItem.ItemClass is 'HDMagAmmo')? SelItem.Amounts.Size() : ((SelItem.Amounts.Size() > 0)? SelItem.Amounts[0] : 0);
		sb.DrawString(
			sb.pSmallFont,
			"In backpack:  "..sb.FormatNumber(AmountInBackpack, 1, 6),
			(0, BaseOffset + Offset.y + (TextOffset * 6)),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
			(AmountInBackpack > 0)? Font.CR_BROWN : Font.CR_DARKBROWN
		);

		int AmountOnPerson = GetAmountOnPerson(hpl.FindInventory(SelItem.ItemClass));
		sb.DrawString(
			sb.pSmallFont,
			"On person:  "..sb.FormatNumber(AmountOnPerson, 1, 6),
			(0, BaseOffset + TextHeight + Offset.y + (TextOffset * 6)),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
			(AmountOnPerson > 0)?  Font.CR_WHITE : Font.CR_DARKGRAY
		);
	}

	action void A_SyncStorage() {
		ItemStorage S = Invoker.Storage;
		WIMPItemStorage WIMP = Invoker.WIMP;
		WOMPItemStorage WOMP = Invoker.WOMP;

		WIMP.UpdateStorage(S);
		WOMP.UpdateStorage(S);
		switch (Invoker.SortMode) {
			case 0:
				WIMP.SelItemIndex = Clamp(WIMP.ActualIndex.Find(S.SelItemIndex), 0, (WIMP.ActualIndex.Size() > 0)? WIMP.ActualIndex.Size() - 1 : 0);
				WOMP.SelItemIndex = Clamp(WOMP.ActualIndex.Find(S.SelItemIndex), 0, (WOMP.ActualIndex.Size() > 0)? WOMP.ActualIndex.Size() - 1 : 0);
				break;

			case 1:
				S.SelItemIndex = (WIMP.ActualIndex.Size() > 0)? WIMP.ActualIndex[WIMP.SelItemIndex] : 0;
				break;

			case 2:
				S.SelItemIndex = (WOMP.ActualIndex.Size() > 0)? WOMP.ActualIndex[WOMP.SelItemIndex] : 0;
				break;
		}
	}

	action void A_DoWIMP() {
		ItemStorage S = Invoker.Storage;
		WIMPItemStorage WIS = Invoker.WIMP;

		WIS.UpdateStorage(S);
		A_HijackMouseInput(WIS);
	}

	action void A_DoWOMP() {
		ItemStorage S = Invoker.Storage;
		WOMPItemStorage WIS = Invoker.WOMP;

		WIS.UpdateStorage(S);
		A_HijackMouseInput(WIS);
	}

	action void A_HijackMouseInput(WIMPItemStorage WIS) {
		if (WIS.Items.Size() < 1) {
			return;
		}

		if (JustPressed(BT_ATTACK)) {
			WIS.PrevItem();
		} else if (JustPressed(BT_ALTATTACK)) {
			WIS.NextItem();
		}
	}

	action bool A_CheckSwitch() {
		if (
			Invoker &&
			Invoker.Owner &&
			Invoker.Owner.Player &&
			Invoker.Owner.Player.CrouchFactor < 1.0
		) {
			ItemStorage S = Invoker.Storage;
			WIMPItemStorage WIS = Invoker.WIMP;

			bool ChangedMode = false;

			if (JustPressed(BT_ATTACK)) {
				Invoker.SortMode--;
				ChangedMode = true;
			} else if (JustPressed(BT_ALTATTACK)) {
				Invoker.SortMode++;
				ChangedMode = true;
			}

			if (Invoker.SortMode > 2) {
				Invoker.SortMode = 0;
			} else if (Invoker.SortMode < 0) {
				Invoker.SortMode = 2;
			}

			return ChangedMode;
		}
		return false;
	}

	States {
		Ready:
			TNT1 A 1 {
				if (A_CheckSwitch()) {
					return;
				}

				A_BPReady();
				A_SyncStorage();

				switch (Invoker.SortMode) {
					case 1:
						A_DoWIMP();
						break;

					case 2:
						A_DoWOMP();
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
		let aaa = WIMPack(Spawn("WIMPack", pos, ALLOW_REPLACE));
		aaa.RandomContents();
		Destroy();
	}
}
