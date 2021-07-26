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
		int DisplayOffset = TextHeight * 6;

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
		int FontColour;

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

				StorageItem CurItem = (UseWIMP)? WIS.Items[RealIndex] : Storage.Items[RealIndex];
				int FontColour = (CurItem.HaveNone())? ColOut : ColIn;

				// Just in case
				FontColour = Clamp(FontColour, 0, Font.CR_TEAL);

				if (hdwimp_ui_type < 2) {
					// WIMP Backpack UI
					// Overwrite i?
					if (ItemCount == 1) {
						i = 2;
					}

					Vector2 ListOffset = (
						(hdwimp_ui_type != 0)? 0 : 20,
						BaseOffset + DisplayOffset + (TextOffset * i)
					);
					Vector2 IconOffset = (-30, ListOffset.y);
					int ListFlag = (hdwimp_ui_type == 0)? sb.DI_TEXT_ALIGN_LEFT : sb.DI_TEXT_ALIGN_CENTER;

					// Draw list of items
					// Icons
					if (i != 2) {
						if (hdwimp_ui_type == 0) {
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
							sb.DI_SCREEN_CENTER | ListFlag,
							FontColour
						);
					}
				} else {
					// Vanilla Hideous Destructor Backpack UI
					vector2 IconOffset = (ItemCount > 1)? (-100, 8) : (0, 0);
					switch (i) {
						case 1:
							IconOffset = (-50, 4);
							break;

						case 2:
							IconOffset = (0, 0);
							break;

						case 3:
							IconOffset = (50, 4);
							break;

						case 4:
							IconOffset = (100, 8);
							break;
					}

					bool CenterItem = IconOffset ~== (0, 0);
					sb.DrawImage(
						CurItem.Icons[0],
						(IconOffset.x, BaseOffset + DisplayOffset + (TextHeight * 2) + IconOffset.y),
						sb.DI_SCREEN_CENTER | sb.DI_ITEM_CENTER,
						(CenterItem && !CurItem.HaveNone())? 1.0 : 0.6,
						(CenterItem)? (50, 30) : (30, 20),
						getdefaultbytype(CurItem.ItemClass).scale * (CenterItem? 4.0 : 3.0)
					);
				}
			}

			int OnBackpackOffset = (hdwimp_ui_type == 2)? (DisplayOffset + 1 + (TextOffset * 4)) : (DisplayOffset + (TextOffset * 6));
			int OnPersonOffset = TextHeight + OnBackpackOffset;

			// Draw these afterwards, because layering
			if (hdwimp_ui_type == 0) {
				// Selected icon
				sb.DrawImage(
					SelItem.Icons[0],
					(-40, BaseOffset + DisplayOffset + (TextOffset * 2)),
					sb.DI_SCREEN_CENTER | sb.DI_ITEM_CENTER,
					(!SelItem.HaveNone())? 1.0 : 0.8,
					(50, 30),
					getdefaultbytype(SelItem.ItemClass).scale * 3.0
				);
			}

			Vector2 SelectedOffset = (
				(hdwimp_ui_type != 0)? 0 : 10,
				BaseOffset + ((hdwimp_ui_type > 1)? (OnBackpackOffset - 1 - TextOffset) : (DisplayOffset + (TextOffset * 2)))
			);
			int SelectedFlag = (hdwimp_ui_type == 0)? sb.DI_TEXT_ALIGN_LEFT : sb.DI_TEXT_ALIGN_CENTER;
			// Selected item name
			sb.DrawString(
				sb.pSmallFont,
				SelItem.NiceName,
				SelectedOffset,
				sb.DI_SCREEN_CENTER | SelectedFlag,
				(SelItem.HaveNone())? ColOutSel : ColInSel
			);

			// Amount
			int AmountInBackpack = (SelItem.ItemClass is 'HDMagAmmo')? SelItem.Amounts.Size() : ((SelItem.Amounts.Size() > 0)? SelItem.Amounts[0] : 0);
			sb.DrawString(
				sb.pSmallFont,
				"In backpack:  "..sb.FormatNumber(AmountInBackpack, 1, 6),
				(0, BaseOffset + OnBackpackOffset),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				(AmountInBackpack > 0)? Font.CR_BROWN : Font.CR_DARKBROWN
			);

			int AmountOnPerson = GetAmountOnPerson(hpl.FindInventory(SelItem.ItemClass));
			sb.DrawString(
				sb.pSmallFont,
				"On person:  "..sb.FormatNumber(AmountOnPerson, 1, 6),
				(0, BaseOffset + OnPersonOffset),
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
			sb.DrawString(sb.pSmallFont, "No items found.", (0, BaseOffset + DisplayOffset), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER, Font.CR_DARKGRAY);
			return;
		}
	}

}
