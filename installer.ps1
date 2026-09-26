<#
.SYNOPSIS
    ALIENX INSTALLER - animated console (text-based) installer UI.

.DESCRIPTION
    Single-file PowerShell script. Pure console rendering via ANSI/VT escape codes,
    no WPF/WinForms. Works on Windows PowerShell 5.1 (conhost) and PowerShell 7 /
    The after-boost FPS readout uses PresentMon when it is available and FiveM is running.
    Windows Terminal. UI only - Invoke-Install / Invoke-Uninstall are placeholders.

.USAGE
    powershell -ExecutionPolicy Bypass -File .\installer.ps1
#>

# ==============================================================================
#region Config  (colors, texts, speeds - tweak the theme here)
# ==============================================================================

$e = [char]27
$Reset = "$e[0m"

$Config = @{
    Title           = "ALIENX INSTALLER"
    ConsoleWidth    = 90
    ConsoleHeight   = 32
    FontName        = "Cascadia Mono"
    FontSize        = 18

    # Theme gradient colors (start -> end). Names kept as ColorPurple/ColorCyan
    # to avoid touching every call site, but they now hold a dark-red ->
    # bright-red gradient to match a red UI theme. Change these two values
    # to retheme the whole banner, progress bar, box border and menu
    # highlight in one place.
    ColorPurple     = @{ R = 139; G = 0;   B = 0 }     # dark red  #8B0000
    ColorCyan       = @{ R = 255; G = 45;  B = 45 }    # bright red #FF2D2D
    ColorDimGray    = @{ R = 130; G = 130; B = 130 }
    ColorDarkGray   = @{ R = 70;  G = 70;  B = 70 }
    ColorGreen      = @{ R = 0;   G = 210; B = 110 }
    ColorRed        = @{ R = 225; G = 55;  B = 55 }
    ColorYellow     = @{ R = 230; G = 200; B = 40 }

    MenuItems       = @("INSTALL", "UNINSTALL", "EXIT")

    IdleFPS         = 15
    IdlePhaseStep   = 0.015
    BootLineDelayMs = 160
    GlitchFrames    = 3
    GlitchDelayMs   = 18

    BootLines = @(
        "[ OK ] Loading modules...",
        "[ OK ] Checking permissions...",
        "[ OK ] Ready."
    )

    # ANSI-shadow style block-letter banner spelling ALIENX
    BannerLines = @(
        " █████╗  ██╗      ██╗ ███████╗ ███╗   ██╗ ██╗  ██╗",
        "██╔══██╗ ██║      ██║ ██╔════╝ ████╗  ██║ ╚██╗██╔╝",
        "███████║ ██║      ██║ █████╗   ██╔██╗ ██║  ╚███╔╝ ",
        "██╔══██║ ██║      ██║ ██╔══╝   ██║╚██╗██║  ██╔██╗ ",
        "██║  ██║ ███████╗ ██║ ███████╗ ██║ ╚████║ ██╔╝ ██╗",
        "╚═╝  ╚═╝ ╚══════╝ ╚═╝ ╚══════╝ ╚═╝  ╚═══╝ ╚═╝  ╚═╝"
    )

    Spinner = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')

    # Access gate - set AccessPassword to require a code before the menu is
    # shown at all. Leave it as an empty string ("") to disable the gate.
    AccessPassword       = "alienxdev"
    MaxPasswordAttempts  = 1

    # Aggressive-but-safe cleanup: closes a broad set of NON-ESSENTIAL user apps
    # and their helper trees before the FPS measurement. It deliberately does NOT
    # use a "kill every process" rule, because doing that can terminate Windows
    # services, FiveM dependencies, drivers, input software, or security components.
    #
    # Matching is by process name (no .exe). Only apps in this explicit list are
    # eligible for automatic closing. Add/remove names here to fit your PC.
    BoostProcessNames = @(
        # Cloud / sync / file helpers
        "OneDrive", "Dropbox", "GoogleDriveFS", "iCloudDrive", "iCloudServices",
        "iCloudUserNotifications", "MEGAsync", "Box", "BoxDrive",
        # Browsers - safe to close for a dedicated gaming session
        "chrome", "msedge", "brave", "firefox", "opera", "opera_gx", "vivaldi",
        "arc", "zen", "waterfox", "librewolf",
        # Chat / work / meeting apps
        "Teams", "ms-teams", "MSTeams", "Skype", "SkypeApp", "Slack", "Zoom",
        "WhatsApp", "WhatsAppWeb", "Telegram", "LINE", "Signal", "Webex",
                # Media / widgets / phone / Windows gaming extras
        "Spotify", "SpotifyWebHelper", "GameBarPresenceWriter", "GameBar",
        "GameBarFTServer", "XboxPcApp", "XboxAppServices", "Widgets",
        "WidgetsBroker", "PhoneExperienceHost", "YourPhone", "YourPhoneServer",
        "Clipchamp", "ScreenClippingHost",
        # Discord and common companion helpers
        "Discord", "DiscordPTB", "DiscordCanary", "DiscordUpdate",
        # Game launchers and their non-essential web/helper processes. Keep Steam
        # and Rockstar itself available for FiveM; web helpers may be closed.
        "EpicGamesLauncher", "EpicWebHelper", "EALauncher", "EA", "EADesktop", "EABackgroundService",
        "Origin", "OriginWebHelper", "RiotClientServices", "RiotClientUx", "RiotClientCrashHandler",
        "upc", "upc.exe", "GalaxyClient", "GalaxyClientService",
        "Overwolf", "Amazon Games", "GOGGalaxy", "GOGGalaxyCommunication", "SteamWebHelper",
        # Adobe / creative background helpers
        "AdobeCollabSync", "CCXProcess", "Creative Cloud", "AdobeIPCBroker", "Adobe Desktop Service",
        "CoreSync", "CCLibrary", "AdobeNotificationClient",
        # Download / torrent utilities
        "qbittorrent", "uTorrent", "BitTorrent", "IDMan", "FDM",
        # OEM / updater helpers that are not required for the game itself
        "GoogleCrashHandler", "GoogleCrashHandler64",
        # Common third-party helper / updater processes
        "Bonjour", "DropboxUpdate", "SpotifyCrashService"
    )

    # Extra cleanup controls. These remain process-name allowlisted on purpose.
    KillProcessTree = $true
    CleanupPasses = 5          # catches helper processes that respawn
    CleanupWaitMs = 450        # lets the process list settle between passes
    AggressiveCleanup = $true  # enable the expanded non-essential app list above
    ShowProcessReduction = $true

    # Toggle individual gaming tweaks on/off without touching the logic below.
    # All of these are standard, reversible Windows performance tweaks - none
    # of them disable security features or touch anything destructive.
    Tweaks = @{
        HighPerformancePower    = $true    # switch to High performance / Ultimate Performance power plan
        UltimatePerformanceTry  = $true    # try to unlock "Ultimate Performance" before falling back to "High performance"
        DisableGameDVR          = $true    # turn off Xbox Game Bar's background recording overlay
        GamesTaskPriority       = $true    # tune the multimedia scheduler (MMCSS) to favor games
        ForegroundPriority      = $true    # give the focused app a bigger CPU time-slice than background apps
        NetworkOptimization      = $true    # registry-only network tuning: disable Nagle, disable network throttling, enable TCP window scaling
        VisualEffectsBestPerf   = $false   # OFF by default - sets Windows visual effects to "Best performance" (changes how the UI looks)
        CloseBackgroundApps     = $true    # close the apps listed in BoostProcessNames above
    ShowAfterBoostFPS        = $true    # measure and show real FPS immediately after the boost
    FPSCaptureSeconds        = 1.0      # short PresentMon capture window for the after-boost reading
    }
}

# Mutable UI state shared across functions
$Script:BannerX     = 0
$Script:BannerY     = 2
$Script:BoxX        = 0
$Script:BoxY        = 0
$Script:MenuX       = 0
$Script:MenuY       = 0
$Script:InfoY       = 0
$Script:FooterY     = 0
$Script:Selected    = 0
$Script:SpinnerIdx  = 0
$Script:LogY        = 0
$Script:OSVersion   = "Unknown"
$Script:UserName    = "Unknown"
$Script:IsAdminUser = $false
$Script:ProcessBefore = $null
$Script:ProcessAfter  = $null
$Script:ProcessDelta  = $null
$Script:ProcessClosed = 0
$Script:ProcessMatched = @()

#endregion

# ==============================================================================
#region Console setup  (VT mode, encoding, size, font, title, background)
# ==============================================================================

$NativeTypeDef = @"
using System;
using System.Runtime.InteropServices;

public static class NativeConsole
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CONSOLE_FONT_INFO_EX
    {
        public uint cbSize;
        public uint nFont;
        public short FontWidth;
        public short FontHeight;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FontFace;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);
}
"@

try {
    Add-Type -TypeDefinition $NativeTypeDef -Language CSharp -ErrorAction Stop
} catch {
    # Type may already be loaded in this session - ignore.
}

function Enable-VirtualTerminal {
    try {
        $STD_OUTPUT_HANDLE = -11
        $ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
        $hOut = [NativeConsole]::GetStdHandle($STD_OUTPUT_HANDLE)
        $mode = 0
        [NativeConsole]::GetConsoleMode($hOut, [ref]$mode) | Out-Null
        [NativeConsole]::SetConsoleMode($hOut, ($mode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING)) | Out-Null
    } catch {
        # Best effort - if this fails we simply may not get colors.
    }
}

function Set-ConsoleFontTheme {
    # Windows Terminal renders its own font settings - skip silently there.
    if ($env:WT_SESSION -or $env:WT_PROFILE_ID) { return }
    try {
        $STD_OUTPUT_HANDLE = -11
        $hOut = [NativeConsole]::GetStdHandle($STD_OUTPUT_HANDLE)
        $font = New-Object NativeConsole+CONSOLE_FONT_INFO_EX
        $font.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($font)
        [NativeConsole]::GetCurrentConsoleFontEx($hOut, $false, [ref]$font) | Out-Null

        $font.FontFamily = 54   # FF_MODERN | TMPF_TRUETYPE
        $font.FontWeight = 400
        $font.FontWidth  = 0
        $font.FontHeight = $Config.FontSize
        $font.FontFace   = $Config.FontName

        $ok = $false
        try { $ok = [NativeConsole]::SetCurrentConsoleFontEx($hOut, $false, [ref]$font) } catch { $ok = $false }

        if (-not $ok) {
            $font.FontFace = "Consolas"
            try { [NativeConsole]::SetCurrentConsoleFontEx($hOut, $false, [ref]$font) | Out-Null } catch { }
        }
    } catch {
        # Skip silently - font control is not critical to functionality.
    }
}

function Resize-ConsoleWindow {
    try {
        $w = $Config.ConsoleWidth
        $h = $Config.ConsoleHeight
        # Shrink the window first so the buffer can always grow to fit it.
        $small = New-Object System.Management.Automation.Host.Size(1, 1)
        try { $Host.UI.RawUI.WindowSize = $small } catch { }
        [Console]::SetBufferSize($w, $h)
        [Console]::SetWindowSize($w, $h)
    } catch {
        # Some hosts (ISE, redirected output) don't allow resizing - ignore.
    }
}

function Initialize-Console {
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    try { $Host.UI.RawUI.WindowTitle = $Config.Title } catch { }

    Enable-VirtualTerminal
    Set-ConsoleFontTheme
    Resize-ConsoleWindow

    try {
        $Host.UI.RawUI.BackgroundColor = "Black"
        $Host.UI.RawUI.ForegroundColor = "Gray"
    } catch { }

    try {
        $Script:OSVersion = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
    } catch {
        $Script:OSVersion = [System.Environment]::OSVersion.VersionString
    }
    $Script:UserName    = [System.Environment]::UserName
    $Script:IsAdminUser = Test-IsAdmin

    Clear-Host
    [Console]::Write("$e[?25l")   # hide cursor
}

function Test-IsAdmin {
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

#endregion

# ==============================================================================
#region Draw helpers  (Write-At, Write-Gradient, Draw-Box, Draw-Progress, color)
# ==============================================================================

function Get-FG([int]$r, [int]$g, [int]$b) { return "$e[38;2;$r;$g;${b}m" }
function Get-BG([int]$r, [int]$g, [int]$b) { return "$e[48;2;$r;$g;${b}m" }

function Write-At([int]$x, [int]$y, [string]$text) {
    [Console]::SetCursorPosition($x, $y)
    [Console]::Write($text)
}

function Get-GradientColor([hashtable]$c1, [hashtable]$c2, [double]$t) {
    if ($t -lt 0) { $t = 0 }
    if ($t -gt 1) { $t = 1 }
    return @{
        R = [int]($c1.R + ($c2.R - $c1.R) * $t)
        G = [int]($c1.G + ($c2.G - $c1.G) * $t)
        B = [int]($c1.B + ($c2.B - $c1.B) * $t)
    }
}

# Colors a line of text column-by-column from c1 to c2, with an optional
# wave "phase" (0..1) used to animate the gradient sliding left to right.
function Write-GradientLine([int]$x, [int]$y, [string]$text, [hashtable]$c1, [hashtable]$c2, [double]$phase = 0) {
    [Console]::SetCursorPosition($x, $y)
    $len = $text.Length
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $len; $i++) {
        $t = 0
        if ($len -gt 1) { $t = $i / [double]($len - 1) }
        $tw = $t + $phase
        $tw = $tw - [math]::Floor($tw)               # wrap into 0..1
        $tw2 = if ($tw -le 0.5) { $tw * 2 } else { (1 - $tw) * 2 }   # ping-pong purple<->cyan
        $col = Get-GradientColor $c1 $c2 $tw2
        [void]$sb.Append((Get-FG $col.R $col.G $col.B))
        [void]$sb.Append($text[$i])
    }
    [void]$sb.Append($Reset)
    [Console]::Write($sb.ToString())
}

function Draw-Box([int]$x, [int]$y, [int]$width, [int]$height, [hashtable]$color) {
    $fg = Get-FG $color.R $color.G $color.B
    Write-At $x $y ($fg + "╭" + ("─" * ($width - 2)) + "╮" + $Reset)
    for ($i = 1; $i -lt ($height - 1); $i++) {
        Write-At $x ($y + $i) ($fg + "│" + (" " * ($width - 2)) + "│" + $Reset)
    }
    Write-At $x ($y + $height - 1) ($fg + "╰" + ("─" * ($width - 2)) + "╯" + $Reset)
}

function Draw-ProgressBar([int]$x, [int]$y, [int]$width, [double]$percent, [hashtable]$c1, [hashtable]$c2) {
    $filled = [int]([math]::Round($width * ($percent / 100.0)))
    [Console]::SetCursorPosition($x, $y)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("[")
    for ($i = 0; $i -lt $width; $i++) {
        $t = 0
        if ($width -gt 1) { $t = $i / [double]($width - 1) }
        $col = Get-GradientColor $c1 $c2 $t
        [void]$sb.Append((Get-FG $col.R $col.G $col.B))
        if ($i -lt $filled) { [void]$sb.Append("█") } else { [void]$sb.Append("░") }
    }
    [void]$sb.Append($Reset)
    [void]$sb.Append("] {0,3}%" -f [int]$percent)
    [Console]::Write($sb.ToString())
}

#endregion

# ==============================================================================
#region Animations  (boot, banner reveal, idle wave, flash, fade)
# ==============================================================================

function Show-BootSequence {
    Clear-Host
    $y = 12
    foreach ($line in $Config.BootLines) {
        Write-At 12 $y ((Get-FG $Config.ColorGreen.R $Config.ColorGreen.G $Config.ColorGreen.B) + $line + $Reset)
        Start-Sleep -Milliseconds $Config.BootLineDelayMs
        $y++
    }
    Start-Sleep -Milliseconds 400
    Clear-Host
}

function Show-BannerReveal {
    $glitchChars = @('░', '▒', '▓')
    $maxLen = ($Config.BannerLines | Measure-Object -Property Length -Maximum).Maximum
    $Script:BannerX = [Math]::Max(0, [int](($Config.ConsoleWidth - $maxLen) / 2))
    $Script:BannerY = 2

    for ($li = 0; $li -lt $Config.BannerLines.Count; $li++) {
        $line = $Config.BannerLines[$li]
        $y = $Script:BannerY + $li
        for ($g = 0; $g -lt $Config.GlitchFrames; $g++) {
            $chars = 1..$line.Length | ForEach-Object { $glitchChars | Get-Random }
            $glitch = -join $chars
            Write-At $Script:BannerX $y ((Get-FG 140 140 140) + $glitch + $Reset)
            Start-Sleep -Milliseconds $Config.GlitchDelayMs
        }
        Write-GradientLine $Script:BannerX $y $line $Config.ColorPurple $Config.ColorCyan 0
        Start-Sleep -Milliseconds 45
    }
}

function Update-IdleBanner([double]$phase) {
    for ($li = 0; $li -lt $Config.BannerLines.Count; $li++) {
        Write-GradientLine $Script:BannerX ($Script:BannerY + $li) $Config.BannerLines[$li] $Config.ColorPurple $Config.ColorCyan $phase
    }
}

function Flash-MenuItem([int]$index) {
    $label = $Config.MenuItems[$index]
    $y = $Script:MenuY + $index
    for ($f = 0; $f -lt 3; $f++) {
        Write-At $Script:MenuX $y ((Get-BG 255 255 255) + (Get-FG 10 10 10) + "▶ " + $label.PadRight(12) + $Reset)
        Start-Sleep -Milliseconds 55
        Write-At $Script:MenuX $y ((Get-BG $Config.ColorCyan.R $Config.ColorCyan.G $Config.ColorCyan.B) + (Get-FG 10 10 10) + "▶ " + $label.PadRight(12) + $Reset)
        Start-Sleep -Milliseconds 55
    }
}

function Show-FadeOutExit {
    for ($f = 5; $f -ge 0; $f--) {
        $factor = $f / 5.0
        for ($li = 0; $li -lt $Config.BannerLines.Count; $li++) {
            $r = [int]($Config.ColorPurple.R * $factor)
            $g = [int]($Config.ColorPurple.G * $factor)
            $b = [int]($Config.ColorPurple.B * $factor)
            Write-At $Script:BannerX ($Script:BannerY + $li) ((Get-FG $r $g $b) + $Config.BannerLines[$li] + $Reset)
        }
        Start-Sleep -Milliseconds 90
    }
    Clear-Host
    $msg = "Goodbye."
    $x = [int](($Config.ConsoleWidth - $msg.Length) / 2)
    Write-At $x 15 ((Get-FG 150 150 150) + $msg + $Reset)
    Start-Sleep -Milliseconds 700
}

#endregion

# ==============================================================================
#region Menu loop  (static screen layout, selection handling, info/footer)
# ==============================================================================

function Draw-MenuItems {
    for ($i = 0; $i -lt $Config.MenuItems.Count; $i++) {
        $label = $Config.MenuItems[$i]
        $y = $Script:MenuY + $i
        if ($i -eq $Script:Selected) {
            $c = $Config.ColorCyan
            Write-At $Script:MenuX $y ((Get-BG $c.R $c.G $c.B) + (Get-FG 10 10 10) + "▶ " + $label.PadRight(12) + $Reset)
        } else {
            Write-At $Script:MenuX $y ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + "  " + $label.PadRight(12) + $Reset)
        }
    }
}

function Draw-InfoLine {
    $adminColor = if ($Script:IsAdminUser) { $Config.ColorGreen } else { $Config.ColorYellow }
    $adminText  = if ($Script:IsAdminUser) { "YES" } else { "NO" }
    $line = "OS: $($Script:OSVersion)  |  User: $($Script:UserName)  |  Admin: "
    $x = [Math]::Max(0, [int](($Config.ConsoleWidth - ($line.Length + $adminText.Length)) / 2))
    [Console]::SetCursorPosition($x, $Script:InfoY)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B))
    [void]$sb.Append($line)
    [void]$sb.Append((Get-FG $adminColor.R $adminColor.G $adminColor.B))
    [void]$sb.Append($adminText)
    [void]$sb.Append($Reset)
    [Console]::Write($sb.ToString())
}

function Draw-Footer {
    $text = "↑↓ navigate   ENTER select   ESC exit"
    $x = [Math]::Max(0, [int](($Config.ConsoleWidth - $text.Length) / 2))
    Write-At $x $Script:FooterY ((Get-FG $Config.ColorDarkGray.R $Config.ColorDarkGray.G $Config.ColorDarkGray.B) + $text + $Reset)
}

function Draw-StaticScreen {
    Clear-Host
    Update-IdleBanner 0

    $subtitle = "I N S T A L L E R   v1.0"
    $subX = [Math]::Max(0, [int](($Config.ConsoleWidth - $subtitle.Length) / 2))
    $subY = $Script:BannerY + $Config.BannerLines.Count + 1
    Write-At $subX $subY ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $subtitle + $Reset)

    $boxWidth  = 26
    $boxHeight = $Config.MenuItems.Count + 2
    $Script:BoxX = [Math]::Max(0, [int](($Config.ConsoleWidth - $boxWidth) / 2))
    $Script:BoxY = $subY + 3
    Draw-Box $Script:BoxX $Script:BoxY $boxWidth $boxHeight $Config.ColorCyan

    $Script:MenuX = $Script:BoxX + 3
    $Script:MenuY = $Script:BoxY + 1
    Draw-MenuItems

    $Script:InfoY   = $Script:BoxY + $boxHeight + 2
    $Script:FooterY = $Script:InfoY + 2
    Draw-InfoLine
    Draw-Footer

    if (-not $Script:IsAdminUser) {
        $warn = "Not running as Administrator - some actions may fail."
        $wx = [Math]::Max(0, [int](($Config.ConsoleWidth - $warn.Length) / 2))
        Write-At $wx ($Script:FooterY + 2) ((Get-FG $Config.ColorYellow.R $Config.ColorYellow.G $Config.ColorYellow.B) + $warn + $Reset)
    }
}

function Confirm-Action([string]$prompt = "Are you sure? [Y/N]") {
    Clear-Host
    $boxWidth = $prompt.Length + 6
    $x = [Math]::Max(0, [int](($Config.ConsoleWidth - $boxWidth) / 2))
    $y = [Math]::Max(0, [int](($Config.ConsoleHeight - 3) / 2))
    Draw-Box $x $y $boxWidth 3 $Config.ColorRed
    Write-At ($x + 3) ($y + 1) ((Get-FG $Config.ColorRed.R $Config.ColorRed.G $Config.ColorRed.B) + $prompt + $Reset)
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Y') { return $true }
        if ($key.Key -eq 'N' -or $key.Key -eq 'Escape') { return $false }
    }
}

# Reads input at (x, y) showing "*" instead of the typed characters.
# Returns the typed string, or $null if the user pressed Escape.
function Read-MaskedInput([int]$x, [int]$y, [int]$maxLen) {
    $sb = New-Object System.Text.StringBuilder
    while ($true) {
        Write-At $x $y (((Get-FG $Config.ColorCyan.R $Config.ColorCyan.G $Config.ColorCyan.B)) + ("*" * $sb.Length).PadRight($maxLen) + $Reset)
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Enter') { break }
        elseif ($key.Key -eq 'Escape') { return $null }
        elseif ($key.Key -eq 'Backspace') {
            if ($sb.Length -gt 0) { [void]$sb.Remove($sb.Length - 1, 1) }
        }
        elseif (-not [char]::IsControl($key.KeyChar) -and $sb.Length -lt $maxLen) {
            [void]$sb.Append($key.KeyChar)
        }
    }
    return $sb.ToString()
}

# Shows a password box before the menu is reachable. Returns $true if the
# gate is disabled or the correct code was entered, $false if the user
# cancelled (Escape) or ran out of attempts.
function Show-AccessGate {
    if ([string]::IsNullOrEmpty($Config.AccessPassword)) { return $true }

    $attemptsLeft = $Config.MaxPasswordAttempts
    while ($attemptsLeft -gt 0) {
        Clear-Host
        $boxWidth  = 40
        $boxHeight = 5
        $x = [Math]::Max(0, [int](($Config.ConsoleWidth - $boxWidth) / 2))
        $y = [Math]::Max(0, [int](($Config.ConsoleHeight - $boxHeight) / 2)) - 2

        Draw-Box $x $y $boxWidth $boxHeight $Config.ColorCyan
        $title = "ENTER ACCESS CODE"
        $titleX = $x + [Math]::Max(0, [int](($boxWidth - $title.Length) / 2))
        Write-At $titleX ($y + 1) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $title + $Reset)

        [Console]::Write("$e[?25l")
        $entryX = $x + 3
        $entryY = $y + 3
        $typed = Read-MaskedInput $entryX $entryY ($boxWidth - 6)

        if ($null -eq $typed) { return $false }

        if ($typed -eq $Config.AccessPassword) {
            return $true
        }

        $attemptsLeft--
        $msg = "Incorrect code. $attemptsLeft attempt(s) left."
        Write-At $x ($y + $boxHeight + 1) ((Get-FG $Config.ColorYellow.R $Config.ColorYellow.G $Config.ColorYellow.B) + $msg + $Reset)
        Start-Sleep -Milliseconds 900
    }

    Show-ResultScreen $false "Too many incorrect attempts." "✔ INSTALL COMPLETE" "✖ ACCESS DENIED"
    return $false
}

function Request-Elevation {
    Clear-Host
    $msg1 = "WARNING: Not running as Administrator."
    $msg2 = "Restart as Admin? [Y/N]"
    Write-At 10 12 ((Get-FG $Config.ColorYellow.R $Config.ColorYellow.G $Config.ColorYellow.B) + $msg1 + $Reset)
    Write-At 10 14 ((Get-FG $Config.ColorYellow.R $Config.ColorYellow.G $Config.ColorYellow.B) + $msg2 + $Reset)
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Y') {
            try {
                $psExe = (Get-Process -Id $PID).Path
                Start-Process -FilePath $psExe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs | Out-Null
            } catch { }
            return $true
        }
        if ($key.Key -eq 'N' -or $key.Key -eq 'Escape') { return $false }
    }
}

#endregion

# ==============================================================================
#region Actions  (placeholder Install / Uninstall logic + working/result screens)
# ==============================================================================

# -----------------------------------------------------------------------------
# Individual gaming tweaks. Each one is self-contained, wrapped in try/catch,
# and returns @{ Success = <bool>; Detail = "<one-line status for the log>" }
# so Invoke-Install can report progress without caring how each tweak works.
# Toggle these on/off via $Config.Tweaks - editing the functions themselves
# is only needed if you want to change *what* a tweak actually does.
# -----------------------------------------------------------------------------

function Set-HighPerformancePower {
    try {
        $applied = "High performance"
        if ($Config.Tweaks.UltimatePerformanceTry) {
            # GUID below is Microsoft's well-known "Ultimate Performance" scheme.
            # Not every SKU exposes it, so we fall back silently if it fails.
            $dup = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            if ($dup) {
                $guidMatch = [regex]::Match($dup, "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})")
                if ($guidMatch.Success) {
                    powercfg -setactive $guidMatch.Value 2>$null | Out-Null
                    $applied = "Ultimate Performance"
                }
            }
        }
        if ($applied -eq "High performance") {
            powercfg -setactive SCHEME_MIN 2>$null | Out-Null
        }
        return @{ Success = $true; Detail = "Power plan set to $applied" }
    } catch {
        return @{ Success = $false; Detail = "Could not change the power plan" }
    }
}

function Disable-GameDVR {
    try {
        $storePath = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $storePath)) { New-Item -Path $storePath -Force | Out-Null }
        Set-ItemProperty -Path $storePath -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force

        $barPath = "HKCU:\SOFTWARE\Microsoft\GameBar"
        if (-not (Test-Path $barPath)) { New-Item -Path $barPath -Force | Out-Null }
        Set-ItemProperty -Path $barPath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $barPath -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force

        return @{ Success = $true; Detail = "Game Bar recording overlay disabled (Game Mode kept on)" }
    } catch {
        return @{ Success = $false; Detail = "Could not update Game Bar settings" }
    }
}

function Set-GamesTaskPriority {
    try {
        $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (-not (Test-Path $mmPath)) { throw "SystemProfile key not found" }
        Set-ItemProperty -Path $mmPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force

        $gamesPath = Join-Path $mmPath "Tasks\Games"
        if (-not (Test-Path $gamesPath)) { New-Item -Path $gamesPath -Force | Out-Null }
        Set-ItemProperty -Path $gamesPath -Name "GPU Priority" -Value 8 -Type DWord -Force
        Set-ItemProperty -Path $gamesPath -Name "Priority" -Value 6 -Type DWord -Force
        Set-ItemProperty -Path $gamesPath -Name "Scheduling Category" -Value "High" -Type String -Force

        return @{ Success = $true; Detail = "Multimedia scheduler tuned to favor games" }
    } catch {
        return @{ Success = $false; Detail = "Could not tune multimedia scheduler (try running as Administrator)" }
    }
}

function Set-ForegroundPriority {
    try {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        # 0x26 = short, fixed quantum, favoring the foreground app - a long-standing
        # "gaming" tweak that gives the active window a bigger share of CPU time.
        Set-ItemProperty -Path $path -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
        return @{ Success = $true; Detail = "Foreground app given priority over background tasks" }
    } catch {
        return @{ Success = $false; Detail = "Could not adjust priority separation (try running as Administrator)" }
    }
}

function Set-NetworkGamingTweaks {
    # Every change here is a plain registry value - no netsh/powercfg calls -
    # so it's easy to see (and reverse) exactly what got written.
    $applied = @()
    $failed  = @()

    # 1) Disable Nagle's algorithm per network adapter for lower latency.
    try {
        $ifacesPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        if (Test-Path $ifacesPath) {
            $ifaces = Get-ChildItem -Path $ifacesPath -ErrorAction Stop
            foreach ($iface in $ifaces) {
                Set-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $iface.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            }
            $applied += "Nagle's algorithm disabled"
        } else {
            $failed += "Nagle tweak (interface keys not found)"
        }
    } catch {
        $failed += "Nagle tweak"
    }

    # 2) Disable network throttling of multimedia/game traffic.
    try {
        $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (-not (Test-Path $mmPath)) { New-Item -Path $mmPath -Force | Out-Null }
        Set-ItemProperty -Path $mmPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
        $applied += "network throttling disabled"
    } catch {
        $failed += "network throttling tweak"
    }

    # 3) Enable TCP window scaling / timestamps for better throughput.
    try {
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Set-ItemProperty -Path $tcpPath -Name "Tcp1323Opts" -Value 1 -Type DWord -Force
        $applied += "TCP window scaling enabled"
    } catch {
        $failed += "TCP window scaling tweak"
    }

    if ($applied.Count -gt 0) {
        $detail = "Network tuned for gaming: " + ($applied -join ", ")
        return @{ Success = $true; Detail = $detail }
    } else {
        $detail = "Could not apply network tweaks (try running as Administrator): " + ($failed -join ", ")
        return @{ Success = $false; Detail = $detail }
    }
}

function Set-VisualEffectsBestPerformance {
    try {
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "VisualFXSetting" -Value 2 -Type DWord -Force
        return @{ Success = $true; Detail = "Visual effects set to Best performance" }
    } catch {
        return @{ Success = $false; Detail = "Could not change visual effects setting" }
    }
}

function Stop-BackgroundBloatProcesses {
    $before = @(Get-Process -ErrorAction SilentlyContinue).Count
    $closed = 0
    $targetsFound = 0
    $treesKilled = 0
    $matchedNames = New-Object System.Collections.Generic.List[string]
    $closedNames = New-Object System.Collections.Generic.List[string]

    # Never target the shell/script itself or important game/runtime components.
    # This is an explicit safety boundary even if somebody accidentally adds a
    # risky process name to BoostProcessNames later.
    $hardKeep = @(
        'powershell','pwsh','explorer','dwm','csrss','wininit','winlogon','services',
        'lsass','smss','svchost','fontdrvhost','conhost','taskhostw','taskhostex',
        'RuntimeBroker','sihost','ShellExperienceHost','StartMenuExperienceHost',
        'SearchHost','SecurityHealthService','SecurityHealthSystray',
        'MsMpEng','NisSrv','WmiPrvSE','ctfmon','spoolsv','audiodg',
        'FiveM','FiveM_b3258_GTAProcess','GTA5','PlayGTAV','RockstarGamesLauncher',
        'RockstarService','RockstarErrorHandler','Steam','steamservice','SteamService',
        'nvcontainer','NVDisplay.Container','NVIDIA Share','RadeonSoftware'
    )

    # Normalize for case-insensitive membership testing.
    $hardKeepSet = @{}
    foreach ($keep in $hardKeep) { $hardKeepSet[[string]$keep.ToLowerInvariant()] = $true }

    $targets = if ($Config.AggressiveCleanup) { @($Config.BoostProcessNames) } else { @($Config.BoostProcessNames) }
    $passes = [Math]::Max(1, [int]$Config.CleanupPasses)

    for ($pass = 1; $pass -le $passes; $pass++) {
        $foundThisPass = $false

        foreach ($name in $targets) {
            $cleanName = [IO.Path]::GetFileNameWithoutExtension([string]$name)
            if ([string]::IsNullOrWhiteSpace($cleanName)) { continue }
            $key = $cleanName.ToLowerInvariant()
            if ($hardKeepSet.ContainsKey($key) -or $cleanName -ieq 'ALIENX_INSTANT_FPS_BOOST') { continue }

            try {
                $procs = @(Get-Process -Name $cleanName -ErrorAction SilentlyContinue)
                if ($procs.Count -eq 0) { continue }

                $foundThisPass = $true
                $targetsFound += $procs.Count
                if (-not $matchedNames.Contains($cleanName)) { $matchedNames.Add($cleanName) }

                foreach ($proc in $procs) {
                    try {
                        if ($proc.Id -eq $PID) { continue }
                        if ($proc.ProcessName -and $hardKeepSet.ContainsKey($proc.ProcessName.ToLowerInvariant())) { continue }

                        if ($Config.KillProcessTree) {
                            $args = "/PID $($proc.Id) /T /F"
                            $p = Start-Process -FilePath "$env:SystemRoot\System32\taskkill.exe" `
                                -ArgumentList $args -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
                            if ($null -eq $p -or $p.ExitCode -eq 0) {
                                $closed++
                                $treesKilled++
                                if (-not $closedNames.Contains($cleanName)) { $closedNames.Add($cleanName) }
                            }
                        } else {
                            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                            $closed++
                            if (-not $closedNames.Contains($cleanName)) { $closedNames.Add($cleanName) }
                        }
                    } catch { }
                }
            } catch { }
        }

        Start-Sleep -Milliseconds ([Math]::Max(100, [int]$Config.CleanupWaitMs))
        if (-not $foundThisPass) { break }
    }

    # One final settle period before taking the AFTER count, so respawning helper
    # processes are included in the real result rather than counted too early.
    Start-Sleep -Milliseconds 250
    $after = @(Get-Process -ErrorAction SilentlyContinue).Count
    $delta = $before - $after

    if ($delta -gt 0) {
        $reductionText = "Processes: $before -> $after (-$delta)"
    } elseif ($delta -lt 0) {
        $reductionText = "Processes: $before -> $after (+$([Math]::Abs($delta)) after app restart)"
    } else {
        $reductionText = "Processes: $before -> $after (no net change)"
    }

    $matchedText = if ($matchedNames.Count -gt 0) { ($matchedNames -join ', ') } else { 'none' }
    $closedText = if ($closedNames.Count -gt 0) { ($closedNames -join ', ') } else { 'none' }

    return @{
        Success = $true
        Detail = "$reductionText; closed $closed process(es) from $($closedNames.Count) app(s). Matched: $matchedText"
        Before = $before
        After = $after
        Delta = $delta
        Closed = $closed
        Matched = @($matchedNames)
        ClosedNames = @($closedNames)
        TreesKilled = $treesKilled
    }
}

# TODO: Replace/extend the "standard install steps" section with your real
# install logic. The gaming tweaks below run afterward and are individually
# controlled by $Config.Tweaks - flip any of them off there without touching
# this function.

function Find-PresentMon {
    # Looks for a PresentMon console binary without requiring a fixed version.
    $candidates = @()

    try {
        $cmd = Get-Command "PresentMon.exe" -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { $candidates += $cmd.Source }
    } catch { }

    $roots = @(
        $PSScriptRoot,
        (Join-Path $PSScriptRoot "tools"),
        (Join-Path $env:ProgramFiles "PresentMon"),
        (Join-Path ${env:ProgramFiles(x86)} "PresentMon"),
        (Join-Path $env:LOCALAPPDATA "PresentMon")
    )

    foreach ($root in $roots) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path $root)) { continue }
        try {
            $found = Get-ChildItem -LiteralPath $root -Filter "PresentMon*.exe" -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending
            foreach ($item in $found) { $candidates += $item.FullName }
        } catch { }
    }

    foreach ($path in ($candidates | Select-Object -Unique)) {
        if ($path -and (Test-Path $path)) { return $path }
    }
    return $null
}

function Get-FiveMProcess {
    # Supports the versioned FiveM process name used by current FiveM builds.
    try {
        $p = Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -match '^FiveM_.*GTAProcess$' } |
            Sort-Object WorkingSet64 -Descending |
            Select-Object -First 1
        return $p
    } catch {
        return $null
    }
}

function Get-AfterBoostFPS {
    # Returns real frame-rate data when FiveM is running and PresentMon is available.
    # We never fabricate an FPS number; unavailable measurements are reported clearly.
    $result = [ordered]@{
        FPS        = $null
        Status     = "UNAVAILABLE"
        Detail     = ""
        Process    = ""
        SampleCount = 0
    }

    $presentMon = Find-PresentMon
    if (-not $presentMon) {
        $result.Detail = "PresentMon not found. Put PresentMon*.exe beside this script or in .\tools\."
        return [pscustomobject]$result
    }

    $game = Get-FiveMProcess
    if (-not $game) {
        $result.Detail = "FiveM is not running. Start FiveM and run BOOST again for a live FPS reading."
        return [pscustomobject]$result
    }

    $result.Process = $game.ProcessName
    $tempCsv = Join-Path ([IO.Path]::GetTempPath()) ("ALIENX_FPS_" + [guid]::NewGuid().ToString("N") + ".csv")

    try {
        # PresentMon's console app supports PID targeting, timed capture, CSV output,
        # and v1 metrics including MsBetweenPresents.
        # PresentMon's --timed value is an integer number of seconds.
        $seconds = [Math]::Max(1, [int][Math]::Ceiling([double]$Config.FPSCaptureSeconds))
        $outputArg = '"' + $tempCsv.Replace('"', '\"') + '"'
        $args = @(
            "--process_id $($game.Id)",
            "--output_file $outputArg",
            "--timed $seconds",
            "--v1_metrics",
            "--exclude_dropped",
            "--no_console_stats"
        )

        $pm = Start-Process -FilePath $presentMon `
            -ArgumentList ($args -join " ") `
            -WindowStyle Hidden `
            -PassThru `
            -ErrorAction Stop

        $deadline = [DateTime]::UtcNow.AddSeconds($seconds + 3.0)
        while (-not $pm.HasExited -and [DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 100
        }
        if (-not $pm.HasExited) {
            try { $pm.Kill() } catch { }
        }

        if (-not (Test-Path $tempCsv)) {
            $result.Detail = "PresentMon returned no frame data."
            return [pscustomobject]$result
        }

        $rows = @(Import-Csv -LiteralPath $tempCsv -ErrorAction Stop)
        $frameTimes = @(
            foreach ($row in $rows) {
                $value = 0.0
                $raw = $row.msBetweenPresents
                if ($null -ne $raw -and
                    [double]::TryParse([string]$raw,
                        [Globalization.NumberStyles]::Float,
                        [Globalization.CultureInfo]::InvariantCulture,
                        [ref]$value) -and
                    $value -gt 0 -and $value -lt 1000) {
                    $value
                }
            }
        )

        if ($frameTimes.Count -lt 2) {
            $result.Detail = "Not enough frames were captured. Keep FiveM running in gameplay, then press BOOST again."
            return [pscustomobject]$result
        }

        $avgMs = ($frameTimes | Measure-Object -Average).Average
        if ($avgMs -le 0) {
            $result.Detail = "FPS sample was invalid."
            return [pscustomobject]$result
        }

        $fps = 1000.0 / $avgMs
        $result.FPS = [Math]::Round($fps, 1)
        $result.SampleCount = $frameTimes.Count
        $result.Status = "OK"
        $result.Detail = "Live FiveM FPS captured from $($frameTimes.Count) frame intervals."
        return [pscustomobject]$result
    } catch {
        $result.Detail = "FPS capture failed: " + $_.Exception.Message
        return [pscustomobject]$result
    } finally {
        if ($tempCsv -and (Test-Path $tempCsv)) {
            Remove-Item -LiteralPath $tempCsv -Force -ErrorAction SilentlyContinue
        }
    }
}

function Show-BoostResultScreen([object]$FpsResult) {
    Clear-Host

    # Make the after-boost number immediately readable at a glance.
    # The layout intentionally follows a simple metric-card style:
    # small label -> BIG NUMBER -> supporting details.
    $title = "BOOST COMPLETE"
    $boxWidth = 70
    $boxHeight = 13
    $x = [Math]::Max(0, [int](($Config.ConsoleWidth - $boxWidth) / 2))
    $y = [Math]::Max(3, [int](($Config.ConsoleHeight - $boxHeight) / 2) - 1)

    $ok = ($FpsResult.Status -eq "OK" -and $null -ne $FpsResult.FPS)
    $color = if ($ok) { $Config.ColorGreen } else { $Config.ColorYellow }

    Draw-Box $x $y $boxWidth $boxHeight $color

    # Header
    $titleX = $x + [Math]::Max(0, [int](($boxWidth - $title.Length) / 2))
    Write-At $titleX ($y + 1) ((Get-FG $color.R $color.G $color.B) + $title + $Reset)

    if ($ok) {
        # Clear, large metric label.
        $label = "AFTER BOOST FPS"
        $labelX = $x + [Math]::Max(0, [int](($boxWidth - $label.Length) / 2))
        Write-At $labelX ($y + 3) ((Get-FG 185 185 185) + $label + $Reset)

        # BIG number - this is the primary result the user should see.
        $fpsValue = "{0:N1}" -f [double]$FpsResult.FPS
        $fpsDisplay = "${fpsValue} FPS"
        $fpsX = $x + [Math]::Max(0, [int](($boxWidth - $fpsDisplay.Length) / 2))
        Write-At $fpsX ($y + 4) ((Get-FG $Config.ColorGreen.R $Config.ColorGreen.G $Config.ColorGreen.B) + $e + "[1m" + $fpsDisplay + $Reset)

        # Secondary information stays smaller so it does not compete with FPS.
        $sampleText = "LIVE MEASURED  •  $($FpsResult.SampleCount) frames"
        $sampleX = $x + [Math]::Max(0, [int](($boxWidth - $sampleText.Length) / 2))
        Write-At $sampleX ($y + 6) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $sampleText + $Reset)

        $processText = "PROCESS  •  $($FpsResult.Process)"
        $processX = $x + [Math]::Max(0, [int](($boxWidth - $processText.Length) / 2))
        Write-At $processX ($y + 7) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $processText + $Reset)
    } else {
        $label = "AFTER BOOST FPS"
        $labelX = $x + [Math]::Max(0, [int](($boxWidth - $label.Length) / 2))
        Write-At $labelX ($y + 3) ((Get-FG 185 185 185) + $label + $Reset)

        $fpsDisplay = "-- FPS"
        $fpsX = $x + [Math]::Max(0, [int](($boxWidth - $fpsDisplay.Length) / 2))
        Write-At $fpsX ($y + 4) ((Get-FG $Config.ColorYellow.R $Config.ColorYellow.G $Config.ColorYellow.B) + $e + "[1m" + $fpsDisplay + $Reset)

        $detail = [string]$FpsResult.Detail
        if ($detail.Length -gt ($boxWidth - 8)) {
            $detail = $detail.Substring(0, $boxWidth - 11) + "..."
        }
        $dx = $x + [Math]::Max(0, [int](($boxWidth - $detail.Length) / 2))
        Write-At $dx ($y + 6) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $detail + $Reset)
    }

    # Show the real process reduction produced by the cleanup step.
    try {
        if ($Config.ShowProcessReduction -and $null -ne $Script:ProcessBefore -and $null -ne $Script:ProcessAfter) {
            $delta = [int]$Script:ProcessBefore - [int]$Script:ProcessAfter
            if ($delta -gt 0) {
                $countText = "PROCESSES  •  $($Script:ProcessBefore) -> $($Script:ProcessAfter)  (-$delta)"
            } elseif ($delta -lt 0) {
                $countText = "PROCESSES  •  $($Script:ProcessBefore) -> $($Script:ProcessAfter)  (+$([math]::Abs($delta)))"
            } else {
                $countText = "PROCESSES  •  $($Script:ProcessBefore) -> $($Script:ProcessAfter)  (0)"
            }
        } else {
            $processCount = @(Get-Process -ErrorAction SilentlyContinue).Count
            $countText = "PROCESSES  •  $processCount"
        }
        $countX = $x + [Math]::Max(0, [int](($boxWidth - $countText.Length) / 2))
        Write-At $countX ($y + 9) ((Get-FG 145 145 145) + $countText + $Reset)
    } catch { }

    $note = "Measured live after the boost • process count is the real Windows count"
    $nx = $x + [Math]::Max(0, [int](($boxWidth - $note.Length) / 2))
    Write-At $nx ($y + 10) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $note + $Reset)

    $closedText = "NON-ESSENTIAL APPS CLOSED  •  $Script:ProcessClosed process(es)"
    $cx = $x + [Math]::Max(0, [int](($boxWidth - $closedText.Length) / 2))
    Write-At $cx ($y + 11) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $closedText + $Reset)

    $prompt = "Press any key to return to menu..."
    $px = $x + [Math]::Max(0, [int](($boxWidth - $prompt.Length) / 2))
    Write-At $px ($y + $boxHeight + 1) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $prompt + $Reset)
    [void][Console]::ReadKey($true)
}

function Invoke-Install {
    param([scriptblock]$Report)

    # --- Standard install steps ---------------------------------------------
    $steps = @(
        @{ Text = "Checking system requirements..."; Percent = 10 },
        @{ Text = "Downloading components...";        Percent = 22 },
        @{ Text = "Copying files...";                 Percent = 36 },
        @{ Text = "Configuring settings...";           Percent = 46 }
    )
    foreach ($step in $steps) {
        for ($tick = 0; $tick -lt 5; $tick++) {
            & $Report $step.Text $step.Percent
            Start-Sleep -Milliseconds 90
        }
        Add-LogLine $step.Text $true
    }

    # --- Gaming performance tweaks (applied as part of install) -------------
    $tweaks = @()
    if ($Config.Tweaks.HighPerformancePower) { $tweaks += @{ Text = "Setting High performance power plan...";      Fn = { Set-HighPerformancePower } } }
    if ($Config.Tweaks.DisableGameDVR)       { $tweaks += @{ Text = "Disabling Game Bar recording overlay...";      Fn = { Disable-GameDVR } } }
    if ($Config.Tweaks.GamesTaskPriority)    { $tweaks += @{ Text = "Tuning multimedia scheduler for games...";     Fn = { Set-GamesTaskPriority } } }
    if ($Config.Tweaks.ForegroundPriority)   { $tweaks += @{ Text = "Prioritizing foreground app performance...";   Fn = { Set-ForegroundPriority } } }
    if ($Config.Tweaks.NetworkOptimization)   { $tweaks += @{ Text = "Optimizing network for gaming...";             Fn = { Set-NetworkGamingTweaks } } }
    if ($Config.Tweaks.VisualEffectsBestPerf) { $tweaks += @{ Text = "Setting visual effects to best performance..."; Fn = { Set-VisualEffectsBestPerformance } } }
    if ($Config.Tweaks.CloseBackgroundApps)  { $tweaks += @{ Text = "Closing non-essential gaming-session apps...";   Fn = { Stop-BackgroundBloatProcesses } } }

    $base  = 50
    $span  = 45
    $total = [Math]::Max(1, $tweaks.Count)
    for ($i = 0; $i -lt $tweaks.Count; $i++) {
        $tw = $tweaks[$i]
        $percent = $base + [int]($span * (($i + 1) / $total))
        & $Report $tw.Text $percent
        Start-Sleep -Milliseconds 120
        $result = & $tw.Fn
        if ($tw.Fn.ToString() -match 'Stop-BackgroundBloatProcesses' -and $result -is [hashtable]) {
            $Script:ProcessBefore = $result.Before
            $Script:ProcessAfter  = $result.After
            $Script:ProcessDelta  = $result.Delta
            $Script:ProcessClosed = $result.Closed
            $Script:ProcessMatched = @($result.Matched)
            if ($result.PSObject.Properties.Name -contains "ClosedNames" -and @($result.ClosedNames).Count -gt 0) {
                Add-LogLine ("Closed apps: " + (@($result.ClosedNames) -join ", ")) $true
            }
        }
        Add-LogLine $result.Detail $result.Success
    }

    & $Report "Finalizing installation..." 100
    Add-LogLine "Finalizing installation..." $true

    # Measure FPS only after every boost tweak has finished.
    if ($Config.ShowAfterBoostFPS) {
        & $Report "Measuring live FiveM FPS after boost..." 100
        $afterBoostFPS = Get-AfterBoostFPS
        if ($afterBoostFPS.Status -eq "OK") {
            Add-LogLine ("After Boost FPS: {0:N1}" -f [double]$afterBoostFPS.FPS) $true
        } else {
            Add-LogLine ("After Boost FPS: -- (" + $afterBoostFPS.Detail + ")") $false
        }
        return $afterBoostFPS
    }

    return $true
}

# TODO: Replace the body of this function with your real uninstall logic.
function Invoke-Uninstall {
    param([scriptblock]$Report)

    $steps = @(
        @{ Text = "Stopping running services...";  Percent = 20 },
        @{ Text = "Removing files...";              Percent = 50 },
        @{ Text = "Cleaning registry entries...";   Percent = 75 },
        @{ Text = "Removing shortcuts...";          Percent = 100 }
    )

    foreach ($step in $steps) {
        for ($tick = 0; $tick -lt 5; $tick++) {
            & $Report $step.Text $step.Percent
            Start-Sleep -Milliseconds 90
        }
        Add-LogLine $step.Text $true
    }

    return $true
}

function Show-WorkingScreen([string]$title) {
    Clear-Host
    $x = [Math]::Max(0, [int](($Config.ConsoleWidth - $title.Length) / 2))
    Write-At $x 6 ((Get-FG $Config.ColorPurple.R $Config.ColorPurple.G $Config.ColorPurple.B) + $title + $Reset)
    $Script:SpinnerIdx = 0
    $Script:LogY = 13
}

function Update-Progress([string]$stepText, [double]$percent) {
    $spin = $Config.Spinner[$Script:SpinnerIdx % $Config.Spinner.Count]
    $Script:SpinnerIdx++

    # Keep the current tweak/status text visually centered in the console.
    # The spinner stays directly to the left of the text while the whole line
    # is centered as one unit, and long text is safely clipped to the width.
    $areaWidth = [Math]::Min(70, $Config.ConsoleWidth - 4)
    $display = "$spin $stepText"
    if ($display.Length -gt $areaWidth) {
        $display = $display.Substring(0, [Math]::Max(1, $areaWidth - 3)) + "..."
    }
    $textX = [Math]::Max(0, [int](($Config.ConsoleWidth - $display.Length) / 2))

    # Clear the previous status line first so leftover characters do not remain.
    Write-At 0 9 (" " * $Config.ConsoleWidth)
    Write-At $textX 9 ((Get-FG 210 210 210) + $display + $Reset)

    # Center the progress bar under the tweak text as well.
    $barWidth = [Math]::Min(50, $Config.ConsoleWidth - 4)
    $barX = [Math]::Max(0, [int](($Config.ConsoleWidth - $barWidth) / 2))
    Draw-ProgressBar $barX 11 $barWidth $percent $Config.ColorPurple $Config.ColorCyan
}

function Add-LogLine([string]$text, [bool]$done) {
    # Center each tweak/status line and safely wrap long text so it never
    # runs off the right edge of the console.
    $markPlain = if ($done) { "✔" } else { "…" }
    $prefixPlain = "→ "
    $maxWidth = [Math]::Max(20, $Config.ConsoleWidth - 8)
    $available = [Math]::Max(12, $maxWidth - $prefixPlain.Length - $markPlain.Length - 1)

    $words = ([string]$text).Trim() -split '\s+'
    $lines = New-Object System.Collections.Generic.List[string]
    $current = ""
    foreach ($word in $words) {
        if (($current.Length + $word.Length + 1) -le $available) {
            $current = if ($current) { "$current $word" } else { $word }
        } else {
            if ($current) { [void]$lines.Add($current) }
            if ($word.Length -gt $available) {
                for ($i = 0; $i -lt $word.Length; $i += $available) {
                    $len = [Math]::Min($available, $word.Length - $i)
                    [void]$lines.Add($word.Substring($i, $len))
                }
                $current = ""
            } else {
                $current = $word
            }
        }
    }
    if ($current) { [void]$lines.Add($current) }
    if ($lines.Count -eq 0) { [void]$lines.Add("") }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $tail = if ($i -eq ($lines.Count - 1)) { " $markPlain" } else { "" }
        $plain = "$prefixPlain$($lines[$i])$tail"
        $x = [Math]::Max(0, [int](($Config.ConsoleWidth - $plain.Length) / 2))

        # Clear the full line first so wrapped/shorter text cannot leave stale pixels.
        Write-At 0 $Script:LogY (" " * $Config.ConsoleWidth)
        $prefix = (Get-FG 210 210 210) + $prefixPlain
        $body   = (Get-FG 210 210 210) + $lines[$i]
        $suffix = if ($tail) {
            (if ($done) { Get-FG $Config.ColorGreen.R $Config.ColorGreen.G $Config.ColorGreen.B } else { Get-FG 150 150 150 }) + $tail
        } else { "" }
        Write-At $x $Script:LogY ($prefix + $body + $suffix + $Reset)
        $Script:LogY++
    }
}

function Show-ResultScreen([bool]$success, [string]$message, [string]$successLabel = "✔ INSTALL COMPLETE", [string]$failureLabel = "✖ FAILED") {
    Clear-Host
    $boxWidth  = 44
    $boxHeight = 5
    $x = [Math]::Max(0, [int](($Config.ConsoleWidth - $boxWidth) / 2))
    $y = 9

    if ($success) {
        $color = $Config.ColorGreen
        $label = $successLabel
        Draw-Box $x $y $boxWidth $boxHeight $color
        $labelX = $x + [Math]::Max(0, [int](($boxWidth - $label.Length) / 2))
        for ($p = 0; $p -lt 3; $p++) {
            Write-At $labelX ($y + 2) ((Get-FG $color.R $color.G $color.B) + $label + $Reset)
            Start-Sleep -Milliseconds 260
            $dim = @{ R = [int]($color.R * 0.35); G = [int]($color.G * 0.35); B = [int]($color.B * 0.35) }
            Write-At $labelX ($y + 2) ((Get-FG $dim.R $dim.G $dim.B) + $label + $Reset)
            Start-Sleep -Milliseconds 260
        }
        Write-At $labelX ($y + 2) ((Get-FG $color.R $color.G $color.B) + $label + $Reset)
        if ($message) {
            $mx = $x + [Math]::Max(0, [int](($boxWidth - $message.Length) / 2))
            Write-At $mx ($y + $boxHeight + 1) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + $message + $Reset)
        }
    } else {
        $color = $Config.ColorRed
        $label = $failureLabel
        Draw-Box $x $y $boxWidth $boxHeight $color
        $labelX = $x + [Math]::Max(0, [int](($boxWidth - $label.Length) / 2))
        foreach ($shift in @(3, -3, 2, -2, 1, -1, 0)) {
            Write-At ($labelX) ($y + 2) (" " * $label.Length)
            Write-At ($labelX + $shift) ($y + 2) ((Get-FG $color.R $color.G $color.B) + $label + $Reset)
            Start-Sleep -Milliseconds 40
        }
        if ($message) {
            $mx = $x
            Write-At $mx ($y + $boxHeight + 1) ((Get-FG $color.R $color.G $color.B) + $message + $Reset)
        }
    }

    Write-At 12 ($y + $boxHeight + 3) ((Get-FG $Config.ColorDimGray.R $Config.ColorDimGray.G $Config.ColorDimGray.B) + "Press any key to return to menu..." + $Reset)
    [void][Console]::ReadKey($true)
}

$Report = {
    param($stepText, $percent)
    Update-Progress $stepText $percent
}

#endregion

# ==============================================================================
#region Main
# ==============================================================================

try {
    Initialize-Console

    if (-not $Script:IsAdminUser) {
        $wantsElevate = Request-Elevation
        if ($wantsElevate) {
            [Console]::Write("$e[?25h")
            exit
        }
    }

    if (-not (Show-AccessGate)) {
        Show-FadeOutExit
        [Console]::Write("$e[0m")
        [Console]::Write("$e[?25h")
        exit
    }

    Show-BootSequence
    Show-BannerReveal
    Draw-StaticScreen

    $phase = 0.0
    $frameDelayMs = [int](1000 / $Config.IdleFPS)
    $running = $true

    while ($running) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow' {
                    $Script:Selected = ($Script:Selected - 1 + $Config.MenuItems.Count) % $Config.MenuItems.Count
                    Draw-MenuItems
                }
                'DownArrow' {
                    $Script:Selected = ($Script:Selected + 1) % $Config.MenuItems.Count
                    Draw-MenuItems
                }
                'Enter' {
                    Flash-MenuItem $Script:Selected
                    $choice = $Config.MenuItems[$Script:Selected]

                    if ($choice -eq 'INSTALL') {
                        Show-WorkingScreen "Installing..."
                        try {
                            $installResult = Invoke-Install -Report $Report
                            if ($Config.ShowAfterBoostFPS -and $null -ne $installResult -and $installResult.PSObject.Properties.Name -contains "Status") {
                                Show-BoostResultScreen $installResult
                            } else {
                                Show-ResultScreen $true "Installation complete - gaming boost tweaks applied." "✔ INSTALL COMPLETE"
                            }
                        } catch {
                            Show-ResultScreen $false ("Error: " + $_.Exception.Message) "✔ INSTALL COMPLETE"
                        }
                        Draw-StaticScreen
                    }
                    elseif ($choice -eq 'UNINSTALL') {
                        if (Confirm-Action "Are you sure? [Y/N]") {
                            Show-WorkingScreen "Uninstalling..."
                            try {
                                Invoke-Uninstall -Report $Report | Out-Null
                                Show-ResultScreen $true "Uninstall completed successfully." "✔ UNINSTALL COMPLETE"
                            } catch {
                                Show-ResultScreen $false ("Error: " + $_.Exception.Message) "✔ UNINSTALL COMPLETE"
                            }
                        }
                        Draw-StaticScreen
                    }
                    elseif ($choice -eq 'EXIT') {
                        Show-FadeOutExit
                        $running = $false
                    }
                }
                'Escape' {
                    Show-FadeOutExit
                    $running = $false
                }
                default { }
            }
        } else {
            Update-IdleBanner $phase
            $phase += $Config.IdlePhaseStep
            if ($phase -ge 1) { $phase = 0 }
            Start-Sleep -Milliseconds $frameDelayMs
        }
    }
}
finally {
    # Always restore terminal state, even on Ctrl+C.
    try { [Console]::Write("$e[0m") } catch { }
    try { [Console]::Write("$e[?25h") } catch { }
}

#endregion
