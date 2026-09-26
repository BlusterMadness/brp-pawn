# bluster-pawn

A simple QBCore pawn-shop resource that lets players sell configured inventory items for cash or bank deposits.

## Installation / updating an existing copy

1. Download the resource from GitHub (Code → Download ZIP) or pull the latest changes.
2. Place the `bluster-pawn` folder in your server's resources folder. If GitHub adds `-main` to the ZIP's folder name, rename it `bluster-pawn`.
3. When upgrading, back up your existing resource and keep any custom prices or pawn location from your previous `config.lua`.
4. In `fxmanifest.lua`, ensure `config.lua` loads on **both** the client and server, such as:

   ```lua
   shared_scripts {
       '@ox_lib/init.lua',
       'config.lua'
   }
   ```

   If your manifest already lists `@ox_lib/init.lua` elsewhere, don't load it twice. Preserve any other manifest entries your resource needs.
5. Ensure `bluster-pawn` starts after `qb-core`, your target resource, and `ox_lib`. For a standard `qb-target` setup:

   ```cfg
   ensure qb-core
   ensure qb-target
   ensure ox_lib
   ensure bluster-pawn
   ```

   If you use `ox_target`'s `qb-target` compatibility exports instead, start `ox_target` rather than starting another target resource. If your `server.cfg` already uses `ensure [standalone]` (or whichever folder contains the resource), don't add a duplicate `ensure bluster-pawn`.
6. Restart the resource or server, then test sales using both cash and bank.

## Configuration

Set `Config.Items` (keyed by QBCore item names, with each entry containing a numeric `price`) and `Config.PedProps` (with `hash` and `location`, including x/y/z/w coordinates).

The client fetches prices from the server when opening the pawn shop, so `math.random()` prices in `config.lua` appear correctly to players. Each configured random price is chosen when the server loads or restarts the resource.

The maximum quantity per sale is `MAX_SELL_AMOUNT = 10000` in **both** `client.lua` and `server.lua`. Change both values together if required. The server also enforces a $2,147,483,647 maximum payout per transaction.

## Protections

- Sale prices are taken from the server's `Config.Items`, never from the client; the menu retrieves the same prices via an ox_lib callback.
- The server rejects unlisted items, invalid amounts, unsupported payment methods, excessive payouts, and attempts to sell away from the configured pawn shop.
- Inventory is checked across item stacks and only quantities **successfully removed** are paid for.
- If payment is rejected, the script tries to return the items removed. Any incomplete refund is logged for staff.

## Dependencies

- `qb-core`
- `qb-target` (or a compatible target bridge)
- `ox_lib`
- `qb-inventory` / a compatible QBCore inventory implementing boolean results for `Player.Functions.RemoveItem` and `Player.Functions.AddItem`

## Credits

Bluster Development. Credit is appreciated if you adapt or redistribute this script.
