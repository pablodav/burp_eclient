@echo on
:: Post, pre, script for backups

powershell -ExecutionPolicy Bypass -File "%programfiles%\burp\burp_clientconfig3.ps1" %1 %2
