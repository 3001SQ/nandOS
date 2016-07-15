// -----------------------------------------------------------------------------
// comms.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Binary nandOS API
#include "stdio.h"
#include "time.h"
#include "fcntl.h"

// AngelScript libraries
#include "/lib/libDCP.as"
#include "/lib/libX17.as"
#include "/lib/libDB.as"
#include "/lib/libThrusters.as"

// Arm display plugins embedded in arm display pages
#include "/bin/plugins/docking.as"
#include "/bin/plugins/distress_call.as"
#include "/bin/plugins/trade.as"
#include "/bin/plugins/target_info.as"

// Arm display misc/game plugins
#include "/bin/plugins/light_control.as"
#include "/bin/plugins/lifesupport.as"
#include "/bin/plugins/thrusters.as"
#include "/usr/games/bin/plugins/pong.as"

// -----------------------------------------------------------------------------
// Arm Display implementation
// -----------------------------------------------------------------------------

enum Page
{
	Page_Target = 0,
	Page_Communication,
	Page_Misc
}

enum PageAction
{
	PageAction_Next = 0,
	PageAction_Previous,
	PageAction_Select,
	PageAction_Back
}

funcdef void ACTIONFUNC(vector<var> &in);

/** Available action for a list item */
class ArmScreenAction
{
	/** Text displayed on option */
	string label;
	
	/** Whether the action is active */
	bool bActive = true;
	
	/** Arguments passed to the action function to allow further customization */
	vector<var> args;
	
	/** Function to be executed when action is performed */
	ACTIONFUNC@ functionHandle;
}

/** Represents an item that can be interacted with, from navigation target to simple text entry */
class ArmScreenItem
{
	string label;

	/** Each page may interpret this in context */
	int userId = -1;
	
	/** Context-specific actions offered when the item is selected */
	vector<ArmScreenAction> actions;
	
	// -----------------------------------------------------

	ArmScreenAction@ GetAction(uint idx)
	{
		if (idx < actions.size())
		{
			return @actions[idx];
		}
		else
		{
			return null;
		}
	}
}

// ---------------------------------------------------------
// ---------------------------------------------------------

funcdef int APPINIT(ArmScreenPage@, ArmScreenItem@);
funcdef void APPEVENTHANDLER(X17::KeyEvent);
funcdef void APPUPDATE(void);
funcdef void APPVISIBLE(bool);

class ArmDisplayPlugin
{
	string label;

	APPINIT@ initialiseFunction;
	APPEVENTHANDLER@ eventFunction;
	APPUPDATE@ updateFunction;
	APPVISIBLE@ visibleFunction;
}

// Actual plugin implementations are included from "bin/plugins"

// ---------------------------------------------------------
// ---------------------------------------------------------

/** Base class for page content minus top menu */
abstract class ArmScreenPage
{
	protected bool m_bActive = false;
	
	X17::Menu m_ListMenu;
	X17::Menu m_ActionMenu;
	
	// ---
	
	vector<uint> m_ListButtons;
	vector<uint> m_ActionButtons;
	
	X17::TextLabel@ m_LabelTitle;
	X17::TextLabel@ m_LabelActions;
	
	// -------------------------------------------
	
	// Interface called by apps
	
	void SetTitle(string title)
	{
		m_LabelTitle.SetText(title);
	}
	
	void SetActionsTitle(string title)
	{
		m_LabelActions.SetText(title);
	}
	
	// -------------------------------------------
	
	void SelectFirstAction()
	{
		uint itemActionCount = m_Items[m_ListMenu.GetIndex()].actions.size();
	
		// Activate the first active button
		for (uint iButton = 0; iButton < itemActionCount; iButton++)
		{
			if (m_ActionMenu.IsButtonActive(iButton))
			{
				m_ActionMenu.Select(iButton);
				break;
			}
		}
	}
	
	// -------------------------------------------
	
	// Selectable items of the page
	vector<ArmScreenItem> m_Items;
	
	// Override this to set up an item of the selection list
	ArmScreenItem@ SetItem(uint idx, string label) { return null; }
	
	/** Override: Called by action menu cancel operation to return focus to list menu */
	void ReturnToListMenu() {}
	
	// Override this to update the screen when an item is selected
	void SelectItem(uint idx) {}
	
	X17::Menu@ GetActionMenu()
	{
		return @m_ActionMenu;
	}
	
	// -------------------------------------------
	
	// Each page should override this!
	void Initialise() {}
	
	// Each page should override this!
	void DeInitialise() {}
	
	// Each page should override this!
	void HandleEvent(X17::KeyEvent ev) {}
	
	// Each page should override this! Item -1 means select previous item
	void SetActive(bool bActive, int item = -1) {}
	
	// Each page should override this!
	void SetVisible(bool bVisible) {}
	
	// -------------------------------------------
	
	bool GetActive() const
	{
		return m_bActive;
	}
}

class TargetPage : ArmScreenPage
{
	// Labels with item data

	X17::TextLabel@ m_LabelRegistrationStatic;
	X17::TextLabel@ m_LabelModelStatic;
	X17::TextLabel@ m_LabelCommunicationStatic;
	
	X17::TextLabel@ m_LabelTransponderStatic;
	
	// ---
	
	X17::TextLabel@ m_LabelVesselId;
	X17::TextLabel@ m_LabelModel;
	X17::TextLabel@ m_LabelComms;
	
	X17::TextArea@ m_AreaDescription;
	
	// -------------------------------------------

	private ArmScreenItem@ SetItem(uint idx, string label) override
	{
		// NOTE We assume that enough item slots were reserved
		if (idx >= m_Items.size())
		{
			return null;
		}

		uint buttonId = m_ListButtons[idx];
		
		m_ListMenu.SetButton(idx, buttonId);
		
		vec2 basePosition = vec2(0.015, 0.7);
		X17::Button@ b = X17::GetButton(buttonId);
		b.SetText(label);
		b.SetPosition(basePosition + idx * 
			vec2(0, -0.014 * ArmDisplayUI::_menuButtonStyle.fontHeight));
		b.SetStyle(@ArmDisplayUI::_menuButtonStyle);
		
		int entryIdx = TargetDatabase::FindEntry(label);
		
		if (entryIdx != -1)
		{
			m_Items[idx].userId = entryIdx;
		}
		
		return @m_Items[idx];
	}
	
	private void ReturnToListMenu() override
	{
		SelectFirstAction();
		m_ListMenu.SetActive(true);
	}
	
	private void SelectItem(uint idx) override
	{
		if (idx >= m_Items.size())
		{
			return;
		}
	
		ArmScreenItem@ item = @m_Items[idx];
	
		// Change the active database entry for other pages, etc
		
		TargetDatabase::SetActive(idx);
	
		// Change content
		
		TargetDatabase::Entry@ entry = TargetDatabase::GetEntry(item.userId);

		m_LabelVesselId.SetText(entry.data[TargetDatabase::Data_VesselId]);
		m_LabelModel.SetText(entry.data[TargetDatabase::Data_Model]);
		m_LabelComms.SetText(entry.data[TargetDatabase::Data_Comms]);

		m_LabelTitle.SetText(entry.data[TargetDatabase::Data_Title]);
		
		m_AreaDescription.SetText(entry.data[TargetDatabase::Data_Description], 36);
		
		// Change action list
		
		uint itemActionCount = item.actions.size();
		
		for (uint iButton = 0; iButton < 5; iButton++)
		{
			X17::Button@ b = m_ActionMenu.GetButton(iButton);
		
			if (iButton < itemActionCount)
			{
				b.SetText(item.actions[iButton].label);
				b.SetState(item.actions[iButton].bActive ?
					X17::Button_Normal : X17::Button_Deactivated);
					
				m_ActionMenu.SetButtonActive(iButton, item.actions[iButton].bActive);
			}
			else
			{
				b.SetText("");
				m_ActionMenu.SetButtonActive(iButton, false);
			}
		}
		
		SelectFirstAction();
	}
	
	// -------------------------------------------
	
	void Initialise() override
	{
		// Prepare item menu
	
		m_Items = vector<ArmScreenItem>(8);
		m_ListMenu.ResetButtons(8);
		
		for (uint iListButton = 0; iListButton < 8; iListButton++)
		{
			uint buttonId = X17::CreateButton(X17::Display_Arm).m_Id;
			m_ListButtons.push_back(buttonId);
			m_ListMenu.SetButton(iListButton, buttonId);
		}
		
		// -------------------------------------------------

		// Prepare action menu
		
		m_ActionMenu.ResetButtons(5);
			
		vec2 actionBasePosition = vec2(0.71, 0.43);
		vec2 actionOffset = vec2(0.0, -0.06);
		
		for (uint iActionButton = 0; iActionButton < 5; iActionButton++)
		{
			X17::Button@ b = X17::CreateButton(X17::Display_Arm);
			m_ActionButtons.push_back(b.m_Id);
			m_ActionMenu.SetButton(iActionButton, b.m_Id);
			// ---
			b.SetText("");
			b.SetVisible(true);
			b.SetPosition(actionBasePosition + iActionButton * actionOffset);
			b.SetStyle(@ArmDisplayUI::_actionButtonStyle);
		}
		
		// -------------------------------------------------
	
		// NOTE Right now we are simply hard-coding the values, obtain from ship database
		
		@m_AreaDescription = X17::CreateTextArea(X17::Display_Arm);
		
		// Prepare items we can display

		// Default actions for stations
		vector<ArmScreenAction> defaultActions(5);
		uint actionIdx = 0;
		defaultActions[actionIdx].label = "Docking Request";
		defaultActions[actionIdx].bActive = false;
		actionIdx++;
		defaultActions[actionIdx].label = "Distress Call";
		defaultActions[actionIdx].bActive = false;
		actionIdx++;
		defaultActions[actionIdx].label = "Trading Interface";
		defaultActions[actionIdx].bActive = false;
		actionIdx++;
		defaultActions[actionIdx].label = "Query Information";
		defaultActions[actionIdx].bActive = false;
		actionIdx++;
		defaultActions[actionIdx].label = "";
		defaultActions[actionIdx].bActive = false;

		{
			ArmScreenItem@ item = SetItem(0, "STATION W1");
			
			item.actions = defaultActions;
			
			// Each function will receive the entry id as argument,
			// so the correct target is selected from the database
			
			vector<var> args;
			args.push_back(item.userId);
			
			actionIdx = 0;
			item.actions[actionIdx].bActive = true;
			@item.actions[actionIdx].functionHandle = @TargetPage::ActionDockingRequest;
			item.actions[actionIdx].args = args;
			
			actionIdx++;
			item.actions[actionIdx].bActive = true;
			@item.actions[actionIdx].functionHandle = @TargetPage::ActionDistressCall;
			item.actions[actionIdx].args = args;
			
			actionIdx++;
			item.actions[actionIdx].bActive = true;
			@item.actions[actionIdx].functionHandle = @TargetPage::ActionTrade;
			item.actions[actionIdx].args = args;
			
			actionIdx++;
			item.actions[actionIdx].bActive = true;
			@item.actions[actionIdx].functionHandle = @TargetPage::ActionQueryInformation;
			item.actions[actionIdx].args = args;
		}
		
		{
			ArmScreenItem@ item = SetItem(1, "STATION W2");
			
			item.actions = defaultActions;
		}
		
		{
			ArmScreenItem@ item = SetItem(2, "STATION M1");
			
			item.actions = defaultActions;
		}
		
		{
			ArmScreenItem@ item = SetItem(3, "UNKNOWN 1");
			
			item.actions = vector<ArmScreenAction>(1);
			item.actions[0].label = "Scan (not installed)";
			item.actions[0].bActive = false;
		}
		
		// Deactivate other items
		for (uint iListButton = 4; iListButton < 8; iListButton++)
		{
			m_ListMenu.SetButtonActive(iListButton, false);
		}

		// -------------------------------------------------
		
		// Center content

		vec2 topBasePosition = vec2(0.25, 0.835);
		vec2 topOffset = vec2(0, -0.05);

		// ---
		
		@m_LabelRegistrationStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelRegistrationStatic.SetText("REGISTRATION:");
		m_LabelRegistrationStatic.SetVisible(true);
		m_LabelRegistrationStatic.SetAlpha(1.0);
		m_LabelRegistrationStatic.SetPosition(topBasePosition);
		m_LabelRegistrationStatic.SetStyle(X17::Font_SystemBold, 4,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
		
		@m_LabelVesselId = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelVesselId.SetText("");
		m_LabelVesselId.SetVisible(true);
		m_LabelVesselId.SetAlpha(1.0);
		m_LabelVesselId.SetPosition(topBasePosition + vec2(0.15, 0));
		m_LabelVesselId.SetStyle(X17::Font_System, 4,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// ---
		
		@m_LabelModelStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelModelStatic.SetText("MODEL:");
		m_LabelModelStatic.SetVisible(true);
		m_LabelModelStatic.SetAlpha(1.0);
		m_LabelModelStatic.SetPosition(topBasePosition + topOffset);
		m_LabelModelStatic.SetStyle(X17::Font_SystemBold, 4,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
		
		@m_LabelModel = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelModel.SetText("");
		m_LabelModel.SetVisible(true);
		m_LabelModel.SetAlpha(1.0);
		m_LabelModel.SetPosition(topBasePosition + topOffset + vec2(0.075, 0));
		m_LabelModel.SetStyle(X17::Font_System, 4,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// ---
		
		@m_LabelCommunicationStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelCommunicationStatic.SetText("COMMUNICATION:");
		m_LabelCommunicationStatic.SetVisible(true);
		m_LabelCommunicationStatic.SetAlpha(1.0);
		m_LabelCommunicationStatic.SetPosition(topBasePosition + 2 * topOffset);
		m_LabelCommunicationStatic.SetStyle(X17::Font_SystemBold, 4,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
				
		@m_LabelComms = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelComms.SetText("");
		m_LabelComms.SetVisible(true);
		m_LabelComms.SetAlpha(1.0);
		m_LabelComms.SetPosition(topBasePosition + 2 * topOffset + vec2(0.163, 0));
		m_LabelComms.SetStyle(X17::Font_System, 4,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// ---
		
		@m_LabelTitle = X17::CreateTextLabel(X17::Display_Arm);
		// m_LabelTitle.SetText("");
		m_LabelTitle.SetVisible(true);
		m_LabelTitle.SetAlpha(1.0);
		m_LabelTitle.SetPosition(vec2(0.25, 0.62));
		m_LabelTitle.SetStyle(X17::Font_System, 10,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// ---

		@m_LabelTransponderStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelTransponderStatic.SetText("TRANSPONDER MESSAGE");
		m_LabelTransponderStatic.SetVisible(true);
		m_LabelTransponderStatic.SetAlpha(1.0);
		m_LabelTransponderStatic.SetPosition(vec2(0.25, 0.55));
		m_LabelTransponderStatic.SetStyle(X17::Font_System, 5,
			Display_TextForeground_Cyan, Display_TextBackground_Default);

		@m_AreaDescription = X17::CreateTextArea(X17::Display_Arm);
		m_AreaDescription.SetText("");
		m_AreaDescription.SetPosition(vec2(0.25, 0.5));
		m_AreaDescription.SetVisible(true);
		m_AreaDescription.SetStyle(X17::Font_System, 4.0, 1.05,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// -------------------------------------------------
		
		// Target actions

		@m_LabelActions = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelActions.SetText("ACTIONS");
		m_LabelActions.SetVisible(true);
		m_LabelActions.SetAlpha(1.0);
		m_LabelActions.SetPosition(vec2(0.71, 0.50));
		m_LabelActions.SetStyle(X17::Font_System, 8,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// -------------------------------------------------
		
		// Set up initial state
		
		@ArmDisplayUI::ActivePage = @TargetPage::Instance;
		SelectItem(0);
	}
	
	void DeInitialise() override
	{
	}
	
	void HandleEvent(X17::KeyEvent ev) override
	{
		if (m_ListMenu.IsActive())
		{
			if (ev.type == X17::KeyEvent_Pressed)
			{
				if (ev.keyCode == Keyboard_Key_Up)
				{
					m_ListMenu.SelectPrevious();
				}
				else if (ev.keyCode == Keyboard_Key_Down)
				{
					m_ListMenu.SelectNext();
				}
				else if (ev.keyCode == Keyboard_Key_Confirm)
				{
					m_ListMenu.ButtonPressed(ev.bDown);
				
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Confirm);
						
						SelectItem(m_ListMenu.GetIndex());
					
						bool bActionsAvailable = false;
						
						for (uint iAction = 0; iAction < m_Items.size(); iAction++)
						{
							if (m_ActionMenu.IsButtonActive(iAction))
							{
								bActionsAvailable = true;
								break;
							}
						}
						
						if (bActionsAvailable)
						{
							// Deactivate list menu
					
							m_ListMenu.SetActive(false);
							
							// Enter into page context
							
							m_ActionMenu.SetActive(true);
						}
					}
				}
				else if (ev.keyCode == Keyboard_Key_Cancel)
				{
					m_ListMenu.ButtonPressed(ev.bDown);
					
					// Return focus to page menu
					
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Cancel);
					
						ArmDisplayUI::ReturnToPageMenu();
					}
				}
			}
		}
		else if (m_ActionMenu.IsActive())
		{
			if (ev.type == X17::KeyEvent_Pressed)
			{
				if (ev.keyCode == Keyboard_Key_Up)
				{
					m_ActionMenu.SelectPrevious();
				}
				else if (ev.keyCode == Keyboard_Key_Down)
				{
					m_ActionMenu.SelectNext();
				}
				else if (ev.keyCode == Keyboard_Key_Confirm)
				{
					m_ActionMenu.ButtonPressed(ev.bDown);
			
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Confirm);
					
						ArmScreenAction@ action = @m_Items[m_ListMenu.GetIndex()].actions[m_ActionMenu.GetIndex()];
						if (action.functionHandle !is null)
						{
							action.functionHandle(action.args);
						}
					}
				}
				else if (ev.keyCode == Keyboard_Key_Cancel)
				{
					m_ActionMenu.ButtonPressed(ev.bDown);
					
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Cancel);
					
						m_ActionMenu.SetActive(false);
					
						// Return focus to page menu
						
						ReturnToListMenu();
					}
				}
			}
		}
	}
	
	void SetActive(bool bActive, int item = -1) override
	{
		if (bActive)
		{
			@ArmDisplayUI::ActivePage = @this;
		}
	
		m_bActive = bActive;
		m_ListMenu.SetActive(m_bActive);
				
		if (bActive && item != -1)
		{
			m_ListMenu.Select(item);
			SelectFirstAction();
			if (m_ActionMenu.HasActiveButtons())
			{
				m_ListMenu.SetActive(false);
				m_ActionMenu.SetActive(true);
			}
		}
	}
	
	void SetVisible(bool bVisible) override
	{
		// Menus
		
		m_ListMenu.SetVisible(bVisible);
		m_ActionMenu.SetVisible(bVisible);
		
		// Static content
		
		m_LabelRegistrationStatic.SetVisible(bVisible);
		m_LabelModelStatic.SetVisible(bVisible);
		m_LabelCommunicationStatic.SetVisible(bVisible);
		
		m_LabelTransponderStatic.SetVisible(bVisible);
		
		m_LabelActions.SetVisible(bVisible);
		
		// Dynamic content
		
		m_LabelVesselId.SetVisible(bVisible);
		m_LabelModel.SetVisible(bVisible);
		m_LabelComms.SetVisible(bVisible);

		m_LabelTitle.SetVisible(bVisible);
	
		m_AreaDescription.SetVisible(bVisible);
	}
}

namespace TargetPage
{
	// Generic action handlers

	void ActionDockingRequest(vector<var> &in args)
	{
		ArmDisplayUI::logDebug("TargetPage: Request docking " + string(args[0]));

		TargetPage::Instance.m_ActionMenu.SetActive(false);
		TargetPage::Instance.m_ListMenu.SetActive(false);
		TargetPage::Instance.SetActive(false);
		
		ArmDisplayUI::_pageMenu.SetActive(false);
		ArmDisplayUI::_pageMenu.Select(1);
		
		CommunicationPage::Instance.SetActive(true);
		ArmDisplayUI::SelectPage(Page_Communication, 0);
	}

	void ActionDistressCall(vector<var> &in args)
	{
		ArmDisplayUI::logDebug("TargetPage: Distress call " + string(args[0]));
		
		TargetPage::Instance.m_ActionMenu.SetActive(false);
		TargetPage::Instance.m_ListMenu.SetActive(false);
		TargetPage::Instance.SetActive(false);
		
		ArmDisplayUI::_pageMenu.SetActive(false);
		ArmDisplayUI::_pageMenu.Select(1);
		
		CommunicationPage::Instance.SetActive(true);
		ArmDisplayUI::SelectPage(Page_Communication, 1);
	}
	
	void ActionTrade(vector<var> &in args)
	{
		ArmDisplayUI::logDebug("TargetPage: Trade " + string(args[0]));
		
		TargetPage::Instance.m_ActionMenu.SetActive(false);
		TargetPage::Instance.m_ListMenu.SetActive(false);
		TargetPage::Instance.SetActive(false);
		
		ArmDisplayUI::_pageMenu.SetActive(false);
		ArmDisplayUI::_pageMenu.Select(1);
		
		CommunicationPage::Instance.SetActive(true);
		ArmDisplayUI::SelectPage(Page_Communication, 2);
	}
	
	void ActionQueryInformation(vector<var> &in args)
	{
		ArmDisplayUI::logDebug("TargetPage: Query information " + string(args[0]));
		
		TargetPage::Instance.m_ActionMenu.SetActive(false);
		TargetPage::Instance.m_ListMenu.SetActive(false);
		TargetPage::Instance.SetActive(false);
		
		ArmDisplayUI::_pageMenu.SetActive(false);
		ArmDisplayUI::_pageMenu.Select(1);
		
		CommunicationPage::Instance.SetActive(true);
		ArmDisplayUI::SelectPage(Page_Communication, 3);
	}
	
	// -------------------------------------------
	
	/** Singleton instance of the target page */
	TargetPage@ Instance;
}

// ---------------------------------------------------------
// ---------------------------------------------------------

class CommunicationPage : ArmScreenPage
{
	vector<ArmDisplayPlugin> m_Apps;
	
	int m_LastActiveApp = -1;

	// -------------------------------------------

	X17::TextLabel@ m_LabelTargetStatic;
	X17::TextLabel@ m_LabelWirelessStatic;
	X17::TextLabel@ m_LabelPhysicalStatic;
	
	// ---
	
	X17::TextLabel@ m_LabelTarget;
	X17::TextLabel@ m_LabelWireless;
	X17::TextLabel@ m_LabelPhysical;

	// -------------------------------------------

	private ArmScreenItem@ SetItem(uint idx, string label) override
	{
		// NOTE We assume that enough item slots were reserved
		if (idx >= m_Items.size())
		{
			return null;
		}

		uint buttonId = m_ListButtons[idx];
		
		m_ListMenu.SetButton(idx, buttonId);
		
		vec2 basePosition = vec2(0.015, 0.7);
		X17::Button@ b = X17::GetButton(buttonId);
		b.SetText(label);
		b.SetPosition(basePosition + idx * 
			vec2(0, -0.014 * ArmDisplayUI::_menuButtonStyle.fontHeight));
		b.SetStyle(@ArmDisplayUI::_menuButtonStyle);
		
		return @m_Items[idx];
	}
	
	private void SelectItem(uint idx) override
	{
		if (idx >= m_Items.size())
		{
			return;
		}
	
		// Hide previous 
		if (m_LastActiveApp != -1)
		{
			m_Apps[m_LastActiveApp].visibleFunction(false);
		}
	
		ArmScreenItem@ item = @m_Items[idx];
	
		// Change the active database entry for other pages, etc
		
		m_ListMenu.Select(idx);
		
		m_Apps[idx].visibleFunction(true);
		m_LastActiveApp = idx;

		// Change action list
		
		uint itemActionCount = item.actions.size();
		
		for (uint iButton = 0; iButton < 5; iButton++)
		{
			X17::Button@ b = m_ActionMenu.GetButton(iButton);
		
			if (iButton < itemActionCount)
			{
				b.SetText(item.actions[iButton].label);
				b.SetState(item.actions[iButton].bActive ?
					X17::Button_Normal : X17::Button_Deactivated);
					
				m_ActionMenu.SetButtonActive(iButton, item.actions[iButton].bActive);
			}
			else
			{
				b.SetText("");
				m_ActionMenu.SetButtonActive(iButton, false);
			}
		}
		
		SelectFirstAction();		
	}
	
	private void ReturnToListMenu() override
	{
		SelectFirstAction();
		m_ListMenu.SetActive(true);
	}

	// -------------------------------------------

	void Initialise() override
	{
		// Prepare item menu
	
		m_Items = vector<ArmScreenItem>(8);
		m_ListMenu.ResetButtons(8);
		
		for (uint iListButton = 0; iListButton < 8; iListButton++)
		{
			uint buttonId = X17::CreateButton(X17::Display_Arm).m_Id;
			m_ListButtons.push_back(buttonId);
			m_ListMenu.SetButton(iListButton, buttonId);
		}
		
		// -------------------------------------------------

		// Prepare action menu
		
		m_ActionMenu.ResetButtons(5);
			
		vec2 actionBasePosition = vec2(0.71, 0.43);
		vec2 actionOffset = vec2(0.0, -0.06);
		
		for (uint iActionButton = 0; iActionButton < 5; iActionButton++)
		{
			X17::Button@ b = X17::CreateButton(X17::Display_Arm);
			m_ActionButtons.push_back(b.m_Id);
			m_ActionMenu.SetButton(iActionButton, b.m_Id);
			// ---
			b.SetText("");
			b.SetVisible(true);
			b.SetPosition(actionBasePosition + iActionButton * actionOffset);
			b.SetStyle(@ArmDisplayUI::_actionButtonStyle);
		}
		
		// -------------------------------------------------

		{
			uint appId = m_Apps.size();
			m_Apps.push_back(ArmDisplayPlugin());
			
			ArmDisplayPlugin@ app = @m_Apps[appId];
			app.label = "DOCKING";
			@app.initialiseFunction = DockingPlugin::initialise;
			@app.updateFunction = DockingPlugin::update;
			@app.visibleFunction = DockingPlugin::setVisible;
			
			ArmScreenItem@ item = SetItem(appId, app.label);
			item.userId = appId;
			
			app.initialiseFunction(@CommunicationPage::Instance, @item);
		}
		
		{
			uint appId = m_Apps.size();
			m_Apps.push_back(ArmDisplayPlugin());
			
			ArmDisplayPlugin@ app = @m_Apps[appId];
			app.label = "DISTRESS CALL";
			@app.initialiseFunction = DistressCallPlugin::initialise;
			@app.updateFunction = DistressCallPlugin::update;
			@app.visibleFunction = DistressCallPlugin::setVisible;
			
			ArmScreenItem@ item = SetItem(appId, app.label);
			item.userId = appId;
			
			app.initialiseFunction(@CommunicationPage::Instance, @item);
		}
		
		{
			uint appId = m_Apps.size();
			m_Apps.push_back(ArmDisplayPlugin());
			
			ArmDisplayPlugin@ app = @m_Apps[appId];
			app.label = "TRADE";
			@app.initialiseFunction = TradePlugin::initialise;
			@app.visibleFunction = TradePlugin::setVisible;
			
			ArmScreenItem@ item = SetItem(appId, app.label);
			item.userId = appId;
			
			app.initialiseFunction(@CommunicationPage::Instance, @item);
		}
		
		{
			uint appId = m_Apps.size();
			m_Apps.push_back(ArmDisplayPlugin());
			
			ArmDisplayPlugin@ app = @m_Apps[appId];
			app.label = "TARGET INFO";
			@app.initialiseFunction = TargetInfoPlugin::initialise;
			@app.updateFunction = TargetInfoPlugin::update;
			@app.visibleFunction = TargetInfoPlugin::setVisible;
			
			ArmScreenItem@ item = SetItem(appId, app.label);
			item.userId = appId;
			
			app.initialiseFunction(@CommunicationPage::Instance, @item);
		}
		
		// Deactivate other items
		for (uint iListButton = 4; iListButton < 8; iListButton++)
		{
			m_ListMenu.SetButtonActive(iListButton, false);
		}

		// -------------------------------------------------
		
		// Center content

		vec2 topBasePosition = vec2(0.25, 0.835);
		vec2 topOffset = vec2(0, -0.05);

		// ---
		
		@m_LabelTargetStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelTargetStatic.SetText("TARGET:");
		m_LabelTargetStatic.SetVisible(true);
		m_LabelTargetStatic.SetAlpha(1.0);
		m_LabelTargetStatic.SetPosition(topBasePosition);
		m_LabelTargetStatic.SetStyle(X17::Font_SystemBold, 4,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
		
		@m_LabelTarget = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelTarget.SetText(TargetDatabase::GetEntry(TargetDatabase::GetActiveIndex()).label);
		m_LabelTarget.SetVisible(true);
		m_LabelTarget.SetAlpha(1.0);
		m_LabelTarget.SetPosition(topBasePosition + vec2(0.085, 0));
		m_LabelTarget.SetStyle(X17::Font_System, 4,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// ---
		
		@m_LabelWirelessStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelWirelessStatic.SetText("WIRELESS LINK:");
		m_LabelWirelessStatic.SetVisible(true);
		m_LabelWirelessStatic.SetAlpha(1.0);
		m_LabelWirelessStatic.SetPosition(topBasePosition + topOffset);
		m_LabelWirelessStatic.SetStyle(X17::Font_SystemBold, 4,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
		
		@m_LabelWireless = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelWireless.SetText("Connection established");
		m_LabelWireless.SetVisible(true);
		m_LabelWireless.SetAlpha(1.0);
		m_LabelWireless.SetPosition(topBasePosition + topOffset + vec2(0.163, 0));
		m_LabelWireless.SetStyle(X17::Font_System, 4,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// ---
		
		@m_LabelPhysicalStatic = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelPhysicalStatic.SetText("PHYSICAL LINK:");
		m_LabelPhysicalStatic.SetVisible(true);
		m_LabelPhysicalStatic.SetAlpha(1.0);
		m_LabelPhysicalStatic.SetPosition(topBasePosition + 2 * topOffset);
		m_LabelPhysicalStatic.SetStyle(X17::Font_SystemBold, 4,
			Display_TextForeground_Cyan, Display_TextBackground_Default);
				
		@m_LabelPhysical = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelPhysical.SetText("Not connected");
		m_LabelPhysical.SetVisible(true);
		m_LabelPhysical.SetAlpha(1.0);
		m_LabelPhysical.SetPosition(topBasePosition + 2 * topOffset + vec2(0.163, 0));
		m_LabelPhysical.SetStyle(X17::Font_System, 4,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// ---
		
		@m_LabelTitle = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelTitle.SetText("");
		m_LabelTitle.SetAlpha(1.0);
		m_LabelTitle.SetPosition(vec2(0.25, 0.62));
		m_LabelTitle.SetStyle(X17::Font_System, 10,
			Display_TextForeground_White, Display_TextBackground_Default);
			
		// -------------------------------------------------
		
		// Target actions

		@m_LabelActions = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelActions.SetVisible(true);
		m_LabelActions.SetAlpha(1.0);
		m_LabelActions.SetPosition(vec2(0.71, 0.50));
		m_LabelActions.SetStyle(X17::Font_System, 8,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// -------------------------------------------------

		@ArmDisplayUI::ActivePage = @CommunicationPage::Instance;
		SelectItem(0);
	}
	
	void HandleEvent(X17::KeyEvent ev) override
	{
		if (ev.type == X17::KeyEvent_Pressed)
		{
			if (m_ListMenu.IsActive())
			{
				if (ev.keyCode == Keyboard_Key_Up)
				{
					m_ListMenu.SelectPrevious();
				}
				else if (ev.keyCode == Keyboard_Key_Down)
				{
					m_ListMenu.SelectNext();
				}
				else if (ev.keyCode == Keyboard_Key_Confirm)
				{
					m_ListMenu.ButtonPressed(ev.bDown);
				
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Confirm);
					
						SelectItem(m_ListMenu.GetIndex());
					
						bool bActionsAvailable = false;
						
						for (uint iAction = 0; iAction < m_Items.size(); iAction++)
						{
							if (m_ActionMenu.IsButtonActive(iAction))
							{
								bActionsAvailable = true;
								break;
							}
						}
						
						if (bActionsAvailable)
						{
							// Deactivate list menu
					
							m_ListMenu.SetActive(false);
							
							// Enter into page context
							
							m_ActionMenu.SetActive(true);
						}
					}
				}
				else if (ev.keyCode == Keyboard_Key_Cancel)
				{
					m_ListMenu.ButtonPressed(ev.bDown);
					
					// Return focus to page menu when releasing key
					
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Cancel);
					
						ArmDisplayUI::ReturnToPageMenu();
					}
				}
			}
			else if (m_ActionMenu.IsActive())
			{
				if (ev.keyCode == Keyboard_Key_Up)
				{
					m_ActionMenu.SelectPrevious();
				}
				else if (ev.keyCode == Keyboard_Key_Down)
				{
					m_ActionMenu.SelectNext();
				}
				else if (ev.keyCode == Keyboard_Key_Confirm)
				{
					m_ActionMenu.ButtonPressed(ev.bDown);
				
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Confirm);
					
						ArmScreenAction@ action = @m_Items[m_ListMenu.GetIndex()].actions[m_ActionMenu.GetIndex()];
						if (action.functionHandle !is null)
						{
							action.functionHandle(action.args);
						}
					}
				}
				else if (ev.keyCode == Keyboard_Key_Cancel)
				{
					m_ActionMenu.ButtonPressed(ev.bDown);
					
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Cancel);
					
						m_ActionMenu.SetActive(false);
					
						// Return focus to page menu
						
						ReturnToListMenu();
					}
				}
			}
		}
	}
	
	void SetActive(bool bActive, int item = -1) override
	{
		if (bActive)
		{
			@ArmDisplayUI::ActivePage = @this;
		}

		m_bActive = bActive;
		m_ListMenu.SetActive(m_bActive);
		
		if (bActive && item != -1)
		{
			SelectItem(item);
			SelectFirstAction();
			if (m_ActionMenu.HasActiveButtons())
			{
				m_ListMenu.SetActive(false);
				m_ActionMenu.SetActive(true);
			}
		}
	}
	
	void SetVisible(bool bVisible) override
	{
		// Menus
	
		m_ListMenu.SetVisible(bVisible);
		m_ActionMenu.SetVisible(bVisible);
	
		// Static content
	
		m_LabelTargetStatic.SetVisible(bVisible);
		m_LabelWirelessStatic.SetVisible(bVisible);
		m_LabelPhysicalStatic.SetVisible(bVisible);
		
		m_LabelActions.SetVisible(bVisible);
		
		// Dynamic content
		
		m_LabelTarget.SetVisible(bVisible);
		m_LabelWireless.SetVisible(bVisible);
		m_LabelPhysical.SetVisible(bVisible);
		
		m_LabelTitle.SetVisible(bVisible);
		
		// Plugin
		if (m_LastActiveApp != -1)
		{
			m_Apps[m_LastActiveApp].visibleFunction(bVisible);
		}
	}

	/** Should be called from an X17 PostDraw callback */
	void UpdateApps()
	{
		// Update Network devices
		WirelessLink::Update();

		// Update app
		if (m_Apps[m_LastActiveApp].updateFunction !is  null)
		{
			m_Apps[m_LastActiveApp].updateFunction();
		}
	
	}
}

namespace CommunicationPage
{
	/** Singleton instance of the communication page */
	CommunicationPage@ Instance;
}

// ---------------------------------------------------------
// ---------------------------------------------------------

class MiscPage : ArmScreenPage
{
	vector<ArmDisplayPlugin> m_Apps;
	
	int m_LastActiveApp = -1;

	// -------------------------------------------
	
	private ArmScreenItem@ SetItem(uint idx, string label) override
	{
		// NOTE We assume that enough item slots were reserved
		if (idx >= m_Items.size())
		{
			return null;
		}

		uint buttonId = m_ListButtons[idx];
		
		m_ListMenu.SetButton(idx, buttonId);
		
		vec2 basePosition = vec2(0.015, 0.7);
		X17::Button@ b = X17::GetButton(buttonId);
		b.SetText(label);
		b.SetPosition(basePosition + idx * 
			vec2(0, -0.014 * ArmDisplayUI::_menuButtonStyle.fontHeight));
		b.SetStyle(@ArmDisplayUI::_menuButtonStyle);
		
		return @m_Items[idx];
	}
	
	private void SelectItem(uint idx) override
	{
		if (idx >= m_Items.size())
		{
			return;
		}
	
		// Hide previous 
		if (m_LastActiveApp != -1)
		{
			m_Apps[m_LastActiveApp].visibleFunction(false);
		}
	
		ArmScreenItem@ item = @m_Items[idx];
	
		// Change the active database entry for other pages, etc
		
		m_ListMenu.Select(idx);
		
		m_Apps[idx].visibleFunction(true);
		m_LastActiveApp = idx;

		// Change action list
		
		uint itemActionCount = item.actions.size();
		
		for (uint iButton = 0; iButton < 5; iButton++)
		{
			X17::Button@ b = m_ActionMenu.GetButton(iButton);
		
			if (iButton < itemActionCount)
			{
				b.SetText(item.actions[iButton].label);
				b.SetState(item.actions[iButton].bActive ?
					X17::Button_Normal : X17::Button_Deactivated);
					
				m_ActionMenu.SetButtonActive(iButton, item.actions[iButton].bActive);
			}
			else
			{
				b.SetText("");
				m_ActionMenu.SetButtonActive(iButton, false);
			}
		}
		
		SelectFirstAction();		
	}
	
	private void ReturnToListMenu() override
	{
		SelectFirstAction();
		m_ListMenu.SetActive(true);
	}
	
	// -------------------------------------------
	
	void Initialise() override
	{
		@ArmDisplayUI::ActivePage = @MiscPage::Instance;
		
		// Prepare item menu
	
		m_Items = vector<ArmScreenItem>(8);
		m_ListMenu.ResetButtons(8);
		
		for (uint iListButton = 0; iListButton < 8; iListButton++)
		{
			uint buttonId = X17::CreateButton(X17::Display_Arm).m_Id;
			m_ListButtons.push_back(buttonId);
			m_ListMenu.SetButton(iListButton, buttonId);
		}
		
		// -------------------------------------------------
		
		{
			uint appId = m_Apps.size();
			m_Apps.push_back(ArmDisplayPlugin());
			
			ArmDisplayPlugin@ app = @m_Apps[appId];
			app.label = "GAME: PONG";
			@app.initialiseFunction = GamePongPlugin::initialise;
			@app.visibleFunction = GamePongPlugin::setVisible;
			
			ArmScreenItem@ item = SetItem(appId, app.label);
			item.userId = appId;
			
			app.initialiseFunction(@MiscPage::Instance, @item);
		}
		
		{
			uint appId = m_Apps.size();
			m_Apps.push_back(ArmDisplayPlugin());
			
			ArmDisplayPlugin@ app = @m_Apps[appId];
			app.label = "LIGHT CONTROL";
			@app.initialiseFunction = LightControlPlugin::initialise;
			@app.visibleFunction = LightControlPlugin::setVisible;
			
			ArmScreenItem@ item = SetItem(appId, app.label);
			item.userId = appId;
			
			app.initialiseFunction(@MiscPage::Instance, @item);
		}
		
		{
			uint appId = m_Apps.size();
			m_Apps.push_back(ArmDisplayPlugin());
			
			ArmDisplayPlugin@ app = @m_Apps[appId];
			app.label = "LIFE SUPPORT";
			@app.initialiseFunction = LifeSupportPlugin::initialise;
			@app.visibleFunction = LifeSupportPlugin::setVisible;
			
			ArmScreenItem@ item = SetItem(appId, app.label);
			item.userId = appId;
			
			app.initialiseFunction(@MiscPage::Instance, @item);
		}
		
		{
			uint appId = m_Apps.size();
			m_Apps.push_back(ArmDisplayPlugin());
			
			ArmDisplayPlugin@ app = @m_Apps[appId];
			app.label = "THRUSTERS";
			@app.initialiseFunction = ThrustersPlugin::initialise;
			@app.visibleFunction = ThrustersPlugin::setVisible;
			
			ArmScreenItem@ item = SetItem(appId, app.label);
			item.userId = appId;
			
			app.initialiseFunction(@MiscPage::Instance, @item);
		}

		// Deactivate other items
		for (uint iListButton = 4; iListButton < 8; iListButton++)
		{
			m_ListMenu.SetButtonActive(iListButton, false);
		}

		// -------------------------------------------------

		// Prepare action menu
		
		m_ActionMenu.ResetButtons(5);
			
		vec2 actionBasePosition = vec2(0.71, 0.43);
		vec2 actionOffset = vec2(0.0, -0.06);
		
		for (uint iActionButton = 0; iActionButton < 5; iActionButton++)
		{
			X17::Button@ b = X17::CreateButton(X17::Display_Arm);
			m_ActionButtons.push_back(b.m_Id);
			m_ActionMenu.SetButton(iActionButton, b.m_Id);
			// ---
			b.SetText("");
			b.SetVisible(true);
			b.SetPosition(actionBasePosition + iActionButton * actionOffset);
			b.SetStyle(@ArmDisplayUI::_actionButtonStyle);
		}
		
		// -------------------------------------------------

		@m_LabelTitle = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelTitle.SetText("");
		m_LabelTitle.SetAlpha(1.0);
		m_LabelTitle.SetPosition(vec2(0.25, 0.62));
		m_LabelTitle.SetStyle(X17::Font_System, 10,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// Target actions

		@m_LabelActions = X17::CreateTextLabel(X17::Display_Arm);
		m_LabelActions.SetVisible(true);
		m_LabelActions.SetAlpha(1.0);
		m_LabelActions.SetPosition(vec2(0.71, 0.50));
		m_LabelActions.SetStyle(X17::Font_System, 8,
			Display_TextForeground_White, Display_TextBackground_Default);
		
		// -------------------------------------------------

		@ArmDisplayUI::ActivePage = @MiscPage::Instance;
		SelectItem(0);
	}
	
	void HandleEvent(X17::KeyEvent ev) override
	{
		if (ev.type == X17::KeyEvent_Pressed)
		{
			if (m_ListMenu.IsActive())
			{
				if (ev.keyCode == Keyboard_Key_Up)
				{
					m_ListMenu.SelectPrevious();
				}
				else if (ev.keyCode == Keyboard_Key_Down)
				{
					m_ListMenu.SelectNext();
				}
				else if (ev.keyCode == Keyboard_Key_Confirm)
				{
					m_ListMenu.ButtonPressed(ev.bDown);
				
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Confirm);
					
						SelectItem(m_ListMenu.GetIndex());
					
						bool bActionsAvailable = false;
						
						for (uint iAction = 0; iAction < m_Items.size(); iAction++)
						{
							if (m_ActionMenu.IsButtonActive(iAction))
							{
								bActionsAvailable = true;
								break;
							}
						}
						
						if (bActionsAvailable)
						{
							// Deactivate list menu
					
							m_ListMenu.SetActive(false);
							
							// Enter into page context
							
							m_ActionMenu.SetActive(true);
						}
					}
				}
				else if (ev.keyCode == Keyboard_Key_Cancel)
				{
					m_ListMenu.ButtonPressed(ev.bDown);
					
					// Return focus to page menu when releasing key
					
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Cancel);
					
						ArmDisplayUI::ReturnToPageMenu();
					}
				}
			}
			else if (m_ActionMenu.IsActive())
			{
				if (ev.keyCode == Keyboard_Key_Up)
				{
					m_ActionMenu.SelectPrevious();
				}
				else if (ev.keyCode == Keyboard_Key_Down)
				{
					m_ActionMenu.SelectNext();
				}
				else if (ev.keyCode == Keyboard_Key_Confirm)
				{
					m_ActionMenu.ButtonPressed(ev.bDown);
				
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Confirm);
					
						ArmScreenAction@ action = @m_Items[m_ListMenu.GetIndex()].actions[m_ActionMenu.GetIndex()];
						if (action.functionHandle !is null)
						{
							action.functionHandle(action.args);
						}
					}
				}
				else if (ev.keyCode == Keyboard_Key_Cancel)
				{
					m_ActionMenu.ButtonPressed(ev.bDown);
					
					if (!ev.bDown)
					{
						ArmDisplayUI::PlaySound(Sound_Cancel);
					
						m_ActionMenu.SetActive(false);
					
						// Return focus to page menu
						
						ReturnToListMenu();
					}
				}
			}
		}
	}
	
	void SetActive(bool bActive, int item = -1) override
	{
		if (bActive)
		{
			@ArmDisplayUI::ActivePage = @this;
		}

		m_bActive = bActive;
		m_ListMenu.SetActive(m_bActive);
		
		if (bActive && item != -1)
		{
			SelectItem(item);
			SelectFirstAction();
			if (m_ActionMenu.HasActiveButtons())
			{
				m_ListMenu.SetActive(false);
				m_ActionMenu.SetActive(true);
			}
		}
	}
	
	void SetVisible(bool bVisible) override
	{
		// Menus
	
		m_ListMenu.SetVisible(bVisible);
		m_ActionMenu.SetVisible(bVisible);
	
		// Static content
		
		m_LabelActions.SetVisible(bVisible);
		
		// Dynamic content
		
		m_LabelTitle.SetVisible(bVisible);
		
		// Plugin
		if (m_LastActiveApp != -1)
		{
			m_Apps[m_LastActiveApp].visibleFunction(bVisible);
		}
	}
}

namespace MiscPage
{
	/** Singleton instance of the misc page */
	MiscPage@ Instance;
}

// ---------------------------------------------------------
// ---------------------------------------------------------

enum SoundId
{
	Sound_Confirm = 0,
	Sound_Cancel
}

// -----------------------------------------------------------------------------
// Arm display, contains most of interactive UI
// -----------------------------------------------------------------------------

namespace ArmDisplayUI
{
// -------------------------------------------------------------------
// -------------------------------------------------------------------

// Debugging

bool bDebug = false;

void logDebug(string message)
{
	if (bDebug)
	{
		log("(ArmDisplay) " + message);
	}
}

// ---------------------------------------------------------

// Sounds

int _fdAudio = -1;

void _initialiseAudio()
{
	_fdAudio = open("/dev/audio", O_WRONLY);
}

void _deInitialiseAudio()
{
	close(_fdAudio);
}

void PlaySound(SoundId id)
{
	int sound = 0;

	if (id == Sound_Confirm)
	{
		sound = 1;
	}
	else if (id == Sound_Cancel)
	{
		sound = 2;
	}
	
	vector<var> controlSound =
	{
		Control_Audio_Play,
		sound
	};
	write(_fdAudio, controlSound);
}

// ---------------------------------------------------------

ArmScreenPage@ ActivePage;

// Currently active page
Page _activePage = Page_Target;

// Menus and buttons

X17::Menu _pageMenu;

X17::ButtonStyle _menuButtonStyle;
X17::ButtonStyle _actionButtonStyle;

// ---------------------------------------------------------

void Initialise()
{
	_initialiseAudio();

	X17::SetBackgroundTexture(X17::Display_Arm, int(X17::Display_Arm));

	// -------------------------------------------------

	_menuButtonStyle = X17::ButtonStyle(X17::Font_SystemBold, 5.5,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_menuButtonStyle.SetColours(X17::Button_Selected, Display_TextForeground_Black, Display_TextBackground_Cyan);
	_menuButtonStyle.SetColours(X17::Button_Hover, Display_TextForeground_Black, Display_TextBackground_Red);
	_menuButtonStyle.SetColours(X17::Button_Active, Display_TextForeground_White, Display_TextBackground_Red);
	_menuButtonStyle.SetColours(X17::Button_Deactivated,
		Display_TextForeground_LightGray, Display_TextBackground_Default);

	_actionButtonStyle = X17::ButtonStyle(X17::Font_SystemBold, 4.0,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_actionButtonStyle.SetColours(X17::Button_Selected, Display_TextForeground_Black, Display_TextBackground_Cyan);
	_actionButtonStyle.SetColours(X17::Button_Hover, Display_TextForeground_Black, Display_TextBackground_Red);
	_actionButtonStyle.SetColours(X17::Button_Active, Display_TextForeground_White, Display_TextBackground_Red);
	_actionButtonStyle.SetColours(X17::Button_Deactivated,
		Display_TextForeground_LightGray, Display_TextBackground_Default);

	// -------------------------------------------------

	X17::SetEventCallback(HandleEvents);
	X17::SetPostDrawCallback(PostDraw);

	// -------------------------------------------------

	//  Set up page menu
	
	_pageMenu.ResetButtons(3);
	
	{
		X17::Button@ b = X17::CreateButton(X17::Display_Arm);
		_pageMenu.SetButton(0, b.m_Id);
		// ---
		b.SetText("TARGET");
		b.SetVisible(true);
		b.SetPosition(vec2(0.07, 0.915));
		b.SetStyle(@_menuButtonStyle);
	}
	
	{
		X17::Button@ b = X17::CreateButton(X17::Display_Arm);
		_pageMenu.SetButton(1, b.m_Id);
		// ---
		b.SetText("COMMS");
		b.SetVisible(true);
		b.SetPosition(vec2(0.231, 0.923));
		b.SetStyle(@_menuButtonStyle);
	}
	
	{
		X17::Button@ b = X17::CreateButton(X17::Display_Arm);
		_pageMenu.SetButton(2, b.m_Id);
		// ---
		b.SetText("APPS");
		b.SetVisible(true);
		b.SetPosition(vec2(0.355, 0.923));
		b.SetStyle(@_menuButtonStyle);
	}

	_pageMenu.SetActive(true);
	
	// -------------------------------------------------

	// Page with final focus should be last
	
	@MiscPage::Instance = @MiscPage();
	
	MiscPage::Instance.Initialise();
	MiscPage::Instance.SetVisible(false);
	
	@CommunicationPage::Instance = @CommunicationPage();
	
	CommunicationPage::Instance.Initialise();
	CommunicationPage::Instance.SetVisible(false);
	
	@TargetPage::Instance = @TargetPage();
	
	TargetPage::Instance.Initialise();
	TargetPage::Instance.SetVisible(true);
	
	TargetPage::Instance.m_ListMenu.Select(0);

}

void DeInitialise()
{
	TargetPage::Instance.DeInitialise();

	X17::DeInitialise();
	
	_deInitialiseAudio();
}

// ---------------------------------------------------------

/** Called by top-level cancel operations of each page to allow page selection after key release */
void ReturnToPageMenu()
{
	if (_activePage == Page_Target)
	{
		TargetPage::Instance.SetActive(false);
	}
	else if (_activePage == Page_Communication)
	{
		CommunicationPage::Instance.SetActive(false);
	}
	else if (_activePage == Page_Misc)
	{
		MiscPage::Instance.SetActive(false);
	}
	
	_pageMenu.SetActive(true);
}

void SelectPage(Page page, int item = -1)
{
	SetVisiblePage(page);
	
	if (page == Page_Target)
	{
		TargetPage::Instance.SetActive(true, item);
	}
	else if (_activePage == Page_Communication)
	{
		CommunicationPage::Instance.SetActive(true, item);
	}
	else if (_activePage == Page_Misc)
	{
		MiscPage::Instance.SetActive(true, item);
	}
}

void SetVisiblePage(Page page)
{
	if (page == _activePage)
	{
		// Do nothing if there is no change
		return;
	}
	
	if (_activePage == Page_Target)
	{
		TargetPage::Instance.SetVisible(false);
	}
	else if (_activePage == Page_Communication)
	{
		CommunicationPage::Instance.SetVisible(false);
	}
	else if (_activePage == Page_Misc)
	{
		MiscPage::Instance.SetVisible(false);
	}

	// ---
	
	X17::ForceSwapBuffers(1);

	// ---
	
	_activePage = page;
	
	if (_activePage == Page_Target)
	{
		TargetPage::Instance.SetVisible(true);
	}
	else if (_activePage == Page_Communication)
	{
		CommunicationPage::Instance.SetVisible(true);
	}
	else if (_activePage == Page_Misc)
	{
		MiscPage::Instance.SetVisible(true);
	}
}

void _pageMenuHandleEvents(X17::KeyEvent ev)
{
	if (ev.type == X17::KeyEvent_Pressed)
	{
		if (ev.keyCode == Keyboard_Key_Up)
		{
			_pageMenu.SelectPrevious();
		}
		else if (ev.keyCode == Keyboard_Key_Down)
		{
			_pageMenu.SelectNext();
		}
		else if (ev.keyCode == Keyboard_Key_Confirm)
		{
			_pageMenu.ButtonPressed(ev.bDown);
			
			if (!ev.bDown)
			{					
				ArmDisplayUI::PlaySound(Sound_Confirm);
			
				// Deactivate page menu
			
				_pageMenu.SetActive(false);
				
				// Enter into page context
				
				uint idx = _pageMenu.GetIndex();
				
				if (idx == 0)
				{
					TargetPage::Instance.SetActive(true);
					SetVisiblePage(Page_Target);
				}
				else if (idx == 1)
				{
					CommunicationPage::Instance.SetActive(true);
					SetVisiblePage(Page_Communication);
				}
				else if (idx == 2)
				{
					MiscPage::Instance.SetActive(true);
					SetVisiblePage(Page_Misc);
				}
			}
		}
		else if (ev.keyCode == Keyboard_Key_Cancel)
		{
			_pageMenu.ButtonPressed(ev.bDown);
			
			// We can't go up any higher
		}
	}
}

void HandleEvents(vector<X17::KeyEvent> &in keyEvents)
{
	for (uint iEvent = 0; iEvent < keyEvents.size(); iEvent++)
	{
		X17::KeyEvent ev = keyEvents[iEvent];
		
		if (_pageMenu.IsActive())
		{
			_pageMenuHandleEvents(ev);
		}
		// Pass event along to page
		else if (_activePage == Page_Target)
		{
			TargetPage::Instance.HandleEvent(ev);
		}
		else if (_activePage == Page_Communication)
		{
			CommunicationPage::Instance.HandleEvent(ev);
		}
		else if (_activePage == Page_Misc)
		{
			MiscPage::Instance.HandleEvent(ev);
		}
	}
}

void PostDraw()
{
	// Other logic
	
	if (_activePage == Page_Communication)
	{
		CommunicationPage::Instance.UpdateApps();
	}
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}

// -----------------------------------------------------------------------------
// Prepare database
// -----------------------------------------------------------------------------

void fillDatabase()
{
	{
		TargetDatabase::Entry@ entry = TargetDatabase::AddEntry("STATION W1");
		
		entry.data = vector<var>(TargetDatabase::Data_SIZE);
		entry.data[TargetDatabase::Data_Title] = "Station W1";
		entry.data[TargetDatabase::Data_Description] = 
				"Automated Water Mining Station 1\n"
				"- Operator:\n" +
				"Universal Colonisation Initiative\n" +
				"- Status:\n" +
				"Operational, Storage 36.4%\n" +
				"\n" +
				"Docking is only granted to pilots\nwith U.C.I. compliance " +
				"rating 100\n('neutral') or better.\n" +
				"\n" +
				"Have a nice day.\n";
		entry.data[TargetDatabase::Data_VesselId] = "984B5AB546CA";
		entry.data[TargetDatabase::Data_Model] = "AMS-WS";
		entry.data[TargetDatabase::Data_Comms] = "Link established";
	}
	
	{
		TargetDatabase::Entry@ entry = TargetDatabase::AddEntry("STATION W2");
		
		entry.data = vector<var>(TargetDatabase::Data_SIZE);
		entry.data[TargetDatabase::Data_Title] = "Station W2";
		entry.data[TargetDatabase::Data_Description] = 
			"Automated Water Mining Station 2\n"
			"- Operator:\n" +
			"Universal Colonisation Initiative\n" +
			"- Status:\n" +
			"Operational, Storage 68.4%\n" +
			"\n" +
			"Docking restrictions lifted.\n"
			"Free ST1 coffe pack per transport.\n"
			"Let's beat W1 this month!\n" + 
			"               - Nikola (sysadmin)\n" +
			"\n";
		entry.data[TargetDatabase::Data_VesselId] = "5A2C16E4ED70";
		entry.data[TargetDatabase::Data_Model] = "AMS-WS";
		entry.data[TargetDatabase::Data_Comms] = "Out of range";
	}
		
	{
		TargetDatabase::Entry@ entry = TargetDatabase::AddEntry("STATION M1");
		
		entry.data = vector<var>(TargetDatabase::Data_SIZE);
		entry.data[TargetDatabase::Data_Title] = "Station M1";
		entry.data[TargetDatabase::Data_Description] =
			"Automated Metal Mining Station 1\n"
			"- Operator:\n" +
			"Universal Colonisation Initiative\n" +
			"- Status:\n" +
			"Maintenance required, Storage 0.0%\n" +
			"\n" +
			"! Req. repair modules class T/C1\n" +
			"\n" +
			"Docking is only granted to pilots\nwith U.C.I. compliance " +
			"rating 100\n('neutral') or better.\n" +
			"\n";
		entry.data[TargetDatabase::Data_VesselId] = "9F1D3E8DF323";
		entry.data[TargetDatabase::Data_Model] = "AMS-MS";
		entry.data[TargetDatabase::Data_Comms] = "Out of range";
	}
	
	{
		TargetDatabase::Entry@ entry = TargetDatabase::AddEntry("UNKNOWN 1");
		
		entry.data = vector<var>(TargetDatabase::Data_SIZE);
		entry.data[TargetDatabase::Data_Title] = "Unknown 1";
		entry.data[TargetDatabase::Data_Description] = "< NONE >";
		entry.data[TargetDatabase::Data_VesselId] = "-";
		entry.data[TargetDatabase::Data_Model] = "< Unidentified metallic object >";
		entry.data[TargetDatabase::Data_Comms] = "Not responding";
	}
}

// -----------------------------------------------------------------------------
// Right display, for now only STATIC data displayed
// -----------------------------------------------------------------------------

namespace ContainerDisplayUI
{
// -------------------------------------------------------------------
// -------------------------------------------------------------------

X17::TextLabel@ _cargoStatic;
X17::TextLabel@ _cargo;

X17::TextLabel@ _originStatic;
X17::TextLabel@ _origin;

X17::TextLabel@ _weightStatic;
X17::TextLabel@ _weight;

X17::TextLabel@ _classStatic;
X17::TextLabel@ _class;

X17::TextLabel@ _energyStatic;
X17::TextLabel@ _energy;

X17::TextArea@ _description;

// ---------------------------------------------------------

void Initialise()
{
	X17::SetBackgroundTexture(X17::Display_Container, int(X17::Display_Container));

	@_cargoStatic = X17::CreateTextLabel(X17::Display_Container);
	_cargoStatic.SetText("CARGO:");
	_cargoStatic.SetAlpha(1.0);
	_cargoStatic.SetVisible(true);
	_cargoStatic.SetStyle(X17::Font_SystemBold, 6,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_cargoStatic.SetPosition(vec2(0.48, 0.87));
	
	@_cargo = X17::CreateTextLabel(X17::Display_Container);
	_cargo.SetAlpha(1.0);
	_cargo.SetVisible(true);
	_cargo.SetStyle(X17::Font_System, 6,
		Display_TextForeground_White, Display_TextBackground_Default);
	_cargo.SetPosition(_cargoStatic.GetPosition() + vec2(_cargoStatic.GetDimensions().x + 0.01, 0));
	
	@_originStatic = X17::CreateTextLabel(X17::Display_Container);
	_originStatic.SetText("ORIGIN:");
	_originStatic.SetAlpha(1.0);
	_originStatic.SetVisible(true);
	_originStatic.SetStyle(X17::Font_SystemBold, 5,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_originStatic.SetPosition(vec2(0.48, 0.74));
	
	@_origin = X17::CreateTextLabel(X17::Display_Container);
	_origin.SetAlpha(1.0);
	_origin.SetVisible(true);
	_origin.SetStyle(X17::Font_System, 5,
		Display_TextForeground_White, Display_TextBackground_Default);
	_origin.SetPosition(_originStatic.GetPosition() + vec2(_originStatic.GetDimensions().x + 0.01, 0));
	
	@_weightStatic = X17::CreateTextLabel(X17::Display_Container);
	_weightStatic.SetText("WEIGHT:");
	_weightStatic.SetAlpha(1.0);
	_weightStatic.SetVisible(true);
	_weightStatic.SetStyle(X17::Font_SystemBold, 5,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_weightStatic.SetPosition(vec2(0.48, 0.64));
	
	@_weight = X17::CreateTextLabel(X17::Display_Container);
	_weight.SetAlpha(1.0);
	_weight.SetVisible(true);
	_weight.SetStyle(X17::Font_System, 5,
		Display_TextForeground_White, Display_TextBackground_Default);
	_weight.SetPosition(_weightStatic.GetPosition() + vec2(_weightStatic.GetDimensions().x + 0.01, 0));
	
	@_classStatic = X17::CreateTextLabel(X17::Display_Container);
	_classStatic.SetText("CONTAINER CLASS:");
	_classStatic.SetAlpha(1.0);
	_classStatic.SetVisible(true);
	_classStatic.SetStyle(X17::Font_SystemBold, 5,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_classStatic.SetPosition(vec2(0.48, 0.54));
	
	@_class = X17::CreateTextLabel(X17::Display_Container);
	_class.SetAlpha(1.0);
	_class.SetVisible(true);
	_class.SetStyle(X17::Font_System, 5,
		Display_TextForeground_White, Display_TextBackground_Default);
	_class.SetPosition(_classStatic.GetPosition() + vec2(_classStatic.GetDimensions().x + 0.01, 0));
	
	@_energyStatic = X17::CreateTextLabel(X17::Display_Container);
	_energyStatic.SetText("ENERGY CONSUMPTION:");
	_energyStatic.SetAlpha(1.0);
	_energyStatic.SetVisible(true);
	_energyStatic.SetStyle(X17::Font_SystemBold, 5,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_energyStatic.SetPosition(vec2(0.48, 0.44));
	
	@_energy = X17::CreateTextLabel(X17::Display_Container);
	_energy.SetAlpha(1.0);
	_energy.SetVisible(true);
	_energy.SetStyle(X17::Font_System, 5,
		Display_TextForeground_White, Display_TextBackground_Default);
	_energy.SetPosition(_energyStatic.GetPosition() + vec2(_energyStatic.GetDimensions().x + 0.01, 0));
	
	@_description = X17::CreateTextArea(X17::Display_Container);
	_description.SetPosition(vec2(0.47, 0.38));
	_description.SetVisible(true);
	_description.SetStyle(X17::Font_System, 3.5, 1.1,
		Display_TextForeground_White, Display_TextBackground_Default);
}

void SetContainer(string cargo, string origin, float weight, string cargoClass,
	float energy, string description)
{
	string sWeight = string(weight);
	string sEnergy = string(energy);

	_cargo.SetText(cargo);
	_origin.SetText(origin);
	_weight.SetText(sWeight.substr(0, sWeight.find(".") + 3) + " t");
	_class.SetText(cargoClass);
	_energy.SetText(sEnergy.substr(0, sEnergy.find(".") + 3) + " MW");
	_description.SetText(description, 43);
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}

namespace LogDisplayUI
{
// -------------------------------------------------------------------
// -------------------------------------------------------------------

vector<Entry> m_LogEntries;

vec2 m_TopPosition = vec2(0.1, 0.9);

// ---------------------------------------------------------

class Entry
{
	private X17::TextLabel@ m_Decoration;
	private X17::TextLabel@ m_Timestamp;
	private X17::TextLabel@ m_Type;
	private X17::TextLabel@ m_Message;
	
	/** The entry is anchored on its upper left corner */
	private vec2 m_Position;
	
	// -------------------------------------------
	
	Entry() {}
	
	/** Allocates text labels, however neither placed nor visible, SetPosition() mandatory */
	Entry(string time, string type, string message, X17::DisplayId displayId = X17::Display_Log)
	{
		@m_Decoration = X17::CreateTextLabel(displayId);
		m_Decoration.SetText("//");
		m_Decoration.SetAlpha(1.0);
		m_Decoration.SetStyle(X17::Font_SystemBold, 6,
			Display_TextForeground_Red, Display_TextBackground_Default);
			
		@m_Timestamp = X17::CreateTextLabel(displayId);
		m_Timestamp.SetText(time);
		m_Timestamp.SetAlpha(1.0);
		m_Timestamp.SetStyle(X17::Font_SystemBold, 6,
			Display_TextForeground_Red, Display_TextBackground_Default);
			
		@m_Type = X17::CreateTextLabel(displayId);
		m_Type.SetText(type + ":");
		m_Type.SetAlpha(1.0);
		m_Type.SetStyle(X17::Font_SystemBold, 3.5,
			Display_TextForeground_Cyan, Display_TextBackground_Default);

		@m_Message = X17::CreateTextLabel(displayId);
		m_Message.SetText(message);
		m_Message.SetAlpha(1.0);
		m_Message.SetStyle(X17::Font_SystemBold, 3.5,
			Display_TextForeground_White, Display_TextBackground_Default);
	}
	
	void SetPosition(vec2 position)
	{
		m_Position = position;

		m_Decoration.SetPosition(position + vec2(0, -m_Decoration.GetDimensions().y));
		m_Decoration.SetVisible(true);
		
		m_Timestamp.SetPosition(m_Decoration.GetPosition() + vec2(m_Decoration.GetDimensions().x + 0.05, 0));
		m_Timestamp.SetVisible(true);
		
		m_Type.SetPosition(m_Decoration.GetPosition() + vec2(0, -0.6 * m_Decoration.GetDimensions().y));
		m_Type.SetVisible(true);
		
		m_Message.SetPosition(m_Type.GetPosition() + vec2(m_Type.GetDimensions().x + 0.01, 0));
		m_Message.SetVisible(true);
	}
}

// ---------------------------------------------------------

void Initialise()
{
	X17::SetBackgroundTexture(X17::Display_Log, int(X17::Display_Log));
}

void AddEntry(string time, string type, string message)
{
	m_LogEntries.push_back(Entry(time, type, message));
	m_LogEntries[0].SetPosition(m_TopPosition);
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}

// -----------------------------------------------------------------------------
// Handle data links
// -----------------------------------------------------------------------------

namespace WirelessLink
{
	// Device path we want to use
	string _devicePath;

	// Vessel model we will transmit
	string _vesselModel;
	
	// Vessel ID we will transmit
	string _vesselId;

	// Taken from libDCP.as
	DCP@ lib;
	
	// -----------------------------------------------------
	
	void Initialise(string path, string model, string id)
	{
		_devicePath = path;
		_vesselModel = model;
		_vesselId = id;
		
		@lib = @DCP(_devicePath, _vesselModel, _vesselId, true);
		
		// Uncomment for additional debug info
		// lib.SetDebug(true);
		
		log("Initialising wireless link " + _devicePath);
		log("  Vessel: " + _vesselModel + " " + _vesselId);
	}
	
	void Update()
	{
		// Should be called to send/receive data over the link
		
		lib.PollNetworkData();
	}
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Application entry point
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

int main(uint argc, vector<var> &in argv)
{
	log("Starting Communications");

	log("PID=" + getpid() + " PPID=" + getppid());

	// --------------------------------------------------------
	
	vector<var> inputDevices = { "/dev/event2" };
	X17::Initialise("/dev/iq0", inputDevices);
	
	// Open the wireless link using libDCP
	WirelessLink::Initialise("/dev/wlan0", "MPS", "S38");
	
	// --------------------------------------------------------
	
	fillDatabase();
	
	// Uncomment for additional debug information
	// ArmDisplayUI::bDebug = true;
	ArmDisplayUI::Initialise();
	
	ContainerDisplayUI::Initialise();
	ContainerDisplayUI::SetContainer("Water", "Station W2", 30, "PASSIVE", 0,
		"BEING A BASE REQUIREMENT FOR HUMAN LIFE,\nFARMING AND VARIOUS TECHNICAL APPLICATIONS,\n" +
		"WATER IS A KEY NECESSITY FOR SPACE\nCOLONISATION. IT IS USUALLY EXTRACTED FROM\nPOLAR " +
		"ICE CAPS, CAPTURED FROM THE\nATMOSPHERE OR SIMPLY COLLECTED IN ITS\nLIQUID FORM.");
	
	LogDisplayUI::Initialise();
	LogDisplayUI::AddEntry("12:22", "ERROR", "Log Disabled.");

	// TODO Allow regular shutdown via process signal
	while (true)
	{
		X17::Run();
	}
	
	ArmDisplayUI::DeInitialise();
	
	// --------------------------------------------------------

	return 0;
}