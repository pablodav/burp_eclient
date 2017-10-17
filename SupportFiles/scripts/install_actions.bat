@echo off

set CENTRALBURPPASS=burp$1999
set TEMPCFGFOLDER=%temp%
set TEMPCFGFORCENTRAL=%TEMPCFGFOLDER%\%computername%
set PROCESSCLIENTSHARE=\\%CENTRALBURPSRV%\process_clients

:: set MDP_Temp=C:\Temp\%PackageName%

::set DIRSRC=%MDR_MediaFolder%
::set DIRDST=%MDP_Temp%

echo initialize LOG > %LOG_FILE%

::Example to call clean.bat
::call %MDR_PackageFolder%\scripts\clean.bat

::Just sending some data to log file
:: cd %temp%
echo log file is %LOG_FILE% >> %LOG_FILE%
echo install dir is %INSTALL_DIR% >> %LOG_FILE%
::echo temp dir is %temp% >> %LOG_FILE%
:: echo temp dir used is %MDP_Temp% >> %LOG_FILE%

::********************Install prerequisite*******************************
::Example to kill executable if it running example:
::WARNING: Programs will be closed:
::Wait 5 minutes




:: Please add on package, error codes 0,255 (if process not exists, continue)
echo Kill burp process >> %LOG_FILE%
taskkill /F /IM "burp.exe"

::********************End Install prerequisite*******************************

:: TYPE options: Update, New, Uninstall
:: PROFILE options: win6x, win5x

:: Start installation:
echo Installing %PackageName% >> %LOG_FILE%

echo STEP1: backup conf if it is an update >> %LOG_FILE%
if exist "%programfiles%\burp\CA\%computername%.csr" (
robocopy "%programfiles%\burp" "%temp%" burp.conf
)

::As done from sap original package, we will copy files on STEP3:
::STEP3:
echo STEP1: install burp >> %LOG_FILE%
:: /poll=20 to repeat 20 minutes the schedule task that checks if it has to do something (burp -a t)

%MDR_MediaFolder%\burp-installer-1.4.40_%processor_architecture%.exe /S /server=%CENTRALBURPSRV% /port=6061 /cname=%computername% /password=8urpCl13nt2015 /autoupgrade=1 /server_can_restore=1 /poll=20 /overwrite >> %LOG_FILE%

echo STEP1: restore config if it is an update >> %LOG_FILE%
if exist "%temp%\burp.conf" (
robocopy "%temp%" "%programfiles%\burp" burp.conf
)


echo STEP2: Modify configuration file >> %LOG_FILE%
sleep 20

powershell -ExecutionPolicy Bypass -File "%MDR_Packagefolder%\scripts\burp_clientconfig3.ps1" initialchange

echo STEP2: copy burp_clientconfig3.ps1 to Program files >> %LOG_FILE%
robocopy "%MDR_Packagefolder%\scripts" "%programfiles%\burp" burp_clientconfig3.ps1 /R:1 /W:1 /COPY:D /LOG+:%LOG_FILE%.robocopy.log
robocopy "%MDR_Packagefolder%\scripts" "%programfiles%\burp" burp_clientconfig3.bat /R:1 /W:1 /COPY:D /LOG+:%LOG_FILE%.robocopy.log


::------------------- Generating configuration for the server-----------------------------------------
:: Added to function in

::Uninstall Druva Insync
echo Checking if Druva is installed >> %LOG_FILE%
if exist "%programfiles%\Druva" (
call %MDR_Packagefolder%\scripts\uninstall_insync.bat
)

if exist "%programfiles(x86)%\Druva" (
call %MDR_Packagefolder%\scripts\uninstall_insync.bat
)

::Uninstall netsafe

echo Uninstall netsafe >> %LOG_FILE%
if exist "%programfiles%\miradore\netsafe" (
MsiExec.exe /quiet /X{894D4752-0F28-4EAF-AFB7-5B4343952337} /log %LOG_FILE%_netsafe.txt
rmdir /S /Q "%programfiles%\miradore\netsafe"
)

if exist "%programfiles(x86)%\miradore\netsafe" (
MsiExec.exe /quiet /X{894D4752-0F28-4EAF-AFB7-5B4343952337} /log %LOG_FILE%_netsafe.txt
rmdir /S /Q "%programfiles(x86)%\miradore\netsafe"
)

::------------------- Generating configuration for the server-----------------------------------------

::clean all installation files
::del /Q /S %temp%
echo Clean temp files >> %LOG_FILE%
rmdir /S /Q %temp%
