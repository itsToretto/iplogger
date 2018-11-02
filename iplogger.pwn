#include <a_samp>
#include <a_mysql>
#include <zcmd>
#include <sscanf2>

#define MYSQL_HOSTNAME		"localhost"
#define MYSQL_USERNAME		"root"
#define MYSQL_PASSWORD		""
#define MYSQL_DATABASE		"test"

new MySQL: Database;

enum
{
    DIALOG_IPINDEX,
    DIALOG_IPLOGS,
    DIALOG_IPACTION,
    DIALOG_IPDELETION
}

new 
    g_ConnectionDate[MAX_PLAYERS][64],
    g_DisconnectionDate[MAX_PLAYERS][64],
    g_pIP[MAX_PLAYERS][17],
    g_DialogPage[MAX_PLAYERS],
    g_TargetID[MAX_PLAYERS];

public OnFilterScriptInit()
{
    MySQLConnection();
    return 1;
}

public OnFilterScriptExit()
{
    mysql_close(Database);
    return 1;
}

MySQLConnection()
{
	new MySQLOpt: option_id = mysql_init_options();

	mysql_set_option(option_id, AUTO_RECONNECT, true);

	Database = mysql_connect(MYSQL_HOSTNAME, MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_DATABASE, option_id);
	if (Database == MYSQL_INVALID_HANDLE || mysql_errno(Database) != 0)
	{
		print("MySQL connection failed. Server is shutting down.");
		return SendRconCommand("exit");
	}
	print("MySQL connection is successful.");
	return 1;
}

ReturnName(playerid)
{
    new name[MAX_PLAYER_NAME];
    GetPlayerName(playerid, name, sizeof(name));
    return name;
}

ReturnIP(playerid)
{
    new IP[17];
    GetPlayerIp(playerid, IP, sizeof(IP));
    return IP;
}

ReturnDate()
{
    new time[3], date[3], string[64];

	gettime(time[0], time[1], time[2]); 
    getdate(date[0], date[1], date[2]); 

    switch(date[1]) 
    { 
        case 1: string = "January";
        case 2: string = "Feburary";
        case 3: string = "March";
        case 4: string = "April";
        case 5: string = "May";
        case 6: string = "June";
        case 7: string = "July";
        case 8: string = "August";
        case 9: string = "September";
        case 10: string = "October";
        case 11: string = "November";
        case 12: string = "December";
    }
	format(string, sizeof(string), "%02d %s %d - %02d:%02d:%02d", date[0], string, date[2], time[0], time[1], time[2]); 
    return string;
}

g_IPDialog(playerid)
{
    new query[128], title[48], string[128], dialog[1200];
    mysql_format(Database, query, sizeof(query), "SELECT * FROM `iplogger` WHERE `Name` = '%e' LIMIT %d, 10", g_TargetID[playerid], g_DialogPage[playerid] * 10);
	mysql_query(Database, query);
	new rows = cache_num_rows();
	if(rows) 
    {
        new sql_ip[64], sql_connected[64];

	    for(new i; i < rows; i++)
	    {
            cache_get_value_name(i, "IP", sql_ip);
            cache_get_value_name(i, "Connected", sql_connected);
            format(string, sizeof(string), "{2ECC71}IP: {FFFFFF}%s{2ECC71} - Last connection: {FFFFFF}%s\n", sql_ip, sql_connected);
            strcat(dialog, string);
	    }

        format(title, sizeof(title), "IP Logs of {2ECC71}%s (Page %d)", g_TargetID[playerid], g_DialogPage[playerid]+1);
        ShowPlayerDialog(playerid, DIALOG_IPLOGS, DIALOG_STYLE_LIST, title, dialog, "{FFFFFF}Next", "Back");
	}
    else
    {
        if(g_DialogPage[playerid] > 0)
        {
            g_DialogPage[playerid] = 0;
            return SendClientMessage(playerid, 0x33CCFFFF, "INFO: {FFFFFF}Can't find any more IP Logs records.");
        }
        else
        {
            new str[128];
            format(str, sizeof(str), "ERROR: {FFFFFF}No records found for the player {AFAFAF}%s", g_TargetID[playerid]);
            SendClientMessage(playerid, 0xDE3838FF, str);
        }
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    g_ConnectionDate[playerid] = ReturnDate();
    g_pIP[playerid] = ReturnIP(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    new query[200];
    g_DisconnectionDate[playerid] = ReturnDate();
	mysql_format(Database, query, sizeof(query), "INSERT INTO `iplogger` (`Name`, `IP`, `Connected`, `Disconnected`) VALUES ('%e', '%e', '%e', '%e')",
    ReturnName(playerid), g_pIP[playerid], g_ConnectionDate[playerid], g_DisconnectionDate[playerid]);
	mysql_tquery(Database, query);
    return 1;
}

CMD:ips(playerid, params[])
{    
    ShowPlayerDialog(playerid, DIALOG_IPINDEX, DIALOG_STYLE_INPUT, "IP Logger - Index", "{FFFFFF}Enter the player's full name below:", "Submit", "Cancel");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_IPINDEX:
        {
            if(response)
            {
                if(sscanf(inputtext, "s[24]", g_TargetID[playerid]))
                    return 1;

                new title[64], query[128], dialog[256];
                mysql_format(Database, query, sizeof(query), "SELECT * FROM `iplogger` WHERE `Name` = '%e'", g_TargetID[playerid]);
                mysql_query(Database, query);
                new rows = cache_num_rows();
                
                if(!rows)
                    return SendClientMessage(playerid, 0xDE3838FF, "ERROR: {FFFFFF}Player not found.");

                format(title, sizeof(title), "IP Logs Panel - Managing player {2ECC71}%s", g_TargetID[playerid]);
                format(dialog, sizeof(dialog), "  {FFFF00}> {FFFFFF}Show {2ECC71}%s{FFFFFF}'s IP Logs\n  {FFFF00}> {DE3838}Delete {2ECC71}%s{DE3838}'s IP Logs", g_TargetID[playerid], g_TargetID[playerid]);
                ShowPlayerDialog(playerid, DIALOG_IPACTION, DIALOG_STYLE_LIST, title, dialog, "Submit", "Cancel");
            }
        }
        case DIALOG_IPLOGS:
        {
            if(!response) 
            {
                g_DialogPage[playerid]--;
                if(g_DialogPage[playerid] < 0)
                {
                    g_DialogPage[playerid] = 0;
                    ShowPlayerDialog(playerid, DIALOG_IPINDEX, DIALOG_STYLE_INPUT, "IP Logger - Index", "{FFFFFF}Enter the player's full name below:", "Submit", "Cancel");
                    return 1;
                }
            }
            else
                g_DialogPage[playerid]++;
            
            g_IPDialog(playerid);
            return 1;
        }   
        case DIALOG_IPACTION:
        {
            if(response)
                switch(listitem)
                {
                    case 0: g_IPDialog(playerid);
                    case 1:
                    {
                        new dialog[256];
                        format(dialog, sizeof(dialog), "{FFFFFF}Are you sure you want to {DE3838}delete {2ECC71}%s{FFFFFF}'s IP Logs permanently? \n                            (This action is {DE3838}irreversible{FFFFFF})", g_TargetID[playerid]);
                        ShowPlayerDialog(playerid, DIALOG_IPDELETION, DIALOG_STYLE_MSGBOX, "Confirmation:", dialog, "Delete", "Cancel");
                    } 
                }
            else
                ShowPlayerDialog(playerid, DIALOG_IPINDEX, DIALOG_STYLE_INPUT, "IP Logger - Index", "{FFFFFF}Enter the player's full name below:", "Submit", "Cancel");
        }
        case DIALOG_IPDELETION:
        {
            if(response)
            {
                new query[128], string[128];
                mysql_format(Database, query, sizeof(query), "DELETE FROM iplogger WHERE Name='%e'", g_TargetID[playerid]);
                mysql_query(Database, query);
                format(string, sizeof(string), "INFO: {FFFFFF}You have successfully {DE3838}deleted {AFAFAF}%s{FFFFFF}'s logs.", g_TargetID[playerid]);
                SendClientMessage(playerid, 0x33CCFFFF, string);
            }
            else
                SendClientMessage(playerid, 0x33CCFFFF, "INFO: {FFFFFF}You have canceled the logs deletion.");
        }
    }
    return 0;     
}