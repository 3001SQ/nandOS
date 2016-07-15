// -----------------------------------------------------------------------------
// docking.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Plugin for comms.as, embedded in the ArmDisplay UI
//

namespace DockingPlugin
{
// -----------------------------------------------
// -----------------------------------------------

bool _bInitialised = false;

X17::TextLabel@ m_LabelRequestStatic;
X17::TextArea@ m_AreaRequest;

X17::TextLabel@ m_LabelResponseStatic;
X17::TextArea@ m_AreaResponse;

// Embedding in the ArmDisplay page

ArmScreenPage@ _page;
ArmScreenItem@ _item;

enum DockingState
{
	Docking_None = 0,			/** No pending requests, no docking granted */
	Docking_Requested,			/** Requesting permission to dock */
	Docking_PermissionGranted,	/** We were allowed to dock */
	Docking_Canceled			/** We requested to cancel docking */
}

DockingState _state = Docking_None;

// -------------------------------------

void clearMessages()
{
	m_AreaRequest.SetText("");
	m_AreaResponse.SetText("");
}

// Actions

void actionRequestDocking(vector<var> &in args)
{
	ArmDisplayUI::logDebug("Docking app: Request docking");
	
	clearMessages();
	
	// Provide some info message for the other vessel
	string message = "Requesting docking permission...";
	m_AreaRequest.SetText(message, 36);

	_state = Docking_Requested;
	
	_item.actions[0].bActive = false;
	_page.GetActionMenu().SetButtonActive(0, _item.actions[0].bActive);
	
	WirelessLink::lib.RequestDockingNormal(message);
}

void actionCancelDocking(vector<var> &in args)
{
	ArmDisplayUI::logDebug("Docking app: Cancel docking");
	
	clearMessages();
	
	// Provide some info message for the other vessel
	string message = "Cancelling docking procedure...";
	m_AreaRequest.SetText(message, 36);

	_state = Docking_Canceled;
	
	_item.actions[1].bActive = false;
	_page.GetActionMenu().SetButtonActive(1, _item.actions[1].bActive);
	
	WirelessLink::lib.RequestCancel(message);
}

// -------------------------------------

int initialise(ArmScreenPage@ page, ArmScreenItem@ item)
{
	ArmDisplayUI::logDebug("Docking app: initialise");

	// Set up default elements
	
	if (!_bInitialised)
	{
		@_page = page;
		@_item = item;
		
		//GetActonMenu
		
		float leftBase = 0.25;
		
		// Set up specific elements
		
		@m_LabelRequestStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelRequestStatic.SetText("REQUEST");
		m_LabelRequestStatic.SetAlpha(1.0);
		m_LabelRequestStatic.SetPosition(vec2(leftBase, 0.55));
		m_LabelRequestStatic.SetStyle(X17::Font_SystemBold, 6,
			Display_TextForeground_Cyan, Display_TextBackground_Default);

		@m_AreaRequest = X17::CreateTextArea(X17::Display_Arm);
		m_AreaRequest.SetText("");
		m_AreaRequest.SetPosition(vec2(leftBase, 0.5));
		m_AreaRequest.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// ---

		@m_LabelResponseStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelResponseStatic.SetText("RESPONSE");
		m_LabelResponseStatic.SetAlpha(1.0);
		m_LabelResponseStatic.SetPosition(vec2(leftBase, 0.42));
		m_LabelResponseStatic.SetStyle(X17::Font_SystemBold, 6,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
		
		@m_AreaResponse = X17::CreateTextArea(X17::Display_Arm);
		m_AreaResponse.SetText("");
		m_AreaResponse.SetPosition(vec2(leftBase, 0.37));
		m_AreaResponse.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// ---
		
		// Action menu
		
		// 5 actions
		_item.actions = vector<ArmScreenAction>(5);

		_item.actions[0].label = "Request Permission";
		_item.actions[0].bActive = true;
		@_item.actions[0].functionHandle = @actionRequestDocking;
		
		_item.actions[1].label = "Cancel Docking";
		_item.actions[1].bActive = false;
		@_item.actions[1].functionHandle = @actionCancelDocking;
		
		for (uint iAction = 2; iAction < 5; iAction++)
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
	if (_state == Docking_Requested)
	{
		if (WirelessLink::lib.IsResponsePending())
		{
			ResponseDCP r = WirelessLink::lib.GetResponse();
			
			if (r.type == DCP_Response_Ok)
			{
				_item.actions[1].bActive = true;
				_page.GetActionMenu().SetButtonActive(1, _item.actions[1].bActive);
				_page.GetActionMenu().Select(1);
				
				m_AreaResponse.SetText("Docking Access Granted\n---\n" + r.message, 36);
				
				// CenterDisplayUI::SetTarget("[ DOCKING ]");
				
				_state = Docking_PermissionGranted;
			}
		}
	}
	else if (_state == Docking_Canceled)
	{
		if (WirelessLink::lib.IsResponsePending())
		{
			ResponseDCP r = WirelessLink::lib.GetResponse();
			
			if (r.type == DCP_Response_Ok)
			{
				_item.actions[0].bActive = true;
				_page.GetActionMenu().SetButtonActive(0, _item.actions[0].bActive);
				_item.actions[1].bActive = false;
				_page.GetActionMenu().SetButtonActive(1, _item.actions[1].bActive);
				_page.GetActionMenu().Select(0);
				
				m_AreaResponse.SetText("Docking Aborted\n---\n" + r.message, 36);
				
				// CenterDisplayUI::SetTarget("");
				
				_state = Docking_None;
			}
		}
	}
}

void setVisible(bool bVisible)
{
	ArmDisplayUI::logDebug("Docking app visible: " + bVisible);

	if (bVisible)
	{
		_page.SetTitle("Docking");
		_page.SetActionsTitle("ACTIONS");
	}
	
	m_LabelRequestStatic.SetVisible(bVisible);
	m_AreaRequest.SetVisible(bVisible);

	m_LabelResponseStatic.SetVisible(bVisible);
	m_AreaResponse.SetVisible(bVisible);
}

// -----------------------------------------------
// -----------------------------------------------
}