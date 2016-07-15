// -----------------------------------------------------------------------------
// trade.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Plugin for comms.as, embedded in the ArmDisplay UI
//

namespace TradePlugin
{
// -----------------------------------------------
// -----------------------------------------------

bool _bInitialised = false;

X17::TextLabel@ m_PhysicalLinkStatic;

// Embedding in the ArmDisplay page

ArmScreenPage@ _page;
ArmScreenItem@ _item;

// -------------------------------------

// Actions

void actionRequestDocking(vector<var> &in args)
{
	ArmDisplayUI::logDebug("Trade app: Request docking");
}

void actionCancelDocking(vector<var> &in args)
{
	ArmDisplayUI::logDebug("Trade app: Cancel docking");
}

// -------------------------------------

int initialise(ArmScreenPage@ page, ArmScreenItem@ item)
{
	ArmDisplayUI::logDebug("Trade app: initialise");

	// Set up default elements
	
	if (!_bInitialised)
	{
		@_page = page;
		@_item = item;
		
		//GetActonMenu
		
		float leftBase = 0.25;
		
		// Set up specific elements
		
		@m_PhysicalLinkStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_PhysicalLinkStatic.SetText("Error: No physical link!");
		m_PhysicalLinkStatic.SetAlpha(1.0);
		m_PhysicalLinkStatic.SetPosition(vec2(leftBase, 0.55));
		m_PhysicalLinkStatic.SetStyle(X17::Font_SystemBold, 6,
			Display_TextForeground_Yellow, Display_TextBackground_Default);
			
		// ---
		
		// Action menu
		
		// 5 actions
		_item.actions = vector<ArmScreenAction>(5);

		_item.actions[0].label = "Commodities";
		_item.actions[0].bActive = false;
		
		_item.actions[1].label = "Contracts";
		_item.actions[1].bActive = false;
		
		_item.actions[2].label = "Licenses";
		_item.actions[2].bActive = false;
		
		_item.actions[3].label = "Station Services";
		_item.actions[3].bActive = false;
		
		_item.actions[4].label = "Food & Drinks";
		_item.actions[4].bActive = false;
		
		// for (uint iAction = 4; iAction < 5; iAction++)
		// {
			// _item.actions[iAction].bActive = false;
		// }
		
		// ---
		
		_bInitialised = true;
	}
	
	return 0;
}

void setVisible(bool bVisible)
{
	ArmDisplayUI::logDebug("Trade app visible: " + bVisible);

	if (bVisible)
	{
		_page.SetTitle("Trade");
		_page.SetActionsTitle("CATEGORIES");
	}
	
	m_PhysicalLinkStatic.SetVisible(bVisible);
}

// -----------------------------------------------
// -----------------------------------------------
}