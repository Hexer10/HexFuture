/*
 * HexFuture Plugin.
 * by: Hexer10
 * https://github.com/Hexer10/HexFuture
 * 
 * Copyright (C) 2016-2017 Mattia (Hexer10 | Hexah | Papero)
 *
 * This file is part of the HexFuture SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colors>
#include <hexstocks>

#pragma semicolon 1
#pragma newdecls required


#define PLUGIN_AUTHOR "Hexah | Original by DarthNinja & Chanz(admin_tools)"
#define PLUGIN_VERSION "1.00"


#define PREFIX "{blue}[Future]{default}"


ArrayList hFutureArray = null;
ArrayList hFutureCmdArray = null;


public Plugin myinfo = 
{
	name = "Hex-Future", 
	author = PLUGIN_AUTHOR, 
	description = "Issue a command to be done in the future!", 
	version = PLUGIN_VERSION, 
	url = "csitajb.it"
};

public void OnPluginStart()
{
	LoadTranslations("core.phrases.txt");
	
	RegAdminCmd("sm_future", Cmd_Future, ADMFLAG_GENERIC, "Allow admins to issue a command to the future");
	RegConsoleCmd("sm_futurelist", Cmd_FutureList, "See all the running futures");
	RegConsoleCmd("sm_futurekill", Cmd_FutureList, "Kill a running future");
}

//Command
public Action Cmd_Future(int client, int args)
{
	if (args < 4) //Check for sufficend args
	{
		CReplyToCommand(client, "%s Usage: sm_future <interval> <repeats | 0 = infinite> <command>", PREFIX);
		return Plugin_Handled;
	}
	
	//Get args value
	float fInter = GetCmdArgFloat(1);
	int iRep = GetCmdArgInt(2);
	
	if (RoundToCeil(fInter) <= 0) //Check for interval lenght
	{
		CReplyToCommand(client, "%s The Interval must be greater than {blue}0", PREFIX);
		return Plugin_Handled;
	}
	
	char sCommand[256];
	
	for (int i = 3; i <= args; i++) //Loop the args the get only the cmd, so not needed the " "
	{
		char sArg[64];
		GetCmdArg(i, sArg, sizeof(sArg));
		TrimString(sArg);
		
		Format(sCommand, sizeof(sArg), "%s %s", sCommand, sArg);
	}
	
	if (sCommand[0] == '\0') //Check for valid cmd
	{
		CReplyToCommand(client, "%s The Cmd seems invalid", PREFIX);
		return Plugin_Handled;
	}
	
	Handle hTimer;
	DataPack Datapack;
	
	hTimer = CreateDataTimer(fInter, Timer_Future, Datapack, TIMER_FLAG_NO_MAPCHANGE); //Create datatimer
	Datapack.WriteCell(client != 0 ? GetClientUserId(client) : -1);
	Datapack.WriteFloat(fInter);
	Datapack.WriteCell(iRep != 0 ? iRep : -1);
	Datapack.WriteString(sCommand);
	
	int iIndex = hFutureArray.Push(hTimer); //Push timers handle to array
	hFutureCmdArray.PushString(sCommand);
	
	Datapack.WriteCell(iIndex);
	
	CReplyToCommand(client, "%s Create Future:", PREFIX); //Print timer infos
	CReplyToCommand(client, "{blue}ID:{default} %i", iIndex);
	CReplyToCommand(client, "{blue}Cmd:{default} %s", sCommand);
	
	LogMessage("[Future] Cmd in the future was issue by %N, Cmd: %s, Every: %.1f, Repeats: %i", sCommand, fInter, iRep);
	
	return Plugin_Handled;
}

public Action Cmd_FutureKill(int client, int args)
{
	if (!CheckAccess(GetUserAdmin(client), "sm_future", ADMFLAG_GENERIC, false))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	
	if (args != 1) //Check for args
	{
		CReplyToCommand(client, "%s Usage: sm_futurekill <Future ID>", PREFIX);
		return Plugin_Handled;
	}
	
	int iIndex = GetCmdArgInt(1); //Get args
	
	if ((iIndex > GetArraySize(hFutureArray)) || iIndex < 0) //Check for valid ID
	{
		CReplyToCommand(client, "Invalid Future ID");
		return Plugin_Handled;
	}
	
	Handle hTimer = hFutureArray.Get(iIndex); //Get the array pos of timer
	
	if (hTimer != null) //Kill timer
	{
		hTimer.Close();
		hTimer = null;
	}
	
	
	hFutureArray.Erase(iIndex); //Remove datas from array
	hFutureCmdArray.Erase(iIndex);
	
	CReplyToCommand(client, "%s Killed Future with id {blue}%i", PREFIX, iIndex);
	return Plugin_Handled;
}

public Action Cmd_FutureList(int client, int args)
{
	if (!CheckAccess(GetUserAdmin(client), "sm_future", ADMFLAG_GENERIC, false))
	{
		ReplyToCommand(client, "%t", "No Access");
		return Plugin_Handled;
	}
	char sCmd[256];
	
	if (GetArraySize(hFutureArray) == 0) //Check for almost one future running
	{
		CReplyToCommand(client, "%s No Future found", PREFIX);
		return Plugin_Handled;
	}
	
	for (int i = 0; i <= GetArraySize(hFutureArray) - 1; i++) //Loop the future
	{
		hFutureCmdArray.GetString(i, sCmd, sizeof(sCmd));
		CReplyToCommand(client, "%s ID: {darkred}%i | CMD: {blue}%s", PREFIX, i, sCmd);
	}
	return Plugin_Handled;
}


//Timer
public Action Timer_Future(Handle timer, DataPack Datapack)
{
	Datapack.Reset(); //Reset pack pos
	
	char sCommand[256];
	
	int iUserId = Datapack.ReadCell(); //Read pack datas
	float fInter = Datapack.ReadFloat();
	int iRep = Datapack.ReadCell();
	Datapack.ReadString(sCommand, sizeof(sCommand));
	int iIndex = Datapack.ReadCell();
	
	int client = GetClientOfUserId(iUserId); //Get client index
	
	if (!IsValidClient(client, true, true) && iUserId != -1) //Check for valid client
		return Plugin_Continue;
	
	if (iRep == 0) //No more repeats lefted
	{
		return Plugin_Continue;
	}
	
	if (iUserId == -1) //Client is the console
	{
		ServerCommand(sCommand);
	}
	else
	{
		FakeClientCommand(client, sCommand); //Do the cmd
	}
	
	iRep--; //Decrease the rep count
	
	Handle hTimer;
	
	DataPack NewData;
	hTimer = CreateDataTimer(fInter, Timer_Future, NewData, TIMER_FLAG_NO_MAPCHANGE); //ReCreate tuner
	NewData.WriteCell(iUserId);
	NewData.WriteFloat(fInter);
	NewData.WriteCell(iRep);
	NewData.WriteString(sCommand);
	NewData.WriteCell(iIndex);
	
	hFutureArray.Set(iIndex, hTimer); //Set the timer handle
	return Plugin_Continue;
} 