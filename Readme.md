Title
======

Burp client script for enterprise deployments

Status
------

This is only a draft used with all settings hardcoded in [burp_clientconfig3.ps1](SupportFiles/scripts/burp_clientconfig3.ps1)

The script is only an idea for now, it should be ported to something like python (prefered because is what I know better than other scripts for multiplatform)

The script is not good enough for me to be shared yet, but I'm sharing it because we started a discussion in https://github.com/grke/burp/issues/618 and it could help explain more about the idea. 


I was thinking in the possibility to open a vote to see if this kind of script/program is something that could be of interest to others in burp community.

The basic features I have now are:

* Per location bandwith traffic (reads location ID from AD and sets bandwith dynamically)
* Also changes the bandwith if the client is not in their location or location of the server
* Change bandwith to out of office hours. [burp_clientconfig3.ps1](SupportFiles/scripts/burp_clientconfig3.ps1#L143)
* Copy last client log with success backup to /path/desired
* Checks the logs and looks for known errors with SSL, like: 
```
*SSL alert number 51*
*SSL3_READ_BYTES:tlsv1 alert decrypt error:s3_pkt.c*
*Error with certificate signing request*
*check cert failed*
*e:Will not accept a client certificate request for* -and $_ -like "*already exists*"
```
* Also checks logs for `*unable to authorise on server*`
* Also checks for errors logs on server `*Error when reading counters from server*`
* If some of the errors are found it will also send request for fix (actually with copy of file, but will be required something more advanced like RESTFUL service or something else for these cases)
* Checks the last time a backup was performed (reading date of log file copied on the client) and displays window notification to user warning about the state of outdated backup (when enabled)
* Also have defaults settings like: burp server to use and request to add the client to the server when initial setup is done.
* Also creates shadow copy snapshot after success backup, so client can right click and restore previous version directly on disk.

The script changes dynamically burp.conf client file and executes `burp -a t`, also `burp.conf` calls this script in options `script_pre` and `script_post`.

The way it copies the files to server using cifs samba share is very ugly, should be used only on very controlled environments or shouldn't be used at all (better). We should create RESTFUL API to control this with something like http://www.hug.rest/.

Usage
=====

Modify the scripts:

[burp_clientconfig3.ps1](SupportFiles/scripts/burp_clientconfig3.ps1)

And

[Deploy-Application.ps1](Deploy-Application.ps1)

Install with:

    Deploy-Application.exe

More details in: http://psappdeploytoolkit.com/

How it works? 
=============

The installation will modify the `burp cron` task, with this line: [burp_clientconfig3.ps1](SupportFiles/scripts/burp_clientconfig3.ps1#L369)

    "%systemroot%\system32\WindowsPowershell\v1.0\powershell.exe -ExecutionPolicy Bypass -File '%programfiles%\burp\burp_clientconfig3.ps1' backup"

And also will modify burp.conf with the pre and post actions using same script.
