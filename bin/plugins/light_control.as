// -----------------------------------------------------------------------------
// light_control.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Plugin for comms.as, embedded in the ArmDisplay UI
//

namespace LightControlPlugin
{
// -----------------------------------------------
// -----------------------------------------------

bool _bInitialised = false;

X17::TextArea@ m_AreaDescriptionStatic;
X17::TextArea@ m_AreaDescription;

// Embedding in the ArmDisplay page

ArmScreenPage@ _page;
ArmScreenItem@ _item;

vector<var> _lightState = { true, true, true, true };

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
	state  = (_lightState[0] ? "ON" : "OFF") + "\n";
	state += (_lightState[1] ? "ON" : "OFF") + "\n";
	state += (_lightState[2] ? "ON" : "OFF") + "\n";
	state += (_lightState[3] ? "ON" : "OFF") + "\n";
	m_AreaDescription.SetText(state);
}

// Actions

void actionToggle(vector<var> &in args)
{
	ArmDisplayUI::logDebug("LightControl app: Toggle");
	
	int idx = int(args[0]);
	_lightState[idx] = !_lightState[idx];

	string path = "/dev/light" + idx;
	int fdLight = open(path, O_WRONLY);
	vector<var> controlToggle =
	{
		Control_Device_Power,
		_lightState[idx] ? Device_PowerMode_On : Device_PowerMode_Off
	};
	write(fdLight, controlToggle);
	close(fdLight);
	
	updateDescription();
}

// -------------------------------------

int initialise(ArmScreenPage@ page, ArmScreenItem@ item)
{
	ArmDisplayUI::logDebug("LightControl app: Initialise");

	// Set up default elements
	
	if (!_bInitialised)
	{
		@_page = page;
		@_item = item;
		
		float leftBase = 0.25;
		
		@m_AreaDescriptionStatic = X17::CreateTextArea(X17::Display_Arm);
		m_AreaDescriptionStatic.SetText(
			"        Ceiling:\n" +
			"           Seat:\n" +
			" Dashboard left:\n" +
			"Dashboard right:\n");
		m_AreaDescriptionStatic.SetPosition(vec2(leftBase, 0.5));
		m_AreaDescriptionStatic.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
		
		@m_AreaDescription = X17::CreateTextArea(X17::Display_Arm);
		m_AreaDescription.SetText("");
		m_AreaDescription.SetPosition(vec2(leftBase + 0.185, 0.5));
		m_AreaDescription.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		updateDescription();
			
		// ---
		
		// Action menu
		
		// 5 actions
		_item.actions = vector<ArmScreenAction>(5);

		int idx = 0;
		
		_item.actions[idx].label = "Ceiling";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 0 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Seat";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 1 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Dashboard left";
		_item.actions[idx].bActive = true;
		{
			vector<var> args = { 2 };
			_item.actions[idx].args = args;
		}
		@_item.actions[idx].functionHandle = @actionToggle;
		
		idx++;
		
		_item.actions[idx].label = "Dashboard right";
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
		
		_bInitialised = true;
	}
	
	return 0;
}

void setVisible(bool bVisible)
{
	ArmDisplayUI::logDebug("LightControl app visible: " + bVisible);

	if (bVisible)
	{
		_page.SetTitle("Light Control");
		_page.SetActionsTitle("ACTIONS");
	}
	
	m_AreaDescriptionStatic.SetVisible(bVisible);
	m_AreaDescription.SetVisible(bVisible);
}

// -----------------------------------------------
// -----------------------------------------------
}