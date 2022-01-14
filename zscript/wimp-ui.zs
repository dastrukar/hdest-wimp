// UI hell revamped
const HDWIMP_MAX_ICON_SIZE = 16;

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

	// generic draw text function because managing two draw functions is a pain in the ass
	// also yes this is horrendous
	ui void DrawListEntry(
		HDStatusBar sb,
		bool isSelected,
		string text,
		string icon,
		string cursor,
		Vector2 textPosition,
		Vector2 iconPosition,
		Vector2 cursorPosition,
		int flags,
		int textColour,
		Vector2 scale
	)
	{
		sb.DrawString(
			sb.pSmallFont,
			text,
			textPosition,
			flags,
			textColour,
			scale: scale
		);

		if (hdwimp_show_icons)
		{
			Vector2 itemSize = TexMan.GetScaledSize(TexMan.CheckForTexture(icon));
			float itemScale = (itemSize.x >= itemSize.y)? HDWIMP_MAX_ICON_SIZE / itemSize.x : HDWIMP_MAX_ICON_SIZE / itemSize.y;
			float itemAlpha = (isSelected)? 1.0 : 0.5;

			sb.DrawImage(
				icon,
				iconPosition,
				flags,
				itemAlpha,
				scale: (itemScale * scale.x, itemScale * scale.y)
			);
		}

		if (isSelected)
		{
			sb.DrawString(
				sb.pSmallFont,
				cursor,
				cursorPosition,
				flags,
				textColour,
				scale: scale
			);
		}
	}

	ui StorageItem GetStorageItem(WIMPItemStorage W, int index)
	{
		int itemCount = W.Items.Size();
		int itemIndex = (W.SelItemIndex + (index - 2)) % itemCount;
		if (itemIndex < 0)
		{
			itemIndex = itemCount - Abs(itemIndex);
		}

		return W.Items[itemIndex];
	}

	ui void DrawHUDStuff(HDStatusBar sb, HDPlayerPawn hpl, ItemStorage storage, string label)
	{
		Vector2 uiScale = (hdwimp_ui_scale, hdwimp_ui_scale);

		float textHeight = sb.pSmallFont.mFont.GetHeight() * uiScale.y;
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
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
			scale: uiScale
		);
		sb.DrawString(
			sb.pSmallFont,
			"Total Bulk: \cf"..int(storage.TotalBulk).."\c-",
			(0, baseOffset),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
			scale: uiScale
		);

		// Lists
		Vector2 wompListPos = (-16 * uiScale.x, baseOffset + (textOffset * 5));
		Vector2 wimpListPos = (16 * uiScale.x, wompListPos.y);

		// Don't draw lists if there's no items at all
		if (storage.Items.Size() == 0)
		{
			sb.DrawString(
				sb.pSmallFont,
				"=No Items Found=",
				(0, wompListPos.y),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				Font.CR_DARKGRAY,
				scale: uiScale
			);
			return;
		}

		// List titles
		string wompText = (WIMPMode)? "\c[DarkGray][WOMP]" : "\c[Fire]<WOMP>";
		string wimpText = (WIMPMode)? "\c[Fire]<WIMP>" : "\c[DarkGray][WIMP]";

		Vector2 wompTitlePos = (wompListPos.x, wompListPos.y - (textOffset * 3));
		Vector2 wimpTitlePos = (wimpListPos.x, wimpListPos.y - (textOffset * 3));
		sb.DrawString(
			sb.pSmallFont,
			wompText,
			wompTitlePos - (0, textHeight),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT,
			scale: uiScale
		);
		sb.DrawString(
			sb.pSmallFont,
			"========================",
			wompTitlePos,
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT,
			(WIMPMode)? Font.CR_DARKGRAY : Font.CR_WHITE,
			scale: uiScale
		);

		sb.DrawString(
			sb.pSmallFont,
			wimpText,
			wimpTitlePos - (0, textHeight),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT,
			scale: uiScale
		);
		sb.DrawString(
			sb.pSmallFont,
			"========================",
			wimpTitlePos,
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT,
			(WIMPMode)? Font.CR_WHITE : Font.CR_DARKGRAY,
			scale: uiScale
		);

		// WOMP List
		if (WOMP.Items.Size())
		{
			int maxCount = (WOMP.Items.Size() > 1)? 5 : 1;
			float drawOffset = (maxCount == 5)? -(textOffset * 2) : 0;
			float gapWidth = SmallFont.GetCharWidth("<") * uiScale.x;

			for (int i = 0; i < maxCount; ++i)
			{
				StorageItem curItem = GetStorageItem(WOMP, i);

				bool isSelected = (
					!WIMPMode &&
					(i == 2 || maxCount == 1)
				);
				bool inWIMP = (WIMP.Items.Find(curItem) != WIMP.ActualIndex.Size());
				int selectedOffset = (isSelected)? gapWidth * -2 : 0;
				selectedOffset -= (hdwimp_show_icons)? HDWIMP_MAX_ICON_SIZE * 2 * uiScale.x : 0;
				int textColour =
					(inWIMP)? (isSelected)? wimpColourSelected : wimpColour :
					(isSelected)? wompColourSelected : wompColour;

				DrawListEntry(
					sb,
					isSelected,
					curItem.NiceName,
					curItem.Icons[0],
					"<",
					wompListPos + (selectedOffset, drawOffset),
					wompListPos + (selectedOffset / 2, drawOffset),
					wompListPos + (0, drawOffset),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_RIGHT | sb.DI_ITEM_CENTER,
					textColour,
					uiScale
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
				Font.CR_DARKGRAY,
				scale: uiScale
			);
		}

		// WIMP List
		if (WIMP.Items.Size())
		{
			int maxCount = (WIMP.Items.Size() > 1)? 5 : 1;
			float drawOffset = (maxCount == 5)? -(textOffset * 2) : 0;
			float gapWidth = SmallFont.GetCharWidth(">") * uiScale.x;

			for (int i = 0; i < maxCount; ++i)
			{
				StorageItem curItem = GetStorageItem(WIMP, i);

				bool isSelected = (
					WIMPMode &&
					(i == 2 || maxCount == 1)
				);
				int selectedOffset = (isSelected)? gapWidth * 2 : 0;
				selectedOffset += (hdwimp_show_icons)? HDWIMP_MAX_ICON_SIZE * 2 * uiScale.x : 0;
				int textColour = (isSelected)? wimpColourSelected : wimpColour;

				DrawListEntry(
					sb,
					isSelected,
					curItem.NiceName,
					curItem.Icons[0],
					">",
					wimpListPos + (selectedOffset, drawOffset),
					wimpListPos + (selectedOffset / 2, drawOffset),
					wimpListPos + (0, drawOffset),
					sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_LEFT | sb.DI_ITEM_CENTER,
					textColour,
					uiScale
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
				Font.CR_DARKGRAY,
				scale: uiScale
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
				(wimpCount > 0)? Font.CR_BROWN : Font.CR_DARKBROWN,
				scale: uiScale
			);
			sb.DrawString(
				sb.pSmallFont,
				"On person:  "..sb.FormatNumber(wompCount, 1, 6),
				itemInfoPos + (0, TextHeight),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				(wompCount > 0)? Font.CR_WHITE : Font.CR_DARKGRAY,
				scale: uiScale
			);

			// Dumb visual arrows
			sb.DrawString(
				sb.pSmallFont,
				"<--",
				(0, wompListPos.y - textPadding),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				(wimpCount > 0)? Font.CR_FIRE : Font.CR_DARKGRAY,
				scale: uiScale
			);
			sb.DrawString(
				sb.pSmallFont,
				"-->",
				(0, wompListPos.y + textPadding),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				(wompCount > 0)? Font.CR_FIRE : Font.CR_DARKGRAY,
				scale: uiScale
			);
		}
	}
}
