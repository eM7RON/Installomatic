##################################################################################################################################
##################################################################################################################################                                                                                                                       
#
# Intune Win32App Manager
# 2024 Simon Tucker
#                                                                                                                                
##################################################################################################################################
##################################################################################################################################

################################################
# NOTE: The following variables should be set  #
################################################

$displayName = "Notepad++"
# Taken from the registry entry HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*
# this is used to find the app's uninstall string 

$wingetAppID = "Notepad++.Notepad++"
# This is used to identify the app in the Winget database.

$installContext = "machine" # machine | user

$installerType = "exe"
# exe | msi | msixbundle
# The file extension of the fallback installer used if Winget fails.

$installerArgList = '/q /norestart'
$uninstallerArgList = '/quiet'
# Arguments to pass to the fallback installers or uninstaller. The are normally one of the following:
# /qn | /S | --silent etc... The uninstaller will likely come from the uninstall string.

$fallbackDownloadURL = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
# A URL to fetch the latest version of the app.

$githubRegex = ""
# If above is for a Github latest release page this regex pattern will match be used to 
# match the installer asset to be downloaded.

$installRegistryItems = @(
    # @{
    #     Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SAIIT';
    #     Keys = @(
    #         @{ Name = 'Installed'; Value = 1; Type = 'STRING'},
    #         @{ Name = 'Bld'; Value = 0x0000816a; Type = 'DWORD'}
    #         # Add more key-value pairs as needed for X64
    #     )
    # }
    # @{
    #     Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X86';
    #     Keys = @(
    #         @{ Key = 'Installed'; Value = 1 },
    #         @{ Key = 'Bld'; Value = 0x0000816a }
    #         # Add more key-value pairs as needed for X86
    #     )
    # }
    # Add more path entries as needed
)


############ Testing variables ############## 

$testExecutablePath = ''
# Path to the executable for testing if app is installed.

$testRegistryItems = @(
    @{
        Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64';
        Keys = @(
            @{ Name = 'Installed'; Value = 1},
            @{ Name = 'Bld'; Value = 0x0000816a}
            # Add more key-value pairs as needed for X64
        )
    }
    # @{
    #     Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X86';
    #     Keys = @(
    #         @{ Name = 'Installed'; Value = 1 },
    #         @{ Name = 'Bld'; Value = 0x0000816a }
    #         # Add more key-value pairs as needed for X86
    #     )
    # }
    # Add more path entries as needed
)

$preInstallRegistryHives = @("HKCU:")
$uninstallRegistryHives = @("HKLM:", "HKCU:")