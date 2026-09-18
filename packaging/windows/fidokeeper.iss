; FidoKeeper Windows installer (Inno Setup 6).
;
; 本地从仓库根目录编译：
;   iscc /DSourceDir="%CD%\build\windows\x64\runner\Release" ^
;        /DOutputDir="%CD%\build\windows\packages" ^
;        /DAppVersion="1.0.0" /DBuildNumber="1" ^
;        packaging\windows\fidokeeper.iss

#ifndef AppName
  #define AppName "FidoKeeper"
#endif
#ifndef AppPublisher
  #define AppPublisher "Yo1sing"
#endif
#ifndef AppURL
  #define AppURL "https://github.com/Yo1sing/FidoKeeper"
#endif
#ifndef AppExeName
  #define AppExeName "fidokeeper.exe"
#endif
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef BuildNumber
  #define BuildNumber "0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\windows\packages"
#endif
#ifndef IconFile
  #define IconFile "..\..\windows\runner\resources\app_icon.ico"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "fidokeeper-" + AppVersion + "." + BuildNumber + "-windows-amd64-setup"
#endif

[Setup]
AppId=dev.yo1sing.fidokeeper
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
WizardStyle=modern
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#AppExeName}
VersionInfoVersion={#AppVersion}.{#BuildNumber}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
