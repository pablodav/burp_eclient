@echo off
:: UnInstallers by architecture
:: Pablo Estigarribia
:: 30/04/2015
::

::"Setting variables"{
set PackageName=Griffin_Burp_Backup_and_restore_Client_1.4.40
set RunOnceDir=%allusersprofile%\griffin\RunOnce
set ODBCCFGDIR=%MDR_PackageFolder%\odbc_cfg
set INSTALL_DIR=%programfiles%\burp
set LOG_FILE=%MDI_LogFolder%\%PackageName%_uninstall_.log


::Setting for copy with robocopy
::Syntax: robocopy DIRSRC DIRDST %ROBOCOPY_OPTIONS%
set ROBOCOPY_OPTIONS=/E /NP /W:0 /R:1 /LOG+:%LOG_FILE%


::Set central server for administration (just for automation tasks, like adding and removing clients with the package)

:: set MDP_Temp=C:\Temp\%PackageName%

::set DIRSRC=%MDR_MediaFolder%
::set DIRDST=%MDP_Temp%

::"End of Setting Variables}
::Use it from miradore
::Step, execute cmd
::%MDR_PackageFolder%\scripts\clean.bat
::Use return code 0,1,255

echo initialize LOG > %LOG_FILE%

:: Please add on package, error codes 0,255 (if process not exists, continue)
::Kill executable if it running example:
echo STEP1: kill burp.exe >> %LOG_FILE%
taskkill /F /IM "burp.exe"

:: TYPE=Archive for deletion of file

:: Uninstall burp
echo STEP2: uninstall burp client >> %LOG_FILE%
%INSTALL_DIR%\uninstall.exe /S


::------------------- Generating configuration for the server-----------------------------------------
powershell -ExecutionPolicy Bypass -File "%MDR_Packagefolder%\scripts\burp_clientconfig3.ps1" uninstall


rmdir /S /Q "%INSTALL_DIR%"

::clean all installation files
del /Q /S %temp%
