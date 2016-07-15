// -----------------------------------------------------------------------------
// libDCP.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

#include "unistd.h"
#include "fcntl.h"

// -----------------------------------------------------------------------------

const string PROTOCOL_NAME = "DCP/1.0";

// -----------------------------------------------------------------------------

/** Request methods, sent out by spacecraft to station it wants to dock with */
enum RequestTypeDCP
{
	DCP_Request_Dock = 0,			/** Request docking permission */
	DCP_Request_Cancel,				/** Cancel the docking procedure */
	DCP_Request_Info,				/** Get information about the station */
	// ---
	DCP_Request_INVALID				/** Returned on conversion if string invalid */
}

string toRequestString(RequestTypeDCP request)
{
	string requestString = "undefined";
	
	switch(request)
	{
		case DCP_Request_Dock:
			requestString = "DOCK";
		break;
		case DCP_Request_Cancel:
			requestString = "CANCEL";
		break;
		case DCP_Request_Info:
			requestString = "INFO";
		break;
	}
	
	return requestString;
}

RequestTypeDCP toRequestCode(string request)
{
	if (request == "DOCK")
	{
		return DCP_Request_Dock;
	}
	else if (request == "CANCEL")
	{
		return DCP_Request_Cancel;
	}
	else if (request == "INFO")
	{
		return DCP_Request_Info;
	}
	else
	{
		return DCP_Request_INVALID;
	}
}

// ---------------------------------------------------------

/** Docking priority */
enum PriorityDCP
{
	DCP_Priority_Normal = 0,		/** Regular docking priority */
	DCP_Priority_High,				/** High docking priority, requires authentication */
	DCP_Priority_Emergency,			/** Highest priority for emergency situations */
	// ---
	DCP_Priority_INVALID			/** Returned on conversion if string invalid */
}

string toPriorityString(PriorityDCP priority)
{
	string priorityString = "invalid";
	
	switch(priority)
	{
		case DCP_Priority_Normal:
			priorityString = "Normal";
		break;
		case DCP_Priority_High:
			priorityString = "High";
		break;
		case DCP_Priority_Emergency:
			priorityString = "Emergency";
		break;
	}
	
	return priorityString;
}


PriorityDCP toPriorityCode(string priority)
{
	if (priority == "Normal")
	{
		return DCP_Priority_Normal;
	}
	else if (priority == "High")
	{
		return DCP_Priority_High;
	}
	else if (priority == "Emergency")
	{
		return DCP_Priority_Emergency;
	}
	else
	{
		return DCP_Priority_INVALID;
	}
}

// ---------------------------------------------------------

/** Emergency reasons */
enum EmergencyReasonDCP
{
	DCP_Emergency_Malfunction = 0,		/** Malfunction of a core system */
	DCP_Emergency_Fire,					/** Active fire or critical damage due to fire */
	DCP_Emergency_Damage,				/** Physical or other damage of spacecraft structure */
	DCP_Emergency_Fuel,					/** Fuel shortage or energy problem */
	DCP_Emergency_Crew,					/** Illegal behaviour of crew or passengers */
	DCP_Emergency_Medical,				/** Crew or passengers seriously wounded */
	DCP_Emergency_Cargo1,				/** Class 1 cargo problem: common goods */
	DCP_Emergency_Cargo2,				/** Class 2 cargo problem: chemical/explosive */
	DCP_Emergency_Cargo3,				/** Class 3 cargo problem: radioactive */
	DCP_Emergency_Cargo4,				/** Class 4 cargo problem: biohazard/contamination */
	// ---
	DCP_Emergency_INVALID				/** Returned on conversion if string invalid */
}

string toEmergencyString(EmergencyReasonDCP reason)
{
	string reasonString = "invalid";
	
	switch(reason)
	{
		case DCP_Emergency_Malfunction:
			reasonString = "Malfunction";
		break;
		case DCP_Emergency_Fire:
			reasonString = "Fire";
		break;
		case DCP_Emergency_Damage:
			reasonString = "Damage";
		break;
		case DCP_Emergency_Fuel:
			reasonString = "Fuel";
		break;
		case DCP_Emergency_Crew:
			reasonString = "Crew";
		break;
		case DCP_Emergency_Cargo1:
			reasonString = "Cargo1";
		break;
		case DCP_Emergency_Cargo2:
			reasonString = "Cargo2";
		break;
		case DCP_Emergency_Cargo3:
			reasonString = "Cargo3";
		break;
		case DCP_Emergency_Cargo4:
			reasonString = "Cargo4";
		break;
	}
	
	return reasonString;
}

EmergencyReasonDCP toEmergencyCode(string reason)
{
	if (reason == "Malfunction")
	{
		return DCP_Emergency_Malfunction;
	}
	else if (reason == "Fire")
	{
		return DCP_Emergency_Fire;
	}
	else if (reason == "Damage")
	{
		return DCP_Emergency_Damage;
	}
	else if (reason == "Fuel")
	{
		return DCP_Emergency_Fuel;
	}
	else if (reason == "Crew")
	{
		return DCP_Emergency_Crew;
	}
	else if (reason == "Cargo1")
	{
		return DCP_Emergency_Cargo1;
	}
	else if (reason == "Cargo2")
	{
		return DCP_Emergency_Cargo2;
	}
	else if (reason == "Cargo3")
	{
		return DCP_Emergency_Cargo3;
	}
	else if (reason == "Cargo4")
	{
		return DCP_Emergency_Cargo4;
	}
	else
	{
		return DCP_Emergency_INVALID;
	}
}

// ---------------------------------------------------------

/** Wrapper for DCP requests providing convenience functions for serialisation to/from string */
class RequestDCP
{
	RequestTypeDCP type;
	
	// Header

	string spacecraftIdentifier;	
	PriorityDCP priority;
	
	EmergencyReasonDCP emergencyReason;
	
	string authLogin;
	string authPassword;
	
	// Body
	
	string message;

	// -----------------------------------------------------
	
	RequestDCP() {}
	
	/** Construct a request from text as received over the network */
	RequestDCP(string data)
	{
		DCP::LogDebug("Parsing request from data");
	
		bool bParsingOkay = false;
		
		string dataLine;
		size_t iStartline = 0;
		size_t iNewline = 0;
		iNewline = data.find("\n", iNewline);

		dataLine = data.substr(iStartline, iNewline - iStartline);
		
		if (dataLine.find(toRequestString(DCP_Request_Dock)) == 0)
		{
			type = DCP_Request_Dock;
		}
		else if (dataLine.find(toRequestString(DCP_Request_Cancel)) == 0)
		{
			type = DCP_Request_Cancel;
		}
		else if (dataLine.find(toRequestString(DCP_Request_Info)) == 0)
		{
			type = DCP_Request_Info;
		}
		else
		{
			DCP::LogDebug("Malformed request type: " + dataLine);
			type = DCP_Request_INVALID;
			return;
		}
		
		iStartline = iNewline + 1;
		iNewline = data.find("\n", iStartline);
		
		while (iNewline != string::npos && iNewline < data.size())
		{
			dataLine = data.substr(iStartline, iNewline - iStartline);
			
			if (dataLine.empty())
			{
				// First empty line marks end of header, rest is message
				message = data.substr(iNewline + 1);
				bParsingOkay = true;
				break;
			}
			
			DCP::LogDebug(dataLine);
			
			// Process header
			
			if (dataLine.find("Spacecraft-Identifier: ") == 0)
			{
				spacecraftIdentifier = dataLine.substr(dataLine.find(" ") + 1);
			}
			else if (dataLine.find("Docking-Priority: ") == 0)
			{
				priority = toPriorityCode(dataLine.substr(dataLine.find(" ") + 1));
			}
			else if (dataLine.find("Authentication: ") == 0)
			{
				string credentials = dataLine.substr(dataLine.find(" ") + 1);
				size_t separator = credentials.find("/");
				authLogin = credentials.substr(0, separator);
				authPassword = credentials.substr(separator + 1);
			}
			else if (dataLine.find("Emergency-Reason: ") == 0)
			{
				emergencyReason = toEmergencyCode(dataLine.substr(dataLine.find(" ") + 1));
			}
		
			iStartline = iNewline + 1;
			iNewline = data.find("\n", iStartline);
		}
		
		if (!bParsingOkay)
		{
			type = DCP_Request_INVALID;
		}
	}
	
	/** Convert request to string */
	string opImplConv() const
	{
		if (type == DCP_Request_INVALID)
		{
			return ("Malformed request!");
		}
	
		string data = toRequestString(type) + " " + PROTOCOL_NAME + "\n";

		// Header

		switch(type)
		{
			case DCP_Request_Dock:
				data += "Spacecraft-Identifier: " + spacecraftIdentifier + "\n";
				data += "Docking-Priority: " + toPriorityString(priority) + "\n";
				if (priority == DCP_Priority_High)
				{
					// High priority requests necessitate authentication
					data += "Authentication: " + authLogin + "/" + authPassword + "\n";
				}
				else if (priority == DCP_Priority_Emergency)
				{
					data += "Emergency-Reason: " + toEmergencyString(emergencyReason) + "\n";
				}
			break;
			case DCP_Request_Cancel:
			break;
			case DCP_Request_Info:
			break;
		}
		
		// Body
		
		if (message.empty())
		{
			data += "\n";
		}
		else
		{
			data += "\n" + message;
		}

		return data;
	}
}

// ---------------------------------------------------------

/** Response status code sent by the station after receiving a request from the spaceship */
enum ResponseTypeDCP
{
	DCP_Response_Ok = 0,			/** The request could be fulfilled normally */
	DCP_Response_BadRequest,		/** Malformed request */
	DCP_Response_Unauthorized,		/** The request requires authentication that was not provided */
	DCP_Response_UnsupportedType,	/** The vessel type is not supported by the station */
	DCP_Response_DockUnavailable,	/** The stations docks are all occupied OR no emergency dock for that type */
	// ---
	DCP_Response_INVALID			/** Returned on conversion if string invalid */
}

string toResponseString(ResponseTypeDCP response)
{
	string responseString = "undefined";
	
	switch(response)
	{
		case DCP_Response_Ok:
			responseString = "200 OK";
		break;
		case DCP_Response_BadRequest:
			responseString = "400 Bad Request";
		break;
		case DCP_Response_Unauthorized:
			responseString = "401 Unauthorized";
		break;
		case DCP_Response_UnsupportedType:
			responseString = "405 Unsupported Vessel Type";
		break;
		case DCP_Response_DockUnavailable:
			responseString = "503 Dock Unavailable";
		break;
	}
	
	return responseString;
}

ResponseTypeDCP toResponseCode(string response)
{
	if (response == "200 OK")
	{
		return DCP_Response_Ok;
	}
	else if (response == "400 Bad Request")
	{
		return DCP_Response_BadRequest;
	}
	else if (response == "401 Unauthorized")
	{
		return DCP_Response_Unauthorized;
	}
	else if (response == "405 Unsupported Vessel Type")
	{
		return DCP_Response_UnsupportedType;
	}
	else if (response == "503 Dock Unavailable")
	{
		return DCP_Response_DockUnavailable;
	}
	else
	{
		return DCP_Response_INVALID;
	}
}

// ---------------------------------------------------------

/** Wrapper for DCP responses providing convenience functions for serialisation to/from string */
class ResponseDCP
{
	ResponseTypeDCP type;
	
	/** Request we are reponding to, only used on station */
	RequestDCP request;
	
	// Header
	
	uint freeSlots = 0;
	
	/** Permission timeout in seconds */
	uint permissionTimeout = 0;
	
	/** Types of spacecraft that can dock with the station */
	vector<var> acceptedSpacecraft;
	
	/** List of emergency facilities that may be returned as information */
	vector<var> emergencyFacilities;
	
	// Body
	
	string message;

	// -----------------------------------------------------
	
	ResponseDCP() {}
	
	ResponseDCP(RequestDCP receivedRequest)
	{
		request = receivedRequest;
	}
	
	/** Construct a response from text as received over the network */
	ResponseDCP(string data)
	{
		DCP::LogDebug("Parsing response from data");
	
		bool bParsingOkay = false;
		
		string dataLine;
		size_t iStartline = 0;
		size_t iNewline = 0;
		iNewline = data.find("\n", iNewline);

		dataLine = data.substr(iStartline, iNewline - iStartline);

		if (dataLine.find(toResponseString(DCP_Response_Ok)) == 0)
		{
			type = DCP_Response_Ok;
		}
		else if (dataLine.find(toResponseString(DCP_Response_BadRequest)) == 0)
		{
			type = DCP_Response_BadRequest;
		}
		else if (dataLine.find(toResponseString(DCP_Response_Unauthorized)) == 0)
		{
			type = DCP_Response_Unauthorized;
		}
		else if (dataLine.find(toResponseString(DCP_Response_UnsupportedType)) == 0)
		{
			type = DCP_Response_UnsupportedType;
		}
		else if (dataLine.find(toResponseString(DCP_Response_DockUnavailable)) == 0)
		{
			type = DCP_Response_DockUnavailable;
		}
		else
		{
			DCP::LogDebug("Malformed response type: " + dataLine);
			type = DCP_Response_INVALID;
			return;
		}
		
		iStartline = iNewline + 1;
		iNewline = data.find("\n", iStartline);
		
		while (iNewline != string::npos && iNewline < data.size())
		{
			dataLine = data.substr(iStartline, iNewline - iStartline);
			
			if (dataLine.empty())
			{
				// First empty line marks end of header, rest is message
				message = data.substr(iNewline + 1);
				bParsingOkay = true;
				break;
			}
			
			DCP::LogDebug(dataLine);
			
			// Process header
			
			if (dataLine.find("Free-Slots: ") == 0)
			{
				freeSlots = stoui(dataLine.find(" ") + 1);
			}
			else if (dataLine.find("Permission-Timeout: ") == 0)
			{
				permissionTimeout = stoui(dataLine.find(" ") + 1);
			}
			else if (dataLine.find("Accepted-Spacecraft: ") == 0)
			{
				size_t startPos = dataLine.find(" ") + 1;
				size_t endPos = dataLine.find(" ", startPos);
				
				while (endPos != string::npos)
				{
					acceptedSpacecraft.push_back(dataLine.substr(startPos, endPos - startPos));
					startPos = endPos + 1;
					endPos = dataLine.find(" ", startPos);
				}
				acceptedSpacecraft.push_back(dataLine.substr(startPos));
			}
			else if (dataLine.find("Emergency-Facilities: ") == 0)
			{
				size_t startPos = dataLine.find(" ") + 1;
				size_t endPos = dataLine.find(" ", startPos);
				
				while (endPos != string::npos)
				{
					emergencyFacilities.push_back(dataLine.substr(startPos, endPos - startPos));
					startPos = endPos + 1;
					endPos = dataLine.find(" ", startPos);
				}
				emergencyFacilities.push_back(dataLine.substr(startPos));
			}
		
			iStartline = iNewline + 1;
			iNewline = data.find("\n", iStartline);
		}
		
		if (!bParsingOkay)
		{
			type = DCP_Response_INVALID;
		}
	}
	
	/** Convert response to string */
	string opImplConv() const
	{
		if (type == DCP_Response_INVALID)
		{
			return ("Malformed response!");
		}
	
		string data = toResponseString(type) + "\n";

		// Header
	
		switch(type)
		{
			case DCP_Response_Ok:
				data += "Free-Slots: " + string(freeSlots) + "\n";
				data += "Permission-Timeout: " + string(permissionTimeout) + "\n";
				
				if (request.type == DCP_Request_Info)
				{
					string spacecraftString;
					
					for (uint iType = 0; iType < acceptedSpacecraft.size(); iType++)
					{
						spacecraftString += acceptedSpacecraft[iType];
						if (iType < acceptedSpacecraft.size() - 1)
						{
							spacecraftString += " ";
						}
					}
					
					data += "Accepted-Spacecraft: " + spacecraftString + "\n";
				}
				
				if (request.type == DCP_Request_Info || (request.type == DCP_Request_Dock &&
					request.priority == DCP_Priority_Emergency))
				{
					string emergencyString;
					
					for (uint iFacility = 0; iFacility < emergencyFacilities.size(); iFacility++)
					{
						emergencyString += emergencyFacilities[iFacility];
						if (iFacility < emergencyFacilities.size() - 1)
						{
							emergencyString += " ";
						}
					}
				
					data += "Emergency-Facilities: " + emergencyString + "\n";
				}
			break;
			case DCP_Response_BadRequest:
			break;
			case DCP_Response_Unauthorized:
			break;
			case DCP_Response_UnsupportedType:
				{
					string spacecraftString;
					
					for (uint iType = 0; iType < acceptedSpacecraft.size(); iType++)
					{
						spacecraftString += acceptedSpacecraft[iType];
						if (iType < acceptedSpacecraft.size() - 1)
						{
							spacecraftString += " ";
						}
					}
					
					data += "Accepted-Spacecraft: " + spacecraftString + "\n";
				}
			break;
			case DCP_Response_DockUnavailable:
				if (request.type == DCP_Request_Dock && request.priority == DCP_Priority_Emergency)
				{
					string emergencyString;
					
					for (uint iFacility = 0; iFacility < emergencyFacilities.size(); iFacility++)
					{
						emergencyString += emergencyFacilities[iFacility];
						if (iFacility < emergencyFacilities.size() - 1)
						{
							emergencyString += " ";
						}
					}
				
					data += "Emergency-Facilities: " + emergencyString + "\n";
				}
			break;
		}
		
		// Body
		
		if (message.empty())
		{
			data += "\n";
		}
		else
		{
			data += "\n" + message;
		}
		
		return data;
	}
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Actual helper library
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

/** Result of reading data from the device */
enum ReadResultDCP
{
	DCP_Read_NoData = 0,	/** No data received */
	DCP_Read_Request,		/** Station: received a docking request from spacecraft */
	DCP_Read_Response		/** Spacecraft: received response from station */
}

// ---------------------------------------------------------

// Emulation of static variables
namespace DCP
{
	bool bDebug = false;
	
	void LogDebug(string message)
	{
		if (bDebug)
		{
			log("(libDCP) " + message);
		}
	}
}

/** Wrapper for DCP (Docking Control Protocol) operations */
class DCP
{
	/** Network device file descriptor */
	private int m_fdWlan = -1;

	/** Identifier of spacecraft/vessel type and its unique identifier */
	private string m_TypeIdentifier = "UndefinedType UndefinedIdentifier";
	
	/** Whether we have a spacecraft (=client) or station (=server) */
	private bool m_bIsSpacecraft = false;
	
	// ---------------------------------
	
	private bool m_bPendingRequest = false;
	
	private RequestDCP m_Request;
	
	private bool m_bPendingResponse = false;

	private ResponseDCP m_Response;
	
	// -----------------------------------------------------

	// LOG ADDITIONAL DEBUG MESSAGES
	
	void SetDebug(bool bEnable)
	{
		DCP::bDebug = bEnable;
	}
	
	// -----------------------------------------------------

	DCP(string networkDevicePath, string type, string identifier, bool bIsSpacecraft)
	{
		string typeIdentifier =  type + "/" + identifier;

		DCP::LogDebug("Initialise '" + typeIdentifier + "'");

		m_TypeIdentifier = typeIdentifier;
		m_bIsSpacecraft = bIsSpacecraft;
		
		m_fdWlan = open(networkDevicePath, O_RDWR);
		
		int fdMode = fcntl(m_fdWlan, F_GETFL);
		fcntl(m_fdWlan, F_SETFL, fdMode | O_NONBLOCK);
	}
	
	// WARNING Never use system calls in DESTRUCTORS since order of execution not predictable
	void Shutdown()
	{
		DCP::LogDebug("Shutting down '" + m_TypeIdentifier + "'");
		
		close(m_fdWlan);
	}

	// ---------------------------------
	
	/** Call periodically to poll for received data */
	ReadResultDCP PollNetworkData()
	{
		vector<var> dataIn;
		ssize_t r = read(m_fdWlan, dataIn, 32);
		
		// TODO Handle spacecraft/vessels coming into/moving out of range
		
		if (r != 2 || (int(dataIn[0]) != Interrupt_DataLink_Data))
		{
			return DCP_Read_NoData;
		}
		else
		{
			if (m_bIsSpacecraft)
			{
				DCP::LogDebug("Spacecraft NetworkData!");
				
				m_Response = ResponseDCP(dataIn[1]);
				m_bPendingResponse = true;
				
				if (true)
				{
					return DCP_Read_Response;
				}
				else
				{
					DCP::LogDebug("Invalid respone format!");
					return DCP_Read_NoData;
				}
			}
			else
			{
				DCP::LogDebug("Station NetworkData!");
				
				m_Request = RequestDCP(dataIn[1]);
				m_bPendingRequest = true;
				
				if (true)
				{
					return DCP_Read_Request;
				}
				else
				{
					DCP::LogDebug("Invalid respone format!");
					return DCP_Read_NoData;
				}
			}
		}
	}
	
	// ---------------------------------
	
	// Vessel: Request helpers
	
	/** Send a regular docking request with an optional message */
	void RequestDockingNormal(string message = "")
	{
		m_Request = RequestDCP();
		
		m_Request.type = DCP_Request_Dock;
		m_Request.priority = DCP_Priority_Normal;
		m_Request.spacecraftIdentifier = m_TypeIdentifier;
		m_Request.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Request)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Request docking with high priority using priority credentials */
	void RequestDockingHigh(string login, string password, string message = "")
	{
		m_Request = RequestDCP();
		
		m_Request.type = DCP_Request_Dock;
		m_Request.priority = DCP_Priority_High;
		m_Request.authLogin = login;
		m_Request.authPassword = password;
		m_Request.spacecraftIdentifier = m_TypeIdentifier;
		m_Request.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Request)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Request docking, indicating an emergency on board */
	void RequestDockingEmergency(EmergencyReasonDCP emergencyReason, string emergencyMessage = "")
	{
		m_Request = RequestDCP();
		
		m_Request.type = DCP_Request_Dock;
		m_Request.priority = DCP_Priority_Emergency;
		m_Request.emergencyReason = emergencyReason;
		m_Request.spacecraftIdentifier = m_TypeIdentifier;
		m_Request.message = emergencyMessage;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Request)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Cancel docking */
	void RequestCancel(string message = "")
	{
		m_Request = RequestDCP();
		
		m_Request.type = DCP_Request_Cancel;
		m_Request.spacecraftIdentifier = m_TypeIdentifier;
		m_Request.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Request)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Request information about the station */
	void RequestInfo(string message = "")
	{
		m_Request = RequestDCP();
		
		m_Request.type = DCP_Request_Info;
		m_Request.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Request)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}

	// ---------------------------------
	
	// Station: Response helpers
	
	/** Regular docking access granted */
	void ResponseOk(RequestDCP request, uint freeSlots, uint timeout, string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.freeSlots = freeSlots;
		m_Response.permissionTimeout = timeout;
		
		m_Response.type = DCP_Response_Ok;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Cancel docking */
	void ResponseOkCancel(RequestDCP request, string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.type = DCP_Response_Ok;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Response to info query */
	void ResponseOkInfo(RequestDCP request, uint freeSlots, uint timeout,
		vector<var> acceptedSpacecraft, vector<var> emergencyFacilities, string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.freeSlots = freeSlots;
		m_Response.permissionTimeout = timeout;
		m_Response.acceptedSpacecraft = acceptedSpacecraft;
		m_Response.emergencyFacilities = emergencyFacilities;
		
		m_Response.type = DCP_Response_Ok;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Emergency  docking access granted */
	void ResponseOkEmergency(RequestDCP request, uint freeSlots, uint timeout,
		vector<var> emergencyFacilities, string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.freeSlots = freeSlots;
		m_Response.permissionTimeout = timeout;
		m_Response.emergencyFacilities = emergencyFacilities;
		
		m_Response.type = DCP_Response_Ok;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Malformed request */
	void ResponseBadRequest(RequestDCP request, string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.type = DCP_Response_BadRequest;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Didn't provide credentials for high priority docking */
	void ResponseUnauthorized(RequestDCP request, string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.type = DCP_Response_Unauthorized;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** Vessel type not supported by station */
	void ResponseUnsupportedType(RequestDCP request, vector<var> acceptedSpacecraft,
		string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.acceptedSpacecraft = acceptedSpacecraft;
		
		m_Response.type = DCP_Response_UnsupportedType;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** All docks are full */
	void ResponseUnavailable(RequestDCP request, string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.type = DCP_Response_DockUnavailable;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	/** No dock available for that emergency type */
	void ResponseUnavailableEmergency(RequestDCP request, vector<var> emergencyFacilities,
		string message = "")
	{
		m_Response = ResponseDCP(request);
		
		m_Response.emergencyFacilities = emergencyFacilities;
		
		m_Response.type = DCP_Response_DockUnavailable;
		m_Response.message = message;
		
		vector<var> dataOut = 
		{
			Control_DataLink_Data,
			string(m_Response)
		};
		
		DCP::LogDebug("Writing out:\n" + string(dataOut[1]));
		
		write(m_fdWlan, dataOut);
	}
	
	// ---------------------------------
	
	bool IsRequestPending() const
	{
		return m_bPendingRequest;
	}
	
	RequestDCP GetRequest()
	{
		m_bPendingRequest = false;
		return m_Request;
	}
	
	bool IsResponsePending() const
	{
		return m_bPendingResponse;
	}
	
	ResponseDCP GetResponse()
	{
		m_bPendingResponse = false;
		return m_Response;
	}
}
