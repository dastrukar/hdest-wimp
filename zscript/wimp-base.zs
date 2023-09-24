class WIMPItemStorage play
{
	Array<StorageItem> Items; // Stores items for sorting
	Array<int> ActualIndex;   // Used for referring back to the original index in Storage
	int SelItemIndex;

	clearscope StorageItem GetSelectedItem()
	{
		if (!(SelItemIndex > Items.Size()))
		{
			return Items[SelItemIndex];
		}

		return null;
	}

	virtual void UpdateStorage(ItemStorage storage)
	{
		if (!storage) return;

		// just clear it
		Items.Clear();
		ActualIndex.Clear();

		for (int i = 0; i < storage.Items.Size(); i++)
		{
			StorageItem item = storage.Items[i];

			// Is the item in the backpack AND not already in Items?
			if (
				item &&
				!item.HaveNone() &&
				Items.Find(Item) == Items.Size()
			)
			{
				Items.Push(Item);
				ActualIndex.Push(i);
			}
		}

		if (Items.Size()) ClampSelItemIndex();
	}

	void ClampSelItemIndex()
	{
		if (SelItemIndex >= Items.Size()) SelItemIndex = 0;
		else if (SelItemIndex < 0) SelItemIndex = Items.Size() - 1;
	}

	void NextItem()
	{
		SelItemIndex++;
		ClampSelItemIndex();
	}

	void PrevItem()
	{
		SelItemIndex--;
		ClampSelItemIndex();
	}
}

class WOMPItemStorage : WIMPItemStorage
{
	override void UpdateStorage(ItemStorage storage)
	{
		if (!storage) return;

		// just clear it
		Items.Clear();
		ActualIndex.Clear();

		for (int i = 0; i < storage.Items.Size(); i++)
		{
			StorageItem item = storage.Items[i];

			// Is the item in the backpack AND not already in Items?
			if (
				item &&
				item.InvRef
			)
			{
				Items.Push(item);
				ActualIndex.Push(i);
			}
		}

		if (Items.Size()) ClampSelItemIndex();
	}
}

class WIMPack : Inventory
{
	// true  - WIMP(What's In My Pack): Shows items in backpack
	// false - WOMP(What's Outside My Pack): Does the opposite of WIMP
	bool WIMPMode;
	WIMPItemStorage WIMP;
	WOMPItemStorage WOMP;
	Array<WIMPInterface> interfaces;

	//CVars
	transient bool InvertItemCycling;
	transient bool InvertModeCycling;
	transient bool InvertScrolling;
	transient int ScrollingInSens;

	Default
	{
		-Inventory.INVBAR;
		+Inventory.UNTOSSABLE;
	}

	override void BeginPlay()
	{
		WIMPMode = false;
		WIMP = new("WIMPItemStorage");
		WOMP = new("WOMPItemStorage");

		interfaces.Clear();
		for (int i = 0; i < AllClasses.Size(); i++)
		{
			if (!(AllClasses[i] is "WIMPInterface") || AllClasses[i].IsAbstract())
			{
				continue;
			}

			let interface = WIMPInterface(new(AllClasses[i]));
			interface.Init();
			interfaces.Push(interface);
		}
	}

	override void DoEffect()
	{
		let hdp = HDPlayerPawn(owner);
		if (!hdp) return;

		GetCVars(hdp.Player);

		let hdb = HDBackpack(hdp.Player.ReadyWeapon);
		if (!hdb) return;

		for (int i = 0; i < interfaces.Size(); i++)
		{
			if (!interfaces[i].CheckBackpack(hdb)) continue;

			interfaces[i].DoEffect(self, hdb, hdp);
			break;
		}

		// force update storage to sync ui properly
		hdb.Storage.UpdateStorage(hdb, hdb.Owner);
		SyncStorage(hdb.Storage);
	}

	// Some stuff from HDBackpack's code
	clearscope int GetAmountOnPerson(Inventory item)
	{
		let wpn = HDWeapon(item);
		let pkp = HDPickup(item);

		return wpn ? wpn.ActualAmount : pkp ? pkp.Amount : 0;
	}

	bool PressingFiremode(HDPlayerPawn Owner)
	{
		return Owner.Player.cmd.Buttons & BT_USER2;
	}

	bool JustPressed(HDPlayerPawn Owner, int whichButton)
	{
		return (
			Owner.Player.cmd.Buttons & whichButton &&
			!(Owner.Player.OldButtons & whichButton)
		);
	}

	int GetMouseY(HDPlayerPawn Owner, bool hijack=false)
	{
		if (hijack)
		{
			Owner.reactionTime = Max(Owner.reactionTime,1);
		}

		double Pitch = Owner.Player.cmd.Pitch;
		if (InvertScrolling) Pitch = Pitch * -1;

		return Pitch;
	}

	// Can't use nosave on stuff in non-ui context due to desyncs
	void GetCVars(PlayerInfo Player)
	{
		InvertItemCycling = CVar.GetCVar("hdwimp_invert_item_cycling", Player).GetBool();
		InvertModeCycling = CVar.GetCVar("hdwimp_invert_mode_cycling", Player).GetBool();
		InvertScrolling = CVar.GetCVar("hdwimp_invert_scrolling", Player).GetBool();
		ScrollingInSens = CVar.GetCVar("hdwimp_scrolling_sensitivity", Player).GetInt();
	}

	// Helps make sure you stay on the correct index when switching between modes
	void SyncStorage(ItemStorage storage)
	{
		WIMP.UpdateStorage(storage);
		WOMP.UpdateStorage(storage);
		if (WIMPMode && WIMP.ActualIndex.Size() > 0)
		{
			storage.SelItemIndex = WIMP.ActualIndex[WIMP.SelItemIndex];
		}
		else if (WOMP.ActualIndex.Size() > 0)
		{
			storage.SelItemIndex = WOMP.ActualIndex[WOMP.SelItemIndex];
		}
	}

	// Handle WIMP inputs
	bool HandleWIMP(HDPlayerPawn Owner, ItemStorage storage)
	{
		// Force WIMP mode when dumping
		if (Owner.Player.cmd.Buttons & BT_ALTRELOAD) WIMPMode = true;

		if (WIMPMode)
		{
			return WIMPHijackMouseInput(Owner, WIMP);
		}
		else
		{
			return WIMPHijackMouseInput(Owner, WOMP);
		}
	}

	// Returns the input used for cycling through items
	int GetCycleInput(bool CyclePrev, bool Invert)
	{
		if (CyclePrev) return (Invert)? BT_ALTATTACK : BT_ATTACK;
		else return (Invert)? BT_ATTACK : BT_ALTATTACK;
	}

	bool WIMPHijackMouseInput(HDPlayerPawn Owner, WIMPItemStorage WIS)
	{
		if (WIS.Items.Size() < 1) return false;

		bool ignoreBPReady = false;

		if (PressingFiremode(Owner))
		{
			int inputAmount = GetMouseY(Owner, true);
			if (inputAmount < -ScrollingInSens) WIS.PrevItem();
			else if (inputAmount > ScrollingInSens) WIS.NextItem();

			ignoreBPReady = true;
		} else {
			if (JustPressed(Owner, GetCycleInput(true, InvertItemCycling)))
			{
				ignoreBPReady = true;
				WIS.PrevItem();
			}
			else if (JustPressed(Owner, GetCycleInput(false, InvertItemCycling)))
			{
				ignoreBPReady = true;
				WIS.NextItem();
			}
		}

		return ignoreBPReady;
	}

	// This is a bool for skipping A_BPReady
	// Returns true if UpdateStorage has to be called
	bool HijackMouseInput(HDPlayerPawn Owner, ItemStorage S)
	{
		if (S.Items.Size() < 1) return false;

		bool ignoreBPReady = false;

		if (PressingFiremode(Owner))
		{
			int inputAmount = GetMouseY(Owner, true);
			if (inputAmount < -ScrollingInSens) S.PrevItem();
			else if (inputAmount > ScrollingInSens) S.NextItem();

			ignoreBPReady = true;
		}
		else
		{
			if (JustPressed(Owner, GetCycleInput(true, InvertItemCycling)))
			{
				ignoreBPReady = true;
				S.PrevItem();
				Console.PrintF("hijack: %d", S.SelItemIndex);
			}
			else if (JustPressed(Owner, GetCycleInput(false, InvertItemCycling)))
			{
				ignoreBPReady = true;
				S.NextItem();
				Console.PrintF("hijack: %d", S.SelItemIndex);
			}
		}
		return ignoreBPReady;
	}

	// Used for switching modes
	bool CheckSwitch(HDPlayerPawn Owner, ItemStorage S)
	{
		bool wimpHasItems = (WIMP.ActualIndex.Size() > 0);
		bool wompHasItems = (WOMP.ActualIndex.Size() > 0);

		if (wimpHasItems || wompHasItems)
		{
			if (WIMPMode && !wimpHasItems) WIMPMode = false;
			else if (!WIMPMode && !wompHasItems) WIMPMode = true;
		}

		if (
			Owner.Player &&
			Owner.Player.cmd.Buttons & BT_ZOOM &&
			!(Owner.Player.OldButtons & BT_ZOOM)
		)
		{
			WIMPMode = !WIMPMode;
			return true;
		}
		return false;
	}
}

class WIMPTest : Inventory
{
	Default
	{
		-Inventory.INVBAR;
		+Inventory.UNTOSSABLE;
	}

	override void DoEffect()
	{
		let hdp = HDPlayerPawn(Owner);
		if (!hdp || !HDBackpack(hdp.Player.ReadyWeapon))
		{
			return ;
		}

		let bak = HDBackpack(hdp.Player.ReadyWeapon);
		if (
			(hdp.Player.Buttons & BT_ATTACK && !(hdp.Player.OldButtons & BT_ATTACK))
			|| (hdp.Player.Buttons & BT_ALTFIRE && !(hdp.Player.OldButtons & BT_ALTFIRE))
		)
		{
			Console.PrintF("test: %d", bak.Storage.SelItemIndex);
		}
	}
}
