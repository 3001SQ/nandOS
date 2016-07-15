// -----------------------------------------------------------------------------
// distress_call.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Plugin for comms.as, embedded in the ArmDisplay UI
//

// NOTE We assume that libDCP.as was included by the main program (comms.as) and
//      is wrapped in the "WirelessLink" namespace

namespace DistressCallPlugin
{
// -----------------------------------------------
// -----------------------------------------------

bool _bInitialised = false;

X17::TextArea@ m_AreaWarningStatic;
X17::TextArea@ m_AreaResponse;

// Embedding in the ArmDisplay page

ArmScreenPage@ _page;
ArmScreenItem@ _item;

bool _bCallDispatched;

string _message;

// -------------------------------------

void activateActions(bool bActive)
{
	for (uint iAction = 0; iAction < 5; iAction++)
	{
		_item.actions[iAction].bActive = bActive;
		_page.GetActionMenu().SetButtonActive(iAction, _item.actions[iAction].bActive);
	}
	
	if (bActive)
	{
		_page.GetActionMenu().Select(_page.GetActionMenu().GetIndex());
	}
}

// Actions

void actionEmergency(vector<var> &in args)
{
	EmergencyReasonDCP reason = EmergencyReasonDCP(int(args[0]));

	ArmDisplayUI::logDebug("DistressCall app: Announcing emergency type " +
		toEmergencyString(reason));

	activateActions(false);
	
	_message = "Distress Call dispatched\n---\n";
	m_AreaResponse.SetText(_message);
	
	_bCallDispatched = true;
	
	WirelessLink::lib.RequestDockingEmergency(reason);
}

// -------------------------------------

int initialise(ArmScreenPage@ page, ArmScreenItem@ item)
{
	ArmDisplayUI::logDebug("DistressCall app: initialise");

	// Set up default elements
	
	if (!_bInitialised)
	{
		@_page = page;
		@_item = item;
		
		//GetActonMenu
		
		float leftBase = 0.25;
		
		// Set up specific elements
		
		@m_AreaWarningStatic = X17::CreateTextArea(X17::Display_Arm);
		m_AreaWarningStatic.SetText("WARNING: Only in case of emergency!\n" + 
			"Abuse will lower your U.C.I.\n" +
			"compliance rating and may entail\n" +
			"additional disciplinary measures.", 36);
		m_AreaWarningStatic.SetPosition(vec2(leftBase, 0.56));
		m_AreaWarningStatic.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);

		
		@m_AreaResponse = X17::CreateTextArea(X17::Display_Arm);
		m_AreaResponse.SetText("");
		m_AreaResponse.SetPosition(vec2(leftBase, 0.36));
		m_AreaResponse.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// ---
		
		// Action menu
		
		// 5 actions
		_item.actions = vector<ArmScreenAction>(5);

		_item.actions[0].label = "Device Malfunction";
		_item.actions[0].bActive = true;
		{
			vector<var> args = { int(DCP_Emergency_Malfunction) };
			_item.actions[0].args = args;
		}
		@_item.actions[0].functionHandle = @actionEmergency;
		
		_item.actions[1].label = "Structural Damage";
		_item.actions[1].bActive = true;
		{
			vector<var> args = { int(DCP_Emergency_Damage) };
			_item.actions[1].args = args;
		}
		@_item.actions[1].functionHandle = @actionEmergency;
		
		_item.actions[2].label = "Passengers/Crew/Mutiny";
		_item.actions[2].bActive = true;
		{
			vector<var> args = { int(DCP_Emergency_Crew) };
			_item.actions[2].args = args;
		}
		@_item.actions[2].functionHandle = @actionEmergency;
		
		_item.actions[3].label = "Radioactive/Chemical";
		_item.actions[3].bActive = true;
		{
			vector<var> args = { int(DCP_Emergency_Cargo2) };
			_item.actions[3].args = args;
		}
		@_item.actions[3].functionHandle = @actionEmergency;
		
		_item.actions[4].label = "Biohazard/Contamination";
		_item.actions[4].bActive = true;
		{
			vector<var> args = { int(DCP_Emergency_Cargo4) };
			_item.actions[4].args = args;
		}
		@_item.actions[4].functionHandle = @actionEmergency;
		
		// ---
		
		_bInitialised = true;
	}
	
	return 0;
}

void update()
{
	if (_bCallDispatched)
	{
		// Check whether we got a network response
		if (WirelessLink::lib.IsResponsePending())
		{
			ResponseDCP r = WirelessLink::lib.GetResponse();
			
			if (r.type == DCP_Response_Ok)
			{
				_message += r.message;
				m_AreaResponse.SetText(_message, 36);
				
				// CenterDisplayUI::SetTarget("[ EMERGENCY DOCKING ]");
			}
			
			activateActions(true);
			_bCallDispatched = false;
		}
	}
}

void setVisible(bool bVisible)
{
	ArmDisplayUI::logDebug("DistressCall app visible: " + bVisible);
	
	if (bVisible)
	{
		_page.SetTitle("Distress Call");
		_page.SetActionsTitle("REASON");
	}
	
	m_AreaWarningStatic.SetVisible(bVisible);
	m_AreaResponse.SetVisible(bVisible);
}

// -----------------------------------------------
// -----------------------------------------------
}