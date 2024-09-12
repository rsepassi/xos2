Name "xos"
OutFile "Install xos.exe"
InstallDir "$PROGRAMFILES\xos"
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!define MUI_ICON "install.ico"
!define MUI_UNICON "install.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\xos.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch xos"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
 SetOutPath $INSTDIR
 File "xos.exe"
 File "CourierPrime-Regular.ttf"
 
 CreateShortcut "$SMPROGRAMS\xos.lnk" "$INSTDIR\xos.exe"

 WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
 Delete "$INSTDIR\xos.exe"
 Delete "$INSTDIR\CourierPrime-Regular.ttf"
 Delete "$INSTDIR\Uninstall.exe"
 
 RMDir "$INSTDIR"
 
 Delete "$SMPROGRAMS\xos.lnk"
SectionEnd
