// -----------------------------------------------------------------------------
// stationcontrol.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Binary nandOS API

// AngelScript
#include "/lib/libDCP.as"

// Messages for networked communication
namespace MessageType
{
	// Messages sent from a vessel
	enum VesselMessageType
	{
		Vessel_Id = 0,				// Send information about a vessel
		Vessel_RequestDocking,		// Docking request
		Vessel_RequestUndocking,	// Undocking request
		Vessel_END
	};
	
	// Messages sent from a (ground) station
	enum StationMessageType
	{
		Station_Id = 0,				// Send information about a station
		Station_ReplyDocking,		// Reply to docking requests
		Station_ReplyUndocking,		// Reply to undocking requests
		Station_END
	};
};

// -----------------------------------------------------------------------------

// Warning lights
vector<int> fdWarningLightsTop;
vector<int> fdWarningLightsMiddle;

// -----------------------------------------------------------------------------

bool initializeDevices()
{
	int fdWarningLight;
	
	fdWarningLight = open("/dev/spacecraftWarningLight0", O_WRONLY);
	if (fdWarningLight == -1)
	{
		log("Failed opening the light device!");
		return false;
	}
	fdWarningLightsTop.push_back(fdWarningLight);
	
	fdWarningLight = open("/dev/spacecraftWarningLight1", O_WRONLY);
	if (fdWarningLight == -1)
	{
		log("Failed opening the light device!");
		return false;
	}
	fdWarningLightsTop.push_back(fdWarningLight);
	
	fdWarningLight = open("/dev/spacecraftWarningLight2", O_WRONLY);
	if (fdWarningLight == -1)
	{
		log("Failed opening the light device!");
		return false;
	}
	fdWarningLightsTop.push_back(fdWarningLight);
	
	// ---
	
	fdWarningLight = open("/dev/spacecraftWarningLight3", O_WRONLY);
	if (fdWarningLight == -1)
	{
		log("Failed opening the light device!");
		return false;
	}
	fdWarningLightsMiddle.push_back(fdWarningLight);
	
	// ---
	
	return true;
}

// -----------------------------------------------------------------------------

enum LightMode
{
	LightMode_Idle = 0,
	LightMode_Docking = 1,
	LightMode_Emergency = 2
}
	
class LightControl
{
	private vector<var> m_ControlOn =
	{
		Control_Device_Power,
		Device_PowerMode_On
	};
	
	private vector<var> m_ControlOff =
	{
		Control_Device_Power,
		Device_PowerMode_Off
	};

	private LightMode m_LightMode = LightMode_Idle;
	private bool m_bEmergencyOn = false;
	
	// Light animation steps, depends on mode
	private int m_LightStep = 0;
	
	// -----------------------------------------------------
	
	void SetMode(LightMode mode)
	{
		m_LightMode = mode;
		
		// Turn off all lights by default
		vector<var> controlOff = { Control_Device_Power, Device_PowerMode_Off };
		write(fdWarningLightsMiddle[0], m_ControlOff);
		write(fdWarningLightsTop[0], m_ControlOff);
		write(fdWarningLightsTop[1], m_ControlOff);
		write(fdWarningLightsTop[2], m_ControlOff);
		
		// Wait till lights are off for change
		usleep(1000000);

		// Change light mode = other colours
		vector<var> controlMode = { Control_Light_SetMode, int(m_LightMode) };
		write(fdWarningLightsMiddle[0], controlMode);
		write(fdWarningLightsTop[0], controlMode);
		write(fdWarningLightsTop[1], controlMode);
		write(fdWarningLightsTop[2], controlMode);

		// Reset light animation steps
		m_LightStep = 0;
	}
	
	// NOTE This function is BLOCKING, however we slice things up into multiple steps for responsiveness
	void UpdateWarningLights()
	{
		if (m_LightMode == LightMode_Idle)
		{
			// Idle

			if (m_LightStep < 1)
			{
				write(fdWarningLightsTop[0], 	m_ControlOn);
				write(fdWarningLightsMiddle[0], m_ControlOn);
				
				sleep(1);
			}
			else if (m_LightStep < 2)
			{
				write(fdWarningLightsTop[0], 	m_ControlOff);
				write(fdWarningLightsMiddle[0], m_ControlOff);
				
				usleep(250000);
			}
			else if (m_LightStep < 3)
			{
				write(fdWarningLightsTop[1], m_ControlOn);
				
				usleep(250000);
			}
			else if (m_LightStep < 4)
			{
				write(fdWarningLightsTop[1], m_ControlOff);
				write(fdWarningLightsTop[2], m_ControlOn);
				
				usleep(250000);
			}
			else
			{
				write(fdWarningLightsTop[2], m_ControlOff);
			
				usleep(500000);
			}
			
			m_LightStep = (m_LightStep + 1) % 5;
		}
		else if (m_LightMode == LightMode_Docking)
		{
			// Docking
			
			if (m_LightStep < 1)
			{
				write(fdWarningLightsMiddle[0], m_ControlOn);
				
				usleep(500000);
			}
			else if (m_LightStep < 2)
			{
				write(fdWarningLightsMiddle[0], m_ControlOff);				
				write(fdWarningLightsTop[1], 	m_ControlOn);				
				
				usleep(500000);
			}
			else if (m_LightStep < 3)
			{
				write(fdWarningLightsTop[1], m_ControlOff);
				write(fdWarningLightsTop[0], m_ControlOn);

				usleep(500000);
			}
			else
			{
				write(fdWarningLightsTop[0], m_ControlOff);
				
				usleep(750000);
			}
		
			m_LightStep = (m_LightStep + 1) % 4;
		}
		else if (m_LightMode == LightMode_Emergency)
		{
			// Emergency
			
			if (m_LightStep < 1)
			{
				m_bEmergencyOn = !m_bEmergencyOn;
			
				write(fdWarningLightsTop[1], m_ControlOff);
				
				write(fdWarningLightsTop[0], 	m_bEmergencyOn ? m_ControlOn : m_ControlOff);
				write(fdWarningLightsMiddle[0], m_bEmergencyOn ? m_ControlOn : m_ControlOff);
				
				usleep(200000);
			}
			else
			{
				write(fdWarningLightsTop[1], m_ControlOn);
				
				usleep(200000);
			}
			
			m_LightStep = (m_LightStep + 1) % 2;
		}
	}
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Application entry point
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

int main(uint argc, vector<var> &in argv)
{
	log("Starting Stationcontrol");

	log("PID=" + getpid() + " PPID=" + getppid());
	
	// --------------------------------------------------------

	if (!initializeDevices())
	{
		return 1;
	}
	
	// --------------------------------------------------------
	
	// Station properties
	
	vector<var> emergencyFacilities = 
	{
		"ReinforcedCell",
		"ActiveFireProtection",
		"MedicalSupplies-A",
		"MedicalSupplies-C",
		"SurgicalRobot",
		"FoodRations-2PY"
	};
	
	vector<var> acceptedSpacecraft =
	{
		"MPS",
		"MPS-M",
		"MPS-S",
		"MPS-E"
	};
	
	// --------------------------------------------------------
	
	// Asteroid mining station W1
	DCP libDCP("/dev/wlan0", "AMS", "W1", false);
	// libDCP.SetDebug(true);
	
	LightControl warningLights;
	
	bool bDockingInitiated = false;
	bool bEmergency = false;
	
	while(true)
	{
		// -----------------------------------------------------
		// Update lights
		// -----------------------------------------------------

		// NOTE This function is blocking in will put the application to sleep for short time
		warningLights.UpdateWarningLights();
		
		// -----------------------------------------------------
		// Process incoming network data
		// -----------------------------------------------------

		ReadResultDCP readResult = libDCP.PollNetworkData();
		if (readResult == DCP_Read_Request)
		{
			RequestDCP request = libDCP.GetRequest();
			
			if (request.type == DCP_Request_Dock)
			{
				// log("Got docking request!");
			
				if (request.priority == DCP_Priority_Emergency)
				{
					// log("Emergency");
				
					warningLights.SetMode(LightMode_Emergency);
					
					string message = "[ Automated Mining Station W1 ]\n";
					
					switch (request.emergencyReason)
					{
					case DCP_Emergency_Malfunction:
						message += "WARNING: No support drones for taxi!\nNotified nearby outposts.\n";
						break;
					case DCP_Emergency_Damage:
						message += "WARNING: No support drones for taxi!\nNotified nearby outposts.\n";
						break;
					case DCP_Emergency_Crew:
						message += "Prepared detainment facilities.\nNotified anti-terror unit of nearby outposts.\n";
						break;
					case DCP_Emergency_Cargo2:
						message += "Permission may be revoked if radiation level too high.\n";
						break;
					case DCP_Emergency_Cargo4:
						message += "Population: 0\nFacility suited for quarantine.\nNotified nearby outposts.\n";
						break;
					default:
						log("Unsupported emergency reason provided! " + request.emergencyReason);
						break;
					}
					
					libDCP.ResponseOkEmergency(request, 1, 300, emergencyFacilities,
						message);
					
					bEmergency = true;
				}
				else
				{
					uint timeout = 300;
					
					string message = "[ Automated Mining Station W1 ]\n";
					
					if (bEmergency)
					{
						message += "! Priority access due to emergency.\n";
					}
					else
					{
						message += "Permission granted for " + request.spacecraftIdentifier + 
							".\nFollow the green docking lights.\n";
						warningLights.SetMode(LightMode_Docking);
					}
					
					libDCP.ResponseOk(request, 1, 300, message);
						
					bDockingInitiated = true;
				}
			}
			else if (request.type == DCP_Request_Cancel)
			{
				if (bDockingInitiated)
				{
					string message = "[ Automated Mining Station W1 ]\nDocking permission revoked.\n";
					
					if (bEmergency)
					{
						message += "Emergency measures suspended.\nYou will be penalized for a non-\nwarranted distress call.\n";
						bEmergency = false;
					}
				
					libDCP.ResponseOkCancel(request, message);
				
					warningLights.SetMode(LightMode_Idle);
					bDockingInitiated = false;
				}
			}
			else if (request.type == DCP_Request_Info)
			{
				string message = "[ Automated Mining Station W1 ]\nOperator: U.C.I.\n";
				
				if (bEmergency)
				{
					message += "! Prepared for emergency docking\n";
				}
				
				libDCP.ResponseOkInfo(request, 1, 300, acceptedSpacecraft, emergencyFacilities,
					message);
			}
		}
		else if (readResult == DCP_Read_NoData)
		{
			// log("No data!");
		}
	}
	
	libDCP.Shutdown();
	
	// --------------------------------------------------------

	return 0;
}