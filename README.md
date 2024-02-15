# Installomatic

Installomatic is a script designed to simplify Intune app installation. All you need to do is fill in some of the variables at the top of the script and deploy it as a Win32 app. 

The commands to manage the Win32 app via Intune are:

Install command:  
powershell -ExecutionPolicy Bypass -File .\installomatic.ps1 install  
Uninstall command:  
powershell -ExecutionPolicy Bypass -File .\installomatic.ps1 remove  

If the script is run with no arguments it works as a detection script (exiting 0 if the app IS detected and 1 if NOT detcted).

The script can install apps via 3 different methods:

1. Winget (Windows package manager)
2. By obtaining an installer from a provided download URL and running tit
3. By running an installer that has been packaged with the script

For best results we recommend using all three for the ulimate in robustness. Installomatic will attempt to install the app going through each method in the above order.