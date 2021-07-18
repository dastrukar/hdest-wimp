// UI hell
extend class WIMPack {
	// Returns ColIn, ColOut, ColInSel, ColOutSel
	ui int, int, int, int GetColourScheme() {
		switch (hdwimp_colourscheme) {
			case 1: // Dast (the original default colour scheme before Fractal came along)
				return 
					Font.CR_GREEN,
					Font.CR_RED,
					Font.CR_FIRE,
					Font.CR_FIRE;
				break;

			case 2: // Oldschool (based on the old backpack ui colours)
				return
					Font.CR_WHITE,
					Font.CR_DARKBROWN,
					Font.CR_SAPPHIRE,
					Font.CR_SAPPHIRE;
				break;

			case 3: // Hideous (based on the original backpack text colours)
				return
					Font.CR_BROWN,
					Font.CR_WHITE,
					Font.CR_FIRE,
					Font.CR_FIRE;
				break;

			default: // Fractal (a replacement to Dast. made by my friend, fractalyee)
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

		// This is where we draw shit
		int ItemCount = (UseWIMP)? WIS.Items.Size() : Storage.Items.Size();

		if (ItemCount != 0) {
			StorageItem SelItem = (UseWIMP)? WIS.GetSelectedItem() : Storage.GetSelectedItem();
			if (!SelItem) {
				return;
			}

			// Draw backpack contents
			for (int i = 0; i < (ItemCount > 1 ? 5 : 1); ++i) {
				int ItemIndex = (UseWIMP)? WIS.SelItemIndex : Storage.SelItemIndex;
				int RealIndex = (ItemIndex + (i - 2)) % ItemCount;
				if (RealIndex < 0) {
					RealIndex = ItemCount - abs(RealIndex);
				}

				// Overwrite i?
				if (ItemCount == 1) {
					i = 2;
				}

				StorageItem CurItem = (UseWIMP)? WIS.Items[RealIndex] : Storage.Items[RealIndex];
				Vector2 ListOffset = (
					(hdwimp_ui_type != 0)? 0 : (i == 2)? 10 : 20,
					BaseOffset + Offset.y + (TextOffset * i)
				);
				Vector2 IconOffset = (-30, ListOffset.y);
				int ListFlag = sb.DI_SCREEN_CENTER;
				ListFlag |= (hdwimp_ui_type == 0)? sb.DI_TEXT_ALIGN_LEFT : sb.DI_TEXT_ALIGN_CENTER;

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
				if (i != 2 && hdwimp_ui_type == 0) {
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
					ListFlag,
					FontColour
				);
			}

			// Draw these afterwards, because layering
			// Selected icon
			if (hdwimp_ui_type == 0) {
				sb.DrawImage(
					SelItem.Icons[0],
					(-40, BaseOffset + Offset.y + (TextOffset * 2)),
					sb.DI_SCREEN_CENTER | sb.DI_ITEM_CENTER,
					(!SelItem.HaveNone())? 1.0 : 0.8,
					(50, 30),
					getdefaultbytype(SelItem.ItemClass).scale * 3.0
				);
			}

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

		// Draw these things regardless
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

}
