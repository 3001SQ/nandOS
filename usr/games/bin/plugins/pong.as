// -----------------------------------------------------------------------------
// pong.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Plugin for comms.as, embedded in the ArmDisplay UI
//

namespace GamePongPlugin
{
// -----------------------------------------------
// -----------------------------------------------

bool _bInitialised = false;

X17::TextArea@ m_AreaDescription;

// Embedding in the ArmDisplay page

ArmScreenPage@ _page;
ArmScreenItem@ _item;

// -------------------------------------

// Actions

void textMode()
{
	// Change into text mode
	vector<var> controlTextMode =
	{
		Control_Video_DisplayMode,
		1,
		Display_Mode_Text
	};
	write(X17::GetVideoFileDescriptor(), controlTextMode);
}

void bitmapMode()
{
	// Restore bitmap mode
	vector<var> controlBitmapMode =
	{
		Control_Video_DisplayMode,
		1,
		Display_Mode_Bitmap
	};
	write(X17::GetVideoFileDescriptor(), controlBitmapMode);
}

void actionPlay(vector<var> &in args)
{
	ArmDisplayUI::logDebug("GamePong app: Play");
	
	textMode();
	
	// Spawn pong process
	vector<var> execArgs;
	pid_t pongPid = fork();
	
	if (execv("/usr/games/bin/pong", execArgs) == -1)
	{
		m_AreaDescription.SetText("Could not launch the application!");
	}
	else
	{
		// Game started properly, wait until ended
		// NOTE The X17 loop will also be paused here as intended
		pid_t waitPid;
		do
		{
			waitPid = wait();
		} while(waitPid != pongPid);
	}
	
	bitmapMode();
}

// -------------------------------------

int initialise(ArmScreenPage@ page, ArmScreenItem@ item)
{
	ArmDisplayUI::logDebug("GamePong app: Initialise");

	// Set up default elements
	
	if (!_bInitialised)
	{
		@_page = page;
		@_item = item;
		
		float leftBase = 0.25;
		
		@m_AreaDescription = X17::CreateTextArea(X17::Display_Arm);
		m_AreaDescription.SetText("WARNING: Uses sidestick as input!");
		m_AreaDescription.SetPosition(vec2(leftBase, 0.55));
		m_AreaDescription.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// ---
		
		// Action menu
		
		// 5 actions
		_item.actions = vector<ArmScreenAction>(5);

		_item.actions[0].label = "Play Pong";
		_item.actions[0].bActive = true;
		@_item.actions[0].functionHandle = @actionPlay;
		
		for (uint iAction = 1; iAction < 5; iAction++)
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
	ArmDisplayUI::logDebug("GamePong app visible: " + bVisible);

	if (bVisible)
	{
		_page.SetTitle("Pong");
		_page.SetActionsTitle("ACTIONS");
		m_AreaDescription.SetText("WARNING: Uses sidestick as input!");
	}
	
	m_AreaDescription.SetVisible(bVisible);
}

// -----------------------------------------------
// -----------------------------------------------
}