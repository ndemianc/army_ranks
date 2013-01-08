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