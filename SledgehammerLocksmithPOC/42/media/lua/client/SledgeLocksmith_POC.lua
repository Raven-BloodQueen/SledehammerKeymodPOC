-- Sledgehammer Locksmith 0.0.2 POC
-- Build target: Project Zomboid 42.20.x
-- Purpose:
--   0.0.1 proved vanilla door KeyId -> imprint modData -> vanilla key KeyId.
--   0.0.2 adds deliberate rekeying of a vanilla IsoDoor using an armed imprint,
--   plus enough audit state to test save/reload persistence.
-- This build is intentionally CLIENT/SINGLE-PLAYER ONLY. Multiplayer authority comes later.

local SL = {}
SL.VERSION = "0.0.2"
SL.PREFIX = "[SLEDGE-LOCK " .. SL.VERSION .. "]"
SL.TOOL_TYPE = "SledgeLocksmith.LocksmithTool"
SL.IMPRINT_TYPE = "SledgeLocksmith.LockImprint"
SL.BLANK_KEY_TYPE = "Base.Key_Blank"
SL.CUT_KEY_TYPE = "Base.Key1"
SL.MD_KEY = "SledgeLocksmith_KeyId"
SL.MD_ACTIVE_KEY = "SledgeLocksmith_ActiveRekeyKeyId"
SL.MD_ACTIVE_NAME = "SledgeLocksmith_ActiveRekeyName"
SL.MD_ACTIVE_SOURCE_X = "SledgeLocksmith_ActiveRekeySourceX"
SL.MD_ACTIVE_SOURCE_Y = "SledgeLocksmith_ActiveRekeySourceY"
SL.MD_ACTIVE_SOURCE_Z = "SledgeLocksmith_ActiveRekeySourceZ"

local function log(message)
    print(SL.PREFIX .. " " .. tostring(message))
end

local function halo(player, message)
    if player then
        player:setHaloNote(tostring(message))
    end
end

local function getPlayer(playerNum)
    return getSpecificPlayer(playerNum)
end

local function findByFullTypeRecursive(container, fullType, shortType)
    if not container then return nil end

    local item = nil
    if shortType then
        item = container:getItemFromTypeRecurse(shortType)
        if item and item:getFullType() == fullType then
            return item
        end
    end

    item = container:getItemFromTypeRecurse(fullType)
    if item and item:getFullType() == fullType then
        return item
    end

    return nil
end

local function getLocksmithTool(player)
    return findByFullTypeRecursive(player:getInventory(), SL.TOOL_TYPE, "LocksmithTool")
end

local function getBlankKey(player)
    return findByFullTypeRecursive(player:getInventory(), SL.BLANK_KEY_TYPE, "Key_Blank")
end

local function getDoorFromWorldObjects(worldObjects)
    if not worldObjects then return nil end

    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        if obj and instanceof(obj, "IsoDoor") then
            return obj
        end
    end

    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        local square = obj and obj:getSquare() or nil
        if square then
            local objects = square:getObjects()
            if objects then
                for j = 0, objects:size() - 1 do
                    local squareObj = objects:get(j)
                    if squareObj and instanceof(squareObj, "IsoDoor") then
                        return squareObj
                    end
                end
            end
        end
    end

    return nil
end

local function getDoorCoords(door)
    local square = door and door:getSquare() or nil
    return square and square:getX() or -1,
           square and square:getY() or -1,
           square and square:getZ() or -1
end

local function readDoorKeyId(door)
    if not door then return -1 end

    local keyId = door:getKeyId()
    log("Door initial getKeyId() = " .. tostring(keyId))

    if not keyId or keyId <= 0 then
        local ok, resolved = pcall(function()
            return door:checkKeyId()
        end)

        if ok and resolved then
            keyId = resolved
            log("Door checkKeyId() resolved = " .. tostring(keyId))
        else
            log("Door checkKeyId() did not resolve a usable id.")
        end
    end

    return keyId or -1
end

local function giveTestKit(player)
    if not player then return end

    local inv = player:getInventory()
    local addedTool = false

    if not getLocksmithTool(player) then
        local tool = inv:AddItem(SL.TOOL_TYPE)
        if tool then
            addedTool = true
            log("Added Locksmith Tool [POC].")
        end
    end

    local blanksAdded = 0
    for i = 1, 3 do
        local blank = inv:AddItem(SL.BLANK_KEY_TYPE)
        if blank then
            blanksAdded = blanksAdded + 1
        end
    end

    if blanksAdded > 0 then
        log("Added " .. tostring(blanksAdded) .. " vanilla Blank Key(s): " .. SL.BLANK_KEY_TYPE)
    else
        log("ERROR: Could not add vanilla blank keys " .. SL.BLANK_KEY_TYPE)
    end

    if blanksAdded > 0 then
        if addedTool then
            halo(player, "0.0.2 kit: Locksmith Tool + " .. tostring(blanksAdded) .. " Blank Keys")
        else
            halo(player, "0.0.2 kit: " .. tostring(blanksAdded) .. " Blank Keys added (tool already owned)")
        end
    else
        halo(player, "POC ERROR: Blank Keys could not be created - check console")
    end
end

local function takeImprint(player, door)
    if not player or not door then return end

    if not getLocksmithTool(player) then
        halo(player, "Need Locksmith Tool [POC]")
        log("Imprint blocked: Locksmith Tool missing.")
        return
    end

    local keyId = readDoorKeyId(door)
    local x, y, z = getDoorCoords(door)

    log("Target door = " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))

    if not keyId or keyId <= 0 then
        halo(player, "This door has no usable KeyId. Try another vanilla locked house door.")
        log("IMPRINT FAILED: unusable KeyId = " .. tostring(keyId))
        return
    end

    local imprint = player:getInventory():AddItem(SL.IMPRINT_TYPE)
    if not imprint then
        halo(player, "POC ERROR: could not create imprint")
        log("ERROR: AddItem failed for " .. SL.IMPRINT_TYPE)
        return
    end

    local md = imprint:getModData()
    md[SL.MD_KEY] = keyId
    md.SledgeLocksmith_SourceX = x
    md.SledgeLocksmith_SourceY = y
    md.SledgeLocksmith_SourceZ = z
    md.SledgeLocksmith_Version = SL.VERSION

    imprint:setName("Lock Imprint [ID " .. tostring(keyId) .. "]")
    imprint:setCustomName(true)

    log("IMPRINT CREATED. Stored KeyId = " .. tostring(keyId))
    halo(player, "Lock imprint captured: KeyId " .. tostring(keyId))
end

local function cutTestKey(player, imprint)
    if not player or not imprint then return end

    local md = imprint:getModData()
    local keyId = md and md[SL.MD_KEY] or nil

    if not keyId or keyId <= 0 then
        halo(player, "POC ERROR: imprint has no usable KeyId")
        log("CUT FAILED: imprint missing usable KeyId.")
        return
    end

    local blank = getBlankKey(player)
    if not blank then
        halo(player, "Need a vanilla Blank Key")
        log("CUT BLOCKED: missing " .. SL.BLANK_KEY_TYPE)
        return
    end

    local blankContainer = blank:getContainer()
    if blankContainer then
        blankContainer:Remove(blank)
    else
        player:getInventory():Remove(blank)
    end

    local key = player:getInventory():AddItem(SL.CUT_KEY_TYPE)
    if not key then
        halo(player, "POC ERROR: could not create test key")
        log("ERROR: AddItem failed for " .. SL.CUT_KEY_TYPE)
        return
    end

    key:setKeyId(keyId)
    key:setName("Cut Key [POC ID " .. tostring(keyId) .. "]")
    key:setCustomName(true)

    log("CUT KEY CREATED. key:getKeyId() = " .. tostring(key:getKeyId()))
    halo(player, "Test key cut: KeyId " .. tostring(keyId))
end

local function inspectImprint(player, imprint)
    if not player or not imprint then return end

    local md = imprint:getModData()
    local keyId = md and md[SL.MD_KEY] or nil
    local x = md and md.SledgeLocksmith_SourceX or "?"
    local y = md and md.SledgeLocksmith_SourceY or "?"
    local z = md and md.SledgeLocksmith_SourceZ or "?"

    log("IMPRINT INSPECT: KeyId=" .. tostring(keyId) .. " source=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
    halo(player, "Imprint KeyId: " .. tostring(keyId) .. " | source " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
end

local function armImprintForRekey(player, imprint)
    if not player or not imprint then return end

    local md = imprint:getModData()
    local keyId = md and md[SL.MD_KEY] or nil
    if not keyId or keyId <= 0 then
        halo(player, "POC ERROR: imprint has no usable KeyId")
        log("ARM FAILED: imprint missing usable KeyId.")
        return
    end

    local pmd = player:getModData()
    pmd[SL.MD_ACTIVE_KEY] = keyId
    pmd[SL.MD_ACTIVE_NAME] = imprint:getName()
    pmd[SL.MD_ACTIVE_SOURCE_X] = md.SledgeLocksmith_SourceX
    pmd[SL.MD_ACTIVE_SOURCE_Y] = md.SledgeLocksmith_SourceY
    pmd[SL.MD_ACTIVE_SOURCE_Z] = md.SledgeLocksmith_SourceZ

    log("REKEY IMPRINT ARMED. KeyId=" .. tostring(keyId) .. " name=" .. tostring(imprint:getName()))
    halo(player, "Armed rekey imprint: ID " .. tostring(keyId) .. ". Now right-click target door.")
end

local function clearArmedImprint(player)
    if not player then return end
    local pmd = player:getModData()
    pmd[SL.MD_ACTIVE_KEY] = nil
    pmd[SL.MD_ACTIVE_NAME] = nil
    pmd[SL.MD_ACTIVE_SOURCE_X] = nil
    pmd[SL.MD_ACTIVE_SOURCE_Y] = nil
    pmd[SL.MD_ACTIVE_SOURCE_Z] = nil
    log("REKEY IMPRINT DISARMED.")
    halo(player, "Rekey imprint disarmed")
end

local function getArmedKeyId(player)
    if not player then return nil end
    local pmd = player:getModData()
    local keyId = pmd and pmd[SL.MD_ACTIVE_KEY] or nil
    if keyId and keyId > 0 then return keyId end
    return nil
end

local function inspectDoorState(player, door)
    if not player or not door then return end

    local currentId = door:getKeyId()
    local x, y, z = getDoorCoords(door)
    local md = door:getModData()

    local oldId = md and md.SledgeLocksmith_LastOldKeyId or nil
    local newId = md and md.SledgeLocksmith_LastNewKeyId or nil
    local rekeyed = md and md.SledgeLocksmith_RekeyedByPOC or false

    log("DOOR INSPECT: coords=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
        .. " currentKeyId=" .. tostring(currentId)
        .. " rekeyMarker=" .. tostring(rekeyed)
        .. " old=" .. tostring(oldId)
        .. " new=" .. tostring(newId))

    if rekeyed then
        halo(player, "Door ID " .. tostring(currentId) .. " | POC rekey " .. tostring(oldId) .. " -> " .. tostring(newId))
    else
        halo(player, "Door current KeyId: " .. tostring(currentId) .. " | no 0.0.2 rekey marker")
    end
end

local function applyArmedImprint(player, door)
    if not player or not door then return end

    if not getLocksmithTool(player) then
        halo(player, "Need Locksmith Tool [POC]")
        log("REKEY BLOCKED: Locksmith Tool missing.")
        return
    end

    local pmd = player:getModData()
    local newId = getArmedKeyId(player)
    if not newId then
        halo(player, "No imprint armed for rekeying")
        log("REKEY BLOCKED: no armed imprint.")
        return
    end

    local oldId = readDoorKeyId(door)
    local x, y, z = getDoorCoords(door)

    if not oldId or oldId <= 0 then
        halo(player, "Target door has no usable KeyId")
        log("REKEY FAILED: target door unusable old KeyId=" .. tostring(oldId))
        return
    end

    if oldId == newId then
        halo(player, "Target already uses KeyId " .. tostring(newId) .. ". Choose a door from a different building.")
        log("REKEY ABORTED: old and new KeyId are identical: " .. tostring(newId))
        return
    end

    -- THE 0.0.2 MONEY LINE:
    -- change the actual native IsoDoor KeyId instead of faking an unlock.
    door:setKeyId(newId)

    -- Store an audit marker on the world object so save/reload can test both
    -- the native door KeyId and ordinary object modData persistence.
    local dmd = door:getModData()
    dmd.SledgeLocksmith_RekeyedByPOC = true
    dmd.SledgeLocksmith_LastOldKeyId = oldId
    dmd.SledgeLocksmith_LastNewKeyId = newId
    dmd.SledgeLocksmith_ImprintName = pmd[SL.MD_ACTIVE_NAME]
    dmd.SledgeLocksmith_ImprintSourceX = pmd[SL.MD_ACTIVE_SOURCE_X]
    dmd.SledgeLocksmith_ImprintSourceY = pmd[SL.MD_ACTIVE_SOURCE_Y]
    dmd.SledgeLocksmith_ImprintSourceZ = pmd[SL.MD_ACTIVE_SOURCE_Z]
    dmd.SledgeLocksmith_RekeyVersion = SL.VERSION

    local afterId = door:getKeyId()
    log("REKEY APPLIED. Target=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
        .. " oldKeyId=" .. tostring(oldId)
        .. " requestedNewKeyId=" .. tostring(newId)
        .. " door:getKeyId() after=" .. tostring(afterId))

    if afterId == newId then
        halo(player, "REKEY SUCCESS: " .. tostring(oldId) .. " -> " .. tostring(newId) .. ". Test old key, then new key.")
    else
        halo(player, "REKEY ERROR: door did not retain requested KeyId - check console")
        log("ERROR: setKeyId mismatch after rekey. Expected=" .. tostring(newId) .. " actual=" .. tostring(afterId))
    end
end

local function unwrapInventoryEntry(entry)
    if not entry then return nil end

    if instanceof(entry, "InventoryItem") then
        return entry
    end

    local wrapped = entry.items
    if wrapped then
        if wrapped[1] then
            return wrapped[1]
        end

        local ok, first = pcall(function()
            if wrapped:size() > 0 then
                return wrapped:get(0)
            end
            return nil
        end)
        if ok then return first end
    end

    return nil
end

local function onWorldContextMenu(playerNum, context, worldObjects)
    local player = getPlayer(playerNum)
    if not player then return end

    context:addOption("[POC] Give Locksmith 0.0.2 Test Kit", player, giveTestKit)

    local door = getDoorFromWorldObjects(worldObjects)
    if not door then return end

    local keyId = door:getKeyId()
    local inspectText = "[POC] Door getKeyId(): " .. tostring(keyId)
    local inspectOption = context:addOption(inspectText, nil, nil)
    if inspectOption then inspectOption.notAvailable = true end

    context:addOption("[POC] Inspect Door Rekey State", player, inspectDoorState, door)

    if getLocksmithTool(player) then
        context:addOption("[POC] Take Lock Imprint", player, takeImprint, door)
    else
        local missing = context:addOption("[POC] Take Lock Imprint (need Locksmith Tool)", nil, nil)
        if missing then missing.notAvailable = true end
    end

    local armedId = getArmedKeyId(player)
    if armedId then
        context:addOption("[POC] APPLY ARMED IMPRINT -> KeyId " .. tostring(armedId), player, applyArmedImprint, door)
        context:addOption("[POC] Disarm Rekey Imprint", player, clearArmedImprint)
    else
        local noArm = context:addOption("[POC] Apply Imprint (arm one in inventory first)", nil, nil)
        if noArm then noArm.notAvailable = true end
    end
end

local function onInventoryContextMenu(playerNum, context, items)
    local player = getPlayer(playerNum)
    if not player or not items then return end

    local imprint = nil
    for i = 1, #items do
        local candidate = unwrapInventoryEntry(items[i])
        if candidate and candidate:getFullType() == SL.IMPRINT_TYPE then
            imprint = candidate
            break
        end
    end

    if not imprint then return end

    context:addOption("[POC] Inspect Lock Imprint", player, inspectImprint, imprint)
    context:addOption("[POC] ARM THIS IMPRINT FOR REKEY", player, armImprintForRekey, imprint)

    if getBlankKey(player) then
        context:addOption("[POC] Cut Test Key (uses 1 Blank Key)", player, cutTestKey, imprint)
    else
        local noBlank = context:addOption("[POC] Cut Test Key (need Blank Key)", nil, nil)
        if noBlank then noBlank.notAvailable = true end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onWorldContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(onInventoryContextMenu)

log("Loaded. 0.0.2 single-player rekey + persistence proof-of-concept ready.")
