// -----------------------------------------------------------------------------
// lifesupport.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Plugin for comms.as, embedded in the ArmDisplay UI
//

namespace LifeSupportPlugin
{
// -----------------------------------------------
// -----------------------------------------------

bool _bInitialised = false;

X17::TextArea@ m_AreaDescriptionStatic;
X17::TextArea@ m_AreaDescription;

// Embedding in the ArmDisplay page

ArmScreenPage@ _page;
ArmScreenItem@ _item;

// Thermal control left/right, air revitalization, Water Coolant loop 01
vector<var> _lifesupportState = { true, true, true, true };

// -------------------------------------

void activateActions(bool bActive)
{
	for (uint iAction = 0; iAction < 4; iAction++)
	{
		_item.actions[iAction].bActive = bActive;
		_page.GetActionMenu().SetButtonActive(iAction, _item.actions[iAction].bActive);
	}
	
	if (bActive)
	{
		_page.GetActionMenu().Select(_page.GetActionMenu().GetIndex());
	}
}

void updateDescription()
{
	string state;
	state  = (_lifesupportState[0] ? "ON" : "OFF") + "\n";
	state += (_lifesupportState[1] ? "ON" : "OFF") + "\n";
	state += (_lifesupportState[2] ? "ON" : "OFF") + "\n";
	state += (_lifesupportState[3] ? "ON" : "OFF") + "\n";
	state += "ERROR\n";
	m_AreaDescription.SetText(state);
}

// Actions

void powerDevice(string path, bool bOn)
{
	int fdDevice = open(path, O_WRONLY);
	vector<var> controlToggle =
	{
		Control_Device_Power,
		bOn ? Device_PowerMode_On : Device_PowerMode_Off
	};
	write(fdDevice, controlToggle);
	close(fdDevice);
}

void actionToggle(vector<var> &in args)
{
	ArmDisplayUI::logDebug("LifeSupport app: Toggle");
	
	int idx = int(args[0]);
	_lifesupportState[idx] = !_lifesupportState[idx];

	switch(idx)
	{
		case 0:
			powerDevice("/dev/therm2", _lifesupportState[idx]);
			powerDevice("/dev/therm3", _lifesupportState[idx]);
			break;
		case 1:
			powerDevice("/dev/therm0", _lifesupportState[idx]);
			powerDevice("/dev/therm1", _lifesupportState[idx]);
			break;
		case 2:
			powerDevice("/dev/air0", _lifesupportState[idx]);
			break;
		case 3:
			powerDevice("/dev/wcl0", _lifesupportState[idx]);
			break;
	}
	
	updateDescription();
}

// -------------------------------------

int initialise(ArmScreenPage@ page, ArmScreenItem@ item)
{
	ArmDisplayUI::logDebug("LifeSupport app: Initialise");

	// Set up default elements
	
	if (!_bInitialised)
	{
		@_page = page;
		@_item = item;
		
		float leftBase = 0.25;
		
		@m_AreaDescriptionStatic = X17::CreateTextArea(X17::Display_Arm);
		m_AreaDescriptionStatic.SetText(
			" Thermal Control Left:\n" +
			"Thermal Control Right:\n" +
			"   Air Revitalisation:\n" +
			"Water Coolant Loop 01:\n" +
			"Water Coolant Loop 02:\n");
		m_AreaDescriptionStatic.SetPosition(vec2(leftBase, 0.5));
		m_AreaDescriptionStatic.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
		
		@m_AreaDescription = X17::CreateTextArea(X17::Display_Arm);
		m_AreaDescription.SetText("");
		m_AreaDescription.SetPosition(vec2(leftBase + 0.251, 0.5));
		m_AreaDescription.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		updateDescription();
			
		// ---
		
		// Action menu
		
		// 5 actions
		_item.actions = vector<ArmScreenAction>(5);

		int idx = 0;
		
		_item.actions[idx].label = "Thermal Control Left";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 0 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Thermal Control Right";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 1 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Air Revitalisation";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 2 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Water Coolant Loop 01";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 3 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Water Coolant Loop 02";
		_item.actions[idx].bActive = false;
		
		// ---
		
		_bInitialised = true;
	}
	
	return 0;
}

void setVisible(bool bVisible)
{
	ArmDisplayUI::logDebug("LifeSupport app visible: " + bVisible);

	if (bVisible)
	{
		_page.SetTitle("Life Support");
		_page.SetActionsTitle("ACTIONS");
	}
	
	m_AreaDescriptionStatic.SetVisible(bVisible);
	m_AreaDescription.SetVisible(bVisible);
}

// -----------------------------------------------
// -----------------------------------------------
}