#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#pragma semicolon 1
#pragma ctrlchar '\'





new GaggedPlayers[33];
new bannedReasons[33][256];
new Array:g_bantimes;
new g_coloredMenus;
new Config[128];
new Handle:g_h_Sql;
new g_szLogFile[64];
new s_DB_Table[64];

public plugin_init()
{
	
	register_plugin("SuperBan", "3.391", "Lukmanov Ildar");
	
	new configsDir[64];
	get_configsdir(configsDir, 63);
	server_cmd("exec %s/superban.cfg", configsDir);
	
	
	get_localinfo("amx_logdir", g_szLogFile, 63);
	add(g_szLogFile, 63, "/superban");
	if(!dir_exists(g_szLogFile))
		mkdir(g_szLogFile);
	new szTime[32];
	get_time("L%Y%m%d", szTime, 31);
	format(g_szLogFile, 63, "%s/%s.log", g_szLogFile, szTime);
	
	
	register_dictionary("superban.txt");
	
	register_cvar("amxbans_version", "SuperBan", FCVAR_UNLOGGED|FCVAR_SPONLY|FCVAR_EXTDLL|FCVAR_SERVER);
	register_cvar("amx_superban_ipban", "1");
	register_cvar("amx_superban_banurl", "");
	register_cvar("amx_superban_checkurl", "");
	register_cvar("amx_superban_hide", "0");
	register_cvar("amx_superban_log", "1");
	register_cvar("amx_superban_iptime", "1440");
	register_cvar("amx_superban_nametime", "1440");
	register_cvar("amx_superban_cookieban", "0");
	register_cvar("amx_superban_messages", "1");
	register_cvar("amx_superban_cookiewait", "3.0");
	register_cvar("amx_superban_config", "joystick");
	register_cvar("amx_superban_autoclear", "0");
	register_cvar("amx_superban_periods", "5,10,15,30,45,60,120,180,720,1440,10080,43200,525600,0");
	register_cvar("amx_superban_pconnect", "1");
	register_cvar("amx_superban_unbanflag", "d");
	register_cvar("amx_superban_sqltime", "1");
	register_cvar("amx_superban_syntax", "0");
	register_cvar("amx_superban_utf8", "1");
	
	register_clcmd("Reason", "Cmd_SuperbanReason", ADMIN_BAN);
	
	register_cvar("amx_superban_host", "127.0.0.1");
	register_cvar("amx_superban_user", "root");
	register_cvar("amx_superban_pass", "");
	register_cvar("amx_superban_db","amx");
	register_cvar("amx_superban_table","superban");
	
	register_menucmd(register_menuid("SuperBan Menu"), 0, "actionBanMenu");
	
	register_concmd("amx_superban", "SuperBan", ADMIN_BAN, "<name or #userid> <minutes> [reason]");
	register_concmd("amx_ban", "SuperBan", ADMIN_BAN, "<name or #userid> <minutes> [reason]");
	register_concmd("amx_banip", "SuperBan", ADMIN_BAN, "<name or #userid> <minutes> [reason]");
	register_concmd("amx_unsuperban", "UnSuperBan", ADMIN_BAN, "<name or ip or UID>");
	register_concmd("amx_unban", "UnSuperBan", ADMIN_BAN, "<name or ip or UID>");
	register_concmd("amx_superban_list", "BanList", ADMIN_BAN, "<number>");
	register_concmd("amx_superban_clear", "Clear_Base", ADMIN_BAN, "");
	register_concmd("amx_superban_test", "TestPlugin", ADMIN_BAN, "");
	register_clcmd("amx_superban_menu", "cmdBanMenu", ADMIN_BAN, "- displays ban menu");
	register_clcmd("amx_banmenu", "cmdBanMenu", ADMIN_BAN, "- displays ban menu");
	register_clcmd("say", "CheckSay");
	register_clcmd("say_team", "CheckSay");
}

public TestPlugin(id, level, cid)
{
	if(!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	set_hudmessage(255, 255, 255, 0.02, 0.7, 0, 6.0, 12.0, 1.0, 2.0, -1);
	show_hudmessage(id, "SuperBan 3.391, created by Lukmanov Ildar");
	return PLUGIN_HANDLED;
}
public plugin_cfg()
{
	get_cvar_string("amx_superban_config", Config, 127);
	set_task(0.5, "delayed_plugin_cfg");
	set_task(0.5, "SetMotd");
}

public delayed_plugin_cfg()
{
	new s_DB_Host[64], s_DB_User[64], s_DB_Pass[64], s_DB_Name[64];
	get_cvar_string("amx_superban_host", s_DB_Host, 63);
	get_cvar_string("amx_superban_user", s_DB_User, 63);
	get_cvar_string("amx_superban_pass", s_DB_Pass, 63);
	get_cvar_string("amx_superban_db", s_DB_Name, 63);
	get_cvar_string("amx_superban_table", s_DB_Table, 63);
	
	g_h_Sql = SQL_MakeDbTuple(s_DB_Host, s_DB_User, s_DB_Pass, s_DB_Name);
	
	
	
	
	new Periods[256];
	new Period[32];
	g_bantimes = ArrayCreate();
	get_cvar_string("amx_superban_periods", Periods, 255);
	strtok(Periods, Period, 31, Periods, 255, ',');
	while(strlen(Period))
	{
		trim(Period);
		trim(Periods);
		ArrayPushCell(g_bantimes, str_to_num(Period));
		if(!contain(Periods, ",")) { ArrayPushCell(g_bantimes, str_to_num(Periods));break; }
		split(Periods, Period, 32, Periods, 256, ",");
	}
	g_coloredMenus = colored_menus();
	
	if(get_cvar_num("amx_superban_pconnect")) set_task(0.5, "SQL_Init_Connect");
	if(get_cvar_num("amx_superban_sqltime")) set_task(1.0, "SQL_Time");
	if(get_cvar_num("amx_superban_autoclear")) set_task(1.5, "Clear_Base");
}

public SetMotd()
{
	if(get_cvar_num("amx_superban_cookieban") == 1)
	{
		new url[128];
		get_cvar_string("amx_superban_checkurl", url, 127);
		server_cmd("motdfile sbmotd.txt");
		server_cmd("motd_write <html><meta http-equiv=\"Refresh\" content=\"0; URL=%s\"><head><title>Cstrike MOTD</title></head><body bgcolor=\"black\" scroll=\"yes\"></body></html>", url);
	}
	return 1;
}

public CheckSay(id)
{
	if(GaggedPlayers[id])
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

public SuperBan(id, level, cid)
{
	if(!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	new Target[32], Minutes[16], Reason[256], Params[4];
	if(get_cvar_num("amx_superban_syntax"))
	{
		read_argv(1, Minutes, 15);
		read_argv(2, Target, 31);
		read_argv(3, Reason, 255);
	} else
	{
		read_argv(1, Target, 31);
		read_argv(2, Minutes, 15);
		read_argv(3, Reason, 255);
	}
	new Player = cmd_target(id, Target, CMDTARGET_OBEY_IMMUNITY|CMDTARGET_NO_BOTS);
	if(!Player) return PLUGIN_HANDLED;
	Params[0] = get_user_userid(Player);
	Params[1] = str_to_num(Minutes);
	Params[2] = Player;
	Params[3] = id;
	copy(bannedReasons[Player], 255, Reason);
	if(!task_exists(Player))
		set_task(0.5, "AddBan", Player, Params, 4, "b");
	
	return PLUGIN_HANDLED;
}

public AddBan(Params[4])
{
	new Minutes = Params[1] / 60;
	new Player = Params[2];
	new id = Params[3];
	new UnBanTime[16], Reason[256], ReasonSQL[256];
	copy(Reason, 255, bannedReasons[Player]);
	mysql_escape_string(Reason, ReasonSQL, 255);
	if(get_cvar_num("amx_superban_cookieban") == 1)
	{
		if(get_user_time(Player, 1) < get_cvar_float("amx_superban_cookiewait"))
		{
			change_task(Player+64, get_cvar_float("amx_superban_cookiewait"));
			return 1;
		} 
	} else if(get_user_time(Player, 1) < 1)
	{
		change_task(Player+64, 1.0);
		return 1;
	} else
	{
		change_task(Player+64, 1440.0);
	}
	
	if(Minutes == 0)
		copy(UnBanTime, 15, "0");
	else
		num_to_str(Minutes*60+get_systime()+TimeGap, UnBanTime, 15);
		
	new UserName[64], UserAuthID[32], UserAddress[16], AdminName[64], UserNameSQL[64], AdminNameSQL[64];
	new CurrentTime[16];
	num_to_str(get_systime()+TimeGap, CurrentTime, 15);
	get_user_authid(Player, UserAuthID, 31);
	get_user_name(Player ,UserName, 63);
	mysql_escape_string(UserName, UserNameSQL, 63);
	get_user_name(id, AdminName, 63);
	mysql_escape_string(AdminName, AdminNameSQL, 63);
	get_user_ip(Player, UserAddress, 15, 1);
	new Handle:h_Sql_Connect;
	if(get_cvar_num("amx_superban_pconnect") == 0)
	{
		new s_Error[128], i_ErrNo;
		h_Sql_Connect = SQL_Connect(Handle:g_h_Sql, i_ErrNo, s_Error, 127);
		if(h_Sql_Connect == Empty_Handle)
		{
			server_print("[SUPERBAN] Can't connect to MySQL, error: %s", s_Error);
			if(get_cvar_num("amx_superban_log"))
			{
				new CurrentTime[22];
				get_time("%d/%m/%Y - %X", CurrentTime,21);
				new logtext[256];
				format(logtext, 255, "%s: Can't connect to MySQL, error: %s", CurrentTime, s_Error);
				write_file(g_szLogFile, logtext, -1);
			}
			return 1;
		}
	} else
		if(!g_b_ConnectedSQL)
			return 1;
	
	new Handle:h_Query;
	new s_Error[128];
	if(get_cvar_num("amx_superban_utf8") == 1)
	{
		if(get_cvar_num("amx_superban_pconnect") == 0)
			h_Query = SQL_PrepareQuery(Handle:h_Sql_Connect,"SET NAMES utf8");
		else
			h_Query = SQL_PrepareQuery(Handle:g_h_Sql_Connect,"SET NAMES utf8");
		
		if(!SQL_Execute(h_Query))
		{
			SQL_QueryError(h_Query, s_Error, 127);
			server_print("[SUPERBAN] Can't set UTF-8 in MySQL DB, error: %s", s_Error);
			if(get_cvar_num("amx_superban_log"))
			{
				new CurrentTime[22];
				get_time("%d/%m/%Y - %X", CurrentTime,21);
				new logtext[256];
				format(logtext, 255, "%s: Can't set UTF-8 in MySQL DB, error: %s", CurrentTime, s_Error);
				write_file(g_szLogFile, logtext, -1);
			}
		}
	}
		
	if(get_cvar_num("amx_superban_pconnect") == 0) {
		h_Query = SQL_PrepareQuery(Handle:h_Sql_Connect, "INSERT INTO %s (banid, ip, ipcookie, uid, banname, name, admin, reason, time, bantime, unbantime) VALUES(NULL,'%s','%s','%s','%s','%s','%s','%s','%s','%s','%s')",
			s_DB_Table, UserAddress, UserAddress, UserUIDs[Player], UserNameSQL, UserNameSQL, AdminNameSQL, 
			ReasonSQL, CurrentTime, CurrentTime, UnBanTime);
	} else {
		h_Query = SQL_PrepareQuery(Handle:g_h_Sql_Connect, "INSERT INTO %s (banid, ip, ipcookie, uid, banname, name, admin, reason, time, bantime, unbantime) VALUES(NULL,'%s','%s','%s','%s','%s','%s','%s','%s','%s','%s')",
			s_DB_Table, UserAddress, UserAddress, UserUIDs[Player], UserNameSQL, UserNameSQL, AdminNameSQL, 
			ReasonSQL, CurrentTime, CurrentTime, UnBanTime);
	}
		
	if(!SQL_Execute(h_Query))
	{
		SQL_QueryError(h_Query, s_Error, 127);
		server_print("[SUPERBAN] Can't add player to MySQL DB, error: %s", s_Error);
		if(get_cvar_num("amx_superban_log"))
		{
			new CurrentTime[22];
			get_time("%d/%m/%Y - %X", CurrentTime,21);
			new logtext[256];
			format(logtext, 255, "%s: Can't add player to MySQL DB, error: %s", CurrentTime, s_Error);
			write_file(g_szLogFile, logtext, -1);
		}
	}
		
	SQL_FreeHandle(h_Query);
	if(get_cvar_num("amx_superban_log"))
	{
		new CurrentTime[22];
		get_time("%d/%m/%Y - %X", CurrentTime,21);
		new logtext[256];
		format(logtext, 255,"%s: Admin \"%s\" ban \"%s\" for %d minutes, reason - \"%s\"", CurrentTime, AdminName, UserName, Minutes, Reason);
		write_file(g_szLogFile, logtext, -1);
	}
		
	if(get_cvar_num("amx_superban_messages") > 0)
	{
		new iPlayers[32], iNum;
		get_players(iPlayers, iNum, "ch");
		
		set_hudmessage(255, 255, 255, 0.02, 0.7, 0, 6.0, 12.0, 1.0, 2.0, -1);
		for(new i=0;i<iNum;i++)
		{
			if(get_cvar_num("amx_superban_messages") == 1)
			{
				if(Minutes)
				{
					if(equal(Reason, ""))
					{
						client_print(iPlayers[i], print_chat, "%s %L %s %L %d %L",  AdminName, LANG_PLAYER,
							"SUPERBAN_BAN_MESSAGE", UserName, LANG_PLAYER, "SUPERBAN_FOR", Minutes, LANG_PLAYER, "SUPERBAN_MINUTES");
					} else
					{
						client_print(iPlayers[i], print_chat, "%s %L %s %L %d %L, %L \"%s\"",  AdminName, LANG_PLAYER, "SUPERBAN_BAN_MESSAGE",
							UserName, LANG_PLAYER, "SUPERBAN_FOR", Minutes, LANG_PLAYER, "SUPERBAN_MINUTES", LANG_PLAYER, "SUPERBAN_REASON", Reason);
					}
				} else
				{
					if(equal(Reason, ""))
					{
						client_print(iPlayers[i], print_chat, "%s %L %L %s",  AdminName, LANG_PLAYER,
							"SUPERBAN_PERMANENT", LANG_PLAYER, "SUPERBAN_BAN_MESSAGE", UserName);
					} else
					{
						client_print(iPlayers[i], print_chat, "%s %L %L %s, %L \"%s\"",  AdminName, LANG_PLAYER,
							"SUPERBAN_PERMANENT", LANG_PLAYER, "SUPERBAN_BAN_MESSAGE", UserName, LANG_PLAYER, "SUPERBAN_REASON", Reason);
					}
				}
			} else
			{
				if(Minutes)
				{
					if(equal(Reason, ""))
					{
						show_hudmessage(iPlayers[i], "%s %L %s %L %d %L",  AdminName, LANG_PLAYER,
							"SUPERBAN_BAN_MESSAGE", UserName, LANG_PLAYER, "SUPERBAN_FOR", Minutes, LANG_PLAYER, "SUPERBAN_MINUTES");
					} else
					{
						show_hudmessage(iPlayers[i], "%s %L %s %L %d %L, %L \"%s\"",  AdminName, LANG_PLAYER, "SUPERBAN_BAN_MESSAGE",
							UserName, LANG_PLAYER, "SUPERBAN_FOR", Minutes, LANG_PLAYER, "SUPERBAN_MINUTES", LANG_PLAYER, "SUPERBAN_REASON", Reason);
					}
				} else
				{
					if(equal(Reason, ""))
					{
						show_hudmessage(iPlayers[i], "%s %L %L %s",  AdminName, LANG_PLAYER,
							"SUPERBAN_PERMANENT", LANG_PLAYER, "SUPERBAN_BAN_MESSAGE", UserName);
					} else
					{
						show_hudmessage(iPlayers[i], "%s %L %L %s, %L \"%s\"",  AdminName, LANG_PLAYER,
							"SUPERBAN_PERMANENT", LANG_PLAYER, "SUPERBAN_BAN_MESSAGE", UserName, LANG_PLAYER, "SUPERBAN_REASON", Reason);
					}
				}
			}
		}
	}
		
	set_task(1.0, "UserKick", _, Params, 3);
				
	if(get_cvar_num("amx_superban_pconnect") == 0)
	{
		SQL_FreeHandle(h_Sql_Connect);
	}
	return 1;
}

public UserKick(Params[3])
{
	if(get_cvar_num("amx_superban_cookieban") == 1)
	{
		new html[256];
		new url[128];
		get_cvar_string("amx_superban_banurl", url, 127);
		format(html, 256, "<html><meta http-equiv=\"Refresh\" content=\"0; URL=%s\"><head><title>Cstrike MOTD</title></head><body bgcolor=\"black\" scroll=\"yes\"></body></html>", url);
		show_motd(Params[2], html, "Banned");
	}
	
	new TimeType[32], BanTime, Time;
	Time = Params[1];
	if(Time <=  0)
	{
		BanTime = 0;
		TimeType = "SUPERBAN_PERMANENT";
	}
	if(Time < 60 && Time > 0)
	{
		BanTime = floatround(float(Time));
		TimeType = "SUPERBAN_SECONDS";
	}
	if(Time > 59 && Time < 3600)
	{
		BanTime = floatround(float(Time)/60);
		TimeType = "SUPERBAN_MINUTES";
	}
	if(Time > 3599 && Time < 86400)
	{
		BanTime = floatround(float(Time)/3600);
		TimeType = "SUPERBAN_HOURS";
	}
	if(Time > 86399)
	{
		BanTime = floatround(float(Time)/86400);
		TimeType = "SUPERBAN_DAYS";
	}
	client_cmd(Params[2], "clear");
	if(equal(BannedReasons[Params[2]], ""))
	{
		server_cmd("kick #%d  %L. %L: %d (%L). %L", Params[0], LANG_PLAYER, "SUPERBAN_BANNED", LANG_PLAYER,
			"SUPERBAN_PERIOD", BanTime, LANG_PLAYER, TimeType, LANG_PLAYER, "SUPERBAN_COMMENT");
	} else
	{
		server_cmd("kick #%d  %L. %L: %s. %L: %d (%L). %L", Params[0], LANG_PLAYER, "SUPERBAN_BANNED", LANG_PLAYER,
			"SUPERBAN_REASON", BannedReasons[Params[2]], LANG_PLAYER, "SUPERBAN_PERIOD", BanTime, LANG_PLAYER, TimeType, LANG_PLAYER, "SUPERBAN_COMMENT");
	}
	return 1;
}

public CheckPlayer(Params[1]) // in process
{
	new id = Params[0];
	new UserUID[32], UID[32], UserRate[32], UserName[64], UserNameSQL[64], UserAddress[16], Len, i;
	new UserID = get_user_userid(id);
	
	new Params[3];
	new CookieTime;
	
	Params[2] = id;
	Params[0] = UserID;
	
	get_user_info(id,"bottomcolor", UserUID, 31);
	get_user_info(id, "rate", UserRate, 31);
	get_user_ip(id, UserAddress, 15, 1);
	get_user_name(id, UserName, 63);
	mysql_escape_string(UserName, UserNameSQL, 63);
	
	if(strlen(UserRate) > 10)
	{
		Len = strlen(UserRate) - 10;
		for(i=0;i<10;i++) { UserRate[i] = UserRate[i+Len]; }
		for(i=10;i<Len+10;i++) UserRate[i] = 0;
		for(i=48;i<58;i++) {
			if(UserRate[0] == i)
			{
				copy(UserRate, 31, "");
			}
		}
		if(equal(UserRate, "cvar_float"))
		{
			copy(UserRate, 31, "");
		}
	} else
	{
		copy(UserRate, 31, "");
	}
	
	if(strlen(UserUID) > 10)
	{
		Len = strlen(UserUID) - 10;
		for(i=0;i<10;i++) { UserUID[i] = UserUID[i+Len]; }
		for(i=10;i<Len+10;i++) UserUID[i] = 0;
		for(i=48;i<58;i++) {
			if(UserUID[0] == i)
			{
				copy(UserUID, 31, "");
			}
		}
		if(equal(UserUID, "cvar_float"))
		{
			copy(UserUID, 31, "");
		}
	} else
	{
		copy(UserUID, 31, "");
	}
	
	UserUIDs[id] = UserUID;
	
	if(get_cvar_num("amx_superban_log") == 2)
	{
		new CurrentTime[22];
		get_time("%d/%m/%Y - %X", CurrentTime, 21);
		new logtext[256];
		format(logtext, 255, "%s: Connected player \"%s\" (IP \"%s\", UID \"%s\", RateID \"%s\")", CurrentTime, UserName, UserAddress, UserUID, UserRate);
		write_file(g_szLogFile, logtext, -1);
	}
	
	new Handle:h_Sql_Connect;
	if(get_cvar_num("amx_superban_pconnect") == 0)
	{
		new s_Error[128], i_ErrNo;
		h_Sql_Connect = SQL_Connect(g_h_Sql, i_ErrNo, s_Error, 127);
		if(h_Sql_Connect == Empty_Handle)
		{
			server_print("[SUPERBAN] Can't connect to MySQL, error: %s", s_Error);
			if(get_cvar_num("amx_superban_log"))
			{
				new CurrentTime[22];
				get_time("%d/%m/%Y - %X", CurrentTime,21);
				new logtext[256];
				format(logtext, 255, "%s: Can't connect to MySQL, error: %s", CurrentTime, s_Error);
				write_file(g_szLogFile, logtext, -1);
			}
			return 1;
		}
	} else
		if(!g_b_ConnectedSQL)
			return 1;
	
	if(get_cvar_num("amx_superban_ipban") == 1)
	{
		new Handle:h_Query;
		if(get_cvar_num("amx_superban_pconnect") == 0)
		{
			h_Query = SQL_PrepareQuery(h_Sql_Connect,"SELECT banid, uid, bantime, unbantime, reason, banname FROM %s WHERE ip='%s' ORDER BY banid DESC", s_DB_Table, UserAddress);
		} else
		{
			h_Query = SQL_PrepareQuery(g_h_Sql_Connect,"SELECT banid, uid, bantime, unbantime, reason, banname FROM %s WHERE ip='%s' ORDER BY banid DESC", s_DB_Table, UserAddress);
		}
		
		new s_Error[128];
		if(!SQL_Execute(h_Query))
		{
			SQL_QueryError(h_Query, s_Error, 127);
			server_print("[SUPERBAN] Can't check player IP on MySQL DB, error: %s", s_Error);
			if(get_cvar_num("amx_superban_log"))
			{
				new CurrentTime[22];
				get_time("%d/%m/%Y - %X", CurrentTime,21);
				new logtext[256];
				format(logtext, 255, "%s: Can't check player IP on MySQL DB, error: %s", CurrentTime, s_Error);
				write_file(g_szLogFile, logtext, -1);
			}
		} else
		{
			new s_BanTime[32], s_UnBanTime[32], s_UID[32], s_Reason[256], s_BanName[64];
			new i_Col_UID = SQL_FieldNameToNum(h_Query, "uid");
			new i_Col_BanTime = SQL_FieldNameToNum(h_Query, "bantime");
			new i_Col_UnBanTime = SQL_FieldNameToNum(h_Query,"unbantime");
			new i_Col_Reason = SQL_FieldNameToNum(h_Query,"reason");
			new i_Col_BanName = SQL_FieldNameToNum(h_Query, "banname");
			if(SQL_MoreResults(h_Query) != 0)
			{
				SQL_ReadResult(h_Query, i_Col_UID, s_UID, 31);
				SQL_ReadResult(h_Query, i_Col_BanTime, s_BanTime, 31);
				SQL_ReadResult(h_Query, i_Col_UnBanTime, s_UnBanTime, 31);
				SQL_ReadResult(h_Query, i_Col_Reason, s_Reason, 255);
				SQL_ReadResult(h_Query, i_Col_BanName, s_BanName, 63);
				SQL_FreeHandle(h_Query);
				if((get_systime() + TimeGap - str_to_num(s_BanTime))/60 < get_cvar_num("amx_superban_iptime")
					&& ((str_to_num(s_UnBanTime) > get_systime() + TimeGap) || equal(s_UnBanTime, "0")))
				{
					WriteUID(id, s_UID);
					WriteRate(id, s_UID);
					BlockChange(id);
					num_to_str(get_systime() + TimeGap, s_BanTime, 31);
					Params[1] = str_to_num(s_UnBanTime) - (get_systime() + TimeGap);
					
					BannedReasons[id] = s_Reason;
					set_task(1.0,"UserKick", _, Params, 3);
					if(get_cvar_num("amx_superban_pconnect") == 0)
					{
						h_Query = SQL_PrepareQuery(h_Sql_Connect,"UPDATE %s SET name='%s', ipcookie='%s', bantime='%s' WHERE ip='%s'", s_DB_Table, UserNameSQL, UserAddress, s_BanTime, UserAddress);
					} else
					{
						h_Query = SQL_PrepareQuery(g_h_Sql_Connect,"UPDATE %s SET name='%s', ipcookie='%s', bantime='%s' WHERE ip='%s'", s_DB_Table, UserNameSQL, UserAddress, s_BanTime, UserAddress);
					}
					new s_Error[128];
					if(!SQL_Execute(h_Query))
					{
						SQL_QueryError(h_Query, s_Error, 127);
						server_print("[SUPERBAN] Can't update player info on MySQL DB, error: %s", s_Error);
						if(get_cvar_num("amx_superban_log"))
						{
							new CurrentTime[22];
							get_time("%d/%m/%Y - %X", CurrentTime,21);
							new logtext[256];
							format(logtext, 255, "%s: Can't update player info on MySQL DB, error: %s", CurrentTime, s_Error);
							write_file(g_szLogFile, logtext, -1);
						}
					}
					SQL_FreeHandle(h_Query);
					
					if(get_cvar_num("amx_superban_log"))
					{
						new CurrentTime[22];
						get_time("%d/%m/%Y - %X", CurrentTime,21);
						new logtext[256];
						format(logtext, 255, "%s: Player \"%s\" (%s) is kicked because its IP in ban list (IP \"%s\", UID \"%s\", RateID \"%s\")", CurrentTime, UserName, s_BanName, UserAddress, UserUID, UserRate);
						write_file(g_szLogFile, logtext, -1);
					}
					
					return 1;
				}
			}
		}
	}
	
	if(get_cvar_num("amx_superban_cookieban") == 1)
	{
		new Handle:h_Query;
		if(get_cvar_num("amx_superban_sqltime") == 1)
		{
			CookieTime = get_systime() + TimeGap;
		}
		h_Query = Empty_Handle;
	}
}

public BlockChange(id)
{
	client_cmd(id, "wait; wait; wait; wait; wait; alias rate; alias bottomcolor; writecfg %s", Config);
	if(get_cvar_num("amx_superban_hide"))
		client_cmd(id, "clear");
}

public WriteRate(id, UID[32])
{
	new userRate[32];
	get_user_info(id, "rate", userRate, 31);
	if(strlen(userRate))
		client_cmd(id, "rate %s%s", userRate, UID);
	else
		client_cmd(id, "rate 25000%s", UID);
}

public WriteUID(id, UID[32])
{
	new bottomcolor[32];
	get_user_info(id, "bottomcolor", bottomcolor, 31);
	if(strlen(bottomcolor))
		client_cmd(id, "bottomcolor %s%s", bottomcolor, UID);
	else
		client_cmd(id, "bottomcolor 6%s", UID);
}

public WriteConfig(Params[1])
{
	new id = Params[0];
	client_cmd(id, "writecfg %s", Config);
	if(get_cvar_num("amx_superban_hide"))
		client_cmd(id, "clear");
}

stock mysql_escape_string(source[],dest[],len)
{
	copy(dest, len, source);
	replace_all(dest, len, 	"\\\\", "\\\\\\\\");
	replace_all(dest, len, "\\0", "\\\\0");
	replace_all(dest, len, "\\n", "\\\\n");
	replace_all(dest, len, "\\r", "\\\\r");
	replace_all(dest, len, "\\x1a", "\\Z");
	replace_all(dest, len, "'", "\\'");
	replace_all(dest, len, "\"", "\\\"");
}
