MachoInjectResource2(NewThreadNs, "any", [[
    local weaponHash = GetHashKey("WEAPON_PISTOL")

    GiveWeaponToPed(PlayerPedId(), weaponHash, 250, false, true)
    SetCurrentPedWeapon(PlayerPedId(), weaponHash, true)
    Wait(250)

    MachoInjectResource("ReaperV4", string.format([[
        local success = exports["ReaperV4"]:InvokeCPlayer("set", "Weapon:%d", true, true)
        if success then
            print("Updated Cache Successfully")
        else
            print("Failed to Update Cache")
        end
    ]], weaponHash))
]])



local weaponHash = GetHashKey("WEAPON_PISTOL")

GiveWeaponToPed(PlayerPedId(), weaponHash, 250, false, true)
SetCurrentPedWeapon(PlayerPedId(), weaponHash, true)
Wait(250)
MachoInjectResource("WaveShield", [[
    local success = exports["ReaperV4"]:InvokeCPlayer("set", "Weapon:" .. ]] .. weaponHash .. [[, true, true)
    if success then
        print("Updated Cache Successfully")
    else
        print("Failed to Update Cache")
    end
]])


MachoInjectResource2(NewThreadNs, "any", function()
    local weaponHash = GetHashKey("WEAPON_PISTOL")

    GiveWeaponToPed(PlayerPedId(), weaponHash, 250, false, true)
    SetCurrentPedWeapon(PlayerPedId(), weaponHash, true)
    Wait(250)

    local innerCode = string.format([[
        local success = exports["ReaperV4"]:InvokeCPlayer("set", "Weapon:%d", true, true)
        if success then
            print("Updated Cache Successfully")
        else
            print("Failed to Update Cache")
        end
    ]], weaponHash)

    MachoInjectResource("ReaperV4", innerCode)
end)