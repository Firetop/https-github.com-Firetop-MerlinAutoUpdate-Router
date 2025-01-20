#!/bin/sh
###################################################################
# MerlinAU.sh (MerlinAutoUpdate)
#
# Original Creation Date: 2023-Oct-01 by @ExtremeFiretop.
# Official Co-Author: @Martinski W. - Date: 2023-Nov-01
# Last Modified: 2025-Jan-18
###################################################################
set -u

## Set version for each Production Release ##
readonly SCRIPT_VERSION=1.4.0
readonly SCRIPT_NAME="MerlinAU"
## Set to "master" for Production Releases ##
SCRIPT_BRANCH="dev"

##FOR TESTING/DEBUG ONLY##
if true ; then SCRIPT_BRANCH="WebFun" ; fi
##FOR TESTING/DEBUG ONLY##

##----------------------------------------##
## Modified by Martinski W. [2024-Jul-03] ##
##----------------------------------------##
# Script URL Info #
readonly SCRIPT_URL_BASE="https://raw.githubusercontent.com/ExtremeFiretop/MerlinAutoUpdate-Router"
SCRIPT_URL_REPO="${SCRIPT_URL_BASE}/$SCRIPT_BRANCH"

# Firmware URL Info #
readonly FW_SFURL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
readonly FW_SFURL_RELEASE_SUFFIX="Release"
readonly FW_GITURL_RELEASE="https://api.github.com/repos/gnuton/asuswrt-merlin.ng/releases/latest"

##----------------------------------------##
## Modified by Martinski W. [2024-May-31] ##
##----------------------------------------##
# Changelog Info #
readonly CL_URL_NG="${FW_SFURL_BASE}/Documentation/Changelog-NG.txt/download"
readonly CL_URL_386="${FW_SFURL_BASE}/Documentation/Changelog-386.txt/download"
readonly CL_URL_3006="${FW_SFURL_BASE}/Documentation/Changelog-3006.txt/download"

readonly high_risk_terms="factory default reset|features are disabled|break backward compatibility|must be manually|strongly recommended"

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-31] ##
##----------------------------------------##
# For new script version updates from source repository #
DLRepoVersion=""
DLRepoVersionNum=""
ScriptVersionNum=""
scriptUpdateNotify=0

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Oct-02] ##
##------------------------------------------##
# For minimum supported firmware version check #
MinFirmwareVerCheckFailed=false
MinSupportedFirmwareVers="3004.386.12.6"

# For router model check #
routerModelCheckFailed=false
offlineUpdateTrigger=false

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
readonly NOct="\e[0m"
readonly BOLDct="\e[1m"
readonly BLKct="\e[1;30m"
readonly REDct="\e[1;31m"
readonly GRNct="\e[1;32m"
readonly YLWct="\e[1;33m"
readonly BLUEct="\e[1;34m"
readonly MAGENTAct="\e[1;35m"
readonly CYANct="\e[1;36m"
readonly WHITEct="\e[1;37m"
readonly CRITct="\e[1;41m"
readonly InvREDct="\e[1;41m"
readonly InvGRNct="\e[1;42m"

readonly ScriptFileName="${0##*/}"
readonly ScriptFNameTag="${ScriptFileName%%.*}"
readonly ScriptDirNameD="${ScriptFNameTag}.d"

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
readonly ADDONS_PATH="/jffs/addons"
readonly SCRIPTS_PATH="/jffs/scripts"
readonly SETTINGS_DIR="${ADDONS_PATH}/$ScriptDirNameD"
readonly CONFIG_FILE="${SETTINGS_DIR}/custom_settings.txt"
readonly SCRIPT_VERPATH="${SETTINGS_DIR}/version.txt"
readonly HELPER_JSFILE="${SETTINGS_DIR}/CheckHelper.js"
readonly SHARED_SETTINGS_FILE="${ADDONS_PATH}/custom_settings.txt"
readonly SHARED_WEB_DIR="$(readlink /www/user)"
readonly SCRIPT_WEB_DIR="${SHARED_WEB_DIR}/$SCRIPT_NAME"
readonly SCRIPT_WEB_ASP_FILE="${SCRIPT_NAME}.asp"
readonly SCRIPT_WEB_ASP_PATH="$SETTINGS_DIR/$SCRIPT_WEB_ASP_FILE"
readonly TEMP_MENU_TREE="/tmp/menuTree.js"
readonly ORIG_MENU_TREE="/www/require/modules/menuTree.js"
readonly WEBUI_LOCKFD=386
readonly WEBUI_LOCKFILE="/tmp/addonwebui.lock"
readonly TEMPFILE="/tmp/MerlinAU_settings_$$.txt"
readonly webPageFileRegExp="user([1-9]|[1-2][0-9])[.]asp"
readonly webPageLineRegExp="\{url: \"$webPageFileRegExp\", tabName: \"$SCRIPT_NAME\"\}"

# Give FIRST priority to built-in binaries over any other #
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

##-------------------------------------##
## Added by Martinski W. [2024-Sep-15] ##
##-------------------------------------##
# For handling 3rd-party add-on cron jobs #
readonly USB_OPT_DIRPATH1="/opt"
readonly USB_OPT_DIRPATH2="/tmp/opt"
readonly USB_MNT_DIRPATH1="/mnt"
readonly USB_MNT_DIRPATH2="/tmp/mnt"

readonly cronJobsRegEx1="[[:blank:]]+${ADDONS_PATH}/.* "
readonly cronJobsRegEx2="[[:blank:]]+${SCRIPTS_PATH}/.* "
readonly cronJobsRegEx3="[[:blank:]]+${USB_OPT_DIRPATH1}/.* "
readonly cronJobsRegEx4="[[:blank:]]+${USB_OPT_DIRPATH2}/.* "
readonly cronJobsRegEx5="[[:blank:]]+${USB_MNT_DIRPATH1}/.* "
readonly cronJobsRegEx6="[[:blank:]]+${USB_MNT_DIRPATH2}/.* "
readonly addonCronJobList="/home/root/addonCronJobList_$$.txt"

##----------------------------------------##
## Modified by Martinski W. [2024-Jun-05] ##
##----------------------------------------##
ScriptsDirPath="$SCRIPTS_PATH"
ScriptFilePath="${SCRIPTS_PATH}/${SCRIPT_NAME}.sh"

if [ ! -f "$ScriptFilePath" ]
then
    ScriptsDirPath="$(pwd)"
    ScriptFilePath="$(pwd)/$ScriptFileName"
fi

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-21] ##
##------------------------------------------##
#-------------------------------------------------------#
# We'll use the built-in AMTM email configuration file
# to send email notifications *IF* enabled by the user.
#-------------------------------------------------------#
readonly FW_UpdateEMailFormatTypeDefault=HTML
readonly FW_UpdateEMailNotificationDefault=DISABLED
readonly amtmMailDirPath="/jffs/addons/amtm/mail"
readonly amtmMailConfFile="${amtmMailDirPath}/email.conf"
readonly amtmMailPswdFile="${amtmMailDirPath}/emailpw.enc"
readonly tempEMailContent="/tmp/var/tmp/tempEMailContent.$$.TXT"
readonly tempNodeEMailList="/tmp/var/tmp/tempNodeEMailList.$$.TXT"
readonly tempEMailBodyMsg="/tmp/var/tmp/tempEMailBodyMsg.$$.TXT"
readonly saveEMailInfoMsg="${SETTINGS_DIR}/savedEMailInfoMsg.SAVE.TXT"
readonly theEMailDateTimeFormat="%Y-%b-%d %a %I:%M:%S %p %Z"

if [ -z "$(which crontab)" ]
then cronListCmd="cru l"
else cronListCmd="crontab -l"
fi

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-27] ##
##----------------------------------------##
inMenuMode=true
isInteractive=false
FlashStarted=false
MerlinChangeLogURL=""
GnutonChangeLogURL=""

# Main LAN Network Info #
readonly myLAN_HostName="$(nvram get lan_hostname)"
readonly mainLAN_IFname="$(nvram get lan_ifname)"
readonly mainLAN_IPaddr="$(nvram get lan_ipaddr)"
readonly mainNET_IPaddr="$(ip route show | grep -E "[[:blank:]]+dev[[:blank:]]+${mainLAN_IFname}[[:blank:]]+proto[[:blank:]]+" | awk -F ' ' '{print $1}')"

# RegExp for IPv4 address #
readonly IPv4octet_RegEx="([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])"
readonly IPv4addrs_RegEx="(${IPv4octet_RegEx}\.){3}${IPv4octet_RegEx}"
readonly IPv4privt_RegEx="(^10\.|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.|^192\.168\.)"

##----------------------------------------##
## Modified by Martinski W. [2024-Oct-03] ##
##----------------------------------------##
readonly fwInstalledBaseVers="$(nvram get firmver | sed 's/\.//g')"
readonly fwInstalledBuildVers="$(nvram get buildno)"
readonly fwInstalledExtendNum="$(nvram get extendno)"
readonly fwInstalledInnerVers="$(nvram get innerver)"
readonly fwInstalledBranchVer="${fwInstalledBaseVers}.$(echo "$fwInstalledBuildVers" | awk -F'.' '{print $1}')"

##-------------------------------------##
## Added by Martinski W. [2024-Oct-03] ##
##-------------------------------------##
readonly MinSupportedFW_3004_386_Ver="3004.386.12.6"
readonly MinSupportedFW_3004_388_Ver="3004.388.6.2"
readonly MinSupportedFW_3006_102_Ver="3004.388.8.0"

case "$fwInstalledBranchVer" in
   "3004.386") MinSupportedFirmwareVers="$MinSupportedFW_3004_386_Ver" ;;
   "3004.388") MinSupportedFirmwareVers="$MinSupportedFW_3004_388_Ver" ;;
   "3006.102") MinSupportedFirmwareVers="$MinSupportedFW_3006_102_Ver" ;;
esac

if [ "$(nvram get sw_mode)" -eq 1 ]
then inRouterSWmode=true
else inRouterSWmode=false
fi

readonly mainMenuReturnPromptStr="Press <Enter> to return to the Main Menu..."
readonly advnMenuReturnPromptStr="Press <Enter> to return to the Advanced Options Menu..."
readonly logsMenuReturnPromptStr="Press <Enter> to return to the Log Options Menu..."
theMenuReturnPromptMsg="$mainMenuReturnPromptStr"
readonly SEPstr="----------------------------------------------------------"

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
# menu setup variables #
readonly padStr="      "
readonly theExitStr="${GRNct}e${NOct}=Exit to Main Menu"
readonly theMUExitStr="${GRNct}e${NOct}=Exit"
readonly theADExitStr="${GRNct}e${NOct}=Exit to Advanced Options Menu"
readonly theLGExitStr="${GRNct}e${NOct}=Exit to Log Options Menu"
readonly menuCancelAndExitStr="${GRNct}e${NOct}=Exit Menu"
readonly menuSavedThenExitStr="${GRNct}s${NOct}=Save&Exit"
readonly menuReturnToBeginStr="${GRNct}b${NOct}=Back to Top"

##-------------------------------------##
## Added by Martinski W. [2024-Aug-15] ##
##-------------------------------------##
routerLoginFailureMsg="Please try the following:
1. Confirm that you are *not* already logged into the router webGUI using a web browser.
2. Check that the \"Enable Access Restrictions\" option from the webGUI is *not* set up
   to restrict access to the router webGUI from the router's IP address [${GRNct}${mainLAN_IPaddr}${NOct}].
3. Confirm your password via the \"Set Router Login Credentials\" option from the Main Menu."

[ -t 0 ] && ! tty | grep -qwi "NOT" && isInteractive=true

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-23] ##
##----------------------------------------##
userLOGFile=""
userTraceFile="${SETTINGS_DIR}/${ScriptFNameTag}_Trace.LOG"
userDebugFile="${SETTINGS_DIR}/${ScriptFNameTag}_Debug.LOG"
LOGdateFormat="%Y-%m-%d %H:%M:%S"
_LogMsgNoTime_() { _UserLogMsg_ "_NOTIME_" "$@" ; }

_UserTraceLog_()
{
   local logTime="$(date +"$LOGdateFormat")"
   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       echo >> "$userTraceFile"
   elif [ $# -eq 1 ]
   then
       echo "$logTime" "$1" >> "$userTraceFile"
   elif [ "$1" = "_NOTIME_" ]
   then
       echo "$2" >> "$userTraceFile"
   else
       echo "$logTime" "${1}: $2" >> "$userTraceFile"
   fi
}

_UserLogMsg_()
{
   if [ -z "$userLOGFile" ] || [ ! -f "$userLOGFile" ]
   then return 1 ; fi

   local logTime="$(date +"$LOGdateFormat")"
   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       echo >> "$userLOGFile"
   elif [ $# -eq 1 ]
   then
       echo "$logTime" "$1" >> "$userLOGFile"
   elif [ "$1" = "_NOTIME_" ]
   then
       echo "$2" >> "$userLOGFile"
   else
       echo "$logTime" "${1}: $2" >> "$userLOGFile"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
Say()
{
   "$isInteractive" && printf "${1}\n"
   # Remove all "color escape sequences" from the system log file entries #
   local logMsg="$(echo "$1" | sed 's/\\\e\[[0-1]m//g ; s/\\\e\[[0-1];[3-4][0-9]m//g')"
   _UserLogMsg_ "$logMsg"
   printf "$logMsg" | logger -t "[$(basename "$0")] $$"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------------##
_WaitForEnterKey_()
{
   ! "$isInteractive" && return 0
   local promptStr

   if [ $# -gt 0 ] && [ -n "$1" ]
   then promptStr="$1"
   else promptStr="Press <Enter> to continue..."
   fi

   printf "\n$promptStr"
   read -rs EnterKEY ; echo
}

##----------------------------------##
## Added Martinski W. [2023-Nov-28] ##
##----------------------------------##
_WaitForYESorNO_()
{
   ! "$isInteractive" && return 0
   local promptStr

   if [ $# -eq 0 ] || [ -z "$1" ]
   then promptStr=" [yY|nN]?  "
   else promptStr="$1 [yY|nN]?  "
   fi

   printf "$promptStr" ; read -r YESorNO
   if echo "$YESorNO" | grep -qE "^([Yy](es)?|YES)$"
   then echo "OK" ; return 0
   else echo "NO" ; return 1
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-11] ##
##----------------------------------------##
readonly LockFilePath="/tmp/var/${ScriptFNameTag}.LOCK"
readonly LockTypeRegEx="(cliMenuLock|cliOptsLock|cliFileLock)"

_FindLockFileTypes_()
{ grep -woE "$LockTypeRegEx" "$LockFilePath" | tr '\n' ' ' | sed 's/[ ]*$//' ; }

_ReleaseLock_() 
{
   local lockType
   if [ $# -eq 0 ] || [ -z "$1" ]
   then lockType=""
   else lockType="$1"
   fi
   if [ -s "$LockFilePath" ] && \
      [ "$(cat "$LockFilePath" | wc -l)" -gt 1 ]
   then
       if [ -z "$lockType" ]
       then sed -i "/^$$|/d" "$LockFilePath"
       else sed -i "/.*|${1}$/d" "$LockFilePath"
       fi
       [ -s "$LockFilePath" ] && return 0
   fi
   rm -f "$LockFilePath"
}

## Defaults ##
LockMaxTimeoutSecs=120
LockFileMaxAgeSecs=600  #10-minutes#

if [ $# -eq 0 ] || [ -z "$1" ]
then
   #Interactive Mode#
   LockMaxTimeoutSecs=3
   LockFileMaxAgeSecs=1200
else
   case "$1" in
       run_now|resetLockFile)
           LockMaxTimeoutSecs=3
           LockFileMaxAgeSecs=1200
           ;;
       startup|addCronJob)
           LockMaxTimeoutSecs=600
           LockFileMaxAgeSecs=900
           ;;
   esac
fi

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
_AcquireLock_()
{
   local retCode  waitTimeoutSecs
   local lockFileSecs  ageOfLockSecs  oldPID
   local lockTypeReq  lockTypeFound

   if [ $# -gt 0 ] && [ -n "$1" ]
   then lockTypeReq="$1"
   else lockTypeReq="cliAnyLock"
   fi

   _CreateLockFile_()
   { echo "$$|$lockTypeReq" > "$LockFilePath" ; }

   if [ ! -f "$LockFilePath" ]
   then _CreateLockFile_ ; return 0
   fi

   retCode=1
   lockTypeFound=""
   waitTimeoutSecs=0

   while true
   do
      if [ -s "$LockFilePath" ]
      then
          oldPID="$(head -n1 "$LockFilePath" |  awk -F '|' '{print $1}')"
          if [ -n "$oldPID" ] && ! pidof "$ScriptFileName" | grep -qow "$oldPID"
          then sed -i "/^${oldPID}|/d" "$LockFilePath"
          fi
          lockFileSecs="$(date +%s -r "$LockFilePath")"
          lockTypeFound="$(_FindLockFileTypes_)"
          if [ "$lockTypeReq" != "cliAnyLock" ] && \
             ! echo "$lockTypeFound" | grep -qw "$lockTypeReq"
          then # Specific "Lock Type" NOT found #
              echo "$$|$lockTypeReq" >> "$LockFilePath"
              retCode=0 ; break
          fi
          [ -z "$lockTypeFound" ] && lockTypeFound="noTypeLock"
      else
          _CreateLockFile_
          retCode=0 ; break
      fi

      ageOfLockSecs="$(($(date +%s) - lockFileSecs))"
      if [ "$ageOfLockSecs" -gt "$LockFileMaxAgeSecs" ]
      then
          Say "Stale Lock Found (older than $LockFileMaxAgeSecs secs). Resetting lock file..."
          if [ -n "$oldPID" ] && \
             pidof "$ScriptFileName" | grep -qow "$oldPID" && \
             kill -EXIT "$oldPID" 2>/dev/null
          then
              kill -TERM "$oldPID" ; wait "$oldPID"
          fi
          _CreateLockFile_
          retCode=0 ; break
      elif [ "$waitTimeoutSecs" -le "$LockMaxTimeoutSecs" ]
      then
          if [ "$((waitTimeoutSecs % 10))" -eq 0 ]
          then
              Say "Lock Found [$lockTypeFound: $ageOfLockSecs secs]. Waiting for script [PID=$oldPID] to exit [Timer: $waitTimeoutSecs secs]"
          fi
          sleep 5
          waitTimeoutSecs="$((waitTimeoutSecs + 5))"
      else
          Say "${REDct}**ERROR**${NOct}: The shell script ${ScriptFileName} [PID=$oldPID] is already running [$lockTypeFound: $ageOfLockSecs secs]"
          retCode=1 ; break
      fi
   done
   return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Dec-26] ##
##-------------------------------------##
_DoExit_()
{
   local exitCode=0
   [ $# -gt 0 ] && [ -n "$1" ] && exitCode="$1"
   _ReleaseLock_ ; exit "$exitCode"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-May-21] ##
##------------------------------------------##
_ShowLogo_()
{
  echo -e "${YLWct}"
  echo -e "      __  __           _ _               _    _ "
  echo -e "     |  \/  |         | (_)         /\  | |  | |"
  echo -e "     | \  / | ___ _ __| |_ _ __    /  \ | |  | |"
  echo -e "     | |\/| |/ _ | '__| | | '_ \  / /\ \| |  | |"
  echo -e "     | |  | |  __| |  | | | | | |/ ____ | |__| |"
  echo -e "     |_|  |_|\___|_|  |_|_|_| |_/_/    \_\____/ ${GRNct}v${SCRIPT_VERSION}"
  echo -e "${NOct}"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Jul-03] ##
##---------------------------------------##
_ShowAbout_()
{
    clear
    _ShowLogo_
    cat <<EOF
About
  $SCRIPT_NAME is a tool for automating firmware updates on AsusWRT Merlin,
  ensuring your router stays up-to-date with the latest features and security
  patches. It simplifies the update process by automatically checking for,
  downloading, and applying new firmware versions.
  Developed by ExtremeFiretop and Martinski W.
License
  $SCRIPT_NAME is free to use under the GNU General Public License
  version 3 (GPL-3.0) https://opensource.org/licenses/GPL-3.0
Help & Support
  https://www.snbforums.com/threads/merlinau-the-ultimate-firmware-auto-updater-addon.88577/
Source code
  https://github.com/ExtremeFiretop/MerlinAutoUpdate-Router
EOF
    echo
    _DoExit_ 0
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Nov-18] ##
##------------------------------------------##
_ShowHelp_()
{
    clear
    _ShowLogo_
    cat <<EOF
Available commands:
  ${SCRIPT_NAME}.sh about              explains functionality
  ${SCRIPT_NAME}.sh help               display available commands
  ${SCRIPT_NAME}.sh checkupdates       check for available MerlinAU script updates
  ${SCRIPT_NAME}.sh forceupdate        updates to latest version (force update)
  ${SCRIPT_NAME}.sh run_now            run update process on router
  ${SCRIPT_NAME}.sh processNodes       run update check on nodes
  ${SCRIPT_NAME}.sh develop            switch to development branch
  ${SCRIPT_NAME}.sh stable             switch to stable branch
  ${SCRIPT_NAME}.sh startup            runs startup initialization & mounts WebUI page
  ${SCRIPT_NAME}.sh install            installs add-on files
  ${SCRIPT_NAME}.sh uninstall          uninstalls add-on files
EOF
    echo
    _DoExit_ 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-31] ##
##----------------------------------------##
## To support new "3006" F/W Basecode ##
if [ "$fwInstalledBaseVers" -ge 3006 ]
then readonly nvramLEDsVar=AllLED
else readonly nvramLEDsVar=led_disable
fi

# Save initial LEDs state to put it back later #
readonly LEDsInitState="$(nvram get "$nvramLEDsVar")"
LEDsToggleState="$LEDsInitState"
Toggle_LEDs_PID=""

# To enable/disable the built-in "F/W Update Check" #
FW_UpdateCheckState="$(nvram get firmware_check_enable)"
FW_UpdateCheckScript="/usr/sbin/webs_update.sh"

##-------------------------------------##
## Added by Martinski W. [2023-Nov-24] ##
##-------------------------------------##
#---------------------------------------------------------#
# The USB-attached drives can have multiple partitions
# with different file systems (NTFS, ext3, ext4, etc.),
# which means that multiple mount points can be found.
# So for the purpose of choosing a default value here
# we will simply select the first mount point found.
# Users can later on change it by typing a different
# mount point path or directory using the Main Menu.
#---------------------------------------------------------#
_GetDefaultUSBMountPoint_()
{
   local mountPointPath  retCode=0
   local mountPointRegExp="^/dev/sd.* /tmp/mnt/.*"

   mountPointPath="$(grep -m1 "$mountPointRegExp" /proc/mounts | awk -F ' ' '{print $2}')"
   [ -z "$mountPointPath" ] && retCode=1
   echo "$mountPointPath" ; return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-31] ##
##----------------------------------------##
# Background function to create a blinking LED effect #
_Toggle_LEDs_()
{
   if [ -z "$LEDsToggleState" ]
   then
       sleep 1
       Toggle_LEDs_PID=""
       return 1
   fi

   if [ $# -eq 0 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE "^[2-5]$"
   then blinkRateSecs=2
   else blinkRateSecs="$1"
   fi

   while true
   do
      LEDsToggleState="$((! LEDsToggleState))"
      nvram set ${nvramLEDsVar}="$LEDsToggleState"
      /sbin/service restart_leds > /dev/null 2>&1
      sleep "$blinkRateSecs"
   done
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-31] ##
##----------------------------------------##
_Reset_LEDs_()
{
   local doTrace=false
   [ $# -gt 0 ] && [ "$1" -eq 1 ] && doTrace=false
   if "$doTrace"
   then
       Say "START _Reset_LEDs_"
       _UserTraceLog_ "START _Reset_LEDs_"
   fi

   # Check if the process with that PID is still running #
   if [ -n "$Toggle_LEDs_PID" ] && \
      kill -EXIT "$Toggle_LEDs_PID" 2>/dev/null
   then
       kill -TERM $Toggle_LEDs_PID
       wait $Toggle_LEDs_PID
       # Set LEDs to their "initial state" #
       nvram set ${nvramLEDsVar}="$LEDsInitState"
       /sbin/service restart_leds >/dev/null 2>&1
       sleep 2
   fi
   Toggle_LEDs_PID=""

   if "$doTrace"
   then
       Say "EXIT _Reset_LEDs_"
       _UserTraceLog_ "EXIT _Reset_LEDs_"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_GetRouterURL_()
{
    local urlProto  urlDomain  urlPort

    if [ "$(nvram get http_enable)" = "1" ]
    then urlProto="https"
    else urlProto="http"
    fi

    urlDomain="$(nvram get lan_domain)"
    if [ -z "$urlDomain" ]
    then urlDomain="$mainLAN_IPaddr"
    else urlDomain="${myLAN_HostName}.$urlDomain"
    fi

    urlPort="$(nvram get "${urlProto}_lanport")"
    if [ "$urlPort" -eq 80 ] || [ "$urlPort" -eq 443 ]
    then urlPort=""
    else urlPort=":$urlPort"
    fi

    echo "${urlProto}://${urlDomain}${urlPort}"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------------##
_GetRouterModelID_()
{
   local retCode=1  routerModelID=""
   local nvramModelKeys="odmpid wps_modelnum model build_name"
   for nvramKey in $nvramModelKeys
   do
       routerModelID="$(nvram get "$nvramKey")"
       [ -n "$routerModelID" ] && retCode=0 && break
   done
   echo "$routerModelID" ; return "$retCode"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------------##
_GetRouterProductID_()
{
   local retCode=1  routerProductID=""
   local nvramProductKeys="productid build_name odmpid"
   for nvramKey in $nvramProductKeys
   do
       routerProductID="$(nvram get "$nvramKey")"
       [ -n "$routerProductID" ] && retCode=0 && break
   done
   echo "$routerProductID" ; return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-28] ##
##-------------------------------------##
_ScriptVersionStrToNum_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then echo 0 ; return 1 ; fi
   local verNum  verStr

   verStr="$(echo "$1" | awk -F '_' '{print $1}')"
   verNum="$(echo "$verStr" | awk -F '.' '{printf ("%d%03d%03d\n", $1,$2,$3);}')"
   verNum="$(echo "$verNum" | sed 's/^0*//')"
   echo "$verNum" ; return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Aug-11] ##
##----------------------------------------##
_GetFirmwareVariantFromRouter_()
{
   local hasGNUtonFW=false

   ##FOR TESTING/DEBUG ONLY##
   if false  # Change to true for forcing GNUton flag #
   then hasGNUtonFW=true ; return 0 ; fi
   ##FOR TESTING/DEBUG ONLY##

   # Check if installed F/W NVRAM vars contain "gnuton" #
   if echo "$fwInstalledInnerVers" | grep -iq "gnuton" || \
      echo "$fwInstalledExtendNum" | grep -iq "gnuton"
   then hasGNUtonFW=true ; fi

   echo "$hasGNUtonFW" ; return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-31] ##
##----------------------------------------##
_FWVersionStrToNum_()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
    then echo ; return 1 ; fi

    USE_BETA_WEIGHT="$(Get_Custom_Setting FW_Allow_Beta_Production_Up)"

    local verNum  verStr="$1"  nonProductionVersionWeight=0
    local fwBasecodeVers=""  numOfFields

    #--------------------------------------------------------------
    # Handle any 'alpha/beta' in the version string to be sure
    # that we always get good numerical values for comparison.
    #--------------------------------------------------------------
    if echo "$verStr" | grep -qiE '(alpha|beta)'
    then
        # Adjust weight value if "Beta-to-Production" update is enabled #
        [ "$USE_BETA_WEIGHT" = "ENABLED" ] && nonProductionVersionWeight=-100

        # Replace '.alpha|.beta' and anything following it with ".0" #
        verStr="$(echo "$verStr" | sed 's/[.][Aa]lpha.*/.0/ ; s/[.][Bb]eta.*/.0/')"
        # Remove 'alpha|beta' and anything following it #
        verStr="$(echo "$verStr" | sed 's/[_-]\?[Aa]lpha.*// ; s/[_-]\?[Bb]eta.*//')"
    fi

    numOfFields="$(echo "$verStr" | awk -F '.' '{print NF}')"

    if [ "$numOfFields" -lt "$2" ]
    then fwBasecodeVers="$fwInstalledBaseVers" ; fi

    #-----------------------------------------------------------
    # Temporarily remove Basecode version to avoid issues with
    # integers greater than the maximum 32-bit signed integer
    # when doing arithmetic computations with shell cmds.
    #-----------------------------------------------------------
    if [ "$numOfFields" -gt 3 ]
    then
        fwBasecodeVers="$(echo "$verStr" | cut -d'.' -f1)"
        verStr="$(echo "$verStr" | cut -d'.' -f2-)"
    fi
    verNum="$(echo "$verStr" | awk -F '.' '{printf ("%d%02d%02d\n", $1,$2,$3);}')"

    # Subtract non-production weight from the version number #
    verNum="$((verNum + nonProductionVersionWeight))"

    # Now prepend the F/W Basecode version #
    [ -n "$fwBasecodeVers" ] && verNum="${fwBasecodeVers}$verNum"

    echo "$verNum" ; return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-27] ##
##----------------------------------------##
if "$inRouterSWmode" 
then
    readonly FW_Update_CRON_DefaultSchedule="0 0 * * *"
else
    ## Recommended 20 minutes AFTER for AiMesh Nodes ##
    readonly FW_Update_CRON_DefaultSchedule="20 0 * * *"
fi

## Recommended 15 minutes BEFORE the F/W Update ##
readonly ScriptAU_CRON_DefaultSchedule="45 23 * * *"

## For Automatic Script Updates Cron Schedule ##
readonly SW_Update_CRON_DefaultSchedDays="* x *"

readonly CRON_MINS_RegEx="([0-9]|[1-5][0-9])"
readonly CRON_HOUR_RegEx="([0-9]|1[0-9]|2[0-3])"

readonly CRON_DAYofMONTH_rexp1="([1-9]|[1-2][0-9]|3[0-1])"
readonly CRON_DAYofMONTH_rexp2="${CRON_DAYofMONTH_rexp1}[-]${CRON_DAYofMONTH_rexp1}"
readonly CRON_DAYofMONTH_rexp3="${CRON_DAYofMONTH_rexp2}[/][2-9]"
readonly CRON_DAYofMONTH_rexp4="${CRON_DAYofMONTH_rexp1}([,]${CRON_DAYofMONTH_rexp1})+"
readonly CRON_DAYofMONTH_RegEx="($CRON_DAYofMONTH_rexp1|$CRON_DAYofMONTH_rexp2|$CRON_DAYofMONTH_rexp3|$CRON_DAYofMONTH_rexp4)"

readonly CRON_DAYofWEEK_Names="([S|s]un|[M|m]on|[T|t]ue|[W|w]ed|[T|t]hu|[F|f]ri|[S|s]at)"
readonly CRON_DAYofWEEK_rexp1="[0-6][-][0-6][/][2-3]"
readonly CRON_DAYofWEEK_rexp2="${CRON_DAYofWEEK_Names}|[0-6]"
readonly CRON_DAYofWEEK_rexp3="${CRON_DAYofWEEK_Names}[-]${CRON_DAYofWEEK_Names}|[0-6][-][0-6]"
readonly CRON_DAYofWEEK_rexp4="${CRON_DAYofWEEK_Names}([,]${CRON_DAYofWEEK_Names})+|[0-6]([,][0-6])+"
readonly CRON_DAYofWEEK_RegEx="($CRON_DAYofWEEK_rexp1|$CRON_DAYofWEEK_rexp2|$CRON_DAYofWEEK_rexp3|$CRON_DAYofWEEK_rexp4)"

readonly CRON_MONTH_NAMES="(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"
readonly CRON_MONTH_RegEx="$CRON_MONTH_NAMES([\/,-]$CRON_MONTH_NAMES)*|([*1-9]|1[0-2])([\/,-]([1-9]|1[0-2]))*"

readonly CRON_UNKNOWN_DATE="**ERROR**: UNKNOWN Date Found"

##------------------------------------------##
## Modified by Martinski W. [2024-Aug-06]   ##
##------------------------------------------##
# To postpone a firmware update for a few days #
readonly FW_UpdateMinimumPostponementDays=0
readonly FW_UpdateDefaultPostponementDays=15
readonly FW_UpdateMaximumPostponementDays=199
readonly FW_UpdateNotificationDateFormat="%Y-%m-%d_%H:%M:00"

readonly MODEL_ID="$(_GetRouterModelID_)"
readonly PRODUCT_ID="$(_GetRouterProductID_)"

##FOR TESTING/DEBUG ONLY##
##readonly PRODUCT_ID="TUF-AX3000_V2"
##readonly MODEL_ID="$PRODUCT_ID"
##FOR TESTING/DEBUG ONLY##

readonly FW_FileName="${PRODUCT_ID}_firmware"
readonly FW_SFURL_RELEASE="${FW_SFURL_BASE}/${PRODUCT_ID}/${FW_SFURL_RELEASE_SUFFIX}/"
readonly isGNUtonFW="$(_GetFirmwareVariantFromRouter_)"

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
readonly FW_RouterProductID="${GRNct}${PRODUCT_ID}${NOct}"
# Some Model IDs have a lower case suffix of the same Product ID #
if [ "$PRODUCT_ID" = "$(echo "$MODEL_ID" | tr 'a-z' 'A-Z')" ]
then
    readonly FW_RouterModelID="$PRODUCT_ID"
    readonly FW_RouterModelIDstr="$FW_RouterProductID"
else
    readonly FW_RouterModelID="${PRODUCT_ID}/$MODEL_ID"
    readonly FW_RouterModelIDstr="${FW_RouterProductID}/${GRNct}${MODEL_ID}${NOct}"
fi

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_ChangeToDev_()
{
    if ! _AcquireLock_ cliFileLock
    then return 1
    fi
    SCRIPT_BRANCH="dev"
    SCRIPT_URL_REPO="${SCRIPT_URL_BASE}/$SCRIPT_BRANCH"
    _SCRIPT_UPDATE_ force
    _DoExit_ 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_ChangeToStable_()
{
    if ! _AcquireLock_ cliFileLock
    then return 1
    fi
    SCRIPT_BRANCH="master"
    SCRIPT_URL_REPO="${SCRIPT_URL_BASE}/$SCRIPT_BRANCH"
    _SCRIPT_UPDATE_ force
    _DoExit_ 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-15] ##
##----------------------------------------##
#-------------------------------------------------------------#
# Since a list of current mount points can have a different
# order after each reboot, or when USB drives are unmounted
# (unplugged) & then mounted (plugged in) manually by users,
# to validate a given mount point path selection we have to
# go through the current list & check for the specific path.
# We also make a special case for Entware "/opt/" paths.
#-------------------------------------------------------------#
_ValidateUSBMountPoint_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local mounPointPaths  expectedPath  mountPointList
   local symblPath  realPath1  realPath2  foundPathOK
   local mountPointRegExp="^/dev/sd.* /tmp/mnt/.*"

   mounPointPaths="$(grep "$mountPointRegExp" /proc/mounts | awk -F ' ' '{print $2}')"
   [ -z "$mounPointPaths" ] && return 1

   expectedPath="$1"
   if echo "$1" | grep -qE "^(/opt/|/tmp/opt/)" && [ -d /tmp/opt ]
   then
       realPath1="$(readlink -f /tmp/opt)"
       realPath2="$(ls -l /tmp/opt | awk -F ' ' '{print $11}')"
       symblPath="$(ls -l /tmp/opt | awk -F ' ' '{print $9}')"
       [ -L "$symblPath" ] && [ -n "$realPath1" ] && \
       [ -n "$realPath2" ] && [ "$realPath1" = "$realPath2" ] && \
       expectedPath="$(/usr/bin/dirname "$realPath1")"
   fi

   mountPointList=""
   foundPathOK=false

   for thePATH in $mounPointPaths
   do
      if echo "${expectedPath}/" | grep -qE "^${thePATH}/"
      then foundPathOK=true ; break ; fi
      mountPointList="$mountPointList $thePATH"
   done
   "$foundPathOK" && return 0

   ## Report found Mount Points on failure ##
   if [ $# -gt 1 ] && [ "$2" -eq 1 ] && [ -n "$mountPointList" ]
   then Say "Mount points found:\n$mountPointList" ; fi
   return 1
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-24] ##
##----------------------------------------##
if USBMountPoint="$(_GetDefaultUSBMountPoint_)"
then
    USBConnected="${GRNct}True${NOct}"
    readonly FW_Update_ZIP_DefaultSetupDIR="$USBMountPoint"
    readonly FW_Update_LOG_BASE_DefaultDIR="$USBMountPoint"
else
    USBConnected="${REDct}False${NOct}"
    readonly FW_Update_ZIP_DefaultSetupDIR="/home/root"
    readonly FW_Update_LOG_BASE_DefaultDIR="$ADDONS_PATH"
fi

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_SetUp_FW_UpdateZIP_DirectoryPaths_()
{
   local theDirPath=""
   if [ $# -eq 1 ] && [ -n "$1" ] && [ -d "$1" ]
   then
       theDirPath="$1"
   else
       theDirPath="$(Get_Custom_Setting FW_New_Update_ZIP_Directory_Path)"
   fi
   FW_ZIP_BASE_DIR="$theDirPath"
   FW_ZIP_DIR="${FW_ZIP_BASE_DIR}/$FW_ZIP_SUBDIR"
   FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_SetUp_FW_UpdateLOG_DirectoryPaths_()
{
   local theDirPath=""
   if [ $# -eq 1 ] && [ -n "$1" ] && [ -d "$1" ]
   then
       theDirPath="$1"
   else
       theDirPath="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"
   fi
   FW_LOG_BASE_DIR="$theDirPath"
   FW_LOG_DIR="${FW_LOG_BASE_DIR}/$FW_LOG_SUBDIR"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_InitCustomSettingsConfig_()
{
   [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

   if [ ! -f "$CONFIG_FILE" ]
   then
      {
         echo "FW_New_Update_Notification_Date TBD"
         echo "FW_New_Update_Notification_Vers TBD"
         echo "FW_New_Update_Postponement_Days=$FW_UpdateDefaultPostponementDays"
         echo "FW_New_Update_EMail_Notification $FW_UpdateEMailNotificationDefault"
         echo "FW_New_Update_EMail_FormatType=\"${FW_UpdateEMailFormatTypeDefault}\""
         echo "FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\""
         echo "FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\""
         echo "FW_New_Update_LOG_Directory_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\""
         echo "FW_New_Update_LOG_Preferred_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\""
         echo "FW_New_Update_EMail_CC_Name=TBD"
         echo "FW_New_Update_EMail_CC_Address=TBD"
         echo "CheckChangeLog ENABLED"
         echo "FW_Update_Check TBD"
         echo "Allow_Updates_OverVPN DISABLED"
         echo "FW_Allow_Beta_Production_Up ENABLED"
         echo "Allow_Script_Auto_Update DISABLED"
         echo "Script_Update_Cron_Job_SchedDays=\"${SW_Update_CRON_DefaultSchedDays}\""
      } > "$CONFIG_FILE"
      chmod 664 "$CONFIG_FILE"
      return 1
   fi
   local retCode=0  preferredPath

   # TEMPORARY Migration Function #
   _Migrate_Settings_

   if ! grep -q "^FW_New_Update_Notification_Date " "$CONFIG_FILE"
   then
       sed -i "1 i FW_New_Update_Notification_Date TBD" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Notification_Vers " "$CONFIG_FILE"
   then
       sed -i "2 i FW_New_Update_Notification_Vers TBD" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Postponement_Days=" "$CONFIG_FILE"
   then
       sed -i "3 i FW_New_Update_Postponement_Days=$FW_UpdateDefaultPostponementDays" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_EMail_Notification " "$CONFIG_FILE"
   then
       sed -i "4 i FW_New_Update_EMail_Notification $FW_UpdateEMailNotificationDefault" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_EMail_FormatType=" "$CONFIG_FILE"
   then
       sed -i "5 i FW_New_Update_EMail_FormatType=\"${FW_UpdateEMailFormatTypeDefault}\"" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Cron_Job_Schedule=" "$CONFIG_FILE"
   then
       sed -i "6 i FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\"" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_ZIP_Directory_Path=" "$CONFIG_FILE"
   then
       sed -i "7 i FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\"" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_LOG_Directory_Path=" "$CONFIG_FILE"
   then
       sed -i "8 i FW_New_Update_LOG_Directory_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\"" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_LOG_Preferred_Path=" "$CONFIG_FILE"
   then
       preferredPath="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"
       sed -i "9 i FW_New_Update_LOG_Preferred_Path=\"${preferredPath}\"" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^CheckChangeLog " "$CONFIG_FILE"
   then
       sed -i "10 i CheckChangeLog ENABLED" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_Update_Check " "$CONFIG_FILE"
   then
       sed -i "11 i FW_Update_Check TBD" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^Allow_Updates_OverVPN " "$CONFIG_FILE"
   then
       sed -i "12 i Allow_Updates_OverVPN DISABLED" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^FW_Allow_Beta_Production_Up " "$CONFIG_FILE"
   then
       sed -i "13 i FW_Allow_Beta_Production_Up ENABLED" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^Allow_Script_Auto_Update " "$CONFIG_FILE"
   then
       sed -i "14 i Allow_Script_Auto_Update DISABLED" "$CONFIG_FILE"
       retCode=1
   fi
   if ! grep -q "^Script_Update_Cron_Job_SchedDays=" "$CONFIG_FILE"
   then
       sed -i "15 i Script_Update_Cron_Job_SchedDays=\"${SW_Update_CRON_DefaultSchedDays}\"" "$CONFIG_FILE"
       retCode=1
   fi
   dos2unix "$CONFIG_FILE"
   chmod 664 "$CONFIG_FILE"

   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
Get_Custom_Setting()
{
    if [ $# -eq 0 ] || [ -z "$1" ]; then echo "**ERROR**"; return 1; fi
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    local setting_value=""  setting_type="$1"  default_value="TBD"
    [ $# -gt 1 ] && default_value="$2"

    if [ -f "$CONFIG_FILE" ]
    then
        case "$setting_type" in
            "ROGBuild" | "TUFBuild" | \
            "credentials_base64" | \
            "CheckChangeLog" | \
            "FW_Update_Check" | \
            "Allow_Updates_OverVPN" | \
            "FW_Allow_Beta_Production_Up" | \
            "FW_Auto_Backupmon" | \
            "Allow_Script_Auto_Update" | \
            "FW_New_Update_EMail_Notification" | \
            "FW_New_Update_Notification_Date" | \
            "FW_New_Update_Notification_Vers")
                setting_value="$(grep "^${setting_type} " "$CONFIG_FILE" | awk -F ' ' '{print $2}')"
                ;;
            "FW_New_Update_Postponement_Days"  | \
            "FW_New_Update_Changelog_Approval" | \
            "FW_New_Update_Expected_Run_Date"  | \
            "FW_New_Update_Cron_Job_Schedule"  | \
            "Script_Update_Cron_Job_SchedDays" | \
            "FW_New_Update_ZIP_Directory_Path" | \
            "FW_New_Update_LOG_Directory_Path" | \
            "FW_New_Update_LOG_Preferred_Path" | \
            "FW_New_Update_EMail_FormatType" | \
            "FW_New_Update_EMail_CC_Name" | \
            "FW_New_Update_EMail_CC_Address")
                grep -q "^${setting_type}=" "$CONFIG_FILE" && \
                setting_value="$(grep "^${setting_type}=" "$CONFIG_FILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                ;;
            *)
                setting_value="**ERROR**"
                ;;
        esac
        if [ -z "$setting_value" ]
        then echo "$default_value"
        else echo "$setting_value"
        fi
    else
        echo "$default_value"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
Update_Custom_Settings()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] ; then return 1 ; fi

    local fixedVal  oldVal=""
    local setting_type="$1"  setting_value="$2"

    # Check if the directory exists, and if not, create it #
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    case "$setting_type" in
        "ROGBuild" | "TUFBuild" | \
        "credentials_base64" | \
        "CheckChangeLog" | \
        "FW_Update_Check" | \
        "Allow_Updates_OverVPN" | \
        "FW_Allow_Beta_Production_Up" | \
        "FW_Auto_Backupmon" | \
        "Allow_Script_Auto_Update" | \
        "FW_New_Update_EMail_Notification" | \
        "FW_New_Update_Notification_Date" | \
        "FW_New_Update_Notification_Vers")
            if [ -f "$CONFIG_FILE" ]
            then
                if [ "$(grep -c "^$setting_type" "$CONFIG_FILE")" -gt 0 ]
                then
                    if [ "$setting_value" != "$(grep "^$setting_type" "$CONFIG_FILE" | cut -f2 -d' ')" ]
                    then
                        sed -i "s/^$setting_type.*/$setting_type $setting_value/" "$CONFIG_FILE"
                    fi
                else
                    echo "$setting_type $setting_value" >> "$CONFIG_FILE"
                fi
            else
                echo "$setting_type $setting_value" > "$CONFIG_FILE"
            fi
            ;;
        "FW_New_Update_Postponement_Days"  | \
        "FW_New_Update_Changelog_Approval" | \
        "FW_New_Update_Expected_Run_Date"  | \
        "FW_New_Update_Cron_Job_Schedule"  | \
        "Script_Update_Cron_Job_SchedDays" | \
        "FW_New_Update_ZIP_Directory_Path" | \
        "FW_New_Update_LOG_Directory_Path" | \
        "FW_New_Update_LOG_Preferred_Path" | \
        "FW_New_Update_EMail_FormatType" | \
        "FW_New_Update_EMail_CC_Name" | \
        "FW_New_Update_EMail_CC_Address")
            if [ -f "$CONFIG_FILE" ]
            then
                if grep -q "^${setting_type}=" "$CONFIG_FILE"
                then
                    oldVal="$(grep "^${setting_type}=" "$CONFIG_FILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                    if [ -z "$oldVal" ] || [ "$oldVal" != "$setting_value" ]
                    then
                        fixedVal="$(echo "$setting_value" | sed 's/[\/.,*-]/\\&/g')"
                        sed -i "s/${setting_type}=.*/${setting_type}=\"${fixedVal}\"/" "$CONFIG_FILE"
                    fi
                else
                    echo "$setting_type=\"${setting_value}\"" >> "$CONFIG_FILE"
                fi
            else
                echo "$setting_type=\"${setting_value}\"" > "$CONFIG_FILE"
            fi
            if [ "$setting_type" = "FW_New_Update_Postponement_Days" ]
            then
                FW_UpdatePostponementDays="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_Expected_Run_Date" ]
            then
                FW_UpdateExpectedRunDate="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_EMail_FormatType" ]
            then
                sendEMailFormaType="$setting_value"
                [ "$sendEMailFormaType" = "HTML" ] && \
                isEMailFormatHTML=true || isEMailFormatHTML=false
            #
            elif [ "$setting_type" = "FW_New_Update_EMail_CC_Name" ]
            then
                sendEMail_CC_Name="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_EMail_CC_Address" ]
            then
                sendEMail_CC_Address="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_Cron_Job_Schedule" ]
            then
                FW_UpdateCronJobSchedule="$setting_value"
            #
            elif [ "$setting_type" = "Script_Update_Cron_Job_SchedDays" ]
            then
                ScriptUpdateCronSchedDays="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_ZIP_Directory_Path" ]
            then
                _SetUp_FW_UpdateZIP_DirectoryPaths_ "$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_LOG_Directory_Path" ]
            then
                _SetUp_FW_UpdateLOG_DirectoryPaths_ "$setting_value"
            fi
            ;;
        *)
            # Generic handling for arbitrary settings #
            if grep -q "^${setting_type}=" "$CONFIG_FILE"
            then
                oldVal="$(grep "^${setting_type}=" "$CONFIG_FILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                if [ -z "$oldVal" ] || [ "$oldVal" != "$setting_value" ]
                then
                    fixedVal="$(echo "$setting_value" | sed 's/[\/&]/\\&/g')"
                    sed -i "s/^${setting_type}=.*/${setting_type}=\"${fixedVal}\"/" "$CONFIG_FILE"
                fi
            else
                echo "${setting_type}=\"${setting_value}\"" >> "$CONFIG_FILE"
            fi
            ;;
    esac
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jun-04] ##
##----------------------------------------##
Delete_Custom_Settings()
{
    if [ $# -lt 1 ] || [ -z "$1" ] || [ ! -f "$CONFIG_FILE" ]
    then return 1 ; fi

    local setting_type="$1"
    sed -i "/^${setting_type}[ =]/d" "$CONFIG_FILE"
    return $?
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-21] ##
##------------------------------------------##
_GetAllNodeSettings_()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
    then echo "**ERROR**" ; return 1; fi

    ## Node Setting KEY="Node_{MACaddress}_{keySuffix}" ##
    local fullKeyName="Node_${1}_${2}"
    local setting_value="TBD"  matched_lines

    # Ensure the settings directory exists #
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    if [ -f "$CONFIG_FILE" ]
    then
        matched_lines="$(grep -E "^${fullKeyName}=.*" "$CONFIG_FILE")"
        if [ -n "$matched_lines" ]
        then
            # Extract the value from the first matched line #
            setting_value="$(echo "$matched_lines" | head -n 1 | awk -F '=' '{print $2}' | tr -d '"')"
        fi
    fi
    echo "$setting_value"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_Validate_FW_UpdateLOG_DirectoryPath_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -d "$1" ]
   then return 1 ; fi

   if [ "$1" = "$FW_LOG_DIR" ] || [ "$1" = "$FW_LOG_BASE_DIR" ]
   then return 0 ; fi

   local newFullDirPath=""  newBaseDirPath="$1"

   if echo "$newBaseDirPath" | grep -qE "/${FW_LOG_SUBDIR}$"
   then newFullDirPath="$newBaseDirPath"
   else newFullDirPath="${newBaseDirPath}/$FW_LOG_SUBDIR"
   fi
   mkdir -p -m 755 "$newFullDirPath" 2>/dev/null
   if [ ! -d "$newFullDirPath" ]
   then
       printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${newFullDirPath}${NOct}].\n"
       _WaitForEnterKey_
       return 1
   fi
   # Move any existing log files to new directory #
   mv -f "${FW_LOG_DIR}"/*.log "$newFullDirPath" 2>/dev/null
   # Remove now the obsolete directory path #
   rm -fr "${FW_LOG_DIR:?}"
   # Update the log directory paths after validation #
   Update_Custom_Settings FW_New_Update_LOG_Directory_Path "$newBaseDirPath"
   Update_Custom_Settings FW_New_Update_LOG_Preferred_Path "$newBaseDirPath"
   return 0
}

##------------------------------------------##
## Modified by ExtremeFiretop [2025-Jan-15] ##
##------------------------------------------##
_Set_FW_UpdateLOG_DirectoryPath_()
{
   local newLogBaseDirPath="$FW_LOG_BASE_DIR"  newLogFileDirPath=""

   while true
   do
      printf "\nEnter the directory path where the LOG subdirectory [${GRNct}${FW_LOG_SUBDIR}${NOct}] will be stored.\n"
      printf "[${theADExitStr}] [CURRENT: ${GRNct}${FW_LOG_BASE_DIR}${NOct}]:  "
      read -r userInput

      if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
      then break ; fi

      if echo "$userInput" | grep -q '/$'
      then userInput="${userInput%/*}" ; fi

      if echo "$userInput" | grep -q '//'   || \
         echo "$userInput" | grep -q '/$'   || \
         ! echo "$userInput" | grep -q '^/' || \
         [ "${#userInput}" -lt 4 ]          || \
         [ "$(echo "$userInput" | awk -F '/' '{print NF-1}')" -lt 2 ]
      then
          printf "\n${REDct}INVALID input.${NOct}\n"
          _WaitForEnterKey_
          clear
          continue
      fi

      if [ -d "$userInput" ]
      then newLogBaseDirPath="$userInput" ; break ; fi

      rootDir="${userInput%/*}"
      if [ ! -d "$rootDir" ]
      then
          printf "\n${REDct}**ERROR**${NOct}: Root directory path [${REDct}${rootDir}${NOct}] does NOT exist.\n\n"
          printf "\n${REDct}INVALID input.${NOct}\n"
          _WaitForEnterKey_
          clear
          continue
      fi

      printf "The directory path '${REDct}${userInput}${NOct}' does NOT exist.\n\n"
      if ! _WaitForYESorNO_ "Do you want to create it now"
      then
          printf "Directory was ${REDct}NOT${NOct} created.\n\n"
      else
          mkdir -m 755 "$userInput" 2>/dev/null
          if [ -d "$userInput" ]
          then newLogBaseDirPath="$userInput" ; break
          else printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${userInput}${NOct}].\n\n"
          fi
      fi
   done

   # Double-check current directory indeed exists after menu selection #
   if [ "$newLogBaseDirPath" = "$FW_LOG_BASE_DIR" ] && [ ! -d "$FW_LOG_DIR" ]
   then mkdir -p -m 755 "$FW_LOG_DIR" ; fi

   if [ -d "$newLogBaseDirPath" ]
   then
       if ! _Validate_FW_UpdateLOG_DirectoryPath_ "$newLogBaseDirPath"
       then return 1
       fi
       echo "The directory path for the log files was updated successfully."
       _WaitForEnterKey_ "$advnMenuReturnPromptStr"
   fi
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_Validate_FW_UpdateZIP_DirectoryPath_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local updateHelperJS=false
   if [ $# -eq 2 ] && [ "$2" = "true" ]
   then updateHelperJS=true ; fi

   if [ ! -d "$1" ]
   then
       if "$updateHelperJS"
       then
           checkErrorMsg="The directory path [$1] was NOT found."
           _UpdateHelperJSFile_ 0x01 "false" "$checkErrorMsg"
       fi
       Say "${REDct}**ERROR**${NOct}: Directory path [${REDct}${1}${NOct}] is NOT found."
       _WaitForEnterKey_
       return 1
   fi

   if [ "$1" = "$FW_ZIP_DIR" ] || [ "$1" = "$FW_ZIP_BASE_DIR" ]
   then
       _UpdateHelperJSFile_ 0x01 "true"
       return 0
   fi

   local newFullDirPath=""  newBaseDirPath="$1"

   if echo "$newBaseDirPath" | grep -qE "/${FW_ZIP_SUBDIR}$"
   then newFullDirPath="$newBaseDirPath"
   else newFullDirPath="${newBaseDirPath}/$FW_ZIP_SUBDIR"
   fi
   mkdir -p -m 755 "$newFullDirPath" 2>/dev/null
   if [ ! -d "$newFullDirPath" ]
   then
       if "$updateHelperJS"
       then
           checkErrorMsg="The directory path [$newFullDirPath] could NOT be created."
           _UpdateHelperJSFile_ 0x01 "false" "$checkErrorMsg"
       fi
       Say "${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${newFullDirPath}${NOct}]"
       _WaitForEnterKey_
       return 1
   fi
   # Remove now the obsolete directory path #
   rm -fr "${FW_ZIP_DIR:?}"
   rm -f "${newFullDirPath}"/*.zip  "${newFullDirPath}"/*.sha256
   Update_Custom_Settings FW_New_Update_ZIP_Directory_Path "$newBaseDirPath"
   _UpdateHelperJSFile_ 0x01 "true"
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
_Set_FW_UpdateZIP_DirectoryPath_()
{
   local newZIP_BaseDirPath="$FW_ZIP_BASE_DIR"  newZIP_FileDirPath=""

   while true
   do
      if "$isGNUtonFW"
      then
          printf "\nEnter the directory path where the update subdirectory [${GRNct}${FW_ZIP_SUBDIR}${NOct}] will be stored.\n" 
      else
          printf "\nEnter the directory path where the ZIP subdirectory [${GRNct}${FW_ZIP_SUBDIR}${NOct}] will be stored.\n"
      fi
      if [ -n "$USBMountPoint" ] && _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR"
      then
          printf "Default directory for USB-attached drive: [${GRNct}${FW_ZIP_BASE_DIR}${NOct}]\n"
      else
          printf "Default directory for 'Local' storage is: [${GRNct}/home/root${NOct}]\n"
      fi
      printf "\n[${theADExitStr}] [CURRENT: ${GRNct}${FW_ZIP_BASE_DIR}${NOct}]:  "

      read -r userInput

      if [ -z "$userInput" ] ; then break ; fi
      if echo "$userInput" | grep -qE "^(e|E|exit|Exit)$" ; then return 1 ; fi

      if echo "$userInput" | grep -q '/$'
      then userInput="${userInput%/*}" ; fi

      if echo "$userInput" | grep -q '//'   || \
         echo "$userInput" | grep -q '/$'   || \
         ! echo "$userInput" | grep -q '^/' || \
         [ "${#userInput}" -lt 4 ]          || \
         [ "$(echo "$userInput" | awk -F '/' '{print NF-1}')" -lt 2 ]
      then
          printf "\n${REDct}INVALID input.${NOct}\n"
          _WaitForEnterKey_
          clear
          continue
      fi

      if [ -d "$userInput" ]
      then newZIP_BaseDirPath="$userInput" ; break ; fi

      rootDir="${userInput%/*}"
      if [ ! -d "$rootDir" ]
      then
          printf "\n${REDct}**ERROR**${NOct}: Root directory path [${REDct}${rootDir}${NOct}] does NOT exist.\n\n"
          printf "\n${REDct}INVALID input.${NOct}\n"
          _WaitForEnterKey_
          clear
          continue
      fi

      printf "The directory path '${REDct}${userInput}${NOct}' does NOT exist.\n\n"
      if ! _WaitForYESorNO_ "Do you want to create it now"
      then
          printf "Directory was ${REDct}NOT${NOct} created.\n\n"
      else
          mkdir -m 755 "$userInput" 2>/dev/null
          if [ -d "$userInput" ]
          then newZIP_BaseDirPath="$userInput" ; break
          else printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${userInput}${NOct}].\n\n"
          fi
      fi
   done

   if [ -d "$newZIP_BaseDirPath" ]
   then
       if ! _Validate_FW_UpdateZIP_DirectoryPath_ "$newZIP_BaseDirPath"
       then return 1
       fi
       if "$isGNUtonFW"
       then
           echo "The directory path for the F/W update file was updated successfully." 
       else
           echo "The directory path for the F/W ZIP file was updated successfully."
       fi
       keepWfile=0
       _WaitForEnterKey_ "$advnMenuReturnPromptStr"
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
## Function to migrate specific settings from old values to new standardized values.
## This function is meant to be only TEMPORARY.
## We should be safe to remove it after 3 months, or 5 version releases,
## whichever comes first. Similar to the migration function removed in v1.0.9
##-----------------------------------------------------------------------------------##
_Migrate_Settings_()
{
    [ ! -s "$CONFIG_FILE" ] && return 1

    ## Migrate Setting from [y|Y|n|N] to [ENABLED|DISABLED] ##
    ROGBuild_Value="$(Get_Custom_Setting ROGBuild)"
    if [ "$ROGBuild_Value" != "TBD" ]
    then
        case "$ROGBuild_Value" in
            y|Y) New_ROGBuild_Value="ENABLED" ;;
            n|N) New_ROGBuild_Value="DISABLED" ;;
            *)
               New_ROGBuild_Value=""
               ! echo "$ROGBuild_Value" | grep -qE "^(ENABLED|DISABLED)$" && \
               Say "ROGBuild has a unknown value: '$ROGBuild_Value'. Skipping migration for this setting."
               ;;
        esac
        if [ -n "$New_ROGBuild_Value" ]
        then
            if Update_Custom_Settings ROGBuild "$New_ROGBuild_Value"
            then
                Say "ROGBuild setting successfully migrated to '$New_ROGBuild_Value'."
            else
                Say "Error occurred while migrating ROGBuild setting to '$New_ROGBuild_Value'."
            fi
        fi
    fi

    ## Migrate Setting from [y|Y|n|N] to [ENABLED|DISABLED] ##
    TUFBuild_Value="$(Get_Custom_Setting TUFBuild)"
    if [ "$TUFBuild_Value" != "TBD" ]
    then
        case "$TUFBuild_Value" in
            y|Y) New_TUFBuild_Value="ENABLED" ;;
            n|N) New_TUFBuild_Value="DISABLED" ;;
            *)
               New_TUFBuild_Value=""
               ! echo "$TUFBuild_Value" | grep -qE "^(ENABLED|DISABLED)$" && \
               Say "TUFBuild has a unknown value: '$TUFBuild_Value'. Skipping migration for this setting."
               ;;
        esac
        if [ -n "$New_TUFBuild_Value" ]
        then
            if Update_Custom_Settings TUFBuild "$New_TUFBuild_Value"
            then
                Say "TUFBuild setting successfully migrated to '$New_TUFBuild_Value'."
            else
                Say "Error occurred while migrating TUFBuild setting to '$New_TUFBuild_Value'."
            fi
        fi
    fi

    ## Migrate Setting from [true|false] to [ENABLED|DISABLED] ##
    EMailNotif_Value="$(grep '^FW_New_Update_EMail_Notification=' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"')"
    if [ -n "$EMailNotif_Value" ] && [ "$EMailNotif_Value" != "TBD" ]
    then
        case "$EMailNotif_Value" in
               true|TRUE|True) New_EMailNotif_Value="ENABLED" ;;
            false|FALSE|False) New_EMailNotif_Value="DISABLED" ;;
            *)
               New_EMailNotif_Value=""
               ! echo "$EMailNotif_Value" | grep -qE "^(ENABLED|DISABLED)$" && \
               Say "FW_New_Update_EMail_Notification has a unknown value: '$EMailNotif_Value'. Skipping migration for this setting."
               ;;
        esac
        if [ -n "$New_EMailNotif_Value" ]
        then
            sed -i "s/^FW_New_Update_EMail_Notification=.*/FW_New_Update_EMail_Notification $New_EMailNotif_Value/" "$CONFIG_FILE"
            if [ $? -eq 0 ]
            then
                sendEMailNotificationsFlag="$New_EMailNotif_Value"
                Say "EMail_Notification setting successfully migrated to $New_EMailNotif_Value."
            else
                Say "Error occurred while migrating EMail_Notification setting to $New_EMailNotif_Value."
            fi
        fi
    fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jun-03] ##
##------------------------------------------##
# NOTE:
# ROG upgrades to 3006 codebase should have 
# the ROG option deleted.
#-----------------------------------------------------------
if ! "$isGNUtonFW"
then
    if [ "$fwInstalledBaseVers" -ge 3006 ] && \
       grep -q "^ROGBuild" "$CONFIG_FILE"
    then Delete_Custom_Settings "ROGBuild" ; fi
fi

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-27] ##
##------------------------------------------##
# NOTE:
# Depending on available RAM & storage capacity of the
# target router, it may be required to have USB-attached
# storage for the ZIP file so that it can be downloaded
# in a separate directory from the firmware bin file.
#-----------------------------------------------------------
readonly FW_LOG_SUBDIR="${ScriptDirNameD}/logs"
readonly FW_BIN_SUBDIR="${ScriptDirNameD}/$FW_FileName"
readonly FW_ZIP_SUBDIR="${ScriptDirNameD}/$FW_FileName"

FW_BIN_BASE_DIR="/home/root"
FW_BIN_DIR="${FW_BIN_BASE_DIR}/$FW_BIN_SUBDIR"

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
_SetUp_FW_UpdateZIP_DirectoryPaths_
_SetUp_FW_UpdateLOG_DirectoryPaths_

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-24] ##
##----------------------------------------##
# The built-in F/W hook script file to be used for
# setting up persistent jobs to run after a reboot.
readonly hookScriptFName="services-start"
readonly hookScriptFPath="${SCRIPTS_PATH}/$hookScriptFName"
readonly hookScriptTagStr="#Added by $ScriptFNameTag#"

# Postponement Days for F/W Update Check #
FW_UpdatePostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days)"
FW_UpdateExpectedRunDate="$(Get_Custom_Setting FW_New_Update_Expected_Run_Date)"

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-18] ##
##----------------------------------------##
# F/W Update Email Notifications #
isEMailFormatHTML=true
isEMailConfigEnabledInAMTM=false
sendEMailFormaType="$(Get_Custom_Setting FW_New_Update_EMail_FormatType)"
sendEMailNotificationsFlag="$(Get_Custom_Setting FW_New_Update_EMail_Notification)"
sendEMail_CC_Name="$(Get_Custom_Setting FW_New_Update_EMail_CC_Name)"
sendEMail_CC_Address="$(Get_Custom_Setting FW_New_Update_EMail_CC_Address)"
if [ "$sendEMailFormaType" = "HTML" ]
then isEMailFormatHTML=true
else isEMailFormatHTML=false
fi

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-27] ##
##----------------------------------------##
# Define the CRON job command to execute #
# Define the hook script file to be used #
ScriptAutoUpdateSetting="$(Get_Custom_Setting Allow_Script_Auto_Update)"
ScriptUpdateCronSchedDays="$(Get_Custom_Setting Script_Update_Cron_Job_SchedDays)"

readonly SCRIPT_UP_CRON_JOB_RUN="sh $ScriptFilePath checkupdates"
readonly SCRIPT_UP_CRON_JOB_TAG="${ScriptFNameTag}_ScriptUpdate"
readonly DAILY_SCRIPT_UPDATE_CHECK_JOB="sh $ScriptFilePath scriptAUCronJob &  $hookScriptTagStr"
readonly DAILY_SCRIPT_UPDATE_CHECK_HOOK="[ -f $ScriptFilePath ] && $DAILY_SCRIPT_UPDATE_CHECK_JOB"

# Define the CRON job command to execute #
FW_UpdateCronJobSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
readonly CRON_JOB_RUN="sh $ScriptFilePath run_now"
readonly CRON_JOB_TAG_OLD="$ScriptFNameTag"
readonly CRON_JOB_TAG="${ScriptFNameTag}_FWUpdate"
readonly CRON_SCRIPT_JOB="sh $ScriptFilePath addCronJob &  $hookScriptTagStr"
readonly CRON_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $CRON_SCRIPT_JOB"

# Define post-reboot run job command to execute #
readonly POST_REBOOT_SCRIPT_JOB="sh $ScriptFilePath postRebootRun &  $hookScriptTagStr"
readonly POST_REBOOT_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $POST_REBOOT_SCRIPT_JOB"

# Define post-update email notification job command to execute #
readonly POST_UPDATE_EMAIL_SCRIPT_JOB="sh $ScriptFilePath postUpdateEmail &  $hookScriptTagStr"
readonly POST_UPDATE_EMAIL_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $POST_UPDATE_EMAIL_SCRIPT_JOB"

if [ -d "$FW_LOG_DIR" ]
then
    # Log rotation - delete logs older than 30 days #
    /usr/bin/find -L "$FW_LOG_DIR" -name '*.log' -mtime +30 -exec rm {} \;
fi

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-27] ##
##----------------------------------------##
#-------------------------------------------------------------------------------------------
# This code is in case the user-selected USB mount point isn't available anymore.
# If the USB drive is selected as the log location but it goes offline for some reason,
# any call to the "Say" function creates a new '/tmp/mnt/XXXX' directory.
# In such a case where the USB drive is unmounted, we need to change the log directory
# back to a local directory. First if-statement executes first and updates to local 'jffs'
# directory if no USB drives are found. If ANY DefaultUSBMountPoint found, then move the
# log files from their local jffs location to the default mount location.
# We don't know the user selected yet because it's local at this time and was changed
# by the else statement. Remove the old log directory location from jffs, and update the
# settings file again to the new default again. This creates a semi-permanent switch which
# can reset back to default if the user-selected mount points aren't valid anymore.
#-------------------------------------------------------------------------------------------
UserSelectedLogPath="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"
if [ ! -d "$UserSelectedLogPath" ] || [ ! -r "$UserSelectedLogPath" ]; then
    Update_Custom_Settings FW_New_Update_LOG_Directory_Path "$ADDONS_PATH"
fi

UserPreferredLogPath="$(Get_Custom_Setting FW_New_Update_LOG_Preferred_Path)"
if echo "$UserPreferredLogPath" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)" && \
   _ValidateUSBMountPoint_ "$UserPreferredLogPath" && \
   [ "$UserPreferredLogPath" != "$FW_LOG_BASE_DIR" ]
then
   mv -f "${FW_LOG_DIR}"/*.log "${UserPreferredLogPath}/$FW_LOG_SUBDIR" 2>/dev/null
   rm -fr "${FW_LOG_DIR:?}"
   Update_Custom_Settings FW_New_Update_LOG_Directory_Path "$UserPreferredLogPath"
fi

##-------------------------------------##
## Added by Martinski W. [2025-Jan-11] ##
##-------------------------------------##
_GetWebUIPage_()
{
   local webPageFile  webPagePath  webPageTemp  webPageEntry

   webPageFile="NONE"

   if [ -f "$TEMP_MENU_TREE" ]
   then
       webPageEntry="$(grep -E "$webPageLineRegExp" "$TEMP_MENU_TREE")"
       if [ -n "$webPageEntry" ]
       then
           webPageTemp="$(echo "$webPageEntry" | grep -owE "$webPageFileRegExp")"
           [ -n "$webPageTemp" ] && webPageFile="$webPageTemp"
       fi
   fi

   for index in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
   do
       webPageTemp="user${index}.asp"
       webPagePath="${SHARED_WEB_DIR}/$webPageTemp"

       if [ -f "$webPagePath" ] && \
          [ "$(md5sum < "$1")" = "$(md5sum < "$webPagePath")" ]
       then
           webPageFile="$webPageTemp"
           break
       elif [ "$webPageFile" = "NONE" ] && [ ! -f "$webPagePath" ]
       then
           webPageFile="$webPageTemp"
       fi
   done
   echo "$webPageFile"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-11] ##
##----------------------------------------##
_Mount_WebUI_()
{
   if [ ! -f "$SCRIPT_WEB_ASP_PATH" ]
   then
       Say "${CRITct}**ERROR**${NOct}: The WebUI page file for $SCRIPT_NAME is NOT found."
       return 1
   fi
   local webPageFile

   Say "Mounting WebUI page for $SCRIPT_NAME"

   eval exec "$WEBUI_LOCKFD>$WEBUI_LOCKFILE"
   flock -x "$WEBUI_LOCKFD"

   webPageFile="$(_GetWebUIPage_ "$SCRIPT_WEB_ASP_PATH")"
   if [ -z "$webPageFile" ] || [ "$webPageFile" = "NONE" ]
   then
       Say "${CRITct}**ERROR**${NOct}: Unable to mount the $SCRIPT_NAME WebUI page."
       flock -u "$WEBUI_LOCKFD"
       return 1
   fi

   cp -fp "$SCRIPT_WEB_ASP_PATH" "${SHARED_WEB_DIR}/$webPageFile"
   echo "$SCRIPT_NAME" > "${SHARED_WEB_DIR}/$(echo "$webPageFile" | cut -f1 -d'.').title"

   if [ ! -f "$TEMP_MENU_TREE" ]
   then cp -fp "$ORIG_MENU_TREE" "$TEMP_MENU_TREE" ; fi

   sed -i "/url: \"$webPageFile\", tabName: \"$SCRIPT_NAME\"/d" "$TEMP_MENU_TREE"

   # Insert new page tab in the 'Administration' menu #
   sed -i "/url: \"Advanced_FirmwareUpgrade_Content.asp\", tabName:/a {url: \"$webPageFile\", tabName: \"$SCRIPT_NAME\"}," "$TEMP_MENU_TREE"

   umount "$ORIG_MENU_TREE" 2>/dev/null
   mount -o bind "$TEMP_MENU_TREE" "$ORIG_MENU_TREE"
   flock -u "$WEBUI_LOCKFD"

   Say "${GRNct}$SCRIPT_NAME WebUI page was mounted successfully."
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-11] ##
##----------------------------------------##
_Unmount_WebUI_()
{
   if [ ! -f "$SCRIPT_WEB_ASP_PATH" ]
   then
       Say "${CRITct}**ERROR**${NOct}: The WebUI page file for $SCRIPT_NAME is NOT found."
       return 1
   fi
   local webPageFile

   Say "Unmounting WebUI page for $SCRIPT_NAME"

   eval exec "$WEBUI_LOCKFD>$WEBUI_LOCKFILE"
   flock -x "$WEBUI_LOCKFD"

   webPageFile="$(_GetWebUIPage_ "$SCRIPT_WEB_ASP_PATH")"
   if [ -z "$webPageFile" ] || [ "$webPageFile" = "NONE" ]
   then
       Say "WebUI page file for $SCRIPT_NAME is NOT found to uninstall."
       flock -u "$WEBUI_LOCKFD"
       return 1
   fi

   if [ -f "$TEMP_MENU_TREE" ]
   then
       sed -i "/url: \"$webPageFile\", tabName: \"$SCRIPT_NAME\"/d" "$TEMP_MENU_TREE"
   fi
   rm -f "${SHARED_WEB_DIR}/$webPageFile"
   rm -f "${SHARED_WEB_DIR}/$(echo "$webPageFile" | cut -f1 -d'.').title"

   umount "$ORIG_MENU_TREE" 2>/dev/null
   mount -o bind "$TEMP_MENU_TREE" "$ORIG_MENU_TREE"
   flock -u "$WEBUI_LOCKFD"

   Say "${GRNct}$SCRIPT_NAME WebUI page unmounted successfully."
   /sbin/service restart_httpd >/dev/null 2>&1 &
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-12] ##
##----------------------------------------##
_AutoStartupHook_()
{
   local theScriptNameTag="#${SCRIPT_NAME}#"
   local theHookScriptFile="${SCRIPTS_PATH}/services-start"
   local theScriptFilePath="${SCRIPTS_PATH}/${SCRIPT_NAME}.sh"

   case "$1" in
       create)
           if [ -f "$theHookScriptFile" ]
           then
               theLineCount="$(grep -c "$theScriptNameTag" "$theHookScriptFile")"
               theLineCountEx="$(grep -cx '\[ -x '"$theScriptFilePath"' \] && '"$theScriptFilePath"' startup "$@" & '"$theScriptNameTag" "$theHookScriptFile")"

               if [ "$theLineCount" -gt 1 ] || { [ "$theLineCountEx" -eq 0 ] && [ "$theLineCount" -gt 0 ] ; }
               then
                    sed -i "/${theScriptNameTag}/d" "$theHookScriptFile"
               fi
               if [ "$theLineCountEx" -eq 0 ]
               then
                  {
                    echo '[ -x '"$theScriptFilePath"' ] && '"$theScriptFilePath"' startup "$@" & '"$theScriptNameTag"
                  } >> "$theHookScriptFile"
               fi
           else
              {
                echo "#!/bin/sh" ; echo
                echo '[ -x '"$theScriptFilePath"' ] && '"$theScriptFilePath"' startup "$@" & '"$theScriptNameTag"
                echo
              } > "$theHookScriptFile"
           fi
           chmod 755 "$theHookScriptFile"
           ;;
       delete)
           if [ -f "$theHookScriptFile" ] && \
              { grep -q "$theScriptNameTag" "$theHookScriptFile" || \
                grep -q "$theScriptFilePath" "$theHookScriptFile" ; }
           then
               theFixedPath="$(echo "$theScriptFilePath" | sed 's/[\/.]/\\&/g')"
               sed -i "/${theScriptNameTag}/d" "$theHookScriptFile"
               sed -i "/$theFixedPath startup/d" "$theHookScriptFile"
           fi
           ;;
   esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-12] ##
##----------------------------------------##
_AutoServiceEvent_()
{
   local theScriptNameTag="#${SCRIPT_NAME}#"
   local theHookScriptFile="${SCRIPTS_PATH}/service-event"
   local theScriptFilePath="${SCRIPTS_PATH}/${SCRIPT_NAME}.sh"

   case "$1" in
       create)
           if [ -f "$theHookScriptFile" ]
           then
               theLineCount="$(grep -c "$theScriptNameTag" "$theHookScriptFile")"
               theLineCountEx="$(grep -cx 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" ; then { '"$theScriptFilePath"' service_event "$@" & }; fi '"$theScriptNameTag" "$theHookScriptFile")"

               if [ "$theLineCount" -gt 1 ] || { [ "$theLineCountEx" -eq 0 ] && [ "$theLineCount" -gt 0 ]; }
               then
                   sed -i "/${theScriptNameTag}/d" "$theHookScriptFile"
               fi
               if [ "$theLineCountEx" -eq 0 ]
               then
                  {
                    echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" ; then { '"$theScriptFilePath"' service_event "$@" & }; fi '"$theScriptNameTag"
                  } >> "$theHookScriptFile"
               fi
           else
              {
                echo "#!/bin/sh" ; echo
                echo 'if echo "$2" | /bin/grep -q "'"$SCRIPT_NAME"'" ; then { '"$theScriptFilePath"' service_event "$@" & }; fi '"$theScriptNameTag"
                echo
              } > "$theHookScriptFile"
           fi
           chmod 755 "$theHookScriptFile"
           ;;
       delete)
           if [ -f "$theHookScriptFile" ] && \
              { grep -q "$theScriptNameTag" "$theHookScriptFile" || \
                grep -q "$theScriptFilePath" "$theHookScriptFile" ; }
           then
               theFixedPath="$(echo "$theScriptFilePath" | sed 's/[\/.]/\\&/g')"
               sed -i "/${theScriptNameTag}/d" "$theHookScriptFile"
               sed -i "/$theFixedPath service_event/d" "$theHookScriptFile"
           fi
           ;;
   esac
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_SetVersionSharedSettings_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE "^(local|server|delete)$"
   then return 1; fi

   if [ "$1" = "delete" ]
   then
       if [ -f "$SHARED_SETTINGS_FILE" ]
       then
           if grep -q "^MerlinAU_version_" "$SHARED_SETTINGS_FILE"
           then
               sed -i "/^MerlinAU_version_local/d" "$SHARED_SETTINGS_FILE"
               sed -i "/^MerlinAU_version_server/d" "$SHARED_SETTINGS_FILE"
           fi
       fi
       return 0
   fi
   if [ $# -lt 2 ] || [ -z "$2" ] ; then return 1; fi

   local versionTypeStr=""
   [ "$1" = "local" ] && versionTypeStr="MerlinAU_version_local"
   [ "$1" = "server" ] && versionTypeStr="MerlinAU_version_server"

   if [ -f "$SHARED_SETTINGS_FILE" ]
   then
       if grep -q "^${versionTypeStr}.*" "$SHARED_SETTINGS_FILE"
       then
           if [ "$2" != "$(grep "^$versionTypeStr" "$SHARED_SETTINGS_FILE" | cut -f2 -d' ')" ]
           then
               sed -i "s/^${versionTypeStr}.*/$versionTypeStr $2/" "$SHARED_SETTINGS_FILE"
           fi
       else
           echo "$versionTypeStr $2" >> "$SHARED_SETTINGS_FILE"
       fi
   else
      echo "$versionTypeStr $2" > "$SHARED_SETTINGS_FILE"
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_CreateDirPaths_()
{
   if [ ! -d "$SETTINGS_DIR" ]
   then
      mkdir -p "$SETTINGS_DIR"
      chmod 755 "$SETTINGS_DIR"
   fi
   if [ ! -d "$SCRIPT_WEB_DIR" ]
   then
      mkdir -p "$SCRIPT_WEB_DIR"
      chmod 775 "$SCRIPT_WEB_DIR"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
_CreateSymLinks_()
{
   rm -rf "${SCRIPT_WEB_DIR:?}/"* 2>/dev/null
   ln -s "$CONFIG_FILE" "${SCRIPT_WEB_DIR}/config.htm" 2>/dev/null
   ln -s "$HELPER_JSFILE" "${SCRIPT_WEB_DIR}/CheckHelper.js" 2>/dev/null
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_InitHelperJSFile_()
{
   [ -s "$HELPER_JSFILE" ] && return 0 
   {
     echo "var externalCheckID = 0x00;"
     echo "var externalCheckOK = true;"
     echo "var externalCheckMsg = '';"
   } > "$HELPER_JSFILE"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_UpdateHelperJSFile_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1; fi

   local extCheckMsg=""
   if [ $# -eq 3 ] && [ -n "$3" ]
   then extCheckMsg="$3" ; fi

   {
     echo "var externalCheckID = ${1};"
     echo "var externalCheckOK = ${2};"
     echo "var externalCheckMsg = '${extCheckMsg}';"
   } > "$HELPER_JSFILE"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_ActionsAfterNewConfigSettings_()
{
   if [ ! -s "${CONFIG_FILE}.bak" ] || \
      diff -q "$CONFIG_FILE" "${CONFIG_FILE}.bak" >/dev/null 2>&1
   then return 1 ; fi

   _ConfigOptionChanged_()
   {
      if diff "$CONFIG_FILE" "${CONFIG_FILE}.bak" | grep -q "$1"
      then return 0
      else return 1
      fi
   }
   local ccNewEmailAddr  ccNewEmailName  newScriptAUpdateVal

   if _ConfigOptionChanged_ "FW_New_Update_EMail_CC_Address="
   then
       ccNewEmailAddr="$(Get_Custom_Setting FW_New_Update_EMail_CC_Address)"
       ccNewEmailName="${ccNewEmailAddr%%@*}"
       Update_Custom_Settings FW_New_Update_EMail_CC_Name "$ccNewEmailName"
   fi
   if _ConfigOptionChanged_ "FW_New_Update_Postponement_Days="
   then
       _Calculate_NextRunTime_
   fi
   if _ConfigOptionChanged_ "Allow_Script_Auto_Update"
   then
       ScriptAutoUpdateSetting="$(Get_Custom_Setting Allow_Script_Auto_Update)"
       if [ "$ScriptAutoUpdateSetting" = "DISABLED" ]
       then
           _DelScriptAutoUpdateHook_
           _DelScriptAutoUpdateCronJob_
       elif [ "$ScriptAutoUpdateSetting" = "ENABLED" ]
       then
           scriptUpdateCronSched="$(_GetScriptAutoUpdateCronSchedule_)"
           if _ValidateCronJobSchedule_ "$scriptUpdateCronSched"
           then
              _AddScriptAutoUpdateCronJob_ && _AddScriptAutoUpdateHook_
           fi
       fi
   fi
   if _ConfigOptionChanged_ "CheckChangeLog"
   then
       currentChangelogValue="$(Get_Custom_Setting CheckChangeLog)"
       if [ "$currentChangelogValue" = "DISABLED" ]
       then
           Delete_Custom_Settings "FW_New_Update_Changelog_Approval"
       elif [ "$currentChangelogValue" = "ENABLED" ]
       then
           Update_Custom_Settings FW_New_Update_Changelog_Approval TBD
       fi
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-16] ##
##----------------------------------------##
_UpdateConfigFromWebUISettings_()
{
   [ ! -f "$SHARED_SETTINGS_FILE" ] && return 1

   local settingsMergeOK=true  logMsgTag="with errors."

   # Check for 'MerlinAU_' entries excluding 'version' #
   if [ "$(grep "^MerlinAU_" "$SHARED_SETTINGS_FILE" | grep -v "_version" -c)" -gt 0 ]
   then
       Say "Updated settings from WebUI found, merging into $CONFIG_FILE"
       cp -a "$CONFIG_FILE" "${CONFIG_FILE}.bak"

       # Extract 'MerlinAU_' entries excluding 'version' #
       grep "^MerlinAU_" "$SHARED_SETTINGS_FILE" | grep -v "_version" > "$TEMPFILE"
       sed -i "s/^MerlinAU_//g;s/ /=/g" "$TEMPFILE"

       while IFS='' read -r line || [ -n "$line" ]
       do
           keySettingName="$(echo "$line" | cut -f1 -d'=')"
           keySettingValue="$(echo "$line" | cut -f2- -d'=')"

           if [ "$keySettingName" = "FW_New_Update_ZIP_Directory_Path" ]
           then
               if _Validate_FW_UpdateZIP_DirectoryPath_ "$keySettingValue" true
               then
                   Say "Directory path [$keySettingValue] was updated successfully."
               else
                   settingsMergeOK=false
                   Say "**ERROR**: Could NOT update directory path [$keySettingValue]"
               fi
               continue
           fi
           Update_Custom_Settings "$keySettingName" "$keySettingValue"
       done < "$TEMPFILE"

       # Extract 'MerlinAU_version_*' separately (if found) #
       grep '^MerlinAU_version_.*' "$SHARED_SETTINGS_FILE" > "$TEMPFILE"
       # Now remove all 'MerlinAU_*' entries #
       sed -i "/^MerlinAU_.*/d" "$SHARED_SETTINGS_FILE"

       # Reconstruct the shared settings file #
       mv -f "$SHARED_SETTINGS_FILE" "${SHARED_SETTINGS_FILE}.bak"
       cat "${SHARED_SETTINGS_FILE}.bak" "$TEMPFILE" > "$SHARED_SETTINGS_FILE"
       rm -f "$TEMPFILE" "${SHARED_SETTINGS_FILE}.bak"

       _ActionsAfterNewConfigSettings_

       "$settingsMergeOK" && logMsgTag="successfully."
       Say "Merge of updated settings from WebUI was completed ${logMsgTag}"

       if ! "$settingsMergeOK"
       then  ## Reset for Next Check ##
           { sleep 10 ; _UpdateHelperJSFile_ 0x01 "true" ; } &
       fi
   else
       Say "No updated settings from WebUI found. No merge into $CONFIG_FILE necessary."
   fi
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Dec-31] ##
##-------------------------------------##
newGUIversionNum="$(_ScriptVersionStrToNum_ '1.4.0')"
# Temporary code used to migrate to future new script version #
_CheckForNewGUIVersionUpdate_()
{
   local retCode  theScriptVerNum   urlScriptVerNum
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then
       theScriptVerNum="$ScriptVersionNum"
       urlScriptVerNum="$DLRepoVersionNum"
   else
       theScriptVerNum="$(_ScriptVersionStrToNum_ "$1")"
       urlScriptVerNum="$(_ScriptVersionStrToNum_ "$2")"
   fi
   if [ "$theScriptVerNum" -lt "$newGUIversionNum" ] && \
      [ "$urlScriptVerNum" -ge "$newGUIversionNum" ]
   then retCode=0
   else retCode=1
   fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-11] ##
##----------------------------------------##
_CurlFileDownload_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1 ; fi
   local retCode=1
   local tempFilePathDL="${2}.DL.TMP"
   local srceFilePathDL="${SCRIPT_URL_REPO}/$1"

   curl -LSs --retry 4 --retry-delay 5 --retry-connrefused \
        "$srceFilePathDL" -o "$tempFilePathDL"
   if [ $? -ne 0 ] || [ ! -s "$tempFilePathDL" ] || \
      grep -iq "^404: Not Found" "$tempFilePathDL"
   then
       rm -f "$tempFilePathDL"
       retCode=1
   else
       if [ "$1" = "$SCRIPT_WEB_ASP_FILE" ] && \
          [ -f "$2" ] && [ -f "$TEMP_MENU_TREE" ] && \
          ! diff -q "$tempFilePathDL" "$2" >/dev/null 2>&1
       then updatedWebUIPage=true
       else updatedWebUIPage=false
       fi
       mv -f "$tempFilePathDL" "$2"
       retCode=0
   fi

   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-11] ##
##----------------------------------------##
_DownloadScriptFiles_()
{
   local retCode  isUpdateAction  updatedWebUIPage  theWebPage

   if [ $# -gt 0 ] && [ "$1" = "update" ]
   then isUpdateAction=true
   else isUpdateAction=false
   fi
   updatedWebUIPage=false

   if _CurlFileDownload_ "version.txt" "$SCRIPT_VERPATH"
   then
       retCode=0 ; chmod 664 "$SCRIPT_VERPATH"
   else
       retCode=1
       Say "${REDct}**ERROR**${NOct}: Unable to download latest version file for $SCRIPT_NAME."
   fi
   if _CurlFileDownload_ "$SCRIPT_WEB_ASP_FILE" "$SCRIPT_WEB_ASP_PATH"
   then
       chmod 664 "$SCRIPT_WEB_ASP_PATH"
       if "$inRouterSWmode" && "$updatedWebUIPage"
       then
           theWebPage="$(_GetWebUIPage_ "$SCRIPT_WEB_ASP_PATH")"
           if [ -n "$theWebPage" ] && [ "$theWebPage" != "NONE" ]
           then
               sed -i "/url: \"$theWebPage\", tabName: \"$SCRIPT_NAME\"/d" "$TEMP_MENU_TREE"
               rm -f "${SHARED_WEB_DIR}/$theWebPage"
               rm -f "${SHARED_WEB_DIR}/$(echo "$theWebPage" | cut -f1 -d'.').title"
           fi
           "$isUpdateAction" && _Mount_WebUI_
       fi
       retCode=0
   else
       retCode=1
       Say "${REDct}**ERROR**${NOct}: Unable to download latest WebUI ASP file for $SCRIPT_NAME."
   fi
   if _CurlFileDownload_ "${SCRIPT_NAME}.sh" "$ScriptFilePath"
   then
       retCode=0 ; chmod 755 "$ScriptFilePath"
   else
       retCode=1
       Say "${REDct}**ERROR**${NOct}: Unable to download latest script file for $SCRIPT_NAME."
   fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-11] ##
##----------------------------------------##
_SCRIPT_UPDATE_()
{
   local urlScriptVers  theScriptVers  extraParam=""

   if [ $# -gt 0 ] && [ "$1" = "force" ]
   then
       printf "\n${CYANct}Force downloading latest script version...${NOct}\n"
       theScriptVers="$SCRIPT_VERSION"
       [ -s "$SCRIPT_VERPATH" ] && theScriptVers="$(cat "$SCRIPT_VERPATH")"
       urlScriptVers="$(/usr/sbin/curl -LSs --retry 4 --retry-delay 5 "${SCRIPT_URL_REPO}/version.txt")"
       printf "${CYANct}Downloading latest version ($urlScriptVers) of ${SCRIPT_NAME}${NOct}\n"

       if _DownloadScriptFiles_ update
       then
           printf "${CYANct}$SCRIPT_NAME files were successfully updated.${NOct}\n\n"
           [ -s "$SCRIPT_VERPATH" ] && urlScriptVers="$(cat "$SCRIPT_VERPATH")"
           if "$inRouterSWmode"
           then
               _SetVersionSharedSettings_ local "$urlScriptVers"
               _SetVersionSharedSettings_ server "$urlScriptVers"
           fi
           sleep 1
           if [ $# -gt 1 ] && [ "$2" = "newgui" ] && \
              _CheckForNewGUIVersionUpdate_ "$theScriptVers" "$urlScriptVers"
           then extraParam="install" ; fi
           _ReleaseLock_
           exec "$ScriptFilePath" $extraParam
           exit 0
       fi
       return 0
   fi

   ! _CheckForNewScriptUpdates_ && return 1

   clear
   _ShowLogo_

   printf "\n${YLWct}Script Update Utility${NOct}\n\n"
   printf "${CYANct}Version Currently Installed:  ${YLWct}${SCRIPT_VERSION}${NOct}\n"
   printf "${CYANct}Update Version Available Now: ${YLWct}${DLRepoVersion}${NOct}\n\n"

   if "$inRouterSWmode"
   then _SetVersionSharedSettings_ server "$DLRepoVersion" ; fi

   if [ "$SCRIPT_VERSION" = "$DLRepoVersion" ]
   then
      echo -e "${CYANct}You are on the latest version! Would you like to download anyways?${NOct}"
      echo -e "${CYANct}This will overwrite your currently installed version.${NOct}"
      if _WaitForYESorNO_
      then
          printf "\n\n${CYANct}Downloading $SCRIPT_NAME $DLRepoVersion version.${NOct}\n"

          if _DownloadScriptFiles_ update
          then
              if "$inRouterSWmode"
              then _SetVersionSharedSettings_ local "$DLRepoVersion" ; fi
              printf "\n${CYANct}Download successful!${NOct}\n"
              printf "$(date) - Successfully downloaded $SCRIPT_NAME v${DLRepoVersion}\n"
          fi
          _WaitForEnterKey_
          return
      else
          printf "\n\n${GRNct}Exiting Script Update Utility...${NOct}\n"
          sleep 1
          return
      fi
   elif [ "$scriptUpdateNotify" != "0" ]
   then
      echo -e "${CYANct}Bingo! New version available! Would you like to update now?${NOct}"
      if _WaitForYESorNO_
      then
          printf "\n\n${CYANct}Downloading $SCRIPT_NAME $DLRepoVersion version.${NOct}\n"

          if _DownloadScriptFiles_ update
          then
              if "$inRouterSWmode"
              then _SetVersionSharedSettings_ local "$DLRepoVersion" ; fi
              printf "\n$(date) - Successfully downloaded $SCRIPT_NAME v${DLRepoVersion}\n"
              printf "${CYANct}Update successful! Restarting script...${NOct}\n"
              sleep 1
              _CheckForNewGUIVersionUpdate_ && extraParam="install"
              _ReleaseLock_
              exec "$ScriptFilePath" $extraParam
              exit 0
          else
              _WaitForEnterKey_
              return
          fi
      else
          printf "\n\n${GRNct}Exiting Script Update Utility...${NOct}\n"
          sleep 1
          return
      fi
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-11] ##
##----------------------------------------##
_CheckForNewScriptUpdates_()
{
   local extraParam=""

   echo
   DLRepoVersion="$SCRIPT_VERSION"
   [ -s "$SCRIPT_VERPATH" ] && DLRepoVersion="$(cat "$SCRIPT_VERPATH")"
   rm -f "$SCRIPT_VERPATH"

   if ! _CurlFileDownload_ "version.txt" "$SCRIPT_VERPATH"
   then
       Say "${REDct}**ERROR**${NOct}: Unable to download latest version file for $SCRIPT_NAME."
       scriptUpdateNotify=0
       return 1
   fi

   DLRepoVersion="$(cat "$SCRIPT_VERPATH")"
   if [ -z "$DLRepoVersion" ]
   then
       Say "${REDct}**ERROR**${NOct}: Variable for downloaded version is empty."
       scriptUpdateNotify=0
       return 1
   fi

   DLRepoVersionNum="$(_ScriptVersionStrToNum_ "$DLRepoVersion")"
   ScriptVersionNum="$(_ScriptVersionStrToNum_ "$SCRIPT_VERSION")"

   if [ "$DLRepoVersionNum" -gt "$ScriptVersionNum" ]
   then
       scriptUpdateNotify="New script update available.
${REDct}v${SCRIPT_VERSION}${NOct} --> ${GRNct}v${DLRepoVersion}${NOct}"
       Say "$myLAN_HostName - A new script version update (v$DLRepoVersion) is available to download."
       if [ "$ScriptAutoUpdateSetting" = "ENABLED" ]
       then
           _CheckForNewGUIVersionUpdate_ && extraParam="newgui"
           _SCRIPT_UPDATE_ force $extraParam
       fi
   else
       scriptUpdateNotify=0
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------##
_GetLatestFWUpdateVersionFromRouter_()
{
   local retCode=0  webState  newVersionStr

   webState="$(nvram get webs_state_flag)"
   if [ -z "$webState" ] || [ "$webState" -eq 0 ]
   then retCode=1 ; fi

   newVersionStr="$(nvram get webs_state_info | sed 's/_/./g')"
   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       newVersionStr="$(echo "$newVersionStr" | awk -F '-' '{print $1}')"
   fi

   [ -z "$newVersionStr" ] && retCode=1
   echo "$newVersionStr" ; return "$retCode"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-28] ##
##------------------------------------------##
_CreateEMailContent_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local fwInstalledVersion  fwNewUpdateVersion
   local savedInstalledVersion  savedNewUpdateVersion
   local subjectStr  emailBodyTitle=""  release_version

   rm -f "$tempEMailContent" "$tempEMailBodyMsg"

   if [ -s "$tempNodeEMailList" ]
   then subjectStr="F/W Update Status for $node_lan_hostname"
   else subjectStr="F/W Update Status for $MODEL_ID"
   fi
   fwInstalledVersion="$(_GetCurrentFWInstalledLongVersion_)"
   if ! "$offlineUpdateTrigger"
   then
        fwNewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
   else
        fwNewUpdateVersion="$(Get_Custom_Setting "FW_New_Update_Notification_Vers")"
   fi

   # Remove "_rog" or "_tuf" or -gHASHVALUES or -Gnuton* suffix to avoid version comparison failure, can't remove all for proper beta and alpha comparison #
   fwInstalledVersion="$(echo "$fwInstalledVersion" | sed -E 's/(_(rog|tuf)|-g[0-9a-f]{10}|-gnuton[0-9]+)$//')"

   case "$1" in
       FW_UPDATE_TEST_EMAIL)
           emailBodyTitle="Testing Email Notification"
           {
             echo "This is a TEST of the F/W Update email notification from the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       NEW_FW_UPDATE_STATUS)
           emailBodyTitle="New Firmware Update for ASUS Router"
           {
             echo "A new F/W Update version <b>${fwNewUpdateVersion}</b> is available for the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
             printf "\nNumber of days to postpone flashing the new F/W Update version: <b>${FW_UpdatePostponementDays}</b>\n"
             printf "\nPlease click here to review the changelog:\n"
             if "$isGNUtonFW"
             then
                 printf "${GnutonChangeLogURL}\n"
             else
                 printf "${MerlinChangeLogURL}\n"
             fi
             [ "$FW_UpdateExpectedRunDate" != "TBD" ] && \
             printf "\nThe firmware update is expected to occur on: <b>${FW_UpdateExpectedRunDate}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       AGGREGATED_UPDATE_NOTIFICATION)
           if "$inRouterSWmode" && [ -n "$node_list" ]; then
              nodefwNewUpdateVersion="$(_GetLatestFWUpdateVersionFromNode_ 1)"
           fi
           if [ -z "$nodefwNewUpdateVersion" ]
           then
               Say "${REDct}**ERROR**${NOct}: Unable to send node email notification [No saved info]."
               return 1
           fi
           emailBodyTitle="New Firmware Update(s) for AiMesh Node(s)"
           NODE_UPDATE_CONTENT="$(cat "$tempNodeEMailList")"
           {
             echo "The following AiMesh Node(s) have a new F/W Update version available:"
             echo "$NODE_UPDATE_CONTENT"
           } > "$tempEMailBodyMsg"
           ;;
       START_FW_UPDATE_STATUS)
           emailBodyTitle="New Firmware Flash Started"
           {
             echo "Started flashing the new F/W Update version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       STOP_FW_UPDATE_APPROVAL)
           emailBodyTitle="WARNING"
           if "$isEMailFormatHTML"
           then
               # Highlight high-risk terms using HTML with a yellow background #
               highlighted_changelog_contents="$(echo "$changelog_contents" | sed -E "s/($high_risk_terms)/<span style='background-color:yellow;'>\1<\/span>/gi")"
           else
               # Step 1: Enclose matched terms with unique markers that don't conflict with '>' and '<'
               highlighted_changelog_contents="$(echo "$changelog_contents" | sed -E "s/($high_risk_terms)/\[\[UPPER\]\]\1\[\[ENDUPPER\]\]/gi")"

               # Step 2: Modify the awk script with correct marker lengths
               highlighted_changelog_contents="$(echo "$highlighted_changelog_contents" | awk '
               BEGIN {
                   upper_marker = "[[UPPER]]"
                   endupper_marker = "[[ENDUPPER]]"
                   upper_marker_length = length(upper_marker)
                   endupper_marker_length = length(endupper_marker)
               }
               {
                 while (match($0, /\[\[UPPER\]\][^\[]*\[\[ENDUPPER\]\]/)) {
                   prefix = substr($0, 1, RSTART - 1)
                   match_text_start = RSTART + upper_marker_length
                   match_text_length = RLENGTH - upper_marker_length - endupper_marker_length
                   match_text = substr($0, match_text_start, match_text_length)
                   suffix = substr($0, RSTART + RLENGTH)
                   match_text_upper = toupper(match_text)
                   $0 = prefix ">" match_text_upper "<" suffix
                 }
                 print
               }
               ')"
           fi
           {
               echo "Found high-risk phrases in the changelog file while Auto-Updating to version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
               echo "Changelog contents include the following changes:"
               echo "$highlighted_changelog_contents"
               printf "\nPlease run script interactively to approve this F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       NEW_BM_BACKUP_FAILED)
           emailBodyTitle="WARNING"
           {
             echo "Backup failed during the F/W Update process to version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             echo "Flashing the F/W Update on the <b>${MODEL_ID}</b> router is now cancelled."
             printf "\nPlease check <b>backupmon.sh</b> configuration and retry F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       FAILED_FW_UNZIP_STATUS)
           emailBodyTitle="**ERROR**"
           {
             echo "Unable to decompress the F/W Update ZIP file for version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             echo "Flashing the F/W Update on the <b>${MODEL_ID}</b> router is now cancelled due to decompress error."
             printf "\nPlease retry F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       FAILED_FW_CHECKSUM_STATUS)
           emailBodyTitle="**ERROR**"
           {
             echo "Checksum verification failed during the F/W Update process to version <b>${fwNewUpdateVersion}</b> on the <b>${MODEL_ID}</b> router."
             echo "Flashing the F/W Update on the <b>${MODEL_ID}</b> router is now cancelled due to checksum mismatch."
             printf "\nPlease retry F/W Update from current version:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       FAILED_FW_UPDATE_STATUS)
           emailBodyTitle="**ERROR**"
           {
             echo "Flashing of new F/W Update version <b>${fwNewUpdateVersion}</b> for the <b>${MODEL_ID}</b> router failed."
             printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
           } > "$tempEMailBodyMsg"
           ;;
       POST_REBOOT_FW_UPDATE_SETUP)
           {
              echo "FW_InstalledVersion=$fwInstalledVersion"
              echo "FW_NewUpdateVersion=$fwNewUpdateVersion"
           } > "$saveEMailInfoMsg"
           _AddPostUpdateEmailNotifyScriptHook_
           return 0
           ;;
       POST_REBOOT_FW_UPDATE_STATUS)
           if [ ! -f "$saveEMailInfoMsg" ]
           then
               Say "${REDct}**ERROR**${NOct}: Unable to send post-update email notification [No saved info file]."
               return 1
           fi
           savedInstalledVersion="$(grep "^FW_InstalledVersion=" "$saveEMailInfoMsg" | awk -F '=' '{print $2}')"
           savedNewUpdateVersion="$(grep "^FW_NewUpdateVersion=" "$saveEMailInfoMsg" | awk -F '=' '{print $2}')"
           if [ -z "$savedInstalledVersion" ] || [ -z "$savedNewUpdateVersion" ]
           then
               Say "${REDct}**ERROR**${NOct}: Unable to send post-update email notification [Saved info is empty]."
               return 1
           fi
           if [ "$savedNewUpdateVersion" = "$fwInstalledVersion" ]
           then
              emailBodyTitle="Successful Firmware Update"
              {
                echo "Flashing of new F/W Update version <b>${fwInstalledVersion}</b> for the <b>${MODEL_ID}</b> router was successful."
                printf "\nThe F/W version that was previously installed:\n<b>${savedInstalledVersion}</b>\n"
              } > "$tempEMailBodyMsg"
           else
              emailBodyTitle="**ERROR**"
              {
                echo "Flashing of new F/W Update version <b>${savedNewUpdateVersion}</b> for the <b>${MODEL_ID}</b> router failed."
                printf "\nThe F/W version that is currently installed:\n<b>${fwInstalledVersion}</b>\n"
              } > "$tempEMailBodyMsg"
           fi
           rm -f "$saveEMailInfoMsg"
           ;;
       *) return 1
           ;;
   esac

   ! "$isEMailFormatHTML" && sed -i 's/[<]b[>]//g ; s/[<]\/b[>]//g' "$tempEMailBodyMsg"

   if [ -n "$CC_NAME" ] && [ -n "$CC_ADDRESS" ]
   then
       CC_ADDRESS_ARG="--mail-rcpt $CC_ADDRESS"
       CC_ADDRESS_STR="\"${CC_NAME}\" <$CC_ADDRESS>"
   fi

   ## Header-1 ##
   cat <<EOF > "$tempEMailContent"
From: "$FROM_NAME" <$FROM_ADDRESS>
To: "$TO_NAME" <$TO_ADDRESS>
EOF

   [ -n "$CC_ADDRESS_STR" ] && \
   printf "Cc: %s\n" "$CC_ADDRESS_STR" >> "$tempEMailContent"

   ## Header-2 ##
   cat <<EOF >> "$tempEMailContent"
Subject: $subjectStr
Date: $(date -R)
EOF

   if "$isEMailFormatHTML"
   then
       cat <<EOF >> "$tempEMailContent"
MIME-Version: 1.0
Content-Type: text/html; charset="UTF-8"
Content-Disposition: inline

<!DOCTYPE html><html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head>
<body><h2>${emailBodyTitle}</h2>
<div style="color:black; font-family: sans-serif; font-size:130%;"><pre>
EOF
    else
        cat <<EOF >> "$tempEMailContent"
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: quoted-printable
Content-Disposition: inline

EOF
       [ -n "$emailBodyTitle" ] && \
       printf "%s\n\n" "$emailBodyTitle" >> "$tempEMailContent"
   fi

   ## Body ##
   cat "$tempEMailBodyMsg" >> "$tempEMailContent"

   ## Footer ##
   if "$isEMailFormatHTML"
   then
       cat <<EOF >> "$tempEMailContent"

Sent by the "<b>${ScriptFNameTag}</b>" utility.
From the "<b>${FRIENDLY_ROUTER_NAME}</b>" router.

$(date +"$theEMailDateTimeFormat")
</pre></div></body></html>
EOF
   else
       cat <<EOF >> "$tempEMailContent"

Sent by the "${ScriptFNameTag}" utility.
From the "${FRIENDLY_ROUTER_NAME}" router.

$(date +"$theEMailDateTimeFormat")
EOF
   fi

   rm -f "$tempEMailBodyMsg"
   rm -f "$tempNodeEMailList"
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-10] ##
##----------------------------------------##
_CheckEMailConfigFileFromAMTM_()
{
   local doLogMsgs

   if [ $# -gt 0 ] && [ "$1" -eq 1 ]
   then doLogMsgs=true
   else doLogMsgs=false
   fi

   isEMailConfigEnabledInAMTM=false

   if [ ! -f "$amtmMailConfFile" ] || [ ! -f "$amtmMailPswdFile" ]
   then
       "$doLogMsgs" && \
       Say "${REDct}**ERROR**${NOct}: Unable to send email notification [No config file]."
       return 1
   fi

   FROM_NAME=""  TO_NAME=""  FROM_ADDRESS=""  TO_ADDRESS=""
   USERNAME=""  SMTP=""  PORT=""  PROTOCOL=""
   PASSWORD=""  emailPwEnc=""

   # Custom Options ##
   CC_NAME=""  CC_ADDRESS=""

   . "$amtmMailConfFile"

   if [ -z "$TO_NAME" ] || [ -z "$USERNAME" ] || \
      [ -z "$FROM_ADDRESS" ] || [ -z "$TO_ADDRESS" ] || \
      [ -z "$SMTP" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] || \
      [ -z "$emailPwEnc" ] || [ "$PASSWORD" = "PUT YOUR PASSWORD HERE" ]
   then
       "$doLogMsgs" && \
       Say "${REDct}**ERROR**${NOct}: Unable to send email notification [Empty variables]."
       return 1
   fi

   sendEMail_CC_Name="$(Get_Custom_Setting FW_New_Update_EMail_CC_Name)"
   sendEMail_CC_Address="$(Get_Custom_Setting FW_New_Update_EMail_CC_Address)"
   sendEMailNotificationsFlag="$(Get_Custom_Setting FW_New_Update_EMail_Notification)"
   sendEMailFormaType="$(Get_Custom_Setting FW_New_Update_EMail_FormatType)"
   if [ "$sendEMailFormaType" = "HTML" ]
   then isEMailFormatHTML=true
   else isEMailFormatHTML=false
   fi

   if [ -n "$sendEMail_CC_Name" ] && [ "$sendEMail_CC_Name" != "TBD" ] && \
      [ -n "$sendEMail_CC_Address" ] && [ "$sendEMail_CC_Address" != "TBD" ]
   then
       [ -z "$CC_NAME" ] && CC_NAME="$sendEMail_CC_Name"
       [ -z "$CC_ADDRESS" ] && CC_ADDRESS="$sendEMail_CC_Address"
   fi

   isEMailConfigEnabledInAMTM=true
   return 0
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-21] ##
##------------------------------------------##
_SendEMailNotification_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]  || \
   [ "$sendEMailNotificationsFlag" != "ENABLED" ] || \
   ! _CheckEMailConfigFileFromAMTM_ 1
   then return 1 ; fi

   local CC_ADDRESS_STR=""  CC_ADDRESS_ARG=""

   [ -z "$FROM_NAME" ] && FROM_NAME="$ScriptFNameTag"
   [ -z "$FRIENDLY_ROUTER_NAME" ] && FRIENDLY_ROUTER_NAME="$MODEL_ID"

   ! _CreateEMailContent_ "$1" && return 1

   [ "$1" = "POST_REBOOT_FW_UPDATE_SETUP" ] && return 0

   if "$isInteractive"
   then
       printf "\nSending email notification [$1]."
       printf "\nPlease wait...\n"
   fi

   _UserTraceLog_ "SENDING email notification..."

   curl -Lv --retry 4 --retry-delay 5 --url "${PROTOCOL}://${SMTP}:${PORT}" \
   --mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" $CC_ADDRESS_ARG \
   --user "${USERNAME}:$(/usr/sbin/openssl aes-256-cbc "$emailPwEnc" -d -in "$amtmMailPswdFile" -pass pass:ditbabot,isoi)" \
   --upload-file "$tempEMailContent" \
   $SSL_FLAG --ssl-reqd --crlf >> "$userTraceFile" 2>&1
   curlCode="$?"

   if [ "$curlCode" -eq 0 ]
   then
       sleep 2
       rm -f "$userTraceFile"
       Say "The email notification was sent successfully [$1]."
   else
       Say "${REDct}**ERROR**${NOct}: Failure to send email notification [Code: $curlCode][$1]."
   fi
   rm -f "$tempEMailContent"

   return "$curlCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jul-31] ##
##----------------------------------------##
# Directory for downloading & extracting firmware #
_CreateDirectory_()
{
    if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

    mkdir -p "$1"
    if [ ! -d "$1" ]
    then
        Say "${REDct}**ERROR**${NOct}: Unable to create directory [$1] to download firmware."
        "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
        return 1
    fi
    if ! "$offlineUpdateTrigger"
    then
        # Clear directory in case any previous files still exist #
        rm -f "${1}"/*
    fi
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-17] ##
##----------------------------------------##
_DelPostUpdateEmailNotifyScriptHook_()
{
   local hookScriptFile

   hookScriptFile="$hookScriptFPath"
   if [ ! -f "$hookScriptFile" ] ; then return 1 ; fi

   if grep -qE "$POST_UPDATE_EMAIL_SCRIPT_JOB" "$hookScriptFile"
   then
       sed -i -e '/\/'"$ScriptFileName"' postUpdateEmail &  '"$hookScriptTagStr"'/d' "$hookScriptFile"
       if [ $? -eq 0 ]
       then
           Say "Post-update email notification hook was deleted successfully from '$hookScriptFile' script."
       fi
   else
       Say "${GRNct}Post-update email notification hook is not found in '$hookScriptFile' script.${NOct}"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-17] ##
##----------------------------------------##
_AddPostUpdateEmailNotifyScriptHook_()
{
   local hookScriptFile  jobHookAdded=false

   hookScriptFile="$hookScriptFPath"
   if [ ! -f "$hookScriptFile" ]
   then
      jobHookAdded=true
      {
        echo "#!/bin/sh"
        echo "# $hookScriptFName"
        echo "#"
        echo "$POST_UPDATE_EMAIL_SCRIPT_HOOK"
      } > "$hookScriptFile"
   #
   elif ! grep -qE "$POST_UPDATE_EMAIL_SCRIPT_JOB" "$hookScriptFile"
   then
      jobHookAdded=true
      echo "$POST_UPDATE_EMAIL_SCRIPT_HOOK" >> "$hookScriptFile"
   fi
   chmod 0755 "$hookScriptFile"

   if "$jobHookAdded"
   then Say "Post-update email notification hook was added successfully to '$hookScriptFile' script."
   else Say "Post-update email notification hook already exists in '$hookScriptFile' script."
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-17] ##
##----------------------------------------##
_DelPostRebootRunScriptHook_()
{
   local hookScriptFile

   hookScriptFile="$hookScriptFPath"
   if [ ! -f "$hookScriptFile" ] ; then return 1 ; fi

   if grep -qE "$POST_REBOOT_SCRIPT_JOB" "$hookScriptFile"
   then
       sed -i -e '/\/'"$ScriptFileName"' postRebootRun &  '"$hookScriptTagStr"'/d' "$hookScriptFile"
       if [ $? -eq 0 ]
       then
           Say "Post-reboot run hook was deleted successfully from '$hookScriptFile' script."
       fi
   else
       Say "${GRNct}Post-reboot run hook is not found in '$hookScriptFile' script.${NOct}"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-17] ##
##----------------------------------------##
_AddPostRebootRunScriptHook_()
{
   local hookScriptFile  jobHookAdded=false

   hookScriptFile="$hookScriptFPath"
   if [ ! -f "$hookScriptFile" ]
   then
      jobHookAdded=true
      {
        echo "#!/bin/sh"
        echo "# $hookScriptFName"
        echo "#"
        echo "$POST_REBOOT_SCRIPT_HOOK"
      } > "$hookScriptFile"
   #
   elif ! grep -qE "$POST_REBOOT_SCRIPT_JOB" "$hookScriptFile"
   then
      jobHookAdded=true
      echo "$POST_REBOOT_SCRIPT_HOOK" >> "$hookScriptFile"
   fi
   chmod 0755 "$hookScriptFile"

   if "$jobHookAdded"
   then Say "Post-reboot run hook was added successfully to '$hookScriptFile' script."
   else Say "Post-reboot run hook already exists in '$hookScriptFile' script."
   fi
   _WaitForEnterKey_
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-31] ##
##----------------------------------------##
_GetCurrentFWInstalledLongVersion_()
{

##FOR TESTING/DEBUG ONLY##
if false ; then echo "3004.388.6.2" ; return 0 ; fi
##FOR TESTING/DEBUG ONLY##

   local theVersionStr  extVersNum

   extVersNum="$fwInstalledExtendNum"
   echo "$extVersNum" | grep -qiE "^(alpha|beta)" && extVersNum="0_$extVersNum"
   [ -z "$extVersNum" ] && extVersNum=0

   theVersionStr="${fwInstalledBuildVers}.$extVersNum"
   [ -n "$fwInstalledBaseVers" ] && \
   theVersionStr="${fwInstalledBaseVers}.${theVersionStr}"

   echo "$theVersionStr"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-31] ##
##----------------------------------------##
_HasRouterMoreThan256MBtotalRAM_()
{
   local totalRAM_KB
   totalRAM_KB="$(awk -F ' ' '/^MemTotal:/{print $2}' /proc/meminfo)"
   [ -n "$totalRAM_KB" ] && [ "$totalRAM_KB" -gt 262144 ] && return 0
   return 1
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-01] ##
##----------------------------------------##
#---------------------------------------------------------------------#
# The actual amount of RAM that is available for any new process
# (*without* using the swap file) can be roughly estimated from
# "Free Memory" & "Page Cache" (e.g. Inactive memory pages).
# This estimate must take into account that the overall system
# (kernel + native services + tmpfs) needs a minimum amount of RAM
# to continue to work, and that not all reclaimable Page Cache can
# be reclaimed because some may actually be in used at the time.
# NOTE: [Martinski]
# Since reported "Available RAM" estimates tend to be extremely
# conservative in many cases, we decided to take another approach
# and calculate it based on the reported "Free RAM" plus ~66% of
# reported "Memory Cached" and then take the largest of the two
# values: Reported "Available RAM" vs Calculated "Available RAM"
# While still somewhat conservative, this would provide a better
# estimate, especially at the time when the router is about to
# shut down and terminate all non-critical services/processes
# before the actual F/W flash is performed.
#---------------------------------------------------------------------#
_GetAvailableRAM_KB_()
{
   local theMemAvailable_KB  theMemAvail_KB  theMemCache_KB
   local theMemFree1_KB  theMemFree2_KB  inactivePgs_KB

   _MaxNumber_() { echo "$(($1 < $2 ? $2 : $1))" ; }

   theMemCache_KB="$(awk -F ' ' '/^Cached:/{print $2}' /proc/meminfo)"
   theMemFree1_KB="$(awk -F ' ' '/^MemFree:/{print $2}' /proc/meminfo)"
   theMemAvail_KB="$(awk -F ' ' '/^MemAvailable:/{print $2}' /proc/meminfo)"
   # Assumes that only ~66% of Page Cache can be reclaimed #
   theMemFree2_KB="$((theMemFree1_KB + ((theMemCache_KB * 2) / 3)))"

   if [ -z "$theMemAvail_KB" ]
   then
       inactivePgs_KB="$(awk -F ' ' '/^Inactive:/{print $2}' /proc/meminfo)"
       theMemAvail_KB="$((theMemFree1_KB + inactivePgs_KB))"
   fi
   theMemAvailable_KB="$(_MaxNumber_ "$theMemAvail_KB" "$theMemFree2_KB")"
   echo "$theMemAvailable_KB" ; return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-31] ##
##----------------------------------------##
_GetFreeRAM_KB_()
{
   awk -F ' ' '/^MemFree:/{print $2}' /proc/meminfo
   ##FOR DEBUG ONLY## echo 1000
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jun-05] ##
##----------------------------------------##
_GetRequiredRAM_KB_()
{
    local url="$1"
    local zip_file_size_bytes  zip_file_size_kb  overhead_kb
    local total_required_kb  overhead_percentage=50

    # Size of the ZIP file in bytes
    zip_file_size_bytes="$(curl -LsI --retry 4 --retry-delay 5 "$url" | grep -i Content-Length | tail -1 | awk '{print $2}')"
    # Convert bytes to kilobytes
    zip_file_size_kb="$((zip_file_size_bytes / 1024))"

    # Calculate overhead based on the percentage
    overhead_kb="$((zip_file_size_kb * overhead_percentage / 100))"

    # Calculate total required space
    total_required_kb="$((zip_file_size_kb + overhead_kb))"
    echo "$total_required_kb"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Mar-24] ##
##----------------------------------------##
_ShutDownNonCriticalServices_()
{
    for procName in nt_center nt_monitor nt_actMail
    do
         procNum="$(ps w | grep -w "$procName" | grep -cv "grep -w")"
         if [ "$procNum" -gt 0 ]
         then
             printf "$procName: [$procNum]\n"
             killall -9 "$procName" && sleep 1
         fi
    done

    for service_name in conn_diag samba nasapps
    do
        procNum="$(ps w | grep -w "$service_name" | grep -cv "grep -w")"
        if [ "$procNum" -gt 0 ]
        then
            printf "$service_name: [$procNum]\n"
            service "stop_$service_name" && sleep 1
        fi
    done
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jan-26] ##
##------------------------------------------##
_DoCleanUp_()
{
   local delBINfiles=false  keepZIPfile=false  keepWfile=false

   local doTrace=false
   [ $# -gt 0 ] && [ "$1" -eq 0 ] && doTrace=false
   if "$doTrace"
   then
       Say "START _DoCleanUp_"
       _UserTraceLog_ "START _DoCleanUp_"
   fi

   [ $# -gt 0 ] && [ "$1" -eq 1 ] && delBINfiles=true
   [ $# -gt 1 ] && [ "$2" -eq 1 ] && keepZIPfile=true
   [ $# -gt 2 ] && [ "$3" -eq 1 ] && keepWfile=true

   # Stop the LEDs blinking #
   _Reset_LEDs_ 1

   # Check existence of files and preserve based on flags #
   local moveZIPback=false  moveWback=false

   # Move file temporarily to save it from deletion #
   "$keepZIPfile" && [ -f "$FW_ZIP_FPATH" ] && \
   mv -f "$FW_ZIP_FPATH" "${FW_ZIP_BASE_DIR}/$ScriptDirNameD" && moveZIPback=true

   if "$keepWfile" && [ -f "$FW_DL_FPATH" ]; then
       mv -f "$FW_DL_FPATH" "${FW_ZIP_BASE_DIR}/$ScriptDirNameD" && moveWback=true
   fi

   rm -f "${FW_ZIP_DIR:?}"/*
   "$delBINfiles" && rm -f "${FW_BIN_DIR:?}"/*

   # Move files back to their original location if needed #
   "$moveZIPback" && \
   mv -f "${FW_ZIP_BASE_DIR}/${ScriptDirNameD}/${FW_FileName}.zip" "$FW_ZIP_FPATH"

   "$moveWback" && \
   mv -f "${FW_ZIP_BASE_DIR}/${ScriptDirNameD}/${FW_FileName}.${extension}" "$FW_DL_FPATH"

   if "$doTrace"
   then
       Say "EXIT _DoCleanUp_"
       _UserTraceLog_ "EXIT _DoCleanUp_"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2023-Mar-26] ##
##-------------------------------------##
_LogMemoryDebugInfo_()
{
   {
     printf "Uptime\n------\n" ; uptime ; echo
     df -hT | grep -E '(^Filesystem|/jffs$|/tmp$|/var$)' | sort -d -t ' ' -k 1
     echo
     printf "/proc/meminfo\n-------------\n"
     grep -E '^Mem[TFA].*:[[:blank:]]+.*' /proc/meminfo
     grep -E '^(Buffers|Cached):[[:blank:]]+.*' /proc/meminfo
     grep -E '^Swap[TFC].*:[[:blank:]]+.*' /proc/meminfo
     grep -E '^(Active|Inactive)(\([af].*\))?:[[:blank:]]+.*' /proc/meminfo
     grep -E '^(Dirty|Writeback|AnonPages|Unevictable):[[:blank:]]+.*' /proc/meminfo
     echo "------------------------------"
   } > "$userDebugFile"
   "$isInteractive" && cat "$userDebugFile"
   _LogMsgNoTime_ "$(cat "$userDebugFile")"
   rm -f "$userDebugFile"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Mar-26] ##
##----------------------------------------##
check_memory_and_prompt_reboot()
{
    local requiredRAM_kb="$1"
    local availableRAM_kb="$2"

    if [ "$availableRAM_kb" -lt "$requiredRAM_kb" ]
    then
        Say "Insufficient RAM available."

        # Attempt to clear PageCache #
        Say "Attempting to free up memory..."
        sync; echo 1 > /proc/sys/vm/drop_caches
        sleep 2

        # Check available memory again #
        availableRAM_kb="$(_GetAvailableRAM_KB_)"
        if [ "$availableRAM_kb" -lt "$requiredRAM_kb" ]
        then
            freeRAM_kb="$(_GetFreeRAM_KB_)"
            Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
            _LogMemoryDebugInfo_

            # Attempt to clear dentries and inodes. #
            Say "Attempting to free up memory again more aggressively..."
            sync; echo 2 > /proc/sys/vm/drop_caches
            sleep 2

            # Check available memory again #
            availableRAM_kb="$(_GetAvailableRAM_KB_)"
            if [ "$availableRAM_kb" -lt "$requiredRAM_kb" ]
            then
                freeRAM_kb="$(_GetFreeRAM_KB_)"
                Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
                _LogMemoryDebugInfo_

                # Attempt to clear clears pagecache, dentries, and inodes after shutting down services
                Say "Attempting to free up memory once more even more aggressively..."

                # Stop Entware services to free some memory #
                _EntwareServicesHandler_ stop

                _ShutDownNonCriticalServices_

                sync; echo 3 > /proc/sys/vm/drop_caches
                sleep 2

                # Check available memory again #
                availableRAM_kb="$(_GetAvailableRAM_KB_)"
                if [ "$availableRAM_kb" -lt "$requiredRAM_kb" ]
                then
                    _LogMemoryDebugInfo_

                    # In an interactive shell session, ask user to confirm reboot #
                    if "$isInteractive" && _WaitForYESorNO_ "Reboot router now"
                    then
                        freeRAM_kb="$(_GetFreeRAM_KB_)"
                        Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
                        _AddPostRebootRunScriptHook_
                        Say "Rebooting router..."
                        _ReleaseLock_
                        /sbin/service reboot
                        exit 1  # Although the reboot command should end the script, it's good practice to exit after.
                    else
                        # Exit script if non-interactive or if user answers NO #
                        freeRAM_kb="$(_GetFreeRAM_KB_)"
                        Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
                        Say "Insufficient memory to continue. Exiting script."
                        # Restart Entware services #
                        _EntwareServicesHandler_ start

                        _DoCleanUp_ 1 "$keepZIPfile" "$keepWfile"
                        _DoExit_ 1
                    fi
                else
                    Say "Successfully freed up memory. Available: ${availableRAM_kb}KB."
                fi
            else
                Say "Successfully freed up memory. Available: ${availableRAM_kb}KB."
            fi
        else
            Say "Successfully freed up memory. Available: ${availableRAM_kb}KB."
        fi
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_CheckForMinimumVersionSupport_()
{
    local numOfFields  current_version  numCurrentVers  numMinimumVers
    current_version="$(_GetCurrentFWInstalledLongVersion_)"

    numOfFields="$(echo "$current_version" | awk -F '.' '{print NF}')"
    numCurrentVers="$(_FWVersionStrToNum_ "$current_version" "$numOfFields")"
    numMinimumVers="$(_FWVersionStrToNum_ "$MinSupportedFirmwareVers" "$numOfFields")"

    # Check if current F/W version is lower than the minimum supported version #
    if [ "$numCurrentVers" -lt "$numMinimumVers" ]
    then MinFirmwareVerCheckFailed=true ; fi

    "$MinFirmwareVerCheckFailed" && return 1 || return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_CheckForMinimumModelSupport_()
{
    # List of unsupported models as a space-separated string
    local unsupported_models="RT-AC87U RT-AC56U RT-AC66U RT-AC3200 RT-AC88U RT-AC5300 RT-AC3100 RT-AC68U RT-AC66U_B1 RT-AC68UF RT-AC68P RT-AC1900P RT-AC1900 RT-N66U RT-N16 DSL-AC68U"

    local current_model="$(_GetRouterProductID_)"

    # Check if current model is in the list of unsupported models #
    if echo "$unsupported_models" | grep -wq "$current_model"
    then routerModelCheckFailed=true ; fi

    "$routerModelCheckFailed" && return 1 || return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Aug-15] ##
##----------------------------------------##
_TestLoginCredentials_()
{
    local credsBase64="$1"
    local curl_response routerURLstr

    # Define routerURLstr #
    routerURLstr="$(_GetRouterURL_)"

    printf "\nRestarting web server... Please wait.\n"
    /sbin/service restart_httpd >/dev/null 2>&1 &
    sleep 5

    curl_response="$(curl -k "${routerURLstr}/login.cgi" \
    --referer "${routerURLstr}/Main_Login.asp" \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: ${routerURLstr}/" \
    -H 'Connection: keep-alive' \
    --data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=${credsBase64}" \
    --cookie-jar /tmp/cookie.txt)"

    # Interpret the curl_response to determine login success or failure #
    # This is a basic check #
    if echo "$curl_response" | grep -Eq 'url=index\.asp|url=GameDashboard\.asp'
    then
        printf "\n${GRNct}Router Login test passed.${NOct}"
        printf "\nRestarting web server... Please wait.\n"
        /sbin/service restart_httpd >/dev/null 2>&1 &
        sleep 1
        return 0
    else
        printf "\n${REDct}**ERROR**${NOct}: Router Login test failed.\n"
        printf "\n${routerLoginFailureMsg}\n\n"
        if _WaitForYESorNO_ "Would you like to try again?"
        then return 1  # Indicates failure but with intent to retry #
        else return 0  # User opted not to retry; do a graceful exit #
        fi
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jul-30] ##
##----------------------------------------##
_GetRawKeypress_() 
{
   local savedSettings
   savedSettings="$(stty -g)"
   stty -echo raw
   echo "$(dd count=1 2>/dev/null)"
   stty "$savedSettings"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-10] ##
##-------------------------------------##
_OfflineKeySeqHandler_()
{
   if [ $# -lt 3 ] || [ -z "$1" ] || \
      [ -z "$2" ] || [ -z "$3" ]
   then return 1 ; fi

   local retCode=1
   local offlineKeySeqNum="27251624"  offlineKeySeqCnt=4

   case "$3" in
       FOUNDOK)
           if [ "$1" -eq "$offlineKeySeqCnt" ] && \
              [ "$2" -eq "$offlineKeySeqNum" ]
           then retCode=0
           else retCode=1
           fi
           ;;
       NOTFOUND)
           if [ "$1" -gt 4 ] || \
              { [ "$1" -eq "$offlineKeySeqCnt" ] && \
                [ "$2" -ne "$offlineKeySeqNum" ] ; }
           then retCode=0
           else retCode=1
           fi
           ;;
       *) retCode=1 ;;
   esac

   return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-10] ##
##-------------------------------------##
_SetReloadKeySeqHandler_()
{
   if [ $# -lt 3 ] || [ -z "$1" ] || \
      [ -z "$2" ] || [ -z "$3" ]
   then return 1 ; fi

   local retCode=1
   local setReloadKeySeqNum="1812"  setReloadKeySeqCnt=2

   case "$3" in
       FOUNDOK)
           if [ "$1" -eq "$setReloadKeySeqCnt" ] && \
              [ "$2" -eq "$setReloadKeySeqNum" ]
           then retCode=0
           else retCode=1
           fi
           ;;
       NOTFOUND)
           if [ "$1" -gt 4 ] || \
              { [ "$1" -eq "$setReloadKeySeqCnt" ] && \
                [ "$2" -ne "$setReloadKeySeqNum" ] ; }
           then retCode=0
           else retCode=1
           fi
           ;;
       *) retCode=1 ;;
   esac

   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-10] ##
##----------------------------------------##
_GetKeypressInput_()
{
   local inputStrLenMAX=16  inputString  promptStr
   local charNum  inputStrLen  keypressCount
   local theKeySeqCnt theKeySeqNum  retCode
   local offlineUpdKeyFlag  execReloadKeyFlag 

   if [ -n "${offlineUpdTrigger:+xSETx}" ]
   then
       offlineUpdKeyFlag=true
       offlineUpdTrigger=false
   else
       offlineUpdKeyFlag=false
       unset offlineUpdTrigger
   fi

   if [ -n "${execReloadTrigger:+xSETx}" ]
   then
       execReloadKeyFlag=true
       execReloadTrigger=false
   else
       execReloadKeyFlag=false
       unset execReloadTrigger
   fi

   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       printf "\n**ERROR**: NO prompt string was provided.\n"
       return 1
   fi

   _ShowInputString_()
   { printf "\r\033[0K${promptStr}  %s" "$inputString" ; }

   _ClearKeySeqState_()
   { theKeySeqNum=0 ; theKeySeqCnt=0 ; }

   charNum=""
   promptStr="$1"
   inputString=""
   inputStrLen=0
   keypressCount=0
   _ClearKeySeqState_
   _ShowInputString_

   local savedIFS="$IFS"
   while IFS='' theChar="$(_GetRawKeypress_)"
   do
      charNum="$(printf "%d" "'$theChar")"

      if [ "$charNum" -eq 0 ] || [ "$charNum" -eq 10 ] || [ "$charNum" -eq 13 ]
      then
          if [ "$inputStrLen" -gt 0 ]
          then retCode=0 ; else retCode=1 ; fi
          break
      fi

      ## BACKSPACE keypress ##
      if [ "$charNum" -eq 8 ] || [ "$charNum" -eq 127 ]
      then
          if [ "$inputStrLen" -gt 0 ]
          then
              inputString="${inputString%?}"
              inputStrLen="${#inputString}"
              _ShowInputString_
          fi
          _ClearKeySeqState_
          continue
      fi

      ## BACKSPACE ALL keypress ##
      if [ "$charNum" -eq 21 ]
      then
          if [ "$inputStrLen" -gt 0 ]
          then
              inputString=""
              inputStrLen=0
              _ShowInputString_
          fi
          _ClearKeySeqState_
          continue
      fi

      ## ONLY 7-bit ASCII printable characters are VALID ##
      if [ "$charNum" -gt 31 ] && [ "$charNum" -lt 127 ]
      then
          if [ "$inputStrLen" -le "$inputStrLenMAX" ]
          then
              inputString="${inputString}${theChar}"
              inputStrLen="${#inputString}"
          fi
          _ShowInputString_
          _ClearKeySeqState_
          continue
      fi

      ## Non-Printable ASCII Codes ##
      if [ "$charNum" -gt 0 ] && [ "$charNum" -lt 32 ] && \
         { "$offlineUpdKeyFlag" || "$execReloadKeyFlag" ; }
      then
          "$offlineUpdKeyFlag" && offlineUpdTrigger=false
          "$execReloadKeyFlag" && execReloadTrigger=false

          theKeySeqCnt="$((theKeySeqCnt + 1))"
          if [ "$theKeySeqCnt" -eq 1 ]
          then theKeySeqNum="$charNum"
          else theKeySeqNum="${theKeySeqNum}${charNum}"
          fi
          if "$offlineUpdKeyFlag" && \
             _OfflineKeySeqHandler_ "$theKeySeqCnt" "$theKeySeqNum" FOUNDOK
          then
              _ClearKeySeqState_
              if [ "$inputString" = "offline" ]
              then offlineUpdTrigger=true ; fi
              continue
          fi
          if "$execReloadKeyFlag" && \
             _SetReloadKeySeqHandler_ "$theKeySeqCnt" "$theKeySeqNum" FOUNDOK
          then
              _ClearKeySeqState_
              execReloadTrigger=true
              continue
          fi
          if { "$offlineUpdKeyFlag" && \
               _OfflineKeySeqHandler_ "$theKeySeqCnt" "$theKeySeqNum" NOTFOUND ; } && \
             { "$execReloadKeyFlag" && \
               _SetReloadKeySeqHandler_ "$theKeySeqCnt" "$theKeySeqNum" NOTFOUND ; }
          then _ClearKeySeqState_ ; fi
      else
          _ClearKeySeqState_
      fi
   done
   IFS="$savedIFS"

   theUserInputStr="$inputString"
   echo ; return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jul-31] ##
##----------------------------------------##
_GetPasswordInput_()
{
   local PSWDstrLenMIN=5  PSWDstrLenMAX=64
   local newPSWDstring  newPSWDtmpStr  PSWDprompt
   local retCode  charNum  newPSWDlength  showPSWD
   # For more responsive TAB keypress debounce #
   local tabKeyDebounceSem="/tmp/var/tmp/${ScriptFNameTag}_TabKeySEM.txt"

   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       printf "${REDct}**ERROR**${NOct}: NO prompt string was provided.\n"
       return 1
   fi
   PSWDprompt="$1"

   _TabKeyDebounceWait_()
   {
      touch "$tabKeyDebounceSem"
      usleep 300000   #0.3 sec#
      rm -f "$tabKeyDebounceSem"
   }

   _ShowAsterisks_()
   {
      if [ $# -eq 0 ] || [ "$1" -eq 0 ]
      then echo ""
      else printf "%*s" "$1" ' ' | tr ' ' '*'
      fi
   }

   _ShowPSWDPrompt_()
   {
      local pswdTemp  LENct  LENwd
      [ "$showPSWD" = "1" ] && pswdTemp="$newPSWDstring" || pswdTemp="$newPSWDtmpStr"
      if [ "$newPSWDlength" -lt "$PSWDstrLenMIN" ] || [ "$newPSWDlength" -gt "$PSWDstrLenMAX" ]
      then LENct="$REDct" ; LENwd=""
      else LENct="$GRNct" ; LENwd="02"
      fi
      printf "\r\033[0K$PSWDprompt [Length=${LENct}%${LENwd}d${NOct}]: %s" "$newPSWDlength" "$pswdTemp"
   }

   showPSWD=0
   charNum=""
   newPSWDstring="$thePWSDstring"
   newPSWDlength="${#newPSWDstring}"
   newPSWDtmpStr="$(_ShowAsterisks_ "$newPSWDlength")"
   echo ; _ShowPSWDPrompt_

   local savedIFS="$IFS"
   while IFS='' theChar="$(_GetRawKeypress_)"
   do
      charNum="$(printf "%d" "'$theChar")"

      if [ "$charNum" -eq 0 ] || [ "$charNum" -eq 10 ] || [ "$charNum" -eq 13 ]
      then
          if [ "$newPSWDlength" -ge "$PSWDstrLenMIN" ] && [ "$newPSWDlength" -le "$PSWDstrLenMAX" ]
          then
              echo
              retCode=0
          elif [ "$newPSWDlength" -lt "$PSWDstrLenMIN" ]
          then
              newPSWDstring=""
              printf "\n${REDct}**ERROR**${NOct}: Password length is less than allowed minimum length "
              printf "[MIN=${GRNct}${PSWDstrLenMIN}${NOct}].\n"
              retCode=1
          elif [ "$newPSWDlength" -gt "$PSWDstrLenMAX" ]
          then
              newPSWDstring=""
              printf "\n${REDct}**ERROR**${NOct}: Password length is greater than allowed maximum length "
              printf "[MAX=${GRNct}${PSWDstrLenMAX}${NOct}].\n"
              retCode=1
          fi
          break
      fi

      ## Keep same previous password string ##
      if [ "$charNum" -eq 27 ] && [ -n "$thePWSDstring" ]
      then
          retCode=0
          newPSWDstring="$thePWSDstring"
          break
      fi

      ## TAB keypress as toggle with debounce ##
      if [ "$charNum" -eq 9 ]
      then
          if [ ! -f "$tabKeyDebounceSem" ]
          then
              showPSWD="$((! showPSWD))"
              _ShowPSWDPrompt_
              _TabKeyDebounceWait_ &
          fi
          continue
      fi

      ## BACKSPACE keypress ##
      if [ "$charNum" -eq 8 ] || [ "$charNum" -eq 127 ]
      then
          if [ "$newPSWDlength" -gt 0 ]
          then
              newPSWDstring="${newPSWDstring%?}"
              newPSWDlength="${#newPSWDstring}"
              newPSWDtmpStr="$(_ShowAsterisks_ "$newPSWDlength")"
              _ShowPSWDPrompt_
          fi
          continue
      fi

      ## BACKSPACE ALL keypress ##
      if [ "$charNum" -eq 21 ]
      then
          if [ "$newPSWDlength" -gt 0 ]
          then
              newPSWDstring=""
              newPSWDlength=0
              newPSWDtmpStr="$(_ShowAsterisks_ "$newPSWDlength")"
              _ShowPSWDPrompt_
          fi
          continue
      fi

      ## ONLY 7-bit ASCII printable characters are VALID ##
      if [ "$charNum" -gt 31 ] && [ "$charNum" -lt 127 ]
      then
          if [ "$newPSWDlength" -le "$PSWDstrLenMAX" ]
          then
              newPSWDstring="${newPSWDstring}${theChar}"
              newPSWDlength="${#newPSWDstring}"
              newPSWDtmpStr="$(_ShowAsterisks_ "$newPSWDlength")"
          fi
          _ShowPSWDPrompt_
          continue
      fi
   done
   IFS="$savedIFS"

   thePWSDstring="$newPSWDstring"
   return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2024-Aug-18] ##
##-------------------------------------##
_CIDR_IPaddrBlockContainsIPaddr_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1 ; fi

   local lastNETIPaddr4thOctet  cidrIPRangeMax=0

   local thisLANIPaddr="$2"
   local cidrNETIPaddr="${1%/*}"
   local cidrNETIPmask="${1#*/}"
   local NETIPaddr4thOctet="${cidrNETIPaddr##*.}"
   local LANIPaddr4thOctet="${thisLANIPaddr##*.}"

   # Assumes the host segment has a maximum of 8 bits #
   # and the network segment has a minimum of 24 bits #
   case "$cidrNETIPmask" in
       31) cidrIPRangeMax=1 ;;
       30) cidrIPRangeMax=3 ;;
       29) cidrIPRangeMax=7 ;;
       28) cidrIPRangeMax=15 ;;
       27) cidrIPRangeMax=31 ;;
       26) cidrIPRangeMax=63 ;;
       25) cidrIPRangeMax=127 ;;
       24) cidrIPRangeMax=255 ;;
   esac
   lastNETIPaddr4thOctet="$((NETIPaddr4thOctet + cidrIPRangeMax))"
   [ "$lastNETIPaddr4thOctet" -gt 255 ] && lastNETIPaddr4thOctet=255

   if [ "$LANIPaddr4thOctet" -ge "$NETIPaddr4thOctet" ] && \
      [ "$LANIPaddr4thOctet" -le "$lastNETIPaddr4thOctet" ]
   then return 0
   else return 1
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Aug-18] ##
##----------------------------------------##
_CheckWebGUILoginAccessOK_()
{
   local accessRestriction  restrictRuleList
   local lanIPaddrRegEx1 lanIPaddrRegEx2 lanIPaddrRegEx3
   local cidrIPaddrEntry  cidrIPaddrBlock  cidrIPaddrRegEx
   local mainLANIPaddrRegEx  netwkIPv4AddrRegEx  netwkIPv4AddrX

   accessRestriction="$(nvram get enable_acc_restriction)"
   if [ -z "$accessRestriction" ] || [ "$accessRestriction" -eq 0 ]
   then return 0 ; fi

   restrictRuleList="$(nvram get restrict_rulelist)"
   if [ -n "$mainNET_IPaddr" ]
   then
       netwkIPv4AddrX="${mainNET_IPaddr%/*}"
       netwkIPv4AddrX="${netwkIPv4AddrX%.*}"
   else
       netwkIPv4AddrX="${mainLAN_IPaddr%.*}"
   fi
   netwkIPv4AddrX="${netwkIPv4AddrX}.${IPv4octet_RegEx}"
   netwkIPv4AddrRegEx="$(echo "$netwkIPv4AddrX" | sed 's/\./\\./g')"
   mainLANIPaddrRegEx="$(echo "$mainLAN_IPaddr" | sed 's/\./\\./g')"

   # Router IP address MUST have access to WebGUI #
   cidrIPaddrRegEx="${netwkIPv4AddrRegEx}/(2[4-9]|3[0-1])"
   lanIPaddrRegEx1=">${mainLANIPaddrRegEx}>[13]"
   lanIPaddrRegEx2=">${mainLANIPaddrRegEx}/(2[4-9]|3[0-2])>[13]"
   lanIPaddrRegEx3=">${cidrIPaddrRegEx}>[13]"

   if echo "$restrictRuleList" | grep -qE "$lanIPaddrRegEx1|$lanIPaddrRegEx2"
   then return 0 ; fi

   cidrIPaddrEntry="$(echo "$restrictRuleList" | grep -oE "$lanIPaddrRegEx3")"
   if [ -n "$cidrIPaddrEntry" ]
   then
       cidrIPaddrBlock="$(echo "$cidrIPaddrEntry" | grep -oE "$cidrIPaddrRegEx")"
       for cidrIPblock in $cidrIPaddrBlock
       do
           if _CIDR_IPaddrBlockContainsIPaddr_ "$cidrIPblock" "$mainLAN_IPaddr"
           then return 0 ; fi
       done
   fi

   printf "\n${REDct}*WARNING*: The \"Enable Access Restrictions\" option is currently active.${NOct}"
   printf "\nTo allow webGUI login access you must add the router IP address ${GRNct}${mainLAN_IPaddr}${NOct}
with the \"${GRNct}Web UI${NOct}\" access type on the \"Access restriction list\" panel."
   printf "\n[See ${GRNct}'Administration -> System -> Access restriction list'${NOct}]"
   printf "\nAn alternative method would be to disable the \"Enable Access Restrictions\" option.\n"

   return 1
}

##----------------------------------------##
## Modified by Martinski W. [2024-Aug-16] ##
##----------------------------------------##
_GetLoginCredentials_()
{
    local retry="yes"  userName  savedMsg
    local oldPWSDstring  thePWSDstring
    local loginCredsENC  loginCredsDEC

    # Check if WebGUI access is NOT restricted #
    if ! _CheckWebGUILoginAccessOK_
    then
        _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    # Get the Username from NVRAM #
    userName="$(nvram get http_username)"

    loginCredsENC="$(Get_Custom_Setting credentials_base64)"
    if [ -z "$loginCredsENC" ] || [ "$loginCredsENC" = "TBD" ]
    then
        thePWSDstring=""
    else
        loginCredsDEC="$(echo "$loginCredsENC" | openssl base64 -d)"
        thePWSDstring="$(echo "$loginCredsDEC" | sed "s/${userName}://")"
    fi
    oldPWSDstring="$thePWSDstring"

    while [ "$retry" = "yes" ]
    do
        echo "=== Login Credentials ==="
        _GetPasswordInput_ "Enter password for user ${GRNct}${userName}${NOct}"
        if [ -z "$thePWSDstring" ]
        then
            printf "\nPassword string is ${REDct}NOT${NOct} valid. Credentials were not saved.\n"
            _WaitForEnterKey_
            continue
        fi

        # Encode the Username and Password in Base64 #
        loginCredsENC="$(echo -n "${userName}:${thePWSDstring}" | openssl base64 -A)"

        Update_Custom_Settings credentials_base64 "$loginCredsENC"

        if [ "$thePWSDstring" != "$oldPWSDstring" ]
        then savedMsg="${GRNct}New credentials saved.${NOct}"
        else savedMsg="${GRNct}Credentials remain unchanged.${NOct}"
        fi
        printf "\n${savedMsg}\n"
        printf "Encoded Credentials:\n"
        printf "${GRNct}$loginCredsENC${NOct}\n"

        # Prompt to test the credentials #
        if _WaitForYESorNO_ "\nWould you like to test the current login credentials?"
        then
            _TestLoginCredentials_ "$loginCredsENC" || continue
        fi

        # Stop the loop if the test passes or if the user chooses not to test #
        retry="no"
    done

    _WaitForEnterKey_ "$mainMenuReturnPromptStr"
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_GetNodeIPv4List_()
{
    # Get the value of asus_device_list #
    local ip_addresses
    local device_list="$(nvram get asus_device_list)"

    # Check if asus_device_list is not empty #
    if [ -n "$device_list" ]
    then
        # Split the device list into records and extract the IP addresses, excluding Main Router LAN IP address #
        ip_addresses="$(echo "$device_list" | tr '<' '\n' | awk -v exclude="$mainLAN_IPaddr" -F'>' '{if (NF>=4 && $3 != exclude) print $3}')"

        # Check if IP addresses are not empty #
        if [ -n "$ip_addresses" ]; then
            # Print each IP address on a separate line
            printf "%s\n" "$ip_addresses"
        else
            return 1
        fi
    else
        Say "NVRAM asus_device_list is NOT populated. No Mesh Nodes were found."
        return 1
    fi
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_NodeActiveStatus_()
{
    # Get the value of cfg_device_list #
    local ip_addresses
    local node_online_status="$(nvram get cfg_device_list)"

    # Check if cfg_device_list is not empty #
    if [ -n "$node_online_status" ]
    then
        # Split the device list into records and extract the IP addresses, excluding Main Router LAN IP address #
        ip_addresses="$(echo "$node_online_status" | tr '<' '\n' | awk -v exclude="$mainLAN_IPaddr" -F'>' '{if (NF>=3 && $2 != exclude) print $2}')"

        # Check if IP addresses are not empty #
        if [ -n "$ip_addresses" ]; then
            # Print each IP address on a separate line
            printf "%s\n" "$ip_addresses"
        else
            return 1
        fi
    else
        Say "NVRAM cfg_device_list is NOT populated. No Mesh Nodes were found."
        return 1
    fi
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-30] ##
##----------------------------------------##
_Populate_Node_Settings_()
{
    local MAC_address="$1"
    local model_id="$2"
    local update_date="$3"
    local update_vers="$4"
    local nodeKeyPrefix="Node_${MAC_address}_"

    # Update or add each piece of information
    Update_Custom_Settings "${nodeKeyPrefix}Model_NameID" "$model_id"
    Update_Custom_Settings "${nodeKeyPrefix}New_Notification_Date" "$update_date"
    Update_Custom_Settings "${nodeKeyPrefix}New_Notification_Vers" "$update_vers"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Mar-26] ##
##---------------------------------------##
_GetNodeURL_()
{
    local NodeIP_Address="$1"
    local urlProto urlDomain urlPort

    if [ "$(nvram get http_enable)" = "1" ]; then
        urlProto="https"
    else
        urlProto="http"
    fi

    urlPort="$(nvram get "${urlProto}_lanport")"
    if [ "$urlPort" -eq 80 ] || [ "$urlPort" -eq 443 ]; then
        urlPort=""
    else
        urlPort=":$urlPort"
    fi

    echo "${urlProto}://${NodeIP_Address}${urlPort}"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Mar-26] ##
##---------------------------------------##
_GetNodeInfo_()
{
    local NodeIP_Address="$1"
    local NodeURLstr="$(_GetNodeURL_ "$NodeIP_Address")"

    ## Default values for specific variables
    node_productid="Unreachable"
    Node_combinedVer="Unreachable"
    node_asus_device_list=""
    node_cfg_device_list=""
    node_firmver="Unreachable"
    node_buildno="Unreachable"
    node_extendno="Unreachable"
    node_webs_state_flag=""
    node_webs_state_info=""
    node_odmpid="Unreachable"
    node_wps_modelnum="Unreachable"
    node_model="Unreachable"
    node_build_name="Unreachable"
    node_lan_hostname="Unreachable"
    node_label_mac="Unreachable"
    NodeGNUtonFW=false

    ## Check for Login Credentials ##
    credsBase64="$(Get_Custom_Setting credentials_base64)"
    if [ -z "$credsBase64" ] || [ "$credsBase64" = "TBD" ]
    then
        Say "${REDct}**ERROR**${NOct}: No login credentials have been saved. Use the Main Menu to save login credentials."
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        return 1
    fi

    # Perform login request #
    curl -s -k "${NodeURLstr}/login.cgi" \
    --referer "${NodeURLstr}/Main_Login.asp" \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: ${NodeURLstr}" \
    -H 'Connection: keep-alive' \
    --data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=$credsBase64" \
    --cookie-jar '/tmp/nodecookies.txt' \
    --max-time 2 > /tmp/login_response.txt 2>&1

    if [ $? -ne 0 ]
    then
        printf "\n${REDct}Login failed for AiMesh Node [$NodeIP_Address].${NOct}\n"
        return 1
    fi

    # Retrieve the HTML content #
    htmlContent="$(curl -s -k "${NodeURLstr}/appGet.cgi?hook=nvram_get(productid)%3bnvram_get(asus_device_list)%3bnvram_get(cfg_device_list)%3bnvram_get(firmver)%3bnvram_get(buildno)%3bnvram_get(extendno)%3bnvram_get(webs_state_flag)%3bnvram_get(odmpid)%3bnvram_get(wps_modelnum)%3bnvram_get(model)%3bnvram_get(build_name)%3bnvram_get(lan_hostname)%3bnvram_get(webs_state_info)%3bnvram_get(label_mac)" \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Accept-Encoding: gzip, deflate' \
    -H 'Connection: keep-alive' \
    -H "Referer: ${NodeURLstr}/index.asp" \
    -H 'Upgrade-Insecure-Requests: 0' \
    --cookie '/tmp/nodecookies.txt' \
    --max-time 2 2>&1)"

    if [ $? -ne 0 ] || [ -z "$htmlContent" ]
    then
        printf "\n${REDct}Failed to get information for AiMesh Node [$NodeIP_Address].${NOct}\n"
        return 1
    fi

    # Extract values using regular expressions #
    node_productid="$(echo "$htmlContent" | grep -o '"productid":"[^"]*' | sed 's/"productid":"//')"
    node_asus_device_list="$(echo "$htmlContent" | grep -o '"asus_device_list":"[^"]*' | sed 's/"asus_device_list":"//')"
    node_cfg_device_list="$(echo "$htmlContent" | grep -o '"cfg_device_list":"[^"]*' | sed 's/"cfg_device_list":"//')"
    node_firmver="$(echo "$htmlContent" | grep -o '"firmver":"[^"]*' | sed 's/"firmver":"//' | tr -d '.')"
    node_buildno="$(echo "$htmlContent" | grep -o '"buildno":"[^"]*' | sed 's/"buildno":"//')"
    node_extendno="$(echo "$htmlContent" | grep -o '"extendno":"[^"]*' | sed 's/"extendno":"//')"
    node_webs_state_flag="$(echo "$htmlContent" | grep -o '"webs_state_flag":"[^"]*' | sed 's/"webs_state_flag":"//')"
    node_webs_state_info="$(echo "$htmlContent" | grep -o '"webs_state_info":"[^"]*' | sed 's/"webs_state_info":"//')"
    node_odmpid="$(echo "$htmlContent" | grep -o '"odmpid":"[^"]*' | sed 's/"odmpid":"//')"
    node_wps_modelnum="$(echo "$htmlContent" | grep -o '"wps_modelnum":"[^"]*' | sed 's/"wps_modelnum":"//')"
    node_model="$(echo "$htmlContent" | grep -o '"model":"[^"]*' | sed 's/"model":"//')"
    node_build_name="$(echo "$htmlContent" | grep -o '"build_name":"[^"]*' | sed 's/"build_name":"//')"
    node_lan_hostname="$(echo "$htmlContent" | grep -o '"lan_hostname":"[^"]*' | sed 's/"lan_hostname":"//')"
    node_label_mac="$(echo "$htmlContent" | grep -o '"label_mac":"[^"]*' | sed 's/"label_mac":"//')"

    # Check if installed F/W NVRAM vars contain "gnuton" #
    if echo "$node_extendno" | grep -iq "gnuton"
    then NodeGNUtonFW=true ; fi
    # Combine extracted information into one string #
    Node_combinedVer="${node_firmver}.${node_buildno}.$node_extendno"

    # Perform logout request #
    curl -s -k "${NodeURLstr}/Logout.asp" \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Accept-Encoding: gzip, deflate' \
    -H 'Connection: keep-alive' \
    -H "Referer: ${NodeURLstr}/Main_Login.asp" \
    -H 'Upgrade-Insecure-Requests: 0' \
    --cookie '/tmp/nodecookies.txt' \
    --max-time 2 > /tmp/logout_response.txt 2>&1

    if [ $? -ne 0 ]; then
        return 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_GetLatestFWUpdateVersionFromNode_()
{
   local retCode=0  webState  newVersionStr

   if [ -z "${node_webs_state_flag:+xSETx}" ]
   then webState=""
   else webState="$node_webs_state_flag"
   fi
   if [ -z "$webState" ] || [ "$webState" -eq 0 ]
   then retCode=1 ; fi

   if [ -z "${node_webs_state_info:+xSETx}" ]
   then
       newVersionStr=""
   else
       newVersionStr="$(echo "$node_webs_state_info" | sed 's/_/./g')"
       if [ $# -eq 0 ] || [ -z "$1" ]
       then
           newVersionStr="$(echo "$newVersionStr" | awk -F '-' '{print $1}')"
       fi
   fi

   [ -z "$newVersionStr" ] && retCode=1
   echo "$newVersionStr" ; return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jun-05] ##
##----------------------------------------##
_GetLatestFWUpdateVersionFromWebsite_()
{
    local url="$1"

    local links_and_versions="$(curl -Ls --retry 4 --retry-delay 5 "$url" | grep -o 'href="[^"]*'"$PRODUCT_ID"'[^"]*\.zip' | sed 's/amp;//g; s/href="//' | \
        awk -F'[_\.]' '{print $3"."$4"."$5" "$0}' | sort -t. -k1,1n -k2,2n -k3,3n)"

    if [ -z "$links_and_versions" ]
    then echo "**ERROR** **NO_URL**" ; return 1 ; fi

    local latest="$(echo "$links_and_versions" | tail -n 1)"
    local linkStr="$(echo "$latest" | cut -d' ' -f2-)"
    local fileStr="$(echo "$linkStr" | grep -oE "/${PRODUCT_ID}_[0-9]+.*.zip$")"
    local versionStr

    if [ -z "$fileStr" ]
    then versionStr="$(echo "$latest" | cut -d ' ' -f1)"
    else versionStr="$(echo "${fileStr%.*}" | sed "s/\/${PRODUCT_ID}_//" | sed 's/_/./g')"
    fi

    # Extracting the correct link from the page
    local correct_link="$(echo "$linkStr" | sed 's|^/|https://sourceforge.net/|')"

    if [ -z "$versionStr" ] || [ -z "$correct_link" ]
    then echo "**ERROR** **NO_URL**" ; return 1 ; fi

    echo "$versionStr"
    echo "$correct_link"
    return 0
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Feb-23] ##
##---------------------------------------##
_GetLatestFWUpdateVersionFromGithub_()
{
    local url="$1"  # GitHub API URL for the latest release
    local firmware_type="$2"  # Type of firmware, e.g., "tuf", "rog" or "pure"

    local search_type="$firmware_type"  # Default to the input firmware_type

    # If firmware_type is "pure", set search_type to include "squashfs" as well
    if [ "$firmware_type" = "pure" ]; then
        search_type="pure\|squashfs\|ubi"
    fi

    # Fetch the latest release data from GitHub #
    local release_data="$(curl -s "$url")"

    # Construct the grep pattern based on search_type #
    local grep_pattern="\"browser_download_url\": \".*${PRODUCT_ID}.*\(${search_type}\).*\.\(w\|pkgtb\)\""

    # Filter the JSON for the desired firmware using grep and head to fetch the URL
    local download_url="$(echo "$release_data" | 
        grep -o "$grep_pattern" | 
        grep -o "https://[^ ]*\.\(w\|pkgtb\)" | 
        head -1)"

    # Check if a URL was found
    if [ -z "$download_url" ]
    then
        echo "**ERROR** **NO_GITHUB_URL**"
        return 1
    else
        # Extract the version from the download URL or release data
        local version="$(echo "$download_url" | grep -oE "${PRODUCT_ID}[_-][0-9.]+[^/]*" | sed "s/${PRODUCT_ID}[_-]//;s/.w$//;s/_/./g")"
        echo "$version"
        echo "$download_url"
        return 0
    fi
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Apr-05] ##
##---------------------------------------##
GetLatestFirmwareMD5Url()
{
    local url="$1"  # GitHub API URL for the latest release
    local firmware_type="$2"  # Type of firmware, e.g., "tuf", "rog" or "pure"

    local search_type="$firmware_type"  # Default to the input firmware_type

    # If firmware_type is "pure", set search_type to include "squashfs" as well
    if [ "$firmware_type" = "pure" ]; then
        search_type="pure\|squashfs\|ubi"
    fi

    # Fetch the latest release data from GitHub
    local release_data="$(curl -s "$url")"

    # Construct the grep pattern based on search_type
    local grep_pattern="\"browser_download_url\": \".*${PRODUCT_ID}.*\(${search_type}\).*\.md5\""

    # Filter the JSON for the desired firmware using grep and sed
    local md5_url="$(echo "$release_data" |
        grep -o "$grep_pattern" | 
        sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/' |
        head -1)"

    # Check if a URL was found and output result or error
    if [ -z "$md5_url" ]
    then
        echo "**ERROR** **NO_FIRMWARE_FILE_URL_FOUND**"
        return 1
    else
        echo "$md5_url"
    fi
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Apr-17] ##
##---------------------------------------##
GetLatestChangelogUrl()
{
    local url="$1"  # GitHub API URL for the latest release

    # Fetch the latest release data from GitHub
    local release_data="$(curl -s "$url")"

    # Parse the release data to find the download URL of the CHANGELOG file
    # Directly find the URL without matching a specific model number
    local changelog_url="$(echo "$release_data" | grep -o "\"browser_download_url\": \".*CHANGELOG.*\"" | grep -o "https://[^ ]*\"" | tr -d '"' | head -1)"

    # Check if the URL has been found
    if [ -z "$changelog_url" ]
    then
        echo "**ERROR** **NO_CHANGELOG_FILE_URL_FOUND**"
        return 1
    else
        echo "$changelog_url"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-18] ##
##----------------------------------------##
_DownloadForGnuton_()
{
    # Follow redirects and capture the effective URL
    local effective_url="$(curl -Ls -o /dev/null -w %{url_effective} "$release_link")"

    # Use the effective URL to capture the Content-Disposition header
    local original_filename="$(curl -sI "$effective_url" | grep -i content-disposition | sed -n 's/.*filename=["]*\([^";]*\).*/\1/p')"

    # Sanitize filename by removing problematic characters
    local sanitized_filename="$(echo "$original_filename" | sed 's/[^a-zA-Z0-9._-]//g')"

    # Extract the file extension
    extension="${sanitized_filename##*.}"   

    # Combine path, custom file name, and extension before download
    FW_DL_FPATH="${FW_ZIP_DIR}/${FW_FileName}.${extension}"
    FW_MD5_GITHUB="${FW_ZIP_DIR}/${FW_FileName}.md5"
    FW_Changelog_GITHUB="${FW_ZIP_DIR}/${FW_FileName}_Changelog.txt"

    # Download the firmware using the release link #
    wget --tries=5 --waitretry=5 --retry-connrefused \
         -O "$FW_DL_FPATH" "$release_link"
    if [ ! -s "$FW_DL_FPATH" ]
    then return 1 ; fi

    # Download the latest MD5 checksum #
    Say "Downloading latest MD5 checksum ${GRNct}${md5_url}${NOct}"
    wget --tries=5 --waitretry=5 --retry-connrefused \
         -O "$FW_MD5_GITHUB" "$md5_url"
    if [ ! -s "$FW_MD5_GITHUB" ]
    then return 1 ; fi

    # Download the latest changelog #
    Say "Downloading latest Changelog ${GRNct}${GnutonChangeLogURL}${NOct}"
    wget --tries=5 --waitretry=5 --retry-connrefused \
         -O "$FW_Changelog_GITHUB" "$GnutonChangeLogURL"
    if [ ! -s "$FW_Changelog_GITHUB" ]
    then return 1
    else return 0
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-18] ##
##----------------------------------------##
_DownloadForMerlin_()
{
    wget --tries=5 --waitretry=5 --retry-connrefused \
         -O "$FW_ZIP_FPATH" "$release_link"

    # Check if the file was downloaded successfully #
    if [ ! -s "$FW_ZIP_FPATH" ]
    then return 1
    else return 0
    fi
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Apr-18] ##
##---------------------------------------##
_UnzipMerlin_()
{
    Say "-----------------------------------------------------------"
    # List & log the contents of the ZIP file
    unzip -l "$FW_ZIP_FPATH" 2>&1 | \
    while IFS= read -r uzLINE ; do Say "$uzLINE" ; done
    Say "-----------------------------------------------------------"

    # Extracting the firmware binary image
    if unzip -o "$FW_ZIP_FPATH" -d "$FW_BIN_DIR" -x README* 2>&1 | \
       while IFS= read -r line ; do Say "$line" ; done
    then
        Say "-----------------------------------------------------------"
        #---------------------------------------------------------------#
        # Check if ZIP file was downloaded to a USB-attached drive.
        # Take into account special case for Entware "/opt/" paths.
        #---------------------------------------------------------------#
        if ! echo "$FW_ZIP_FPATH" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)"
        then
            # It's not on a USB drive, so it's safe to delete it
            rm -f "$FW_ZIP_FPATH"
        elif ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR" 1
        then
            #-------------------------------------------------------------#
            # This should not happen because we already checked for it
            # at the very beginning of this function, but just in case
            # it does (drive going bad suddenly?) we'll report it here.
            #-------------------------------------------------------------#
            Say "Expected directory path $FW_ZIP_BASE_DIR is NOT found."
            Say "${REDct}**ERROR**${NOct}: Required USB storage device is not connected or not mounted correctly."
            return 1
            # Consider how to handle this error. For now, we'll not delete the ZIP file.
        else
            keepZIPfile=1
        fi
    else
        #------------------------------------------------------------#
        # Remove ZIP file here because it may have been corrupted.
        # Better to download it again and start all over, instead
        # of trying to figure out why uncompressing it failed.
        #------------------------------------------------------------#
        rm -f "$FW_ZIP_FPATH"
        _SendEMailNotification_ FAILED_FW_UNZIP_STATUS
        Say "${REDct}**ERROR**${NOct}: Unable to decompress the firmware ZIP file [$FW_ZIP_FPATH]."
        _return 1
    fi
    return 0
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Apr-18] ##
##---------------------------------------##
_CopyGnutonFiles_()
{
   Say "Checking if file management is required"

   local copy_success=true
   local copy_attempted=false

   # Check and copy the firmware file if different from destination
   if [ "$FW_DL_FPATH" != "${FW_BIN_DIR}/${FW_FileName}.${extension}" ]
   then
       Say "File management is required"
       copy_attempted=true
       cp "$FW_DL_FPATH" "$FW_BIN_DIR" && Say "Copying firmware file..." || copy_success=false
   else
       Say "File management is not required"
   fi

   if ! "$offlineUpdateTrigger"
   then
       # Check and copy the MD5 file if different from destination
       if [ "$FW_MD5_GITHUB" != "${FW_BIN_DIR}/${FW_FileName}.md5" ]
       then
           copy_attempted=true
           mv -f "$FW_MD5_GITHUB" "$FW_BIN_DIR" && Say "Moving MD5 file..." || copy_success=false
       fi

       # Check and copy the Changelog file if different from destination
       if [ "$FW_Changelog_GITHUB" != "${FW_BIN_DIR}/${FW_FileName}_Changelog.txt" ]
       then
           copy_attempted=true
           mv -f "$FW_Changelog_GITHUB" "$FW_BIN_DIR" && Say "Moving changelog file..." || copy_success=false
       fi
   fi

   if "$copy_attempted" && "$copy_success"
   then
       #---------------------------------------------------------------#
       # Check if Gntuon file was downloaded to a USB-attached drive.
       # Take into account special case for Entware "/opt/" paths.
       #---------------------------------------------------------------#
       if ! echo "$FW_DL_FPATH" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)"
       then
           # It's not on a USB drive, so it's safe to delete it #
           rm -f "$FW_DL_FPATH"
           rm -f "$FW_Changelog_GITHUB"
           rm -f "$FW_MD5_GITHUB"
       elif ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR" 1
       then
          #-------------------------------------------------------------#
           # This should not happen because we already checked for it
           # at the very beginning of this function, but just in case
           # it does (drive going bad suddenly?) we'll report it here.
           #-------------------------------------------------------------#
           Say "Expected directory path $FW_ZIP_BASE_DIR is NOT found."
           Say "${REDct}**ERROR**${NOct}: Required USB storage device is not connected or not mounted correctly."
           return 1
           # Consider how to handle this error. For now, we'll not delete the firmware file.
       else
           keepWfile=1
       fi
   fi
   return 0
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jul-24] ##
##------------------------------------------##
_CheckOnlineFirmwareSHA256_()
{
    # Fetch the latest SHA256 checksums from ASUSWRT-Merlin website #
    checksums="$(curl -Ls --retry 4 --retry-delay 5 --retry-connrefused \
 https://www.asuswrt-merlin.net/download | \
 sed -n '/<.*>SHA256 signatures:<\/.*>/,/<\/pre>/p' | \
 sed -n '/<pre[^>].*>/,/<\/pre>/p' | sed -e 's/<[^>].*>//g')"

    if [ -z "$checksums" ]
    then
        Say "${REDct}**ERROR**${NOct}: Could not download the firmware SHA256 signatures from the website."
        _DoCleanUp_ 1
        return 1
    fi

    if [ -f "$firmware_file" ]
    then
        fw_sig="$(openssl sha256 "$firmware_file" | cut -d' ' -f2)"
        # Extract the corresponding signature for the firmware file from the fetched checksums #
        dl_sig="$(echo "$checksums" | grep "$(basename "$firmware_file")" | cut -d' ' -f1)"
        if [ "$fw_sig" != "$dl_sig" ]
        then
            Say "${REDct}**ERROR**${NOct}: SHA256 signature from extracted firmware file does not match the SHA256 signature from the website."
            _DoCleanUp_ 1
            _SendEMailNotification_ FAILED_FW_CHECKSUM_STATUS
            return 1
        else
            Say "SHA256 signature check for firmware image file passed successfully."
            return 0
        fi
    else
        Say "${REDct}**ERROR**${NOct}: Firmware image file NOT found!"
        _DoCleanUp_ 1
        return 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jul-31] ##
##----------------------------------------##
_CheckOfflineFirmwareSHA256_()
{
    if [ -f "sha256sum.sha256" ] && [ -f "$firmware_file" ]
    then
        fw_sig="$(openssl sha256 "$firmware_file" | cut -d' ' -f2)"
        dl_sig="$(grep "$firmware_file" sha256sum.sha256 | cut -d' ' -f1)"
        if [ "$fw_sig" != "$dl_sig" ]
        then
            echo
            Say "${REDct}**ERROR**${NOct}: SHA256 signature from firmware file does NOT have a matching SHA256 signature."
            _SendEMailNotification_ FAILED_FW_CHECKSUM_STATUS
            printf "\nOffline update was aborted. Exiting.\n"
            _DoCleanUp_ 1
            return 1
        else
            Say "SHA256 signature check for firmware image file passed successfully."
            return 0
        fi
    else
        echo
        Say "${REDct}**ERROR**${NOct}: SHA256 signature file NOT found."
        printf "\nOffline update was aborted. Exiting.\n"
        _DoCleanUp_ 1
        return 1
    fi
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Apr-18] ##
##---------------------------------------##
_CheckFirmwareMD5_()
{
    # Check if both the MD5 checksum file and the firmware file exist
    if [ -f "${FW_BIN_DIR}/${FW_FileName}.md5" ] && [ -f "$firmware_file" ]
    then
        # Extract the MD5 checksum from the downloaded .md5 file #
        # Assuming the .md5 file contains a single line with the checksum followed by the filename
        local md5_expected="$(cut -d' ' -f1 "${FW_BIN_DIR}/${FW_FileName}.md5")"
    
        # Calculate the MD5 checksum of the firmware file #
        local md5_actual="$(md5sum "$firmware_file" | cut -d' ' -f1)"
    
        # Compare the calculated MD5 checksum with the expected MD5 checksum #
        if [ "$md5_actual" != "$md5_expected" ]
        then
            Say "${REDct}**ERROR**${NOct}: Extracted firmware does not match the MD5 checksum!"
            _DoCleanUp_ 1
            _SendEMailNotification_ FAILED_FW_CHECKSUM_STATUS
            return 1
        else
            Say "Firmware MD5 checksum verified successfully."
        fi
    else
        Say "${REDct}**ERROR**${NOct}: MD5 checksum file not found or firmware file is missing!"
        _DoCleanUp_ 1
        return 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-27] ##
##----------------------------------------##
_toggle_change_log_check_()
{
    local currentSetting="$(Get_Custom_Setting "CheckChangeLog")"

    if [ "$currentSetting" = "ENABLED" ]
    then
        printf "${REDct}*WARNING*${NOct}\n"
        printf "Disabling the changelog verification check may risk unanticipated firmware changes.\n"
        printf "The advice is to proceed only if you review the latest firmware changelog file manually.\n"

        if _WaitForYESorNO_ "\nProceed to ${REDct}DISABLE${NOct}?"
        then
            Update_Custom_Settings "CheckChangeLog" "DISABLED"
            Delete_Custom_Settings "FW_New_Update_Changelog_Approval"
            printf "Changelog verification check is now ${REDct}DISABLED.${NOct}\n"
        else
            printf "Changelog verification check remains ${GRNct}ENABLED.${NOct}\n"
        fi
    else
        printf "Confirm to enable the changelog verification check."
        if _WaitForYESorNO_ "\nProceed to ${GRNct}ENABLE${NOct}?"
        then
            Update_Custom_Settings "CheckChangeLog" "ENABLED"
            Update_Custom_Settings "FW_New_Update_Changelog_Approval" "TBD"
            printf "Changelog verification check is now ${GRNct}ENABLED.${NOct}\n"
        else
            printf "Changelog verification check remains ${REDct}DISABLED.${NOct}\n"
        fi
    fi
    _WaitForEnterKey_
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jul-23] ##
##------------------------------------------##
_Toggle_VPN_Access_()
{
    local currentSetting="$(Get_Custom_Setting "Allow_Updates_OverVPN")"

    if [ "$currentSetting" = "ENABLED" ]
    then
        printf "\n${REDct}*NOTICE*${NOct}\n"
        printf "Disabling this feature will shut down Tailscale/ZeroTier VPN access during updates.\n"
        printf "Proceed if you do not need remote VPN access during firmware updates.\n"

        if _WaitForYESorNO_ "\nProceed to ${GRNct}DISABLE${NOct}?"
        then
            Update_Custom_Settings "Allow_Updates_OverVPN" "DISABLED"
            printf "VPN access will now be ${GRNct}DISABLED.${NOct}\n"
        else
            printf "VPN access during updates remains ${REDct}ENABLED.${NOct}\n"
        fi
    else
        printf "\n${REDct}*WARNING*${NOct}\n"
        printf "Enabling this feature will keep Tailscale/ZeroTier VPN access active during updates.\n"
        printf "Proceed only if you require Tailscale/ZeroTier to connect remotely via an SSH session during firmware updates.\n"
        if _WaitForYESorNO_ "\nProceed to ${REDct}ENABLE${NOct}?"
        then
            Update_Custom_Settings "Allow_Updates_OverVPN" "ENABLED"
            printf "VPN access will now be ${REDct}ENABLED.${NOct}\n"
        else
            printf "VPN access during updates remains ${GRNct}DISABLED.${NOct}\n"
        fi
    fi
    _WaitForEnterKey_
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-27] ##
##----------------------------------------##
_Toggle_FW_UpdatesFromBeta_()
{
    local currentSetting="$(Get_Custom_Setting "FW_Allow_Beta_Production_Up")"

    if [ "$currentSetting" = "ENABLED" ]
    then
        printf "${REDct}*WARNING*${NOct}\n"
        printf "Disabling firmware updates from beta to production releases may limit access to new features and fixes.\n"
        printf "Keep this option ENABLED if you prefer to stay up-to-date with the latest production releases.\n"

        if _WaitForYESorNO_ "\nProceed to ${REDct}DISABLE${NOct}?"
        then
            Update_Custom_Settings "FW_Allow_Beta_Production_Up" "DISABLED"
            printf "Firmware updates from beta to production releases are now ${REDct}DISABLED.${NOct}\n"
        else
            printf "Firmware updates from beta to production releases remain ${GRNct}ENABLED.${NOct}\n"
        fi
    else
        printf "Confirm to enable firmware updates from beta to production."
        if _WaitForYESorNO_ "\nProceed to ${GRNct}ENABLE${NOct}?"
        then
            Update_Custom_Settings "FW_Allow_Beta_Production_Up" "ENABLED"
            printf "Firmware updates from beta to production releases are now ${GRNct}ENABLED.${NOct}\n"
        else
            printf "Firmware updates from beta to production releases remain ${REDct}DISABLED.${NOct}\n"
        fi
    fi
    _WaitForEnterKey_
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-27] ##
##----------------------------------------##
_Toggle_Auto_Backups_()
{
    local currentSetting="$(Get_Custom_Setting "FW_Auto_Backupmon")"

    if [ "$currentSetting" = "ENABLED" ]
    then
        printf "${REDct}*WARNING*${NOct}\n"
        printf "Disabling automatic backups may risk data loss or inconsistency.\n"
        printf "The advice is to proceed only if you're sure you want to disable auto backups.\n"

        if _WaitForYESorNO_ "\nProceed to ${REDct}DISABLE${NOct}?"
        then
            Update_Custom_Settings "FW_Auto_Backupmon" "DISABLED"
            printf "Automatic backups are now ${REDct}DISABLED.${NOct}\n"
        else
            printf "Automatic backups remain ${GRNct}ENABLED.${NOct}\n"
        fi
    else
        printf "Confirm to enable automatic backups before firmware flash."
        if _WaitForYESorNO_ "\nProceed to ${GRNct}ENABLE${NOct}?"
        then
            Update_Custom_Settings "FW_Auto_Backupmon" "ENABLED"
            printf "Automatic backups are now ${GRNct}ENABLED.${NOct}\n"
        else
            printf "Automatic backups remain ${REDct}DISABLED.${NOct}\n"
        fi
    fi
    _WaitForEnterKey_
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-21] ##
##------------------------------------------##
_ChangeBuildType_TUF_()
{
   local doReturnToMenu  buildtypechoice
   printf "Changing Flash Build Type...\n"

   # Use Get_Custom_Setting to retrieve the previous choice
   previous_choice="$(Get_Custom_Setting "TUFBuild")"

   # If the previous choice is not set, default to 'DSIABLED'
   if [ "$previous_choice" = "TBD" ]; then
       previous_choice="DISABLED"
   fi

   # Convert previous choice to a descriptive text
   if [ "$previous_choice" = "ENABLED" ]; then
       display_choice="TUF Build"
   else
       display_choice="Pure Build"
   fi

   printf "\nCurrent Build Type: ${GRNct}$display_choice${NOct}.\n"

   doReturnToMenu=false
   while true
   do
       printf "\n${SEPstr}"
       printf "\nChoose your preferred option for the build type to flash:\n"
       printf "\n  ${GRNct}1${NOct}. Original ${REDct}TUF${NOct} themed user interface${NOct}\n"
       printf "\n  ${GRNct}2${NOct}. Pure ${GRNct}non-TUF${NOct} themed user interface ${GRNct}(Recommended)${NOct}\n"
       printf "\n  ${GRNct}e${NOct}. Exit to Advanced Menu\n"
       printf "${SEPstr}\n"
       printf "[$display_choice] Enter selection:  "
       read -r choice

       [ -z "$choice" ] && break

       if echo "$choice" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       case $choice in
           1) buildtypechoice="ENABLED" ; break
              ;;
           2) buildtypechoice="DISABLED" ; break
              ;;
           *) echo ; _InvalidMenuSelection_
              ;;
       esac
   done

   "$doReturnToMenu" && return 0

   Update_Custom_Settings "TUFBuild" "$buildtypechoice"
   printf "\nThe build type to flash was updated successfully.\n"

   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-21] ##
##------------------------------------------##
_ChangeBuildType_ROG_()
{
   local doReturnToMenu  buildtypechoice
   printf "Changing Flash Build Type...\n"

   # Use Get_Custom_Setting to retrieve the previous choice
   previous_choice="$(Get_Custom_Setting "ROGBuild")"

   # If the previous choice is not set, default to 'DISABLED'
   if [ "$previous_choice" = "TBD" ]; then
       previous_choice="DISABLED"
   fi

   # Convert previous choice to a descriptive text
   if [ "$previous_choice" = "ENABLED" ]; then
       display_choice="ROG Build"
   else
       display_choice="Pure Build"
   fi

   printf "\nCurrent Build Type: ${GRNct}$display_choice${NOct}.\n"

   doReturnToMenu=false
   while true
   do
       printf "\n${SEPstr}"
       printf "\nChoose your preferred option for the build type to flash:\n"
       printf "\n  ${GRNct}1${NOct}. Original ${REDct}ROG${NOct} themed user interface${NOct}\n"
       printf "\n  ${GRNct}2${NOct}. Pure ${GRNct}non-ROG${NOct} themed user interface ${GRNct}(Recommended)${NOct}\n"
       printf "\n  ${GRNct}e${NOct}. Exit to Advanced Menu\n"
       printf "${SEPstr}\n"
       printf "[$display_choice] Enter selection:  "
       read -r choice

       [ -z "$choice" ] && break

       if echo "$choice" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       case $choice in
           1) buildtypechoice="ENABLED" ; break
              ;;
           2) buildtypechoice="DISASLED" ; break
              ;;
           *) echo ; _InvalidMenuSelection_
              ;;
       esac
   done

   "$doReturnToMenu" && return 0

   Update_Custom_Settings "ROGBuild" "$buildtypechoice"
   printf "\nThe build type to flash was updated successfully.\n"

   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-27] ##
##----------------------------------------##
_Approve_FW_Update_()
{
    local currentSetting="$(Get_Custom_Setting "FW_New_Update_Changelog_Approval")"

    if [ "$currentSetting" = "BLOCKED" ]
    then
        printf "${REDct}*WARNING*:${NOct} Found high-risk phrases in the changelog file.\n"
        printf "The advice is to approve if you've read the firmware changelog and you want to proceed with the update.\n"

        if _WaitForYESorNO_ "Do you want to ${GRNct}APPROVE${NOct} the latest firmware update?"
        then
            Update_Custom_Settings "FW_New_Update_Changelog_Approval" "APPROVED"
            printf "The latest firmware update is now ${GRNct}APPROVED.${NOct}\n"
        else
            Update_Custom_Settings "FW_New_Update_Changelog_Approval" "BLOCKED"
            printf "The latest firmware update remain ${REDct}BLOCKED.${NOct}\n"
        fi
    else
        printf "${REDct}*WARNING*:${NOct} Found high-risk phrases in the changelog file.\n"
        if _WaitForYESorNO_ "Do you want to ${REDct}BLOCK${NOct} the latest firmware update?"
        then
            Update_Custom_Settings "FW_New_Update_Changelog_Approval" "BLOCKED"
            printf "The latest firmware update is now ${REDct}BLOCKED.${NOct}\n"
        else
            Update_Custom_Settings "FW_New_Update_Changelog_Approval" "APPROVED"
            printf "The latest firmware update remain ${GRNct}APPROVED.${NOct}\n"
        fi
    fi
    _WaitForEnterKey_
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-22] ##
##----------------------------------------##
translate_schedule()
{
   minute="$(echo "$1" | cut -d' ' -f1)"
   hour="$(echo "$1" | cut -d' ' -f2)"
   day_of_month="$(echo "$1" | cut -d' ' -f3)"
   month="$(echo "$1" | cut -d' ' -f4)"
   day_of_week="$(echo "$1" | cut -d' ' -f5)"

   # Function to add ordinal suffix to day
   get_ordinal()
   {
      case $1 in
          1? | *[04-9]) echo "$1"th ;;
          *1) echo "$1"st ;;
          *2) echo "$1"nd ;;
          *3) echo "$1"rd ;;
      esac
   }

   # Helper function to translate each field
   translate_field()
   {
      local field="$1"
      local type="$2"
      case "$field" in
          '*') echo "every $type" ;;
          */*) echo "every $(echo "$field" | cut -d'/' -f2) $type(s)" ;;
          *-*) echo "from $(echo "$field" | cut -d'-' -f1) to $(echo "$field" | cut -d'-' -f2) $type(s)" ;;
          *,*) echo "$(echo "$field" | sed 's/,/, /g') $type(s)" ;;
            *) if [ "$type" = "day of the month" ]; then
                   echo "$(get_ordinal "$field") $type"
               else
                   echo "$type $field"
               fi ;;
      esac
   }

   minute_text="$(translate_field "$minute" "Minute")"
   hour_text="$(translate_field "$hour" "Hour")"
   day_of_month_text="$(translate_field "$day_of_month" "day of the month")"
   month_text="$(translate_field "$month" "month")"
   # Check specifically for "day_of_week" being "*" #
   if [ "$day_of_week" = "*" ]; then
       day_of_week_text="Any day of the week"
   else
       day_of_week_text="$(translate_field "$day_of_week" "week day")"
   fi

   # Special handling for "month" to map short abbreviations to long full names #
   month_text="$(echo "$month_text" | tr 'A-Z' 'a-z')"
   month_map1="jan:January feb:February mar:March apr:April may:May jun:June jul:July aug:August sep:September oct:October nov:November dec:December"
   for month_pair in $month_map1
   do
       month_stName="$(echo "$month_pair" | cut -d':' -f1)"
       month_lnName="$(echo "$month_pair" | cut -d':' -f2)"
       month_text="$(echo "$month_text" | sed "s/\b${month_stName}\b/$month_lnName/g")"
   done

   # Special handling for "month" to map month numbers to long full names #
   month_map2="1:January 2:February 3:March 4:April 5:May 6:June 7:July 8:August 9:September 10:October 11:November 12:December"
   for month_pair in $month_map2
   do
       month_number="$(echo "$month_pair" | cut -d':' -f1)"
       month_lnName="$(echo "$month_pair" | cut -d':' -f2)"
       month_text="$(echo "$month_text" | sed "s/\b${month_number}\b/$month_lnName/g")"
   done

   if [ "$day_of_week_text" != "Any day of the week" ]
   then
       # Special handling for "day of the week" to map short abbreviations to long full names #
       day_of_week_text="$(echo "$day_of_week_text" | tr 'A-Z' 'a-z')"
       dow_map1="sun:Sunday mon:Monday tue:Tuesday wed:Wednesday thu:Thursday fri:Friday sat:Saturday"
       for dow_pair in $dow_map1
       do
           dow_stName="$(echo "$dow_pair" | cut -d':' -f1)"
           dow_lnName="$(echo "$dow_pair" | cut -d':' -f2)"
           day_of_week_text="$(echo "$day_of_week_text" | sed "s/\b${dow_stName}\b/$dow_lnName/g")"
       done

       # Special handling for "day of the week" to map day numbers to long full names #
       dow_map2="0:Sunday 1:Monday 2:Tuesday 3:Wednesday 4:Thursday 5:Friday 6:Saturday"
       for dow_pair in $dow_map2
       do
           dow_number="$(echo "$dow_pair" | cut -d':' -f1)"
           dow_lnName="$(echo "$dow_pair" | cut -d':' -f2)"
           day_of_week_text="$(echo "$day_of_week_text" | sed "s/\b${dow_number}\b/$dow_lnName/g")"
       done
   fi

   echo "At $hour_text, and $minute_text."
   echo "$day_of_week_text, $day_of_month_text, in $month_text."
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-May-04] ##
##------------------------------------------##
_IncrementDay_()
{
    local day="$1"
    local month="$2"
    local year="$3"

    # Define number of days in each month considering leap year
    local leap_year=0
    if [ "$((year % 4))" -eq 0 ]
    then
        if [ "$((year % 100))" -ne 0 ] || [ "$((year % 400))" -eq 0 ]; then
            leap_year=1
        fi
    fi

    local days_in_feb="$((28 + leap_year))"
    local days_in_month=31

    case $month in
        4|6|9|11) days_in_month=30 ;;
        2) days_in_month="$days_in_feb" ;;
    esac

    day="$((day + 1))"
    if [ "$day" -gt "$days_in_month" ]
    then
        day=1
        month="$((month + 1))"
    fi
    if [ "$month" -gt 12 ]
    then
        month=1
        year="$((year + 1))"
    fi

    echo "$day $month $year"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Nov-26] ##
##------------------------------------------##
matches_day_of_month()
{
    local curr_dom="$1"
    local dom_expr="$2"
    local domStart  domEnd  expanded_days

    if [ "$dom_expr" = "*" ]
    then  # Matches any day of the month #
        return 0
    elif echo "$dom_expr" | grep -q '/'
    then
        # Handle step values like '*/5' or '1-15/3' #
        expanded_days="$(expand_cron_field "$dom_expr" 1 31)"
        for day in $expanded_days
        do
            if [ "$day" -eq "$curr_dom" ]
            then  # Current day matches one in the expanded list #
                return 0
            fi
        done
    elif echo "$dom_expr" | grep -q '-'
    then
        domStart="$(echo "$dom_expr" | cut -d'-' -f1)"
        domEnd="$(echo "$dom_expr" | cut -d'-' -f2)"

        if [ "$domStart" -le "$domEnd" ] && \
           [ "$curr_dom" -ge "$domStart" ] && \
           [ "$curr_dom" -le "$domEnd" ]
        then  # Current day is within the range #
            return 0
        fi
    else
        for day in $(echo "$dom_expr" | tr ',' ' ')
        do
            if [ "$day" -eq "$curr_dom" ]
            then  # Current day matches one in the list #
                return 0
            fi
        done
    fi
    return 1  # No match #
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-18] ##
##----------------------------------------##
matches_month()
{
    local curr_month="$1"
    local month_expr="$2"
    local monthStart  monthEnd  monthStartNum  monthEndNum

    _MonthNameToNumber_()
    {
        if echo "$1" | grep -qE "^([1-9]|1[0-2])$"
        then echo "$1" ; return 0 ; fi

        local monthNum="$1"
        case "$1" in
            [Jj][Aa][Nn]) monthNum=1 ;;
            [Ff][Ee][Bb]) monthNum=2 ;;
            [Mm][Aa][Rr]) monthNum=3 ;;
            [Aa][Pp][Rr]) monthNum=4 ;;
            [Mm][Aa][Yy]) monthNum=5 ;;
            [Jj][Uu][Nn]) monthNum=6 ;;
            [Jj][Uu][Ll]) monthNum=7 ;;
            [Aa][Uu][Gg]) monthNum=8 ;;
            [Ss][Ee][Pp]) monthNum=9 ;;
            [Oo][Cc][Tt]) monthNum=10 ;;
            [Nn][Oo][Vv]) monthNum=11 ;;
            [Dd][Ee][Cc]) monthNum=12 ;;
            *) ;;
        esac
        echo "$monthNum" ; return 0
    }

    if [ "$month_expr" = "*" ]
    then  # Matches any month #
        return 0
    elif echo "$month_expr" | grep -q '-'
    then
        monthStart="$(echo "$month_expr" | cut -d'-' -f1)"
        monthEnd="$(echo "$month_expr" | cut -d'-' -f2)"
        monthStartNum="$(_MonthNameToNumber_ "$monthStart")"
        monthEndNum="$(_MonthNameToNumber_ "$monthEnd")"

        if [ "$monthStartNum" -le "$monthEndNum" ] && \
           [ "$curr_month" -ge "$monthStartNum" ] && \
           [ "$curr_month" -le "$monthEndNum" ]
        then  # Current month is within the range #
            return 0
        fi
    else
        for month in $(echo "$month_expr" | tr ',' ' ')
        do
            if [ "$(_MonthNameToNumber_ "$month")" -eq "$curr_month" ]
            then  # Current month matches one in the list #
                return 0
            fi
        done
    fi
    return 1  # No match #
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Nov-26] ##
##------------------------------------------##
matches_day_of_week()
{
    local curr_dow="$1"
    local dow_expr="$2"
    local dowStart  dowEnd  dowStartNum  dowEndNum  expanded_dows

    _DayOfWeekNameToNumber_()
    {
        if echo "$1" | grep -qE "^[0-6]$"
        then echo "$1" ; return 0 ; fi

        local dowNum="$1"
        case "$1" in
            [Ss][Uu][Nn]) dowNum=0 ;;
            [Mm][Oo][Nn]) dowNum=1 ;;
            [Tt][Uu][Ee]) dowNum=2 ;;
            [Ww][Ee][Dd]) dowNum=3 ;;
            [Tt][Hh][Uu]) dowNum=4 ;;
            [Ff][Rr][Ii]) dowNum=5 ;;
            [Ss][Aa][Tt]) dowNum=6 ;;
            *) ;;
        esac
        echo "$dowNum" ; return 0
    }

    if [ "$dow_expr" = "*" ]
    then  # Matches any day of the week #
        return 0
    elif echo "$dow_expr" | grep -q '/'
    then
        # Handle step values like '*/2' or '1-5/2' #
        expanded_dows="$(expand_cron_field "$dow_expr" 0 6)"
        for dow in $expanded_dows
        do
            if [ "$dow" -eq "$curr_dow" ]
            then  # Current day of the week matches one in the expanded list #
                return 0
            fi
        done
    elif echo "$dow_expr" | grep -q '-'
    then
        dowStart="$(echo "$dow_expr" | cut -d'-' -f1)"
        dowEnd="$(echo "$dow_expr" | cut -d'-' -f2)"
        dowStartNum="$(_DayOfWeekNameToNumber_ "$dowStart")"
        dowEndNum="$(_DayOfWeekNameToNumber_ "$dowEnd")"
        if [ "$dowStartNum" -gt "$dowEndNum" ]
        then
            dow_expr="$dowStartNum"
            while true
            do
                dowStartNum="$((dowStartNum + 1))"
                [ "$dowStartNum" -ge 7 ] && dowStartNum=0
                dow_expr="${dow_expr},$dowStartNum"
                [ "$dowStartNum" -eq "$dowEndNum" ] && break
            done
            if matches_day_of_week "$curr_dow" "$dow_expr"
            then return 0
            else return 1
            fi
        elif [ "$dowStartNum" -le "$dowEndNum" ] && \
             [ "$curr_dow" -ge "$dowStartNum" ] && \
             [ "$curr_dow" -le "$dowEndNum" ]
        then  # Current day of the week is within the range #
            return 0
        fi
    else
        for day in $(echo "$dow_expr" | tr ',' ' ')
        do
            if [ "$(_DayOfWeekNameToNumber_ "$day")" -eq "$curr_dow" ]
            then  # Current day of the week matches one in the list #
                return 0
            fi
        done
    fi
    return 1  # No match #
}

expand_cron_field()
{
    local field="$1"
    local min="$2"
    local max="$3"
    local range_part  step  start  end  num

    if echo "$field" | grep -q '/'
    then
        range_part="${field%/*}"
        step="${field##*/}"
        start="$min"
        end="$max"

        if echo "$range_part" | grep -q '-'
        then
            start="${range_part%-*}"
            end="${range_part#*-}"
        fi

        num="$start"
        while [ "$num" -le "$end" ]
        do
            echo "$num"
            num="$((num + step))"
        done
    elif echo "$field" | grep -q '-'
    then
        start="${field%-*}"
        end="${field#*-}"
        num="$start"
        while [ "$num" -le "$end" ]
        do
            echo "$num"
            num="$((num + 1))"
        done
    elif [ "$field" = "*" ]
    then
        num="$min"
        while [ "$num" -le "$max" ]
        do
            echo "$num"
            num="$((num + 1))"
        done
    else
        echo "$field"
    fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jun-10] ##
##------------------------------------------##
_EstimateNextCronTimeAfterDate_()
{
    local post_date_secs="$1"
    local cron_schedule="$2"
    local minute_field="$(echo "$cron_schedule" | awk '{print $1}')"
    local hour_field="$(echo "$cron_schedule" | awk '{print $2}')"
    local dom_field="$(echo "$cron_schedule" | awk '{print $3}')"
    local month_field="$(echo "$cron_schedule" | awk '{print $4}')"
    local dow_field="$(echo "$cron_schedule" | awk '{print $5}')"
    local day  month  year  hour  minute  dow

    eval $(date '+day=%d month=%m year=%Y hour=%H minute=%M dow=%u' -d "@$post_date_secs")
    local current_day="$(echo "$day" | sed 's/^0*\([0-9]\)/\1/')"
    local current_month="$(echo "$month" | sed 's/^0*\([0-9]\)/\1/')"
    local current_year="$year"
    local current_hour="$(echo "$hour" | sed 's/^0*\([0-9]\)/\1/')"
    local current_minute="$(echo "$minute" | sed 's/^0*\([0-9]\)/\1/')"
    local current_dow="$((dow % 7))"  # Adjusting so Sunday is 0

    # Apply default values if variables are empty
    current_day="${current_day:-0}"
    current_month="${current_month:-0}"
    current_hour="${current_hour:-0}"
    current_minute="${current_minute:-0}"

    local found=false  loopCount=0  maxLoopCount=120

    while [ "$found" = "false" ]
    do
        loopCount="$((loopCount + 1))"

        if matches_month "$current_month" "$month_field" && \
           matches_day_of_month "$current_day" "$dom_field" && \
           matches_day_of_week "$current_dow" "$dow_field"
        then
            for this_hour in $(expand_cron_field "$hour_field" 0 23)
            do
                if [ "$this_hour" -gt "$current_hour" ]
                then
                    for this_min in $(expand_cron_field "$minute_field" 0 59)
                    do
                        echo "$(date -d "@$(date '+%s' -d "$current_year-$current_month-$current_day $this_hour:$this_min")" '+%Y-%m-%d %H:%M:%S')"
                        found=true
                        return 0
                    done
                elif [ "$this_hour" -eq "$current_hour" ]
                then
                    for this_min in $(expand_cron_field "$minute_field" 0 59)
                    do
                        if [ "$this_min" -ge "$current_minute" ]
                        then
                            echo "$(date -d "@$(date '+%s' -d "$current_year-$current_month-$current_day $this_hour:$this_min")" '+%Y-%m-%d %H:%M:%S')"
                            found=true
                            return 0
                        fi
                    done
                fi
            done
        fi
        if [ "$loopCount" -gt "$maxLoopCount" ]
        then  # Avoid possible endless loop at this point #
            echo "$CRON_UNKNOWN_DATE"
            return 1
        fi
        # Increment the day and check again #
        set -- $(_IncrementDay_ "$current_day" "$current_month" "$current_year")
        current_day="$1"
        current_month="$2"
        current_year="$3"
        current_dow="$(date '+%u' -d "$current_year-$current_month-$current_day" | awk '{print $1%7}')"  # Recalculate day of the week
        current_hour=0  # Reset hours and minutes for the new day
        current_minute=0
    done
}

_Calculate_DST_()
{
   local notifyTimeStrn notifyTimeSecs currentTimeSecs dstAdjustSecs dstAdjustDays
   local postponeTimeSecs fwNewUpdatePostponementDays

   notifyTimeStrn="$1"

   currentTimeSecs="$(date +%s)"
   notifyTimeSecs="$(date +%s -d "$notifyTimeStrn")"

   # Adjust for DST discrepancies
   if [ "$(date -d @$currentTimeSecs +'%Z')" = "$(date -d @$notifyTimeSecs +'%Z')" ]
   then dstAdjustSecs=86400  # 24-hour day is same as always
   else dstAdjustSecs=82800  # 23-hour day only when DST happens
   fi

   fwNewUpdatePostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days)"
   dstAdjustDays="$((fwNewUpdatePostponementDays - 1))"
   if [ "$dstAdjustDays" -eq 0 ]
   then postponeTimeSecs="$dstAdjustSecs"
   else postponeTimeSecs="$(((dstAdjustDays * 86400) + dstAdjustSecs))"
   fi

   echo "$((notifyTimeSecs + postponeTimeSecs))"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jun-10] ##
##------------------------------------------##
_Calculate_NextRunTime_()
{
    local fwNewUpdateVersion  fwNewUpdateNotificationDate
    local upfwDateTimeSecs  nextCronTimeSecs

    # Check for available firmware update
    if ! fwNewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"; then
        fwNewUpdateVersion="NONE FOUND"
    fi

    ExpectedFWUpdateRuntime="$(Get_Custom_Setting FW_New_Update_Expected_Run_Date)"

    # Determine appropriate messaging based on the firmware update availability and check state
    if [ "$FW_UpdateCheckState" -eq 0 ]
    then
        ExpectedFWUpdateRuntime="${REDct}NO CRON JOB${NOct}"
    elif [ "$fwNewUpdateVersion" = "NONE FOUND" ]
    then
        ExpectedFWUpdateRuntime="${REDct}NONE FOUND${NOct}"
    elif [ "$ExpectedFWUpdateRuntime" = "TBD" ] || [ -z "$ExpectedFWUpdateRuntime" ]
    then
        # If conditions are met (cron job enabled and update available), calculate the next runtime
        fwNewUpdateNotificationDate="$(Get_Custom_Setting FW_New_Update_Notification_Date)"
        if [ "$fwNewUpdateNotificationDate" = "TBD" ] || [ -z "$fwNewUpdateNotificationDate" ]
        then
            fwNewUpdateNotificationDate="$(date +%Y-%m-%d_%H:%M:%S)"
        fi
        upfwDateTimeSecs="$(_Calculate_DST_ "$(echo "$fwNewUpdateNotificationDate" | sed 's/_/ /g')")"
        ExpectedFWUpdateRuntime="$(_EstimateNextCronTimeAfterDate_ "$upfwDateTimeSecs" "$FW_UpdateCronJobSchedule")"
        if [ "$ExpectedFWUpdateRuntime" = "$CRON_UNKNOWN_DATE" ]
        then
            Update_Custom_Settings FW_New_Update_Expected_Run_Date "TBD"
            ExpectedFWUpdateRuntime="${REDct}UNKNOWN${NOct}"
        else
            Update_Custom_Settings FW_New_Update_Expected_Run_Date "$ExpectedFWUpdateRuntime"
            ExpectedFWUpdateRuntime="${GRNct}$ExpectedFWUpdateRuntime${NOct}"
        fi
    else
        ExpectedFWUpdateRuntime="${GRNct}$ExpectedFWUpdateRuntime${NOct}"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------##
_AddFWAutoUpdateCronJob_()
{
   local newSchedule  newSetting  retCode=1
   if [ $# -gt 0 ] && [ -n "$1" ]
   then
       newSetting=true
       newSchedule="$1"
   else
       newSetting=false
       newSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
   fi
   if [ -z "$newSchedule" ] || [ "$newSchedule" = "TBD" ]
   then
       newSchedule="$FW_Update_CRON_DefaultSchedule"
   fi

   cru a "$CRON_JOB_TAG" "$newSchedule $CRON_JOB_RUN"
   sleep 1
   if eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
   then
       retCode=0
       "$newSetting" && \
       Update_Custom_Settings FW_New_Update_Cron_Job_Schedule "$newSchedule"
   fi
   return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-19] ##
##-------------------------------------##
_DelFWAutoUpdateCronJob_()
{
   local retCode
   if eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
   then
       cru d "$CRON_JOB_TAG" ; sleep 1
       if eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
       then
           retCode=1
           printf "${REDct}**ERROR**${NOct}: Failed to remove cron job [${GRNct}${CRON_JOB_TAG}${NOct}].\n"
       else
           retCode=0
           printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was removed successfully.\n"
       fi
   else
       retCode=0
       printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' does not exist.\n"
   fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-27] ##
##----------------------------------------##
_GetScriptAutoUpdateCronSchedule_()
{
   local fwCronSchedule  scriptSchedDays
   local cronMINS  cronHOUR  updtMINS  updtHOUR  cronDAYM  cronDAYW

   fwCronSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
   scriptSchedDays="$(Get_Custom_Setting Script_Update_Cron_Job_SchedDays)"

   if [ -z "$fwCronSchedule" ] || [ "$fwCronSchedule" = "TBD" ]
   then
       echo "$ScriptAU_CRON_DefaultSchedule"
       return 1
   fi
   if [ -z "$scriptSchedDays" ] || [ "$scriptSchedDays" = "TBD" ]
   then scriptSchedDays="$SW_Update_CRON_DefaultSchedDays" ; fi

   updtHOUR=0 ; updtMINS=45
   cronMINS="$(echo "$fwCronSchedule" | awk -F ' ' '{print $1}')"
   cronHOUR="$(echo "$fwCronSchedule" | awk -F ' ' '{print $2}')"
   cronDAYM="$(echo "$scriptSchedDays" | awk -F ' ' '{print $1}')"
   cronDAYW="$(echo "$scriptSchedDays" | awk -F ' ' '{print $3}')"

   if [ "$cronDAYM" != "*" ] && [ "$cronDAYW" != "*" ]
   then
       cronDAYM="*" ; cronDAYW="*"
       Update_Custom_Settings Script_Update_Cron_Job_SchedDays "$SW_Update_CRON_DefaultSchedDays"
   fi

   if echo "$cronHOUR" | grep -qE "^${CRON_HOUR_RegEx}$"
   then updtHOUR="$cronHOUR"
   fi
   if echo "$cronMINS" | grep -qE "^${CRON_MINS_RegEx}$"
   then
       if  [ "$cronMINS" -ge 15 ]
       then
           updtMINS="$((cronMINS - 15))"
       else
           updtMINS="$((45 + cronMINS))"
           if [ "$updtHOUR" -eq 0 ]
           then updtHOUR=23
           else updtHOUR="$((updtHOUR - 1))"
           fi
       fi
   fi

   echo "$updtMINS $updtHOUR $cronDAYM * $cronDAYW"
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-24] ##
##----------------------------------------##
_AddScriptAutoUpdateCronJob_()
{
   local newSchedule  newSetting  retCode=1
   if [ $# -gt 0 ] && [ -n "$1" ]
   then
       newSetting=true
       newSchedule="$1"
   else
       newSetting=false
       newSchedule="$(_GetScriptAutoUpdateCronSchedule_)"
   fi
   if [ -z "$newSchedule" ] || [ "$newSchedule" = "TBD" ]
   then
       newSchedule="$ScriptAU_CRON_DefaultSchedule"
   fi

   cru a "$SCRIPT_UP_CRON_JOB_TAG" "$newSchedule $SCRIPT_UP_CRON_JOB_RUN"
   sleep 1
   if eval $cronListCmd | grep -qE "$SCRIPT_UP_CRON_JOB_RUN #${SCRIPT_UP_CRON_JOB_TAG}#$"
   then
       retCode=0
   fi
   return "$retCode"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Nov-18] ##
##---------------------------------------##
_DelScriptAutoUpdateCronJob_()
{
   local retCode
   if eval $cronListCmd | grep -qE "$SCRIPT_UP_CRON_JOB_RUN #${SCRIPT_UP_CRON_JOB_TAG}#$"
   then
       cru d "$SCRIPT_UP_CRON_JOB_TAG" ; sleep 1
       if eval $cronListCmd | grep -qE "$SCRIPT_UP_CRON_JOB_RUN #${SCRIPT_UP_CRON_JOB_TAG}#$"
       then
           retCode=1
           printf "${REDct}**ERROR**${NOct}: Failed to remove cron job [${GRNct}${SCRIPT_UP_CRON_JOB_TAG}${NOct}].\n"
       else
           retCode=0
           printf "Cron job '${GRNct}${SCRIPT_UP_CRON_JOB_TAG}${NOct}' was removed successfully.\n"
       fi
   else
       retCode=0
       printf "Cron job '${GRNct}${SCRIPT_UP_CRON_JOB_TAG}${NOct}' does not exist.\n"
   fi
   return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Oct-12] ##
##-------------------------------------##
_CheckPostponementDays_()
{
   local retCode  newPostponementDays
   newPostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days TBD)"
   if [ -z "$newPostponementDays" ] || [ "$newPostponementDays" = "TBD" ]
   then retCode=1 ; else retCode=0 ; fi
   return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Aug-06] ##
##----------------------------------------##
_Set_FW_UpdatePostponementDays_()
{
   local validNumRegExp="([0-9]|[1-9][0-9]|1[0-9][0-9])"
   local oldPostponementDays  newPostponementDays  postponeDaysStr  userInput

   oldPostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days TBD)"
   if [ -z "$oldPostponementDays" ] || [ "$oldPostponementDays" = "TBD" ]
   then
       newPostponementDays="$FW_UpdateDefaultPostponementDays"
       postponeDaysStr="Default Value: ${GRNct}${newPostponementDays}${NOct}"
   else
       newPostponementDays="$oldPostponementDays"
       postponeDaysStr="Current Value: ${GRNct}${newPostponementDays}${NOct}"
   fi

   while true
   do
       printf "\nEnter the number of days to postpone the update once a new firmware notification is made.\n"
       printf "[${theExitStr}] "
       printf "[Min=${GRNct}${FW_UpdateMinimumPostponementDays}${NOct}, Max=${GRNct}${FW_UpdateMaximumPostponementDays}${NOct}] "
       printf "[${postponeDaysStr}]:  "
       read -r userInput

       if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then break ; fi

       if echo "$userInput" | grep -qE "^${validNumRegExp}$" && \
          [ "$userInput" -ge "$FW_UpdateMinimumPostponementDays" ] && \
          [ "$userInput" -le "$FW_UpdateMaximumPostponementDays" ]
       then newPostponementDays="$userInput" ; break ; fi

       printf "\n${REDct}INVALID input.${NOct}\n"
       _WaitForEnterKey_
       clear
   done

   if [ "$newPostponementDays" != "$oldPostponementDays" ]
   then
       Update_Custom_Settings FW_New_Update_Postponement_Days "$newPostponementDays"
       echo "The number of days to postpone F/W Update was updated successfully."
       _Calculate_NextRunTime_
       _WaitForEnterKey_ "$mainMenuReturnPromptStr"
   fi
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
_TranslateCronSchedHR_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]
   then echo "ERROR" ; return 1 ; fi

   local theCronMINS  theCronHOUR  theCronDAYW  theCronDAYM
   local freqNumMINS  freqNumHOUR  freqNumDAYW  freqNumDAYM
   local hasFreqMINS  hasFreqHOUR  hasFreqDAYW  hasFreqDAYM
   local infoStrDAYS  schedInfoStr

   _IsValidNumber_()
   {
      if echo "$1" | grep -qE "^[0-9]+$"
      then return 0 ; else return 1 ; fi
   }

   _Get12HourAmPm_()
   {
      if [ $# -eq 0 ] || [ -z "$1" ]
      then echo ; return 1 ; fi
      local theHour  theMins=""  ampmTag="AM"
      theHour="$1"
      if [ $# -eq 2 ] && [ -n "$2" ]
      then theMins="$2"
      fi
      if [ "$theHour" -eq 0 ]
      then theHour=12
      elif [ "$theHour" -eq 12 ]
      then ampmTag="PM"
      elif [ "$theHour" -gt 12 ]
      then
          ampmTag="PM" ; theHour="$((theHour - 12))"
      fi
      if [ -z "$theMins" ]
      then printf "%d $ampmTag" "$theHour"
      else printf "%d:%02d $ampmTag" "$theHour" "$theMins"
      fi
   }

   theCronMINS="$(echo "$1" | awk -F ' ' '{print $1}')"
   theCronHOUR="$(echo "$1" | awk -F ' ' '{print $2}')"
   theCronDAYM="$(echo "$1" | awk -F ' ' '{print $3}')"
   theCronDAYW="$(echo "$1" | awk -F ' ' '{print $5}')"

   if [ "$theCronDAYW" = "*" ] && [ "$theCronDAYM" = "*" ]
   then
       infoStrDAYS="every day, in every month"
   elif [ "$theCronDAYW" != "*" ]
   then
       if echo "$theCronDAYW" | grep -qE "^[*]/.*"
       then
           freqNumDAYW="$(echo "$theCronDAYW" | cut -f2 -d'/')"
           infoStrDAYS="every $freqNumDAYW days of the week, in every month"
       elif echo "$theCronDAYW" | grep -qE "[,-]"
       then
           infoStrDAYS="days ${theCronDAYW}, in every month"
       else
           infoStrDAYS="day ${theCronDAYW}, in every month"
       fi
   elif [ "$theCronDAYM" != "*" ]
   then
       if echo "$theCronDAYM" | grep -qE "^[*]/.*"
       then
           freqNumDAYM="$(echo "$theCronDAYM" | cut -f2 -d'/')"
           infoStrDAYS="every $freqNumDAYM days of the month, in every month"
       elif echo "$theCronDAYM" | grep -qE "[,-]"
       then
           infoStrDAYS="days ${theCronDAYM} of the month, in every month"
       else
           infoStrDAYS="day ${theCronDAYM} of the month, in every month"
       fi
   fi

   if echo "$theCronHOUR" | grep -qE "^[*]/.*"
   then
       hasFreqHOUR=true
       freqNumHOUR="$(echo "$theCronHOUR" | cut -f2 -d'/')"
   else
       hasFreqHOUR=false ; freqNumHOUR=""
   fi
   if echo "$theCronMINS" | grep -qE "^[*]/.*"
   then
       hasFreqMINS=true
       freqNumMINS="$(echo "$theCronMINS" | cut -f2 -d'/')"
   else
       hasFreqMINS=false ; freqNumMINS=""
   fi
   if [ "$theCronHOUR" = "*" ] && [ "$theCronMINS" = "0" ]
   then
       schedInfoStr="Every hour"
   elif [ "$theCronHOUR" = "*" ] && [ "$theCronMINS" = "*" ]
   then
       schedInfoStr="Every minute"
   elif [ "$theCronHOUR" = "*" ] && _IsValidNumber_ "$theCronMINS"
   then
       schedInfoStr="Every hour at minute $theCronMINS"
   elif "$hasFreqHOUR" && [ "$theCronMINS" = "0" ]
   then
       schedInfoStr="Every $freqNumHOUR hours"
   elif "$hasFreqHOUR" && [ "$theCronMINS" = "*" ]
   then
       schedInfoStr="Every minute, every $freqNumHOUR hours"
   elif "$hasFreqHOUR" && _IsValidNumber_ "$theCronMINS"
   then
       schedInfoStr="Every $freqNumHOUR hours at minute $theCronMINS"
   elif "$hasFreqMINS" && [ "$theCronHOUR" = "*" ]
   then
       schedInfoStr="Every $freqNumMINS minutes"
   elif "$hasFreqHOUR" && "$hasFreqMINS"
   then
       schedInfoStr="Every $freqNumMINS minutes, every $freqNumHOUR hours"
   elif "$hasFreqMINS" && _IsValidNumber_ "$theCronHOUR"
   then
       schedInfoStr="$(_Get12HourAmPm_ "$theCronHOUR"), every $freqNumMINS minutes"
   elif _IsValidNumber_ "$theCronHOUR" && _IsValidNumber_ "$theCronMINS"
   then
       schedInfoStr="$(_Get12HourAmPm_ "$theCronHOUR" "$theCronMINS")"
   elif "$hasFreqHOUR"
   then
       schedInfoStr="Every $freqNumHOUR hours, Minutes: $theCronMINS"
   elif "$hasFreqMINS"
   then
       schedInfoStr="$theCronHOUR, every $freqNumMINS minutes"
   elif [ "$theCronHOUR" = "*" ]
   then
       schedInfoStr="Every hour, Minutes: $theCronMINS"
   elif [ "$theCronMINS" = "*" ]
   then
       schedInfoStr="$theCronHOUR, every minute"
   else
       schedInfoStr="$theCronHOUR, Minutes: $theCronMINS"
   fi
   echo "${schedInfoStr}, $infoStrDAYS"
}

##-------------------------------------##
## Added by Martinski W. [2024-Feb-22] ##
##-------------------------------------##
_CapitalizeFirstChar_()
{
   if [ $# -eq 0 ] && [ -z "$1" ]
   then echo "$1" ; return 1; fi

   local upperChar  capWord  origStr="$1"
   local prevIFS="$IFS"

   IFS="/,-$IFS"
   for origWord in $1
   do
       upperChar="$(echo "${origWord:0:1}" | tr 'a-z' 'A-Z')"
       if [ -n "$upperChar" ]
       then
           capWord="${upperChar}${origWord:1}"
           origStr="$(echo "$origStr" | sed "s/\b${origWord}\b/$capWord/g")"
       fi
   done
   IFS="$prevIFS"
   echo "$origStr"
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
#---------------------------------------------------#
# Allow ONLY full numbers within the range [0-59].
# All intervals, lists and ranges are INVALID for
# the purposes of checking for F/W Updates.
#---------------------------------------------------#
_ValidateCronScheduleMINS_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   if echo "$1" | grep -qE "^${CRON_MINS_RegEx}$" && \
      [ "$1" -ge 0 ] && [ "$1" -lt 60 ]
   then return 0
   fi
   printf "\n${REDct}INVALID cron value for 'MINUTE' [$1]${NOct}\n"
   printf "${REDct}NOTE${NOct}: Only numbers within the range [0-59] are valid.\n"
   printf "All other intervals, lists, and ranges are INVALID.\n"
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
#---------------------------------------------------#
# Allow ONLY full numbers within the range [0-23]
# and specific intervals [ */4  */6  */8  */12]
# for the purposes of doing F/W Updates.
# All other intervals, lists & ranges are INVALID.
#---------------------------------------------------#
_ValidateCronScheduleHOUR_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   if echo "$1" | grep -qE "^[*]/(4|6|8|12)$"
   then return 0 ; fi
   if echo "$1" | grep -qE "^${CRON_HOUR_RegEx}$" && \
      [ "$1" -ge 0 ] && [ "$1" -lt 24 ]
   then return 0
   fi
   printf "\n${REDct}INVALID cron value for 'HOUR' [$1]${NOct}\n"
   printf "${REDct}NOTE${NOct}: Only numbers within the range [0-23] and\n"
   printf "specific intervals (*/4 */6 */8 */12) are valid.\n"
   printf "All other intervals, lists, and ranges are INVALID.\n"
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-23] ##
##-------------------------------------##
_ConvertDAYW_NumToName_()
{
   if [ $# -eq 0 ] && [ -z "$1" ] ; then echo ; return 1; fi
   local rangeDays  rangeFreq
   rangeDays="$(echo "$1" | awk -F '/' '{print $1}')"
   rangeFreq="$(echo "$1" | awk -F '/' '{print $2}')"
   rangeDays="$(echo "$rangeDays" | sed 's/0/Sun/g;s/1/Mon/g;s/2/Tue/g;s/3/Wed/g;s/4/Thu/g;s/5/Fri/g;s/6/Sat/g')"
   if [ -z "$rangeFreq" ]
   then echo "$rangeDays"
   else echo "${rangeDays}/$rangeFreq"
   fi
   return 0
}

_ConvertDAYW_NameToNum_()
{
   if [ $# -eq 0 ] && [ -z "$1" ] ; then echo ; return 1; fi
   echo "$1" | sed 's/[Ss]un/0/g;s/[Mm]on/1/g;s/[Tt]ue/2/g;s/[Ww]ed/3/g;s/[Tt]hu/4/g;s/[Ff]ri/5/g;s/[Ss]at/6/g'
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
_ValidateCronNumOrderDAYW_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local numDAYS  numDays1  numDays2
   if ! echo "$1" | grep -qE "[a-zA-Z]"
   then numDAYS="$1"
   else numDAYS="$(_ConvertDAYW_NameToNum_ "$1")"
   fi
   numDays1="$(echo "$numDAYS" | awk -F '[-/]' '{print $1}')"
   numDays2="$(echo "$numDAYS" | awk -F '[-/]' '{print $2}')"
   if [ "$numDays1" -lt "$numDays2" ]
   then return 0
   else return 1
   fi
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
#---------------------------------------------------#
# Allow ONLY full numbers within the range [0-6]
# specific intervals [ *  */2  */3 ], lists and
# ranges for the purposes of doing F/W Updates.
#---------------------------------------------------#
_ValidateCronScheduleDAYofWEEK_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   if [ "$1" = "*" ] || echo "$1" | grep -qE "^[*]/(2|3)$"
   then return 0 ; fi
   if echo "$1" | grep -qE "^${CRON_DAYofWEEK_RegEx}$"
   then
       if echo "$1" | grep -q '-'
       then
           if _ValidateCronNumOrderDAYW_ "$1"
           then return 0 ; fi
       else
           return 0
       fi
   fi
   printf "\n${REDct}INVALID cron value for 'DAY of WEEK' [$1]${NOct}\n"
   printf "${REDct}NOTE${NOct}: Only numbers within the range [0-6], some\n"
   printf "specific intervals (* */2 */3), day abbreviations,\n"
   printf "lists of days, and single ranges are valid.\n"
   return 1
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
#----------------------------------------------------------#
# Allow ONLY full numbers within the range [1-31]
# some intervals [ *  */[2-9]  */10  */12  */15 ],
# lists and ranges for the purposes of doing F/W Updates.
#----------------------------------------------------------#
_ValidateCronScheduleDAYofMONTH_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   if [ "$1" = "*" ] || \
      echo "$1" | grep -qE "^[*]/([2-9]|10|12|15)$"
   then return 0 ; fi
   if echo "$1" | grep -qE "^${CRON_DAYofMONTH_RegEx}$"
   then
       if echo "$1" | grep -q '-'
       then
           local numDays1  numDays2
           numDays1="$(echo "$1" | awk -F '[-/]' '{print $1}')"
           numDays2="$(echo "$1" | awk -F '[-/]' '{print $2}')"
           if [ "$numDays1" -lt "$numDays2" ]
           then return 0 ; fi
       else
           return 0
       fi
   fi
   printf "\n${REDct}INVALID cron value for 'DAY of MONTH' [$1]${NOct}\n"
   printf "${REDct}NOTE${NOct}: Only numbers within the range [1-31],\n"
   printf "specific intervals (* */[2-9] */10 */12 */15),\n"
   printf "lists of numbers, and single ranges are valid.\n"
   return 1
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-26] ##
##----------------------------------------##
_ValidateCronJobSchedule_()
{
   local cronSchedStr  cronSchedDAYW  cronSchedDAYM  cronSchedMNTH

   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       printf "${REDct}INVALID cron schedule string: [EMPTY].${NOct}\n"
       return 1
   fi
   cronSchedStr="$(echo "$1" | awk -F ' ' '{print NF}')"
   if [ "$cronSchedStr" -ne 5 ]
   then
       printf "${REDct}INVALID cron schedule string [$1]. Incorrect number of parameters.${NOct}\n"
       return 1
   fi
   cronSchedStr="$(echo "$1" | awk -F ' ' '{print $1}')"
   if ! _ValidateCronScheduleMINS_ "$cronSchedStr"
   then return 1
   fi
   cronSchedStr="$(echo "$1" | awk -F ' ' '{print $2}')"
   if ! _ValidateCronScheduleHOUR_ "$cronSchedStr"
   then return 1
   fi
   cronSchedDAYM="$(echo "$1" | awk -F ' ' '{print $3}')"
   if ! _ValidateCronScheduleDAYofMONTH_ "$cronSchedDAYM"
   then return 1
   fi
   cronSchedMNTH="$(echo "$1" | awk -F ' ' '{print $4}')"
   if ! echo "$cronSchedMNTH" | grep -qiE "^(${CRON_MONTH_RegEx})$"
   then
       printf "\n${REDct}INVALID cron value for 'MONTH' [$cronSchedMNTH]${NOct}\n"
       return 1
   fi
   cronSchedDAYW="$(echo "$1" | awk -F ' ' '{print $5}')"
   if ! _ValidateCronScheduleDAYofWEEK_ "$cronSchedDAYW"
   then return 1
   fi
   if [ "$cronSchedDAYW" != "*" ] && [ "$cronSchedDAYM" != "*" ]
   then
       printf "\n${REDct}INVALID cron value for 'DAY of WEEK' [$cronSchedDAYW] or 'DAY of MONTH' [$cronSchedDAYM]${NOct}\n"
       printf "One of them MUST be set to a 'daily' value [${GRNct}*${NOct}=daily].\n"
       return 1
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-24] ##
##----------------------------------------##
_Set_FW_UpdateCronScheduleCustom_()
{
    printf "\nChanging Firmware Auto Update Schedule...\n"

    local currCronSchedule  nextCronSchedule  userInput  retCode=1

    currCronSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
    if [ -z "$currCronSchedule" ] || [ "$currCronSchedule" = "TBD" ]
    then
        nextCronSchedule=""
        currCronSchedule="$FW_UpdateCronJobSchedule"
    else
        nextCronSchedule="$currCronSchedule"
        # Translate the current schedule to English (human readable form) #
        current_schedule_english="$(translate_schedule "$currCronSchedule")"
        printf "Current Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
    fi

    while true
    do
        printf "\nEnter new cron job schedule (e.g. '${GRNct}0 0 * * Sun${NOct}' for every Sunday at midnight)"
        if [ -z "$currCronSchedule" ]
        then printf "\n[${theADExitStr}]\n[Default Schedule: ${GRNct}${nextCronSchedule}${NOct}]:  "
        else printf "\n[${theADExitStr}]\n[Current Schedule: ${GRNct}${currCronSchedule}${NOct}]:  "
        fi
        read -r userInput

        # If the user enters 'e', break out of the loop and return to the main menu
        if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
        then
            ! _ValidateCronJobSchedule_ "$currCronSchedule" && continue

            # Capitalize 1st char of any abbreviated short names #
            currCronSchedule="$(_CapitalizeFirstChar_ "$currCronSchedule")"
            currCronSchedule="$(echo "$currCronSchedule" | awk -F ' ' '{print $1, $2, $3, $4, $5}')"
            break
        fi

        if _ValidateCronJobSchedule_ "$userInput"
        then
            # Capitalize 1st char of any abbreviated short names #
            nextCronSchedule="$(_CapitalizeFirstChar_ "$userInput")"
            nextCronSchedule="$(echo "$nextCronSchedule" | awk -F ' ' '{print $1, $2, $3, $4, $5}')"
            break
        fi
    done

    [ "$nextCronSchedule" = "$currCronSchedule" ] && return 1

    FW_UpdateCheckState="$(nvram get firmware_check_enable)"
    [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
    if [ "$FW_UpdateCheckState" -eq 1 ]
    then
        # Add/Update cron job ONLY if "F/W Update Check" is enabled #
        printf "Updating '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
        if _AddFWAutoUpdateCronJob_ "$nextCronSchedule"
        then
            retCode=0
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was updated successfully.\n"
            current_schedule_english="$(translate_schedule "$nextCronSchedule")"
            printf "Job Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
            _Calculate_NextRunTime_
        else
            retCode=1
            printf "${REDct}**ERROR**${NOct}: Failed to add/update the cron job [${CRON_JOB_TAG}].\n"
        fi
    else
        retCode=0
        Update_Custom_Settings FW_New_Update_Cron_Job_Schedule "$nextCronSchedule"
        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was configured but not added.\n"
        printf "Firmware Update Check is currently ${REDct}DISABLED${NOct}.\n"
    fi

    if [ "$ScriptAutoUpdateSetting" = "ENABLED" ]
    then
        _AddScriptAutoUpdateCronJob_
    fi

    _WaitForEnterKey_ "$advnMenuReturnPromptStr"
    return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
_CheckForSavedThenExitMenu_()
{ if echo "$1" | grep -qE "^([Ss]|se|save)$" ; then return 0 ; else return 1 ; fi ; }
   
_CheckForCancelAndExitMenu_()
{ if echo "$1" | grep -qE "^([Ee]|ce|exit)$" ; then return 0 ; else return 1 ; fi ; }

_CheckForReturnToBeginMenu_()
{ if echo "$1" | grep -qE "^([Bb]|be|begin)$" ; then return 0 ; else return 1 ; fi ; }

_ShowCronMenuHeader_()
{
   clear
   _ShowLogo_
   printf "================ F/W Update Check Schedule ===============\n"
   printf "${SEPstr}\n"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-20] ##
##----------------------------------------##
_GetCronScheduleInputDAYofMONTH_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local oldSchedDAYM  newSchedDAYM  oldSchedDAYHR

   _GetSchedDaysHR_()
   {
      local cruDAYS="$1"
      [ "$1" = "*" ] && cruDAYS="Every day"
      echo "$cruDAYS"
   }

   newSchedDAYM=""
   oldSchedDAYM="$1"
   oldSchedDAYHR="$(_GetSchedDaysHR_ "$1")"

   while true
   do
       _ShowCronMenuHeader_
       printf "\nCurrent Schedule: ${GRNct}\"${cronSchedTmpStr}\"${NOct}"
       printf "\n[${GRNct}${cronSchedStrHR}${NOct}]\n"
       printf "\nThe DAYS of the MONTH when to run the cron job for Automatic F/W Updates.\n"
       printf "\nExamples:\n"
       printf "   ${GRNct}*${NOct}=Every day   ${GRNct}*/3${NOct}=Every 3 days   ${GRNct}*/5${NOct}=Every 5 days\n"
       printf "   ${GRNct}*/7${NOct}=Every 7 days   ${GRNct}*/10${NOct}=Every 10 days  ${GRNct}*/15${NOct}=Every 15 days\n"

       printf "\n[${menuCancelAndExitStr}]\n"
       printf "\nEnter ${GRNct}DAYS of the MONTH${NOct} [1-31] ${GRNct}${oldSchedDAYHR}${NOct}?: "
       read -r newSchedDAYM
       if [ -z "$newSchedDAYM" ]
       then
           newSchedDAYM="$oldSchedDAYM"
           if _ValidateCronScheduleDAYofMONTH_ "$oldSchedDAYM"
           then break  #Keep Current Value#
           fi
       elif _CheckForCancelAndExitMenu_ "$newSchedDAYM" || \
            _ValidateCronScheduleDAYofMONTH_ "$newSchedDAYM"
       then break
       fi
       _WaitForEnterKey_
   done
   nextSchedDAYM="$newSchedDAYM"
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Dec-20] ##
##----------------------------------------##
_GetCronScheduleInputDAYofWEEK_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local oldSchedDAYW  newSchedDAYW  oldSchedDAYHR

   _DayOfWeekNumToDayName_()
   { echo "$1" | sed 's/0/Sun/;s/1/Mon/;s/2/Tue/;s/3/Wed/;s/4/Thu/;s/5/Fri/;s/6/Sat/;' ; }

   _GetSchedDaysHR_()
   {
      local cruDAYS="$1"
      if [ "$1" = "*" ]
      then cruDAYS="Every day"
      elif ! echo "$1" | grep -qE "^[*]/.*"
      then cruDAYS="$(_DayOfWeekNumToDayName_ "$1")" 
      fi
      echo "$cruDAYS"
   }

   newSchedDAYW=""
   oldSchedDAYW="$1"
   oldSchedDAYHR="$(_GetSchedDaysHR_ "$1")"

   while true
   do
       _ShowCronMenuHeader_
       printf "\nCurrent Schedule: ${GRNct}\"${cronSchedTmpStr}\"${NOct}"
       printf "\n[${GRNct}${cronSchedStrHR}${NOct}]\n"
       printf "\nThe DAYS of the WEEK when to run the cron job for Automatic F/W Updates.\n"
       printf "\nExamples:\n"
       printf "   ${GRNct}*${NOct}=Every day   ${GRNct}*/2${NOct}=Every 2 days   ${GRNct}*/3${NOct}=Every 3 days\n"
       printf "   ${GRNct}0${NOct}=Sun, ${GRNct}1${NOct}=Mon, ${GRNct}2${NOct}=Tue, "
       printf "${GRNct}3${NOct}=Wed, ${GRNct}4${NOct}=Thu, ${GRNct}5${NOct}=Fri, ${GRNct}6${NOct}=Sat\n"
       printf "   ${GRNct}6,0${NOct}=Sat,Sun   ${GRNct}1,3,5${NOct}=Mon,Wed,Fri   ${GRNct}2,4${NOct}=Tue,Thu\n"

       printf "\n[${menuCancelAndExitStr}] [${menuSavedThenExitStr}] [${menuReturnToBeginStr}]\n"
       printf "\nEnter ${GRNct}DAYS of the WEEK${NOct} [0-6] ${GRNct}${oldSchedDAYHR}${NOct}?: "
       read -r newSchedDAYW
       if [ -z "$newSchedDAYW" ]
       then
           newSchedDAYW="$oldSchedDAYW"
           if _ValidateCronScheduleDAYofWEEK_ "$oldSchedDAYW"
           then break  #Keep Current Value#
           fi
       elif _CheckForCancelAndExitMenu_ "$newSchedDAYW" || \
            _CheckForReturnToBeginMenu_ "$newSchedDAYW" || \
            _CheckForSavedThenExitMenu_ "$newSchedDAYW"
       then break
       elif _ValidateCronScheduleDAYofWEEK_ "$newSchedDAYW"
       then
           if echo "$newSchedDAYW" | grep -qE "[fmstw]"
           then
               newSchedDAYW="$(_CapitalizeFirstChar_ "$newSchedDAYW")"
           elif ! echo "$newSchedDAYW" | grep -q '[*/]' && \
                echo "$newSchedDAYW" | grep -q "[0-6]"
           then
               newSchedDAYW="$(_ConvertDAYW_NumToName_ "$newSchedDAYW")"
           fi
           break
       fi
       _WaitForEnterKey_
   done
   nextSchedDAYW="$newSchedDAYW"
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
#---------------------------------------------------#
# Allow ONLY full numbers within the range: [0-23]
# and specific intervals [ */4  */6  */8  */12 ]
# for the purposes of doing F/W Updates.
# All other intervals, lists & ranges are INVALID.
#---------------------------------------------------#
_GetCronScheduleInputHOUR_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local oldSchedHOUR="$1"  newSchedHOUR

   newSchedHOUR=""
   while true
   do
       _ShowCronMenuHeader_
       printf "\nCurrent Schedule: ${GRNct}\"${cronSchedTmpStr}\"${NOct}"
       printf "\n[${GRNct}${cronSchedStrHR}${NOct}]\n"
       printf "\nThe HOUR when to run the cron job for Automatic F/W Updates.\n"
       printf "\nExamples:\n"
       printf "   ${GRNct}0${NOct}=12:00AM   ${GRNct}23${NOct}=11:00PM"
       printf "   ${GRNct}*/8${NOct}=Every 8 hours   ${GRNct}*/12${NOct}=Every 12 hours\n"

       printf "\n[${menuCancelAndExitStr}] [${menuSavedThenExitStr}] [${menuReturnToBeginStr}]\n"
       printf "\nEnter ${GRNct}HOUR${NOct} [0-23] ${GRNct}${oldSchedHOUR}${NOct}?: "
       read -r newSchedHOUR
       if [ -z "$newSchedHOUR" ]
       then
           newSchedHOUR="$oldSchedHOUR"
           if _ValidateCronScheduleHOUR_ "$oldSchedHOUR"
           then break  #Keep Current Value#
           fi
       elif _CheckForCancelAndExitMenu_ "$newSchedHOUR" || \
            _CheckForReturnToBeginMenu_ "$newSchedHOUR" || \
            _CheckForSavedThenExitMenu_ "$newSchedHOUR" || \
            _ValidateCronScheduleHOUR_  "$newSchedHOUR"
       then break
       fi
       _WaitForEnterKey_
   done
   nextSchedHOUR="$newSchedHOUR"
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
#---------------------------------------------------#
# Allow ONLY full numbers within the range [0-59].
# All intervals, lists and ranges are INVALID for
# the purposes of checking for F/W Updates.
#---------------------------------------------------#
_GetCronScheduleInputMINS_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local oldSchedMINS="$1"  newSchedMINS

   newSchedMINS=""
   while true
   do
       _ShowCronMenuHeader_
       printf "\nCurrent Schedule: ${GRNct}\"${cronSchedTmpStr}\"${NOct}"
       printf "\n[${GRNct}${cronSchedStrHR}${NOct}]\n"
       printf "\nThe MINUTE when to run the cron job for Automatic F/W Updates.\n"

       printf "\n[${menuCancelAndExitStr}] [${menuSavedThenExitStr}] [${menuReturnToBeginStr}]\n"
       printf "\nEnter ${GRNct}MINUTE${NOct} [0-59] ${GRNct}${oldSchedMINS}${NOct}?: "
       read -r newSchedMINS
       if [ -z "$newSchedMINS" ]
       then
           newSchedMINS="$oldSchedMINS"
           if _ValidateCronScheduleMINS_ "$oldSchedMINS"
           then break  #Keep Current Value#
           fi
       elif _CheckForCancelAndExitMenu_ "$newSchedMINS" || \
            _CheckForReturnToBeginMenu_ "$newSchedMINS" || \
            _CheckForSavedThenExitMenu_ "$newSchedMINS" || \
            _ValidateCronScheduleMINS_  "$newSchedMINS"
       then break
       fi
       _WaitForEnterKey_
   done
   nextSchedMINS="$newSchedMINS"
   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
_Set_FW_UpdateCronScheduleGuided_()
{
   local cronSchedInfo  currCronSched  nextCronSched
   local cronSchedMINS  cronSchedHOUR  cronSchedDAYW  cronSchedDAYM  cronSchedMNTH
   local nextSchedMINS  nextSchedHOUR  nextSchedDAYW  nextSchedDAYM  nextSchedMNTH
   local savedThenExit  cronSchedStrHR  cronSchedTmpStr  retCode=1

   currCronSched="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
   if [ -z "$currCronSched" ] || [ "$currCronSched" = "TBD" ]
   then
       currCronSched="$FW_UpdateCronJobSchedule"
   fi

   cronSchedMINS="$(echo "$currCronSched" | awk -F ' ' '{print $1}')"
   cronSchedHOUR="$(echo "$currCronSched" | awk -F ' ' '{print $2}')"
   cronSchedDAYM="$(echo "$currCronSched" | awk -F ' ' '{print $3}')"
   cronSchedDAYW="$(echo "$currCronSched" | awk -F ' ' '{print $5}')"

   ## MONTH is FIXED to "every month" for F/W Update Purposes ##
   cronSchedMNTH="*" ; nextSchedMNTH="*"

   _ClearCronSchedValues_()
   {
      nextSchedMINS=""
      nextSchedHOUR=""
      nextSchedDAYM=""
      nextSchedDAYW=""
   }

   _ResetCronSchedValues_()
   {
      nextSchedMINS="$cronSchedMINS"
      nextSchedHOUR="$cronSchedHOUR"
      nextSchedDAYM="$cronSchedDAYM"
      nextSchedDAYW="$cronSchedDAYW"
   }

   nextCronSched=""
   savedThenExit=false
   _ResetCronSchedValues_

   while true
   do
       cronSchedTmpStr="$nextSchedMINS $nextSchedHOUR $nextSchedDAYM $nextSchedMNTH $nextSchedDAYW"
       cronSchedStrHR="$(_TranslateCronSchedHR_ "$cronSchedTmpStr")"
       _GetCronScheduleInputDAYofMONTH_ "$cronSchedDAYM"
       if _CheckForCancelAndExitMenu_ "$nextSchedDAYM"
       then _ClearCronSchedValues_ ; break
       fi

       if [ "$nextSchedDAYM" = "*" ]
       then
           cronSchedTmpStr="$nextSchedMINS $nextSchedHOUR $nextSchedDAYM $nextSchedMNTH $nextSchedDAYW"
           cronSchedStrHR="$(_TranslateCronSchedHR_ "$cronSchedTmpStr")"
           _GetCronScheduleInputDAYofWEEK_ "$cronSchedDAYW"
           if _CheckForCancelAndExitMenu_ "$nextSchedDAYW"
           then _ClearCronSchedValues_ ; break
           fi
           if _CheckForReturnToBeginMenu_ "$nextSchedDAYW"
           then _ResetCronSchedValues_ ; continue
           fi
           if _CheckForSavedThenExitMenu_ "$nextSchedDAYW"
           then
               savedThenExit=true
               nextSchedDAYW="$cronSchedDAYW"
               break
           fi
       else
           nextSchedDAYW="*"
       fi

       cronSchedTmpStr="$nextSchedMINS $nextSchedHOUR $nextSchedDAYM $nextSchedMNTH $nextSchedDAYW"
       cronSchedStrHR="$(_TranslateCronSchedHR_ "$cronSchedTmpStr")"
       _GetCronScheduleInputHOUR_ "$cronSchedHOUR"
       if _CheckForCancelAndExitMenu_ "$nextSchedHOUR"
       then _ClearCronSchedValues_ ; break
       fi
       if _CheckForReturnToBeginMenu_ "$nextSchedHOUR"
       then _ResetCronSchedValues_ ; continue
       fi
       if _CheckForSavedThenExitMenu_ "$nextSchedHOUR"
       then
           savedThenExit=true
           nextSchedHOUR="$cronSchedHOUR"
           break
       fi

       cronSchedTmpStr="$nextSchedMINS $nextSchedHOUR $nextSchedDAYM $nextSchedMNTH $nextSchedDAYW"
       cronSchedStrHR="$(_TranslateCronSchedHR_ "$cronSchedTmpStr")"
       _GetCronScheduleInputMINS_ "$cronSchedMINS"
       if _CheckForCancelAndExitMenu_ "$nextSchedMINS"
       then _ClearCronSchedValues_ ; break
       fi
       if _CheckForReturnToBeginMenu_ "$nextSchedMINS"
       then _ResetCronSchedValues_ ; continue
       fi
       if _CheckForSavedThenExitMenu_ "$nextSchedMINS"
       then
           savedThenExit=true
           nextSchedMINS="$cronSchedMINS"
           break
       fi

       if [ -n "$nextSchedMINS" ] || \
          [ -n "$nextSchedHOUR" ] || \
          [ -n "$nextSchedDAYM" ] || \
          [ -n "$nextSchedDAYW" ]
       then savedThenExit=true
       else savedThenExit=false
       fi
       break
   done

   if "$savedThenExit" && \
      { [ "$nextSchedMINS" != "$cronSchedMINS" ] || \
        [ "$nextSchedHOUR" != "$cronSchedHOUR" ] || \
        [ "$nextSchedDAYM" != "$cronSchedDAYM" ] || \
        [ "$nextSchedDAYW" != "$cronSchedDAYW" ]
      }
   then
       if [ -n "$nextSchedMINS" ]
       then nextCronSched="$nextSchedMINS"
       else nextCronSched="$cronSchedMINS"
       fi
       if [ -n "$nextSchedHOUR" ]
       then nextCronSched="$nextCronSched $nextSchedHOUR"
       else nextCronSched="$nextCronSched $cronSchedHOUR"
       fi
       if [ -n "$nextSchedDAYM" ]
       then nextCronSched="$nextCronSched $nextSchedDAYM"
       else nextCronSched="$nextCronSched $cronSchedDAYM"
       fi
       ## MONTH is FIXED for F/W Update Purposes ##
       nextCronSched="$nextCronSched $nextSchedMNTH"
       ##
       if [ -n "$nextSchedDAYW" ]
       then nextCronSched="$nextCronSched $nextSchedDAYW"
       else nextCronSched="$nextCronSched $cronSchedDAYW"
       fi
       cronSchedStrHR="$(_TranslateCronSchedHR_ "$nextCronSched")"
       printf "\nNew Schedule: ${GRNct}\"${nextCronSched}\"${NOct}"
       printf "\n[${GRNct}${cronSchedStrHR}${NOct}]\n"
       _WaitForEnterKey_
   else
       nextCronSched="$currCronSched"
   fi

   [ "$nextCronSched" = "$currCronSched" ] && return 1

   FW_UpdateCheckState="$(nvram get firmware_check_enable)"
   [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
   if [ "$FW_UpdateCheckState" -eq 1 ]
   then
       # Add/Update cron job ONLY if "F/W Update Check" is enabled #
       printf "Updating '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
       if _AddFWAutoUpdateCronJob_ "$nextCronSched"
       then
            retCode=0
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was updated successfully.\n"
            cronSchedStrHR="$(_TranslateCronSchedHR_ "$nextCronSched")"
            printf "Job Schedule: ${GRNct}${cronSchedStrHR}${NOct}\n"
            _Calculate_NextRunTime_
       else
            retCode=1
            printf "${REDct}**ERROR**${NOct}: Failed to add/update the cron job [${CRON_JOB_TAG}].\n"
       fi
   else
       retCode=0
       Update_Custom_Settings FW_New_Update_Cron_Job_Schedule "$nextCronSched"
       printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was configured but not added.\n"
       printf "Firmware Update Check is currently ${REDct}DISABLED${NOct}.\n"
   fi

   if [ "$ScriptAutoUpdateSetting" = "ENABLED" ]
   then
       _AddScriptAutoUpdateCronJob_
   fi

   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
   return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2024-Nov-24] ##
##-------------------------------------##
_Set_FW_AutoUpdateCronSchedule_()
{
   local doReturnToMenu=false

   while true
   do
       printf "\n${SEPstr}"
       printf "\nChoose the method to input the cron schedule for F/W Updates:\n"
       printf "\n  ${GRNct}1${NOct}. Menu-Guided Entry\n"
       printf "\n  ${GRNct}2${NOct}. Custom Input/Entry\n"
       printf "\n  ${GRNct}e${NOct}. Exit to Advanced Menu\n"
       printf "${SEPstr}\n"
       printf "Enter selection:  " ; read -r userInput
       if [ -z "$userInput" ] || \
          echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then break ; fi

       case $userInput in
           1) if _Set_FW_UpdateCronScheduleGuided_
              then break ; fi
              ;;
           2) if _Set_FW_UpdateCronScheduleCustom_
              then break ; fi
              ;;
           *) echo ; _InvalidMenuSelection_
           ;;
       esac

       "$doReturnToMenu" && break
   done
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-26] ##
##----------------------------------------##
_Toggle_ScriptAutoUpdate_Config_()
{
    local currentSetting  scriptUpdateCronSched  cronSchedStrHR
    local keepOptionDisabled=false  retCode=1

    currentSetting="$(Get_Custom_Setting "Allow_Script_Auto_Update")"

    if [ "$currentSetting" = "DISABLED" ]
    then
        printf "\n${REDct}*NOTICE*${NOct}\n"
        printf "Enabling this feature allows the MerlinAU script to self-update automatically\n"
        printf "without user action when a newer version becomes available. This means both the\n"
        printf "script and the firmware updates become fully automatic. Proceed with caution.\n"
        printf "The recommendation is to always read the changelogs on SNBForums or Github.\n"

        if _WaitForYESorNO_ "\nProceed to ${MAGENTAct}ENABLE${NOct}?"
        then
            scriptUpdateCronSched="$(_GetScriptAutoUpdateCronSchedule_)"
            cronSchedStrHR="$(_TranslateCronSchedHR_ "$scriptUpdateCronSched")"
            printf "\nCurrent Schedule: ${GRNct}${scriptUpdateCronSched}${NOct}\n"
            printf "[${GRNct}${cronSchedStrHR}${NOct}]\n"

            if _WaitForYESorNO_ "\nConfirm the above schedule to check for automatic script updates?"
            then
                if _ValidateCronJobSchedule_ "$scriptUpdateCronSched"
                then
                    Update_Custom_Settings "Allow_Script_Auto_Update" "ENABLED"
                    printf "MerlinAU automatic script updates are now ${MAGENTAct}ENABLED${NOct}.\n"
                    printf "Adding '${GRNct}${SCRIPT_UP_CRON_JOB_TAG}${NOct}' cron job for automatic script updates...\n"
                    if _AddScriptAutoUpdateCronJob_
                    then
                        retCode=0
                        printf "Cron job '${GRNct}${SCRIPT_UP_CRON_JOB_TAG}${NOct}' was added successfully.\n"
                        printf "Job Schedule: ${GRNct}${cronSchedStrHR}${NOct}\n"
                        _AddScriptAutoUpdateHook_
                    else
                        retCode=1
                        printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${SCRIPT_UP_CRON_JOB_TAG}].\n"
                    fi
                else
                    retCode=1 ; keepOptionDisabled=true
                    printf "${REDct}**ERROR**${NOct}: Invalid cron schedule for automatic script updates.\n"
                fi
            else
                retCode=1 ; keepOptionDisabled=true
            fi
        else
            retCode=1 ; keepOptionDisabled=true
        fi
    else
        printf "\n${REDct}*NOTICE*${NOct}\n"
        printf "Disabling this feature will require user action to update the MerlinAU script\n"
        printf "when a newer version becomes available. This is the default setting.\n"
        if _WaitForYESorNO_ "\nProceed to ${GRNct}DISABLE${NOct}?"
        then
            Update_Custom_Settings "Allow_Script_Auto_Update" "DISABLED"
            printf "MerlinAU automatic script updates are now ${GRNct}DISABLED${NOct}.\n"
            printf "Removing '${GRNct}${SCRIPT_UP_CRON_JOB_TAG}${NOct}' cron job for automatic script updates...\n"
            _DelScriptAutoUpdateHook_
            if _DelScriptAutoUpdateCronJob_
            then
                retCode=0
                # Successful removal message is printed within function #
            else
                retCode=1
                # Error message is printed within function call #
            fi
        else
            printf "MerlinAU automatic script updates remain ${MAGENTAct}ENABLED${NOct}.\n"
        fi
    fi

    if "$keepOptionDisabled"
    then
        printf "MerlinAU automatic script updates remain ${GRNct}DISABLED.${NOct}\n"
    fi
    _WaitForEnterKey_
    return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-31] ##
##----------------------------------------##
_high_risk_phrases_interactive_()
{
    local changelog_contents="$1"

    if echo "$changelog_contents" | grep -Eiq "$high_risk_terms"
    then
        ChangelogApproval="$(Get_Custom_Setting "FW_New_Update_Changelog_Approval")"

        if [ "$ChangelogApproval" = "APPROVED" ]
        then
            Say "Changelog review is pre-approved!"
        #
        elif [ -z "$ChangelogApproval" ] || \
             [ "$ChangelogApproval" = "TBD" ] || \
             [ "$ChangelogApproval" = "BLOCKED" ]
        then
            if [ "$inMenuMode" = true ]
            then
                printf "\n ${REDct}*WARNING*: Found high-risk phrases in the changelog file.${NOct}"
                printf "\n ${REDct}Would you like to continue with the firmware update anyways?${NOct}"
                if ! _WaitForYESorNO_
                then
                    Say "Exiting for changelog review."
                    Update_Custom_Settings "FW_New_Update_Changelog_Approval" "BLOCKED"
                    _DoCleanUp_ 1
                    return 1
                else
                    Update_Custom_Settings "FW_New_Update_Changelog_Approval" "APPROVED"
                fi
            else
                Say "*WARNING*: Found high-risk phrases in the changelog file."
                Say "Please run script interactively to approve the firmware update."
                Update_Custom_Settings "FW_New_Update_Changelog_Approval" "BLOCKED"
                _SendEMailNotification_ STOP_FW_UPDATE_APPROVAL
                _DoCleanUp_ 1
                _DoExit_ 1
            fi
        fi
    else
        Say "No high-risk phrases found in the changelog file."
    fi
    return 0
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-May-26] ##
##------------------------------------------##
_high_risk_phrases_nointeractive_()
{
    local changelog_contents="$1"

    if echo "$changelog_contents" | grep -Eiq "$high_risk_terms"
    then
        _SendEMailNotification_ STOP_FW_UPDATE_APPROVAL
        Update_Custom_Settings "FW_New_Update_Changelog_Approval" "BLOCKED"
        if [ "$inMenuMode" = true ]
        then
            printf "\n${REDct}*WARNING*${NOct}: Found high-risk phrases in the changelog file."
            printf "\nPlease approve the update by selecting ${GRNct}'Toggle F/W Update Changelog Approval'${NOct}\n"
            _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        else
            Say "Please run script interactively to approve the firmware update."
            Say "To approve the update, select 'Toggle F/W Update Changelog Approval'"
        fi
        return 1
    else
        return 0
    fi
}

##-------------------------------------==---##
## Modified by ExtremeFiretop [2024-Nov-24] ##
##-------------------------------------==---##
_ChangelogVerificationCheck_()
{
    local mode="$1"  # Mode should be 'auto' or 'interactive' #
    local current_version  formatted_current_version
    local release_version  formatted_release_version
    local checkChangeLogSetting="$(Get_Custom_Setting "CheckChangeLog")"
    local changeLogFName  changeLogFPath

    if [ "$checkChangeLogSetting" = "ENABLED" ]
    then
        current_version="$(_GetCurrentFWInstalledLongVersion_)"
        release_version="$(Get_Custom_Setting "FW_New_Update_Notification_Vers")"

        if "$isGNUtonFW"
        then
            changeLogFName="${FW_FileName}_Changelog.txt"
            changeLogFPath="${FW_BIN_DIR}/$changeLogFName"
        else
            # Get the correct Changelog filename: "Changelog-[3006|386|NG].txt" #
            if echo "$release_version" | grep -qE "^3006[.]"
            then
                changeLogTag="3006"
            elif echo "$release_version" | grep -q "386[.]"
            then
                changeLogTag="386"
            else
                changeLogTag="NG"
            fi
            changeLogFName="Changelog-${changeLogTag}.txt"
            changeLogFPath="$(/usr/bin/find -L "${FW_BIN_DIR}" -name "$changeLogFName" -print)"
        fi

        if [ ! -f "$changeLogFPath" ]
        then
            Say "Changelog file [${FW_BIN_DIR}/${changeLogFName}] does NOT exist."
            _DoCleanUp_
            return 1
        else
            # Use awk to format the version based on the number of initial digits #
            formatted_current_version=$(echo "$current_version" | awk -F. '{
                if ($1 ~ /^[0-9]{4}$/) {  # Check for a four-digit prefix
                    if (NF == 4) {
                        # Remove any non-digit characters from the fourth field
                        sub(/[^0-9].*/, "", $4)
                        if ($4 == "0") {
                            printf "%s.%s", $2, $3  # For version like 3004.388.5.0, remove the last .0
                        } else {
                            printf "%s.%s.%s", $2, $3, $4  # For version like 3004.388.5.2, keep the last digit
                        }
                    }
                } else if (NF == 3) {  # For version without a four-digit prefix
                    if ($3 == "0") {
                        printf "%s.%s", $1, $2  # For version like 388.5.0, remove the last .0
                    } else {
                        printf "%s.%s.%s", $1, $2, $3  # For version like 388.5.2, keep the last digit
                    }
                }
            }')

            formatted_release_version=$(echo "$release_version" | awk -F. '{
                if ($1 ~ /^[0-9]{4}$/) {  # Check for a four-digit prefix
                    if (NF == 4 && $4 == "0") {
                        printf "%s.%s", $2, $3  # For version like 3004.388.5.0, remove the last .0
                    } else if (NF == 4) {
                        printf "%s.%s.%s", $2, $3, $4  # For version like 3004.388.5.2, keep the last digit
                    }
                } else if (NF == 3) {  # For version without a four-digit prefix
                    if ($3 == "0") {
                        printf "%s.%s", $1, $2  # For version like 388.5.0, remove the last .0
                    } else {
                        printf "%s.%s.%s", $1, $2, $3  # For version like 388.5.2, keep the last digit
                    }
                }
            }')

            # Define regex patterns for both versions #
            release_version_regex="${formatted_release_version//./[._]}\s*\([0-9]{1,2}-[A-Za-z]+-[0-9]{4}\)"
            current_version_regex="${formatted_current_version//./[._]}\s*\([0-9]{1,2}-[A-Za-z]+-[0-9]{4}\)"

            if "$isGNUtonFW"
            then
                # For Gnuton, the whole file is relevant as it only contains the current version #
                changelog_contents="$(cat "$changeLogFPath")"
            else
                if ! grep -Eq "$current_version_regex" "$changeLogFPath"
                then
                    Say "Current version NOT found in changelog file. Bypassing changelog verification for this run."
                    return 0
                fi
                # Extract log contents between two firmware versions from RMerlin #
                changelog_contents="$(awk "/$release_version_regex/,/$current_version_regex/" "$changeLogFPath")"
            fi

            if [ "$mode" = "interactive" ]
            then
                if _high_risk_phrases_interactive_ "$changelog_contents"
                then return 0
                else return 1
                fi
            else
                if _high_risk_phrases_nointeractive_ "$changelog_contents"
                then return 0
                else return 1
                fi
            fi
        fi
    else
        [ "$mode" = "interactive" ] && Say "Changelog check is DISABLED."
        return 0
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-18] ##
##----------------------------------------##
_ManageChangelogMerlin_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

    local mode="$1"  # Mode should be 'download' or 'view' #
    local newUpdateVerStr=""
    local wgetLogFile  changeLogFile  changeLogTag

    # Create directory to download changelog if missing #
    if ! _CreateDirectory_ "$FW_BIN_DIR" ; then return 1 ; fi

    if [ "$mode" = "view" ]
    then
        if [ "$fwInstalledBaseVers" -eq 3006 ]
        then
            changeLogTag="3006"
            MerlinChangeLogURL="${CL_URL_3006}"
        elif echo "$fwInstalledBuildVers" | grep -qE "^386[.]"
        then
            changeLogTag="386"
            MerlinChangeLogURL="${CL_URL_386}"
        else
            changeLogTag="NG"
            MerlinChangeLogURL="${CL_URL_NG}"
        fi
    elif [ "$mode" = "download" ]
    then
        [ $# -gt 1 ] && [ -n "$2" ] && newUpdateVerStr="$2"
        if echo "$newUpdateVerStr" | grep -qE "^3006[.]"
        then
            changeLogTag="3006"
            MerlinChangeLogURL="${CL_URL_3006}"
        elif echo "$newUpdateVerStr" | grep -q "386[.]"
        then
            changeLogTag="386"
            MerlinChangeLogURL="${CL_URL_386}"
        else
            changeLogTag="NG"
            MerlinChangeLogURL="${CL_URL_NG}"
        fi 
    fi

    wgetLogFile="${FW_BIN_DIR}/${ScriptFNameTag}.WGET.LOG"
    changeLogFile="${FW_BIN_DIR}/Changelog-${changeLogTag}.txt"

    if [ "$mode" = "view" ]; then
        printf "\nRetrieving ${GRNct}Changelog-${changeLogTag}.txt${NOct} ...\n"
    fi

    wget --tries=5 --waitretry=5 --retry-connrefused \
         -O "$changeLogFile" -o "$wgetLogFile" "${MerlinChangeLogURL}"

    if [ ! -s "$changeLogFile" ]
    then
        Say "Changelog file [$changeLogFile] does NOT exist."
        echo ; [ -s "$wgetLogFile" ] && cat "$wgetLogFile"
    else
        if [ "$mode" = "download" ]
        then
            _ChangelogVerificationCheck_ "auto"
        elif [ "$mode" = "view" ]
        then
            clear
            printf "\n${GRNct}Changelog file is ready to review!${NOct}\n"
            printf "\nPress '${REDct}q${NOct}' to quit when finished.\n"
            dos2unix "$changeLogFile"
            _WaitForEnterKey_
            less "$changeLogFile"
            "$inMenuMode" && _WaitForEnterKey_ "$logsMenuReturnPromptStr"
        fi
    fi
    rm -f "$changeLogFile" "$wgetLogFile"
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-18] ##
##----------------------------------------##
_ManageChangelogGnuton_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

    local mode="$1"  # Mode should be 'download' or 'view' #
    local newUpdateVerStr=""
    local wgetLogFile  changeLogFile  changeLogTag

    # Create directory to download changelog if missing
    if ! _CreateDirectory_ "$FW_BIN_DIR" ; then return 1 ; fi

    GnutonChangeLogURL="$(GetLatestChangelogUrl "$FW_GITURL_RELEASE")"

    # Follow redirects and capture the effective URL
    local effective_url="$(curl -Ls -o /dev/null -w %{url_effective} "$GnutonChangeLogURL")"

    # Use the effective URL to capture the Content-Disposition header
    local original_filename="$(curl -sI "$effective_url" | grep -i content-disposition | sed -n 's/.*filename=["]*\([^";]*\).*/\1/p')"

    # Sanitize filename by removing problematic characters
    local sanitized_filename="$(echo "$original_filename" | sed 's/[^a-zA-Z0-9._-]//g')"

    FW_Changelog_GITHUB="${FW_BIN_DIR}/${FW_FileName}_Changelog.txt"

    wgetLogFile="${FW_BIN_DIR}/${ScriptFNameTag}.WGET.LOG"

    if [ "$mode" = "view" ]; then
        printf "\nRetrieving ${GRNct}${FW_Changelog_GITHUB}${NOct} ...\n"
    fi

    wget --tries=5 --waitretry=5 --retry-connrefused \
         -O "$FW_Changelog_GITHUB" -o "$wgetLogFile" "${GnutonChangeLogURL}"

    if [ ! -s "$FW_Changelog_GITHUB" ]
    then
        Say "Changelog file [$FW_Changelog_GITHUB] does NOT exist."
        echo ; [ -s "$wgetLogFile" ] && cat "$wgetLogFile"
    else
        if [ "$mode" = "download" ]
        then
            _ChangelogVerificationCheck_ "auto"
        elif [ "$mode" = "view" ]
        then
            clear
            printf "\n${GRNct}Changelog file is ready to review!${NOct}\n"
            printf "\nPress '${REDct}q${NOct}' to quit when finished.\n"
            dos2unix "$FW_Changelog_GITHUB"
            _WaitForEnterKey_
            less "$FW_Changelog_GITHUB"
        fi
    fi
    rm -f "$FW_Changelog_GITHUB" "$wgetLogFile"
    return 1
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-10] ##
##----------------------------------------##
_CheckNewUpdateFirmwareNotification_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local numOfFields  fwNewUpdateVersNum
   local sendNewUpdateStatusEmail=false
   local currentVersionStr="$1"  releaseVersionStr="$2"

   numOfFields="$(echo "$currentVersionStr" | awk -F '.' '{print NF}')"
   currentVersionNum="$(_FWVersionStrToNum_ "$currentVersionStr" "$numOfFields")"
   releaseVersionNum="$(_FWVersionStrToNum_ "$releaseVersionStr" "$numOfFields")"

   if [ "$currentVersionNum" -ge "$releaseVersionNum" ]
   then
       Say "Current firmware version '${currentVersionStr}' is up to date."
       Update_Custom_Settings FW_New_Update_Notification_Date TBD
       Update_Custom_Settings FW_New_Update_Notification_Vers TBD
       Update_Custom_Settings FW_New_Update_Expected_Run_Date TBD
       local currentChangelogValue="$(Get_Custom_Setting CheckChangeLog)"
       if [ "$currentChangelogValue" = "ENABLED" ]
       then
           Update_Custom_Settings FW_New_Update_Changelog_Approval TBD
       fi
       return 1
   fi

   fwNewUpdateNotificationVers="$(Get_Custom_Setting FW_New_Update_Notification_Vers TBD)"
   if [ -z "$fwNewUpdateNotificationVers" ] || [ "$fwNewUpdateNotificationVers" = "TBD" ]
   then
       fwNewUpdateNotificationVers="$releaseVersionStr"
       Update_Custom_Settings FW_New_Update_Notification_Vers "$fwNewUpdateNotificationVers"
   else
       numOfFields="$(echo "$fwNewUpdateNotificationVers" | awk -F '.' '{print NF}')"
       fwNewUpdateVersNum="$(_FWVersionStrToNum_ "$fwNewUpdateNotificationVers" "$numOfFields")"
       if [ "$releaseVersionNum" -gt "$fwNewUpdateVersNum" ]
       then
           fwNewUpdateNotificationVers="$releaseVersionStr"
           fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
           Update_Custom_Settings FW_New_Update_Notification_Vers "$fwNewUpdateNotificationVers"
           Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
           "$inRouterSWmode" && sendNewUpdateStatusEmail=true
           if ! "$FlashStarted"
           then
               if "$isGNUtonFW"
               then
                   _ManageChangelogGnuton_ "download" "$fwNewUpdateNotificationVers"
               else
                   _ManageChangelogMerlin_ "download" "$fwNewUpdateNotificationVers"
               fi
           fi
       fi
   fi

   fwNewUpdateNotificationDate="$(Get_Custom_Setting FW_New_Update_Notification_Date)"
   if [ -z "$fwNewUpdateNotificationDate" ] || [ "$fwNewUpdateNotificationDate" = "TBD" ]
   then
       fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
       Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
       "$inRouterSWmode" && sendNewUpdateStatusEmail=true
       if ! "$FlashStarted"
       then
           if "$isGNUtonFW"
           then
               _ManageChangelogGnuton_ "download" "$fwNewUpdateNotificationVers"
           else
               _ManageChangelogMerlin_ "download" "$fwNewUpdateNotificationVers"
           fi
       fi
   fi

   fwNewUpdateNotificationDate="$(Get_Custom_Setting FW_New_Update_Notification_Date)"
   upfwDateTimeSecs="$(_Calculate_DST_ "$(echo "$fwNewUpdateNotificationDate" | sed 's/_/ /g')")"
   nextCronTimeSecs="$(_EstimateNextCronTimeAfterDate_ "$upfwDateTimeSecs" "$FW_UpdateCronJobSchedule")"

   if [ "$nextCronTimeSecs" = "$CRON_UNKNOWN_DATE" ]
   then Update_Custom_Settings FW_New_Update_Expected_Run_Date TBD
   else Update_Custom_Settings FW_New_Update_Expected_Run_Date "$nextCronTimeSecs"
   fi

   "$sendNewUpdateStatusEmail" && _SendEMailNotification_ NEW_FW_UPDATE_STATUS
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-27] ##
##----------------------------------------##
_CheckNodeFWUpdateNotification_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local nodeNumOfFields  nodefwNewUpdateVersNum
   local currentVersionStr="$1"  releaseVersionStr="$2"

   nodeNumOfFields="$(echo "$currentVersionStr" | awk -F '.' '{print NF}')"
   nodecurrentVersionNum="$(_FWVersionStrToNum_ "$currentVersionStr" "$nodeNumOfFields")"
   nodereleaseVersionNum="$(_FWVersionStrToNum_ "$releaseVersionStr" "$nodeNumOfFields")"

   if [ "$nodecurrentVersionNum" -ge "$nodereleaseVersionNum" ]
   then
       _Populate_Node_Settings_ "$node_label_mac" "$node_lan_hostname" "TBD" "TBD" "$uid"
       return 1
   fi

   nodefwNewUpdateNotificationVers="$(_GetAllNodeSettings_ "$node_label_mac" "New_Notification_Vers")"
   if [ -z "$nodefwNewUpdateNotificationVers" ] || [ "$nodefwNewUpdateNotificationVers" = "TBD" ]
   then
       nodefwNewUpdateNotificationVers="$releaseVersionStr"
       _Populate_Node_Settings_ "$node_label_mac" "$node_lan_hostname" "TBD" "$nodefwNewUpdateNotificationVers" "$uid"
   else
       nodeNumOfFields="$(echo "$nodefwNewUpdateNotificationVers" | awk -F '.' '{print NF}')"
       nodefwNewUpdateVersNum="$(_FWVersionStrToNum_ "$nodefwNewUpdateNotificationVers" "$nodeNumOfFields")"
       if [ "$nodereleaseVersionNum" -gt "$nodefwNewUpdateVersNum" ]
       then
           nodefwNewUpdateNotificationVers="$releaseVersionStr"
           nodefwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
           _Populate_Node_Settings_ "$node_label_mac" "$node_lan_hostname" "$nodefwNewUpdateNotificationDate" "$nodefwNewUpdateNotificationVers" "$uid"
           nodefriendlyname="$(_GetAllNodeSettings_ "$node_label_mac" "Model_NameID")"
           {
             echo ""
             echo "AiMesh Node <b>${nodefriendlyname}</b> with MAC address <b>${node_label_mac}</b> requires update from <b>${1}</b> to <b>${2}</b> version."
             echo "(<b>${1}</b> --> <b>${2}</b>)"
             echo "Please click here to review the latest changelog:"
             if "$NodeGNUtonFW"
             then
                 GnutonChangeLogURL="$(GetLatestChangelogUrl "$FW_GITURL_RELEASE")"
                 echo "$GnutonChangeLogURL"
             else
                 if [ "$node_firmver" -eq 3006 ]
                 then
                     MerlinChangeLogURL="${CL_URL_3006}"
                 elif echo "$node_buildno" | grep -qE "^386[.]"
                 then
                     MerlinChangeLogURL="${CL_URL_386}"
                 else
                     MerlinChangeLogURL="${CL_URL_NG}"
                 fi
                 echo "$MerlinChangeLogURL"
             fi
             echo "Automated update will be scheduled <b>only if</b> MerlinAU is installed on the node."
           } > "$tempNodeEMailList"
       fi
   fi

   nodefwNewUpdateNotificationDate="$(_GetAllNodeSettings_ "$node_label_mac" "New_Notification_Date")"
   if [ -z "$nodefwNewUpdateNotificationDate" ] || [ "$nodefwNewUpdateNotificationDate" = "TBD" ]
   then
       nodefwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
       _Populate_Node_Settings_ "$node_label_mac" "$node_lan_hostname" "$nodefwNewUpdateNotificationDate" "$nodefwNewUpdateNotificationVers" "$uid"
       nodefriendlyname="$(_GetAllNodeSettings_ "$node_label_mac" "Model_NameID")"
       {
         echo ""
         echo "AiMesh Node <b>${nodefriendlyname}</b> with MAC address <b>${node_label_mac}</b> requires update from <b>${1}</b> to <b>${2}</b> version."
         echo "(<b>${1}</b> --> <b>${2}</b>)"
         echo "Please click here to review the latest changelog:"
         if "$NodeGNUtonFW"
         then
             GnutonChangeLogURL="$(GetLatestChangelogUrl "$FW_GITURL_RELEASE")"
             echo "$GnutonChangeLogURL"
         else
             if [ "$node_firmver" -eq 3006 ]
             then
                 MerlinChangeLogURL="${CL_URL_3006}"
             elif echo "$node_buildno" | grep -qE "^386[.]"
             then
                 MerlinChangeLogURL="${CL_URL_386}"
             else
                 MerlinChangeLogURL="${CL_URL_NG}"
             fi
             echo "$MerlinChangeLogURL"
         fi
         echo "Automated update will be scheduled <b>only if</b> MerlinAU is installed on the node."
       } > "$tempNodeEMailList"
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-18] ##
##----------------------------------------##
_CheckTimeToUpdateFirmware_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local upfwDateTimeSecs nextCronTimeSecs upfwDateTimeStrn
   local fwNewUpdatePostponementDays  fwNewUpdateNotificationDate  fwNewUpdateNotificationVers

   _CheckNewUpdateFirmwareNotification_ "$1" "$2"

   if [ "$currentVersionNum" -ge "$releaseVersionNum" ]
   then return 1 ; fi

   fwNewUpdatePostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days TBD)"
   if [ -z "$fwNewUpdatePostponementDays" ] || [ "$fwNewUpdatePostponementDays" = "TBD" ]
   then
       fwNewUpdatePostponementDays="$FW_UpdateDefaultPostponementDays"
       Update_Custom_Settings FW_New_Update_Postponement_Days "$fwNewUpdatePostponementDays"
   fi

   if [ "$fwNewUpdatePostponementDays" -eq 0 ]
   then return 0 ; fi

   upfwDateTimeSecs="$(_Calculate_DST_ "$(echo "$fwNewUpdateNotificationDate" | sed 's/_/ /g')")"

   local currentTimeSecs="$(date +%s)"
   if [ "$((currentTimeSecs - upfwDateTimeSecs))" -ge 0 ]
   then return 0 ; fi

   Say "The firmware update to ${GRNct}${2}${NOct} version is currently postponed for ${GRNct}${fwNewUpdatePostponementDays}${NOct} day(s)."

   nextCronTimeSecs="$(_EstimateNextCronTimeAfterDate_ "$upfwDateTimeSecs" "$FW_UpdateCronJobSchedule")"
   if [ "$nextCronTimeSecs" = "$CRON_UNKNOWN_DATE" ]
   then
       upfwDateTimeStrn="$(date -d @$upfwDateTimeSecs +"%A, %Y-%b-%d %I:%M %p")"
       Say "The firmware update is expected to occur on or after ${GRNct}${upfwDateTimeStrn}${NOct}, depending on when your cron job is scheduled to check again."
       return 1
   fi

   Say "The firmware update is expected to occur on ${GRNct}${nextCronTimeSecs}${NOct}."
   echo ""

   # Check if running in a menu environment #
   if "$isInteractive" && _WaitForYESorNO_ "Would you like to proceed with the update now?"
   then return 0
   else return 1
   fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-21] ##
##------------------------------------------##
_RunEMailNotificationTest_()
{
   [ "$sendEMailNotificationsFlag" != "ENABLED" ] && return 1
   local retCode=1

   if _WaitForYESorNO_ "\nWould you like to run a test of the email notification?"
   then
       retCode=0
       _SendEMailNotification_ FW_UPDATE_TEST_EMAIL
   fi
   return "$retCode"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-21] ##
##------------------------------------------##
_Toggle_FW_UpdateEmailNotifications_()
{
   local emailNotificationEnabled  emailNotificationNewStateStr

   if [ "$sendEMailNotificationsFlag" = "ENABLED" ]
   then
       emailNotificationEnabled="ENABLED"
       emailNotificationNewStateStr="${REDct}DISABLE${NOct}"
   else
       emailNotificationEnabled="DISABLED"
       emailNotificationNewStateStr="${GRNct}ENABLE${NOct}"
   fi

   if ! _WaitForYESorNO_ "Do you want to ${emailNotificationNewStateStr} F/W Update email notifications?"
   then
       _RunEMailNotificationTest_ && _WaitForEnterKey_ "$advnMenuReturnPromptStr"
       return 1
   fi

   if [ "$emailNotificationEnabled" = "ENABLED" ];
   then
       sendEMailNotificationsFlag="DISABLED"
       emailNotificationNewStateStr="${REDct}DISABLED${NOct}"
   else
       sendEMailNotificationsFlag="ENABLED"
       emailNotificationNewStateStr="${GRNct}ENABLED${NOct}"
   fi

   Update_Custom_Settings FW_New_Update_EMail_Notification "$sendEMailNotificationsFlag"
   printf "F/W Update email notifications are now ${emailNotificationNewStateStr}.\n"

   _RunEMailNotificationTest_
   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_Toggle_FW_UpdateCheckSetting_()
{
   local fwUpdateCheckEnabled  fwUpdateCheckNewStateStr
   local runfwUpdateCheck=false

   if [ "$FW_UpdateCheckState" -eq 0 ]
   then
       fwUpdateCheckEnabled=false
       fwUpdateCheckNewStateStr="${GRNct}ENABLE${NOct}"
   else
       fwUpdateCheckEnabled=true
       fwUpdateCheckNewStateStr="${REDct}DISABLE${NOct}"
   fi

   if ! _WaitForYESorNO_ "Do you want to ${fwUpdateCheckNewStateStr} the built-in F/W Update Check?"
   then return 1 ; fi

   if "$fwUpdateCheckEnabled"
   then
       runfwUpdateCheck=false
       FW_UpdateCheckState=0
       fwUpdateCheckNewStateStr="${REDct}DISABLED${NOct}"
       Update_Custom_Settings "FW_Update_Check" "DISABLED"
       _DelFWAutoUpdateHook_
       _DelFWAutoUpdateCronJob_
   else
       [ -x "$FW_UpdateCheckScript" ] && runfwUpdateCheck=true
       FW_UpdateCheckState=1
       fwUpdateCheckNewStateStr="${GRNct}ENABLED${NOct}"
       Update_Custom_Settings "FW_Update_Check" "ENABLED"
       if _AddFWAutoUpdateCronJob_
       then
           printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
           _AddFWAutoUpdateHook_
       else
           printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
       fi
   fi

   nvram set firmware_check_enable="$FW_UpdateCheckState"
   printf "Router's built-in Firmware Update Check is now ${fwUpdateCheckNewStateStr}.\n"
   nvram commit

   if "$runfwUpdateCheck"
   then
       printf "\nChecking for new F/W Updates... Please wait.\n"
       sh "$FW_UpdateCheckScript" 2>&1
   fi
   _WaitForEnterKey_ "$mainMenuReturnPromptStr"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Oct-04] ##
##----------------------------------------##
_RemoveCronJobsFromAddOns_()
{
   eval $cronListCmd | grep -E "$cronJobsRegEx1|$cronJobsRegEx2|$cronJobsRegEx3|cronJobsRegEx4|$cronJobsRegEx5|$cronJobsRegEx6" > "$addonCronJobList"
   if [ ! -s "$addonCronJobList" ]
   then
       rm -f "$addonCronJobList"
       Say "Cron jobs from 3rd-party add-ons were not found."
       return 1
   fi

   local cronJobCount=0  cronJobIDx  cronJobCMD

   while read -r cronJobLINE
   do
      if [ -z "$cronJobLINE" ] || echo "$cronJobLINE" | grep -qE "^[[:blank:]]*#"
      then continue ; fi
      cronJobCount="$((cronJobCount + 1))"

      [ "$cronJobCount" -eq 1 ] && \
      Say "---------------------------------------------------------------"
      Say "Cron job #${cronJobCount}: [$cronJobLINE]"

      cronJobIDx="$(echo "$cronJobLINE" | awk -F '#' '{print $2}')"
      cronJobCMD="$(echo "$cronJobLINE" | awk -F '#' '{print $1}' | sed 's/[[:blank:]]*$//')"

      if [ -n "$cronJobIDx" ]
      then
          cru d "$cronJobIDx" ; sleep 1
          if eval $cronListCmd | grep -qE "#${cronJobIDx}#$"
          then Say "**ERROR**: Failed to remove cron job [$cronJobIDx]."
          else Say "Cron job [$cronJobIDx] was removed successfully."
          fi
      fi
   done < "$addonCronJobList"

   rm -f "$addonCronJobList"
   Say "Cron jobs [$cronJobCount] from 3rd-party add-ons were found."
   Say "---------------------------------------------------------------"

   sleep 5
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-Aug-02] ##
##----------------------------------------##
_EntwareServicesHandler_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi
   local AllowVPN="$(Get_Custom_Setting Allow_Updates_OverVPN)"

   local actionStr=""
   local servicesList  servicesCnt=0
   local entwOPT_init  entwOPT_unslung
   # space-delimited list of services to skip #
   local skipServiceList="tailscaled zerotier-one sshd"
   local skippedService  skippedServiceFile  skippedServiceName
   local theSkippedServiceList=""

   entwOPT_init="/opt/etc/init.d"
   entwOPT_unslung="${entwOPT_init}/rc.unslung"

   case "$1" in
       stop) actionStr="Stopping" ;;
      start) actionStr="Restarting" ;;
          *) return 1 ;;
   esac

   # Check if *NOT* skipping any services #
   [ $# -gt 1 ] && [ "$2" = "-noskip" ] && skipServiceList=""

   _RenameSkippedService_()
   {
       [ -z "$theSkippedServiceList" ] && return 1
       for skippedServiceName in $theSkippedServiceList
       do  # Rename service file back to original state #
           skippedServiceFile="${entwOPT_init}/$skippedServiceName"
           if mv -f "${entwOPT_init}/OFF.${skippedServiceName}.OFF" "$skippedServiceFile"
           then Say "Skipped $skippedServiceFile $1 call." ; fi
       done
       return 0
   }

   if [ ! -x /opt/bin/opkg ] || [ ! -x "$entwOPT_unslung" ]
   then return 0 ; fi  ## Entware is NOT found ##

   servicesList="$(/usr/bin/find -L "$entwOPT_init" -name "*" -print 2>/dev/null | /bin/grep -E "(${entwOPT_init}/S[0-9]+|${entwOPT_init}/.*[.]sh$)")"
   [ -z "$servicesList" ] && return 0

   Say "Searching for Entware services to ${1}..."

   # Filter out services to skip and add a "skip message" #
   if [ "$AllowVPN" = "ENABLED" ] && [ -n "$skipServiceList" ]
   then
      for skipService in $skipServiceList
      do
          skippedService="$(echo "$servicesList" | /bin/grep -E "/S[0-9]+.*${skipService}([.]sh)?$")"
          if [ -n "$skippedService" ]
          then
              for skippedServiceFile in $skippedService
              do
                  skippedServiceName="$(basename "$skippedServiceFile")"
                  Say "Skipping $skippedServiceFile $1 call..."
                  # Rename service file so it's skipped by Entware #
                  if mv -f "$skippedServiceFile" "${entwOPT_init}/OFF.${skippedServiceName}.OFF"
                  then
                      [ -z "$theSkippedServiceList" ] && \
                      theSkippedServiceList="$skippedServiceName" || \
                      theSkippedServiceList="$theSkippedServiceList $skippedServiceName"
                      servicesList="$(echo "$servicesList" | /bin/grep -vE "${skippedServiceFile}$")"
                  fi
              done
          fi
      done
   fi

   [ -n "$servicesList" ] && servicesCnt="$(echo "$servicesList" | wc -l)"
   if [ "$servicesCnt" -eq 0 ]
   then
       Say "No Entware services to ${1}."
       _RenameSkippedService_ "$1" && echo
       return 0
   fi

   Say "${actionStr} Entware services..."
   "$isInteractive" && printf "Please wait.\n"
   Say "-----------------------------------------------------------"
   # List the Entware services found to stop/start #
   echo "$servicesList" | while IFS= read -r servLine ; do Say "$servLine" ; done
   Say "-----------------------------------------------------------"

   $entwOPT_unslung "$1" ; sleep 5
   _RenameSkippedService_ "$1" && echo
   "$isInteractive" && printf "\nDone.\n"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Nov-15] ##
##------------------------------------------##
_GetOfflineFirmwareVersion_()
{
    local zip_file="$1"
    local extract_version_regex='[0-9]+_[0-9]+\.[0-9]+_[0-9a-zA-Z]+'
    local validate_version_regex='[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(_[0-9a-zA-Z]+)?'
    local fwVersionFormat  firmware_version  formatted_version

    # Extract the version number using regex #
    firmware_version="$(echo "$zip_file" | grep -oE "$extract_version_regex")"

    if [ -n "$firmware_version" ]
    then
        if echo "$firmware_version" | grep -qE '^([0-9]+)_([0-9]+)\.([0-9]+)_([0-9]+)$'
        then
            # Numeric patch version
            formatted_version="$(echo "$firmware_version" | sed -E 's/^([0-9]+)_([0-9]+)\.([0-9]+)_([0-9]+)/\1.\2.\3.\4/')"
        elif echo "$firmware_version" | grep -qE '^([0-9]+)_([0-9]+)\.([0-9]+)_([0-9a-zA-Z]+)$'
        then
            # Alphanumeric suffix
            formatted_version="$(echo "$firmware_version" | sed -E 's/^([0-9]+)_([0-9]+)\.([0-9]+)_([0-9a-zA-Z]+)/\1.\2.\3.0_\4/')"
        else
            printf "\nFailed to parse firmware version from the ZIP file name.\n"
            firmware_version=""
        fi
        printf "\nIdentified firmware version: ${GRNct}$formatted_version${NOct}\n"
        printf "\n---------------------------------------------------\n"

        # Ask the user to confirm the detected firmware version
        if _WaitForYESorNO_ "\nIs this firmware version correct?"; then
            printf "\n---------------------------------------------------\n"
        else
            # Set firmware_version to empty to trigger manual entry
            firmware_version=""
        fi
    fi

    if [ -z "$firmware_version" ]
    then
        fwVersionFormat="${BLUEct}BASE${WHITEct}.${CYANct}MAJOR${WHITEct}.${MAGENTAct}MINOR${WHITEct}.${YLWct}PATCH${NOct}"
        # Prompt user for the firmware version if extraction fails #
        printf "\n${REDct}**WARNING**${NOct}\n"
        if "$isGNUtonFW"
        then
            printf "\nFailed to identify firmware version from the update file name."
        else
            printf "\nFailed to identify firmware version from the ZIP file name."
        fi
        printf "\nPlease enter the firmware version number in the format ${fwVersionFormat}\n"
        printf "\n(Examples: 3004.388.8.0 or 3004.388.8.0_beta1). Enter 'e' to exit:  "
        read -r formatted_version

        # Validate user input #
        while ! echo "$formatted_version" | grep -qE "^${validate_version_regex}$"
        do
            if echo "$formatted_version" | grep -qE "^(e|E|exit|Exit)$"; then
                return 1
            fi
            printf "\n${REDct}**WARNING**${NOct} Invalid format detected!\n"
            printf "\nPlease enter the firmware version number in the format ${fwVersionFormat}\n"
            printf "\n(i.e 3004.388.8.0 or 3004.388.8.0_beta1). Enter 'e' to exit:  "
            read -r formatted_version
        done
        printf "\nThe user-provided firmware version: ${GRNct}$formatted_version${NOct}\n"
    fi

    export release_version="$formatted_version"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Nov-15] ##
##------------------------------------------##
_SelectOfflineUpdateFile_()
{
    local selection fileList fileCount

    # Check if the directory is empty or no valid files are found #
    if "$isGNUtonFW"
    then
        if [ -z "$(ls -A "$FW_ZIP_DIR"/*.w "$FW_ZIP_DIR"/*.pkgtb 2>/dev/null)" ]
        then
            printf "\nNo valid update files found in the directory. Exiting.\n"
            printf "\n---------------------------------------------------\n"
            return 1
        fi
    else
        if [ -z "$(ls -A "$FW_ZIP_DIR"/*.zip 2>/dev/null)" ]
        then
            printf "\nNo valid ZIP files found in the directory. Exiting.\n"
            printf "\n---------------------------------------------------\n"
            return 1
        fi
    fi

    while true
    do
        if "$isGNUtonFW"
        then
            fileList="$(ls -A1 "$FW_ZIP_DIR"/*.w "$FW_ZIP_DIR"/*.pkgtb 2>/dev/null)"
            printf "\nAvailable update files in the directory: [${GRNct}${FW_ZIP_DIR}${NOct}]:\n\n"
        else
            fileList="$(ls -A1 "$FW_ZIP_DIR"/*.zip 2>/dev/null)"
            printf "\nAvailable ZIP files in the directory: [${GRNct}${FW_ZIP_DIR}${NOct}]:\n\n"
        fi
        fileCount=1
        for file in $fileList
        do
            printf "${GRNct}%d${NOct}) %s\n" "$fileCount" "$file"
            fileCount="$((fileCount + 1))"
        done

        # Prompt user to select a file #
        printf "\n---------------------------------------------------\n"
        if "$isGNUtonFW"
        then
            printf "\n[${theMUExitStr}] Enter the number of the update file you want to select:  "
        else
            printf "\n[${theMUExitStr}] Enter the number of the ZIP file you want to select:  "
        fi

        read -r selection
        if [ -z "$selection" ]
        then
            printf "\n${REDct}Invalid selection${NOct}. Please try again.\n"
            _WaitForEnterKey_
            clear
            continue
        fi

        if echo "$selection" | grep -qE "^(e|E|exit|Exit)$"
        then
            printf "Update process was cancelled. Exiting.\n"
            return 1
        fi

        # Validate selection #
        selected_file="$(echo "$fileList" | awk "NR==$selection")"
        if [ -z "$selected_file" ]
        then
            printf "\n${REDct}Invalid selection${NOct}. Please try again.\n"
            _WaitForEnterKey_
            clear
            continue
        else
            clear
            printf "\n---------------------------------------------------\n"
            printf "\nYou have selected:\n${GRNct}$selected_file${NOct}\n"
            break
        fi
    done

    # Extract or prompt for firmware version #
    if ! _GetOfflineFirmwareVersion_ "$selected_file"
    then
        printf "Operation was cancelled by user. Exiting.\n"
        return 1
    fi

    # Confirm the selection
    if _WaitForYESorNO_ "\nDo you want to continue with the selected file?"
    then
        printf "\n---------------------------------------------------\n"
        printf "\nStarting firmware update with the selected file.\n"
        # Rename the selected file #
        new_file_name="${PRODUCT_ID}_firmware.${selected_file##*.}"
        mv -f "$selected_file" "${FW_ZIP_DIR}/$new_file_name"
        if [ $? -eq 0 ]
        then
            printf "\nFile packaged to ${GRNct}${new_file_name}${NOct}"
            printf "\nRelease version: ${GRNct}${release_version}${NOct}\n"
            printf "\n---------------------------------------------------\n"
            _WaitForEnterKey_
            Update_Custom_Settings FW_New_Update_Notification_Vers "$release_version"
            Update_Custom_Settings FW_New_Update_Notification_Date "$(date +"$FW_UpdateNotificationDateFormat")"
            clear
            return 0
        else
            printf "\nFailed to rename the file. Exiting.\n"
            return 1
        fi
    else
        printf "Operation was cancelled by user. Exiting.\n"
        return 1
    fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Dec-21] ##
##------------------------------------------##
_GnutonBuildSelection_()
{
   # Check if PRODUCT_ID is for a TUF model and requires user choice
   if echo "$PRODUCT_ID" | grep -q "^TUF-"
   then
        # Fetch the previous choice from the settings file
        local previous_choice="$(Get_Custom_Setting "TUFBuild")"

        if [ "$previous_choice" = "ENABLED" ]
        then
            echo "TUF Build selected for flashing"
            firmware_choice="tuf"
        elif [ "$previous_choice" = "DISABLED" ]
        then
            echo "Pure Build selected for flashing"
            firmware_choice="pure"
        elif [ "$inMenuMode" = true ]
        then
            printf "${REDct}Found TUF build for: $PRODUCT_ID.${NOct}\n"
            printf "${REDct}Would you like to use the TUF build?${NOct}\n"
            printf "Enter your choice (y/n): "
            read -r choice
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]
            then
                echo "TUF Build selected for flashing"
                firmware_choice="tuf"
                Update_Custom_Settings "TUFBuild" "ENABLED"
            else
                echo "Pure Build selected for flashing"
                firmware_choice="pure"
                Update_Custom_Settings "TUFBuild" "DISABLED"
            fi
        else
            echo "Defaulting to Pure Build due to non-interactive mode."
            firmware_choice="pure"
            Update_Custom_Settings "TUFBuild" "DISABLED"
        fi
   elif echo "$PRODUCT_ID" | grep -q "^GT-"
   then
        # Fetch the previous choice from the settings file
        local previous_choice="$(Get_Custom_Setting "ROGBuild")"

        if [ "$previous_choice" = "ENABLED" ]
        then
            echo "ROG Build selected for flashing"
            firmware_choice="rog"
        elif [ "$previous_choice" = "DISABLED" ]
        then
            echo "Pure Build selected for flashing"
            firmware_choice="pure"
        elif [ "$inMenuMode" = true ]
        then
            printf "${REDct}Found ROG build for: $PRODUCT_ID.${NOct}\n"
            printf "${REDct}Would you like to use the ROG build?${NOct}\n"
            printf "Enter your choice (y/n): "
            read -r choice
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]
            then
                echo "ROG Build selected for flashing"
                firmware_choice="rog"
                Update_Custom_Settings "ROGBuild" "ENABLED"
            else
                echo "Pure Build selected for flashing"
                firmware_choice="pure"
                Update_Custom_Settings "ROGBuild" "DISABLED"
            fi
        else
            echo "Defaulting to Pure Build due to non-interactive mode."
            firmware_choice="pure"
            Update_Custom_Settings "ROGBuild" "DISABLED"
        fi
   else
        # If not a TUF model, process as usual
        firmware_choice="pure"
   fi
   return 0
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Jul-23] ##
##------------------------------------------##
_RunBackupmon_()
{
    # Check for the presence of backupmon.sh script
    if [ -f "/jffs/scripts/backupmon.sh" ]
    then
        local current_backup_settings="$(Get_Custom_Setting "FW_Auto_Backupmon")"

        # Default to ENABLED if the setting is empty
        if [ "$current_backup_settings" = "TBD" ]
        then
            Update_Custom_Settings "FW_Auto_Backupmon" "ENABLED"
            current_backup_settings="ENABLED"
        fi

        if [ "$current_backup_settings" = "ENABLED" ]
        then
            # Extract version number from backupmon.sh
            local BM_VERSION="$(grep "^Version=" /jffs/scripts/backupmon.sh | awk -F'"' '{print $2}')"

            # Adjust version format from 1.46 to 1.4.6 if needed
            local DOT_COUNT="$(echo "$BM_VERSION" | tr -cd '.' | wc -c)"
            if [ "$DOT_COUNT" -eq 0 ]
            then
                # If there's no dot, it's a simple version like "1" (unlikely but let's handle it)
                BM_VERSION="${BM_VERSION}.0.0"
            elif [ "$DOT_COUNT" -eq 1 ]
            then
                # For versions like 1.46, insert a dot before the last two digits
                BM_VERSION="$(echo "$BM_VERSION" | sed 's/\.\([0-9]\)\([0-9]\)/.\1.\2/')"
            fi

            # Convert version strings to comparable numbers
            local currentBM_version="$(_ScriptVersionStrToNum_ "$BM_VERSION")"
            local requiredBM_version="$(_ScriptVersionStrToNum_ "1.5.3")"

            # Check if BACKUPMON version is greater than or equal to 1.5.3
            if [ "$currentBM_version" -ge "$requiredBM_version" ]
            then
                # Execute the backup script if it exists #
                echo ""
                Say "Backup Started (by BACKUPMON)"
                sh /jffs/scripts/backupmon.sh -backup >/dev/null
                BE=$?
                Say "Backup Finished"
                echo ""
                if [ $BE -eq 0 ]
                then
                    Say "Backup Completed Successfully"
                    echo ""
                else
                    Say "Backup Failed"
                    echo ""
                    _SendEMailNotification_ NEW_BM_BACKUP_FAILED
                    _DoCleanUp_ 1
                    return 1
                fi
            else
                # BACKUPMON version is not sufficient
                echo ""
                Say "${REDct}**IMPORTANT NOTICE**:${NOct}"
                echo ""
                Say "Backup script (BACKUPMON) is installed; but version $BM_VERSION does not meet the minimum required version of 1.5.3."
                Say "Skipping backup. Please update your version of BACKUPMON."
                echo ""
            fi
        else
            Say "Backup script (BACKUPMON) is disabled in the advanced options. Skipping backup."
            echo ""
        fi
    else
        local current_backup_settings="$(Get_Custom_Setting "FW_Auto_Backupmon")"
        if [ "$current_backup_settings" != "TBD" ]
        then
            Delete_Custom_Settings "FW_Auto_Backupmon"
        fi
        Say "Backup script (BACKUPMON) is not installed. Skipping backup."
        echo ""
    fi
    return 0
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
_RunOfflineUpdateNow_()
{
    local retCode
    local offlineConfigFile="${SETTINGS_DIR}/offline_updates.txt"

    _ClearOfflineUpdateState_()
    {
        offlineUpdateTrigger=false
        theMenuReturnPromptMsg="$mainMenuReturnPromptStr"
        if [ $# -eq 0 ] || [ -z "$1" ] ; then return 0 ; fi
        [ "$1" != "1" ] && printf "$1"
        _WaitForEnterKey_ "$advnMenuReturnPromptStr"
    }

    [ ! -s "$offlineConfigFile" ] && return 2

    # Source the configuration file #
    . "$offlineConfigFile"

    # Check required parameter #
    if [ -z "${FW_OFFLINE_UPDATE_IS_ALLOWED:+xSETx}" ] || \
       [ "$FW_OFFLINE_UPDATE_IS_ALLOWED" != "true" ]
    then return 2 ; fi

    # Reset FW_OFFLINE_UPDATE_ACCEPT_RISK to false #
    if grep -q "^FW_OFFLINE_UPDATE_ACCEPT_RISK=" "$offlineConfigFile"
    then
        sed -i "s/^FW_OFFLINE_UPDATE_ACCEPT_RISK=.*/FW_OFFLINE_UPDATE_ACCEPT_RISK=\"false\"/" "$offlineConfigFile"
    fi

    clear
    printf "\n${REDct}***WARNING***${NOct}"
    printf "\nYou are about to initiate an ${REDct}offline${NOct} firmware update."
    printf "\nThe firmware image to be flashed is ${REDct}unvetted${NOct} and of ${REDct}unknown${NOct} origin.\n"
    printf "\n1. This feature is intended for developers and advanced users only."    
    printf "\n2. No support will be offered when flashing firmware offline."
    printf "\n3. This offline feature is excluded from documentation on purpose.\n"
    printf "\nDo you acknowledge the risk and wish to proceed?"
    printf "\nYou must type '${REDct}YES${NOct}' to continue."
    printf "\n---------------------------------------------------\n"

    read -r response
    if [ "$response" = "YES" ]
    then
        # Add or update the setting to true #
        if grep -q "^FW_OFFLINE_UPDATE_ACCEPT_RISK=" "$offlineConfigFile"
        then
            sed -i "s/^FW_OFFLINE_UPDATE_ACCEPT_RISK=.*/FW_OFFLINE_UPDATE_ACCEPT_RISK=\"true\"/" "$offlineConfigFile"
        else
            # Ensure the new setting is added on a new line
            echo "" >> "$offlineConfigFile"
            echo "FW_OFFLINE_UPDATE_ACCEPT_RISK=\"true\"" >> "$offlineConfigFile"
        fi
    else
        # Add or update the setting to false #
        if grep -q "^FW_OFFLINE_UPDATE_ACCEPT_RISK=" "$offlineConfigFile"
        then
            sed -i "s/^FW_OFFLINE_UPDATE_ACCEPT_RISK=.*/FW_OFFLINE_UPDATE_ACCEPT_RISK=\"false\"/" "$offlineConfigFile"
        else
            # Ensure the new setting is added on a new line #
            echo "" >> "$offlineConfigFile"
            echo "FW_OFFLINE_UPDATE_ACCEPT_RISK=\"false\"" >> "$offlineConfigFile"
        fi
        _ClearOfflineUpdateState_ "Offline update was aborted. Exiting.\n"
        return 1
    fi
    clear
    _ShowLogo_
    printf "\n---------------------------------------------------\n"

    offlineUpdateTrigger=true
    theMenuReturnPromptMsg="$advnMenuReturnPromptStr"

    clear
    # Create directory for downloading & extracting firmware #
    if ! _CreateDirectory_ "$FW_ZIP_DIR"
    then
        _ClearOfflineUpdateState_ 1 ; return 1
    fi
    printf "\n---------------------------------------------------\n"
    if "$isGNUtonFW"
    then
        printf "\nPlease copy your firmware update file (.w or .pkgtb) using the *original* filename to this directory:"
    else
        printf "\nPlease copy your firmware ZIP file (using the *original* ZIP filename) to this directory:"
    fi
    printf "\n[${GRNct}$FW_ZIP_DIR${NOct}]\n"
    printf "\nPress '${GRNct}Y${NOct}' when completed, or '${REDct}N${NOct}' to cancel.\n"
    printf "\n---------------------------------------------------\n"
    if _WaitForYESorNO_
    then
        clear
        printf "\n---------------------------------------------------\n"
        printf "\nContinuing to the update file selection process.\n"
        if _SelectOfflineUpdateFile_
        then
            if "$isGNUtonFW"
            then
                # Extract the filename from the path #
                original_filename="$(basename "$selected_file")"
                # Sanitize filename by removing problematic characters (if necessary) #
                sanitized_filename="$(echo "$original_filename" | sed 's/[^a-zA-Z0-9._-]//g')"
                # Extract the file extension #
                extension="${sanitized_filename##*.}"
                FW_DL_FPATH="${FW_ZIP_DIR}/${FW_FileName}.${extension}"
                _GnutonBuildSelection_
                set -- $(_GetLatestFWUpdateVersionFromGithub_ "$FW_GITURL_RELEASE" "$firmware_choice")
                retCode="$?"
            else
                set -- $(_GetLatestFWUpdateVersionFromWebsite_ "$FW_SFURL_RELEASE")
                retCode="$?"
            fi
            if [ "$retCode" -eq 0 ] && [ $# -eq 2 ] && \
               [ "$1" != "**ERROR**" ] && [ "$2" != "**NO_URL**" ]
            then
                release_link="$2"
                if _AcquireLock_ cliFileLock
                then
                    _RunFirmwareUpdateNow_
                    _ReleaseLock_ cliFileLock
                fi
                _ClearOfflineUpdateState_
            else
                Say "${REDct}**ERROR**${NOct}: No firmware release URL was found for [$PRODUCT_ID] router model."
                _ClearOfflineUpdateState_ 1
                return 1
            fi
        else
            _ClearOfflineUpdateState_ 1
            return 1
        fi
    else
        _ClearOfflineUpdateState_ "Offline update process was cancelled. Exiting.\n"
        return 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
_RunFirmwareUpdateNow_()
{
    # Double-check the directory exists before using it #
    [ ! -d "$FW_LOG_DIR" ] && mkdir -p -m 755 "$FW_LOG_DIR"

    # Set up the custom log file #
    userLOGFile="${FW_LOG_DIR}/${MODEL_ID}_FW_Update_$(date '+%Y-%m-%d_%H_%M_%S').log"
    touch "$userLOGFile"  ## Must do this to indicate custom log file is enabled ##

    # Check if the router model is supported OR if
    # it has the minimum firmware version supported.
    if "$routerModelCheckFailed"
    then
        Say "${REDct}*WARNING*:${NOct} The current router model is not supported by this script."
        if "$inMenuMode"
        then
            printf "\nWould you like to uninstall the script now?"
            if _WaitForYESorNO_
            then
                _DoUnInstallation_
                return 0
            else
                Say "Uninstallation cancelled. Exiting script."
                _WaitForEnterKey_ "$theMenuReturnPromptMsg"
                return 0
            fi
        else
            Say "Exiting script due to unsupported router model."
            _DoExit_ 1
        fi
    fi
    if "$MinFirmwareVerCheckFailed" && ! "$offlineUpdateTrigger"
    then
        Say "${REDct}*WARNING*:${NOct} The current firmware version is below the minimum supported.
Please manually update to version ${GRNct}${MinSupportedFirmwareVers}${NOct} or higher to use this script.\n"
        "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
        return 1
    fi

    echo
    Say "${GRNct}MerlinAU${NOct} v$SCRIPT_VERSION"
    Say "Running the update task now... Checking for F/W updates..."
    FlashStarted=true

    #---------------------------------------------------------------#
    # Check if an expected USB-attached drive is still mounted.
    # Make a special case when USB drive has Entware installed.
    #---------------------------------------------------------------#
    if echo "$FW_ZIP_BASE_DIR" | grep -qE "^(/tmp/mnt/|/tmp/opt/|/opt/)" && \
       ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR" 1
    then
        Say "Expected directory path $FW_ZIP_BASE_DIR is NOT found."
        Say "${REDct}**ERROR**${NOct}: Required USB storage device is not connected or not mounted correctly."
        "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
        return 1
    fi

    #---------------------------------------------------------#
    # If the expected directory path for the ZIP file is not
    # found, we select the $HOME path instead as a temporary
    # fallback. This should work if free RAM is >= ~150MB.
    #---------------------------------------------------------#
    if [ ! -d "$FW_ZIP_BASE_DIR" ]
    then
        Say "Expected directory path $FW_ZIP_BASE_DIR is NOT found."
        Say "Using temporary fallback directory: /home/root"
        "$inMenuMode" && { _WaitForYESorNO_ "Continue?" || return 1 ; }
        # Continue #
        _SetUp_FW_UpdateZIP_DirectoryPaths_ "/home/root"
    fi

    if ! node_online_status="$(_NodeActiveStatus_)"
    then node_online_status="" 
    else _ProcessMeshNodes_ 0
    fi

    local retCode  credsBase64=""
    local currentVersionNum=""  releaseVersionNum=""
    local current_version=""

    # Create directory for downloading & extracting firmware #
    if ! _CreateDirectory_ "$FW_ZIP_DIR" ; then return 1 ; fi

    # In case ZIP directory is different from BIN directory #
    if [ "$FW_ZIP_DIR" != "$FW_BIN_DIR" ] && \
       ! _CreateDirectory_ "$FW_BIN_DIR" ; then return 1 ; fi

    # Get current firmware version #
    current_version="$(_GetCurrentFWInstalledLongVersion_)"

    #---------------------------------------------------------#
    # If the "F/W Update Check" in the WebGUI is disabled
    # return without further actions. This allows users to
    # control the "F/W Auto-Update" feature from one place.
    # However, when running in "Menu Mode" the assumption
    # is that the user wants to do a MANUAL Update Check
    # regardless of the state of the "F/W Update Check."
    #---------------------------------------------------------#
    if ! "$offlineUpdateTrigger"
    then
        FW_UpdateCheckState="$(nvram get firmware_check_enable)"
        [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0

        if [ "$FW_UpdateCheckState" -eq 0 ]
        then
            Say "Firmware update check is currently disabled."
            "$inMenuMode" && _WaitForEnterKey_ || return 1
        fi

        #------------------------------------------------------
        # If the "New F/W Update" flag has been set get the
        # "New F/W Release Version" from the router itself.
        # If no new F/W version update is available return.
        #------------------------------------------------------
        if ! release_version="$(_GetLatestFWUpdateVersionFromRouter_)" || \
           ! _CheckNewUpdateFirmwareNotification_ "$current_version" "$release_version"
        then
            Say "No new firmware version update is found for [$PRODUCT_ID] router model."
            "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
            return 1
        fi

        # Use set to read the output of the function into variables #
        if "$isGNUtonFW"
        then
           Say "Using release information for Gnuton Firmware."
           _GnutonBuildSelection_
           md5_url="$(GetLatestFirmwareMD5Url "$FW_GITURL_RELEASE" "$firmware_choice")"
           GnutonChangeLogURL="$(GetLatestChangelogUrl "$FW_GITURL_RELEASE")"
           set -- $(_GetLatestFWUpdateVersionFromGithub_ "$FW_GITURL_RELEASE" "$firmware_choice")
           retCode="$?"
        else
           Say "Using release information for Merlin Firmware."
           set -- $(_GetLatestFWUpdateVersionFromWebsite_ "$FW_SFURL_RELEASE")
           retCode="$?"
        fi
        if [ "$retCode" -eq 0 ] && [ $# -eq 2 ] && \
           [ "$1" != "**ERROR**" ] && [ "$2" != "**NO_URL**" ]
        then
            release_version="$1"
            release_link="$2"
        else
            Say "${REDct}**ERROR**${NOct}: No firmware release URL was found for [$PRODUCT_ID] router model."
            "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
            return 1
        fi

        if ! _CheckTimeToUpdateFirmware_ "$current_version" "$release_version"
        then
            "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
            return 0
        fi
    fi

    # Extracting the F/W Update codebase number #
    fwUpdateBaseNum="$(echo "$release_version" | cut -d'.' -f1)"
    # Inserting dots between each number #
    dottedVersion="$(echo "$fwUpdateBaseNum" | sed 's/./&./g' | sed 's/.$//')"

    ## Check for Login Credentials ##
    credsBase64="$(Get_Custom_Setting credentials_base64)"
    if [ -z "$credsBase64" ] || [ "$credsBase64" = "TBD" ]
    then
        Say "${REDct}**ERROR**${NOct}: No login credentials have been saved. Use the Main Menu to save login credentials."
        "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
        return 1
    fi

    ##---------------------------------------##
    ## Added by ExtremeFiretop [2023-Dec-09] ##
    ##---------------------------------------##
    # Get the required memory for the firmware download and extraction
    requiredRAM_kb="$(_GetRequiredRAM_KB_ "$release_link")"
    if ! _HasRouterMoreThan256MBtotalRAM_ && [ "$requiredRAM_kb" -gt 51200 ]
    then
        if ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR" 1
        then
            Say "${REDct}**ERROR**${NOct}: A USB drive is required for the F/W update due to limited RAM."
            "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
            return 1
        fi
    fi

    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    ##----------------------------------------##
    ## Modified by Martinski W. [2024-Jul-29] ##
    ##----------------------------------------##
    _RunBackupmon_
    retCode="$?"

    if [ "$retCode" -ne 0 ]
    then
        Say "\n${REDct}**IMPORTANT NOTICE**:${NOct}\n"
        Say "The firmware flash has been ${REDct}CANCELLED${NOct} due to a failed backup from BACKUPMON.\n"
        Say "Please fix the BACKUPMON configuration, or consider uninstalling it to proceed flash.\n"
        Say "Resolving the BACKUPMON configuration is HIGHLY recommended for safety of the upgrade.\n"
        "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
        _Reset_LEDs_
        return 1
    fi

    # Background function to create a blinking LED effect #
    _Toggle_LEDs_ 2 & Toggle_LEDs_PID=$!

    # Compare versions before deciding to download #
    if ! "$offlineUpdateTrigger" && \
       [ "$releaseVersionNum" -gt "$currentVersionNum" ]
    then
        Say "Latest release version is ${GRNct}${release_version}${NOct}."
        Say "Downloading ${GRNct}${release_link}${NOct}"
        echo

        ##------------------------------------------##
        ## Modified by ExtremeFiretop [2024-Apr-24] ##
        ##------------------------------------------##
        # Avoid error message about HSTS database #
        wgetHstsFile="/tmp/home/root/.wget-hsts"
        [ -s "$wgetHstsFile" ] && chmod 0644 "$wgetHstsFile"

        if "$isGNUtonFW"
        then
            _DownloadForGnuton_
            retCode="$?"
        else
            _DownloadForMerlin_
            retCode="$?"
        fi
        if [ "$retCode" -ne 0 ]
        then
            Say "${REDct}**ERROR**${NOct}: Firmware files were not downloaded successfully."
            "$inMenuMode" && _WaitForEnterKey_ "$mainMenuReturnPromptStr"
            _Reset_LEDs_
            return 1
        fi
    fi

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Feb-18] ##
    ##------------------------------------------##
    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Apr-21] ##
    ##------------------------------------------##
    if "$isGNUtonFW"
    then
        _CopyGnutonFiles_
        retCode="$?"
    else
        _UnzipMerlin_
        retCode="$?"
    fi
    if [ "$retCode" -ne 0 ]
    then
        "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
        _Reset_LEDs_
        return 1
    fi

    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    # Navigate to the firmware directory
    cd "$FW_BIN_DIR"

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Aug-11] ##
    ##------------------------------------------##
    if ! { "$isGNUtonFW" && "$offlineUpdateTrigger" ; }
    then
        if ! _ChangelogVerificationCheck_ "interactive"
        then
            "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
            _Reset_LEDs_
            return 1
        fi
    fi

    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Dec-21] ##
    ##------------------------------------------##
    pure_file="$(ls -1 | grep -iE '.*[.](w|pkgtb)$' | grep -iv 'rog')"

    if [ "$fwInstalledBaseVers" -le 3004 ] && [ "$fwUpdateBaseNum" -le 3004 ]
    then
        # Handle upgrades from 3004 and lower #

        # Detect ROG firmware file #
        rog_file="$(ls | grep -i '_rog_')"

        # Fetch the previous choice from the settings file
        previous_choice="$(Get_Custom_Setting "ROGBuild")"

        # Check if a ROG build is present #
        if [ -n "$rog_file" ]
        then
            # Use the previous choice if it exists and valid, else prompt the user for their choice in interactive mode
            if [ "$previous_choice" = "ENABLED" ]
            then
                Say "ROG Build selected for flashing"
                firmware_file="$rog_file"
            elif [ "$previous_choice" = "DISABLED" ]
            then
                Say "Pure Build selected for flashing"
                firmware_file="$pure_file"
            elif [ "$inMenuMode" = true ]
            then
                printf "${REDct}Found ROG build: $rog_file.${NOct}\n"
                printf "${REDct}Would you like to use the ROG build?${NOct}\n"
                printf "Enter your choice (y/n): "
                read -r choice
                if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                    Say "ROG Build selected for flashing"
                    firmware_file="$rog_file"
                    Update_Custom_Settings "ROGBuild" "ENABLED"
                else
                    Say "Pure Build selected for flashing"
                    firmware_file="$pure_file"
                    Update_Custom_Settings "ROGBuild" "DISABLED"
                fi
            else
                # Default to pure_file in non-interactive mode if no previous choice
                Say "Pure Build selected for flashing"
                Update_Custom_Settings "ROGBuild" "DISABLED"
                firmware_file="$pure_file"
            fi
        else
            # No ROG build found, use the pure build
            Say "No ROG Build detected. Skipping."
            firmware_file="$pure_file"
        fi
    elif [ "$fwInstalledBaseVers" -eq 3004 ] && [ "$fwUpdateBaseNum" -ge 3006 ]
    then
        # Handle upgrade from 3004 to 3006
        # Fetch the previous choice from the settings file
        previous_choice="$(Get_Custom_Setting "ROGBuild")"

        # Handle upgrade from 3004 to 3006 if there is a ROG setting
        if [ "$previous_choice" = "ENABLED" ]
        then
            Say "Upgrading from 3004 to 3006, ROG UI is no longer supported, auto-selecting Pure UI firmware."
            firmware_file="$pure_file"
            Update_Custom_Settings "ROGBuild" "DISABLED"
        else
            firmware_file="$pure_file"
        fi
    else
        # Handle upgrades from 3006 and higher #
        firmware_file="$pure_file"
    fi

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Aug-11] ##
    ##------------------------------------------##
    if "$offlineUpdateTrigger"
    then
        if ! "$isGNUtonFW"
        then
            _CheckOfflineFirmwareSHA256_
            retCode="$?"
        elif [ -f "${FW_BIN_DIR}/${FW_FileName}.md5" ]
        then
            _CheckFirmwareMD5_
            retCode="$?"
        else
            retCode=0  # Skip if the MD5 file does not exist
        fi
    else
        if "$isGNUtonFW"
        then
            _CheckFirmwareMD5_
            retCode="$?"
        else
            _CheckOnlineFirmwareSHA256_
            retCode="$?"
        fi
    fi
    if [ "$retCode" -ne 0 ]
    then
        "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
        _Reset_LEDs_
        return 1
    fi

    ##----------------------------------------##
    ## Modified by Martinski W. [2024-Mar-16] ##
    ##----------------------------------------##
    freeRAM_kb="$(_GetFreeRAM_KB_)"
    availableRAM_kb="$(_GetAvailableRAM_KB_)"
    Say "Required RAM: ${requiredRAM_kb} KB - RAM Free: ${freeRAM_kb} KB - RAM Available: ${availableRAM_kb} KB"
    check_memory_and_prompt_reboot "$requiredRAM_kb" "$availableRAM_kb"

    routerURLstr="$(_GetRouterURL_)"
    Say "Router Web URL is: ${routerURLstr}"

    if "$isInteractive"
    then
        printf "${GRNct}**IMPORTANT**:${NOct}\nThe firmware flash is about to start.\n"
        printf "Press <Enter> to stop now, or type ${GRNct}Y${NOct} to continue.\n"
        printf "Once started, the flashing process CANNOT be interrupted.\n"
        if ! _WaitForYESorNO_ "Continue?"
        then
            Say "F/W Update was cancelled by user."
            _DoCleanUp_ 1 "$keepZIPfile" "$keepWfile"
            return 1
        fi
    fi

    #------------------------------------------------------------#
    # Restart the WebGUI to make sure nobody else is logged in
    # so that the F/W Update can start without interruptions.
    #------------------------------------------------------------#
    "$isInteractive" && printf "\nRestarting web server... Please wait.\n"
    /sbin/service restart_httpd >/dev/null 2>&1 &
    sleep 5

    # Send last email notification before F/W flash #
    _SendEMailNotification_ START_FW_UPDATE_STATUS

    ##------------------------------------------##
    ## Modified by ExtremeFiretop [2024-Sep-07] ##
    ##------------------------------------------##
    curl_response="$(curl -k "${routerURLstr}/login.cgi" \
    --referer "${routerURLstr}/Main_Login.asp" \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: ${routerURLstr}/" \
    -H 'Connection: keep-alive' \
    --data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=${credsBase64}" \
    --cookie-jar /tmp/cookie.txt)"

    if echo "$curl_response" | grep -Eq 'url=index\.asp|url=GameDashboard\.asp'
    then
        if [ -f /opt/bin/diversion ]
        then
            # Extract version number from Diversion
            local DIVER_VERSION="$(grep "^VERSION=" /opt/bin/diversion | awk -F'=' '{print $2}' | tr -d ' ')"

            # Adjust version format from 1.46 to 1.4.6 if needed
            local DDOT_COUNT="$(echo "$DIVER_VERSION" | tr -cd '.' | wc -c)"
            if [ "$DDOT_COUNT" -eq 0 ]; then
                # If there's no dot, it's a simple version like "1" (unlikely but let's handle it)
                DIVER_VERSION="${DIVER_VERSION}.0.0"
            elif [ "$DDOT_COUNT" -eq 1 ]; then
                # Check if there is only one character after the dot
                if echo "$DIVER_VERSION" | grep -qE '^[0-9]+\.[0-9]{1}$'; then
                    # If the version is like 5.2, convert it to 5.2.0
                    DIVER_VERSION="${DIVER_VERSION}.0"
                else
                    # For versions like 5.26, insert a dot between the last two digits
                    DIVER_VERSION="$(echo "$DIVER_VERSION" | sed 's/\.\([0-9]\)\([0-9]\)/.\1.\2/')"
                fi
            fi

            # Convert version strings to comparable numbers
            local currentDIVER_version="$(_ScriptVersionStrToNum_ "$DIVER_VERSION")"
            local requiredDIVER_version="$(_ScriptVersionStrToNum_ "5.2.0")"

            # Diversion unmount command also unloads entware services #
            Say "Stopping Diversion service..."
            if [ "$currentDIVER_version" -ge "$requiredDIVER_version" ]
            then
                /opt/bin/diversion temp_disable &
            else
                local AllowVPN="$(Get_Custom_Setting Allow_Updates_OverVPN)"
                if [ "$AllowVPN" = "DISABLED" ]
                then
                    /opt/bin/diversion unmount &
                fi
            fi
            sleep 5
        fi

        #-------------------------------------------------------
        # Stop toggling LEDs during the F/W flash to avoid
        # modifying NVRAM during the actual flash process.
        #-------------------------------------------------------
        _Reset_LEDs_

        ##----------------------------------------##
        ## Modified by Martinski W. [2024-Jul-24] ##
        ##----------------------------------------##
        # Remove SIGHUP to allow script to continue #
        trap '' HUP

        # Stop Entware services WITHOUT exceptions BEFORE the F/W flash #
        _EntwareServicesHandler_ stop -noskip

        ##-------------------------------------##
        ## Added by Martinski W. [2024-Sep-15] ##
        ##-------------------------------------##
        # Remove cron jobs from 3rd-party Add-Ons #
        _RemoveCronJobsFromAddOns_

        _SendEMailNotification_ POST_REBOOT_FW_UPDATE_SETUP
        echo
        Say "Flashing ${GRNct}${firmware_file}${NOct}... ${REDct}Please wait for reboot in about 4 minutes or less.${NOct}"
        echo

        # *WARNING*: NO MORE logging at this point & beyond #
        /sbin/ejusb -1 0 -u 1 2>/dev/null

        #----------------------------------------------------------------------------------#
        # **IMPORTANT NOTE**:
        # Due to the nature of 'nohup' and the specific behavior of this 'curl' request,
        # the following 'curl' command MUST always be the last step in this block.
        # Do NOT insert any commands after it! (unless you understand the implications).
        #----------------------------------------------------------------------------------#
        nohup curl -k "${routerURLstr}/upgrade.cgi" \
        --referer "${routerURLstr}/Advanced_FirmwareUpgrade_Content.asp" \
        --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
        -H 'Accept-Language: en-US,en;q=0.5' \
        -H "Origin: ${routerURLstr}/" \
        -F 'current_page=Advanced_FirmwareUpgrade_Content.asp' \
        -F 'next_page=' \
        -F 'action_mode=' \
        -F 'action_script=' \
        -F 'action_wait=' \
        -F 'preferred_lang=EN' \
        -F "firmver=${dottedVersion}" \
        -F "file=@${firmware_file}" \
        --cookie /tmp/cookie.txt > /tmp/upload_response.txt 2>&1 &
        curlPID=$!

        #----------------------------------------------------------#
        # In the rare case that the F/W Update gets "stuck" for
        # some reason & the "curl" cmd never returns, we create
        # a background child process that sleeps for 3 minutes
        # and then kills the "curl" process if it still exists.
        # Otherwise, this child process does nothing & returns.
        # NORMALLY the "Curl" command returns almost instantly
        # once the upload is complete.
        #----------------------------------------------------------#
        (
           sleep 180
           if [ "$curlPID" -gt 0 ]
           then
               kill -EXIT $curlPID 2>/dev/null || return
               kill -TERM $curlPID 2>/dev/null
           fi
        ) &
        wait $curlPID ; curlPID=0
        #----------------------------------------------------------#
        # Let's wait for 3 minutes here. If the router does not
        # reboot by itself after the process returns, do it now.
        #----------------------------------------------------------#
        sleep 180
        _ReleaseLock_
        /sbin/service reboot
    else
        Say "${REDct}**ERROR**${NOct}: Router Login failed."
        if "$inMenuMode" || "$isInteractive"
        then
            printf "\n${routerLoginFailureMsg}\n\n"
            _WaitForEnterKey_
        fi
        _SendEMailNotification_ FAILED_FW_UPDATE_STATUS
        _DoCleanUp_ 1 "$keepZIPfile" "$keepWfile"
        _EntwareServicesHandler_ start
        if [ -f /opt/bin/diversion ]
        then
            Say "Restarting Diversion service..."
            if [ "$currentDIVER_version" -ge "$requiredDIVER_version" ]
            then
                /opt/bin/diversion enable &
            else
                AllowVPN="$(Get_Custom_Setting Allow_Updates_OverVPN)"
                if [ "$AllowVPN" = "DISABLED" ]
                then
                    Say "Unable to Restart Diversion. Please reboot to restart entware services."
                fi
            fi
            sleep 5
        fi
    fi

    "$inMenuMode" && _WaitForEnterKey_ "$theMenuReturnPromptMsg"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Nov-17] ##
##----------------------------------------##
_PostUpdateEmailNotification_()
{
   _DelPostUpdateEmailNotifyScriptHook_
   currentChangelogValue="$(Get_Custom_Setting CheckChangeLog)"
   if [ "$currentChangelogValue" = "ENABLED" ]
   then
      Update_Custom_Settings "FW_New_Update_Changelog_Approval" "TBD"
   fi

   local theWaitDelaySecs=10
   local maxWaitDelaySecs=600  #10 minutes#
   local curWaitDelaySecs=0
   local logMsg="Post-Reboot Update Email Notification Wait Timeout"
   Say "START of ${logMsg}."

   #--------------------------------------------------------------
   # Wait until all services are started, including WAN & NTP
   # so the system clock is updated/synced with correct time.
   #--------------------------------------------------------------
   while [ "$curWaitDelaySecs" -lt "$maxWaitDelaySecs" ]
   do
      if [ "$(nvram get ntp_ready)" -eq 1 ] && \
         [ "$(nvram get start_service_ready)" -eq 1 ] && \
         [ "$(nvram get success_start_service)" -eq 1 ]
      then break ; fi

      if [ "$curWaitDelaySecs" -gt 0 ] && \
         [ "$((curWaitDelaySecs % 60))" -eq 0 ]
      then Say "$logMsg [$curWaitDelaySecs secs.]..." ; fi

      sleep $theWaitDelaySecs
      curWaitDelaySecs="$((curWaitDelaySecs + theWaitDelaySecs))"
   done

   if [ "$curWaitDelaySecs" -lt "$maxWaitDelaySecs" ]
   then Say "$logMsg [$curWaitDelaySecs sec.] succeeded."
   else Say "$logMsg [$maxWaitDelaySecs sec.] expired."
   fi

   Say "END of $logMsg [$$curWaitDelaySecs sec.]"
   sleep 20  ## Let's wait a bit & proceed ##
   _SendEMailNotification_ POST_REBOOT_FW_UPDATE_STATUS
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-05] ##
##----------------------------------------##
_PostRebootRunNow_()
{
   _DelPostRebootRunScriptHook_

   local theWaitDelaySecs=10
   local maxWaitDelaySecs=600  #10 minutes#
   local curWaitDelaySecs=0
   local logMsg="Post-Reboot F/W Update Run Wait Timeout"
   Say "START of ${logMsg}."

   #--------------------------------------------------------------
   # Wait until all services are started, including WAN & NTP
   # so the system clock is updated/synced with correct time.
   # Wait for "F/W ZIP BASE" directory to be mounted as well.
   #--------------------------------------------------------------
   while [ "$curWaitDelaySecs" -lt "$maxWaitDelaySecs" ]
   do
      if [ -d "$FW_ZIP_BASE_DIR" ] && \
         [ "$(nvram get ntp_ready)" -eq 1 ] && \
         [ "$(nvram get start_service_ready)" -eq 1 ] && \
         [ "$(nvram get success_start_service)" -eq 1 ]
      then break ; fi

      if [ "$curWaitDelaySecs" -gt 0 ] && \
         [ "$((curWaitDelaySecs % 60))" -eq 0 ]
      then Say "$logMsg [$curWaitDelaySecs secs.]..." ; fi

      sleep $theWaitDelaySecs
      curWaitDelaySecs="$((curWaitDelaySecs + theWaitDelaySecs))"
   done

   if [ "$curWaitDelaySecs" -lt "$maxWaitDelaySecs" ]
   then Say "$logMsg [$curWaitDelaySecs sec.] succeeded."
   else Say "$logMsg [$maxWaitDelaySecs sec.] expired."
   fi

   Say "END of $logMsg [$$curWaitDelaySecs sec.]"
   sleep 30  ## Let's wait a bit & proceed ##
   if _AcquireLock_ cliFileLock
   then
       _RunFirmwareUpdateNow_
       _ReleaseLock_ cliFileLock
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-17] ##
##----------------------------------------##
_DelFWAutoUpdateHook_()
{
   local hookScriptFile

   hookScriptFile="$hookScriptFPath"
   if [ ! -f "$hookScriptFile" ] ; then return 1 ; fi

   if grep -qE "$CRON_SCRIPT_JOB" "$hookScriptFile"
   then
       sed -i -e '/\/'"$ScriptFileName"' addCronJob &  '"$hookScriptTagStr"'/d' "$hookScriptFile"
       if [ $? -eq 0 ]
       then
           Say "F/W Update cron job hook was deleted successfully from '$hookScriptFile' script."
       fi
   else
       printf "F/W Update cron job hook does not exist in '$hookScriptFile' script.\n"
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-17] ##
##----------------------------------------##
_AddFWAutoUpdateHook_()
{
   local hookScriptFile  jobHookAdded=false

   hookScriptFile="$hookScriptFPath"
   if [ ! -f "$hookScriptFile" ]
   then
      jobHookAdded=true
      {
        echo "#!/bin/sh"
        echo "# $hookScriptFName"
        echo "#"
        echo "$CRON_SCRIPT_HOOK"
      } > "$hookScriptFile"
   #
   elif ! grep -qE "$CRON_SCRIPT_JOB" "$hookScriptFile"
   then
      jobHookAdded=true
      echo "$CRON_SCRIPT_HOOK" >> "$hookScriptFile"
   fi
   chmod 0755 "$hookScriptFile"

   if "$jobHookAdded"
   then Say "Cron job hook was added successfully to '$hookScriptFile' script."
   else Say "Cron job hook already exists in '$hookScriptFile' script."
   fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Nov-18] ##
##------------------------------------------##
_AddScriptAutoUpdateHook_()
{
   local hookScriptFile  jobHookAdded=false

   hookScriptFile="$hookScriptFPath"
   if [ ! -f "$hookScriptFile" ]
   then
      jobHookAdded=true
      {
        echo "#!/bin/sh"
        echo "# $hookScriptFName"
        echo "#"
        echo "$DAILY_SCRIPT_UPDATE_CHECK_HOOK"
      } > "$hookScriptFile"
   #
   elif ! grep -qE "$DAILY_SCRIPT_UPDATE_CHECK_JOB" "$hookScriptFile"
   then
      jobHookAdded=true
      echo "$DAILY_SCRIPT_UPDATE_CHECK_HOOK" >> "$hookScriptFile"
   fi
   chmod 0755 "$hookScriptFile"

   if "$jobHookAdded"
   then Say "Cron job hook was added successfully to '$hookScriptFile' script."
   else Say "Cron job hook already exists in '$hookScriptFile' script."
   fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Nov-18] ##
##------------------------------------------##
_DelScriptAutoUpdateHook_()
{
   local hookScriptFile

   hookScriptFile="$hookScriptFPath"
   if [ ! -f "$hookScriptFile" ] ; then return 1 ; fi

   if grep -qE "$DAILY_SCRIPT_UPDATE_CHECK_JOB" "$hookScriptFile"
   then
       sed -i -e '/\/'"$ScriptFileName"' scriptAUCronJob &  '"$hookScriptTagStr"'/d' "$hookScriptFile"
       if [ $? -eq 0 ]
       then
           Say "ScriptAU cron job hook was deleted successfully from '$hookScriptFile' script."
       fi
   else
       printf "ScriptAU cron job hook does not exist in '$hookScriptFile' script.\n"
   fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-05] ##
##-------------------------------------##
_CheckForMinimumRequirements_()
{
   local requirementsCheckOK=true

   if [ "$(uname -o)" != "ASUSWRT-Merlin" ]
   then
       requirementsCheckOK=false
       Say "\n${CRITct}*WARNING*:${NOct} The current firmware installed is NOT ASUSWRT-Merlin.\n"
   fi

   if ! nvram get rc_support | grep -qwoF "am_addons"
   then
       requirementsCheckOK=false
       Say "\n${CRITct}*WARNING*:${NOct} The current firmware installed does NOT support add-ons.\n"
   fi

   if ! _CheckForMinimumModelSupport_
   then
       requirementsCheckOK=false
       Say "\n${CRITct}*WARNING*:${NOct} The current router model ${REDct}${FW_RouterModelID}${NOct} is NOT supported by this script.\n"
   fi

   if ! _CheckForMinimumVersionSupport_
   then
       requirementsCheckOK=false
       Say "\n${CRITct}*WARNING*:${NOct} The current firmware version is below the minimum supported by this script."
       printf "\nCurrent F/W version found: ${REDct}${FW_InstalledVersion}${NOct}"
       printf "\nMinimum version required: ${GRNct}${MinSupportedFirmwareVers}${NOct}\n"
   fi

   jffsScriptOK="$(nvram get jffs2_scripts)"
   if [ -n "$jffsScriptOK" ] && [ "$jffsScriptOK" -ne 1 ] && "$requirementsCheckOK"
   then
       nvram set jffs2_scripts=1
       nvram commit
       mkdir -p "$SCRIPTS_PATH"
       chmod 755 "$SCRIPTS_PATH"
       Say "\nThe NVRAM Custom JFFS Scripts option was ${GRNct}ENABLED${NOct}.\n"
   fi

   "$requirementsCheckOK" && return 0 || return 1
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_DoStartupInit_()
{
   _CreateDirPaths_
   _InitCustomSettingsConfig_
   _CreateSymLinks_
   _InitHelperJSFile_
   _SetVersionSharedSettings_ local "$SCRIPT_VERSION"

   if "$inRouterSWmode"
   then
       _Mount_WebUI_
       _AutoStartupHook_ create 2>/dev/null
       _AutoServiceEvent_ create 2>/dev/null
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
_DoInstallation_()
{
   local webguiOK=true
   
   if ! _AcquireLock_ cliFileLock ; then return 1 ; fi

   _CreateDirPaths_
   _InitCustomSettingsConfig_
   _CreateSymLinks_
   _InitHelperJSFile_
   _SetVersionSharedSettings_ local "$SCRIPT_VERSION"
   _SetVersionSharedSettings_ server "$SCRIPT_VERSION"
   _DownloadScriptFiles_ install

   if "$inRouterSWmode"
   then
       ! _Mount_WebUI_ && webguiOK=false
       _AutoStartupHook_ create 2>/dev/null
       _AutoServiceEvent_ create 2>/dev/null
   fi
   ! "$webguiOK" && _DoExit_ 1

   _ReleaseLock_ cliFileLock
   _ReleaseLock_ cliOptsLock

   if ! _AcquireLock_ cliMenuLock
   then Say "Exiting..." ; exit 1 ; fi
   _MainMenu_
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-18] ##
##----------------------------------------##
_DoUnInstallation_()
{
   printf "\n${BOLDct}Are you sure you want to uninstall $ScriptFileName script now${NOct}"
   ! _WaitForYESorNO_ && return 0

   if ! _AcquireLock_ cliFileLock ; then return 1 ; fi

   local doSaveConfig=false
   local savedCFGPath="${SCRIPTS_PATH}/${SCRIPT_NAME}_CFG.SAVED.TXT"

   printf "\n${BOLDct}Do you want to keep/save the $SCRIPT_NAME configuration file${NOct}"
   if _WaitForYESorNO_
   then
       doSaveConfig=true
       mv -f "$CONFIG_FILE" "$savedCFGPath"
   fi

   _DelFWAutoUpdateHook_
   _DelFWAutoUpdateCronJob_
   _DelScriptAutoUpdateHook_
   _DelScriptAutoUpdateCronJob_
   _DelPostRebootRunScriptHook_
   _DelPostUpdateEmailNotifyScriptHook_
   _SetVersionSharedSettings_ delete

   if "$inRouterSWmode"
   then
       _Unmount_WebUI_
       _AutoStartupHook_ delete 2>/dev/null
       _AutoServiceEvent_ delete 2>/dev/null 
   fi

   if rm -fr "${SETTINGS_DIR:?}" && \
      rm -fr "${SCRIPT_WEB_DIR:?}" && \
      rm -fr "${FW_BIN_BASE_DIR:?}/$ScriptDirNameD" && \
      rm -fr "${FW_LOG_BASE_DIR:?}/$ScriptDirNameD" && \
      rm -fr "${FW_ZIP_BASE_DIR:?}/$ScriptDirNameD" && \
      rm -f "$ScriptFilePath"
   then
       Say "${GRNct}Successfully Uninstalled.${NOct}"
   else
       Say "${CRITct}**ERROR**: Uninstallation failed.${NOct}"
   fi

   if "$doSaveConfig"
   then
       if mkdir -p "$SETTINGS_DIR"
       then
           chmod 755 "$SETTINGS_DIR"
           mv -f "$savedCFGPath" "$CONFIG_FILE"
       fi
   fi
   _DoExit_ 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Feb-18] ##
##-------------------------------------##
_SetEMailFormatType_()
{
   local doReturnToMenu
   local currFormatOpt  nextFormatOpt  currFormatStr

   currFormatOpt="$(Get_Custom_Setting FW_New_Update_EMail_FormatType)"
   if [ -z "$currFormatOpt" ] || [ "$currFormatOpt" = "TBD" ]
   then
       nextFormatOpt=""
       currFormatOpt="$sendEMailFormaType"
   else
       nextFormatOpt="$currFormatOpt"
   fi
   currFormatStr="Current Format: ${GRNct}${currFormatOpt}${NOct}"

   doReturnToMenu=false
   while true
   do
       printf "\n${SEPstr}"
       printf "\nChoose the format type for email notifications:\n"
       printf "\n  ${GRNct}1${NOct}. HTML\n"
       printf "\n  ${GRNct}2${NOct}. Plain Text\n"
       printf "\n  ${GRNct}e${NOct}. Exit to Advanced Menu\n"
       printf "${SEPstr}\n"
       printf "[$currFormatStr] Enter selection:  "
       read -r userInput

       [ -z "$userInput" ] && break

       if echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       case $userInput in
           1) nextFormatOpt="HTML" ; break
              ;;
           2) nextFormatOpt="Plain Text" ; break
              ;;
           *) echo ; _InvalidMenuSelection_
              ;;
       esac
   done

   "$doReturnToMenu" && return 0

   if [ "$nextFormatOpt" = "$currFormatOpt" ]
   then
       _RunEMailNotificationTest_ && _WaitForEnterKey_ "$advnMenuReturnPromptStr"
       return 0
   fi

   Update_Custom_Settings FW_New_Update_EMail_FormatType "$nextFormatOpt"
   printf "\nThe email format type was updated successfully.\n"

   _RunEMailNotificationTest_
   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
}

##-------------------------------------##
## Added by Martinski W. [2024-Feb-16] ##
##-------------------------------------##
_SetSecondaryEMailAddress_()
{
   local currCC_NameOpt  currCC_AddrOpt
   local nextCC_NameOpt  nextCC_AddrOpt
   local currCC_NameStr="Current Name/Alias:"
   local currCC_AddrStr="Current Address:"
   local clearOptStr="${GRNct}c${NOct}=Clear/Remove Setting"
   local doReturnToMenu  doClearSetting  minCharLen  maxCharLen  curCharLen

   currCC_NameOpt="$(Get_Custom_Setting FW_New_Update_EMail_CC_Name)"
   currCC_AddrOpt="$(Get_Custom_Setting FW_New_Update_EMail_CC_Address)"

   if [ -z "$currCC_AddrOpt" ] || [ "$currCC_AddrOpt" = "TBD" ]
   then
       nextCC_AddrOpt=""  currCC_AddrOpt=""
       currCC_AddrStr="$currCC_AddrStr ${REDct}NONE${NOct}"
   else
       nextCC_AddrOpt="$currCC_AddrOpt"
       currCC_AddrStr="$currCC_AddrStr ${GRNct}${currCC_AddrOpt}${NOct}"
   fi

   userInput=""
   minCharLen=10
   maxCharLen=64
   doReturnToMenu=false
   doClearSetting=false

   while true
   do
       printf "\nEnter a secondary email address to receive email notifications.\n"
       if [ -z "$currCC_AddrOpt" ]
       then printf "[${theADExitStr}] [${currCC_AddrStr}]:  "
       else printf "[${theADExitStr}] [${clearOptStr}] [${currCC_AddrStr}]:  "
       fi
       read -r userInput

       [ -z "$userInput" ] && break

       if echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       if echo "$userInput" | grep -qE "^(c|C)$"
       then doClearSetting=true ; break ; fi

       if ! echo "$userInput" | grep -qE ".+[@].+"
       then
           printf "\n${REDct}INVALID input.${NOct} "
           printf "No ampersand character [${GRNct}@${NOct}] is found.\n"
           _WaitForEnterKey_
           clear
           continue
       fi

       curCharLen="${#userInput}"
       if [ "$curCharLen" -lt "$minCharLen" ] || [ "$curCharLen" -gt "$maxCharLen" ]
       then
           printf "\n${REDct}INVALID input length${NOct} "
           printf "[Minimum=${GRNct}${minCharLen}${NOct}, Maximum=${GRNct}${maxCharLen}${NOct}]\n"
           _WaitForEnterKey_
           clear
           continue
       fi

       nextCC_AddrOpt="$userInput"
       break
   done

   if "$doReturnToMenu" || \
      { [ -z "$nextCC_AddrOpt" ] && [ -z "$currCC_AddrOpt" ] ; }
   then return 0 ; fi   ##NO Change##

   if "$doClearSetting" || \
      { [ -z "$nextCC_AddrOpt" ] && [ -n "$currCC_AddrOpt" ] ; }
   then
       Update_Custom_Settings FW_New_Update_EMail_CC_Name "TBD"
       Update_Custom_Settings FW_New_Update_EMail_CC_Address "TBD"
       echo "The secondary email address and associated name/alias were removed successfully."
       _WaitForEnterKey_ "$advnMenuReturnPromptStr"
       return 0
   fi

   if [ -z "$currCC_NameOpt" ] || [ "$currCC_NameOpt" = "TBD" ]
   then
       currCC_NameOpt=""
       nextCC_NameOpt="${nextCC_AddrOpt%%@*}"
       currCC_NameStr="$currCC_NameStr ${GRNct}${nextCC_NameOpt}${NOct}"
   else
       nextCC_NameOpt="$currCC_NameOpt"
       currCC_NameStr="$currCC_NameStr ${GRNct}${currCC_NameOpt}${NOct}"
   fi

   userInput=""
   minCharLen=6
   maxCharLen=64
   doReturnToMenu=false

   while true
   do
       printf "\nEnter a name or alias for the secondary email address.\n"
       printf "[${theADExitStr}] [${currCC_NameStr}]:  "
       read -r userInput

       if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then doReturnToMenu=true ; break ; fi

       curCharLen="${#userInput}"
       if [ "$curCharLen" -lt "$minCharLen" ] || [ "$curCharLen" -gt "$maxCharLen" ]
       then
           printf "${REDct}INVALID input length${NOct} "
           printf "[Minimum=${GRNct}${minCharLen}${NOct}, Maximum=${GRNct}${maxCharLen}${NOct}]\n"
           continue
       fi

       nextCC_NameOpt="$userInput"
       break;
   done

   if [ "$nextCC_AddrOpt" = "$currCC_AddrOpt" ] && [ "$nextCC_NameOpt" = "$currCC_NameOpt" ]
   then
       _RunEMailNotificationTest_ && _WaitForEnterKey_ "$advnMenuReturnPromptStr"
       return 0
   fi

   Update_Custom_Settings FW_New_Update_EMail_CC_Name "$nextCC_NameOpt"
   Update_Custom_Settings FW_New_Update_EMail_CC_Address "$nextCC_AddrOpt"
   printf "\nThe secondary email address and associated name/alias were updated successfully.\n"

   _RunEMailNotificationTest_
   _WaitForEnterKey_ "$advnMenuReturnPromptStr"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Apr-06] ##
##----------------------------------------##
_ValidatePrivateIPv4Address_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || \
      ! echo "$1" | grep -qE "^${IPv4addrs_RegEx}$" || \
      ! echo "$1" | grep -qE "^${IPv4privt_RegEx}"
   then return 1
   else return 0
   fi
}

##------------------------------------------##
## Modified by ExtremeFiretop [2024-Apr-30] ##
##------------------------------------------##
_ProcessMeshNodes_()
{
    includeExtraLogic="$1"  # Use '1' to include extra logic, '0' to exclude
    if [ $# -eq 0 ] || [ -z "$1" ]
    then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

    uid=1
    if ! node_list="$(_GetNodeIPv4List_)"
    then node_list="" ; fi

    if "$inRouterSWmode"
    then
        if [ -n "$node_list" ]
        then
            # Iterate over the list of nodes and print information for each node
            for nodeIPv4addr in $node_list
            do
                ! _ValidatePrivateIPv4Address_ "$nodeIPv4addr" && continue
                _GetNodeInfo_ "$nodeIPv4addr"
                if ! Node_FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromNode_ 1)"
                then
                    Node_FW_NewUpdateVersion="NONE FOUND"
                else
                    _CheckNodeFWUpdateNotification_ "$Node_combinedVer" "$Node_FW_NewUpdateVersion"
                fi

                # Apply extra logic if flag is '1'
                if [ "$includeExtraLogic" -eq 1 ]; then
                    _PrintNodeInfo "$nodeIPv4addr" "$node_online_status" "$Node_FW_NewUpdateVersion" "$uid"
                    uid="$((uid + 1))"
                fi
            done
            if [ -s "$tempNodeEMailList" ]; then
                _SendEMailNotification_ AGGREGATED_UPDATE_NOTIFICATION
            fi
        else
            if [ "$includeExtraLogic" -eq 1 ]; then
                printf "\n${padStr}${padStr}${padStr}${REDct}No AiMesh Node(s)${NOct}"
            fi
        fi
    fi
}

keepZIPfile=0
keepWfile=0
trap '_DoCleanUp_ 0 "$keepZIPfile" "$keepWfile" ; _DoExit_ 0' HUP INT QUIT ABRT TERM

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-05] ##
##----------------------------------------##
if [ $# -eq 1 ] && [ "$1" = "resetLockFile" ]
then
    ! _AcquireLock_ && printf "\nReset Lock and Exit...\n"
    _ReleaseLock_ ; exit 0
fi

currentBackupOption="$(Get_Custom_Setting "FW_Auto_Backupmon")"
if [ -f "/jffs/scripts/backupmon.sh" ]
then
    # If setting is empty, add it to the configuration file #
    if [ "$currentBackupOption" = "TBD" ]
    then
        Update_Custom_Settings FW_Auto_Backupmon "ENABLED"
    fi
else
    # If the configuration setting exists, delete it #
    if [ "$currentBackupOption" != "TBD" ]
    then
        Delete_Custom_Settings "FW_Auto_Backupmon"
    fi
fi

##-------------------------------------##
## Added by Martinski W. [2025-Jan-05] ##
##-------------------------------------##
_DisableFWAutoUpdateChecks_()
{
   _DelFWAutoUpdateHook_
   _DelFWAutoUpdateCronJob_
   Update_Custom_Settings "FW_Update_Check" "DISABLED"

   runfwUpdateCheck=false
   if [ "$FW_UpdateCheckState" -ne 0 ]
   then
      FW_UpdateCheckState=0
      nvram set firmware_check_enable="$FW_UpdateCheckState"
      nvram commit
   fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-05] ##
##-------------------------------------##
_EnableFWAutoUpdateChecks_()
{
   _AddFWAutoUpdateHook_
   Update_Custom_Settings "FW_Update_Check" "ENABLED"

   runfwUpdateCheck=true
   if [ "$FW_UpdateCheckState" -ne 1 ]
   then
      FW_UpdateCheckState=1
      nvram set firmware_check_enable="$FW_UpdateCheckState"
      nvram commit
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-12] ##
##----------------------------------------##
_ConfirmCronJobForFWAutoUpdates_()
{
    if [ $# -gt 0 ] && [ -n "$1" ] && \
       echo "$1" | grep -qE "^(install|startup)$"
    then return 1 ; fi

    # Check if the PREVIOUS Cron Job ID already exists #
    if eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG_OLD}#$"
    then  #If it exists, delete the OLD one & create a NEW one#
        cru d "$CRON_JOB_TAG_OLD" ; sleep 1 ; _AddFWAutoUpdateCronJob_
    fi

    # Retrieve custom setting for automatic F/W update checks #
    # Expected values: "ENABLED", "TBD", "DISABLED" (or fallback) #
    fwUpdateCheckState="$(Get_Custom_Setting "FW_Update_Check")"

    # Always start with a default of "false" (do not run checks by default) #
    runfwUpdateCheck=false

    FW_UpdateCheckState="$(nvram get firmware_check_enable)"
    [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0

    ##------------------------------------------------------------##
    # Priority is given to custom '$fwUpdateCheckState' value. 
    # The NVRAM variable is updated only after we've decided 
    # what to do based on the custom setting.
    ##------------------------------------------------------------##

    # 1) "ENABLED": Automatically enable checks (no user prompt) #
    if [ "$fwUpdateCheckState" = "ENABLED" ]
    then
        if ! eval "$cronListCmd" | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
        then
            printf "Auto-enabling cron job '${GRNct}${CRON_JOB_TAG}${NOct}'...\n"
            if _AddFWAutoUpdateCronJob_
            then
                printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
                cronSchedStrHR="$(_TranslateCronSchedHR_ "$FW_UpdateCronJobSchedule")"
                printf "Job Schedule: ${GRNct}${cronSchedStrHR}${NOct}\n"
            else
                printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
            fi
        else
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' already exists.\n"
        fi
        _EnableFWAutoUpdateChecks_

    # 2) "TBD": Prompt the user (original behavior) #
    elif [ "$fwUpdateCheckState" = "TBD" ]
    then
        if ! eval $cronListCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
        then
            _ShowLogo_
            printf "Do you want to enable automatic firmware update checks?\n"
            printf "This will create a CRON job to check for updates regularly.\n"
            printf "The CRON can be disabled at any time via the main menu.\n"

            if _WaitForYESorNO_
            then
                # User said YES -> enable checks #
                printf "Adding '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
                if ! eval "$cronListCmd" | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
                then
                    if _AddFWAutoUpdateCronJob_
                    then
                        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
                        cronSchedStrHR="$(_TranslateCronSchedHR_ "$FW_UpdateCronJobSchedule")"
                        printf "Job Schedule: ${GRNct}${cronSchedStrHR}${NOct}\n"
                    else
                        printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
                    fi
                else
                    printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' already exists.\n"
                fi
                _EnableFWAutoUpdateChecks_
            else
                # User said NO -> disable checks #
                printf "Automatic firmware update checks will be ${REDct}DISABLED${NOct}.\n"
                printf "You can enable this feature later via the main menu.\n"
                _DisableFWAutoUpdateChecks_ 
            fi
            _WaitForEnterKey_
        else
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' already exists.\n"
            Update_Custom_Settings "FW_Update_Check" "ENABLED"
            _AddFWAutoUpdateHook_
            runfwUpdateCheck=true
        fi

    # 3) "DISABLED": Perform the disable steps (same as _Toggle_FW_UpdateCheckSetting_) #
    elif [ "$fwUpdateCheckState" = "DISABLED" ]
    then
        printf "Firmware update checks have been ${REDct}DISABLED${NOct}.\n"
        _DisableFWAutoUpdateChecks_

    # 4) Unknown/fallback -> treat as DISABLED #
    else
        printf "Unknown FW_Update_Check value: '%s'. Disabling firmware checks.\n" "$fwUpdateCheckState"
        _DisableFWAutoUpdateChecks_
    fi

    ##------------------------------------------------------------##
    # If 'runfwUpdateCheck' is true and built-in script is found
    # run the built-in F/W Update check in the background.
    ##------------------------------------------------------------##
    if "$runfwUpdateCheck" && [ -x "$FW_UpdateCheckScript" ]
    then
        sh "$FW_UpdateCheckScript" 2>&1
        sleep 1
    fi
}

##-------------------------------------##
## Added by Martinski W. [2024-May-03] ##
##-------------------------------------##
_list2_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1 ; fi
   local prevIFS="$IFS"
   IFS="$(printf '\n\t')"
   ls $1 $2 ; retcode="$?"
   IFS="$prevIFS"
   return "$retcode"
}

##-------------------------------------##
## Added by Martinski W. [2024-May-03] ##
##-------------------------------------##
_GetFileSelectionIndex_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   local selectStr  promptStr  numRegEx  indexNum  indexList
   local multiIndexListOK  theAllStr="${GRNct}all${NOct}"

   if [ "$1" -eq 1 ]
   then selectStr="${GRNct}1${NOct}"
   else selectStr="${GRNct}1${NOct}-${GRNct}${1}${NOct}"
   fi

   if [ $# -lt 2 ] || [ "$2" != "-MULTIOK" ]
   then
       multiIndexListOK=false
       promptStr="Enter selection [${selectStr}] [${theLGExitStr}]?"
   else
       multiIndexListOK=true
       promptStr="Enter selection [${selectStr} | ${theAllStr}] [${theLGExitStr}]?"
   fi
   fileIndex=0  multiIndex=false
   numRegEx="([1-9]|[1-9][0-9])"

   while true
   do
       printf "${promptStr}  " ; read -r userInput

       if [ -z "$userInput" ] || \
          echo "$userInput" | grep -qE "^(e|exit|Exit)$"
       then fileIndex="NONE" ; break ; fi

       if "$multiIndexListOK" && \
          echo "$userInput" | grep -qE "^(all|All)$"
       then fileIndex="ALL" ; break ; fi

       if echo "$userInput" | grep -qE "^${numRegEx}$" && \
          [ "$userInput" -gt 0 ] && [ "$userInput" -le "$1" ]
       then fileIndex="$userInput" ; break ; fi

       if "$multiIndexListOK" && \
          echo "$userInput" | grep -qE "^${numRegEx}\-${numRegEx}[ ]*$"
       then ## Index Range ##
           index1st="$(echo "$userInput" | awk -F '-' '{print $1}')"
           indexMax="$(echo "$userInput" | awk -F '-' '{print $2}')"
           if [ "$index1st" -lt "$indexMax" ]  && \
              [ "$index1st" -gt 0 ] && [ "$index1st" -le "$1" ] && \
              [ "$indexMax" -gt 0 ] && [ "$indexMax" -le "$1" ]
           then
               indexNum="$index1st"
               indexList="$indexNum"
               while [ "$indexNum" -lt "$indexMax" ]
               do
                   indexNum="$((indexNum+1))"
                   indexList="${indexList},${indexNum}"
               done
               userInput="$indexList"
           fi
       fi

       if "$multiIndexListOK" && \
          echo "$userInput" | grep -qE "^${numRegEx}(,[ ]*${numRegEx}[ ]*)+$"
       then ## Index List ##
           indecesOK=true
           indexList="$(echo "$userInput" | sed 's/ //g' | sed 's/,/ /g')"
           for theIndex in $indexList
           do
              if [ "$theIndex" -eq 0 ] || [ "$theIndex" -gt "$1" ]
              then indecesOK=false ; break ; fi
           done
           "$indecesOK" && fileIndex="$indexList" && multiIndex=true && break
       fi

       printf "${REDct}INVALID selection.${NOct}\n"
   done
}

##-------------------------------------##
## Added by Martinski W. [2024-May-03] ##
##-------------------------------------##
_GetFileSelection_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

   if [ $# -lt 2 ] || [ "$2" != "-MULTIOK" ]
   then indexType="" ; else indexType="$2" ; fi

   theFilePath=""  theFileName=""  fileTemp=""
   fileCount=0  fileIndex=0  multiIndex=false
   local sourceDirPath="$FW_LOG_DIR"
   local maxFileCount=20

   printf "\n${1}\n[Directory: ${GRNct}${sourceDirPath}${NOct}]\n\n"

   while IFS="$(printf '\n\t')" read -r backupFilePath
   do
       fileCount="$((fileCount+1))"
       fileVar="file_${fileCount}_Name"
       eval file_${fileCount}_Name="${backupFilePath##*/}"
       printf "${GRNct}%3d${NOct}. " "$fileCount"
       eval echo "\$${fileVar}"
       [ "$fileCount" -ge "$maxFileCount" ] && break
   done <<EOT
$(_list2_ -1t "$theLogFilesMatch" 2>/dev/null)
EOT

   echo
   _GetFileSelectionIndex_ "$fileCount" "$indexType"

   if [ "$fileIndex" = "ALL" ] || [ "$fileIndex" = "NONE" ]
   then theFilePath="$fileIndex" ; return 0 ; fi

   if [ "$indexType" = "-MULTIOK" ] && "$multiIndex"
   then
       for index in $fileIndex
       do
           fileVar="file_${index}_Name"
           eval fileTemp="\$${fileVar}"
           if [ -z "$theFilePath" ]
           then theFilePath="${sourceDirPath}/$fileTemp"
           else theFilePath="${theFilePath}|${sourceDirPath}/$fileTemp"
           fi
       done
   else
       fileVar="file_${fileIndex}_Name"
       eval theFileName="\$${fileVar}"
       theFilePath="${sourceDirPath}/$theFileName"
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-04] ##
##----------------------------------------##
_CheckForUpdateLogFiles_()
{
   theLogFilesMatch="${FW_LOG_DIR}/${MODEL_ID}_FW_Update_*.log"
   theFileCount="$(_list2_ -1 "$theLogFilesMatch" 2>/dev/null | wc -l)"
   
   if [ ! -d "$FW_LOG_DIR" ] || [ "$theFileCount" -eq 0 ]
   then
       updateLogFileFound=false
       return 1
   fi
   chmod 444 "${FW_LOG_DIR}/${MODEL_ID}"_FW_Update_*.log
   updateLogFileFound=true
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-05] ##
##----------------------------------------##
_ViewUpdateLogFile_()
{
   local theFilePath=""  theFileCount  theLogFilesMatch  retCode

   if ! _CheckForUpdateLogFiles_
   then
       printf "\n${REDct}**ERROR**${NOct}: Log file(s) [$theLogFilesMatch] NOT FOUND."
       return 1
   fi
   printf "\n---------------------------------------------------"
   _GetFileSelection_ "Select a log file to view:"

   if [ "$theFilePath" = "NONE" ] || [ ! -f "$theFilePath" ]
   then return 1 ; fi

   printf "\nLog file to view:\n${GRNct}${theFilePath}${NOct}\n"
   printf "\n[Press '${REDct}q${NOct}' to quit when finished]\n"
   _WaitForEnterKey_
   less "$theFilePath"

   return 0
}

##-------------------------------------##
## Added by Martinski W. [2024-Mar-20] ##
##-------------------------------------##
_SimpleNotificationDate_()
{
   local notifyTimeStrn  notifyTimeSecs
   notifyTimeStrn="$(echo "$1" | sed 's/_/ /g')"
   notifyTimeSecs="$(date +%s -d "$notifyTimeStrn")"
   echo "$(date -d @$notifyTimeSecs +"%Y-%b-%d %I:%M %p")"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Mar-27] ##
##---------------------------------------##
# Define a function to print information about each AiMesh node
_PrintNodeInfo()
{
    local node_info="$1"
    local node_online_status="$2"
    local Node_FW_NewUpdateVersion="$3"
    local uid="$4"

    # Trim to first word if needed
    local node_productid="$(echo "$node_productid" | cut -d' ' -f1)"
    local node_version="$(echo "$Node_combinedVer" | cut -d' ' -f2)"
    node_info="$(echo "$node_info" | cut -d' ' -f1)"

    # Calculate box width based on the longest line
    local max_length=0
    local line length
    for line in "${node_productid}/${node_lan_hostname}: ${node_info}" "F/W Version Installed: ${node_version}" "F/W Update Available: ${Node_FW_NewUpdateVersion}"
    do
        length="$(printf "%s" "$line" | awk '{print length}')"
        [ "$length" -gt "$max_length" ] && max_length="$length"
    done

    local box_width="$((max_length + 0))"  # Adjust box padding here

    # Build the horizontal line without using seq
    local h_line=""
    for i in $(awk "BEGIN{for(i=1;i<=$box_width;i++) print i}")
    do
        h_line="${h_line}─"
    done

    # Assume ANSI color codes are used but do not manually adjust padding for them.
    if echo "$node_online_status" | grep -q "$node_info"
    then
        printf "\n   ┌─%s─┐" "$h_line"

        # Calculate visual length and determine required padding.
        visible_text_length="$(printf "Node ID: %s" "${uid}" | wc -m)"
        padding="$((box_width - visible_text_length))"
        # Ensure even padding for left and right by dividing total_padding by 2
        left_padding="$((padding / 2))" # Add 1 to make the division round up in case of an odd number
        printf "\n   │%*s Node ID: ${REDct}${uid}${NOct}%*s │" "$left_padding" "" "$((padding - left_padding))" ""

        # Calculate visual length and determine required padding.
        visible_text_length="$(printf "%s/%s: %s" "$node_productid" "$node_lan_hostname" "$node_info" | wc -m)"
        padding="$((box_width - visible_text_length))"
        printf "\n   │ %s/%s: ${GRNct}%s${NOct}%*s │" "$node_productid" "$node_lan_hostname" "$node_info" "$padding" ""

        visible_text_length="$(printf "F/W Version Installed: %s" "$node_version" | wc -m)"
        padding="$((box_width - visible_text_length))"
        printf "\n   │ F/W Version Installed: ${GRNct}%s${NOct}%*s │" "$node_version" "$padding" ""

        #
        if [ -n "$Node_FW_NewUpdateVersion" ]
        then
            visible_text_length="$(printf "F/W Update Available: %s" "$Node_FW_NewUpdateVersion" | wc -m)"
            padding="$((box_width - visible_text_length))"
            if echo "$Node_FW_NewUpdateVersion" | grep -q "NONE FOUND"
            then
                printf "\n   │ F/W Update Available: ${REDct}%s${NOct}%*s │" "$Node_FW_NewUpdateVersion" "$padding" ""
            else
                printf "\n   │ F/W Update Available: ${GRNct}%s${NOct}%*s │" "$Node_FW_NewUpdateVersion" "$padding" ""
            fi
        fi

        printf "\n   └─%s─┘" "$h_line"
    else
        visible_text_length="$(printf "Node Offline" | wc -m)"
        total_padding="$((box_width - visible_text_length))"
        # Ensure even padding for left and right by dividing total_padding by 2
        left_padding="$((total_padding / 2))" # Add 1 to make the division round up in case of an odd number

        printf "\n   ┌─%s─┐" "$h_line"
        # Apply the left padding. The '%*s' uses left_padding as its width specifier to insert spaces before "Node Offline"
        printf "\n   │%*s ${REDct}Node Offline${NOct}%*s │" "$left_padding" "" "$((total_padding - left_padding))" ""
        printf "\n   └─%s─┘" "$h_line"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Feb-18] ##
##----------------------------------------##
_InvalidMenuSelection_()
{
   printf "${REDct}INVALID selection.${NOct} Please try again."
   _WaitForEnterKey_
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-11] ##
##----------------------------------------##
_ShowMainMenuOptions_()
{
   local FW_NewUpdateVerStr  FW_NewUpdateVersion

   #-----------------------------------------------------------#
   # Check if router reports a new F/W update is available.
   # If yes, modify the notification settings accordingly.
   #-----------------------------------------------------------#
   if FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_)" && \
      [ -n "$FW_NewUpdateVersion" ] && [ -n "$FW_InstalledVersion" ] && \
      [ "$FW_NewUpdateVersion" != "$FW_NewUpdateVerInit" ]
   then
       FW_NewUpdateVerInit="$FW_NewUpdateVersion"
       _CheckNewUpdateFirmwareNotification_ "$FW_InstalledVersion" "$FW_NewUpdateVersion"
   fi

   clear
   _ShowLogo_
   printf "${YLWct}============ By ExtremeFiretop & Martinski W. ============${NOct}\n\n"

   # New Script Update Notification #
   if [ "$scriptUpdateNotify" != "0" ]; then
      Say "${REDct}*WARNING*:${NOct} ${scriptUpdateNotify}\n"
   fi

   # Unsupported Model Check #
   if "$routerModelCheckFailed"
   then
      Say "${REDct}*WARNING*:${NOct} The current router model is not supported by this script.
 Please uninstall.\n"
   fi
   if "$MinFirmwareVerCheckFailed"
   then
      Say "${REDct}*WARNING*:${NOct} The current firmware version is below the minimum supported.
 Please manually update to version ${GRNct}${MinSupportedFirmwareVers}${NOct} or higher to use this script.\n"
   fi

   if ! _HasRouterMoreThan256MBtotalRAM_ && ! _ValidateUSBMountPoint_ "$FW_ZIP_BASE_DIR"
   then
      Say "${REDct}*WARNING*:${NOct} Limited RAM detected (256MB).
 A USB drive is required for F/W updates.\n"
   fi

   arrowStr=" ${InvREDct} <<--- ${NOct}"

   _Calculate_NextRunTime_

   notifyDate="$(Get_Custom_Setting "FW_New_Update_Notification_Date")"
   if [ "$notifyDate" = "TBD" ]
   then notificationStr="${REDct}NOT SET${NOct}"
   else notificationStr="${GRNct}$(_SimpleNotificationDate_ "$notifyDate")${NOct}"
   fi

   if "$isGNUtonFW"
   then FirmwareFlavor="${MAGENTAct}GNUton${NOct}"
   else FirmwareFlavor="${BLUEct}Merlin${NOct}"
   fi

   printf "${SEPstr}"
   if [ "$HIDE_ROUTER_SECTION" = "false" ]
   then
      if ! FW_NewUpdateVerStr="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
      then FW_NewUpdateVerStr=" ${REDct}NONE FOUND${NOct}"
      else FW_NewUpdateVerStr="${InvGRNct} ${FW_NewUpdateVerStr} ${NOct}$arrowStr"
      fi
      printf "\n  Router's Product Name/Model ID:  ${FW_RouterModelIDstr}${padStr}(H)ide"
      printf "\n  USB-Attached Storage Connected:  $USBConnected"
      printf "\n  F/W Variant Configuration Found: $FirmwareFlavor"
      printf "\n  F/W Version Currently Installed: $FW_InstalledVerStr"
      printf "\n  F/W Update Version Available:   $FW_NewUpdateVerStr"
      printf "\n  F/W Update Estimated Run Date:   $ExpectedFWUpdateRuntime"
   else
      printf "\n  Router's Product Name/Model ID:  ${FW_RouterModelIDstr}${padStr}(S)how"
   fi
   printf "\n${SEPstr}"

   printf "\n  ${GRNct}1${NOct}.  Run F/W Update Check Now\n"
   printf "\n  ${GRNct}2${NOct}.  Set Router Login Credentials\n"

   # Enable/Disable the ASUS Router's built-in "F/W Update Check" #
   FW_UpdateCheckState="$(nvram get firmware_check_enable)"
   [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
   if [ "$FW_UpdateCheckState" -eq 0 ]
   then
       printf "\n  ${GRNct}3${NOct}.  Toggle F/W Update Check"
       printf "\n${padStr}[Currently ${InvREDct} DISABLED ${NOct}]"
   else
       printf "\n  ${GRNct}3${NOct}.  Toggle F/W Update Check"
       printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]"
   fi
   printf "\n${padStr}[Last Notification Date: $notificationStr]\n"

   FW_UpdatePostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days)"
   printf "\n  ${GRNct}4${NOct}.  Set F/W Update Postponement Days"
   printf "\n${padStr}[Current Days: ${GRNct}${FW_UpdatePostponementDays}${NOct}]\n"

   local checkChangeLogSetting="$(Get_Custom_Setting "CheckChangeLog")"
   if [ "$checkChangeLogSetting" = "DISABLED" ]
   then
       printf "\n  ${GRNct}5${NOct}.  Toggle F/W Changelog Check"
       printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
   else
       printf "\n  ${GRNct}5${NOct}.  Toggle F/W Changelog Check"
       printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]\n"
   fi

   ChangelogApproval="$(Get_Custom_Setting "FW_New_Update_Changelog_Approval")"
   if [ "$ChangelogApproval" = "BLOCKED" ]
   then
       printf "\n  ${GRNct}6${NOct}.  Toggle F/W Update Changelog Approval"
       printf "\n${padStr}[Currently ${REDct}${ChangelogApproval}${NOct}]\n"
   elif [ "$ChangelogApproval" = "APPROVED" ]
   then
       printf "\n  ${GRNct}6${NOct}.  Toggle F/W Update Changelog Approval"
       printf "\n${padStr}[Currently ${GRNct}${ChangelogApproval}${NOct}]\n"
   fi

   # Check for new script updates #
   if [ "$scriptUpdateNotify" != "0" ]
   then
      printf "\n ${GRNct}up${NOct}.  Update $SCRIPT_NAME Script"
      printf "\n${padStr}[Version ${GRNct}${DLRepoVersion}${NOct} Available for Download]\n"
   else
      printf "\n ${GRNct}up${NOct}.  Force Update $SCRIPT_NAME Script"
      printf "\n${padStr}[No Update Available]\n"
   fi

   # Add selection for "Advanced Options" sub-menu #
   printf "\n ${GRNct}ad${NOct}.  Advanced Options\n"

   # Check for AiMesh Nodes #
   if "$inRouterSWmode" && [ -n "$node_list" ]; then
      printf "\n ${GRNct}mn${NOct}.  AiMesh Node(s) Info\n"
   fi

   # Add selection for "Log Options" sub-menu #
   printf "\n ${GRNct}lo${NOct}.  Log Options Menu\n"

   printf "\n  ${GRNct}e${NOct}.  Exit\n"
   printf "${SEPstr}\n"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
_ShowAdvancedOptionsMenu_()
{
   local BetaProductionSetting  VPNAccess  currentBackupOption
   local scriptUpdateCronSched  current_build_type

   clear
   _ShowLogo_
   printf "================== Advanced Options Menu =================\n"
   printf "${SEPstr}\n"

   _SetUp_FW_UpdateZIP_DirectoryPaths_
   printf "\n  ${GRNct}1${NOct}.  Set Directory for F/W Update File"
   printf "\n${padStr}[Current Path: ${GRNct}${FW_ZIP_DIR}${NOct}]\n"

   printf "\n  ${GRNct}2${NOct}.  Set F/W Update Cron Schedule"
   printf "\n${padStr}[Current Schedule: ${GRNct}${FW_UpdateCronJobSchedule}${NOct}]"
   printf "\n${padStr}[${GRNct}%s${NOct}]\n" "$(_TranslateCronSchedHR_ "$FW_UpdateCronJobSchedule")"

   BetaProductionSetting="$(Get_Custom_Setting "FW_Allow_Beta_Production_Up")"
   printf "\n  ${GRNct}3${NOct}.  Toggle Beta-to-Release F/W Updates"
   if [ "$BetaProductionSetting" = "DISABLED" ]
   then
       printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
   else
       printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]\n"
   fi

   VPNAccess="$(Get_Custom_Setting "Allow_Updates_OverVPN")"
   printf "\n  ${GRNct}4${NOct}.  Toggle Tailscale/ZeroTier Access During Updates"
   if [ "$VPNAccess" = "DISABLED" ]
   then
       printf "\n${padStr}[Currently ${GRNct}DISABLED${NOct}]\n"
   else
       printf "\n${padStr}[Currently ${REDct}ENABLED${NOct}]\n"
   fi

   # Check if the file BACKUPMON exists #
   if [ -f "/jffs/scripts/backupmon.sh" ]
   then
       # Retrieve the current backup setting #
       currentBackupOption="$(Get_Custom_Setting "FW_Auto_Backupmon")"

       # Display the backup option toggle menu
       printf "\n ${GRNct}ab${NOct}.  Toggle Automatic Backups"
       if [ "$currentBackupOption" = "DISABLED" ]
       then printf "\n${padStr}[Currently ${REDct}${currentBackupOption}${NOct}]\n"
       else printf "\n${padStr}[Currently ${GRNct}${currentBackupOption}${NOct}]\n"
       fi
   fi

   ScriptAutoUpdateSetting="$(Get_Custom_Setting "Allow_Script_Auto_Update")"
   printf "\n ${GRNct}au${NOct}.  Toggle Auto-Updates for MerlinAU Script"
   if [ "$ScriptAutoUpdateSetting" = "DISABLED" ]
   then
       printf "\n${padStr}[Currently ${GRNct}DISABLED${NOct}]\n"
   else
       scriptUpdateCronSched="$(_GetScriptAutoUpdateCronSchedule_)"
       printf "\n${padStr}[Current Schedule: ${GRNct}${scriptUpdateCronSched}${NOct}]"
       printf "\n${padStr}[${GRNct}%s${NOct}]\n" "$(_TranslateCronSchedHR_ "$scriptUpdateCronSched")"
   fi

   if "$isGNUtonFW"
   then
      if [ "$fwInstalledBaseVers" -le 3004 ]
      then
         # Retrieve the current build type setting
         current_build_type="$(Get_Custom_Setting "TUFBuild")"

         # Convert the setting to a descriptive text
         if [ "$current_build_type" = "ENABLED" ]; then
             current_build_type_menu="TUF Build"
         elif [ "$current_build_type" = "DISABLED" ]; then
             current_build_type_menu="Pure Build"
         else
             current_build_type_menu="NOT SET"
         fi

         if echo "$PRODUCT_ID" | grep -q "^TUF-"
         then
             printf "\n ${GRNct}bt${NOct}.  Toggle F/W Build Type"
             if [ "$current_build_type_menu" = "NOT SET" ]
             then printf "\n${padStr}[Current Build Type: ${REDct}${current_build_type_menu}${NOct}]\n"
             else printf "\n${padStr}[Current Build Type: ${GRNct}${current_build_type_menu}${NOct}]\n"
             fi
         fi
      elif [ "$fwInstalledBaseVers" -ge 3006 ]
      then
          # Retrieve the current build type setting #
          local current_build_typerog="$(Get_Custom_Setting "ROGBuild")"

          # Convert the setting to a descriptive text
          if [ "$current_build_typerog" = "ENABLED" ]; then
              current_build_type_menurog="ROG Build"
          elif [ "$current_build_typerog" = "DISABLED" ]; then
              current_build_type_menurog="Pure Build"
          else
              current_build_type_menurog="NOT SET"
          fi

          if echo "$PRODUCT_ID" | grep -q "^GT-"
          then
              printf "\n ${GRNct}bt${NOct}.  Toggle F/W Build Type"
              if [ "$current_build_type_menurog" = "NOT SET" ]
              then printf "\n${padStr}[Current Build Type: ${REDct}${current_build_type_menurog}${NOct}]\n"
              else printf "\n${padStr}[Current Build Type: ${GRNct}${current_build_type_menurog}${NOct}]\n"
              fi
          fi

          # Retrieve the current build type setting
          local current_build_typetuf="$(Get_Custom_Setting "TUFBuild")"

          # Convert the setting to a descriptive text
          if [ "$current_build_typetuf" = "ENABLED" ]; then
              current_build_type_menutuf="TUF Build"
          elif [ "$current_build_typetuf" = "DISABLED" ]; then
              current_build_type_menutuf="Pure Build"
          else
              current_build_type_menutuf="NOT SET"
          fi

          if echo "$PRODUCT_ID" | grep -q "^TUF-"
          then
              printf "\n ${GRNct}bt${NOct}.  Toggle F/W Build Type"
              if [ "$current_build_type_menutuf" = "NOT SET" ]
              then printf "\n${padStr}[Current Build Type: ${REDct}${current_build_type_menutuf}${NOct}]\n"
              else printf "\n${padStr}[Current Build Type: ${GRNct}${current_build_type_menutuf}${NOct}]\n"
              fi
          fi
       fi
   else
      if [ "$fwInstalledBaseVers" -le 3004 ]
      then
          # Retrieve the current build type setting
          current_build_type="$(Get_Custom_Setting "ROGBuild")"

          # Convert the setting to a descriptive text
          if [ "$current_build_type" = "ENABLED" ]; then
              current_build_type_menu="ROG Build"
          elif [ "$current_build_type" = "DISABLED" ]; then
              current_build_type_menu="Pure Build"
          else
              current_build_type_menu="NOT SET"
          fi

          if echo "$PRODUCT_ID" | grep -q "^GT-"
          then
              printf "\n ${GRNct}bt${NOct}.  Toggle F/W Build Type"
              if [ "$current_build_type_menu" = "NOT SET" ]
              then printf "\n${padStr}[Current Build Type: ${REDct}${current_build_type_menu}${NOct}]\n"
              else printf "\n${padStr}[Current Build Type: ${GRNct}${current_build_type_menu}${NOct}]\n"
              fi
          fi
      fi
   fi

   # Additional Email Notification Options #
   if _CheckEMailConfigFileFromAMTM_ 0
   then
       # F/W Update Email Notifications #
       if "$inRouterSWmode" 
       then
           printf "\n ${GRNct}em${NOct}.  Toggle F/W Update Email Notifications"
       else
           printf "\n ${GRNct}em${NOct}.  Toggle F/W Email Notifications"
       fi
       if [ "$sendEMailNotificationsFlag" = "ENABLED" ]
       then
           printf "\n${padStr}[Currently ${GRNct}ENABLED${NOct}]\n"
       else
           printf "\n${padStr}[Currently ${REDct}DISABLED${NOct}]\n"
       fi

       if [ "$sendEMailNotificationsFlag" = "ENABLED" ]
       then
           # Format Types: "HTML" or "Plain Text" #
           printf "\n ${GRNct}ef${NOct}.  Set Email Format Type"
           printf "\n${padStr}[Current Format: ${GRNct}${sendEMailFormaType}${NOct}]\n"

           # Secondary Email Address Setup for "CC" option #
           printf "\n ${GRNct}se${NOct}.  Set Email Notifications Secondary Address"
           if [ -n "$CC_NAME" ] && [ -n "$CC_ADDRESS" ]
           then
               printf "\n${padStr}[Current Name/Alias: ${GRNct}${CC_NAME}${NOct}]"
               printf "\n${padStr}[Current 2nd Address: ${GRNct}${CC_ADDRESS}${NOct}]\n"
           else
               echo
           fi
       fi
   fi

   printf "\n ${GRNct}un${NOct}.  Uninstall\n"
   printf "\n  ${GRNct}e${NOct}.  Return to Main Menu\n"
   printf "${SEPstr}\n"
}

##---------------------------------------##
## Added by ExtremeFiretop [2024-Apr-02] ##
##---------------------------------------##
_ShowNodesMenu_()
{
   clear
   _ShowLogo_
   printf "================ AiMesh Node(s) Info Menu ================\n"
   printf "${SEPstr}\n"

   if ! node_online_status="$(_NodeActiveStatus_)"
   then node_online_status="" ; fi

   # Count the number of IP addresses
   local numIPs="$(echo "$node_list" | wc -w)"

   # Print the result
   printf "\n${padStr}${padStr}${padStr}${GRNct} AiMesh Node(s): ${numIPs}${NOct}"

   _ProcessMeshNodes_ 1

   echo ""

   printf "\n  ${GRNct}e${NOct}.  Return to Main Menu\n"
   printf "${SEPstr}"
}

_ShowNodesMenuOptions_()
{
    while true
    do
        _ShowNodesMenu_
        printf "\nEnter selection:  "
        read -r nodesChoice
        echo
        case $nodesChoice in
            e|exit) break
               ;;
            *) _InvalidMenuSelection_
               ;;
        esac
    done
}

##----------------------------------------##
## Modified by Martinski W. [2024-May-04] ##
##----------------------------------------##
_ShowLogOptionsMenu_()
{
   clear
   _ShowLogo_
   printf "==================== Log Options Menu ====================\n"
   printf "${SEPstr}\n"

   printf "\n  ${GRNct}1${NOct}.  Set Directory for F/W Update Log Files"
   printf "\n${padStr}[Current Path: ${GRNct}${FW_LOG_DIR}${NOct}]\n"

   if _CheckForUpdateLogFiles_
   then
       printf "\n ${GRNct}lg${NOct}.  View F/W Update Log File\n"
   fi

   printf "\n ${GRNct}cl${NOct}.  View Latest F/W Changelog\n"

   printf "\n  ${GRNct}e${NOct}.  Return to Main Menu\n"
   printf "${SEPstr}"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-15] ##
##----------------------------------------##
_AdvancedLogsOptions_()
{
    local menuChoice=""
    _SetUp_FW_UpdateLOG_DirectoryPaths_

    while true
    do
        _ShowLogOptionsMenu_
        printf "\nEnter selection:  "
        read -r menuChoice
        echo
        case "$menuChoice" in
            1) _Set_FW_UpdateLOG_DirectoryPath_
               ;;
           lg) if _CheckForUpdateLogFiles_
               then
                   while true
                   do
                       if _ViewUpdateLogFile_
                       then continue ; else break ; fi
                   done
               else
                   _InvalidMenuSelection_
               fi
               ;;
           cl) if "$isGNUtonFW"
               then _ManageChangelogGnuton_ "view"
               else _ManageChangelogMerlin_ "view"
               fi
               ;;
       e|exit) break
               ;;
            *) _InvalidMenuSelection_
               ;;
        esac
    done
}

##------------------------------------------##
## Modified by ExtremeFiretop [2025-Jan-10] ##
##------------------------------------------##
_AdvancedOptionsMenu_()
{
    local theUserInputStr=""
    local offlineUpdTrigger=false
    local execReloadTrigger=false

    while true
    do
        _ShowAdvancedOptionsMenu_
        _GetKeypressInput_ "Enter selection:"
        echo

        case "$theUserInputStr" in
            1) _Set_FW_UpdateZIP_DirectoryPath_
               ;;
            2) _Set_FW_AutoUpdateCronSchedule_
               ;;
            3) _Toggle_FW_UpdatesFromBeta_
               ;;
            4) _Toggle_VPN_Access_
               ;;
           ab) if [ -f "/jffs/scripts/backupmon.sh" ]
               then _Toggle_Auto_Backups_
               else _InvalidMenuSelection_
               fi
               ;;
           au) _Toggle_ScriptAutoUpdate_Config_
               ;;
           bt) if echo "$PRODUCT_ID" | grep -q "^TUF-"
               then _ChangeBuildType_TUF_
               elif [ "$fwInstalledBaseVers" -le 3004 ] && \
                    echo "$PRODUCT_ID" | grep -q "^GT-"
               then _ChangeBuildType_ROG_
               elif [ "$fwInstalledBaseVers" -ge 3006 ] && "$isGNUtonFW" && \
                    echo "$PRODUCT_ID" | grep -q "^GT-"
               then _ChangeBuildType_ROG_
               else _InvalidMenuSelection_
               fi
               ;;
           em) if "$isEMailConfigEnabledInAMTM"
               then _Toggle_FW_UpdateEmailNotifications_
               else _InvalidMenuSelection_
               fi
               ;;
           ef) if "$isEMailConfigEnabledInAMTM" && \
                  [ "$sendEMailNotificationsFlag" = "ENABLED" ]
               then _SetEMailFormatType_
               else _InvalidMenuSelection_
               fi
               ;;
           se) if "$isEMailConfigEnabledInAMTM" && \
                  [ "$sendEMailNotificationsFlag" = "ENABLED" ]
               then _SetSecondaryEMailAddress_
               else _InvalidMenuSelection_
               fi
               ;;
           un) _DoUnInstallation_ && _WaitForEnterKey_
               ;;
           e|E|exit) break
               ;;
            *) if "$offlineUpdTrigger"
               then
                   _RunOfflineUpdateNow_
                   [ "$?" -eq 2 ] && _InvalidMenuSelection_
               ##
               elif "$execReloadTrigger"
               then
                   printf "Reloading configuration to refresh menu."
                   printf "\nPlease wait...\n"
                   _ReleaseLock_
                   exec "$ScriptFilePath" reload advmenu
                   exit 0
               else
                   _InvalidMenuSelection_
               fi
               ;;
        esac
    done
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-10] ##
##----------------------------------------##
_MainMenu_()
{
   local theUserInputStr=""  jumpToAdvMenu
   local execReloadTrigger=false

   inMenuMode=true
   HIDE_ROUTER_SECTION=false
   if ! node_list="$(_GetNodeIPv4List_)"
   then node_list="" ; fi

   if [ $# -gt 1 ] && \
      [ "$1" = "reload" ] && \
      [ "$2" = "advmenu" ]
   then jumpToAdvMenu=true
   else jumpToAdvMenu=false
   fi

   while true
   do
      [ -d "$FW_BIN_DIR" ] && cd "$FW_BIN_DIR"

      if "$jumpToAdvMenu"
      then
          theUserInputStr=ad
          jumpToAdvMenu=false
      else
          _ShowMainMenuOptions_
          _GetKeypressInput_ "Enter selection:"
          echo
      fi

      case "$theUserInputStr" in
          s|S|h|H)
             if [ "$theUserInputStr" = "s" ] || \
                [ "$theUserInputStr" = "S" ]
             then
                 HIDE_ROUTER_SECTION=false
             elif [ "$theUserInputStr" = "h" ] || \
                  [ "$theUserInputStr" = "H" ]
             then
                 HIDE_ROUTER_SECTION=true
             fi
             ;;
          1) if _AcquireLock_ cliFileLock
             then
                 _RunFirmwareUpdateNow_
                 _ReleaseLock_ cliFileLock
                 FlashStarted=false
             fi
             ;;
          2) _GetLoginCredentials_
             ;;
          3) _Toggle_FW_UpdateCheckSetting_
             ;;
          4) _Set_FW_UpdatePostponementDays_
             ;;
          5) _toggle_change_log_check_
             ;;
          6) if  [ -z "$ChangelogApproval" ] || \
                 [ "$ChangelogApproval" = "TBD" ]
             then _InvalidMenuSelection_
             else _Approve_FW_Update_
             fi
             ;;
         up) if _AcquireLock_ cliFileLock
             then
                 _SCRIPT_UPDATE_
                 _ReleaseLock_ cliFileLock
             fi
             ;;
         ad) _AdvancedOptionsMenu_
             ;;
         mn) if "$inRouterSWmode" && [ -n "$node_list" ]
             then _ShowNodesMenuOptions_
             else _InvalidMenuSelection_
             fi
             ;;
         lo) _AdvancedLogsOptions_
             ;;
         e|E|exit) _DoExit_ 0
             ;;
          *) if "$execReloadTrigger"
             then
                 printf "Reloading configuration to refresh menu."
                 printf "\nPlease wait...\n"
                 _ReleaseLock_
                 exec "$ScriptFilePath" reload topmenu
                 exit 0
             else
                 _InvalidMenuSelection_
             fi
             ;;
      esac
   done
}

##-------------------------------------##
## Added by Martinski W. [2025-Jan-15] ##
##-------------------------------------##
_DoInitializationStartup_()
{
   if ! _CheckForMinimumRequirements_
   then
       printf "\n${CRITct}Minimum requirements for $SCRIPT_NAME were not met. See the reason(s) above.${NOct}\n"
       _DoExit_ 1
   fi

   if [ $# -gt 0 ] && [ -n "$1" ] && \
      echo "$1" | grep -qE "^(install|startup)$"
   then return 1 ; fi

   _CreateDirPaths_
   _InitCustomSettingsConfig_
   _CreateSymLinks_
   _InitHelperJSFile_
   _SetVersionSharedSettings_ local "$SCRIPT_VERSION"

   if "$inRouterSWmode"
   then
       _AutoStartupHook_ create 2>/dev/null
       _AutoServiceEvent_ create 2>/dev/null
   fi
}

FW_InstalledVersion="$(_GetCurrentFWInstalledLongVersion_)"
FW_InstalledVerStr="${GRNct}${FW_InstalledVersion}${NOct}"
FW_NewUpdateVerInit=TBD

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-10] ##
##----------------------------------------##
if [ $# -eq 0 ] || [ -z "$1" ] || \
   { [ $# -gt 1 ] && [ "$1" = "reload" ] ; }
then
   if ! _AcquireLock_ cliMenuLock
   then Say "Exiting..." ; exit 1 ; fi

   inMenuMode=true
   _DoInitializationStartup_
   if _AcquireLock_ cliFileLock
   then
       _CheckForNewScriptUpdates_
       _ReleaseLock_ cliFileLock
   fi
   if [ "$ScriptAutoUpdateSetting" = "ENABLED" ]
   then _AddScriptAutoUpdateCronJob_ ; fi
   _ConfirmCronJobForFWAutoUpdates_

   _MainMenu_ "$@"
   _DoExit_ 0
fi

##----------------------------------------##
## Modified by Martinski W. [2024-Jan-15] ##
##----------------------------------------##
if [ $# -gt 0 ]
then
   if ! _AcquireLock_ cliOptsLock
   then Say "Exiting..." ; exit 1 ; fi

   inMenuMode=false
   _DoInitializationStartup_ "$1"
   _ConfirmCronJobForFWAutoUpdates_ "$1"

   case "$1" in
       run_now)
           if _AcquireLock_ cliFileLock
           then
               _RunFirmwareUpdateNow_
               _ReleaseLock_ cliFileLock
           fi
           ;;
       processNodes) _ProcessMeshNodes_ 0
           ;;
       addCronJob) _AddFWAutoUpdateCronJob_
           ;;
       scriptAUCronJob) _AddScriptAutoUpdateCronJob_
           ;;
       postRebootRun) _PostRebootRunNow_
           ;;
       postUpdateEmail) _PostUpdateEmailNotification_
           ;;
       about) _ShowAbout_
           ;;
       help) _ShowHelp_
           ;;
       checkupdates)
           if _AcquireLock_ cliFileLock
           then
               _CheckForNewScriptUpdates_
               _ReleaseLock_ cliFileLock
           fi
           ;;
       forceupdate)
           if _AcquireLock_ cliFileLock
           then
               _SCRIPT_UPDATE_ force "$([ $# -gt 1 ] && echo "$2" || echo)"
               _ReleaseLock_ cliFileLock
           fi
           ;;
       develop) _ChangeToDev_
           ;;
       stable) _ChangeToStable_
           ;;
       startup) _DoStartupInit_
           ;;
       install) _DoInstallation_
           ;;
       uninstall) _DoUnInstallation_
           ;;
       service_event)
           if [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}uninstall" ]
           then
               _DoUnInstallation_
               sleep 1
           elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}approvechangelog" ] 
           then
               local currApprovalStatus="$(Get_Custom_Setting "FW_New_Update_Changelog_Approval")"
               if [ "$currApprovalStatus" = "BLOCKED" ]
               then
                   Update_Custom_Settings "FW_New_Update_Changelog_Approval" "APPROVED"
               elif [ "$currApprovalStatus" = "APPROVED" ]
               then
                   Update_Custom_Settings "FW_New_Update_Changelog_Approval" "BLOCKED"
               fi
           elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}checkupdate" ]
           then
               if _AcquireLock_ cliFileLock
               then
                   _RunFirmwareUpdateNow_
                   _ReleaseLock_ cliFileLock
               fi
           elif [ "$2" = "start" ] && [ "$3" = "${SCRIPT_NAME}config" ]
           then
               if _AcquireLock_ cliFileLock
               then
                   _UpdateConfigFromWebUISettings_
                   _ConfirmCronJobForFWAutoUpdates_
                   _ReleaseLock_ cliFileLock
               fi
           fi
           ;;
       *) printf "${REDct}INVALID Parameter [$*].${NOct}\n"
           ;;
   esac
   _DoExit_ 0
fi

#EOF#
