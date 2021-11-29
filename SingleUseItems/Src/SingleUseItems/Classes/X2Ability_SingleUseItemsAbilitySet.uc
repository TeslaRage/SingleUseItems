class X2Ability_SingleUseItemsAbilitySet extends X2Ability config(SingleUse);

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;	

	Templates.AddItem(TRLimitedUsePassive());

	return Templates;
}

static function X2AbilityTemplate TRLimitedUsePassive()
{
	local X2AbilityTemplate Template;

	Template = CreatePassiveAbility('TRLimitedUsePassive', "img:///UILibrary_PerkIcons.UIPerk_destroycover");

	return Template;
}

static function X2AbilityTemplate CreatePassiveAbility(name AbilityName, optional string IconString, optional name IconEffectName = AbilityName, optional bool bDisplayIcon = true)
{	
	local X2AbilityTemplate Template;
	local X2Effect_Persistent IconEffect;	

	`CREATE_X2ABILITY_TEMPLATE (Template, AbilityName);
	Template.IconImage = IconString;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	Template.bCrossClassEligible = false;
	Template.bUniqueSource = true;
	Template.bIsPassive = true;

	// Dummy effect to show a passive icon in the tactical UI for the SourceUnit
	IconEffect = new class'X2Effect_Persistent';
	IconEffect.BuildPersistentEffect(1, true, false);
	IconEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.LocHelpText, Template.IconImage, bDisplayIcon,, Template.AbilitySourceName);
	IconEffect.EffectName = IconEffectName;
	Template.AddTargetEffect(IconEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	return Template;
}