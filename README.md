# cfx-callback

## Server Functions

```lua
-- Enregistrer un callback serveur
registerServerCallback({
    eventName = "getPlayerMoney",
    eventCallback = function(source, playerId)
        local player = GetPlayerById(playerId or source)
        return player.getMoney(), player.getBank()
    end
})

-- Appeler un callback client depuis le serveur
triggerClientCallback({
    source = playerId,
    eventName = "getPlayerPosition",
    args = {},
    timeout = 5, -- secondes
    timedout = function()
        print("La requête a expiré")
    end,
    callback = function(x, y, z)
        print("Position du joueur:", x, y, z)
    end
})

-- Version synchrone (bloque jusqu'à la réponse)
local x, y, z = triggerClientCallback({
    source = playerId,
    eventName = "getPlayerPosition",
    timeout = 5
})
print("Position du joueur:", x, y, z)
```

## Client Functions

```lua
-- Enregistrer un callback client
registerClientCallback({
    eventName = "getPlayerPosition",
    eventCallback = function()
        local x, y, z = GetEntityCoords(PlayerPedId())
        return x, y, z
    end
})

-- Appeler un callback serveur depuis le client
triggerServerCallback({
    eventName = "getPlayerMoney",
    args = {123}, -- ID du joueur (optionnel)
    timeout = 5,
    callback = function(cash, bank)
        print("Argent du joueur:", cash, "Banque:", bank)
    end
})

-- Version synchrone
local cash, bank = triggerServerCallback({
    eventName = "getPlayerMoney",
    args = {123}
})
print("Argent du joueur:", cash, "Banque:", bank)
```
