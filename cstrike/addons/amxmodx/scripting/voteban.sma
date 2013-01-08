#include <amxmodx>
#include <amxmisc>

#define MAX_players 32
#define MAX_menudata 1024

new ga_PlayerName[MAX_players][32]
new ga_PlayerAuthID[MAX_players][35]
new ga_PlayerID[MAX_players]
new ga_PlayerIP[MAX_players][16]
new ga_MenuData[MAX_menudata]
new ga_Choice[2]
new gi_VoteStarter
new gi_MenuPosition
new gi_Sellection
new gi_TotalPlayers
new gi_SysTimeOffset = 0
new i
//pcvars
new gi_LastTime
new gi_DelayTime
new gf_Ratio
new gf_MinVoters
new gf_BF_Ratio
new gi_BanTime
new gi_Disable
new gi_BanType


public plugin_init()
{
  register_plugin("Voteban Menu Rus","1.2","hjvl & Maksovich")
  register_clcmd("say /voteban","SayIt")
  register_clcmd("say voteban","SayIt")
  register_clcmd("say /vtb","SayIt")
  register_clcmd("say vtb","SayIt")
  register_menucmd(register_menuid("ChoosePlayer"), 1023, "ChooseMenu")
  register_menucmd(register_menuid("VoteMenu"), 1023, "CountVotes")

  gi_LastTime=register_cvar("amx_voteban_lasttime","0")
  gi_DelayTime=register_cvar("amxx_voteban_delaytime","300")
  gf_Ratio=register_cvar("amxx_voteban_ratio","0.65")
  gf_MinVoters=register_cvar("amxx_voteban_minvoters","0.0")
  gf_BF_Ratio=register_cvar("amxx_voteban_bf_ratio","0.0")
  gi_BanTime=register_cvar("amxx_voteban_bantime","15")
  gi_Disable=register_cvar("amxx_voteban_disable","0")
  gi_BanType=register_cvar("amxx_voteban_type","0")
}

public SayIt(id) {
	if(get_pcvar_num(gi_Disable)) {
		client_print(id,print_chat,"[VOTEBAN] Голосование отключено");
		return 0;
	}

	if(any_admin_with_ban())	{     
		client_print(id,print_chat,"[VOTEBAN] ADMIN(s) онлайн, голосование недоступно");
		return 0;
	}

	if( get_user_flags(id) & ADMIN_LEVEL_H ) {
		new Elapsed=get_systime(gi_SysTimeOffset) - get_pcvar_num(gi_LastTime)
		new Delay=get_pcvar_num(gi_DelayTime)

		if (Delay > Elapsed)
		{
			new seconds = Delay - Elapsed
			client_print(id,print_chat,"[VOTEBAN] Создать голосования будет доступно по истечению %d секунд", seconds)
			return 0
		}

		get_players( ga_PlayerID, gi_TotalPlayers )
		for(i=0; i<gi_TotalPlayers; i++)
		{
			new TempID = ga_PlayerID[i];

			if(TempID == id)
				gi_VoteStarter=i

			get_user_name( TempID, ga_PlayerName[i], 31 )
			get_user_authid( TempID, ga_PlayerAuthID[i], 34 )
			get_user_ip( TempID, ga_PlayerIP[i], 15, 1 )
		}

		gi_MenuPosition = 0;
		ShowPlayerMenu(id);
		return 0;
	} else {
		client_print(id,print_chat,"[VOTEBAN] Эта функция доступна только для игроков с VIP статусом!");
	}
	return 0;
}

public ShowPlayerMenu(id)
{
  new arrayloc = 0
  new keys = (1<<9)

  arrayloc = format(ga_MenuData,(MAX_menudata-1),"Голосование за БАН ^n")
  for(i=0; i<8; i++)
   if( gi_TotalPlayers>(gi_MenuPosition+i) )
   {
     arrayloc += format(ga_MenuData[arrayloc],(MAX_menudata-1-arrayloc),"%d. %s^n", i+1, ga_PlayerName[gi_MenuPosition+i])
     keys |= (1<<i)
   }
  if( gi_TotalPlayers>(gi_MenuPosition+8) )
  {
    arrayloc += format(ga_MenuData[arrayloc],(MAX_menudata-1-arrayloc),"^n9. Дальше")
    keys |= (1<<8)
  }
  arrayloc += format(ga_MenuData[arrayloc],(MAX_menudata-1-arrayloc),"^n0. Назад/Выход")

  show_menu(id, keys, ga_MenuData, 20, "ChoosePlayer")
  return PLUGIN_HANDLED
}

public ChooseMenu(id, key)
{
  switch(key)
  {
    case 8:
    {
      gi_MenuPosition=gi_MenuPosition+8
      ShowPlayerMenu(id)
    }
    case 9:
    {
      if(gi_MenuPosition>=8)
      {
        gi_MenuPosition=gi_MenuPosition-8
        ShowPlayerMenu(id)
      }
      else
        return 0
    }
    default:
    {
      gi_Sellection=gi_MenuPosition+key
      new Now=get_systime(gi_SysTimeOffset)
      set_pcvar_num(gi_LastTime, Now)

      run_vote()
      return 0
    }
  }
  return PLUGIN_HANDLED
}

public run_vote()
{
  log_amx("Голосование запустил %s за %s %s", ga_PlayerName[gi_VoteStarter], ga_PlayerName[gi_Sellection], ga_PlayerAuthID[gi_Sellection])
  format(ga_MenuData,(MAX_menudata-1),"Забанить %s на %d минут?^n1. Да^n2. Нет",ga_PlayerName[gi_Sellection], get_pcvar_num(gi_BanTime))
  ga_Choice[0] = 0
  ga_Choice[1] = 0
  show_menu( 0, (1<<0)|(1<<1), ga_MenuData, 15, "VoteMenu" )
  set_task(15.0,"outcom")
  return 0
}

public CountVotes(id, key)
{
  ++ga_Choice[key]
  return PLUGIN_HANDLED
}

public outcom()
{
  new TotalVotes = ga_Choice[0] + ga_Choice[1]
  new Float:result = (float(ga_Choice[0]) / float(TotalVotes))

  if( get_pcvar_float(gf_MinVoters) >= ( float(TotalVotes) / float(gi_TotalPlayers) ) )
  {
    client_print(0,print_chat,"[VOTEBAN] Для голосования нехватает %s игрока!", ga_PlayerName[gi_Sellection])
    return 0
  }
  else
  {
    if( result < get_pcvar_float(gf_BF_Ratio) )
    {
      client_print(0,print_chat,"[VOTEBAN] Голосование не состоялось, инициатор %s забанен на %d минут", ga_PlayerName[gi_VoteStarter], get_pcvar_num(gi_BanTime))
      ActualBan(gi_VoteStarter)
      log_amx("Голосование не состоялось, инициатор %s забанен на %d минут", ga_PlayerName[gi_VoteStarter], get_pcvar_num(gi_BanTime))
    }

    if( result >= get_pcvar_float(gf_Ratio) )
    {
      client_print(0,print_chat,"[VOTEBAN] Голосование окончено, %s забанен на %d минут", ga_PlayerName[gi_Sellection], get_pcvar_num(gi_BanTime))
      log_amx("Голосование окончено, %s забанен на %d минут", ga_PlayerAuthID[gi_Sellection], get_pcvar_num(gi_BanTime))
      ActualBan(gi_Sellection)
    }
    else
    {
      client_print(0,print_chat,"[VOTEBAN] Голосование не состоялось!")
      log_amx("Голосование не состоялось!")
    }
  }
  client_print(0,print_chat,"[VOTEBAN] Всего %d игроков, %d сказали ДА", gi_TotalPlayers, ga_Choice[0])

  return 0
}

public ActualBan(Selected)
{
  new Type = get_pcvar_num(gi_BanType)
  switch(Type)
  {
    case 1:
      server_cmd("addip %d %s", get_pcvar_num(gi_BanTime), ga_PlayerIP[Selected])
    case 2:
      server_cmd("amx_ban %d %s Voteban", get_pcvar_num(gi_BanTime), ga_PlayerAuthID[Selected])
    default:
      server_cmd("banid %d %s kick", get_pcvar_num(gi_BanTime), ga_PlayerAuthID[Selected])
  }
  return 0
}

public bool:any_admin_with_ban() {
	new players[32];
	new players_count;
	new counter, user;

	get_players(players, players_count);

	for(counter=0; counter < players_count; counter++) {
		user = players[counter];
		if(user_can_ban(user)) {     
			return true;
		}
	}
	return false;
}

public bool:user_can_ban(id) {
	new __flags=get_user_flags(id);
	return (__flags>0 && (__flags&ADMIN_BAN));
}