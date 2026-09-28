// installer.ig — Ignid Setup
// Copies the Ignid toolchain (from the folder this .exe was launched from) into
// %LOCALAPPDATA%\Ignid, bundles NASM, auto-detects Visual Studio's MSVC linker +
// Windows SDK via a small PowerShell helper, writes ignid_paths.cfg, and adds
// the install directory to the current user's PATH.
use "d:/Ignid/std.ig":

// cmd.exe's built-in `copy`/`mkdir`/`del` misparse paths with more than one
// forward slash (they'll report "cannot find the file" on a perfectly valid
// path) — so any path handed to those built-ins is converted to real
// backslashes first. External .exe tools (xcopy, nasm, link) don't have this
// problem and are given the plain forward-slash paths as-is.
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

fn mkd(text dir) -> int [
    give system("mkdir \"" + winpath(dir) + "\" 2>NUL"):
]

fn cp(text src, text dst) -> int [
    give system("copy /Y \"" + winpath(src) + "\" \"" + winpath(dst) + "\" >NUL"):
]

fn xcp(text src, text dst) -> int [
    give system("xcopy /Y /I /E /Q \"" + src + "\" \"" + dst + "\" >NUL"):
]

start [
    // When launched by innosetup.iss (via `Parameters: "--from-inno"`), Inno
    // has already copied every file (its [Files] section) and already owns
    // the .ig file association + Control Panel entry (its [Registry] section
    // + auto-generated uninstaller) — doing those again here would create
    // duplicate/conflicting Control Panel entries and registry values.
    // Standalone (no Inno wrapper), this .exe is the whole installer and
    // does all of it itself.
    let int from_inno = 0:
    when argc() > 0 and argv(0) == "--from-inno" [ from_inno = 1: ]

    iglog("======================================="):
    iglog(" Ignid Setup"):
    iglog("======================================="):

    let text src    = exedir():
    let text target = getenv("LOCALAPPDATA") + "/Ignid":
    iglog("Install directory: " + target):
    iglog(""):

    when from_inno == 0 [
        iglog("Source (payload):  " + src):
        mkd(target):
        mkd(target + "/tools"):

        let list files = list_new_text():
        push(files, "ignidc.exe"):
        push(files, "ignid.exe"):
        push(files, "checker_s11.exe"):
        push(files, "irgen_s10.exe"):
        push(files, "opt.exe"):
        push(files, "codegen_s11.exe"):
        push(files, "codegen_s10.exe"):
        push(files, "std.ig"):
        push(files, "ignidweb.ig"):
        push(files, "uninstall.exe"):
        push(files, "LICENSE"):
        push(files, "README.md"):

        let int i = 0: let int n = len(files):
        loop while i < n [
            let text f = files{i}:
            iglog("  copying " + f):
            cp(src + "/" + f, target + "/" + f):
            i = i + 1:
        ]

        iglog("  copying tools/nasm.exe"):
        cp(src + "/tools/nasm.exe", target + "/tools/nasm.exe"):

        iglog("  copying docs/"):
        xcp(src + "/docs", target + "/docs"):

        iglog("  copying demos/"):
        xcp(src + "/demos", target + "/demos"):
    ]

    // The demo .ig files' `use "d:/Ignid/...":` directives are hardcoded to the
    // dev machine's path — `use` is resolved by literal text-splice at compile
    // time, with no concept of "relative to this source file", so an absolute
    // path baked in at build time can never be right on someone else's machine
    // (or even this one, under a different username). Rewrite each demo to
    // point at wherever this install actually landed. Needed either way —
    // Inno's own [Files] copy doesn't know about this Ignid-specific issue.
    iglog("  fixing demo use-paths..."):
    let list demo_files = list_new_text():
    push(demo_files, "01_hello.ig"):
    push(demo_files, "02_add.ig"):
    push(demo_files, "03_list.ig"):
    push(demo_files, "04_forloop.ig"):
    push(demo_files, "05_objects_functions_trycatch.ig"):
    push(demo_files, "06_class_style.ig"):
    push(demo_files, "07_map_float.ig"):
    push(demo_files, "demo.ig"):
    push(demo_files, "demo2.ig"):
    push(demo_files, "demoweb.ig"):

    let int di = 0: let int dn = len(demo_files):
    loop while di < dn [
        let text dpath = target + "/demos/" + demo_files{di}:
        try [
            let text content = readfile(dpath):
            let text fixed = replace(content, "d:/Ignid", target):
            writefile(dpath, fixed):
        ]
        catch [
            iglog("    (skipped " + demo_files{di} + ": " + lasterror() + ")"):
        ]
        di = di + 1:
    ]

    // ---- write + run the toolchain-detection / PATH-update helper ----
    let text ps1 = "":
    ps1 = ps1 + "$installDir = \"" + "$env:LOCALAPPDATA/Ignid" + "\"\n":
    ps1 = ps1 + "$vswhere = \"C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe\"\n":
    ps1 = ps1 + "$link = \"\"\n":
    ps1 = ps1 + "$msvcrt = \"\"\n":
    ps1 = ps1 + "$kernel32 = \"\"\n":
    ps1 = ps1 + "$ws2 = \"\"\n":
    ps1 = ps1 + "if (Test-Path $vswhere) {\n":
    ps1 = ps1 + "  $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath\n":
    ps1 = ps1 + "  if ($vsPath) {\n":
    ps1 = ps1 + "    $verFile = \"$vsPath/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt\"\n":
    ps1 = ps1 + "    if (Test-Path $verFile) {\n":
    ps1 = ps1 + "      $ver = (Get-Content $verFile).Trim()\n":
    ps1 = ps1 + "      $link = \"$vsPath/VC/Tools/MSVC/$ver/bin/HostX64/x64/link.exe\"\n":
    ps1 = ps1 + "      $msvcrt = \"$vsPath/VC/Tools/MSVC/$ver/lib/x64/msvcrt.lib\"\n":
    ps1 = ps1 + "    }\n":
    ps1 = ps1 + "  }\n":
    ps1 = ps1 + "}\n":
    ps1 = ps1 + "$sdkRoot = \"C:/Program Files (x86)/Windows Kits/10/Lib\"\n":
    ps1 = ps1 + "$rc = \"\"\n":
    ps1 = ps1 + "if (Test-Path $sdkRoot) {\n":
    ps1 = ps1 + "  $sdkVer = Get-ChildItem $sdkRoot -Directory | Where-Object { Test-Path \"$($_.FullName)/um/x64/kernel32.Lib\" } | Sort-Object Name -Descending | Select-Object -First 1\n":
    ps1 = ps1 + "  if ($sdkVer) {\n":
    ps1 = ps1 + "    $kernel32 = \"$($sdkVer.FullName)/um/x64/kernel32.Lib\"\n":
    ps1 = ps1 + "    $ws2 = \"$($sdkVer.FullName)/um/x64/WS2_32.Lib\"\n":
    ps1 = ps1 + "    $rcPath = \"C:/Program Files (x86)/Windows Kits/10/bin/$($sdkVer.Name)/x64/rc.exe\"\n":
    ps1 = ps1 + "    if (Test-Path $rcPath) { $rc = $rcPath }\n":
    ps1 = ps1 + "  }\n":
    ps1 = ps1 + "}\n":
    ps1 = ps1 + "$cfg = @()\n":
    ps1 = ps1 + "$cfg += \"NASM=$installDir/tools/nasm.exe\"\n":
    ps1 = ps1 + "$cfg += \"LINK=$link\"\n":
    ps1 = ps1 + "$cfg += \"RC=$rc\"\n":
    ps1 = ps1 + "$cfg += \"MSVCRT=$msvcrt\"\n":
    ps1 = ps1 + "$cfg += \"KERNEL32=$kernel32\"\n":
    ps1 = ps1 + "$cfg += \"WS2_32=$ws2\"\n":
    ps1 = ps1 + "$cfg | Set-Content -Encoding ASCII \"$installDir/ignid_paths.cfg\"\n":
    ps1 = ps1 + "if ($link -eq \"\") {\n":
    ps1 = ps1 + "  Write-Host \"WARNING: Visual Studio Build Tools (Desktop development with C++ workload) was not found.\"\n":
    ps1 = ps1 + "  Write-Host \"Install it, then re-run this installer, to enable compiling .ig programs.\"\n":
    ps1 = ps1 + "}\n":
    ps1 = ps1 + "$userPath = [Environment]::GetEnvironmentVariable(\"Path\",\"User\")\n":
    ps1 = ps1 + "if ($userPath -notlike \"*$installDir*\") {\n":
    ps1 = ps1 + "  $newPath = \"$userPath;$installDir\"\n":
    ps1 = ps1 + "  [Environment]::SetEnvironmentVariable(\"Path\", $newPath, \"User\")\n":
    ps1 = ps1 + "  Write-Host \"Added $installDir to your PATH. Restart your terminal for it to take effect.\"\n":
    ps1 = ps1 + "} else {\n":
    ps1 = ps1 + "  Write-Host \"$installDir is already on PATH.\"\n":
    ps1 = ps1 + "}\n":
    when from_inno == 0 [
        // ---- .ig file association + icon (HKCU, no admin needed) ----
        ps1 = ps1 + "New-Item -Path \"HKCU:/Software/Classes/.ig\" -Force | Out-Null\n":
        ps1 = ps1 + "Set-ItemProperty -Path \"HKCU:/Software/Classes/.ig\" -Name \"(Default)\" -Value \"IgnidFile.ig\"\n":
        ps1 = ps1 + "New-Item -Path \"HKCU:/Software/Classes/IgnidFile.ig\" -Force | Out-Null\n":
        ps1 = ps1 + "Set-ItemProperty -Path \"HKCU:/Software/Classes/IgnidFile.ig\" -Name \"(Default)\" -Value \"Ignid File\"\n":
        ps1 = ps1 + "New-Item -Path \"HKCU:/Software/Classes/IgnidFile.ig/DefaultIcon\" -Force | Out-Null\n":
        ps1 = ps1 + "Set-ItemProperty -Path \"HKCU:/Software/Classes/IgnidFile.ig/DefaultIcon\" -Name \"(Default)\" -Value \"$installDir\\ignid.exe,0\"\n":
        // ---- Control Panel / Apps & Features entry (HKCU, no admin needed) ----
        ps1 = ps1 + "$uninstKey = \"HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall/Ignid\"\n":
        ps1 = ps1 + "New-Item -Path $uninstKey -Force | Out-Null\n":
        ps1 = ps1 + "Set-ItemProperty -Path $uninstKey -Name \"DisplayName\" -Value \"Ignid Programming Language\"\n":
        ps1 = ps1 + "Set-ItemProperty -Path $uninstKey -Name \"DisplayVersion\" -Value \"1.0.0\"\n":
        ps1 = ps1 + "Set-ItemProperty -Path $uninstKey -Name \"Publisher\" -Value \"EnduraSolution\"\n":
        ps1 = ps1 + "Set-ItemProperty -Path $uninstKey -Name \"DisplayIcon\" -Value \"$installDir\\ignid.exe,0\"\n":
        ps1 = ps1 + "Set-ItemProperty -Path $uninstKey -Name \"InstallLocation\" -Value \"$installDir\"\n":
        ps1 = ps1 + "$q = [char]34\n":
        ps1 = ps1 + "Set-ItemProperty -Path $uninstKey -Name \"UninstallString\" -Value ($q + $installDir + \"\\uninstall.exe\" + $q)\n":
        ps1 = ps1 + "Set-ItemProperty -Path $uninstKey -Name \"NoModify\" -Value 1 -Type DWord\n":
        ps1 = ps1 + "Set-ItemProperty -Path $uninstKey -Name \"NoRepair\" -Value 1 -Type DWord\n":
        // Tell Explorer to refresh icons for the new association immediately,
        // instead of waiting for its icon cache to notice on its own.
        ps1 = ps1 + "$sig = '[System.Runtime.InteropServices.DllImport(\"shell32.dll\")] public static extern void SHChangeNotify(int e,int f,IntPtr a,IntPtr b);'\n":
        ps1 = ps1 + "Add-Type -MemberDefinition $sig -Namespace WinAPI -Name Explorer\n":
        ps1 = ps1 + "[WinAPI.Explorer]::SHChangeNotify(0x8000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)\n":
        ps1 = ps1 + "Write-Host \"Registered .ig file icon and Control Panel entry.\"\n":
    ]

    let text ps1path = target + "/_ignid_setup.ps1":
    writefile(ps1path, ps1):
    iglog(""):
    iglog("Detecting Visual Studio / Windows SDK, updating PATH..."):
    system("powershell -NoProfile -ExecutionPolicy Bypass -File \"" + ps1path + "\""):
    system("del \"" + winpath(ps1path) + "\""):

    iglog(""):
    iglog("======================================="):
    iglog(" Ignid installed to " + target):
    iglog(" Restart your terminal, then run:  ignid --version"):
    iglog("======================================="):
]
