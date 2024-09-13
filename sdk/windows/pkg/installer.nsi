Name XOS_APP_NAME
OutFile "Install XOS_APP_NAME.exe"
InstallDir "$PROGRAMFILES\XOS_APP_NAME"
SetCompressor /SOLID lzma

Function createDesktopShortcut
  CreateShortcut "$DESKTOP\XOS_APP_NAME.lnk" "$INSTDIR\XOS_EXE_NAME"
FunctionEnd

!include "MUI2.nsh"
!define MUI_ICON "install.ico"
!define MUI_UNICON "install.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\XOS_EXE_NAME"
!define MUI_FINISHPAGE_RUN_TEXT "Launch XOS_APP_NAME"
!define MUI_FINISHPAGE_SHOWREADME
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Create Desktop Shortcut"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION createDesktopShortcut
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
 SetOutPath $INSTDIR
 File "XOS_EXE_NAME"
XOS_INSTALL_RESOURCES
 WriteUninstaller "$INSTDIR\Uninstall.exe"
 
 CreateShortcut "$SMPROGRAMS\XOS_APP_NAME.lnk" "$INSTDIR\XOS_EXE_NAME"

 WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XOS_APP_NAME" \
                  "DisplayName" "XOS_APP_NAME"
 WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XOS_APP_NAME" \
                  "Publisher" "XOS_PUBLISHER"
 WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XOS_APP_NAME" \
                  "UninstallString" "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
 Delete "$INSTDIR\XOS_EXE_NAME"
XOS_DELETE_RESOURCES
 Delete "$INSTDIR\Uninstall.exe"
 RMDir "$INSTDIR"
 
 Delete "$SMPROGRAMS\XOS_APP_NAME.lnk"

 DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\XOS_APP_NAME"
SectionEnd
