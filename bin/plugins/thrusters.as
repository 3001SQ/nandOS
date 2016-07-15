// -----------------------------------------------------------------------------
// thrusters.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Plugin for comms.as, embedded in the ArmDisplay UI
//

namespace ThrustersPlugin
{
// -----------------------------------------------
// -----------------------------------------------

X17::TextArea@ m_AreaDescriptionStatic;

bool _bInitialised = false;

// Embedding in the ArmDisplay page

ArmScreenPage@ _page;
ArmScreenItem@ _item;

vector<int> _thrusterGroups = 
{
	ThrusterControl::Pitch_Positive,
	ThrusterControl::Pitch_Negative,
	ThrusterControl::Yaw_Positive,
	ThrusterControl::Yaw_Negative
};

// -------------------------------------

// Actions

void actionToggle(vector<var> &in args)
{
	ArmDisplayUI::logDebug("Thrusters app: Toggle");

	int iGroup = int(args[0]);
	
	ThrusterControl::SetGroup(ThrusterControl::ThrusterGroup(_thrusterGroups[iGroup]), 1.0);
}

// -------------------------------------

int initialise(ArmScreenPage@ page, ArmScreenItem@ item)
{
	ArmDisplayUI::logDebug("Thrusters app: Initialise");

	// Set up default elements
	
	if (!_bInitialised)
	{
		@_page = page;
		@_item = item;
		
		float leftBase = 0.25;
		
		@m_AreaDescriptionStatic = X17::CreateTextArea(X17::Display_Arm);
		m_AreaDescriptionStatic.SetText(
			"WARNING: This may interfere with\nregular flightcontrols!\n");
		m_AreaDescriptionStatic.SetPosition(vec2(leftBase, 0.5));
		m_AreaDescriptionStatic.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// ---
		
		// Action menu
		
		// 5 actions
		_item.actions = vector<ArmScreenAction>(5);

		int idx = 0;
		
		_item.actions[idx].label = "Pitch Positive";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 0 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Pitch Negative";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 1 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Yaw Positive";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 2 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Yaw Negative";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 3 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		for (uint iAction = 4; iAction < 5; iAction++)
		{
			_item.actions[iAction].bActive = false;
		}
		
		// ---
		
		// Thruster control
		ThrusterControl::InitialiseDevices();
		
		// ---
		
		_bInitialised = true;
	}
	
	return 0;
}

void setVisible(bool bVisible)
{
	ArmDisplayUI::logDebug("Thrusters app visible: " + bVisible);

	if (bVisible)
	{
		_page.SetTitle("Thrusters");
		_page.SetActionsTitle("BURST TEST");
	}
	
	m_AreaDescriptionStatic.SetVisible(bVisible);
}

// -----------------------------------------------
// -----------------------------------------------
}