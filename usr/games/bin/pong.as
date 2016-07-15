// -----------------------------------------------------------------------------
// pong.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS binary interface
#include "unistd.h"
#include "fcntl.h"
#include "time.h"
#include "stdlib.h"

// -----------------------------------------------------------------------------

// Framerate in microseconds
const uint64 frametimeUs = 50000;

enum PaddleMovement
{
	Paddle_Up = 0,
	Paddle_Still,
	Paddle_Down
}

class Ball
{	
	private uint m_Column;
	private uint m_Line;
	private uint m_ColumnDrawn = 0;
	private uint m_LineDrawn = 0;
	
	private int m_fdVideo;
	private int m_DisplayId;

	private bool m_bLeft = true;	
	private bool m_bUp = true;
	
	// --------------------------------------------------------

	Ball() {}
	
	Ball(uint column, uint line, bool bLeft, bool bUp, int fdVideo, int displayId)
	{
		m_Column = column;
		m_Line = line;

		m_bUp = bUp;
		m_bLeft = bLeft;
		
		m_fdVideo = fdVideo;
		m_DisplayId = displayId;
	}
	
	uint GetColumn() const
	{
		return m_Column;
	}
	
	uint GetLine() const
	{
		return m_Line;
	}
	
	void SetColumn(uint column)
	{
		m_Column = column;
	}
	
	void SetLine(uint line)
	{
		m_Line = line;
	}
	
	bool IsMovingLeft() const
	{
		return m_bLeft;
	}
	
	bool IsMovingUp() const
	{
		return m_bUp;
	}
	
	void SetMovementX(bool bLeft)
	{
		m_bLeft = bLeft;
	}
	
	void SetMovementY(bool bUp)
	{
		m_bUp = bUp;
	}
	
	void Update(float timeMs)
	{
		// TODO Fine-grained movement when we can normalize the framerate
		// NOTE the game loop assures that we are within bounds
		m_Column += m_bLeft ? -1 : 1;
		m_Line += m_bUp ? -1 : 1;
	}
	
	void Draw()
	{
		vector<var> controlClear = { Control_Video_SetCharacter, m_DisplayId, 
				" ", m_ColumnDrawn, m_LineDrawn,
				Display_TextForeground_Default,
				Display_TextBackground_Black,
				Display_TextAttribute_Normal
			};
		write(m_fdVideo, controlClear);
		m_ColumnDrawn = m_Column;
		m_LineDrawn = m_Line;
	
		vector<var> controlBall = { Control_Video_SetCharacter, m_DisplayId, 
				" ", m_Column, m_Line,
				Display_TextForeground_Default,
				Display_TextBackground_Yellow,
				Display_TextAttribute_Normal
			};
		write(m_fdVideo, controlBall);
	}
}

class Paddle
{
	private int m_Background;
	private uint m_Column;
	// TODO Calculate speed
	private uint m_CenterLine;

	private int m_fdVideo;
	private int m_DisplayId;
	private uint m_DisplayLines;
	
	private float m_UnitHeight;		// Height of center in 0.0 - 1.0
	private PaddleMovement m_Movement = Paddle_Still;

	// --------------------------------------------------------

	Paddle() {}
	
	Paddle(int background, uint column, uint centerLine, uint displayLines, int fdVideo, int displayId)
	{
		m_Background = background;
		m_Column = column;
		m_CenterLine = centerLine;

		m_fdVideo = fdVideo;
		m_DisplayId = displayId;
		m_DisplayLines = displayLines;
	}
	
	uint GetCenterLine() const
	{
		return m_CenterLine;
	}
	
	void SetCenterLine(uint line)
	{
		m_CenterLine = line;
	}
	
	void SetMovement(PaddleMovement movement)
	{
		m_Movement = movement;
	}
	
	void Update(float timeMs)
	{
		// TODO Fine-grained movement when we can normalize the framerate
		
		if (m_Movement == Paddle_Up)
		{
			if (m_CenterLine > 1)
			{
				m_CenterLine--;
			}
		}
		else if (m_Movement == Paddle_Down)
		{
			if (m_CenterLine < m_DisplayLines - 2)
			{
				m_CenterLine++;
			}			
		}
	}
	
	void Draw() const
	{
		// Calculate start and end range of paddle to avoid invalid coordinates at edges
		uint startLine = m_CenterLine > 0 ? m_CenterLine - 1 : 0;
		uint endLine = m_CenterLine < m_DisplayLines - 1 ? m_CenterLine + 1 : m_DisplayLines - 1;

		for (uint iLine = startLine; iLine <= endLine; iLine++)
		{
			vector<var> c = { Control_Video_SetCharacter, m_DisplayId, 
					" ", m_Column, iLine,
					Display_TextForeground_Default,
					m_Background,
					Display_TextAttribute_Normal
				};
			write(m_fdVideo, c);
		}
		
		// Clear border if required
		
		if (startLine > 0)
		{
			vector<var> c = { Control_Video_SetCharacter, m_DisplayId, 
					" ", m_Column, startLine - 1,
					Display_TextForeground_Default,
					Display_TextBackground_Black,
					Display_TextAttribute_Normal
				};
			write(m_fdVideo, c);
		}
		
		if (endLine < m_DisplayLines - 1)
		{
			vector<var> c = { Control_Video_SetCharacter, m_DisplayId, 
					" ", m_Column, endLine + 1,
					Display_TextForeground_Default,
					Display_TextBackground_Black,
					Display_TextAttribute_Normal
				};
			write(m_fdVideo, c);
		}
	}
}

class PongGame
{
	private int m_fdVideo = -1;
	private int m_fdAudio = -1;
	private int m_fdSidestick = -1;
	private int m_DisplayId = 1;

	// Display properties
	private uint m_Columns = 58;
	private uint m_Lines = 20;

	private Paddle m_PlayerPaddle;
	private Paddle m_ComputerPaddle;
	private Ball m_Ball;
	
	bool m_bShutdown = false;

	// --------------------------------------------------------

	void SoundBorder()
	{
		vector<var> controlPlay =
		{
			Control_Audio_Play,
			2
		};
		write(m_fdAudio, controlPlay);
	}
	
	void SoundPaddle()
	{
		vector<var> controlPlay =
		{
			Control_Audio_Play,
			1
		};
		write(m_fdAudio, controlPlay);
	}
	
	// Text menu rendering

	private void DrawMenuCharacter(string s, uint column, uint row, bool bBright)
	{
		for (uint iChar = 0;  iChar < s.size(); iChar++)
		{
			vector<var> c = { Control_Video_SetCharacter, m_DisplayId, 
				s[iChar], column + iChar, row,
				bBright ? Display_TextForeground_LightGray : Display_TextForeground_DarkGray,
				Display_TextBackground_Default,
				Display_TextAttribute_Normal
			};
			write(m_fdVideo, c);
		}
	}

	private void DrawMenu()
	{
		// FIXME No proper support for string character access yet, include in Build 0012

		uint column = m_Columns / 2 - 9;
		uint row = 14;
		string s = "Move left";
		DrawMenuCharacter(s, column, row, true);
		column += s.size() + 1;
		DrawMenuCharacter("to quit", column, row, false);
		column++;
		
		row++;
		column = m_Columns / 2 - 9;
		DrawMenuCharacter("Other", column, row, true);
		column += s.size() + 1;
		DrawMenuCharacter("to start", column, row, false);
	}

	// --------------------------------------------------------

	private void ResetScreen()
	{
		// NOTE Always clear characters first, then clear screen with colour
	
		vector<var> commandClearCharacters = { Control_Video_ClearCharacters, m_DisplayId };
		write(m_fdVideo, commandClearCharacters);

		vector<var> commandClear = { Control_Video_Clear, m_DisplayId, Display_TextBackground_Black };
		write(m_fdVideo, commandClear);
	
		m_PlayerPaddle.SetMovement(Paddle_Still);
		
		m_PlayerPaddle.SetCenterLine(m_Lines / 2);
		m_ComputerPaddle.SetCenterLine(m_Lines / 2);

		m_Ball.SetColumn(m_Columns / 2);
		m_Ball.SetLine(3 * m_Lines / 4 - (rand() % (m_Lines / 2)));
		m_Ball.SetMovementX(true);
		m_Ball.SetMovementY(rand() % 2 == 0);
	}
	
	private void Initialise()
	{
		m_fdVideo = open("/dev/iq0", O_WRONLY);
		
		m_fdAudio = open("/dev/audio", O_WRONLY);
		
		vector<var> controlMode = 
		{
			Control_Video_DisplayMode,
			m_DisplayId,
			Display_Mode_Text
		};
		write(m_fdVideo, controlMode);
		
		m_fdSidestick  = open("/dev/sidestick", O_RDONLY);
		
		// Set up the sidestick as nonblocking, so we don't wait for read() to return data
		int fdMode = fcntl(m_fdSidestick, F_GETFL);
		fcntl(m_fdSidestick, F_SETFL, fdMode | O_NONBLOCK);

		m_PlayerPaddle = Paddle(Display_TextBackground_Green, 0, m_Lines / 2, m_Lines,
			m_fdVideo, m_DisplayId);
		m_ComputerPaddle = Paddle(Display_TextBackground_Red, m_Columns - 1, m_Lines / 2, m_Lines,
			m_fdVideo, m_DisplayId);
			
		m_Ball = Ball(m_Columns / 2, m_Lines / 2, true, true, m_fdVideo, m_DisplayId);
		
		// Seed random numbers
		srand(uint(time()));
		
		ResetScreen();
	}

	private void Shutdown()
	{
		close(m_fdVideo);
		close(m_fdSidestick);
	}
	
	private void ScoreScreen(bool bPlayerWon)
	{
		uint column = m_Ball.GetColumn();
		uint line = m_Ball.GetLine();
		
		vector<var> controlClear = { Control_Video_SetCharacter, m_DisplayId, 
				" ", column, line,
				Display_TextForeground_Default,
				Display_TextBackground_Black,
				Display_TextAttribute_Normal
			};
		write(m_fdVideo, controlClear);
	
		if (bPlayerWon)
		{
			column++;
		}
		else
		{
			column--;
		}
		
		line = m_Ball.IsMovingUp() ? line - 1 : line + 1;
		
		vector<var> controlBall = { Control_Video_SetCharacter, m_DisplayId, 
				" ", column, line,
				Display_TextForeground_Default,
				Display_TextBackground_White,
				Display_TextAttribute_Normal
			};
		write(m_fdVideo, controlBall);
		
		DrawMenu();

		// -------------------------------------------------
		
		// We are waiting for the next sidestick event to continue, block
		int fdMode = fcntl(m_fdSidestick, F_GETFL);
		fcntl(m_fdSidestick, F_SETFL, fdMode & ~O_NONBLOCK);
		
		// -------------------------------------------------
		
		// Wait for up/down to continue
		vector<var> sidestickIn;
		int r = read(m_fdSidestick, sidestickIn, 1);

		// -------------------------------------------------
		
		// Moving LEFT = end application
		if (vec4(sidestickIn[0]).y > 0)
		{
			m_bShutdown = true;
			return;
		}
		
		// -------------------------------------------------
		
		// Restore non-blocking access again
		fdMode = fcntl(m_fdSidestick, F_GETFL);
		fcntl(m_fdSidestick, F_SETFL, fdMode | O_NONBLOCK);
		
		// -------------------------------------------------
		
		ResetScreen();
	}
	
	private void HandleCollisions()
	{
		// Collision with top/bottom border
		
		if (m_Ball.GetLine() == 0)
		{
			SoundBorder();
			m_Ball.SetMovementY(false);
		}
		else if (m_Ball.GetLine() == m_Lines - 1)
		{
			SoundBorder();
			m_Ball.SetMovementY(true);
		}
		
		// Collision with left/right border
		
		if (m_Ball.GetColumn() == 1)
		{
			int lineDiff = m_Ball.GetLine() - m_PlayerPaddle.GetCenterLine();
			if (lineDiff < 2 && lineDiff > -2)
			{
				SoundPaddle();
				m_Ball.SetMovementX(false);
			}
			else
			{
				SoundBorder();
				ScoreScreen(false);
			}
		}
		else if (m_Ball.GetColumn() == m_Columns - 2)
		{
			int lineDiff = m_Ball.GetLine() - m_ComputerPaddle.GetCenterLine();
			if (lineDiff < 2 && lineDiff > -1)
			{
				SoundPaddle();
				m_Ball.SetMovementX(true);
			}
			else
			{
				SoundBorder();
				ScoreScreen(true);
			}
		}
	}
	
	// --------------------------------------------------------

	void Play()
	{
		log("Starting Pong");

		Initialise();

		clock_t timepointStartFrame = clock();
		float frameTimeMs = 16.f;
		
		while (!m_bShutdown)
		{
			vector<var> sidestickIn;
			int r = read(m_fdSidestick, sidestickIn, 1);
			if (r != -1)
			{
				vec4 axis = sidestickIn[0];

				if (axis.x > 0.9)
				{
					m_PlayerPaddle.SetMovement(Paddle_Down);
				}
				else if (axis.x < -0.9)
				{
					m_PlayerPaddle.SetMovement(Paddle_Up);
				}
				else
				{
					m_PlayerPaddle.SetMovement(Paddle_Still);
				}
			}

			float timeMs = 14.0;
			
			m_PlayerPaddle.Update(timeMs);
			m_Ball.Update(timeMs);
			
			// Computer follows ball with 1 unit delay
			uint line = m_Ball.GetLine();
			if (line < 1)
			{
				line = 1;
			}
			if (line > m_Lines - 1)
			{
				line = m_Lines - 1;
			}
			m_ComputerPaddle.SetCenterLine(line);
			
			// ---
			
			m_PlayerPaddle.Draw();
			m_ComputerPaddle.Draw();
			m_Ball.Draw();
			
			// ---

			uint64 diffTime = clock() - timepointStartFrame;
			
			// Frame should take at least 50ms
			if (diffTime < frametimeUs)
			{
				usleep(frametimeUs - diffTime);
			}

			clock_t endFrame = clock();
			
			frameTimeMs = (endFrame - timepointStartFrame) / 1000.0;
			
			timepointStartFrame = endFrame;
			
			// ---
			
			// Handle ball collisions
			HandleCollisions();
		}

		Shutdown();

		log("Pong ended");
	}
}

// -----------------------------------------------------------------------------

int main(uint argc, vector<var> &in argv)
{
	PongGame pong;
	pong.Play();

	return 0;
}
