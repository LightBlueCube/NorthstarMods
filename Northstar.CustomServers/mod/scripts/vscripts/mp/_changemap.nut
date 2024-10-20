global function CodeCallback_MatchIsOver

// modified to add: for handling match making system
global struct MatchOverStruct
{
	bool shouldChangeMap = true
	float mapChangeDelay = 0.0 // sets the delay before map change
}

global function AddCallback_MatchIsOver

struct
{
	array<void functionref( MatchOverStruct matchStruct )> matchOverCallbacks
} file
//

void function CodeCallback_MatchIsOver()
{
	if ( !IsPrivateMatch() && IsMatchmakingServer() )
		SetUIVar( level, "putPlayerInMatchmakingAfterDelay", true )
	else
		SetUIVar( level, "putPlayerInMatchmakingAfterDelay", false )
	
#if MP
	AddCreditsForXPGained()
	PopulatePostgameData()
#endif

	// modified to add: for handling match making system
	MatchOverStruct matchStruct
	// Added via AddCallback_MatchIsOver()
	foreach ( callbackFunc in file.matchOverCallbacks )
		callbackFunc( matchStruct )
	
	if ( matchStruct.shouldChangeMap )
		thread ChangeServerMapAfterDelay( matchStruct.mapChangeDelay )
	//
}


void function ChangeServerMapAfterDelay( float delay = 0.0 )
{
	if ( delay > 0 )
		wait delay

	if ( ShouldReturnToLobby() )
	{
		SetCurrentPlaylist( "private_match" ) // needed for private lobby to load
		
		if ( IsSingleplayer() )
			GameRules_ChangeMap( "mp_lobby", "tdm" ) // need to change back to mp playlist or loadouts will break in lobby
		else
			GameRules_ChangeMap( "mp_lobby", GAMETYPE )
	}
	else
	{
		// iterate over all gamemodes/maps in current playlist, choose map/mode combination that's directly after our current one
		// if we reach the end, go back to the first map/mode
		bool changeOnNextIteration = false
	
		for ( int i = 0; i < GetCurrentPlaylistGamemodesCount(); i++ )
		{
			if ( GetCurrentPlaylistGamemodeByIndex( i ) == GAMETYPE )
			{
				for ( int j = 0; j < GetCurrentPlaylistGamemodeByIndexMapsCount( i ); j++ )
				{
					if ( changeOnNextIteration )
					{
						GameRules_ChangeMap( GetCurrentPlaylistGamemodeByIndexMapByIndex( i, j ), GetCurrentPlaylistGamemodeByIndex( i ) )
						return
					}
				
					if ( GetCurrentPlaylistGamemodeByIndexMapByIndex( i, j ) == GetMapName() )
						changeOnNextIteration = true // change to next map/mode we iterate over
				}
			}
		}
		
		// go back to first map/mode
		GameRules_ChangeMap( GetCurrentPlaylistGamemodeByIndexMapByIndex( 0, 0 ), GetCurrentPlaylistGamemodeByIndex( 0 ) )
	}

#if DEV
	if ( !IsMatchmakingServer() )
		GameRules_ChangeMap( "mp_lobby", GAMETYPE )
#endif // #if DEV
}

#if MP
void function PopulatePostgameData()
{
	// show the postgame scoreboard summary
	SetUIVar( level, "showGameSummary", true )

	foreach ( entity player in GetPlayerArray() )
	{
		int teams = GetCurrentPlaylistVarInt( "max_teams", 2 )
		bool standardTeams = teams != 2
		
		int enumModeIndex = 0
		int enumMapIndex = 0
		
		try
		{
			enumModeIndex = PersistenceGetEnumIndexForItemName( "gamemodes", GAMETYPE )
			enumMapIndex = PersistenceGetEnumIndexForItemName( "maps", GetMapName() )
		}	
		catch( ex ) {}
	
		player.SetPersistentVar( "postGameData.myTeam", player.GetTeam() )
		player.SetPersistentVar( "postGameData.myXuid", player.GetUID() )
		player.SetPersistentVar( "postGameData.gameMode", enumModeIndex )
		player.SetPersistentVar( "postGameData.map", enumMapIndex )
		player.SetPersistentVar( "postGameData.teams", standardTeams )
		player.SetPersistentVar( "postGameData.maxTeamSize", teams )
		player.SetPersistentVar( "postGameData.privateMatch", true )
		player.SetPersistentVar( "postGameData.ranked", true )
		player.SetPersistentVar( "postGameData.hadMatchLossProtection", false )
		
		player.SetPersistentVar( "isFDPostGameScoreboardValid", GAMETYPE == FD )
		
		if ( standardTeams )
		{
			if ( player.GetTeam() == TEAM_MILITIA )
			{
				player.SetPersistentVar( "postGameData.factionMCOR", GetFactionChoice( player ) )
				player.SetPersistentVar( "postGameData.factionIMC", GetEnemyFaction( player ) )
			}
			else
			{
				player.SetPersistentVar( "postGameData.factionIMC", GetFactionChoice( player ) )
				player.SetPersistentVar( "postGameData.factionMCOR", GetEnemyFaction( player ) )
			}
			
			player.SetPersistentVar( "postGameData.scoreMCOR", GameRules_GetTeamScore( TEAM_MILITIA ) )
			player.SetPersistentVar( "postGameData.scoreIMC", GameRules_GetTeamScore( TEAM_IMC ) )
		}
		else
		{
			player.SetPersistentVar( "postGameData.factionMCOR", GetFactionChoice( player ) )
			player.SetPersistentVar( "postGameData.scoreMCOR", GameRules_GetTeamScore( player.GetTeam() ) )
		}
		
		array<entity> otherPlayers = GetPlayerArray()
		array<int> scoreTypes = GameMode_GetScoreboardColumnScoreTypes( GAMETYPE )
		int persistenceArrayCount = PersistenceGetArrayCount( "postGameData.players" )
		for ( int i = 0; i < min( otherPlayers.len(), persistenceArrayCount ); i++ )
		{
			player.SetPersistentVar( "postGameData.players[" + i + "].team", otherPlayers[ i ].GetTeam() )
			player.SetPersistentVar( "postGameData.players[" + i + "].name", otherPlayers[ i ].GetPlayerName() )
			player.SetPersistentVar( "postGameData.players[" + i + "].xuid", otherPlayers[ i ].GetUID() )
			player.SetPersistentVar( "postGameData.players[" + i + "].callsignIconIndex", otherPlayers[ i ].GetPersistentVarAsInt( "activeCallsignIconIndex" ) )
			
			for ( int j = 0; j < scoreTypes.len(); j++ )
				player.SetPersistentVar( "postGameData.players[" + i + "].scores[" + j + "]", otherPlayers[ i ].GetPlayerGameStat( scoreTypes[ j ] ) )
		}
		
		player.SetPersistentVar( "isPostGameScoreboardValid", true )
	}
}
#endif

// modified to add: for handling match making system
void function AddCallback_MatchIsOver( void functionref( MatchOverStruct matchStruct ) callbackFunc )
{
	if ( !file.matchOverCallbacks.contains( callbackFunc ) )
		file.matchOverCallbacks.append( callbackFunc )
}
//