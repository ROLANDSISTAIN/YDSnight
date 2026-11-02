; =====================================================================
; YDS NIGHT · Programme d'installation Windows (Inno Setup)
; Fabrique automatiquement par GitHub (.github/workflows/livraison.yml).
; =====================================================================
#define Version GetEnv("YDS_VERSION")
#if Version == ""
  #define Version "1.0.0"
#endif

[Setup]
AppId={{9532C20D-1C59-4D57-A7BA-BFCDF76704E8}
AppName=YDS Night
AppVersion={#Version}
AppVerName=YDS Night {#Version}
AppPublisher=YDS Tech
DefaultDirName={localappdata}\Programs\YDS Night
DefaultGroupName=YDS Night
DisableProgramGroupPage=yes
; Installation pour l'utilisateur : pas besoin d'etre administrateur
PrivilegesRequired=lowest
OutputDir=..\livraison
OutputBaseFilename=YDS-Night-Installation
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\harem_club.exe
UninstallDisplayName=YDS Night
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Ferme le logiciel s'il est ouvert pendant une mise a jour
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "bureau"; Description: "Creer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\YDS Night"; Filename: "{app}\harem_club.exe"
Name: "{autodesktop}\YDS Night"; Filename: "{app}\harem_club.exe"; Tasks: bureau

[Run]
Filename: "{app}\harem_club.exe"; Description: "Ouvrir YDS Night maintenant"; Flags: nowait postinstall skipifsilent
