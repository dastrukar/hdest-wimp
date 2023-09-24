// Interface as in the programming kind of interface :]

class WIMPInterface play abstract
{
	abstract void Init(); // if you want to init some variables
	abstract bool CheckBackpack(HDBackpack hdb); // Check if backpack is the correct one
	abstract void DoEffect(WIMPack wimp, HDBackpack hdb, HDPlayerPawn owner); // Runs if CheckBackpack is true
}

class WIMPInterface_GenericBackpack : WIMPInterface
{
	override void Init() {}

	override bool CheckBackpack(HDBackpack hdb)
	{
		return (
			hdb && (
				hdb.GetClassName() == "HDBackPack"
				|| hdb.GetClassName() == "UaS_AmmoPouch"
				|| hdb.GetClassName() == "UaS_AssaultPack"
				|| hdb.GetClassName() == "GunsmithPouch"
				|| hdb.GetClassName() == "HDGearBox"
			)
		);
	}

	override void DoEffect(WIMPack wimp, HDBackpack hdb, HDPlayerPawn owner)
	{
		if (wimp.CheckSwitch(owner, hdb.Storage)) return;

		wimp.HandleWIMP(owner, hdb.Storage);
	}
}
