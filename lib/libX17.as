// -----------------------------------------------------------------------------
// libX17.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// This program will print a message to the Launcher debugging console
//
// To get started with nandOS development, check:
// - https://3001sq.net/forums/#/categories/hello-world (Beginners Forum)
// - https://github.com/3001SQ                          (Code Examples)
//

// nandOS binary API
#include "stdio.h"
#include "time.h"
#include "fcntl.h"

// -----------------------------------------------------------------------------

/** 
	The X17 namespace bundles User Interface utilites for Bitmap Mode and comes
    with some hardware parameter data like display layouts

	- Being a namespace, X17 acts as a pseudo-singleton and should have exclusive
	  access to the video device per application if used to manage Bitmap Mode
	- If the application also supports text mode, DeInitialise() should be called before mode change
	- functions/properties starting with "_" should NOT be used from outside
	- Initialise() and similar functions should be called ONLY ONCE during the application
	- WARNING The rendering order is not well organized, basically: background - text - user elements
*/
namespace X17 {
// -------------------------------------------------------------------
// -------------------------------------------------------------------

// ---------------------------------------------------------
// Debugging
// ---------------------------------------------------------

/** Log various actions regarding UI object management, drawing, etc */
bool bDebug = false;

void logDebug(string message)
{
	if (bDebug)
	{
		log("(X17) " + message);
	}
}

// ---------------------------------------------------------
// Displays (firmware properties)
// ---------------------------------------------------------

enum DisplayId
{
	Display_INVALID = -1,
	// ---
	Display_Terminal = 0,
	Display_Arm,
	Display_DashboardLeft,
	Display_DashboardCenter,
	Display_DashboardRight,
	Display_Container,
	Display_Log,
	Display_Overhead,
	Display_Door,
	// ---
	Display_COUNT
}

class DisplayProperties
{
	/** Width of a perceived unit rectangle if height is 1.0 */
	float aspectRatio = 1.f;

	DisplayProperties() {}
	
	DisplayProperties(float ratio)
	{
		aspectRatio = ratio;
	}
}

vector<DisplayProperties> Displays =
{
	DisplayProperties(1.077586),
	DisplayProperties(1.324324),
	DisplayProperties(0.448980),
	DisplayProperties(0.448980),
	DisplayProperties(0.448980),
	DisplayProperties(1.655405),
	DisplayProperties(0.418367),
	DisplayProperties(3.829787),
	DisplayProperties(1.297858),
	// ---
	DisplayProperties(-1.0)
};

// ---------------------------------------------------------
// Fonts (firmware properties)
// ---------------------------------------------------------

// NOTE Right now all fonts are monospace

enum Font
{
	Font_Terminal = 0,
	Font_System,
	Font_SystemBold
}

class FontProperties
{
	/** Width of a character if height is 1.0, take display aspect ratio into account for size calculations */
	float characterWidth = 1.f;
	
	FontProperties() {}
	
	FontProperties(float width)
	{
		characterWidth = width;
	}
}

vector<FontProperties> Fonts = 
{
	FontProperties(0.4521),				// Terminal
	FontProperties(0.48630136986),		// System
	FontProperties(0.48630136986)		// SystemBold
};

// ---------------------------------------------------------
// Base class for drawable User Interface elements
// ---------------------------------------------------------

abstract class Drawable
{
	// NOTE The display is set ONCE after creation of the element
	protected int m_DisplayId;

	/** Positions are relative to the lower left corner within unit square [0, 1]^2 */
	protected vec2 m_Position = vec2(0, 0);

	protected float m_Alpha = 1.0;
	
	protected bool m_bVisible = false;
	
	// -------------------------------------------

	int GetDisplayId() const
	{
		return m_DisplayId;
	}
	
	void SetPosition(vec2 position)
	{
		m_Position = position;
	}
	
	vec2 GetPosition() const
	{
		return m_Position;
	}
	
	void SetAlpha(float alpha)
	{
		m_Alpha = alpha;
		
		RequestDraw(m_DisplayId);
	}
	
	float GetAlpha() const
	{
		return m_Alpha;
	}
	
	void SetVisible(bool bVisible)
	{
		m_bVisible = bVisible;
		
		RequestDraw(m_DisplayId);
	}
	
	bool IsVisible() const
	{
		return m_bVisible;
	}
	
	// -------------------------------------------
	
	// NOTE This should ALWAYS be implemented by the actual class
	vec2 GetDimensions() const { return vec2(1.0, 1.0); }
	
	// NOTE This should ALWAYS be implemented by the actual class
	void Draw() { logDebug("Draw() not implemented by UI object!"); }
}

// ---------------------------------------------------------
// Bitmap (read-only on firmware)
// ---------------------------------------------------------

class Bitmap : Drawable
{
	/** ID of the bitmap on the video device (read-only on firmware) */
	private int m_BitmapObject = 0;
	
	/** Source rectangle (for sprite sheets, etc) */
	private vec4 m_SourceRect;
	
	/** Destination rectangle (for output) */
	private vec4 m_DestinationRect;
	
	// -------------------------------------------
	
	Bitmap()
	{
		logDebug("Constructing empty bitmap");
	}
	
	Bitmap(int displayId, int bitmapId)
	{
		logDebug("Constructing bitmap from " + bitmapId + "  for display " + displayId);
	
		if (displayId > 0 && displayId < Display_COUNT)
		{
			m_DisplayId = displayId;
			RequestDraw(m_DisplayId);
		}

		if (bitmapId > 0)
		{
			m_BitmapObject = bitmapId;
		}
	}

	void SetRect(vec4 srcRect, vec4 destRect)
	{
		m_SourceRect =  srcRect;
		m_DestinationRect = destRect;
	}
	
	// -------------------------------------------
	
	vec2 GetDimensions() const override
	{
		return vec2(m_DestinationRect.z, m_DestinationRect.w);
	}
	
	vec2 GetPosition() const override
	{
		return vec2(m_DestinationRect.x, m_DestinationRect.y);
	}
	
	void SetPosition(vec2 position)
	{
		m_DestinationRect.x  = position.x;
		m_DestinationRect.y  = position.y;
	}
	
	void Draw() override
	{
		logDebug("Drawing bitmap " + m_BitmapObject + " on " + m_DisplayId);

		vector<var> controlDrawBitmap =
		{
			Control_Video_DrawTexture,
			m_DisplayId,
			m_BitmapObject,
			m_SourceRect,
			m_DestinationRect,
			m_Alpha
		};
		write(_hwData.fdVideo, controlDrawBitmap);
	}
}

// ---------------------------------------------------------

/** Create a bitmap */
Bitmap@ CreateBitmap(int displayId, int bitmapId)
{
	logDebug("Creating bitmap");

	Bitmap b(displayId, bitmapId);
	
	// We assume that we always want to redraw after adding a bitmap, even if it's hidden in the end
	RequestDraw(displayId);	// Request X17 redraw
	
	return @b;
}

// ---------------------------------------------------------
// Text label
// ---------------------------------------------------------

class TextLabel : Drawable
{
	/** ID of the text object on the video device */
	private int m_TextObject = 0;
	
	/** Whether the static content of text was updated (text / style) */
	private bool m_bStaticUpdate = true;
	
	/** Text to display */
	private string m_Text;

	int m_Font;
	float m_FontHeight;
	
	private int m_ForegroundColour;
	private int m_BackgroundColour;
	
	// -------------------------------------------
	
	TextLabel()
	{
		logDebug("Constructing empty text label");
	}
	
	TextLabel(int displayId)
	{
		logDebug("Constructing text label for display " + displayId);
	
		if (displayId > 0 && displayId < Display_COUNT)
		{
			m_DisplayId = displayId;
			RequestDraw(m_DisplayId);
		}

		int textId = _hwData.nextTextId++;
			
		vector<var> controlCreateText =
		{
			Control_Video_CreateText,
			textId
		};
		write(_hwData.fdVideo, controlCreateText);			
			
		m_TextObject = textId;
			
		logDebug("Created text object " + textId);
	}
	
	// -------------------------------------------
	
	void SetText(string text)
	{
		m_Text = text;
		m_bStaticUpdate = true;
		
		RequestDraw(m_DisplayId);
	}
	
	void SetStyle(int font, float fontHeight, int fg, int bg)
	{
		m_Font = font;
		m_FontHeight = fontHeight;
		m_ForegroundColour = fg;
		m_BackgroundColour = bg;
		m_bStaticUpdate = true;
		
		RequestDraw(m_DisplayId);
	}

	// -------------------------------------------
	
	vec2 GetDimensions() const override
	{
		return 0.01 * m_FontHeight * vec2(
			m_Text.size() * Fonts[m_Font].characterWidth / Displays[m_DisplayId].aspectRatio, 1.0);
	}
	
	void Draw() override
	{
		logDebug("Drawing text label " + m_TextObject + " '" + m_Text + "' on " + m_DisplayId);
		
		if (m_bStaticUpdate)
		{
			logDebug("  Static update");
		
			vector<var> controlUpdateText =
			{
				Control_Video_UpdateText,
				m_TextObject,
				m_Text,
				m_Font,
				m_ForegroundColour,
				m_BackgroundColour
			};
			write(_hwData.fdVideo, controlUpdateText);
			
			m_bStaticUpdate = false;
		}
		
		vector<var> controlDrawText =
		{
			Control_Video_DrawText,
			m_TextObject,
			m_DisplayId,
			m_Position,
			m_FontHeight,
			m_Alpha
		};
		write(_hwData.fdVideo, controlDrawText);
	}
}

// ---------------------------------------------------------

/** NOTE We can NOT remove text labels yet, simply hide them if no longer needed */
TextLabel@ CreateTextLabel(int displayId)
{
	logDebug("Creating text label (count: " + _drawableData.textLabels.size() + ")");

	_drawableData.textLabels.push_back(TextLabel(displayId));
	
	// We assume that we always want to redraw after adding a text label, even if it's hidden in the end
	RequestDraw(displayId);	// Request X17 redraw
	
	return @_drawableData.textLabels[_drawableData.textLabels.size() - 1];
}

// ---------------------------------------------------------
// Text area
// ---------------------------------------------------------

// TODO: Positions should be relative to bottom left, not bottom left of first line

class TextArea : Drawable
{
	/** NOTE The number of managed text objects may grow with parsing '\n' */
	private vector<int> m_TextObjects;
	
	/** Whether the static content of text was updated (text / style) */
	private bool m_bStaticUpdate = true;
	
	/** Text to display */
	private vector<var> m_TextLines;
	
	uint m_ActiveTextLines = 0;
	
	/** Columns per line */
	private size_t m_MaxColumns = string::npos;

	int m_Font;
	float m_FontHeight;
	
	/** Factor to move next line down */
	float m_FontSpacing;
	
	private int m_ForegroundColour;
	private int m_BackgroundColour;
	
	// -------------------------------------------
	
	// WORKAROUND Keep ID until we have proper object-handle support for container types
	uint m_Id;

	// -------------------------------------------
	
	TextArea()
	{
		logDebug("Constructing empty text area");
	}
	
	TextArea(int displayId)
	{
		logDebug("Constructing text area for display " + displayId);
	
		if (displayId > 0 && displayId < Display_COUNT)
		{
			m_DisplayId = displayId;
			RequestDraw(m_DisplayId);
		}
	}
	
	// -------------------------------------------
	
	private void _addLine(uint line, string text)
	{
		if (line == m_TextLines.size())
		{
			// Request creation of text
			
			int textId = _hwData.nextTextId++;
			
			vector<var> controlCreateText =
			{
				Control_Video_CreateText,
				textId
			};
			write(_hwData.fdVideo, controlCreateText);			
			
			m_TextObjects.push_back(textId);
			m_TextLines.push_back(text);
			
			logDebug("Created text object " + textId);
		}
		else
		{
			m_TextLines[line] = text;
		}
	}
	
	void SetText(string text, size_t maxColumns = 0)
	{
		m_bStaticUpdate = true;
		
		if (maxColumns > 0)
		{
			m_MaxColumns = maxColumns;
		}
		else
		{
			m_MaxColumns = string::npos;
		}
		
		RequestDraw(m_DisplayId);
		
		m_ActiveTextLines = 0;
		size_t startPos = 0;
		size_t endPos = text.find("\n");
		// Cut-off due to column limit
		bool bLineBreak = false;		
		if (endPos - startPos > m_MaxColumns)
		{
			endPos = startPos + m_MaxColumns;
		}
		
		while (endPos != string::npos)
		{
			_addLine(m_ActiveTextLines, text.substr(startPos, endPos - startPos));
			m_ActiveTextLines++;
			if (bLineBreak)
			{
				startPos = endPos;
				bLineBreak = false;
			}
			else
			{
				startPos = endPos + 1;
			}
			endPos = text.find("\n", startPos);
			// Cut-off due to column limit
			if (endPos - startPos > m_MaxColumns)
			{
				if (endPos == string::npos && !bLineBreak)
				{
					break;
				}
				bLineBreak = true;
				endPos = startPos + m_MaxColumns;
			}
		}

		endPos = text.size();
		while (startPos < text.size())
		{
			if (endPos - startPos > m_MaxColumns)
			{
				endPos = startPos + m_MaxColumns;
			}
			
			_addLine(m_ActiveTextLines, text.substr(startPos, endPos - startPos));
			m_ActiveTextLines++;
			
			startPos = endPos;
			endPos = text.size();
		}
	}
	
	void SetStyle(int font, float fontHeight, float fontSpacing, int fg, int bg)
	{
		m_Font = font;
		m_FontHeight = fontHeight;
		m_FontSpacing = fontSpacing;
		m_ForegroundColour = fg;
		m_BackgroundColour = bg;
		m_bStaticUpdate = true;
		
		RequestDraw(m_DisplayId);
	}
	
	// -------------------------------------------
	
	void Draw() override
	{
		logDebug("Drawing text area " + m_Id + " on " + m_DisplayId);
		
		if (m_bStaticUpdate)
		{
			logDebug("  Static update");
		
			for (uint iLine = 0; iLine < m_ActiveTextLines; iLine++)
			{
				vector<var> controlUpdateText =
				{
					Control_Video_UpdateText,
					m_TextObjects[iLine],
					m_TextLines[iLine],
					m_Font,
					m_ForegroundColour,
					m_BackgroundColour
				};
				write(_hwData.fdVideo, controlUpdateText);
			}
			
			m_bStaticUpdate = false;
		}
		
		for (uint iLine = 0; iLine < m_ActiveTextLines; iLine++)
		{
			vector<var> controlDrawText =
			{
				Control_Video_DrawText,
				m_TextObjects[iLine],
				m_DisplayId,
				m_Position - vec2(0, 0.01 * iLine * m_FontHeight * m_FontSpacing),
				m_FontHeight,
				m_Alpha
			};
			write(_hwData.fdVideo, controlDrawText);
		}
	}
}

// ---------------------------------------------------------

/** NOTE We can NOT remove text areas yet, simply hide them if no longer needed */
TextArea@ CreateTextArea(int displayId)
{
	logDebug("Creating text area " + _drawableData.textAreas.size());

	_drawableData.textAreas.push_back(TextArea(displayId));
	
	// We assume that we always want to redraw after adding a text label, even if it's hidden in the end
	RequestDraw(displayId);	// Request X17 redraw
	
	uint id = _drawableData.textAreas.size() - 1;
	_drawableData.textAreas[id].m_Id = id;
	
	return @_drawableData.textAreas[id];
}

// ---------------------------------------------------------
// Button class = text label + background with states
// ---------------------------------------------------------

enum ButtonState
{
	Button_Normal = 0,			// The button is not selected
	Button_Selected,			// The button is selected, but focus is in another context
	Button_Hover,				// The button is selected in the current context
	Button_Active,				// The button is being pressed
	Button_Deactivated,			// The button is in the context but deactivated
	// ---
	Button_STATES
}

/** Set of text styles for button states */
class ButtonStyle
{
	vector<int> foregroundColour;
	vector<int> backgroundColour;
	
	int font;
	float fontHeight;
	
	// -------------------------------------------
	
	ButtonStyle()
	{
		for (uint iState = 0; iState < Button_STATES; iState++)
		{
			foregroundColour.push_back(Display_TextForeground_White);
			backgroundColour.push_back(Display_TextBackground_Default);
		}
	}
	
	ButtonStyle(int fontId, float height, int fg, int bg)
	{
		font = fontId;
		fontHeight = height;
	
		// Indexed by button states
		for (uint iState = 0; iState < Button_STATES; iState++)
		{
			foregroundColour.push_back(fg);
			backgroundColour.push_back(bg);
		}
	}
	
	void SetColours(int iState, int fg, int bg)
	{
		if (iState >= 0 && iState < Button_STATES)
		{
			foregroundColour[iState] = fg;
			backgroundColour[iState] = bg;
		}
	}
}

ButtonStyle DefaultButtonStyle;

void _prepareButton()
{
	DefaultButtonStyle = ButtonStyle(Font_System, 5,
		Display_TextForeground_White, Display_TextBackground_Default);
}


class Button : Drawable
{
	/** IDs of text objects on the video device */
	private vector<int> m_TextObject;
	
	/** Whether the static content of the button was updated (text / style) */
	private bool m_bStaticUpdate = true;

	/** Handle to the button style */
	private ButtonStyle@ m_Style;
	
	/** State of the button */
	private ButtonState m_State = Button_Normal;
	
	/** Text to display */
	private string m_Text;
	
	// -------------------------------------------
	
	// WORKAROUND Keep ID until we have proper object-handle support for container types
	uint m_Id;
	
	// -------------------------------------------

	Button()
	{
		logDebug("Constructing empty button");
	
		for (uint iState = 0; iState < Button_STATES; iState++)
		{
			// The default constructor does NOT reserve text objects yet
			m_TextObject.push_back(0);
		}
	}
	
	Button(int displayId)
	{
		logDebug("Constructing button for display " + displayId);
	
		if (displayId > 0 && displayId < Display_COUNT)
		{
			m_DisplayId = displayId;
			RequestDraw(m_DisplayId);
		}
	
		@m_Style = @DefaultButtonStyle;
	
		// Reserve text objects
		for (uint iState = 0; iState < Button_STATES; iState++)
		{
			int textId = _hwData.nextTextId++;
			
			vector<var> controlCreateText =
			{
				Control_Video_CreateText,
				textId
			};
			write(_hwData.fdVideo, controlCreateText);			
			
			m_TextObject.push_back(textId);
			
			logDebug("Created text object " + textId);
		}
	}
	
	~Button()
	{
		// WARNING Hardware text resources are centrally released on DeInitialise()
		//         NEVER perform hardware interaction in destructors as order ill-defined
	}
	
	// -------------------------------------------
	
	void SetStyle(ButtonStyle@ style)
	{
		@m_Style = style;
		m_bStaticUpdate = true;
		
		RequestDraw(m_DisplayId);
	}
	
	void SetText(string text)
	{
		m_Text = text;
		m_bStaticUpdate = true;
		
		RequestDraw(m_DisplayId);
	}
	
	ButtonState GetState() const
	{
		return m_State;
	}
	
	void SetState(ButtonState state)
	{
		m_State = state;
		
		RequestDraw(m_DisplayId);
	}
	
	// -------------------------------------------
	
	vec2 GetDimensions() const override
	{
		return 0.01 * m_Style.fontHeight * vec2(
			m_Text.size() * Fonts[m_Style.font].characterWidth / Displays[m_DisplayId].aspectRatio, 1.0);
	}

	void Draw() override
	{
		logDebug("Drawing button " + m_TextObject[m_State] + " '" + m_Text + "' on " + m_DisplayId);
		
		if (m_bStaticUpdate)
		{
			logDebug("  Static update");
		
			for (uint iState = 0; iState < Button_STATES; iState++)
			{
				vector<var> controlUpdateText =
				{
					Control_Video_UpdateText,
					m_TextObject[iState],
					m_Text,
					m_Style.font,
					m_Style.foregroundColour[iState],
					m_Style.backgroundColour[iState]
				};
				write(_hwData.fdVideo, controlUpdateText);
			}
			
			m_bStaticUpdate = false;
		}
		
		vector<var> controlDrawText =
		{
			Control_Video_DrawText,
			m_TextObject[m_State],
			m_DisplayId,
			m_Position,
			m_Style.fontHeight,
			m_Alpha
		};
		write(_hwData.fdVideo, controlDrawText);
	}
}

// ---------------------------------------------------------

/** NOTE We can NOT remove buttons yet, simply hide them if no longer needed */
Button@ CreateButton(int displayId)
{
	logDebug("Creating button " + _drawableData.buttons.size());

	_drawableData.buttons.push_back(Button(displayId));
	
	// We assume that we always want to redraw after adding a button, even if it's hidden in the end
	RequestDraw(displayId);	// Request X17 redraw
	
	uint id = _drawableData.buttons.size() - 1;
	_drawableData.buttons[id].m_Id = id;
	
	return @_drawableData.buttons[id];
}

Button@ GetButton(uint buttonId)
{
	if (buttonId < _drawableData.buttons.size())
	{
		return @_drawableData.buttons[buttonId];
	}
	else
	{
		return null;
	}	
}

// ---------------------------------------------------------
// Menu container for buttons
// ---------------------------------------------------------

/** Convenience class to control the drawing style of a group of buttons */
class Menu
{
	/** Currently selected index */
	private uint m_ActiveIndex = 0;
	
	/** FIXME Probably change to object-handles when container types support them */
	private vector<uint> m_ButtonIds;
	
	/** Whether the button is enabled/used */
	private vector<bool> m_ButtonActive;
	
	/** Whether the menu is selected and can be navigated */
	private bool m_bActive = false;
	
	// -------------------------------------------
	
	uint GetIndex() const
	{
		return m_ActiveIndex;
	}

	Button@ GetButton(uint idx)
	{
		return @_drawableData.buttons[m_ButtonIds[idx]];
	}
	
	void ButtonPressed(bool bDown)
	{
		if (m_bActive)
		{
			GetButton(m_ActiveIndex).SetState(bDown ? Button_Active : Button_Hover);
		}
	}
	
	void Select(uint idx)
	{
		if (idx >= m_ButtonIds.size())
		{
			return;
		}
	
		// Unselect previous index
		GetButton(m_ActiveIndex).SetState(IsButtonActive(m_ActiveIndex) ? Button_Normal : Button_Deactivated);
		
		m_ActiveIndex = idx;
		
		// Select new index
		GetButton(m_ActiveIndex).SetState(m_bActive ? Button_Hover : Button_Selected);
	}

	void SelectPrevious()
	{
		if (m_ActiveIndex > 0)
		{
			// Find previous active button
			uint previousActive = m_ActiveIndex - 1;
			while (previousActive != 0 &&
				!m_ButtonActive[previousActive])
			{
				previousActive--;
			}
		
			if (m_ButtonActive[previousActive])
			{
				Select(previousActive);
			}
		}
	}
	
	void SelectNext()
	{
		if (m_ActiveIndex < (m_ButtonIds.size() - 1))
		{
			// Find next active button
			uint nextActive = m_ActiveIndex + 1;
			while (nextActive != (m_ButtonIds.size() - 1) &&
				!m_ButtonActive[nextActive])
			{
				nextActive--;
			}
		
			if (m_ButtonActive[nextActive])
			{
				Select(nextActive);
			}
		}
	}
	
	void ResetButtons(uint count)
	{
		m_ButtonIds.clear();
		m_ButtonActive.clear();
		
		for (uint iButton = 0; iButton < count; iButton++)
		{
			m_ButtonIds.push_back(0);
			m_ButtonActive.push_back(false);
		}
		
		m_ActiveIndex = 0;
	}
	
	/** Set up a button that was allocated by ResetButtons(), active by default */
	void SetButton(uint idx, uint buttonId, bool bActive = true)
	{
		if (idx >= m_ButtonIds.size())
		{
			log("Menu button out of range! " + idx + " / " + m_ButtonIds.size());
			return;
		}

		m_ButtonIds[idx] = buttonId;
		SetButtonActive(idx, bActive);
		
		/*if (idx == 0)
		{
			// We assume the first item has the focus
			GetButton(0).SetState(m_bActive ? Button_Hover : Button_Selected);
			m_ActiveIndex = 0;
		}*/
	}
	
	void SetButtonActive(uint idx, bool bActive)
	{
		if (idx < m_ButtonActive.size())
		{
			m_ButtonActive[idx] = bActive;
			GetButton(idx).SetState(bActive ? Button_Normal : Button_Deactivated);
		}
	}

	bool IsButtonActive(uint idx) const
	{
		if (idx < m_ButtonActive.size())
		{
			return m_ButtonActive[idx];
		}
		
		return false;
	}
	
	bool HasActiveButtons() const
	{
		for (uint iButton = 0; iButton < m_ButtonActive.size(); iButton++)
		{
			if (m_ButtonActive[iButton])
			{
				return true;
			}
		}
		
		return false;
	}
	
	void SetActive(bool bActive)
	{
		m_bActive = bActive;
		
		GetButton(m_ActiveIndex).SetState(m_bActive ? Button_Hover : Button_Selected);
	}
	
	bool IsActive() const
	{
		return m_bActive;
	}
	
	void SetVisible(bool bVisible)
	{
		// Toggle visibility of all buttons registered with this menu
		for (uint iButton = 0; iButton < m_ButtonIds.size(); iButton++)
		{
			GetButton(iButton).SetVisible(bVisible);
		}
	}
}

// ---------------------------------------------------------
// INTERNAL containers, use functions for access instead
// ---------------------------------------------------------

class HardwareData
{
	/** The video device may control multiple displays */
	int fdVideo = -1;
	
	/** Optional event devices */
	vector<int> fdsEvent;
	
	/** Next unallocated text id TODO re-use after deletion */
	int nextTextId = 1;
}

HardwareData _hwData;

int GetVideoFileDescriptor()
{
	return _hwData.fdVideo;
}

class DrawableData
{
	// WARNING We don't have a general-purpose map/dictionary container yet,
	//         so text labels are simply added to a steadily growing vector
	//         and can NOT be removed after creation - set visible to false for now
	vector<TextLabel> textLabels;
	
	// WARNING We don't have a general-purpose map/dictionary container yet,
	//         so text areas are simply added to a steadily growing vector
	//         and can NOT be removed after creation - set visible to false for now
	vector<TextArea> textAreas;

	// WARNING We don't have a general-purpose map/dictionary container yet,
	//         so buttons are simply added to a steadily growing vector
	//         and can NOT be removed after creation - set visible to false for now
	vector<Button> buttons;
	
	// FIXME Add object handle support to container type
	//vector<Drawable@> drawable;
	
	/** Background colours of available displays, used when no background texture specified */
	vector<int> backgroundColour;
	
	/** Background textures of available displays, leave -1 to leave disabled */
	vector<int> backgroundTexture;
}

DrawableData _drawableData;

void _prepareDrawableData()
{
	// Set up default display backgrounds
	
	for (uint iDisplay = 0; iDisplay < Display_COUNT; iDisplay++)
	{
		_drawableData.backgroundColour.push_back(Display_TextBackground_Black);
		_drawableData.backgroundTexture.push_back(-1);
	}
}

// ---------------------------------------------------------

void SetBackgroundColour(int displayId, int bg)
{
	if (displayId > 0 && displayId < Display_COUNT)
	{
		_drawableData.backgroundColour[displayId] = bg;
		RequestDraw(displayId);
	}
}

void SetBackgroundTexture(int displayId, int textureId)
{
	if (displayId > 0 && displayId < Display_COUNT)
	{
		_drawableData.backgroundTexture[displayId] = textureId;
		RequestDraw(displayId);
	}
}

// ---------------------------------------------------------
// X17 Core loop
// ---------------------------------------------------------

void Run()
{
	// -------------------------------------------
	
	_readEvents();

	if (_eventCallback !is null)
	{
		_eventCallback(_keyEvents);
	}
	
	// Clear any leftover events from last loop
	_keyEvents.clear();

	// -------------------------------------------
	
	_draw();
	
	if (_drawCallback !is null)
	{
		_drawCallback();	// May call additional RequestDraw()
	}
	
	// -------------------------------------------
	
	_swapBuffers();
	
	// -------------------------------------------
	
	// Perform other logic stuff
	
	if (_postDrawCallback !is null)
	{
		_postDrawCallback();
	}
}

// ---------------------------------------------------------

vector<bool> _redrawRequested;

/** Applications should use this to require explicit redraw in the draw callback */
void RequestDraw(int displayId)
{
	if (displayId > 0 && displayId < Display_COUNT)
	{
		logDebug("RequestDraw: " + displayId);
		_redrawRequested[displayId] = true;
	}
}

// ---------------------------------------------------------

// User application callbacks that may be plugged into Run()

funcdef void EVENTCALLBACK(vector<KeyEvent> &in);
funcdef void DRAWCALLBACK(void);

EVENTCALLBACK@ _eventCallback;
DRAWCALLBACK@ _drawCallback;
DRAWCALLBACK@ _postDrawCallback;

void SetEventCallback(EVENTCALLBACK@ f)
{
	@_eventCallback = f;
}

void SetDrawCallback(DRAWCALLBACK@ f)
{
	@_drawCallback = f;
}

void SetPostDrawCallback(DRAWCALLBACK@ f)
{
	@_postDrawCallback = f;
}

// ---------------------------------------------------------

// So far we support two types of events:
//
// - Special keys with states up/down
// - Printable characters directly scanned from the keyboard
//
// TODO 
// - Low-level access of all keys via code
//

enum KeyEventType
{
	KeyEvent_Pressed,
	KeyEvent_CharacterInput
}

class KeyEvent
{
	KeyEventType type;
	
	// Id of the device the event is coming from
	int device;
	
	// Pressed
	int keyCode;
	bool bDown;		// true if key pressed, false if released
	
	// CharacterInput
	string scannedCharacter;
}

vector<KeyEvent> _keyEvents;

void _readEvents()
{
	// logDebug("read Events");

	for (uint iDevice = 0; iDevice < _hwData.fdsEvent.size(); iDevice++)
	{
		// logDebug("Device: " + iDevice + " " + _hwData.fdsEvent[iDevice]);
	
		vector<var> dataIn;
		ssize_t r  = read(_hwData.fdsEvent[iDevice], dataIn, 32);
		
		if (r == -1)
		{
			// -1 for non-blocking devices indicates there is no data to read
			continue;
		}
		
		int interruptCode = int(dataIn[0]);
		
		if (interruptCode == Interrupt_Keyboard_Key)
		{
			KeyEvent ev;
			
			ev.type = KeyEvent_Pressed;
			ev.device = int(iDevice);
			ev.keyCode = int(dataIn[1]);
			ev.bDown = int(dataIn[2]) == 1;
			
			_keyEvents.push_back(ev);
			
			logDebug("Key Pressed: " + ev.keyCode + " " + ev.bDown + " - " + ev.device);
		}
		else if (interruptCode == Interrupt_Keyboard_Character)
		{
			KeyEvent ev;
			
			ev.type = KeyEvent_CharacterInput;
			ev.device = int(iDevice);
			ev.scannedCharacter = string(dataIn[1]);
			
			_keyEvents.push_back(ev);
			
			logDebug("Character scanned: " + ev.scannedCharacter + " - " + ev.device);
		}
	}
}

// ---------------------------------------------------------

void _draw()
{
	// -------------------------------------------
	// Background
	// -------------------------------------------

	for (uint iDisplay = 0; iDisplay < Display_COUNT; iDisplay++)
	{
		if (!_redrawRequested[iDisplay])
		{
			continue;
		}
	
		if (_drawableData.backgroundTexture[iDisplay] != -1)
		{
			// Use background texture
			
			logDebug("Draw background texture: " + iDisplay + " " + 
				_drawableData.backgroundTexture[iDisplay]);
			
			vector<var> controlDrawTexture = 
			{
				Control_Video_DrawTexture,
				iDisplay,
				_drawableData.backgroundTexture[iDisplay],
				vec4(0, 0, 1, 1)
			};
			write(_hwData.fdVideo, controlDrawTexture);
		}
		else
		{
			// Use background colour
			
			logDebug("Draw background colour: " + iDisplay + " " +
				_drawableData.backgroundColour[iDisplay]);
			
			vector<var> controlClearColour = 
			{
				Control_Video_Clear,
				iDisplay,
				_drawableData.backgroundColour[iDisplay]
			};
			write(_hwData.fdVideo, controlClearColour);
		}
		
		// General draw commands processed
	}
	
	// -------------------------------------------
	// Buttons
	// -------------------------------------------
	
	for (uint iButton = 0; iButton < _drawableData.buttons.size(); iButton++)
	{
		Button@ button = @_drawableData.buttons[iButton];
		
		if (_redrawRequested[button.GetDisplayId()] && button.IsVisible())
		{
			button.Draw();
		}
	}
	
	// -------------------------------------------
	// Text labels
	// -------------------------------------------
	
	for (uint iTextLabel = 0; iTextLabel < _drawableData.textLabels.size(); iTextLabel++)
	{
		TextLabel@ textLabel = @_drawableData.textLabels[iTextLabel];
		
		if (_redrawRequested[textLabel.GetDisplayId()] && textLabel.IsVisible())
		{
			textLabel.Draw();
		}
	}
	
	// -------------------------------------------
	// Text areas
	// -------------------------------------------
	
	for (uint iTextArea = 0; iTextArea < _drawableData.textAreas.size(); iTextArea++)
	{
		TextArea@ textArea = @_drawableData.textAreas[iTextArea];
		
		if (_redrawRequested[textArea.GetDisplayId()] && textArea.IsVisible())
		{
			textArea.Draw();
		}
	}
}

void ForceSwapBuffers(int displayId)
{
	vector<var> controlSwapBuffers =
	{
		Control_Video_SwapBuffers,
		displayId
	};
	write(_hwData.fdVideo, controlSwapBuffers);
}

void _swapBuffers()
{
	for (uint iDisplay = 0; iDisplay < Display_COUNT; iDisplay++)
	{
		if (_redrawRequested[iDisplay])
		{
			logDebug("Swapping buffers for display " + iDisplay);
		
			vector<var> controlSwapBuffers =
			{
				Control_Video_SwapBuffers,
				iDisplay
			};
			write(_hwData.fdVideo, controlSwapBuffers);

			// The display was redrawn for this run of the loop
			_redrawRequested[iDisplay] = false;
		}
	}
}

// ---------------------------------------------------------
// X17 Basic initialisation/deinitialisation
// ---------------------------------------------------------

bool _prepareVideo(string videoPath)
{
	_hwData.fdVideo = open(videoPath, O_WRONLY);
	
	if (_hwData.fdVideo != -1)
	{
		return true;
	}
	else
	{
		logDebug("Failed to open " + videoPath);
		return false;
	}
}

void _prepareObjects()
{
	for (uint iDisplay = 0; iDisplay < Display_COUNT; iDisplay++)
	{
		_redrawRequested.push_back(false);
	}

	_prepareButton();
	
	_prepareDrawableData();
}

// ---------------------------------------------------------

/** We need at least a video device, optionally an array of event devices (keyboards, etc) */
bool Initialise(string videoPath)
{
	logDebug("Initialising X17 using " + videoPath);

	if (!_prepareVideo(videoPath))
	{
		return false;
	}
	
	_prepareObjects();
	
	return true;
}

/** We need at least a video device, optionall event devices (keyboards, etc)
	By default, no display is overwritten, create UI elements or call RequestDraw(displayId) for background */
bool Initialise(string videoPath, vector<var> &in eventPaths)
{
	logDebug("Initialising X17 using " + videoPath + " and " + eventPaths.size() + " event devices");

	if (!_prepareVideo(videoPath))
	{
		return false;
	}
	
	for (uint iEvent = 0; iEvent < eventPaths.size(); iEvent++)
	{
		int fdEvent = open(string(eventPaths[iEvent]), O_RDONLY);
		
		if (fdEvent != -1)
		{
			// Open in non-blocking mode so we can extract events in the main loop
			int fdMode = fcntl(fdEvent, F_GETFL);
			fcntl(fdEvent, F_SETFL, fdMode | O_NONBLOCK);
		
			logDebug("Initialised " + string(eventPaths[iEvent]) + " with fd " + fdEvent);
		
			_hwData.fdsEvent.push_back(fdEvent);
		}
		else
		{
			logDebug("Failed to open " + string(eventPaths[iEvent]));
			DeInitialise();
			return false;
		}
	}
	
	_prepareObjects();
	
	return true;
}

/** Close devices we used for the UI */
void DeInitialise()
{
	logDebug("DeInitialising X17");

	// WARNING Some objects may reference resources of the video device,
	//         make sure the release functions are called before losing the file descriptor
	
	_drawableData.textLabels.clear();
	_drawableData.buttons.clear();
	
	// FIXME Wait a bit before releasing hardware resources as some control messages may have
	//       been dispatched in this UPCI cycle already
	usleep(50000);
	
	// FIXME We simply assume that all text objects are still in use
	for (int iText = 1; iText < _hwData.nextTextId; iText++)
	{
		logDebug("Delete text " + iText);
	
		vector<var> controlDeleteText =
		{
			Control_Video_DeleteText,
			iText
		};
		write(_hwData.fdVideo, controlDeleteText);
	}
	
	if (_hwData.fdVideo != -1)
	{
		close(_hwData.fdVideo);
	}
	
	for (uint iEvent = 0; iEvent < _hwData.fdsEvent.size(); iEvent++)
	{
		if (_hwData.fdsEvent[iEvent] != -1)
		{
			close(_hwData.fdsEvent[iEvent]);
		}
	}
	
	@_eventCallback = null;
	@_drawCallback = null;
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}
