/*
 * Prerequirements:
 * put maps_restriction.cfg into cstrike\addons\amxmodx\configs\army_ranks - for those maps bonuses will be restricted
 * put army_ranks.txt into cstrike\addons\amxmodx\data\lang\ - for language translation
*/

#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <colorchat>
#include <core>
#include <fun>
#include <cstrike>
#include <army_ranks_stocks>
#include <hamsandwich>

#define PLUGIN "ARMYRANKS"
#define VERSION "1.1"
#define AUTHOR "sdemian"

#define SQLX_HOST "army_ranks_host"
#define SQLX_DB "army_ranks_db"
#define SQLX_USER "army_ranks_user"
#define SQLX_PASS "army_ranks_pass"
#define SQLX_TABLE "army_ranks_table_name"

new Handle:sql_tuple;

enum player_data {
	user_id,
	exp,
	level,
	temp_id
};

new user_data[33][player_data];

/*
 * this variable restrictes bonus menu for certain maps
*/
new bool:g_bonus_restricted;

/*
 * these variables posses cvars
*/
new g_tk_lost_exp, g_tk_lost_exp_amount, g_show_lup_message_all, g_health_per_level, \
		g_armor_per_level, g_bonus_menu_on;

new const global_ranks[][] = 
{
	"level_0","level_1","level_2","level_3","level_4","level_5","level_6","level_7","level_8","level_9","level_10","level_11","level_12","level_13","level_14",		
	"level_15","level_16","level_17","level_18","level_19","level_20"
};

/*
 * this is experience amount for each level
*/
new const global_levels[] = 
{
	0,15,30,60,100,180,350,750,999,1500,2200,2800,3200,3900,4500,5000,5500,6000,7000,8000
};

new g_msg_hud, max_players;
new bool:is_level_up[33];

/*
 * this macro is taken from string.inc file
 * so when we include string.inc file this can be removed
*/
#define charsmax(%1) (sizeof(%1)-1)

#define MAX_LEVEL 20

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar(SQLX_HOST, "localhost");
	register_cvar(SQLX_DB, "test");
	register_cvar(SQLX_USER, "test");
	register_cvar(SQLX_PASS, "test");
	register_cvar(SQLX_TABLE, "army_ranks");
	
	// lose experience on team kill = 1
	g_tk_lost_exp = register_cvar("tk_lost_exp", "1");
	// how much experience will lose player on team kill = 3
	g_tk_lost_exp_amount = register_cvar("tk_lost_exp_amount", "3");
	// show message about player level up to all = 1
	g_show_lup_message_all	= register_cvar("show_lup_message_all", "1");
	// how much health player gets for each level
	g_health_per_level = register_cvar("health_per_level", "3");
	// how much armor player gets for each level
	g_armor_per_level = register_cvar("armor_per_level", "5");
	// show bonus menu on onRoundStart = 1
	g_bonus_menu_on = register_cvar("bonus_menu_on", "1");
	/*
	 * from amxmodx.inc file
	 * native register_concmd(const cmd[],const function[],flags=-1, const info[]="", FlagManager=-1);
	*/
	register_concmd("drop_army_ranks_table", "drop_table", ADMIN_IMMUNITY, "command drops whole 'army_ranks' table");
	/*
	 * from amxmodx.inc file
	 * native register_event(const event[],const function[],const flags[],const cond[]="", ... );
	 * native register_logevent(const function[], argsnum,  ... );
	*/
	register_event("DeathMsg", "onEventDeath", "a", "1>0");
	register_logevent( "onRoundStart", 2, "1=Round_Start" );
	
	/*
	 * from hamsandwich.inc file
	 * native HamHook:RegisterHam(Ham:function, const EntityClass[], const Callback[], Post=0);
	*/
	RegisterHam(Ham_Spawn, "player", "player_spawned", 1);
	/*
	 * from amxmodx.inc file
	 * native CreateHudSyncObj(num=0, ...);
	*/
	g_msg_hud = CreateHudSyncObj();
	max_players = get_maxplayers();
	register_dictionary("army_ranks.txt");
	set_task(1.0,"showRank",_,_,_, "b")

	g_bonus_restricted = mapDisableCheck( "maps_restriction.cfg" );
}

public plugin_cfg() {
	/*
	 * this function creates table with given information from cvars
	*/
	log_amx("Bonuses on this map is %s", g_bonus_restricted==true?"disabled":"enabled");
	log_amx("Level up messages is turned to show %s", get_pcvar_num(g_show_lup_message_all)==1?"All":"only to player");
	
	sqlCreateTable();
}

public sqlCreateTable() {
	new Handle:sql_connection = createConnection();
	new error[512];	
	new table[64];
	get_cvar_string(SQLX_TABLE, table, charsmax(table));	
	/*
	 * from sqlx.inc file
	 * native Handle:SQL_PrepareQuery(Handle:db, const fmt[], any:...);
	*/
	new Handle:sql_createtable_query = SQL_PrepareQuery(sql_connection, "CREATE TABLE IF NOT EXISTS `%s`(`id` INT(10) NOT NULL AUTO_INCREMENT,`name` VARCHAR(32) NOT NULL,`exp` INT(10) NOT NULL,`level` INT(10) NOT NULL,PRIMARY KEY (id));", table);
	/*
	 * from sqlx.inc
	 * native SQL_Execute(Handle:query);
   * Returns 1 if the query succeeded.
   * Returns 0 if the query failed.
	*/
	if (!SQL_Execute(sql_createtable_query)) {
		/*
		 * from sqlx.inc file
		 * native SQL_QueryError(Handle:query, error[], maxlength);
		*/
		SQL_QueryError(sql_createtable_query, error, charsmax(error));
		log_amx("Error: While SQL_Execute call function: ", error);
		set_fail_state(error);
	} else {
		log_amx("Success: SQL_Execute call executed");
	}
	/*
	 * from sqlx.inc file
	 * native SQL_FreeHandle(Handle:h);
	*/
	SQL_FreeHandle(sql_createtable_query);
	SQL_FreeHandle(sql_connection);
}

public drop_table(id,level,cid) {
	if (!access(id,level)) {
		console_print(id, "[sdemian_sql_dbcreate.amxx] You level is low to drop table");
		return PLUGIN_HANDLED
	}
	new error[512];	
	new Handle:sql_connection = createConnection();
	new table[64];
	get_cvar_string(SQLX_TABLE, table, charsmax(table));	
	/*
	 * from sqlx.inc file
	 * native Handle:SQL_PrepareQuery(Handle:db, const fmt[], any:...);
	*/
	new Handle:sql_createtable_query = SQL_PrepareQuery(sql_connection, "DROP TABLE `%s`", table);
	/*
	 * from sqlx.inc
	 * native SQL_Execute(Handle:query);
   * Returns 1 if the query succeeded.
   * Returns 0 if the query failed.
	*/
	if (!SQL_Execute(sql_createtable_query)) {
		/*
		 * from sqlx.inc file
		 * native SQL_QueryError(Handle:query, error[], maxlength);
		*/
		SQL_QueryError(sql_createtable_query, error, charsmax(error));
		log_amx("Error: While SQL_Execute call function: ", error);
		set_fail_state(error);
	} else {
		log_amx("Success: SQL_Execute call executed");
	}
	/*
	 * from sqlx.inc file
	 * native SQL_FreeHandle(Handle:h);
	*/
	SQL_FreeHandle(sql_createtable_query);
	SQL_FreeHandle(sql_connection);
	
	return PLUGIN_HANDLED
}

public client_putinserver(id) {
	user_data[id] = user_data[0];
	
	loadData(id, "");
}

public client_disconnect(id) {
	saveDate(id);
	
	user_data[id] = user_data[0];
}

public plugin_end() {
	if (sql_tuple != Empty_Handle) {
		/*
		 * from sqlx.inc file
		 * native SQL_FreeHandle(Handle:h);
		*/
		SQL_FreeHandle(sql_tuple);
	}
}

public loadData(id, name[]) {
	new Handle:sql_connection = createConnection();
	new table[64];
	new error[512];	
	new user_name[32];
	new quoted_user_name[64];
	/*
	 * from string.inc file
	 * native equali(const a[],const b[],c=0);
	 * native copy(dest[],len,const src[]);
	*/
	copy(user_name, charsmax(user_name), name);
	if (strlen(user_name) == 0) {
		get_user_name(id, user_name, 31);
	}
	/*
	 * from sqlx.inc file
	 * native SQL_QuoteString(Handle:db, buffer[], buflen, const string[]);
	*/
	SQL_QuoteString(sql_connection, quoted_user_name, charsmax(quoted_user_name), user_name);
	get_cvar_string(SQLX_TABLE, table, charsmax(table));
	/*
	 * from sqlx.inc file
	 * native Handle:SQL_PrepareQuery(Handle:db, const fmt[], any:...);
	*/
	new Handle:sql_select_query = SQL_PrepareQuery(sql_connection, "SELECT `id`, `exp`, `level` FROM `%s` WHERE name = '%s'", table, quoted_user_name);
	/*
	 * from sqlx.inc
	 * native SQL_Execute(Handle:query);
   * Returns 1 if the query succeeded.
   * Returns 0 if the query failed.
	*/
	if (!SQL_Execute(sql_select_query)) {
		/*
		 * from sqlx.inc file
		 * native SQL_QueryError(Handle:query, error[], maxlength);
		*/
		SQL_QueryError(sql_select_query, error, charsmax(error));
		log_amx("Error: While SQL_Execute call function: ", error);
		return;
	}
	/*
	 * At this point we should have some results
	 * Lets process them
	*/
	/*
	 * from sqlx.inc file
	 * native SQL_NumResults(Handle:query);
	*/
	if (SQL_NumResults(sql_select_query) > 0) {
		getUserData(id, sql_select_query);
		check_level(id);
	} else {
		// this is a new player, so lets us register him
		registerPlayer(id, table, quoted_user_name);
	}
	
	/*
	 * from sqlx.inc file
	 * native SQL_FreeHandle(Handle:h);
	*/
	SQL_FreeHandle(sql_select_query);
	SQL_FreeHandle(sql_connection);	
}

public saveDate(id) {
	new Handle:sql_connection = createConnection();
	new table[64];
	new user_name[32];
	new quoted_user_name[64];
	get_user_name(id, user_name, 31);	
	/*
	 * from sqlx.inc file
	 * native SQL_QuoteString(Handle:db, buffer[], buflen, const string[]);
	*/
	SQL_QuoteString(sql_connection, quoted_user_name, charsmax(quoted_user_name), user_name);
	get_cvar_string(SQLX_TABLE, table, charsmax(table));
	new save_query[256];
	format(save_query, charsmax(save_query), "UPDATE `%s` SET `exp` = '%d', `level` = '%d' WHERE `id` = '%d';", table, user_data[id][exp], user_data[id][level], user_data[id][user_id]);
	SQL_ThreadQuery(sql_tuple, "queryHandler", save_query);
	
	/*
	 * from sqlx.inc file
	 * native SQL_FreeHandle(Handle:h);
	*/
	SQL_FreeHandle(sql_connection);		
}

public Handle:createConnection() {
	new host[64], db[64], user[64], pass[64];
	new error[512];
	new error_address;
	/*
	 * from amxmodx.inc
	 * native get_cvar_string(const cvarname[],output[],iLen);
	*/
	get_cvar_string(SQLX_HOST, host, charsmax(host));
	get_cvar_string(SQLX_DB, db, charsmax(db));
	get_cvar_string(SQLX_USER, user, charsmax(user));
	get_cvar_string(SQLX_PASS, pass, charsmax(pass));

	/*
	 * from sqlx.inc file
	 * native Handle:SQL_MakeDbTuple(const host[], const user[], const pass[], const db[], timeout=0);
	*/
	sql_tuple = SQL_MakeDbTuple(host, user, pass, db);
	/*
	 * from sqlx.inc file
	 * native Handle:SQL_Connect(Handle:cn_tuple, &errcode, error[], maxlength);
	*/
	new Handle:sql_connection = SQL_Connect(sql_tuple, error_address, error, charsmax(error));
	if (sql_connection == Empty_Handle) {
		log_amx("Error: While SQL_Connect call function: ", error);
		set_fail_state(error);
	}
	
	return sql_connection;
}

public getUserData(id, Handle:query) {
	/*
	 * from sqlx.inc file
	 * native SQL_ReadResult(Handle:query, column, {Float,_}:...);
	*/
	user_data[id][user_id] = SQL_ReadResult(query, 0);
	user_data[id][exp] = SQL_ReadResult(query, 1);
	user_data[id][level] = SQL_ReadResult(query, 2);
	
	log_amx("Success: get user data for player with id = %d", user_data[id][user_id]);
}

public registerPlayer(id, table[], name[]) {
	new error[512];
	new Handle:sql_connection = createConnection();
	/*
	 * from sqlx.inc file
	 * native Handle:SQL_PrepareQuery(Handle:db, const fmt[], any:...);
	*/
	new Handle:sql_insert_query = SQL_PrepareQuery(sql_connection, "INSERT INTO `%s` (`id`, `name`, `exp`, `level`) VALUES (NULL, '%s', '0', '1')", table, name);
	/*
	 * from sqlx.inc
	 * native SQL_Execute(Handle:query);
   * Returns 1 if the query succeeded.
   * Returns 0 if the query failed.
	*/
	if (!SQL_Execute(sql_insert_query)) {
		/*
		 * from sqlx.inc file
		 * native SQL_QueryError(Handle:query, error[], maxlength);
		*/
		SQL_QueryError(sql_insert_query, error, charsmax(error));
		log_amx("Error: While SQL_Execute call function: ", error);
		return;
	}
	
	/*
	 * fetching id of newly registered player
	 * by name
	*/
	new Handle:sql_select_query = SQL_PrepareQuery(sql_connection, "SELECT `id`, `exp`, `level` FROM `%s` WHERE name = '%s'", table, name);
	if (!SQL_Execute(sql_select_query)) {
		/*
		 * from sqlx.inc file
		 * native SQL_QueryError(Handle:query, error[], maxlength);
		*/
		SQL_QueryError(sql_select_query, error, charsmax(error));
		log_amx("Error: While SQL_Execute call function: ", error);
		return;
	}
	log_amx("Success: Registered new player with name = %s", name);
	
	getUserData(id, sql_select_query);
	/*
	 * from sqlx.inc file
	 * native SQL_FreeHandle(Handle:h);
	*/
	SQL_FreeHandle(sql_insert_query);
	SQL_FreeHandle(sql_select_query);
	SQL_FreeHandle(sql_connection);
}

// Funtion will check a file to see if the mapname exists
bool:mapDisableCheck( file_name[] )
{
	new file[128];
	get_configsdir( file, 127 );
	formatex( file, 127, "%s/army_ranks/%s", file, file_name );

	if ( !file_exists( file ) ) {
		log_amx("Error: could not load %s", file);
		return false;
	}

	log_amx("Success: file %s is loaded", file);
	new iLineNum, szData[64], iTextLen, iLen;
	new szMapName[64], szRestrictName[64];
	get_mapname( szMapName, 63 );

	while ( read_file( file, iLineNum, szData, charsmax(szData), iTextLen ) )
	{
		iLen = copyc( szRestrictName, 63, szData, '*' );
		/*
		 * from string.inc file
		 * native equali(const a[],const b[],c=0);
		*/
		if ( equali( szMapName, szRestrictName, iLen ) )
		{
			return true;
		}

		iLineNum++;
	}

	return false;
}

public onRoundStart() {
	if (get_pcvar_num(g_bonus_menu_on) == 1) {
		for (new id = 1; id <= max_players; id++) {
			if (is_user_alive(id) && is_user_connected(id)) {
				if (is_level_up[id] == true) {
					showBonusMenu(id);
					is_level_up[id] = false;
				}
			}
		}
	}
	return PLUGIN_CONTINUE;
}

/*
 * handler for event named DeathMsg
 * Name:	 DeathMsg
	Structure:	
	byte	 KillerID
	byte	 VictimID
	byte	 IsHeadshot
	string	 TruncatedWeaponName
*/
public onEventDeath() {
	/*
	 * from amxmodx.inc file
	 * Gets value from client messages.
	 * When you are asking for string the array and length is needed (read_data(2,name,len)).
	 * Integer is returned by function (new me = read_data(3)).
	 * Float is set in second parameter (read_data(3,value)).
	 * native read_data(value, any:... );
	*/
	new killer_id = read_data(1);
	new victim_id = read_data(2);
	// new is_headshot = read_data(3);
	new weapon[64];
	read_data(4, weapon, charsmax(weapon));
	
	if (killer_id != victim_id && is_user_connected(killer_id) && is_user_connected(victim_id) && user_data[killer_id][level] <= MAX_LEVEL) {
		if (get_pcvar_num(g_tk_lost_exp) && get_user_team(killer_id) == get_user_team(victim_id)) {
			user_data[killer_id][exp] -= get_pcvar_num(g_tk_lost_exp_amount);
			return PLUGIN_CONTINUE;
		}
		user_data[killer_id][exp] += 1;
		
		/*
		 * TODO
		 * deprecated functionality
			if(weapon == CSW_KNIFE)
				UserData[iKiller][gExp] += 3;
				
			if(head)
				UserData[iKiller][gExp] += 2;

			if(weapon == CSW_HEGRENADE)
				UserData[iKiller][gExp] += 1; 
		*/
		
		check_level(killer_id);
	}
	
	return PLUGIN_CONTINUE;
}

public check_level(id) {
	if (user_data[id][level] < 0) user_data[id][level] = 0;
	if (user_data[id][exp] < 0) user_data[id][exp] = 0;
	
	while (user_data[id][level] <= 19 && global_levels[user_data[id][level]] < user_data[id][exp]) {
		user_data[id][level]++;
		is_level_up[id] = true;
	}
	
	if (is_level_up[id]) {
		showLevelUpMessage(id);
	}
}

public showLevelUpMessage(id) {
	new user_name[64];
	get_user_name(id, user_name, charsmax(user_name));
	static buffer[192], len;
	len = format(buffer, charsmax(buffer), "^4[^3Army Ranks^4] ^1%L ^4%s^1 ", LANG_PLAYER, "PLAYER", user_name);
	len += format(buffer[len], charsmax(buffer) - len, "%L ", LANG_PLAYER, "NEW_LEVEL"); 
	len += format(buffer[len], charsmax(buffer) - len, "^4%L^1. ", LANG_PLAYER, global_ranks[user_data[id][level]]);
	len += format(buffer[len], charsmax(buffer) - len, "%L", LANG_PLAYER, "CONGRATULATION");
	ColorChat(get_pcvar_num(g_show_lup_message_all)==0?0:id, NORMAL, buffer);
}

public client_infochanged(id) {
	if (!is_user_connected(id) || is_user_bot(id)) {
		return PLUGIN_CONTINUE;
	}
	/*
	 * from amxmodx.inc file
	 * native get_user_info(index,const info[],output[],len);
	 * native get_user_name(index,name[],len);
	*/
	new new_name[32], old_name[32];
	get_user_info(id, "name", new_name, charsmax(new_name));
	get_user_name(id, old_name, charsmax(old_name));
	/*
	 * from string.inc file
	 * native equali(const a[],const b[],c=0);
	*/
	/*
	 * check if player's name changed
	*/
	if (!equali(old_name, new_name)) {
		// first save current player data
		saveDate(id);
		// then reset user_data[id]
		user_data[id] = user_data[0];
		// and then load Data for user
		loadData(id, new_name);
	}
	return PLUGIN_CONTINUE;
}


/*
 * this function needs to be public always
 * because it is executes by set_task()
*/
public showRank()
{
	for(new id = 1; id <= max_players; id++)
	{
		if(!is_user_bot(id) && is_user_connected(id))
		{
			/*
			 * from amxmodx.inc file
			 * native set_hudmessage(red=200, green=100, blue=0, Float:x=-1.0, Float:y=0.35, effects=0, Float:fxtime=6.0, Float:holdtime=12.0, Float:fadeintime=0.1, 	Float:fadeouttime=0.2,channel=4);
			*/
			set_hudmessage(127, 127, 127, 0.01, 0.35, 0, 1.0, 1.0, _, _, -1)
			static buffer[192], len;
			len = format(buffer, charsmax(buffer), "%L ", LANG_PLAYER, "RANK");
			len += format(buffer[len], charsmax(buffer) - len, "%L", LANG_PLAYER, global_ranks[user_data[id][level]]);
			if(user_data[id][level] <= 19)
			{
				len += format(buffer[len], charsmax(buffer) - len, "^n%L", LANG_PLAYER, "PLAYER_EXP", user_data[id][exp], global_levels[user_data[id][level]]);
			} else {
				len += format(buffer[len], charsmax(buffer) - len, "^n%L", LANG_PLAYER, "PLAYER_MAX");
			}
			/*
			 * from amxmodx.inc file
			 * native ShowSyncHudMsg(target, syncObj, const fmt[], any:...);
			*/
			ShowSyncHudMsg(id, g_msg_hud, "%s", buffer);
		}
	}
	return PLUGIN_CONTINUE
}

public player_spawned(client_id) {
	if (g_bonus_restricted) {
		return HAM_IGNORED;
	}
	if (is_user_alive(client_id) && is_user_connected(client_id)) {
		new value;
		/*
		 * from army_ranks_stock.inc file
		 * stock army_ranks_calculate_value(const base_value, const level, const increase_per_level)
		*/
		value = army_ranks_calculate_value(100, user_data[client_id][level], get_pcvar_num(g_health_per_level));
		/*
		 * from fun.inc file
		 * native set_user_health(index, health);
		*/
		set_user_health(client_id, value);
		/*
		 * from cstrike.inc file
		 * native cs_set_user_armor(index, armorvalue, CsArmorType:armortype);
		 * enum CsArmorType {
		 *   CS_ARMOR_NONE = 0, // no armor
		 *   CS_ARMOR_KEVLAR = 1, // armor
		 *   CS_ARMOR_VESTHELM = 2 // armor and helmet
		 * };
		*/
		value = army_ranks_calculate_value(100, user_data[client_id][level], get_pcvar_num(g_armor_per_level));
		cs_set_user_armor(client_id, value, value >= 100 ? CS_ARMOR_VESTHELM : CS_ARMOR_KEVLAR);
	}
	return HAM_IGNORED;
}


public showBonusMenu(client_id) {

}

/*
* 	Army ranks by sdemian
*	Natives
*/
public plugin_natives()
{
	register_native("get_user_exp", "native_get_user_exp", 1);
	register_native("get_user_lvl", "native_get_user_lvl", 1);
	register_native("set_user_exp", "native_set_user_exp", 1);
	register_native("set_user_lvl", "native_set_user_lvl", 1);
	register_native("get_user_rankname", "native_get_user_rankname", 0);
	return PLUGIN_CONTINUE
}

public native_get_user_exp(id)
{
	return user_data[id][exp];
}

public native_get_user_lvl(id)
{
	return user_data[id][level];
}

public native_set_user_exp(id, num)
{
	user_data[id][exp] = num;
}

public native_set_user_lvl(id, num)
{
	user_data[id][level] = num;
}

public native_get_user_rankname()
{
	new id = get_param(1);
	static rank_name[64];
	format(rank_name, charsmax(rank_name), "%L", LANG_PLAYER, global_ranks[user_data[id][level]]);
	/*
	 * from amxmodx.inc file
	 * native set_string(param, dest[], maxlen);
	*/
	new len = get_param(3);
	set_string(2, rank_name, len);
	return 1;
}

/*
 * from sqlx.inc file
 * public QueryHandler(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime)
*/
public queryHandler(failstate, Handle:query, error[], error_code, data[], data_size) {
	switch(failstate) {
		case -2:
			log_amx("Failed to connect with error code = (%d) and error is %s", error_code, error);
		case -1:
			log_amx("Failed with error code = (%d) and error is %s", error_code, error);
		case 0:
			log_amx("Success with SQL_ThreadQuery call executions");
	}
	return PLUGIN_HANDLED;
}