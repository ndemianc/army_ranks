#if defined _army_ranks_stocks_included
	#endinput
#endif
#define _army_ranks_stocks_included

/* 
 * Calculates the value of the item based on the current level, max level, and max value.
 * 
 * @param 	base_value - The base value of the item
 * @param		level - The level of the client
 * @param		increase_per_level - The incease of the value on each level
 * 
 * @return		The value of the item for the given level
 * 
 */
stock army_ranks_calculate_value(const base_value, const level, const increase_per_level)
{
	return (base_value + level * increase_per_level);
}

/*
 * Prints color message to the client using format string
 * @param		id - The client identifier
 * @param		input - The string with message and substition characters
 * @param		any - Arbitrary parameters reflected with substitution characters
*/

stock client_print_color_msg(const id, const input[], any:...) {
	static msg[256];
	vformat(msg, 255, input, 3);
	replace_all(msg, 255, "!g", "^4"); // Green Color
	replace_all(msg, 255, "!y", "^1"); // Default Color (yellow)
	replace_all(msg, 255, "!t", "^3"); // Team Color
	format(msg, 255, "^x01%s", msg);
	if ( is_user_connected(id) ) {
			message_begin(MSG_ONE_UNRELIABLE, gmsgSayText, _, id);
			write_byte(id);
			write_string(msg);
			message_end();
	}
}