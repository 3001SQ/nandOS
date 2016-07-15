// -----------------------------------------------------------------------------
// flightcontrol.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Basic attitude controls, reads actual navigation data but not used yet

// ---------------------------------------------------------

// AngelScript libraries
#include "/lib/libX17.as"
#include "/lib/libThrusters.as"

//   Guidance: Generate desired process variables
// Navigation: Prepare sensor data as measured process variables
//    Control: Calculate control values, impose restrictions, smoothing

// Input: Process variables (measured, desired) -> error, command variables -> control variables 

// PID control - Proportional-Integral-Derivative control
// previous_error = 0
// integral = 0 
// start:
//	error = setpoint - measured_value
//	integral = integral + error*dt
//	derivative = (error - previous_error)/dt
//	output = Kp*error + Ki*integral + Kd*derivative
//	previous_error = error
//	wait(dt)
//	goto start

// ---------------------------------------------------------

class NavigationData
{
	vec3 position;
	vec3 orientationAngles;
	vec3 linearVelocity;
	vec3 angularVelocity;	

	quat toGlobalAngles;
	quat toLocalAngles;
	vec3 localAngularVelocity;

	// -----------------------------------------------------
	
	vec3 ToGlobalAngles(vec3 localAngles)
	{
		return toGlobalAngles * quat(localAngles);
	}
	
	vec3 ToLocalAngles(vec3 globalAngles)
	{
		return toLocalAngles * quat(globalAngles);
	}
	
	// -----------------------------------------------------
		
	string opImplConv()
	{
		string s = "NavigationData:\n";
		s += "    Position: " + position + "\n";
		s += " Orientation: " + degrees(orientationAngles) + "\n";
		s += " LinVelocity: " + linearVelocity + "\n";
		s += " AngVelocity: " + degrees(angularVelocity) + "\n";
		s += "LAngVelocity: " + degrees(localAngularVelocity) + "\n";
		
		return s;
	}
}

NavigationData navigationData;

// ---------------------------------------------------------

namespace ControlData
{
	enum Axis
	{
		Axis_X = 0,
		Axis_Y,
		Axis_Z
	}
	
	Axis GetDominantAxis(vec3 v)
	{
		vec3 vAbs = abs(v);
		
		if  (vAbs.x > vAbs.y)
		{
			return vAbs.x > vAbs.z ? Axis_X : Axis_Z;
		}
		else
		{
			return vAbs.y > vAbs.z ? Axis_Y : Axis_Z;
		}
	}
}

class ControlData
{
	// Guidance values
	vec3 desiredDestination;
	vec3 desiredOrientationAngles;

	// Derived values, take NavigationData into account
	vec3 desiredLocalAngularVelocity;
	float desiredMainThrust;
	
	// Final deltas
	vec3 angularVelocityDelta;
	float mainThrustDelta;
	
	// -----------------------------------------------------
		
	string opImplConv()
	{
		string s = "ControlData:\n";
		s += "Desired Destination: " + desiredDestination + "\n";
		s += "Desired Orientation: " + degrees(desiredOrientationAngles) + "\n";
		s += "Desired AngVelocity: " + degrees(desiredLocalAngularVelocity) + "\n";
		s += " Desired MainThrust: " + desiredMainThrust + "\n";
		s += "  AngVelocity Delta: " + degrees(angularVelocityDelta) + "\n";
		s += "   MainThrust Delta: " + mainThrustDelta + "\n";
		
		return s;
	}
}

ControlData controlData;

// ---------------------------------------------------------

// Sidestick file descriptor
int fdSidestick;

// Navigation device
int fdNavigation;

// -----------------------------------------------------------------------------

void updateNavigation()
{
	// Incoming navigation data:
	// [0] vec3 : position
	// [1] vec3 : orientationAnglesRadian
	// [2] vec3 : linearVelocity
	// [3] vec3 : angularVelocity
	vector<var> navigationIn;
	
	ssize_t r = read(fdNavigation, navigationIn, 32);
	
	if (r == -1)
	{
		// TODO Check error code
		return;
	}
	
	// -----------------------------------------------------
	
	navigationData.position = navigationIn[0];
	navigationData.orientationAngles = navigationIn[1];
	navigationData.linearVelocity = navigationIn[2];
	navigationData.angularVelocity = navigationIn[3];
	
	quat qOrientation = quat(navigationData.orientationAngles);
	navigationData.toGlobalAngles = qOrientation;
	navigationData.toLocalAngles = inverse(qOrientation);
		
	navigationData.localAngularVelocity =
		navigationData.ToLocalAngles(navigationData.angularVelocity);
	
	// -----------------------------------------------------
	
	// Log navigation data for debugging
	// log(navigationData);
}

// ---------------------------------------------------------
	
void updateControls()
{
	// Incoming sidestick data: 
	// [0] vec4 : normalized axes
	vector<var> sidestickIn;
	
	ssize_t r = read(fdSidestick, sidestickIn, 32);
	
	if (r == -1)
	{
		// No new data on sidestick, continue with last control value
		return;
	}
	else
	{
		vec4 axes = sidestickIn[0];
		
		// The sidestick position changes the desired orientation and destination
			
		// NOTE For now just map control directly onto thruster groups, manual control
		controlData.angularVelocityDelta = vec3(axes.x, axes.y, axes.z);
		// controlData.mainThrustDelta = axes.w;
	}
	
	// -----------------------------------------------------

	// TODO Calculate actually desired velocities from destination/orientation
}

// -----------------------------------------------------------------------------

void controlThrusters()
{
	// Final deltas
	vec3 angularVelocityDeltaAbs = abs(controlData.angularVelocityDelta);

	// Map X sidestick to X-thruster (pitch)
	if (angularVelocityDeltaAbs.x > 0)
	{
		// log("Thrusters x: " + controlData.angularVelocityDelta.x);
	
		if (controlData.angularVelocityDelta.x > 0)
		{
			// log("positive pitch");
			ThrusterControl::SetGroup(ThrusterControl::Pitch_Positive, angularVelocityDeltaAbs.x);
			ThrusterControl::SetGroup(ThrusterControl::Pitch_Negative, 0);
			
			// Update UI
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Bottom, angularVelocityDeltaAbs.x);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Top, angularVelocityDeltaAbs.x);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Top, 0);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Bottom, 0);
		}
		else
		{
			// log("negative pitch");
			ThrusterControl::SetGroup(ThrusterControl::Pitch_Positive, 0);
			ThrusterControl::SetGroup(ThrusterControl::Pitch_Negative, angularVelocityDeltaAbs.x);
			
			// Update UI
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Top, angularVelocityDeltaAbs.x);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Bottom, angularVelocityDeltaAbs.x);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Bottom, 0);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Top, 0);
		}
	}
	
	// Map Y sidestick to Y-thruster (yaw)
	if (angularVelocityDeltaAbs.y > 0)
	{
		// log("Thrusters y: " + controlData.angularVelocityDelta.y);
	
		if (controlData.angularVelocityDelta.y > 0)
		{
			// log("positive yaw");
			ThrusterControl::SetGroup(ThrusterControl::Yaw_Positive, angularVelocityDeltaAbs.y);
			ThrusterControl::SetGroup(ThrusterControl::Yaw_Negative, 0);
			
			// Update UI
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Right, angularVelocityDeltaAbs.y);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Left, angularVelocityDeltaAbs.y);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Left, 0);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Right, 0);
		}
		else
		{	
			// log("negative yaw");
			ThrusterControl::SetGroup(ThrusterControl::Yaw_Positive, 0);
			ThrusterControl::SetGroup(ThrusterControl::Yaw_Negative, angularVelocityDeltaAbs.y);
			
			// Update UI
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Left, angularVelocityDeltaAbs.y);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Right, angularVelocityDeltaAbs.y);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Right, 0);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Left, 0);
		}
	}
	
	// Map Z sidestick to Z-thruster (roll)
	if (angularVelocityDeltaAbs.z > 0)
	{
		// log("Thrusters z: " + controlData.angularVelocityDelta.z);
	
		if (controlData.angularVelocityDelta.z > 0)
		{	
			// log("positive roll");
			ThrusterControl::SetGroup(ThrusterControl::Roll_Positive, angularVelocityDeltaAbs.z);
			ThrusterControl::SetGroup(ThrusterControl::Roll_Negative, 0);
			
			// Update UI
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Roll, angularVelocityDeltaAbs.z);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Roll, angularVelocityDeltaAbs.z);
		}
		else
		{
			// log("negative roll");
			ThrusterControl::SetGroup(ThrusterControl::Roll_Positive, 0);
			ThrusterControl::SetGroup(ThrusterControl::Roll_Negative, angularVelocityDeltaAbs.z);
			
			// Update UI
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Front_Roll, -angularVelocityDeltaAbs.z);
			OverheadDisplayUI::SetThrusterIntensity(OverheadDisplayUI::Group_Back_Roll, -angularVelocityDeltaAbs.z);
		}
	}
	
	// TODO Value 0? Controls oscillate around it probably anyway...
	
	if (length(angularVelocityDeltaAbs) < 0.001)
	{
		// Stop everything
		ThrusterControl::SetGroup(ThrusterControl::Thrusters_All, 0);
	}
	
	// -----------------------------------------------------
	
	float mainThrustDeltaAbs = abs(controlData.mainThrustDelta);
	
	// Main engine
	if (mainThrustDeltaAbs > 0)
	{
		ThrusterControl::SetEngine(controlData.mainThrustDelta);
	}
}

// -----------------------------------------------------------------------------

namespace NavigationUI
{
// -------------------------------------------------------------------
// -------------------------------------------------------------------

// Velocity

X17::TextLabel@ VelocityTitleStatic;

X17::TextLabel@ VelocityTargetStatic;
X17::TextLabel@ VelocityTarget;

X17::TextLabel@ VelocityLinear;
X17::TextArea@ AreaVelocityAnglesStatic;
X17::TextArea@ AreaVelocityAngles;

X17::TextLabel@ VelocityStarStatic;
X17::TextLabel@ VelocityStar;

X17::TextLabel@ VelocityStarLinear;
X17::TextArea@ AreaVelocityAnglesStarStatic;
X17::TextArea@ AreaVelocityAnglesStar;

// Center Navigation

// Distance

X17::TextLabel@ DistanceTitleStatic;

X17::TextLabel@ DistanceTargetStatic;
X17::TextLabel@ DistanceTarget;

X17::TextLabel@ DistanceLength;

X17::TextLabel@ DistanceETAStatic;
X17::TextLabel@ DistanceETA;

X17::TextLabel@ DistanceSurfaceStatic;
X17::TextLabel@ DistanceSurface;

X17::TextLabel@ DistanceSurfaceLength;

X17::TextLabel@ DistanceStarStatic;
X17::TextLabel@ DistanceStar;

X17::TextLabel@ DistanceStarLength;

X17::TextLabel@ DistanceStarETAStatic;
X17::TextLabel@ DistanceStarETA;

// ---------------------------------------------------------

int _fdVideo = -1;

void SetPositionCenter(X17::TextLabel@ label, vec2 center)
{
	label.SetPosition(center - 0.5 * label.GetDimensions());
}

void Initialise()
{
	X17::SetBackgroundTexture(X17::Display_DashboardLeft, int(X17::Display_DashboardLeft));

	// -------------------------------------------------
	
	@VelocityTitleStatic = X17::CreateTextLabel(X17::Display_DashboardLeft);
	VelocityTitleStatic.SetText("VELOCITY");
	VelocityTitleStatic.SetVisible(true);
	VelocityTitleStatic.SetAlpha(1.0);
	VelocityTitleStatic.SetPosition(vec2(0.21, 0.86));
	VelocityTitleStatic.SetStyle(X17::Font_SystemBold, 6,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	
	@VelocityTargetStatic = X17::CreateTextLabel(X17::Display_DashboardLeft);
	VelocityTargetStatic.SetText("TARGET:");
	VelocityTargetStatic.SetVisible(true);
	VelocityTargetStatic.SetAlpha(1.0);
	VelocityTargetStatic.SetPosition(vec2(0.205, 0.745));
	VelocityTargetStatic.SetStyle(X17::Font_SystemBold, 4,
		Display_TextForeground_Cyan, Display_TextBackground_Default);

	string angleLabels = "PITCH:\nYAW:\nROLL:\n";

	@AreaVelocityAnglesStatic = X17::CreateTextArea(X17::Display_DashboardLeft);
	AreaVelocityAnglesStatic.SetText(angleLabels);
	AreaVelocityAnglesStatic.SetPosition(vec2(0.205, 0.615));
	AreaVelocityAnglesStatic.SetVisible(true);
	AreaVelocityAnglesStatic.SetStyle(X17::Font_SystemBold, 3.3, 1.05,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	
	@VelocityStarStatic = X17::CreateTextLabel(X17::Display_DashboardLeft);
	VelocityStarStatic.SetText("STAR:");
	VelocityStarStatic.SetVisible(true);
	VelocityStarStatic.SetAlpha(1.0);
	VelocityStarStatic.SetPosition(vec2(0.21, 0.445));
	VelocityStarStatic.SetStyle(X17::Font_SystemBold, 4,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	
	@AreaVelocityAnglesStarStatic = X17::CreateTextArea(X17::Display_DashboardLeft);
	AreaVelocityAnglesStarStatic.SetText(angleLabels);
	AreaVelocityAnglesStarStatic.SetPosition(vec2(0.205, 0.315));
	AreaVelocityAnglesStarStatic.SetVisible(true);
	AreaVelocityAnglesStarStatic.SetStyle(X17::Font_SystemBold, 3.3, 1.05,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	
	// ---
	
	@VelocityTarget = X17::CreateTextLabel(X17::Display_DashboardLeft);
	VelocityTarget.SetText("Station W1");
	VelocityTarget.SetVisible(true);
	VelocityTarget.SetAlpha(1.0);
	VelocityTarget.SetPosition(VelocityTargetStatic.GetPosition() +
		vec2(VelocityTargetStatic.GetDimensions().x + 0.02, 0.0));
	VelocityTarget.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
		
	@VelocityLinear = X17::CreateTextLabel(X17::Display_DashboardLeft);
	VelocityLinear.SetText("0.0 m/s");
	VelocityLinear.SetVisible(true);
	VelocityLinear.SetAlpha(1.0);
	VelocityLinear.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
	SetPositionCenter(VelocityLinear, vec2(0.53, 0.7));
	
	@AreaVelocityAngles = X17::CreateTextArea(X17::Display_DashboardLeft);
	AreaVelocityAngles.SetText("0 deg/s\n0 deg/s\n0 deg/s\n");
	AreaVelocityAngles.SetPosition(vec2(0.45, 0.615));
	AreaVelocityAngles.SetVisible(true);
	AreaVelocityAngles.SetStyle(X17::Font_System, 3.3, 1.05,
		Display_TextForeground_White, Display_TextBackground_Default);

	@VelocityStar = X17::CreateTextLabel(X17::Display_DashboardLeft);
	VelocityStar.SetText("S-0");
	VelocityStar.SetVisible(true);
	VelocityStar.SetAlpha(1.0);
	VelocityStar.SetPosition(VelocityStarStatic.GetPosition() +
		vec2(VelocityStarStatic.GetDimensions().x + 0.02, 0.0));
	VelocityStar.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
	
	@VelocityStarLinear = X17::CreateTextLabel(X17::Display_DashboardLeft);
	VelocityStarLinear.SetText("0.0 m/s");
	VelocityStarLinear.SetVisible(true);
	VelocityStarLinear.SetAlpha(1.0);
	VelocityStarLinear.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
	SetPositionCenter(VelocityStarLinear, vec2(0.53, 0.4));
	
	@AreaVelocityAnglesStar = X17::CreateTextArea(X17::Display_DashboardLeft);
	AreaVelocityAnglesStar.SetText("0 deg/s\n0 deg/s\n0 deg/s\n");
	AreaVelocityAnglesStar.SetPosition(vec2(0.45, 0.315));
	AreaVelocityAnglesStar.SetVisible(true);
	AreaVelocityAnglesStar.SetStyle(X17::Font_System, 3.3, 1.05,
		Display_TextForeground_White, Display_TextBackground_Default);
	
	// -------------------------------------------------

	X17::SetBackgroundTexture(X17::Display_DashboardRight, int(X17::Display_DashboardRight));
	
	@DistanceTitleStatic = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceTitleStatic.SetText("DISTANCE");
	DistanceTitleStatic.SetVisible(true);
	DistanceTitleStatic.SetAlpha(1.0);
	DistanceTitleStatic.SetPosition(vec2(0.21, 0.86));
	DistanceTitleStatic.SetStyle(X17::Font_SystemBold, 6,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
		
	@DistanceTargetStatic = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceTargetStatic.SetText("TARGET:");
	DistanceTargetStatic.SetVisible(true);
	DistanceTargetStatic.SetAlpha(1.0);
	DistanceTargetStatic.SetPosition(vec2(0.18, 0.745));
	DistanceTargetStatic.SetStyle(X17::Font_SystemBold, 4,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	
	@DistanceETAStatic = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceETAStatic.SetText("ETA:");
	DistanceETAStatic.SetVisible(true);
	DistanceETAStatic.SetAlpha(1.0);
	DistanceETAStatic.SetPosition(vec2(0.18, 0.61));
	DistanceETAStatic.SetStyle(X17::Font_SystemBold, 4,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
		
	@DistanceSurfaceStatic = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceSurfaceStatic.SetText("SURFACE:");
	DistanceSurfaceStatic.SetVisible(true);
	DistanceSurfaceStatic.SetAlpha(1.0);
	DistanceSurfaceStatic.SetPosition(vec2(0.18, 0.546));
	DistanceSurfaceStatic.SetStyle(X17::Font_SystemBold, 4,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	
	@DistanceStarStatic = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceStarStatic.SetText("STAR:");
	DistanceStarStatic.SetVisible(true);
	DistanceStarStatic.SetAlpha(1.0);
	DistanceStarStatic.SetPosition(vec2(0.19, 0.414));
	DistanceStarStatic.SetStyle(X17::Font_SystemBold, 4,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
		
	@DistanceStarETAStatic = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceStarETAStatic.SetText("ETA:");
	DistanceStarETAStatic.SetVisible(true);
	DistanceStarETAStatic.SetAlpha(1.0);
	DistanceStarETAStatic.SetPosition(vec2(0.18, 0.276));
	DistanceStarETAStatic.SetStyle(X17::Font_SystemBold, 4,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	
	// ---
	
	@DistanceTarget = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceTarget.SetText("Station W1");
	DistanceTarget.SetVisible(true);
	DistanceTarget.SetAlpha(1.0);
	DistanceTarget.SetPosition(DistanceTargetStatic.GetPosition() +
		vec2(DistanceTargetStatic.GetDimensions().x + 0.02, 0.0));
	DistanceTarget.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);

	@DistanceLength = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceLength.SetText("1000.15 km");
	DistanceLength.SetVisible(true);
	DistanceLength.SetAlpha(1.0);
	DistanceLength.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
	SetPositionCenter(DistanceLength, vec2(0.5, 0.692));
	
	@DistanceETA = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceETA.SetText("-");
	DistanceETA.SetVisible(true);
	DistanceETA.SetAlpha(1.0);
	DistanceETA.SetPosition(DistanceETAStatic.GetPosition() +
		vec2(DistanceETAStatic.GetDimensions().x + 0.02, 0.0));
	DistanceETA.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
		
	@DistanceSurface = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceSurface.SetText("S-0 B729");
	DistanceSurface.SetVisible(true);
	DistanceSurface.SetAlpha(1.0);
	DistanceSurface.SetPosition(DistanceSurfaceStatic.GetPosition() +
		vec2(DistanceSurfaceStatic.GetDimensions().x + 0.02, 0.0));
	DistanceSurface.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
		
	@DistanceSurfaceLength = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceSurfaceLength.SetText("1200.32 km");
	DistanceSurfaceLength.SetVisible(true);
	DistanceSurfaceLength.SetAlpha(1.0);
	DistanceSurfaceLength.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
	SetPositionCenter(DistanceSurfaceLength, vec2(0.5, 0.501));

	@DistanceStar = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceStar.SetText("S-0");
	DistanceStar.SetVisible(true);
	DistanceStar.SetAlpha(1.0);
	DistanceStar.SetPosition(DistanceStarStatic.GetPosition() +
		vec2(DistanceStarStatic.GetDimensions().x + 0.02, 0.0));
	DistanceStar.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);

	@DistanceStarLength = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceStarLength.SetText("32.14 AU");
	DistanceStarLength.SetVisible(true);
	DistanceStarLength.SetAlpha(1.0);
	DistanceStarLength.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
	SetPositionCenter(DistanceStarLength, vec2(0.5, 0.363));
		
	@DistanceStarETA = X17::CreateTextLabel(X17::Display_DashboardRight);
	DistanceStarETA.SetText("-");
	DistanceStarETA.SetVisible(true);
	DistanceStarETA.SetAlpha(1.0);
	DistanceStarETA.SetPosition(DistanceStarETAStatic.GetPosition() +
		vec2(DistanceStarETAStatic.GetDimensions().x + 0.02, 0.0));
	DistanceStarETA.SetStyle(X17::Font_System, 4,
		Display_TextForeground_White, Display_TextBackground_Default);
}

void DeInitialise()
{
	close(_fdVideo);
}

void UpdateVelocityDisplay()
{
	float v = length(navigationData.linearVelocity);

	float pitch = degrees(navigationData.angularVelocity.x);
	float yaw = degrees(navigationData.angularVelocity.y);
	float roll = degrees(navigationData.angularVelocity.z);

	VelocityLinear.SetText(floatToString(v, 3) + " m/s");
	SetPositionCenter(VelocityLinear, vec2(0.53, 0.7));
	
	VelocityStarLinear.SetText(floatToString(v, 3) + " m/s");
	SetPositionCenter(VelocityStarLinear, vec2(0.53, 0.4));
	
	string anglesText = floatToString(pitch, 2) + " deg/s\n" + 
		floatToString(yaw, 2) + " deg/s\n" + 
		floatToString(roll, 2) + " deg/s\n";
	
	AreaVelocityAngles.SetText(anglesText);
	AreaVelocityAnglesStar.SetText(anglesText);
}

void UpdateDistanceDisplay()
{
	// TODO Dynamic target selection from database
	vec3 stationPosition = vec3(0, 1000, 0);

	DistanceLength.SetText(floatToString(length(navigationData.position - stationPosition), 2) + " m");
	SetPositionCenter(DistanceLength, vec2(0.5, 0.692));

	DistanceSurfaceLength.SetText(floatToString(length(navigationData.position), 2) + " m");
	SetPositionCenter(DistanceSurfaceLength, vec2(0.5, 0.501));
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}

string floatToString(float v, int decimals)
{
	string s = v;
	return s.substr(0, s.find(".") + 1 + decimals);
}

// -----------------------------------------------------------------------------
// Overhead UI for thruster activity
// -----------------------------------------------------------------------------

namespace OverheadDisplayUI
{
// -------------------------------------------------------------------
// -------------------------------------------------------------------

enum ThrusterGroup
{
	Group_FRONT = 0,
	Group_Front_Top = Group_FRONT,
	Group_Front_Bottom,
	Group_Front_Left,
	Group_Front_Right,
	Group_Front_Roll,
	// ---
	Group_BACK,
	Group_Back_Top = Group_BACK,
	Group_Back_Bottom,
	Group_Back_Left,
	Group_Back_Right,
	Group_Back_Roll,
	// ---
	Group_SIZE
}

vector<float> _thrusterIntensity;

X17::TextLabel@ _frontGroupsStatic;
X17::TextArea@ _frontThrustersStatic;
X17::TextArea@ _frontThrusters;

X17::TextLabel@ _backGroupsStatic;
X17::TextArea@ _backThrustersStatic;
X17::TextArea@ _backThrusters;

bool _bUpdateFront;
bool _bUpdateBack;

// ---------------------------------------------------------

void Initialise()
{
	_thrusterIntensity = vector<float>(Group_SIZE);
	
	X17::SetBackgroundTexture(X17::Display_Overhead, int(X17::Display_Overhead));

	@_frontGroupsStatic = X17::CreateTextLabel(X17::Display_Overhead);
	_frontGroupsStatic.SetText("FRONT THRUSTER GROUPS");
	_frontGroupsStatic.SetVisible(true);
	_frontGroupsStatic.SetAlpha(1.0);
	_frontGroupsStatic.SetStyle(X17::Font_SystemBold, 8,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_frontGroupsStatic.SetPosition(vec2(0.018, 0.9));
	
	@_frontThrustersStatic = X17::CreateTextArea(X17::Display_Overhead);
	_frontThrustersStatic.SetText("TOP:\nBOTTOM:\nLEFT:\nRIGHT:\nROLL:\n");
	_frontThrustersStatic.SetPosition(vec2(0.04, 0.7));
	_frontThrustersStatic.SetVisible(true);
	_frontThrustersStatic.SetStyle(X17::Font_SystemBold, 9.0, 1.33,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
		
	@_frontThrusters = X17::CreateTextArea(X17::Display_Overhead);
	_frontThrusters.SetPosition(vec2(_frontThrustersStatic.GetPosition().x + 0.12, 0.7));
	_frontThrusters.SetVisible(true);
	_frontThrusters.SetStyle(X17::Font_System, 9.0, 1.33,
		Display_TextForeground_White, Display_TextBackground_Default);
	
	// ---
	
	@_backGroupsStatic = X17::CreateTextLabel(X17::Display_Overhead);
	_backGroupsStatic.SetText("BACK THRUSTER GROUPS");
	_backGroupsStatic.SetVisible(true);
	_backGroupsStatic.SetAlpha(1.0);
	_backGroupsStatic.SetStyle(X17::Font_SystemBold, 8,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_backGroupsStatic.SetPosition(vec2(0.982 - _backGroupsStatic.GetDimensions().x, 0.9));
	
	@_backThrustersStatic = X17::CreateTextArea(X17::Display_Overhead);
	_backThrustersStatic.SetText("TOP:\nBOTTOM:\nLEFT:\nRIGHT:\nROLL:\n");
	_backThrustersStatic.SetPosition(vec2(0.74, 0.7));
	_backThrustersStatic.SetVisible(true);
	_backThrustersStatic.SetStyle(X17::Font_SystemBold, 9.0, 1.33,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
		
	@_backThrusters = X17::CreateTextArea(X17::Display_Overhead);
	_backThrusters.SetPosition(vec2(_backThrustersStatic.GetPosition().x + 0.12, 0.7));
	_backThrusters.SetVisible(true);
	_backThrusters.SetStyle(X17::Font_System, 9.0, 1.33,
		Display_TextForeground_White, Display_TextBackground_Default);
		
	// ---
	
	_bUpdateFront = true;
	_bUpdateBack = true;
}

void SetThrusterIntensity(ThrusterGroup group, float intensity)
{
	// log("Setting thruster intensity " + group + " " + intensity);
	
	_thrusterIntensity[group] = intensity * 100;
	
	if (group < Group_BACK)
	{
		_bUpdateBack = true;
	}
	else
	{
		_bUpdateFront = true;
	}
}

string floatToString(float f, int decimals = 2, int padding = 4)
{
	string s = string(f);
	
	size_t iSeparator = s.find(".");
	
	// Decimals
	s = s.substr(0, iSeparator + 1 + decimals);
	// Padding
	int fillSpaces = padding - iSeparator;
	for (int iPad = 0; iPad < fillSpaces; iPad++)
	{
		s = " " + s;
	}
	
	return s;
}

void _updateGroups(bool bFront)
{
	X17::TextArea@ area = bFront ? @_frontThrusters : @_backThrusters;
}

void Update()
{
	if (_bUpdateFront)
	{
		string s;
		for (uint iGroup = Group_FRONT; iGroup < Group_BACK; iGroup++)
		{
			s += floatToString(_thrusterIntensity[iGroup]) + "%\n";
		}
		_frontThrusters.SetText(s);
		
		_bUpdateFront = false;
	}
	
	if (_bUpdateBack)
	{
		string s;
		for (uint iGroup = Group_BACK; iGroup < Group_SIZE; iGroup++)
		{
			s += floatToString(_thrusterIntensity[iGroup]) + "%\n";
		}
		_backThrusters.SetText(s);
		
		_bUpdateBack = true;
	}
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}

// -----------------------------------------------------------------------------
// Central UI for target tracking
// -----------------------------------------------------------------------------

namespace CenterDisplayUI
{
// -------------------------------------------------------------------
// -------------------------------------------------------------------

X17::TextLabel@ _targetStatic;

X17::TextLabel@ _targetName;
X17::TextLabel@ _targetAction;

float _inverseRatio;

X17::Bitmap@ _navigationOverlay;
X17::Bitmap@ _navigationElement;

vec2 _elementDimensions;
vec2 _navigationCenter;
float _navigationRadius;

// ---------------------------------------------------------

void Initialise()
{
	X17::SetBackgroundTexture(X17::Display_DashboardCenter, int(X17::Display_DashboardCenter));

	// -------------------------------------------------

	// Top text labels

	@_targetStatic = X17::CreateTextLabel(X17::Display_DashboardCenter);
	_targetStatic.SetText("TARGET");
	_targetStatic.SetVisible(true);
	_targetStatic.SetAlpha(1.0);
	_targetStatic.SetPosition(vec2(0, 0.915));
	_targetStatic.SetStyle(X17::Font_SystemBold, 6,
		Display_TextForeground_Cyan, Display_TextBackground_Default);
	_targetStatic.SetPosition(vec2(0.5 - 0.5 * _targetStatic.GetDimensions().x,
		_targetStatic.GetPosition().y));

	@_targetName = X17::CreateTextLabel(X17::Display_DashboardCenter);
	_targetName.SetVisible(true);
	_targetName.SetAlpha(1.0);
	_targetName.SetPosition(vec2(0, 0.85));
	_targetName.SetStyle(X17::Font_System, 5,
		Display_TextForeground_White, Display_TextBackground_Default);
	SetTarget("Station W1");

	// Central navigation

	_inverseRatio = 1.0 / X17::Displays[X17::Display_DashboardCenter].aspectRatio;

	@_navigationOverlay = X17::CreateBitmap(X17::Display_DashboardCenter, 8);
	_navigationOverlay.SetRect(vec4(0, 0, 1.0, 1.0), vec4(-0.07, 0.24, 1.141, 0.51));
	_navigationOverlay.SetAlpha(0.1);

	_elementDimensions.y = 0.03;
	_elementDimensions.x = _elementDimensions.y * _inverseRatio;
	
	_navigationCenter = vec2(0.5, 0.5);
	_navigationRadius = 0.18;
	
	@_navigationElement = X17::CreateBitmap(X17::Display_DashboardCenter, 9);
	_navigationElement.SetRect(vec4(0, 0, 1.0, 1.0),
		vec4(0.25, 0.25, _elementDimensions.x, _elementDimensions.y));
}

void SetTarget(string name)
{
	_targetName.SetText(name);
	_targetName.SetPosition(vec2(0.5 - 0.5 * _targetName.GetDimensions().x,
		_targetName.GetPosition().y));
}

void SetAction(string name)
{
}

// Smaller scale = less sensitive
const float _navigationScale = 0.5;

void UpdateElement(vec3 localTarget)
{
	vec2 projection = vec2(localTarget.x, localTarget.y);
	vec2 elementPosition = _navigationCenter;
	
	if (length(projection) > 0.0001)
	{
		float scale = _navigationScale * length(projection) / abs(localTarget.z);
		
		if (scale > 1.0 || localTarget.z > 0)
		{
			scale = 1.0;
		}
		elementPosition += _navigationRadius * scale * normalize(projection) * vec2(_inverseRatio, 1);
	}
	
	_navigationElement.SetPosition(elementPosition - 0.5 * _elementDimensions);
}

void Draw()
{
	// Always redraw the center screen to update navigation
	
	// TODO Track multiple targets
	vec3 stationPosition = vec3(0, 1000, 0);
	vec3 diffPosition = stationPosition - navigationData.position;
	vec3 stationLocal = inverse(quat(navigationData.orientationAngles)) * diffPosition;
	
	UpdateElement(stationLocal);

	_navigationElement.Draw();
	_navigationOverlay.Draw();
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}

// -----------------------------------------------------------------------------

bool initialiseDevices()
{
	int fdMode;
	
	// --------------------------------------------------------
	// IN
	// --------------------------------------------------------

	fdSidestick = open("/dev/sidestick", O_RDONLY);

	if (fdSidestick == -1)
	{
		log("Sidestick initialisation failed!");
		return false;
	}

	fdMode = fcntl(fdSidestick, F_GETFL);
	fcntl(fdSidestick, F_SETFL, fdMode | O_NONBLOCK);

	// ---
	
	fdNavigation = open("/dev/nav", O_RDONLY);
	
	if (fdNavigation == -1)
	{
		log("Navigation initialisation failed!");
		return false;
	}
	
	fdMode = fcntl(fdNavigation, F_GETFL);
	fcntl(fdNavigation, F_SETFL, fdMode | O_NONBLOCK);
	
	// --------------------------------------------------------
	// OUT
	// --------------------------------------------------------
	
	if (!ThrusterControl::InitialiseDevices())
	{
		log("Failed to initialise thrusters!");
		return false;
	}
	
	return true;
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Application entry point
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

int main(uint argc, vector<var> &in argv)
{
	log("Starting Flightcontrols");
	
	log("PID=" + getpid() + " PPID=" + getppid());
	
	// --------------------------------------------------------
	
	// X17::bDebug = true;
	
	X17::Initialise("/dev/iq0");
	
	NavigationUI::Initialise();
	
	X17::SetDrawCallback(CenterDisplayUI::Draw);
	CenterDisplayUI::Initialise();
	
	OverheadDisplayUI::Initialise();
	
	// --------------------------------------------------------

	if (!initialiseDevices())
	{
		log("Failed to initialise devices!");
		return 1;
	}
	
	// --------------------------------------------------------

	// Input loop
	while(true)
	{
		// TODO select() input
		
		// Fetch latest navigation data for course corrections
		updateNavigation();
		
		// Determine desired attitude and other values, calculate thruster values
		updateControls();
		
		// Apply thruster controls
		controlThrusters();
		
		// Update UI data
		NavigationUI::UpdateVelocityDisplay();
		NavigationUI::UpdateDistanceDisplay();
		
		OverheadDisplayUI::Update();
		
		// Always update center screen
		X17::RequestDraw(X17::Display_DashboardCenter);
		
		// Render screens that need updates
		X17::Run();
	}

	// --------------------------------------------------------
	
	NavigationUI::DeInitialise();
	
	X17::DeInitialise();
	
	// Release drivce nodes

	if (!ThrusterControl::ShutdownDevices())
	{
		log("Failed to release device nodes!");
		return 3;
	}
	
	if (close(fdSidestick) == -1)
	{
		log("Failed closing sidestick!");
		return 3;
	}
	
	// --------------------------------------------------------
	
	return 0;
}