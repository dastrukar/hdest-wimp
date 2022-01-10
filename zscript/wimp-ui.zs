// UI hell revamped
extend class WIMPack
{
	// Returns wimpColour, wompColour, wimpColourSelected, wompColourSelected
	ui int, int, int, int GetColourScheme()
	{
		switch (hdwimp_colourscheme)
		{
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
					Font.CR_RED;
				break;
		}
		return 0, 0, 0, 0;
	}

	ui void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl, ItemStorage storage, string label)
	{
		float textHeight = sb.pSmallFont.mFont.GetHeight();
		float textPadding = textHeight / 2;
		float textOffset = textHeight + textPadding;
		float baseOffset = textOffset * -6;

		int wimpColour, wompColour, wimpColourSelected, wompColourSelected;
		[wimpColour, wompColour, wimpColourSelected, wompColourSelected] = GetColourScheme();

		// Header
		sb.DrawString(
			sb.pSmallFont,
			"\c[DarkBrown][] [] [] "..label.." \c[DarkBrown][] [] []",
			(0, baseOffset - textHeight),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER
		);
		sb.DrawString(
			sb.pSmallFont,
			"Total Bulk: \cf"..int(storage.TotalBulk).."\c-",
			(0, baseOffset),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER
		);

		// Lists
		Vector2 wompListPos = (-16, baseOffset + (textOffset * 5));
		Vector2 wimpListPos = (16, wompListPos.y);

		// Don't draw lists if there's no items at all
		if (storage.Items.Size() == 0)
		{
			sb.DrawString(
				sb.pSmallFont,
				"=No Items Found=",
				(0, wompListPos.y),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				Font.CR_DARKGRAY
			);
			return;
		}

		// Draw debug shit
		sb.DrawString(
			sb.pSmallFont,
			""..storage.SelItemIndex.." : "..storage.GetSelectedItem().NiceName,
			(0, 0)
		);
		let debugItem = storage.Items[storage.SelItemIndex];
		int wompCount = GetAmountOnPerson(hpl.FindInventory(debugItem.ItemClass));
		int wimpCount = (debugItem.ItemClass is "HDMagAmmo")? debugItem.Amounts.Size() : ((debugItem.Amounts.Size() > 0)? debugItem.Amounts[0] : 0);
		sb.DrawString(
			sb.pSmallFont,
			"\c[Red]"..wompCount.." \c[Green]"..wimpCount,
			(0, 16)
		);


		// List titles
		string wompText = (WIMPMode)? "\c[DarkGray][WOMP]" : "\c[Fire]<WOMP>";
		string wimpText = (WIMPMode)? "\c[Fire]<WIMP>" : "\c[DarkGray][WIMP]";

		Vector2 wompTitlePos = (wompListPos.x, wompListPos.y - (textOffset * 3));
		Vector2 wimpTitlePos = (wimpListPos.x, wimpListPos.y - (textOffset * 3));
		sb.DrawString(
			sb.pSmallFont,
			wompText,
			wompTitlePos - (0, textHeight),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT
		);
		sb.DrawString(
			sb.pSmallFont,
			"========================",
			wompTitlePos,
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT,
			(WIMPMode)? Font.CR_DARKGRAY : Font.CR_WHITE
		);

		sb.DrawString(
			sb.pSmallFont,
			wimpText,
			wimpTitlePos - (0, textHeight),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT
		);
		sb.DrawString(
			sb.pSmallFont,
			"========================",
			wimpTitlePos,
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT,
			(WIMPMode)? Font.CR_WHITE : Font.CR_DARKGRAY
		);

		// WOMP List
		if (WOMP.Items.Size())
		{
			int itemCount = WOMP.Items.Size();

			int maxCount = (itemCount > 1)? 5 : 1;
			float drawOffset = (maxCount == 5)? -(textOffset * 2) : 0;

			for (int i = 0; i < maxCount; ++i)
			{
				int drawIndex = (WOMP.SelItemIndex + (i - 2)) % itemCount;
				if (drawIndex < 0)
				{
					drawIndex = itemCount - Abs(drawIndex);
				}

				StorageItem curItem = WOMP.Items[drawIndex];
				bool isSelected = (
					!WIMPMode &&
					(i == 2 || maxCount == 1)
				);
				bool inWIMP = (WIMP.ActualIndex.Find(drawIndex) != WIMP.ActualIndex.Size());
				string pointer = (isSelected)? " <" : "";
				int textColour =
					(inWIMP)? (isSelected)? wimpColourSelected : wimpColour :
					(isSelected)? wompColourSelected : wompColour;

				sb.DrawString(
					sb.pSmallFont,
					curItem.NiceName..pointer,
					wompListPos + (0, drawOffset),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT,
					textColour
				);

				drawOffset += textOffset;
			}
		}
		else
		{
			sb.DrawString(
				sb.pSmallFont,
				"=No Items On Person=",
				wompListPos,
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT,
				Font.CR_DARKGRAY
			);
		}

		// WIMP List
		if (WIMP.Items.Size())
		{
			int itemCount = WIMP.Items.Size();

			int maxCount = (itemCount > 1)? 5 : 1;
			float drawOffset = (maxCount == 5)? -(textOffset * 2) : 0;

			for (int i = 0; i < maxCount; ++i)
			{
				int drawIndex = (WIMP.SelItemIndex + (i - 2)) % itemCount;
				if (drawIndex < 0)
				{
					drawIndex = itemCount - Abs(drawIndex);
				}

				StorageItem curItem = WIMP.Items[drawIndex];
				bool isSelected = (
					WIMPMode &&
					(i == 2 || maxCount == 1)
				);
				string pointer = (isSelected)? "> " : "";
				int textColour = (isSelected)? wimpColourSelected : wimpColour;

				sb.DrawString(
					sb.pSmallFont,
					pointer..curItem.NiceName,
					wimpListPos + (0, drawOffset),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT,
					textColour
				);

				drawOffset += textOffset;
			}
		}
		else
		{
			sb.DrawString(
				sb.pSmallFont,
				"=No Items In Backpack=",
				wimpListPos,
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT,
				Font.CR_DARKGRAY
			);
		}

		// Item info
		Vector2 itemInfoPos = (0, wompListPos.y + (textOffset * 4));
		StorageItem selItem = storage.Items[storage.SelItemIndex];

		if (selItem)
		{
			int wimpCount = (selItem.ItemClass is "HDMagAmmo")? selItem.Amounts.Size() : ((selItem.Amounts.Size() > 0)? selItem.Amounts[0] : 0);
			int wompCount = GetAmountOnPerson(hpl.FindInventory(selItem.ItemClass));

			sb.DrawString(
				sb.pSmallFont,
				"In backpack:  "..sb.FormatNumber(wimpCount, 1, 6),
				itemInfoPos,
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				(wimpCount > 0)? Font.CR_BROWN : Font.CR_DARKBROWN
			);
			sb.DrawString(
				sb.pSmallFont,
				"On person:  "..sb.FormatNumber(wompCount, 1, 6),
				itemInfoPos + (0, TextHeight),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				(wompCount > 0)? Font.CR_WHITE : Font.CR_DARKGRAY
			);

			// Dumb visual arrows
			sb.DrawString(
				sb.pSmallFont,
				"<--",
				(0, wompListPos.y - textPadding),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				(wimpCount > 0)? Font.CR_FIRE : Font.CR_DARKGRAY
			);
			sb.DrawString(
				sb.pSmallFont,
				"-->",
				(0, wompListPos.y + textPadding),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				(wompCount > 0)? Font.CR_FIRE : Font.CR_DARKGRAY
			);
		}
	}
}
