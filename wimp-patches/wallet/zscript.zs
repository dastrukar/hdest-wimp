version 4.6.0

class WIMP_HDWalletReplacer : EventHandler
{
	override void WorldThingSpawned(WorldEvent e)
	{
		let wallet = HDWallet(e.Thing);
		if (!(
			wallet &&
			wallet.GetClassName() == "HDWallet" &&
			wallet.Owner
		)) return;

		wallet.Owner.GiveInventory("WIMP_HDWallet", 1);

		let wimp = WIMP_HDWallet(wallet.Owner.FindInventory("WIMP_HDWallet"));
		wimp.Storage = wallet.Storage;
		wimp.MaxCapacity = wimp.MaxCapacity;

		wallet.Destroy();
	}
}

class WIMP_HDWallet : HDWallet replaces HDWallet
{
	WIMPack WP;

	override void BeginPlay()
	{
		Super.BeginPlay();
		WP = new("WIMPack");
		WP.WIMP = new("WIMPItemStorage");
		WP.WOMP = new("WOMPItemStorage");
	}

	override void DrawHUDStuff(HDStatusBar sb, HDWeapon hdw, HDPlayerPawn hpl)
	{
		string title = "\c[DarkGreen]$ $ $ \c[Green]Wallet \c[DarkGreen]$ $ $";
		string subtitle = "Total Bulk: \c[Gold]"..int(Storage.TotalBulk).."\c-";

		Vector2 uiScale = (hdwimp_ui_scale, hdwimp_ui_scale);

		float textHeight = sb.pSmallFont.mFont.GetHeight() * uiScale.y;
		float textPadding = textHeight / 2;
		float textOffset = textHeight + textPadding;
		float baseOffset = textOffset * -6;

		Vector2 wompListPos = (-16 * uiScale.x, baseOffset + (textOffset * 5));
		Vector2 itemInfoPos = (0, wompListPos.y + (textOffset * 4));

		if (Storage.Items.Size() == 0)
		{
			// Header
			sb.DrawString(
				sb.pSmallFont,
				title,
				(0, baseOffset - textHeight),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				scale: uiScale
			);
			sb.DrawString(
				sb.pSmallFont,
				subtitle,
				(0, baseOffset),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				scale: uiScale
			);

			sb.DrawString(
				sb.pSmallFont,
				"\c[Gold]Ha ha! You're \c[Red]POOR!",
				(0, wompListPos.y),
				sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
				Font.CR_DARKGRAY,
				scale: uiScale
			);
			return;
		}

		WP.DrawHUDStuff(
			sb,
			hpl,
			Storage,
			title,
			subtitle,
			"In wallet:"
		);

		// Some flavourful text from the wallet
		StorageItem selItem = Storage.GetSelectedItem();
		if (!selItem && selItem.Amounts.Size() == 0) return;

		int money = selItem.Amounts[0];
		string walletText =
			(money <= 250)? "Man, You can't even afford Taco Bell." :
			(money <= 500)? "Ok. Now you got a little walking around money." :
			(money <= 750)? "You saving up for a rainy day now?" :
			(money <= 1000)? "Oh, look at Moneybags over here thinking you've finally made it." :
			"Too bad all this money can't make up for that ugly ass face.";

		sb.DrawString(
			sb.pSmallFont,
			walletText,
			itemInfoPos + (0, textHeight * 2 + textPadding),
			sb.DI_SCREEN_CENTER | sb.DI_TEXT_ALIGN_CENTER,
			Font.CR_GOLD,
			scale: uiScale
		);
	}

	States
	{
		Select0:
			// Initialize shit to (try) prevent reading from address zero
			TNT1 A 10
			{
				A_UpdateStorage();
				Invoker.WP.SyncStorage(invoker.Storage);
				A_StartSound("weapons/pocket", CHAN_WEAPON);
				if (invoker.Storage.TotalBulk > (HDCONST_BPMAX * 0.7))
				{
					A_SetTics(20);
				}
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

				if (
					!(
					W.HandleWIMP(Owner, S) ||
					W.HijackMouseInput(Owner, S)
					)
				)
				{
					A_BPReady();
				}
			}
			Goto ReadyEnd;
	}
}
