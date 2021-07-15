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

class WIMPack : HDBackpack replaces HDBackpack {
	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl) {
		int BaseOffset = -80;

		sb.DrawString(sb.pSmallFont, "\c[DarkBrown][] [] [] \c[Tan]Backpack\c[DarkBrown][] [] []", (0, BaseOffset), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER);
		sb.DrawString(sb.pSmallFont, "Total Bulk: \cf"..int(Storage.TotalBulk).."\c-", (0, BaseOffset + 10), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER);

		int ItemCount = Storage.Items.Size();

		if (ItemCount == 0) {
			sb.DrawString(sb.pSmallFont, "No items found.", (0, BaseOffset + 30), sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER, Font.CR_DARKGRAY);
			return;
		}

		StorageItem SelItem = Storage.GetSelectedItem();
		if (!SelItem) {
			return;
		}

		Vector2 Offset = (0, 30);
		int TextHeight = sb.pSmallFont.mFont.GetHeight();
		int TextPadding = TextHeight / 2;
		int TextOffset = TextHeight + TextPadding;

		for (int i = 0; i < (ItemCount > 1 ? 5 : 1); ++i) {
			int RealIndex = (Storage.SelItemIndex + (i - 2)) % ItemCount;
			if (RealIndex < 0) {
				RealIndex = ItemCount - abs(RealIndex);
			}
			StorageItem CurItem = Storage.Items[RealIndex];

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
				Storage.Items[RealIndex].NiceName,
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
