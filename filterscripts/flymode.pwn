//-------------------------------------------------
//
// This is an example of using the AttachCameraToObject function
// to create a no-clip flying camera.
//
// h02 2012
//
// SA-MP 0.3e and above
//
//-------------------------------------------------

#include <a_samp>
#include <JunkBuster>
#include <soc_defines>
#include <strlib>

new g_szSprintfBuffer[1024];

// Players Move Speed
#define MOVE_SPEED              100.0
#define ACCEL_RATE              0.03

// Players Mode
#define CAMERA_MODE_NONE    	0
#define CAMERA_MODE_FLY     	1

// Key state definitions
#define MOVE_FORWARD    		1
#define MOVE_BACK       		2
#define MOVE_LEFT       		3
#define MOVE_RIGHT      		4
#define MOVE_FORWARD_LEFT       5
#define MOVE_FORWARD_RIGHT      6
#define MOVE_BACK_LEFT          7
#define MOVE_BACK_RIGHT         8

// Enumeration for storing data about the player
enum noclipenum
{
	cameramode,
	flyobject,
	mode,
	lrold,
	udold,
	lastmove,
	Float:accelmul
}
new noclipdata[MAX_PLAYERS][noclipenum];

stock spect(playerid, l = 2)
{
	if( !l )
	{
		TogglePlayerSpectating(playerid, false);
	}
	if(l == 1)
	{
		if(!get.spec[playerid])
		{
			/* ------ */
			set.spec[playerid] = 1;
			new _wep, _ammo;
			for(new i; i < 13; i++)
			{
				GetPlayerWeaponData(playerid, i, _wep, _ammo);
				if(_wep)
				{
					SetPVarInt(playerid, F("gun%i",i), _wep);
				}
			}

			/* ------ */
			new Float:x,Float:y,Float:z;
			GetPlayerPos(playerid, x,y,z);
			fset.spect_x[playerid] = x;
			fset.spect_y[playerid] = y;
			fset.spect_z[playerid] = z;

			/* ------- */
			set.spec_skin[playerid] = GetPlayerSkin(playerid);

			/* ------- */
			TogglePlayerSpectating(playerid, true);
		}
	}
}

//--------------------------------------------------

public OnFilterScriptExit()
{
	// If any players are still in edit mode, boot them out before the filterscript unloads
	for(new x; x<MAX_PLAYERS; x++)
	{
		if(noclipdata[x][cameramode] == CAMERA_MODE_FLY) CancelFlyMode(x);
	}
	return 1;
}

//--------------------------------------------------

public OnPlayerConnect(playerid)
{
	// Reset the data belonging to this player slot
	noclipdata[playerid][cameramode] 	= CAMERA_MODE_NONE;
	noclipdata[playerid][lrold]	   	 	= 0;
	noclipdata[playerid][udold]   		= 0;
	noclipdata[playerid][mode]   		= 0;
	noclipdata[playerid][lastmove]   	= 0;
	noclipdata[playerid][accelmul]   	= 0.0;
	return 1;
}

//--------------------------------------------------

public OnPlayerCommandText(playerid, cmdtext[])
{
	if(!strcmp(cmdtext, "/flymode", true))
	{
	    // Place the player in and out of edit mode
		if(GetPVarType(playerid, "FlyMode")) CancelFlyMode(playerid);
		else FlyMode(playerid);
		return 1;
	}
	if(!strcmp(cmdtext, "/savecam", true, 8))
	{
	    new Float:x,Float:y,Float:z;
	    GetPlayerCameraPos(playerid,x,y,z);
	    printf("// camPos: %s\nSetPlayerCameraPos(playerid, %f,%f,%f);", cmdtext[8], x,y,z);
	    GetPlayerCameraLookAt(playerid, x,y,z);
	    printf("SetPlayerCameraLookAt(playerid, %f,%f,%f);\n \n", x,y,z);
	    return 1;
	}
	return 0;
}

//--------------------------------------------------

public OnPlayerUpdate(playerid)
{
	if(noclipdata[playerid][cameramode] == CAMERA_MODE_FLY)
	{
		new keys,ud,lr;
		GetPlayerKeys(playerid,keys,ud,lr);

		if(noclipdata[playerid][mode] && (GetTickCount() - noclipdata[playerid][lastmove] > 100))
		{
		    // If the last move was > 100ms ago, process moving the object the players camera is attached to
		    MoveCamera(playerid);
		}

		// Is the players current key state different than their last keystate?
		if(noclipdata[playerid][udold] != ud || noclipdata[playerid][lrold] != lr)
		{
			if((noclipdata[playerid][udold] != 0 || noclipdata[playerid][lrold] != 0) && ud == 0 && lr == 0)
			{   // All keys have been released, stop the object the camera is attached to and reset the acceleration multiplier
				StopPlayerObject(playerid, noclipdata[playerid][flyobject]);
				noclipdata[playerid][mode]      = 0;
				noclipdata[playerid][accelmul]  = 0.0;
			}
			else
			{   // Indicates a new key has been pressed

			    // Get the direction the player wants to move as indicated by the keys
				noclipdata[playerid][mode] = GetMoveDirectionFromKeys(ud, lr);

				// Process moving the object the players camera is attached to
				MoveCamera(playerid);
			}
		}
		noclipdata[playerid][udold] = ud; noclipdata[playerid][lrold] = lr; // Store current keys pressed for comparison next update
		return 0;
	}
	return 1;
}

//--------------------------------------------------

stock GetMoveDirectionFromKeys(ud, lr)
{
	new direction = 0;

    if(lr < 0)
	{
		if(ud < 0) 		direction = MOVE_FORWARD_LEFT; 	// Up & Left key pressed
		else if(ud > 0) direction = MOVE_BACK_LEFT; 	// Back & Left key pressed
		else            direction = MOVE_LEFT;          // Left key pressed
	}
	else if(lr > 0) 	// Right pressed
	{
		if(ud < 0)      direction = MOVE_FORWARD_RIGHT;  // Up & Right key pressed
		else if(ud > 0) direction = MOVE_BACK_RIGHT;     // Back & Right key pressed
		else			direction = MOVE_RIGHT;          // Right key pressed
	}
	else if(ud < 0) 	direction = MOVE_FORWARD; 	// Up key pressed
	else if(ud > 0) 	direction = MOVE_BACK;		// Down key pressed

	return direction;
}

//--------------------------------------------------

stock MoveCamera(playerid)
{
	new Float:FV[3], Float:CP[3];
	GetPlayerCameraPos(playerid, CP[0], CP[1], CP[2]);          // 	Cameras position in space
    GetPlayerCameraFrontVector(playerid, FV[0], FV[1], FV[2]);  //  Where the camera is looking at

	// Increases the acceleration multiplier the longer the key is held
	if(noclipdata[playerid][accelmul] <= 1) noclipdata[playerid][accelmul] += ACCEL_RATE;

	// Determine the speed to move the camera based on the acceleration multiplier
	new Float:speed = MOVE_SPEED * noclipdata[playerid][accelmul];

	// Calculate the cameras next position based on their current position and the direction their camera is facing
	new Float:X, Float:Y, Float:Z;
	GetNextCameraPosition(noclipdata[playerid][mode], CP, FV, X, Y, Z);
	MovePlayerObject(playerid, noclipdata[playerid][flyobject], X, Y, Z, speed);

	// Store the last time the camera was moved as now
	noclipdata[playerid][lastmove] = GetTickCount();
	return 1;
}

//--------------------------------------------------

stock GetNextCameraPosition(move_mode, Float:CP[3], Float:FV[3], &Float:X, &Float:Y, &Float:Z)
{
    // Calculate the cameras next position based on their current position and the direction their camera is facing
    #define OFFSET_X (FV[0]*6000.0)
	#define OFFSET_Y (FV[1]*6000.0)
	#define OFFSET_Z (FV[2]*6000.0)
	switch(move_mode)
	{
		case MOVE_FORWARD:
		{
			X = CP[0]+OFFSET_X;
			Y = CP[1]+OFFSET_Y;
			Z = CP[2]+OFFSET_Z;
		}
		case MOVE_BACK:
		{
			X = CP[0]-OFFSET_X;
			Y = CP[1]-OFFSET_Y;
			Z = CP[2]-OFFSET_Z;
		}
		case MOVE_LEFT:
		{
			X = CP[0]-OFFSET_Y;
			Y = CP[1]+OFFSET_X;
			Z = CP[2];
		}
		case MOVE_RIGHT:
		{
			X = CP[0]+OFFSET_Y;
			Y = CP[1]-OFFSET_X;
			Z = CP[2];
		}
		case MOVE_BACK_LEFT:
		{
			X = CP[0]+(-OFFSET_X - OFFSET_Y);
 			Y = CP[1]+(-OFFSET_Y + OFFSET_X);
		 	Z = CP[2]-OFFSET_Z;
		}
		case MOVE_BACK_RIGHT:
		{
			X = CP[0]+(-OFFSET_X + OFFSET_Y);
 			Y = CP[1]+(-OFFSET_Y - OFFSET_X);
		 	Z = CP[2]-OFFSET_Z;
		}
		case MOVE_FORWARD_LEFT:
		{
			X = CP[0]+(OFFSET_X  - OFFSET_Y);
			Y = CP[1]+(OFFSET_Y  + OFFSET_X);
			Z = CP[2]+OFFSET_Z;
		}
		case MOVE_FORWARD_RIGHT:
		{
			X = CP[0]+(OFFSET_X  + OFFSET_Y);
			Y = CP[1]+(OFFSET_Y  - OFFSET_X);
			Z = CP[2]+OFFSET_Z;
		}
	}
}
//--------------------------------------------------

stock CancelFlyMode(playerid)
{
	DeletePVar(playerid, "FlyMode");
	CancelEdit(playerid);
	spect(playerid, 0);
//	TogglePlayerSpectating(playerid, false);

	DestroyPlayerObject(playerid, noclipdata[playerid][flyobject]);
	noclipdata[playerid][cameramode] = CAMERA_MODE_NONE;
	return 1;
}

//--------------------------------------------------

stock FlyMode(playerid)
{
	// Create an invisible object for the players camera to be attached to
	new Float:X, Float:Y, Float:Z;
	GetPlayerPos(playerid, X, Y, Z);
	noclipdata[playerid][flyobject] = CreatePlayerObject(playerid, 19300, X, Y, Z, 0.0, 0.0, 0.0);

	// Place the player in spectating mode so objects will be streamed based on camera location
	spect(playerid, 1);
//	TogglePlayerSpectating(playerid, true);
	// Attach the players camera to the created object
	AttachCameraToPlayerObject(playerid, noclipdata[playerid][flyobject]);

	SetPVarInt(playerid, "FlyMode", 1);
	noclipdata[playerid][cameramode] = CAMERA_MODE_FLY;
	return 1;
}

//--------------------------------------------------

stock GetPlayerCameraLookAt(playerid, &Float:X, &Float:Y, &Float:Z)
{
    	new
			Float:fPX, Float:fPY, Float:fPZ,
			Float:fVX, Float:fVY, Float:fVZ;

		// Change me to change the scale you want. A larger scale increases the distance from the camera.
		// A negative scale will inverse the vectors and make them face in the opposite direction.
		const
			Float:fScale = 10.0;

		GetPlayerCameraPos(playerid, fPX, fPY, fPZ);
		GetPlayerCameraFrontVector(playerid, fVX, fVY, fVZ);

		X = fPX + floatmul(fVX, fScale);
		Y = fPY + floatmul(fVY, fScale);
		Z = fPZ + floatmul(fVZ, fScale);
		return 0;
}

//--------------------------------------------------
