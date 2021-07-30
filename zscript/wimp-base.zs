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

	//CVars
	transient bool InvertItemCycling;
	transient bool InvertModeCycling;
	transient bool InvertScrolling;
	transient bool DisableScrolling;
	transient int ScrollingInSens;

	// Some stuff from HDBackpack's code
	clearscope int GetAmountOnPerson(Inventory Item) {
		let wpn = HDWeapon(item);
		let pkp = HDPickup(item);

		return wpn ? wpn.ActualAmount : pkp ? pkp.Amount : 0;
	}

	bool PressingFiremode(HDPlayerPawn Owner) {
		return Owner.Player.cmd.Buttons & BT_USER2;
	}

	bool PressingZoom(HDPlayerPawn Owner) {
		return Owner.Player.cmd.Buttons & BT_ZOOM;
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

		double Pitch = Owner.Player.cmd.Pitch;
		if (InvertScrolling) {
			Pitch = Pitch * -1;
		}

		return Pitch;
	}

	// Can't use nosave on stuff in non-ui context due to desyncs
	void GetCVars(PlayerInfo Player) {
		InvertItemCycling = CVar.GetCVar("hdwimp_invert_item_cycling", Player).GetBool();
		InvertModeCycling = CVar.GetCVar("hdwimp_invert_mode_cycling", Player).GetBool();
		InvertScrolling = CVar.GetCVar("hdwimp_invert_scrolling", Player).GetBool();
		DisableScrolling = CVar.GetCVar("hdwimp_disable_scrolling", Player).GetBool();
		ScrollingInSens = CVar.GetCVar("hdwimp_scrolling_sensitivity", Player).GetInt();
	}

	// Helps make sure you stay on the correct index when switching between modes
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

	bool DoWIMP(HDPlayerPawn Owner, ItemStorage S) {
		WIMP.UpdateStorage(S);
		return WIMPHijackMouseInput(Owner, WIMP);
	}

	bool DoWOMP(HDPlayerPawn Owner, ItemStorage S) {
		WOMP.UpdateStorage(S);
		return WIMPHijackMouseInput(Owner, WOMP);
	}

	// Returns the input used for cycling through items
	int GetCycleInput(bool CyclePrev, bool Invert) {
		if (CyclePrev) {
			return (Invert)? BT_ALTATTACK : BT_ATTACK;
		} else {
			return (Invert)? BT_ATTACK : BT_ALTATTACK;
		}
	}

	bool WIMPHijackMouseInput(HDPlayerPawn Owner, WIMPItemStorage WIS) {
		if (WIS.Items.Size() < 1) {
			return false;
		}

		bool IgnoreBPReady = false;

		if (PressingFiremode(Owner) && !DisableScrolling) {
			int InputAmount = GetMouseY(Owner, true);
			if (InputAmount < -ScrollingInSens) {
				WIS.PrevItem();
			} else if (InputAmount > ScrollingInSens) {
				WIS.NextItem();
			}

			IgnoreBPReady = true;
		} else {
			if (JustPressed(Owner, GetCycleInput(true, InvertItemCycling))) {
				IgnoreBPReady = true;
				WIS.PrevItem();
			} else if (JustPressed(Owner, GetCycleInput(false, InvertItemCycling))) {
				IgnoreBPReady = true;
				WIS.NextItem();
			}
		}

		return IgnoreBPReady;
	}

	// This is a bool for skipping A_BPReady
	// Returns true if UpdateStorage has to be called
	bool HijackMouseInput(HDPlayerPawn Owner, ItemStorage S) {
		if (S.Items.Size() < 1) {
			return false;
		}

		bool IgnoreBPReady = false;

		if (PressingFiremode(Owner)) {
			if (DisableScrolling) {
				return true;
			}

			int InputAmount = GetMouseY(Owner, true);
			if (InputAmount < -ScrollingInSens) {
				S.PrevItem();
			} else if (InputAmount > ScrollingInSens) {
				S.NextItem();
			}

			IgnoreBPReady = true;
		} else {
			if (JustPressed(Owner, GetCycleInput(true, InvertItemCycling))) {
				IgnoreBPReady = true;
				S.PrevItem();
			} else if (JustPressed(Owner, GetCycleInput(false, InvertItemCycling))) {
				IgnoreBPReady = true;
				S.NextItem();
			}
		}
		return IgnoreBPReady;
	}

	// Used for switching modes
	bool CheckSwitch(HDPlayerPawn Owner, ItemStorage S) {
		if (
			Owner.Player &&
			PressingZoom(Owner)
		) {
			bool ChangedMode = false;

			if (JustPressed(Owner, GetCycleInput(true, InvertModeCycling))) {
				SortMode--;
				ChangedMode = true;
			} else if (JustPressed(Owner, GetCycleInput(false, InvertModeCycling))) {
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
