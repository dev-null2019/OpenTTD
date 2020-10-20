/* $Id$ */

/** @file command_type.h Types related to commands. */

#ifndef COMMAND_TYPE_H
#define COMMAND_TYPE_H

#include "economy_type.h"
#include "strings_type.h"
#include "tile_type.h"

/**
 * Common return value for all commands. Wraps the cost and
 * a possible error message/state together.
 */
class CommandCost {
	ExpensesType expense_type; ///< the type of expence as shown on the finances view
	Money cost;       ///< The cost of this action
	StringID message; ///< Warning message for when success is unset
	bool success;     ///< Whether the comment went fine up to this moment

public:
	/**
	 * Creates a command cost return with no cost and no error
	 */
	CommandCost() : expense_type(INVALID_EXPENSES), cost(0), message(INVALID_STRING_ID), success(true) {}

	/**
	 * Creates a command return value the is failed with the given message
	 */
	CommandCost(StringID msg) : expense_type(INVALID_EXPENSES), cost(0), message(msg), success(false) {}

	/**
	 * Creates a command cost with given expense type and start cost of 0
	 * @param ex_t the expense type
	 */
	CommandCost(ExpensesType ex_t) : expense_type(ex_t), cost(0), message(INVALID_STRING_ID), success(true) {}

	/**
	 * Creates a command return value with the given start cost and expense type
	 * @param ex_t the expense type
	 * @param cst the initial cost of this command
	 */
	CommandCost(ExpensesType ex_t, Money cst) : expense_type(ex_t), cost(cst), message(INVALID_STRING_ID), success(true) {}

	/**
	 * Adds the cost of the given command return value to this cost.
	 * Also takes a possible error message when it is set.
	 * @param ret the command to add the cost of.
	 * @return this class.
	 */
	CommandCost AddCost(CommandCost ret);

	/**
	 * Adds the given cost to the cost of the command.
	 * @param cost the cost to add
	 * @return this class.
	 */
	CommandCost AddCost(Money cost);

	/**
	 * Multiplies the cost of the command by the given factor.
	 * @param cost factor to multiply the costs with
	 * @return this class
	 */
	CommandCost MultiplyCost(int factor);

	/**
	 * The costs as made up to this moment
	 * @return the costs
	 */
	Money GetCost() const;

	/**
	 * The expense type of the cost
	 * @return the expense type
	 */
	ExpensesType GetExpensesType() const;

	/**
	 * Sets the global error message *if* this class has one.
	 */
	void SetGlobalErrorMessage() const;

	/**
	 * Did this command succeed?
	 * @return true if and only if it succeeded
	 */
	bool Succeeded() const;

	/**
	 * Did this command fail?
	 * @return true if and only if it failed
	 */
	bool Failed() const;
};

/**
 * List of commands.
 *
 * This enum defines all possible commands which can be executed to the game
 * engine. Observing the game like the query-tool or checking the profit of a
 * vehicle don't result in a command which should be executed in the engine
 * nor send to the server in a network game.
 *
 * @see _command_proc_table
 */
enum Commands: uint32 {
	CMD_BUILD_RAILROAD_TRACK,         ///< build a rail track
	CMD_REMOVE_RAILROAD_TRACK,        ///< remove a rail track
	CMD_BUILD_SINGLE_RAIL,            ///< build a single rail track
	CMD_REMOVE_SINGLE_RAIL,           ///< remove a single rail track
	CMD_LANDSCAPE_CLEAR,              ///< demolish a tile
	CMD_BUILD_BRIDGE,                 ///< build a bridge
	CMD_BUILD_RAILROAD_STATION,       ///< build a railroad station
	CMD_BUILD_TRAIN_DEPOT,            ///< build a train depot
	CMD_BUILD_SIGNALS,                ///< build a signal
	CMD_REMOVE_SIGNALS,               ///< remove a signal
	CMD_TERRAFORM_LAND,               ///< terraform a tile
	CMD_PURCHASE_LAND_AREA,           ///< purchase a tile
	CMD_SELL_LAND_AREA,               ///< sell a bought tile before
	CMD_BUILD_TUNNEL,                 ///< build a tunnel

	CMD_REMOVE_FROM_RAILROAD_STATION, ///< remove a tile station
	CMD_CONVERT_RAIL,                 ///< convert a rail type

	CMD_BUILD_TRAIN_WAYPOINT,         ///< build a waypoint
	CMD_RENAME_WAYPOINT,              ///< rename a waypoint
	CMD_REMOVE_TRAIN_WAYPOINT,        ///< remove a waypoint

	CMD_BUILD_ROAD_STOP,              ///< build a road stop
	CMD_REMOVE_ROAD_STOP,             ///< remove a road stop
	CMD_BUILD_LONG_ROAD,              ///< build a complete road (not a "half" one)
	CMD_REMOVE_LONG_ROAD,             ///< remove a complete road (not a "half" one)
	CMD_BUILD_ROAD,                   ///< build a "half" road
	CMD_REMOVE_ROAD,                  ///< remove a "half" road
	CMD_BUILD_ROAD_DEPOT,             ///< build a road depot

	CMD_BUILD_AIRPORT,                ///< build an airport

	CMD_BUILD_DOCK,                   ///< build a dock

	CMD_BUILD_SHIP_DEPOT,             ///< build a ship depot
	CMD_BUILD_BUOY,                   ///< build a buoy

	CMD_PLANT_TREE,                   ///< plant a tree

	CMD_BUILD_RAIL_VEHICLE,           ///< build a rail vehicle
	CMD_MOVE_RAIL_VEHICLE,            ///< move a rail vehicle (in the depot)

	CMD_START_STOP_TRAIN,             ///< start or stop a train

	CMD_SELL_RAIL_WAGON,              ///< sell a rail wagon

	CMD_SEND_TRAIN_TO_DEPOT,          ///< send a train to a depot
	CMD_FORCE_TRAIN_PROCEED,          ///< proceed a train to pass a red signal
	CMD_REVERSE_TRAIN_DIRECTION,      ///< turn a train around

	CMD_MODIFY_ORDER,                 ///< modify an order (like set full-load)
	CMD_SKIP_TO_ORDER,                ///< skip an order to the next of specific one
	CMD_DELETE_ORDER,                 ///< delete an order
	CMD_INSERT_ORDER,                 ///< insert a new order

	CMD_CHANGE_SERVICE_INT,           ///< change the server interval of a vehicle

	CMD_BUILD_INDUSTRY,               ///< build a new industry

	CMD_BUILD_COMPANY_HQ,             ///< build the company headquarter
	CMD_SET_PLAYER_FACE,              ///< set the face of the player/company
	CMD_SET_PLAYER_COLOR,             ///< set the color of the player/company

	CMD_INCREASE_LOAN,                ///< increase the loan from the bank
	CMD_DECREASE_LOAN,                ///< decrease the loan from the bank

	CMD_WANT_ENGINE_PREVIEW,          ///< confirm the preview of an engine

	CMD_NAME_VEHICLE,                 ///< rename a whole vehicle
	CMD_RENAME_ENGINE,                ///< rename a engine (in the engine list)
	CMD_CHANGE_COMPANY_NAME,          ///< change the company name
	CMD_CHANGE_PRESIDENT_NAME,        ///< change the president name
	CMD_RENAME_STATION,               ///< rename a station

	CMD_SELL_AIRCRAFT,                ///< sell an aircraft
	CMD_START_STOP_AIRCRAFT,          ///< start/stop an aircraft
	CMD_BUILD_AIRCRAFT,               ///< build an aircraft
	CMD_SEND_AIRCRAFT_TO_HANGAR,      ///< send an aircraft to a hanger
	CMD_REFIT_AIRCRAFT,               ///< refit the cargo space of an aircraft

	CMD_PLACE_SIGN,                   ///< place a sign
	CMD_RENAME_SIGN,                  ///< rename a sign

	CMD_BUILD_ROAD_VEH,               ///< build a road vehicle
	CMD_START_STOP_ROADVEH,           ///< start/stop a road vehicle
	CMD_SELL_ROAD_VEH,                ///< sell a road vehicle
	CMD_SEND_ROADVEH_TO_DEPOT,        ///< send a road vehicle to the depot
	CMD_TURN_ROADVEH,                 ///< turn a road vehicle around
	CMD_REFIT_ROAD_VEH,               ///< refit the cargo space of a road vehicle

	CMD_PAUSE,                        ///< pause the game

	CMD_BUY_SHARE_IN_COMPANY,         ///< buy a share from a company
	CMD_SELL_SHARE_IN_COMPANY,        ///< sell a share from a company
	CMD_BUY_COMPANY,                  ///< buy a company which is bankrupt

	CMD_BUILD_TOWN,                   ///< build a town

	CMD_RENAME_TOWN,                  ///< rename a town
	CMD_DO_TOWN_ACTION,               ///< do a action from the town detail window (like advertises or bribe)

	CMD_SET_ROAD_DRIVE_SIDE,          ///< set the side where the road vehicles drive

	CMD_CHANGE_DIFFICULTY_LEVEL,      ///< change the difficult of a game (each setting for it own)

	CMD_START_STOP_SHIP,              ///< start/stop a ship
	CMD_SELL_SHIP,                    ///< sell a ship
	CMD_BUILD_SHIP,                   ///< build a new ship
	CMD_SEND_SHIP_TO_DEPOT,           ///< send a ship to a depot
	CMD_REFIT_SHIP,                   ///< refit the cargo space of a ship

	CMD_ORDER_REFIT,                  ///< change the refit informaction of an order (for "goto depot" )
	CMD_CLONE_ORDER,                  ///< clone (and share) an order
	CMD_CLEAR_AREA,                   ///< clear an area

	CMD_MONEY_CHEAT,                  ///< do the money cheat
	CMD_BUILD_CANAL,                  ///< build a canal

	CMD_PLAYER_CTRL,                  ///< used in multiplayer to create a new player etc.
	CMD_LEVEL_LAND,                   ///< level land

	CMD_REFIT_RAIL_VEHICLE,           ///< refit the cargo space of a train
	CMD_RESTORE_ORDER_INDEX,          ///< restore vehicle order-index and service interval
	CMD_BUILD_LOCK,                   ///< build a lock

	CMD_BUILD_SIGNAL_TRACK,           ///< add signals along a track (by dragging)
	CMD_REMOVE_SIGNAL_TRACK,          ///< remove signals along a track (by dragging)

	CMD_GIVE_MONEY,                   ///< give money to an other player
	CMD_CHANGE_PATCH_SETTING,         ///< change a patch setting

	CMD_SET_AUTOREPLACE,              ///< set an autoreplace entry

	CMD_CLONE_VEHICLE,                ///< clone a vehicle
	CMD_MASS_START_STOP,              ///< start/stop all vehicles (in a depot)
	CMD_DEPOT_SELL_ALL_VEHICLES,      ///< sell all vehicles which are in a given depot
	CMD_DEPOT_MASS_AUTOREPLACE,       ///< force the autoreplace to take action in a given depot

	CMD_CREATE_GROUP,                 ///< create a new group
	CMD_DELETE_GROUP,                 ///< delete a group
	CMD_RENAME_GROUP,                 ///< rename a group
	CMD_ADD_VEHICLE_GROUP,            ///< add a vehicle to a group
	CMD_ADD_SHARED_VEHICLE_GROUP,     ///< add all other shared vehicles to a group which are missing
	CMD_REMOVE_ALL_VEHICLES_GROUP,    ///< remove all vehicles from a group
	CMD_SET_GROUP_REPLACE_PROTECTION, ///< set the autoreplace-protection for a group

	CMD_MOVE_ORDER,                   ///< move an order
	CMD_CHANGE_TIMETABLE,             ///< change the timetable for a vehicle
	CMD_SET_VEHICLE_ON_TIME,          ///< set the vehicle on time feature (timetable)
	CMD_AUTOFILL_TIMETABLE,           ///< autofill the timetable
};

/**
 * List of flags for a command.
 *
 * This enums defines some flags which can be used for the commands.
 */
enum {
	DC_EXEC            = 0x001, ///< execute the given command
	DC_AUTO            = 0x002, ///< don't allow building on structures
	DC_QUERY_COST      = 0x004, ///< query cost only,  don't build.
	DC_NO_WATER        = 0x008, ///< don't allow building on water
	DC_NO_RAIL_OVERLAP = 0x010, ///< don't allow overlap of rails (used in buildrail)
	DC_AI_BUILDING     = 0x020, ///< special building rules for AI
	DC_NO_TOWN_RATING  = 0x040, ///< town rating does not disallow you from building
	DC_BANKRUPT        = 0x080, ///< company bankrupts, skip money check, skip vehicle on tile check in some cases
	DC_AUTOREPLACE     = 0x100, ///< autoreplace/autorenew is in progress
};

/**
 * Used to combine a StringID with the command.
 *
 * This macro can be used to add a StringID (the error message to show) on a command-id
 * (CMD_xxx). Use the binary or-operator "|" to combine the command with the result from
 * this macro.
 *
 * @param x The StringID to combine with a command-id
 */
#define CMD_MSG(x) ((x) << 16)

/**
 * Defines some flags.
 *
 * This enumeration defines some flags which are binary-or'ed on a command.
 */
enum {
	CMD_NO_WATER              = 0x0400, ///< dont build on water
	CMD_NETWORK_COMMAND       = 0x0800, ///< execute the command without sending it on the network
	CMD_NO_TEST_IF_IN_NETWORK = 0x1000, ///< When enabled, the command will bypass the no-DC_EXEC round if in network
	CMD_SHOW_NO_ERROR         = 0x2000, ///< do not show the error message
};

/**
 * Command flags for the command table _command_proc_table.
 *
 * This enumeration defines flags for the _command_proc_table.
 */
enum CommandFlags {
	CMD_SERVER  = 0x001, ///< the command can only be initiated by the server
	CMD_OFFLINE = 0x002, ///< the command cannot be executed in a multiplayer game; single-player only
	CMD_AUTO    = 0x004, ///< set the DC_AUTO flag on this command
	CMD_DEITY   = 0x100, ///< the command may be executed by COMPANY_DEITY
};

/**
 * Defines the callback type for all command handler functions.
 *
 * This type defines the function header for all functions which handles a CMD_* command.
 * A command handler use the parameters to act according to the meaning of the command.
 * The tile parameter defines the tile to perform an action on.
 * The flag parameter is filled with flags from the DC_* enumeration. The parameters
 * p1 and p2 are filled with parameters for the command like "which road type", "which
 * order" or "direction". Each function should mentioned in there doxygen comments
 * the usage of these parameters.
 *
 * @param tile The tile to apply a command on
 * @param flags Flags for the command, from the DC_* enumeration
 * @param p1 Additional data for the command
 * @param p2 Additional data for the command
 * @return The CommandCost of the command, which can be succeeded or failed.
 */
typedef CommandCost CommandProc(TileIndex tile, uint32 flags, uint32 p1, uint32 p2);

/**
 * Define a command with the flags which belongs to it.
 *
 * This struct connect a command handler function with the flags created with
 * the #CMD_AUTO, #CMD_OFFLINE and #CMD_SERVER values.
 */
struct Command {
	CommandProc *proc;
	byte flags;
};

/**
 * Define a callback function for the client, after the command is finished.
 *
 * Functions of this type are called after the command is finished. The parameters
 * are from the #CommandProc callback type. The boolean parameter indicates if the
 * command succeeded or failed.
 *
 * @param success If the command succeeded or not.
 * @param tile The tile of the command action
 * @param p1 Additional data of the command
 * @param p1 Additional data of the command
 * @see CommandProc
 */
typedef void CommandCallback(bool success, TileIndex tile, uint32 p1, uint32 p2);

#endif /* COMMAND_TYPE_H */
