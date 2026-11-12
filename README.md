# discsc.bat

> Disable Windows CSC feature

https://github.com/lukaszjablonski/discsc.bat

Windows batch script that check and (optionally) disable the Windows "Offline Files" (CSC, Client Side Caching) feature

## What it does, step by step

1. **Elevation check** – aborts if not run as Administrator (`net session`).
2. **Reads current state**:
   - `HKLM\SYSTEM\CurrentControlSet\Services\CSC` → `Start` (the CSC filter driver's startup type: `0x1`=enabled-ish, `0x4`=disabled).
   - `HKLM\SYSTEM\CurrentControlSet\Services\CSC\Parameters` → `FormatDatabase` (flag that tells Windows to wipe the CSC cache on next boot).
3. **Prints a status summary** of both values.
4. **Decision logic**:
   - If it can't read `Start`, it skips straight to verification.
   - If `Start=0x4` already, it reports "already disabled" and skips to verification.
   - Otherwise it warns you (sync conflicts, unsynced edits) and asks Y/N before doing anything destructive.
5. **If confirmed, performs the actual disable sequence**:
   - `sc stop CscService` – stop the "Offline Files" service.
   - `sc config CscService start= disabled` – stop it from starting again.
   - `reg add ...\Policies\Microsoft\Windows\NetCache /v Enabled /d 0` – local-policy equivalent of the GPO "Allow or Disallow use of the Offline Files feature" = Disallow.
   - `reg add ...\Services\CSC /v Start /d 4` – disable the CSC driver itself.
   - `reg add ...\Services\CSC\Parameters /v FormatDatabase /d 1` – schedule a cache wipe (clears `C:\Windows\CSC`) on next boot.
6. **Offers to reboot immediately** (10-second `shutdown /r`), or lets you reboot later.
7. **Verification block** (always runs) – re-queries all of the above plus service state (`sc query`) and service startup type (`sc qc`), and reminds you to check Sync Center / Explorer / disk space manually.

This is the same standard sequence documented in various Microsoft/community troubleshooting guides for completely disabling Offline Files and resetting a corrupted CSC cache.

## Caveats worth knowing (not bugs, but things to be aware of)

- **Requires a reboot** to actually take effect — the script correctly says so, but nothing works until then, especially the cache wipe.
- **Domain Group Policy can override it.** `HKLM\SOFTWARE\Policies\Microsoft\Windows\NetCache` is exactly the key a domain GPO ("Allow or Disallow use of the Offline Files feature") would also write. If your machine is domain-joined and a GPO enables Offline Files, a `gpupdate /force` or policy refresh could silently re‑enable it after your reboot.
- **English-locale dependent.** The verification section greps for literal strings like `"STATE"`, `"START_TYPE"`, `"Start"`, `"FormatDatabase"`. On a non-English Windows install, `sc`/`reg` output uses localised labels, so those `findstr` matches could come back empty even though the underlying values are correct. This only affects the *display*, not the actual registry/service changes.
- **No rollback script** — if you want to re-enable Offline Files later, you'd need to manually reverse the five registry/service changes (there's nothing scripted for that).
- Logic correctly treats "0x4" as the only "already disabled" state; other `Start` values (2, 3, etc.) fall through to the disable branch, which is the expected/sane behaviour.
