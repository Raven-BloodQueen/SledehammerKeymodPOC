SLEDGEHAMMER LOCKSMITH 0.0.2 POC
Target: Project Zomboid Build 42.20.x

END USER WORKFLOW GOALS
-------------------------
- Find blank key
- Find Locksmith Tool
- Find Key Machine
- Use Locksmith Tool on door, retrieve imprint (which can be renamed with a new label)
- Crafting recipe; Key Machine + Locksmith imprint + blank key = imprinted key
- Imprinted key is able to lock and unlock doors with the correct imprint.
- Locksmith tool stores imprint, can use on other doors to either steal their imprints or to apply other imprint upon door.

WHAT 0.0.1 ALREADY PROVED
-------------------------
Vanilla door KeyId -> Lock Imprint -> vanilla Blank Key -> real vanilla Key
works. PZ accepted the copied key on the original door.

WHAT 0.0.2 PROVES
-----------------
1. Read Door A's original native KeyId.
2. Read a DIFFERENT Door B's native KeyId.
3. Make keys for both IDs so we know what each key belongs to.
4. Arm Door B's Lock Imprint.
5. Apply Door B's imprint to Door A using IsoDoor:setKeyId().
6. Confirm Door A now reports Door B's KeyId.
7. Confirm old Key A no longer opens Door A.
8. Confirm Key B now opens Door A.
9. Save and reload.
10. Confirm Door A still reports the new KeyId and Key B still work.

REPRODUCTION TEST
---------------------------------
VERY IMPORTANT: Door A and Door B should be on DIFFERENT vanilla buildings.
Vanilla doors in the same building may share a KeyId, which would make the
rekey test meaningless.

1. Load a disposable SINGLE-PLAYER save.
2. Right-click world -> [POC] Give Locksmith 0.0.2 Test Kit.
   You get the tool + 3 vanilla Blank Keys.

DOOR A = TARGET DOOR WE WILL CHANGE
3. Find a normal locked vanilla door on Building A.
4. Right-click Door A -> [POC] Take Lock Imprint.
5. Right-click the new Door A imprint -> [POC] Cut Test Key.
   This is OLD KEY A. Leave Door A locked for now.
6. Write down Door A's ID or just remember which cut key belongs to A.

DOOR B = DONOR LOCK PROFILE
7. Walk to a DIFFERENT vanilla building.
8. Find a normal locked vanilla door on Building B.
9. Take its Lock Imprint.
10. Cut a test key from Door B's imprint.
    This is KEY B.
11. Check that Door B's ID is DIFFERENT from Door A's ID.
    If the IDs match, choose another building.

ARM THE DONOR IMPRINT
12. Right-click Door B's Lock Imprint in inventory.
13. Choose:
       [POC] ARM THIS IMPRINT FOR REKEY
14. You should get a halo message showing the armed KeyId.

REKEY DOOR A
15. Return to Door A.
16. Right-click Door A.
17. Choose:
       [POC] APPLY ARMED IMPRINT -> KeyId <B's ID>
18. You should get:
       REKEY SUCCESS: <A ID> -> <B ID>
19. Right-click Door A -> [POC] Inspect Door Rekey State.
    It should show current Door ID = B's ID and the A -> B audit marker.

FUNCTION TEST
-------------
20. Make sure Door A is CLOSED + LOCKED.
21. IMPORTANT: move KEY B COMPLETELY OUT OF YOUR CHARACTER INVENTORY
    (drop it on the ground or put it in a nearby world container).
    Keep only OLD KEY A on your character and try Door A normally.
    EXPECTED: OLD KEY A should NOT unlock Door A anymore.
22. Retrieve KEY B and keep it on your character. Try Door A normally.
    EXPECTED: KEY B SHOULD unlock Door A.

Why the stash step matters: PZ can use a matching key from your inventory. If
Key B is still carried while you "test" Key A, Door A may open using B and give
us a false result.

If both are true, native rekeying works in the current session.

SAVE / RELOAD
------------------------
23. Close + lock Door A again using KEY B.
24. Save / quit to menu.
25. Reload the same save.
26. Return to Door A.
27. Right-click -> [POC] Inspect Door Rekey State.

EXPECTED AFTER RELOAD:
- Door current KeyId is still B's ID.
- Audit marker still says old A ID -> new B ID.
- With KEY B stashed outside your inventory, OLD KEY A still does not work.
- After retrieving KEY B, KEY B still opens Door A.

CONSOLE TAG
-----------
Search console.txt for:
    [SLEDGE-LOCK 0.0.2] (Or matching Version)

IMPORTANT LINES
--------------------
[SLEDGE-LOCK 0.0.2] IMPRINT CREATED. Stored KeyId = ...
[SLEDGE-LOCK 0.0.2] CUT KEY CREATED. key:getKeyId() = ...
[SLEDGE-LOCK 0.0.2] REKEY IMPRINT ARMED. KeyId=...
[SLEDGE-LOCK 0.0.2] REKEY APPLIED. Target=... oldKeyId=... requestedNewKeyId=... door:getKeyId() after=...
[SLEDGE-LOCK 0.0.2] DOOR INSPECT: ... currentKeyId=... rekeyMarker=true old=... new=...
