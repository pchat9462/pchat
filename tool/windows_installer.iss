; PCHAT — Windows installer (Inno Setup 6)
;
; It installs the whole Flutter "Release" folder: the .exe needs data\ and the
; .dll files next to it, so shipping the .exe alone would not run.
;
; What it leaves behind:
;   * a Desktop shortcut,
;   * a Start menu entry ("All programs" → PCHAT),
;   * an entry in Settings → Apps (and in the old "Programs and Features"),
;   * an uninstaller, which removes all of the above.
; Every one of them carries PCHAT's own icon.
;
; Build it on Windows:
;     "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" tool\windows_installer.iss
;
; The CI does the same on the windows-latest runner; see
; .github/workflows/release.yml. It passes the paths in absolute form, because
; a relative path is not resolved the same way by every caller.

#ifndef ReleaseDir
  ; Where "flutter build windows --release" put the files.
  #define ReleaseDir "..\build\windows\x64\runner\Release"
#endif

#ifndef SetupIconFile
  #define SetupIconFile "..\windows\runner\resources\app_icon.ico"
#endif

#ifndef OutputDir
  #define OutputDir "..\dist\windows"
#endif

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "PCHAT"
#define AppExeName "pchat_app.exe"
#define AppPublisher "io.github.shepu1"

[Setup]
; A fixed AppId is what makes a new version *replace* the old one instead of
; installing a second copy next to it.
AppId={{AA1B44A1-E299-4A99-B5D8-9396F75CB076}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/pchat9462/pchat
AppSupportURL=https://github.com/pchat9462/pchat/issues
AppUpdatesURL=https://github.com/pchat9462/pchat/releases

; C:\Program Files\PCHAT — the normal place for an installed program.
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; No "choose a folder" page: the app is a single-purpose wrapper, there is
; nothing to configure.
DisableDirPage=yes

; The installer's own icon: PCHAT's, straight from the Windows runner.
SetupIconFile={#SetupIconFile}
; What the entry in "Apps" shows.
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

OutputBaseFilename=pchat_app-{#AppVersion}-windows-x64-installer
OutputDir={#OutputDir}
; lzma2 at the "normal" level: the smallest setting ("max") is several times
; slower to compress the 30 MB of WebView2 and Flutter binaries, and the
; installer is a couple of megabytes bigger for it.
Compression=lzma2/normal
SolidCompression=yes
WizardStyle=modern
; The app is 64-bit only (the WebView2 plugin and the runner are x64).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
; Let the installer close a running PCHAT instead of failing.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.CreateDesktopIcon=Create a &desktop shortcut
english.LaunchProgram=Start {#AppName}

[Tasks]
; A task is checked by default — there is no "checked" flag; "unchecked" is
; what would turn that off. The user can still untick the box.
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; The whole Release folder: the .exe, the plugin .dll files and data\.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; "All programs" → PCHAT. The icon is the one built into the .exe.
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
; The desktop shortcut. The icon is the one built into the .exe, so it always
; matches what the running window shows.
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
