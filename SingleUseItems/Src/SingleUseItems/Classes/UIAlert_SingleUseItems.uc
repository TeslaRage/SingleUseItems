class UIAlert_SingleUseItems extends UIAlert;

var public localized String m_strItemDestroyed;
var public localized String m_strItemRemovedInInventory;

simulated function BuildAlert()
{
	BindLibraryItem();

	BuildItemDestroyedAlert();	

	// Set  up the navigation *after* the alert is built, so that the button visibility can be used. 
	RefreshNavigation();	
}

simulated function Name GetLibraryID()
{
	//This gets the Flash library name to load in a panel. No name means no library asset yet. 
	switch ( eAlertName )
	{	
	case 'eAlert_ItemDestroyed': return 'Alert_ItemAvailable';
	default:
		return '';
	}
}

simulated function BuildItemDestroyedAlert()
{
	local TAlertAvailableInfo kInfo;
	local X2ItemTemplate ItemTemplate;
	local X2ItemTemplateManager TemplateManager;

	TemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	ItemTemplate = TemplateManager.FindItemTemplate(
		class'X2StrategyGameRulesetDataStructures'.static.GetDynamicNameProperty(DisplayPropertySet, 'ItemTemplate'));

	kInfo.strTitle = m_strItemDestroyed;
	kInfo.strName = ItemTemplate.GetItemFriendlyName(, false);
	kInfo.strBody = ItemTemplate.GetItemBriefSummary() $ "\n\n" $ Repl(m_strItemRemovedInInventory, "%ITEMNAME", ItemTemplate.GetItemFriendlyName(, false));
	kInfo.strConfirm = m_strAccept;
	kInfo.strImage = ItemTemplate.strImage;
	kInfo.eColor = eUIState_Good;
	kInfo.clrAlert = MakeLinearColor(0.0, 0.75, 0.0, 1);

	kInfo = FillInShenAlertAvailable(kInfo);

	BuildAvailableAlert(kInfo);
}