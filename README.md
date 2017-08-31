# Candy
Candy bars for DataBroker modules in World of Warcraft.

## Description
Do you find big DataBroker panels slightly too sturdy or would you fancy something small on the side as well? Introducing Candy for your candybar sized DataBroker modules.

Candy adds singular customizable displays for DataBroker modules.

* The bars are small and freely movable to wherever you need them, making highly customized layout simple for any interface.
* Visibility of the bars can be automatically toggled based on group status, instance status, modifier keys and custom callbacks.
* The DataBroker output text can also be modified with custom callbacks.

## Custom callbacks

Custom callbacks are simple calls to Lua functions.

Text callback function receives one parameter: text. It expects a new string (text or number allowed) as return that will be used for display.

Example:

```-- Returns reverse text
return string.reverse(text);
```

Visibility callback function receives two parameters: text (with color information stripped) and icon. It expects a boolean or nil as return (true is visible).

Examples:

```-- Toggles visibility based on if player has reached maximum level
return UnitLevel("player") == GetMaxPlayerLevel();
```

```-- Toggles visibility based on durability number displayed
local durability = tonumber(strmatch(text, "(%d+)")) or 0; return durability <= 50;
```

## Usage

To begin using Candy you need to create the bars. You can do that by opening the options menu by typing **/candy** or **/cd**.

Editing per-bar settings is only possible when bars are unlocked. When they are unlocked you can move bar with left mouse button and open options drop down menu with right mouse button. Global settings that apply to all bars at once can be changed from the main options window.

## Dependencies
Candy uses Ace3, LibDataBroker, LibFlyPaper and LibSharedMedia which are included in the /libs directory.
