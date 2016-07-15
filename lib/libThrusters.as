// -----------------------------------------------------------------------------
// libThrusters.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// A wrapper for MPS thruster controls
//
// To get started with nandOS development, check:
// - https://3001sq.net/forums/#/categories/hello-world (Beginners Forum)
// - https://github.com/3001SQ                          (Code Examples)
//

// nandOS binary API
#include "fcntl.h"

// -----------------------------------------------------------------------------

/** 
	The MPS spacecraft is equipped with various attitude control thrusters for manoeuvring
*/

namespace ThrusterControl
{
// -------------------------------------------------------------------
// -------------------------------------------------------------------

// How a thruster affects an axis
enum ThrusterEffect
{
	Thrust_None = 0,	// No effect
	Thrust_Positive,	// Rotate around axis
	Thrust_Negative		// Rotate against axis
}

/** Thruster Groups */
enum ThrusterGroup
{
	Pitch_Positive = 0,
	Pitch_Negative,
	Yaw_Positive,
	Yaw_Negative,
	Roll_Positive,
	Roll_Negative,
	// ---
	Thrusters_All
}

// Thruster device file descriptors
vector<int> fdAttitudeThruster;

// Thruster groups
vector<int> thrustersPitchPos;
vector<int> thrustersPitchNeg;
vector<int> thrustersYawPos;
vector<int> thrustersYawNeg;
vector<int> thrustersRollPos;
vector<int> thrustersRollNeg;

// Main engine device
int fdMainEngine;

// ---------------------------------------------------------

// Open the thruster device and associate it with 
// contributing to positive/negative pitch/yaw/roll
bool _initialiseThruster(string devicePath,
	ThrusterEffect pitch, ThrusterEffect yaw, ThrusterEffect roll)
{
	int fd = open(devicePath, O_WRONLY);
	
	if (fd == -1)
	{
		return false;
	}
	
	// Register thruster with appropriate group
	
	if (pitch == Thrust_Positive)
	{
		thrustersPitchPos.push_back(fd);
	}
	else if (pitch == Thrust_Negative)
	{
		thrustersPitchNeg.push_back(fd);
	}
	
	if (yaw == Thrust_Positive)
	{
		thrustersYawPos.push_back(fd);
	}
	else if (yaw == Thrust_Negative)
	{
		thrustersYawNeg.push_back(fd);
	}
	
	if (roll == Thrust_Positive)
	{
		thrustersRollPos.push_back(fd);
	}
	else if (roll == Thrust_Negative)
	{
		thrustersRollNeg.push_back(fd);
	}
	
	// Register thruster with general group that's closed at shutdown
	
	fdAttitudeThruster.push_back(fd);

	return true;
}

void _setGroup(const vector<int> &in fds, float power)
{
	for (uint i = 0; i < fds.size(); i++)
	{
		// Send control code to device
		vector<var> controlCode = {Control_Thruster_Power, power};
		write(fds[i], controlCode);
	}
}


// ---------------------------------------------------------

void SetGroup(ThrusterGroup group, float power)
{
	vector<int>@ deviceGroup;
	switch(group)
	{
		case Thrusters_All:
			@deviceGroup = @fdAttitudeThruster;
			break;
		case Pitch_Positive:
			@deviceGroup = @thrustersPitchPos;
		break;
		case Pitch_Negative:
			@deviceGroup = @thrustersPitchNeg;
		break;
		case Yaw_Positive:
			@deviceGroup = @thrustersYawPos;
		break;
		case Yaw_Negative:
			@deviceGroup = @thrustersYawNeg;
		break;
		case Roll_Positive:
			@deviceGroup = @thrustersRollPos;
		break;
		case Roll_Negative:
			@deviceGroup = @thrustersRollNeg;
		break;
	}
	
	_setGroup(deviceGroup, power);
}

void SetEngine(float power)
{
	vector<var> controlCode = {Control_Thruster_Power, power};
	write(fdMainEngine, controlCode);
}

// ---------------------------------------------------------

// TODO add to standard headers
void perror(string str)
{
	log(str + " : errno (TODO)");
}

/** Initialise thrusters for MPS */
bool InitialiseDevices()
{
	// Thruster devices specify contribution to: Pitch, Yaw, Roll
	
	// Front Thrusters
	
	if (!_initialiseThruster("/dev/thruster0",
		Thrust_Negative, Thrust_None, Thrust_Positive))
	{
		perror("Left Top Front : Up");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster1",
		Thrust_None, Thrust_Negative, Thrust_Negative))
	{
		perror("Left Top Front : Left");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster2",
		Thrust_None, Thrust_Negative, Thrust_Positive))
	{
		perror("Left Bottom Front : Left");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster3",
		Thrust_Positive, Thrust_None, Thrust_Negative))
	{
		perror("Left Bottom Front : Down");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster4",
		Thrust_Positive, Thrust_None, Thrust_Positive))
	{
		perror("Right Bottom Front : Down");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster5",
		Thrust_None, Thrust_Positive, Thrust_Negative))
	{
		perror("Right Bottom Front : Right");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster6",
		Thrust_None, Thrust_Positive, Thrust_Positive))
	{
		perror("Right Top Front : Right");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster7",
		Thrust_Negative, Thrust_None, Thrust_Negative))
	{
		perror("Right Top Front : Up");
		return false;
	}
	
	// NOTE /dev/thruster8 is the central engine responsible for forward propulsion
	
	// Back Thrusters
	
	if (!_initialiseThruster("/dev/thruster9",
		Thrust_Positive, Thrust_None, Thrust_Positive))
	{
		perror("Left Top Back : Up");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster10",
		Thrust_None, Thrust_Positive, Thrust_Negative))
	{
		perror("Left Top Back : Left");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster11",
		Thrust_None, Thrust_Positive, Thrust_Positive))
	{
		perror("Left Bottom Back : Left");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster12",
		Thrust_Negative, Thrust_None, Thrust_Negative))
	{
		perror("Left Bottom Back : Down");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster13",
		Thrust_Negative, Thrust_None, Thrust_Positive))
	{
		perror("Right Bottom Back : Down");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster14",
		Thrust_None, Thrust_Negative, Thrust_Negative))
	{
		perror("Right Bottom Back : Right");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster15",
		Thrust_None, Thrust_Negative, Thrust_Positive))
	{
		perror("Right Top Back : Right");
		return false;
	}
	
	if (!_initialiseThruster("/dev/thruster16",
		Thrust_Positive, Thrust_None, Thrust_Negative))
	{
		perror("Right Top Back : Up");
		return false;
	}

	// --------------------------------------------------------
	
	fdMainEngine = open("/dev/thruster8", O_WRONLY);

	if (fdMainEngine == -1)
	{
		log("Failed opening the main engine device!");
		return false;
	}
	
	// --------------------------------------------------------
	
	// log("### Sidestick : " + fdSidestick);
	// log("### Engine : " + fdMainEngine);
	// for (uint i = 0; i < fdAttitudeThruster.size(); i++)
	// {
		// log("### Thruster" + i + " : " + fdAttitudeThruster[i]);
	// }
	
	return true;
}

bool ShutdownDevices()
{
	for (uint i = 0; i < fdAttitudeThruster.size(); i++)
	{
		if (close(fdAttitudeThruster[i]) == -1)
		{
			perror("Failed closing attitude thruster" + i);
			return false;
		}
	}
	
	if (close(fdMainEngine) == -1)
	{
		perror("Failed closing main engine");
		return false;
	}
	
	return true;
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}
