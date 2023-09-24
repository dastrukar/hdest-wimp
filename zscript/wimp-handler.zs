class WIMPHandler : StaticEventHandler
{
	override void WorldTick()
	{
		for (int i = 0; i < Players.Size(); i++)
		{
			let player = HDPlayerPawn(Players[i].mo);
			if (!player) continue;

			if (!player.FindInventory("WIMPack"))
			{
				player.GiveInventory("WIMPack", 1);
			}
		}
	}
}
