; Inno Setup script for the Redtick Flutter Windows app.
; Produces an unsigned setup.exe that installs the self-contained release bundle
; (redtick.exe + data\ + the Flutter/VC++ runtime DLLs) with Start-menu and
; optional desktop shortcuts. Build it with:
;   iscc /DMyAppVersion=1.0.0 /DOutputName=redtick-v1.0.0-setup packaging\windows\redtick.iss
; Run from the `app/` directory so the relative Source/Icon paths resolve.

#define MyAppName "Redtick"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "cz.syky.redtick"
#define MyAppExeName "redtick.exe"

; Override these from the command line (/D...) when packaging in CI.
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef OutputName
  #define OutputName "redtick-setup"
#endif

[Setup]
; Stable AppId so upgrades replace in place (do not change once shipped).
AppId={{8B2E5A14-9C3D-4F7A-B1E6-2D9A7C4F0E33}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
