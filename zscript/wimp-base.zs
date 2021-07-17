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

class WIMPack : Thinker {
	// 0 - All: Shows all items
	// 1 - WIMP(What's In My Pack): Shows items in backpack
	// 2 - WOMP(What's Outside My Pack): Does the opposite of WIMP
	static const string WIMPModes[] = {"All", "WIMP", "WOMP"};
	int SortMode;
	WIMPItemStorage WIMP;
	WOMPItemStorage WOMP;

	// Some stuff from HDBackpack's code
	clearscope int GetAmountOnPerson(Inventory Item) {
		let wpn = HDWeapon(item);
		let pkp = HDPickup(item);

		return wpn ? wpn.ActualAmount : pkp ? pkp.Amount : 0;
	}

	bool JustPressed(HDPlayerPawn Owner, int whichbutton) {
		return(
			Owner.Player.cmd.Buttons & whichbutton &&
			!(Owner.Player.OldButtons & whichbutton)
		);
	}

	// Returns ColIn, ColOut, ColInSel, ColOutSel
	ui int, int, int, int GetColourScheme() {
		switch (hdwimp_colourscheme) {
			case 1: // Dast
				return 
					Font.CR_GREEN,
					Font.CR_RED,
					Font.CR_FIRE,
					Font.CR_FIRE;
				break;

			case 2: // Oldschool
				return
					Font.CR_WHITE,
					Font.CR_DARKBROWN,
					Font.CR_SAPPHIRE,
					Font.CR_SAPPHIRE;
				break;

			default: // Fractal
				return
					Font.CR_DARKGREEN,
					Font.CR_DARKRED,
					Font.CR_GREEN,
					Font.CR_BRICK;
				break;
		}
		return 0, 0, 0, 0;
	}

	ui void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl, ItemStorage Storage, string label) {
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

		// Get mode
		bool UseWIMP = (SortMode > 0);
		WIMPItemStorage WIS;
		if (SortMode == 1) {
			WIS = WIMP;
		} else {
			WIS = WOMP;
		}

		// Get colours
		int ColIn;
		int ColOut;
		int ColInSel;
		int ColOutSel;
		if (!hdwimp_use_customcolourscheme) {
			[ColIn, ColOut, ColInSel, ColOutSel] = GetColourScheme();
		} else {
			// Custom colours
			ColIn = hdwimp_wimp_colour;
			ColOut = hdwimp_womp_colour;
			ColInSel = hdwimp_wimp_selected_colour;
			ColOutSel = hdwimp_womp_selected_colour;
		}

		int ItemCount = (UseWIMP)? WIS.Items.Size() : Storage.Items.Size();

		if (ItemCount != 0) {
			StorageItem SelItem = (UseWIMP)? WIS.GetSelectedItem() : Storage.GetSelectedItem();
			if (!SelItem) {
				return;
			}

			for (int i = 0; i < (ItemCount > 1 ? 5 : 1); ++i) {
				int ItemIndex = (UseWIMP)? WIS.SelItemIndex : Storage.SelItemIndex;
				int RealIndex = (ItemIndex + (i - 2)) % ItemCount;
				if (RealIndex < 0) {
					RealIndex = ItemCount - abs(RealIndex);
				}
				StorageItem CurItem = (UseWIMP)? WIS.Items[RealIndex] : Storage.Items[RealIndex];

				// Overwrite i?
				if (ItemCount == 1) {
					i = 2;
				}

				Vector2 ListOffset = ((i == 2)? 10 : 20, BaseOffset + Offset.y + (TextOffset * i));
				Vector2 IconOffset = (-30, ListOffset.y);

				int FontColour = ColOut;
				if (i == 2) {
					// Is selected
					FontColour = (SelItem.HaveNone())? ColOutSel : ColInSel;
				} else if (CurItem.Amounts.Size() > 0) {
					// In backpack
					FontColour = ColIn;
				}
				// Just in case
				FontColour = Clamp(FontColour, 0, Font.CR_TEAL);

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

			// Amount
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

		// Header
		sb.DrawString(
			sb.pSmallFont,
			"\c[DarkBrown][] [] [] \c[Tan]"..label.."\c[DarkBrown][] [] []",
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
			"\c[Fire]<"..Modes[1]..">",
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

		if (ItemCount == 0) {
			sb.DrawString(sb.pSmallFont, "No items found.", (0, BaseOffset + Offset.y), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER, Font.CR_DARKGRAY);
			return;
		}
	}

	void SyncStorage(ItemStorage S) {
		WIMP.UpdateStorage(S);
		WOMP.UpdateStorage(S);
		switch (SortMode) {
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

	void DoWIMP(HDPlayerPawn Owner, ItemStorage S) {
		WIMP.UpdateStorage(S);
		HijackMouseInput(Owner, WIMP);
	}

	void DoWOMP(HDPlayerPawn Owner, ItemStorage S) {
		WOMP.UpdateStorage(S);
		HijackMouseInput(Owner, WOMP);
	}

	void HijackMouseInput(HDPlayerPawn Owner, WIMPItemStorage WIS) {
		if (WIS.Items.Size() < 1) {
			return;
		}

		if (JustPressed(Owner, BT_ATTACK)) {
			WIS.PrevItem();
		} else if (JustPressed(Owner, BT_ALTATTACK)) {
			WIS.NextItem();
		}
	}

	bool CheckSwitch(HDPlayerPawn Owner, ItemStorage S) {
		if (
			Owner.Player &&
			Owner.Player.CrouchFactor < 1.0
		) {
			bool ChangedMode = false;

			if (JustPressed(Owner, BT_ATTACK)) {
				SortMode--;
				ChangedMode = true;
			} else if (JustPressed(Owner, BT_ALTATTACK)) {
				SortMode++;
				ChangedMode = true;
			}

			if (SortMode > 2) {
				SortMode = 0;
			} else if (SortMode < 0) {
				SortMode = 2;
			}

			return ChangedMode;
		}
		return false;
	}
}
