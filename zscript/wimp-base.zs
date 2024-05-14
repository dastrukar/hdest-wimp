// god forbid someone uses their own backpack storage solution
class WIMPStorageItem play
{
	class<Inventory> ItemClass;
	int AmountsFirstItem;
	int AmountsSize;
	int WeaponStatusSize;
	int ActualIndex; // Used for referring back to the original index in HDBackpack Storage

	static WIMPStorageItem Create(StorageItem item, int index)
	{
		let newItem = new("WIMPStorageItem");
		newItem.ItemClass = item.ItemClass;
		newItem.AmountsFirstItem = (item.Amounts.Size() > 0)? item.Amounts[0] : 0;
		newItem.AmountsSize = item.Amounts.Size();
		newItem.WeaponStatusSize = item.WeaponStatus.Size();
		newItem.ActualIndex = index;

		return newItem;
	}

	// returns true if any values actually changed
	bool Update(StorageItem item, int index)
	{
		int oldAmountsFirstItem = AmountsFirstItem;
		int oldAmountsSize = AmountsSize;
		int oldWeaponStatusSize = WeaponStatusSize;

		AmountsFirstItem = (item.Amounts.Size() > 0)? item.Amounts[0] : 0;
		AmountsSize = item.Amounts.Size();
		WeaponStatusSize = item.WeaponStatus.Size();
		ActualIndex = index;

		return (
			oldAmountsFirstItem != AmountsFirstItem
			|| oldAmountsSize != AmountsSize
			|| oldWeaponStatusSize != WeaponStatusSize
		);
	}

	clearscope bool CheckType(StorageItem item)
	{
		return (ItemClass == item.ItemClass);
	}

	clearscope bool Compare(StorageItem item)
	{
		return (
			ItemClass == item.ItemClass
			&& AmountsFirstItem == ((item.Amounts.Size() > 0)? item.Amounts[0] : 0)
			&& AmountsSize == item.Amounts.Size()
			&& WeaponStatusSize == item.WeaponStatus.Size()
		);
	}
}

class WIMPItemStorage play
{
	Array<WIMPStorageItem> Items; // Stores items for sorting
	int SelItemIndex;

	clearscope WIMPStorageItem GetSelectedItem()
	{
		if (!(SelItemIndex > Items.Size()))
			return Items[SelItemIndex];

		return null;
	}

	clearscope int GetActualIndex(int index)
	{
		return (Items[index].ActualIndex);
	}

	clearscope WIMPStorageItem Find(StorageItem item)
	{
		foreach (wimpItem : Items)
		{
			if (!wimpItem.Compare(item))
				continue;

			return wimpItem;
		}

		return null;
	}

	virtual void UpdateStorage(ItemStorage storage, bool selectUpdated)
	{
		if (!storage)
			return;

		Array<WIMPStorageItem> newItems;
		for (int i = 0; i < storage.Items.Size(); i++)
		{
			StorageItem item = storage.Items[i];

			// Is the item in the backpack?
			if (!item || item.HaveNone())
				continue;

			// don't try to recreate the item because of GC reasons
			WIMPStorageItem wimpItem = Find(item);
			bool changed = (!wimpItem);
			if (wimpItem)
				changed = wimpItem.Update(item, i);

			else
				wimpItem = WIMPStorageItem.Create(item, i);

			newItems.Push(wimpItem);
			if (selectUpdated && changed && newItems.Size() > 0)
				SelItemIndex = newItems.Size() - 1;
		}

		Items.Move(newItems);
		// if (Items.Size())
		ClampSelItemIndex();
	}

	void ClampSelItemIndex()
	{
		if (SelItemIndex >= Items.Size())
			SelItemIndex = 0;

		else if (SelItemIndex < 0)
			SelItemIndex = Items.Size() - 1;
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
	override void UpdateStorage(ItemStorage storage, bool selectUpdated)
	{
		if (!storage)
			return;

		Array<WIMPStorageItem> newItems;
		for (int i = 0; i < storage.Items.Size(); i++)
		{
			StorageItem item = storage.Items[i];

			// Does the item exist?
			if (!item || !item.InvRef)
				continue;

			// don't try to recreate the item because of GC reasons
			WIMPStorageItem wimpItem = Find(item);
			bool changed = (!wimpItem);
			if (wimpItem)
				changed = wimpItem.Update(item, i);

			else
				wimpItem = WIMPStorageItem.Create(item, i);

			newItems.Push(wimpItem);
			if (selectUpdated && changed && newItems.Size() > 0)
				SelItemIndex = newItems.Size() - 1;
		}

		Items.Move(newItems);
		// if (Items.Size())
		ClampSelItemIndex();
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
	transient CVar SelectItemOnUpdate;

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
				continue;

			let interface = WIMPInterface(new(AllClasses[i]));
			interface.Init();
			interfaces.Push(interface);
		}
	}

	override void DoEffect()
	{
		let hdp = HDPlayerPawn(owner);
		if (!hdp)
			return;

		GetCVars(hdp.Player);

		let hdb = HDBackpack(hdp.Player.ReadyWeapon);
		if (!hdb)
			return;

		for (int i = 0; i < interfaces.Size(); i++)
		{
			if (!interfaces[i].CheckBackpack(hdb))
				continue;

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

		return (wpn)? wpn.ActualAmount : (pkp)? pkp.Amount : 0;
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
			Owner.reactionTime = Max(Owner.reactionTime,1);

		double Pitch = Owner.Player.cmd.Pitch;
		if (InvertScrolling)
			Pitch = Pitch * -1;

		return Pitch;
	}

	// Can't use nosave on stuff in non-ui context due to desyncs
	void GetCVars(PlayerInfo Player)
	{
		InvertItemCycling = CVar.GetCVar("hdwimp_invert_item_cycling", Player).GetBool();
		InvertModeCycling = CVar.GetCVar("hdwimp_invert_mode_cycling", Player).GetBool();
		InvertScrolling = CVar.GetCVar("hdwimp_invert_scrolling", Player).GetBool();
		ScrollingInSens = CVar.GetCVar("hdwimp_scrolling_sensitivity", Player).GetInt();
		SelectItemOnUpdate = CVar.GetCVar("hdwimp_select_item_on_update", Player);
	}

	// Helps make sure you stay on the correct index when switching between modes
	void SyncStorage(ItemStorage storage)
	{
		bool wimpSelectItem = (SelectItemOnUpdate.GetBool());
		bool wompSelectItem = (
			SelectItemOnUpdate.GetBool()
			&& WIMPMode
			&& (Owner.Player.Buttons & BT_RELOAD | BT_UNLOAD)
		);
		WIMP.UpdateStorage(storage, wimpSelectItem);
		WOMP.UpdateStorage(storage, wompSelectItem);
		WIMPItemStorage selected = null;
		if (WIMPMode && WIMP.Items.Size() > 0)
			selected = WIMP;

		else if (WOMP.Items.Size() > 0)
			selected = WOMP;

		if (selected)
			storage.SelItemIndex = min(selected.GetActualIndex(selected.SelItemIndex), storage.Items.Size() - 1);
	}

	// Handle WIMP inputs
	bool HandleWIMP(HDPlayerPawn Owner, ItemStorage storage)
	{
		// Force WIMP mode when dumping
		if (Owner.Player.cmd.Buttons & BT_ALTRELOAD) WIMPMode = true;

		if (WIMPMode)
			return WIMPHijackMouseInput(Owner, WIMP);

		else
			return WIMPHijackMouseInput(Owner, WOMP);
	}

	// Returns the input used for cycling through items
	int GetCycleInput(bool CyclePrev, bool Invert)
	{
		if (CyclePrev)
			return (Invert)? BT_ALTATTACK : BT_ATTACK;

		else
			return (Invert)? BT_ATTACK : BT_ALTATTACK;
	}

	bool WIMPHijackMouseInput(HDPlayerPawn Owner, WIMPItemStorage WIS)
	{
		if (WIS.Items.Size() < 1) return false;

		bool ignoreBPReady = false;

		if (PressingFiremode(Owner))
		{
			int inputAmount = GetMouseY(Owner, true);
			if (inputAmount < -ScrollingInSens)
				WIS.PrevItem();

			else if (inputAmount > ScrollingInSens)
				WIS.NextItem();

			ignoreBPReady = true;
		}
		else
		{
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

	// Used for switching modes
	bool CheckSwitch(HDPlayerPawn Owner, ItemStorage S)
	{
		bool wimpHasItems = (WIMP.Items.Size() > 0);
		bool wompHasItems = (WOMP.Items.Size() > 0);

		if (wimpHasItems || wompHasItems)
		{
			if (WIMPMode && !wimpHasItems)
				WIMPMode = false;

			else if (!WIMPMode && !wompHasItems)
				WIMPMode = true;
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
