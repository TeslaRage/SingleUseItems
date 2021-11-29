class X2DownloadableContentInfo_SingleUseItems extends X2DownloadableContentInfo;

var config (SingleUse) array<name> LimitedUseItems;
var config array<int> ItemObjectIDs; // Feels bad man

// --------------------------------------------------
// DLC HOOKS
// --------------------------------------------------
static event OnPostTemplatesCreated()
{
	// Adding a passive ability that does nothing but convey information to players
	AttachAbilitiesToItems();
}

static event OnPostMission()
{
	// The items are removed during OnPostMission
	RemoveLimitedUseItems();
}

static event OnExitPostMissionSequence()
{
	// Popups appear here because it's better from UX perspective
	// The items cannot be removed here because the units may no longer be in the squad e.g. injured, captured, dead
	ShowPopups();
}

static function bool DisplayQueuedDynamicPopup(DynamicPropertySet PropertySet)
{
	if (PropertySet.PrimaryRoutingKey == 'UIAlert_SingleUseItems')
	{
		CallUIAlert_SingleUseItems(PropertySet);
		return true;
	}

	return false;
}

// --------------------------------------------------
// HELPERS
// --------------------------------------------------
static function AttachAbilitiesToItems()
{
	local X2ItemTemplateManager ItemTemplateMan;
	local array<X2DataTemplate> DataTemplates;
	local X2DataTemplate DataTemplate;
	local X2EquipmentTemplate EqTemplate;
	local array<name> AbilityList;
	local name TemplateName, AbilityFromEq;

	ItemTemplateMan = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	
	foreach default.LimitedUseItems(TemplateName)
	{
		ItemTemplateMan.FindDataTemplateAllDifficulties(TemplateName, DataTemplates);

		foreach DataTemplates(DataTemplate)
		{
			EqTemplate = X2EquipmentTemplate(DataTemplate);
			if (EqTemplate == none) continue;

			AbilityList.Length = 0;
			AbilityList.AddItem('TRLimitedUsePassive');

			foreach EqTemplate.Abilities(AbilityFromEq)
			{
				AbilityList.AddItem(AbilityFromEq);
			}

			EqTemplate.Abilities = AbilityList;
		}
	}	
}

static function RemoveLimitedUseItems()
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameStateHistory History;
	local StateObjectReference UnitRef, ItemRef;
	local XComGameState_Unit Unit;
	local XComGameState_Item Item, NewItem;
	local XComGameState NewGameState;
	local EInventorySlot Slot;	
	local bool bNeedSubmission;

	XComHQ = `XCOMHQ;
	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Destroy single use items (Mod: SingleUseItems)");	

	// Loop through units in squad to find the limited use item
	foreach XComHQ.Squad(UnitRef)
	{
		Unit = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (Unit == none) continue;
		
		foreach Unit.InventoryItems(ItemRef)
		{
			Item = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
			if (Item == none) continue;

			// Not a limited use item, not interested
			if (default.LimitedUseItems.Find(Item.GetMyTemplateName()) == INDEX_NONE) continue;
			
			Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));

			// Grab slot here before we remove it from the unit
			Slot = Item.InventorySlot;

			// Remove the item from inventory, and replace with a basic one
			if (Unit.RemoveItemFromInventory(Item, NewGameState))
			{
				bNeedSubmission = true;
				Item = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', Item.ObjectID));
				
				default.ItemObjectIDs.AddItem(Item.ObjectID); // Hacky				

				// We will only replace the destroyed item if the unit is alive and not captured
				if (Unit.IsAlive() && !Unit.bCaptured)
				{
					// To replace, we get the alternative item based on loadout
					NewItem = GetItemBasedOnLoadout(Unit, Slot, NewGameState);				

					if (NewItem != none)
					{
						// Add to inventory
						if (!Unit.AddItemToInventory(NewItem, Slot, NewGameState))
						{
							`LOG("Not able to equip a basic weapon so you will appear weird", true, 'SingleUseItems');
						}
					}
				}

				// Kill the item
				NewGameState.RemoveStateObject(Item.ObjectID);
			}
			else
			{
				NewGameState.PurgeGameStateForObjectID(Unit.ObjectID);
			}
		}
	}

	if (bNeedSubmission)
	{		
		`GAMERULES.SubmitGameState(NewGameState);		
	}
	else 
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}
}

static function XComGameState_Item GetItemBasedOnLoadout(XComGameState_Unit Unit, EInventorySlot Slot, XComGameState NewGameState)
{
	local name LoadoutName;
	local X2ItemTemplateManager ItemTemplateMan;
	local InventoryLoadout Loadout;
	local X2EquipmentTemplate ItemTemplate;
	local XComGameState_Item NewItem;
	local int i;	
	local bool bFoundLoadout;

	// Determine the loadout
	LoadoutName = Unit.GetSoldierClassTemplate().SquaddieLoadout;	
	if (LoadoutName == '') Unit.GetMyTemplate().DefaultLoadout;	
	if (LoadoutName == '') LoadoutName = 'RookieSoldier'; // I don't like this, but somehow in my game, DefaultLoadout is blank?

	// Get loadout
	ItemTemplateMan = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach ItemTemplateMan.Loadouts(Loadout)
	{
		if (Loadout.LoadoutName == LoadoutName)
		{
			bFoundLoadout = true;
			break;			
		}
	}

	// If found, we instantiate and return
	if (bFoundLoadout)
	{
		for (i = 0; i < Loadout.Items.Length; ++i)
		{
			ItemTemplate = X2EquipmentTemplate(ItemTemplateMan.FindItemTemplate(Loadout.Items[i].Item));
			if (ItemTemplate == none) continue;
			if (ItemTemplate.InventorySlot != Slot) continue;			
			NewItem = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
		}
	}

	return NewItem;
}

static function ShowPopups()
{
	local XComGameStateHistory History;
	local XComGameState_Item Item;
	local int ItemObjectID;
	
	History = `XCOMHISTORY;

	foreach default.ItemObjectIDs(ItemObjectID)
	{
		Item = XComGameState_Item(History.GetGameStateForObjectID(ItemObjectID));		
		if (Item == none) continue;

		UIItemDestroyed(Item.GetMyTemplate());
	}
	default.ItemObjectIDs.Length = 0;
}

static function UIItemDestroyed(X2ItemTemplate ItemTemplate, optional XComGameState NewGameState)
{
	local DynamicPropertySet PropertySet;

	BuildUIAlert(PropertySet, 'eAlert_ItemDestroyed', None, '', "Geoscape_ItemComplete");
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicNameProperty(PropertySet, 'ItemTemplate', ItemTemplate.DataName);

	if (NewGameState != none)
	{
		QueueDynamicPopup(PropertySet, NewGameState);
	}
	else
	{
		QueueDynamicPopup(PropertySet);
	}
}

static function BuildUIAlert(
	out DynamicPropertySet PropertySet, 
	Name AlertName, 
	delegate<X2StrategyGameRulesetDataStructures.AlertCallback> CallbackFunction, 
	Name EventToTrigger, 
	string SoundToPlay,
	bool bImmediateDisplay = true)
{
	class'X2StrategyGameRulesetDataStructures'.static.BuildDynamicPropertySet(PropertySet, 'UIAlert_SingleUseItems', AlertName, CallbackFunction, bImmediateDisplay, true, true, false);
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicNameProperty(PropertySet, 'EventToTrigger', EventToTrigger);
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicStringProperty(PropertySet, 'SoundToPlay', SoundToPlay);
}

static function QueueDynamicPopup(const out DynamicPropertySet PopupInfo, optional XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local bool bLocalNewGameState;

	if( PopupInfo.bDisplayImmediate )
	{
		`PRESBASE.DisplayDynamicPopupImmediate(PopupInfo);
		return;
	}

	if( NewGameState == None )
	{
		bLocalNewGameState = true;
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Queued UI Alert" @ PopupInfo.PrimaryRoutingKey @ PopupInfo.SecondaryRoutingKey);
	}
	else
	{
		bLocalNewGameState = false;
	}

	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	XComHQ.QueuedDynamicPopups.AddItem(PopupInfo);

	if( bLocalNewGameState )
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	if( PopupInfo.bDisplayImmediate )
	{
		`PRESBASE.DisplayQueuedDynamicPopups();
	}
}

static function CallUIAlert_SingleUseItems(const out DynamicPropertySet PropertySet)
{
	local XComHQPresentationLayer Pres;
	local UIAlert_SingleUseItems Alert;

	Pres = `HQPRES;

	Alert = Pres.Spawn(class'UIAlert_SingleUseItems', Pres);
	Alert.DisplayPropertySet = PropertySet;
	Alert.eAlertName = PropertySet.SecondaryRoutingKey;

	Pres.ScreenStack.Push(Alert);
}