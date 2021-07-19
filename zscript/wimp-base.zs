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

class WIMPack play {
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

	bool PressingFiremode(HDPlayerPawn Owner) {
		return Owner.Player.cmd.Buttons & BT_USER2;
	}
	bool JustPressed(HDPlayerPawn Owner, int whichbutton) {
		return(
			Owner.Player.cmd.Buttons & whichbutton &&
			!(Owner.Player.OldButtons & whichbutton)
		);
	}

	int GetMouseY(HDPlayerPawn Owner, bool hijack=false) {
		if (hijack) {
			Owner.reactiontime = max(Owner.reactiontime,1);
		}
		return Owner.Player.cmd.Pitch;
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
		WIMPHijackMouseInput(Owner, WIMP);
	}

	void DoWOMP(HDPlayerPawn Owner, ItemStorage S) {
		WOMP.UpdateStorage(S);
		WIMPHijackMouseInput(Owner, WOMP);
	}

	void WIMPHijackMouseInput(HDPlayerPawn Owner, WIMPItemStorage WIS) {
		if (WIS.Items.Size() < 1) {
			return;
		}

		if (PressingFiremode(Owner)) {
			int InputAmount = GetMouseY(Owner, true);
			if (
				(
					InputAmount > hdwimp_scrolling_sensitivity &&
					hdwimp_invert_scrolling
				) || (
					InputAmount < -hdwimp_scrolling_sensitivity &&
					!hdwimp_invert_scrolling
				)
			) {
				WIS.PrevItem();
			} else if (
				(
					InputAmount < -hdwimp_scrolling_sensitivity &&
					hdwimp_invert_scrolling
				) || (
					InputAmount > hdwimp_scrolling_sensitivity &&
					!hdwimp_invert_scrolling
				)
			) {
				WIS.NextItem();
			}
		} else {
			if (JustPressed(Owner, BT_ATTACK)) {
				WIS.PrevItem();
			} else if (JustPressed(Owner, BT_ALTATTACK)) {
				WIS.NextItem();
			}
		}
	}

	// This is a bool for skipping A_BPReady
	bool HijackMouseInput(HDPlayerPawn Owner, ItemStorage S) {
		if (S.Items.Size() < 1) {
			return false;
		}

		if (PressingFiremode(Owner)) {
			int InputAmount = GetMouseY(Owner, true);
			if (
				(
					InputAmount > hdwimp_scrolling_sensitivity &&
					hdwimp_invert_scrolling
				) || (
					InputAmount < -hdwimp_scrolling_sensitivity &&
					!hdwimp_invert_scrolling
				)
			) {
				S.PrevItem();
			} else if (
				(
					InputAmount < -hdwimp_scrolling_sensitivity &&
					hdwimp_invert_scrolling
				) || (
					InputAmount > hdwimp_scrolling_sensitivity &&
					!hdwimp_invert_scrolling
				)
			) {
				S.NextItem();
			}

			return true;
		}
		return false;
	}

	bool CheckSwitch(HDPlayerPawn Owner, ItemStorage S) {
		if (
			Owner.Player &&
			PressingFiremode(Owner)
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
