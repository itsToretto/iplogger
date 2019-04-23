#include "iplogger.inc"

CMD:iplogger(playerid) 
    return ShowPlayerDialog(playerid, DIALOG_IPINDEX, DIALOG_STYLE_INPUT, "IP Logger - Index", "{FFFFFF}Enter the player's full name below:", "Submit", "Cancel");