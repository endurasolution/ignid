// uninstall.ig — removes Ignid: PATH entry, .ig file association, Control
// Panel entry, and the installed files themselves.
use "d:/Ignid/std.ig":

fn winpath(text p) -> text [
    let text bs = chr(92):
    let text out = "":
    let int i = 0: let int n = len(p):
    loop while i < n [
        when p{i} == "/" [ out = out + bs: ]
        else [ out = out + p{i}: ]
        i = i + 1:
    ]
    give out:
]

start [
    // When run by Inno's own generated uninstaller ([UninstallRun] with
    // `Parameters: "--from-inno"`), Inno already owns file deletion and its
    // own [Registry]-managed .ig association / Control Panel entry (with
    // uninsdeletekey/uninsdeletevalue) — this run should ONLY clean up the
    // PATH entry, which is the one thing Inno's script doesn't manage.
    // Standalone (double-clicked from the install folder, or via the
    // separately-registered Control Panel entry this same installer created
    // when NOT run through Inno), it does the full teardown itself.
    let int from_inno = 0:
    when argc() > 0 and argv(0) == "--from-inno" [ from_inno = 1: ]

    let text target = getenv("LOCALAPPDATA") + "/Ignid":

    when from_inno == 0 [
        iglog("======================================="):
        iglog(" Uninstall Ignid"):
        iglog("======================================="):
        iglog("This will remove Ignid from: " + target):
        let text confirm = trim(ask("Continue? [y/N]: ")):
        when confirm != "y" and confirm != "Y" [
            iglog("Cancelled."):
            quit(0):
        ]
    ]

    let text ps1 = "":
    // A directory can't be fully deleted while any process (this one
    // included) has it as its current working directory — e.g. if you `cd`
    // into the install folder before running this uninstaller. Relocate
    // immediately so nothing in this script's own process chain holds that
    // lock, regardless of where the uninstaller itself was launched from.
    ps1 = ps1 + "Set-Location $env:TEMP\n":
    ps1 = ps1 + "$installDir = \"" + "$env:LOCALAPPDATA/Ignid" + "\"\n":
    ps1 = ps1 + "$userPath = [Environment]::GetEnvironmentVariable(\"Path\",\"User\")\n":
    ps1 = ps1 + "if ($userPath) {\n":
    ps1 = ps1 + "  $parts = ($userPath -split \";\") | Where-Object { $_ -ne $installDir -and $_ -ne \"\" }\n":
    ps1 = ps1 + "  [Environment]::SetEnvironmentVariable(\"Path\", ($parts -join \";\"), \"User\")\n":
    ps1 = ps1 + "}\n":

    when from_inno == 0 [
        ps1 = ps1 + "Remove-Item -Path \"HKCU:/Software/Classes/.ig\" -Force -ErrorAction SilentlyContinue\n":
        ps1 = ps1 + "Remove-Item -Path \"HKCU:/Software/Classes/IgnidFile.ig\" -Recurse -Force -ErrorAction SilentlyContinue\n":
        ps1 = ps1 + "Remove-Item -Path \"HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall/Ignid\" -Force -ErrorAction SilentlyContinue\n":
        ps1 = ps1 + "$sig = '[System.Runtime.InteropServices.DllImport(\"shell32.dll\")] public static extern void SHChangeNotify(int e,int f,IntPtr a,IntPtr b);'\n":
        ps1 = ps1 + "Add-Type -MemberDefinition $sig -Namespace WinAPI -Name Explorer\n":
        ps1 = ps1 + "[WinAPI.Explorer]::SHChangeNotify(0x8000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)\n":
        // This uninstall.exe is itself a file inside $installDir, so it can't
        // delete its own containing folder while running. Hand the actual
        // folder removal off to a fully detached process that waits for this
        // one (and the powershell.exe running this very script) to exit
        // first. Only needed standalone — when run via Inno, Inno's own
        // uninstaller deletes {app} itself right after this process exits.
        ps1 = ps1 + "$deleteCmd = \"Set-Location " + chr(36) + "env:TEMP; Start-Sleep -Seconds 3; Remove-Item -Recurse -Force '$installDir'\"\n":
        ps1 = ps1 + "Start-Process powershell -ArgumentList @('-NoProfile','-WindowStyle','Hidden','-Command',$deleteCmd) -WindowStyle Hidden\n":
        ps1 = ps1 + "Write-Host \"Removed PATH entry, file association, and Control Panel entry.\"\n":
    ]
    when from_inno == 1 [
        ps1 = ps1 + "Write-Host \"Removed PATH entry.\"\n":
    ]

    let text ps1path = getenv("TEMP") + "/ignid_uninstall.ps1":
    writefile(ps1path, ps1):
    system("powershell -NoProfile -ExecutionPolicy Bypass -File \"" + ps1path + "\""):
    system("del \"" + winpath(ps1path) + "\" 2>NUL"):

    when from_inno == 0 [
        iglog(""):
        iglog("Ignid has been uninstalled."):
        iglog("(The install folder finishes removing itself in the background"):
        iglog(" a few seconds after this window closes.)"):
    ]
]
