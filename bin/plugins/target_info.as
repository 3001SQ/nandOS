// -----------------------------------------------------------------------------
// target_info.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Plugin for comms.as, embedded in the ArmDisplay UI
//

namespace TargetInfoPlugin
{
// -----------------------------------------------
// -----------------------------------------------

bool _bInitialised = false;

X17::TextArea@ m_AreaResponse;

// Embedding in the ArmDisplay page

ArmScreenPage@ _page;
ArmScreenItem@ _item;

bool bInfoRequested = false;

// -------------------------------------

// Actions

void actionRequestInfo(vector<var> &in args)
{
	ArmDisplayUI::logDebug("TargetInfo app: Request info");
	
	m_AreaResponse.SetText("");

	bInfoRequested = true;
	
	_item.actions[0].bActive = false;
	_page.GetActionMenu().SetButtonActive(0, _item.actions[0].bActive);
	
	WirelessLink::lib.RequestInfo();
}

// -------------------------------------

int initialise(ArmScreenPage@ page, ArmScreenItem@ item)
{
	ArmDisplayUI::logDebug("TargetInfo app: initialise");

	// Set up default elements
	
	if (!_bInitialised)
	{
		@_page = page;
		@_item = item;
		
		float leftBase = 0.25;
		
		@m_AreaResponse = X17::CreateTextArea(X17::Display_Arm);
		m_AreaResponse.SetText("");
		m_AreaResponse.SetPosition(vec2(leftBase, 0.55));
		m_AreaResponse.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// ---
		
		// Action menu
		
		// 5 actions
		_item.actions = vector<ArmScreenAction>(5);

		_item.actions[0].label = "Query Information";
		_item.actions[0].bActive = true;
		@_item.actions[0].functionHandle = @actionRequestInfo;
		
		_item.actions[1].label = "Scan (not installed)";
		_item.actions[1].bActive = false;
		
		_item.actions[2].label = "U.C.I. (not authorized)";
		_item.actions[2].bActive = false;
		
		for (uint iAction = 3; iAction < 5; iAction++)
		{
			_item.actions[iAction].bActive = false;
		}
		
		// ---
		
		_bInitialised = true;
	}
	
	return 0;
}

void update()
{
	// Check whether we got a network response
	if (bInfoRequested)
	{
		if (WirelessLink::lib.IsResponsePending())
		{
			ResponseDCP r = WirelessLink::lib.GetResponse();
			
			if (r.type == DCP_Response_Ok)
			{
				_item.actions[0].bActive = true;
				_page.GetActionMenu().SetButtonActive(0, _item.actions[0].bActive);
				_page.GetActionMenu().Select(0);
				
				string acceptedSpacecraft;
				
				for (uint iSpacecraft = 0; iSpacecraft < r.acceptedSpacecraft.size(); iSpacecraft++)
				{
					acceptedSpacecraft += string(r.acceptedSpacecraft[iSpacecraft]) + " ";
				}
				
				string emergencyFacilities;
				
				for (uint iFacility = 0; iFacility < r.emergencyFacilities.size(); iFacility++)
				{
					emergencyFacilities += string(r.emergencyFacilities[iFacility]) + " ";
				}
				
				m_AreaResponse.SetText("Received Information\n---\n" + r.message +
				"- Accepted spacecraft:\n" + acceptedSpacecraft +
				"\n- Emergency Facilities:\n" + emergencyFacilities, 36);
			}
			
			// TODO Error handling?
			
			bInfoRequested = false;
		}
	}
}

void setVisible(bool bVisible)
{
	ArmDisplayUI::logDebug("TargetInfo app visible: " + bVisible);

	if (bVisible)
	{
		_page.SetTitle("Target Info");
		_page.SetActionsTitle("ACTIONS");
	}
	
	m_AreaResponse.SetVisible(bVisible);
}

// -----------------------------------------------
// -----------------------------------------------
}