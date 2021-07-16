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

	void UpdateStorage(ItemStorage Storage) {
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
				Items.Insert(0, Item);
				ActualIndex.Insert(0, i);
			}
		}
	}
}

class WIMPack : HDBackpack replaces HDBackpack {
	// 0 - All: Shows all items
	// 1 - WIMP(What's In My Pack): Shows items in backpack
	// 2 - WOMP(What's Outside My Pack): Does the opposite of WIMP
	int SortMode;
	WIMPItemStorage WIMP;

	override void BeginPlay() {
		Super.BeginPlay();
		SortMode = 0;
		WIMP = New("WIMPItemStorage");
	}

	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl) {
		int BaseOffset = -80;

		sb.DrawString(sb.pSmallFont, "\c[DarkBrown][] [] [] \c[Tan]Backpack\c[DarkBrown][] [] []", (0, BaseOffset), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER);
		sb.DrawString(sb.pSmallFont, "Total Bulk: \cf"..int(Storage.TotalBulk).."\c-", (0, BaseOffset + 10), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER);

		int ItemCount = (SortMode == 1)? WIMP.Items.Size() : Storage.Items.Size();

		if (ItemCount == 0) {
			sb.DrawString(sb.pSmallFont, "No items found.", (0, BaseOffset + 30), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER, Font.CR_DARKGRAY);
			return;
		}

		StorageItem SelItem = (SortMode == 1)? WIMP.GetSelectedItem() : Storage.GetSelectedItem();
		if (!SelItem) {
			return;
		}

		Vector2 Offset = (0, 30);
		int TextHeight = sb.pSmallFont.mFont.GetHeight();
		int TextPadding = TextHeight / 2;
		int TextOffset = TextHeight + TextPadding;

		for (int i = 0; i < (ItemCount > 1 ? 5 : 1); ++i) {
			int ItemIndex = (SortMode == 1)? WIMP.SelItemIndex : Storage.SelItemIndex;
			int RealIndex = (ItemIndex + (i - 2)) % ItemCount;
			if (RealIndex < 0) {
				RealIndex = ItemCount - abs(RealIndex);
			}
			StorageItem CurItem = (SortMode == 1)? WIMP.Items[RealIndex] : Storage.Items[RealIndex];

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

		sb.DrawImage(
			SelItem.Icons[0],
			(-40, BaseOffset + Offset.y + (TextOffset * 2)),
			sb.DI_SCREEN_CENTER | sb.DI_ITEM_CENTER,
			(!SelItem.HaveNone())? 1.0 : 0.8,
			(50, 30),
			getdefaultbytype(SelItem.ItemClass).scale * 3.0
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

	action void A_DoWIMP() {
		// Hijack the max amount of items
		ItemStorage S = Invoker.Storage;
		WIMPItemStorage WIS = Invoker.WIMP;
		Invoker.A_Log("WIS.Items.Size():"..WIS.Items.Size().." S.Items.Size():"..S.Items.Size().." WIS.SelItemIndex:"..WIS.SelItemIndex);

		WIS.UpdateStorage(S);

		if (WIS.Items.Size() < 1) {
			return;
		}

		int TempIndex = WIS.SelItemIndex;
		if (JustPressed(BT_ATTACK)) {
			TempIndex--;
		} else if (JustPressed(BT_ALTATTACK)) {
			TempIndex++;
		}

		if (TempIndex < 0) {
			TempIndex = WIS.Items.Size() - 1;
		} else if (TempIndex >= WIS.Items.Size()) {
			TempIndex = 0;
		}

		// No negative index
		if (TempIndex < 0) {
			TempIndex = 0;
		}

		WIS.SelItemIndex = TempIndex;
		S.SelItemIndex = WIS.ActualIndex[TempIndex];
	}

	action void A_CheckSwitch() {
		if (
			Invoker &&
			Invoker.Owner &&
			Invoker.Owner.Player &&
			Invoker.Owner.Player.CrouchFactor < 1.0
		) {
			ItemStorage S = Invoker.Storage;
			if (JustPressed(BT_ATTACK)) {
				Invoker.SortMode++;
				S.NextItem();
			} else if (JustPressed(BT_ALTATTACK)) {
				Invoker.SortMode--;
				S.PrevItem();
			}

			if (Invoker.SortMode > 1) {
				Invoker.SortMode = 0;
			} else if (Invoker.SortMode < 0) {
				Invoker.SortMode = 1;
			}
		}
	}

	States {
		Ready:
			TNT1 A 1 {
				A_BPReady();
				A_CheckSwitch();

				switch (Invoker.SortMode) {
					case 1:
						A_DoWIMP();
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
