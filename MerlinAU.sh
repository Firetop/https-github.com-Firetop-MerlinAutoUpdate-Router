#!/bin/sh
###################################################################
# MerlinAU.sh (MerlinAutoUpdate)
#
# Original Creation Date: 2023-Oct-01 by @ExtremeFiretop.
# Official Co-Author: @Martinski W. - Date: 2021-Nov-01
# Last Modified: 2023-Dec-03
###################################################################
set -u

readonly SCRIPT_VERSION="0.2.26"
readonly SCRIPT_NAME="MerlinAU"

##-------------------------------------##
## Added by Martinski W. [2023-Dec-01] ##
##-------------------------------------##
# Script URL Info #
readonly SCRIPT_BRANCH="master"
readonly SCRIPT_URL_BASE="https://raw.githubusercontent.com/Firetop/MerlinAutoUpdate-Router/$SCRIPT_BRANCH"

# Firmware URL Info #
readonly FW_URL_BASE="https://sourceforge.net/projects/asuswrt-merlin/files"
readonly FW_URL_RELEASE_SUFFIX="Release"

# For new script version updates from source repository #
UpdateNotify=0
DLRepoVersion=""

##-------------------------------------##
## Added by Martinski W. [2023-Oct-16] ##
##-------------------------------------##
readonly ADDONS_PATH="/jffs/addons"
readonly SCRIPTS_PATH="/jffs/scripts"

readonly ScriptFileName="${0##*/}"
readonly ScriptFNameTag="${ScriptFileName%%.*}"

ScriptsDirPath="$(/usr/bin/dirname "$0")"
if [ "$ScriptsDirPath" != "." ]
then
   ScriptFilePath="$0"
else
   ScriptsDirPath="$(pwd)"
   ScriptFilePath="$(pwd)/$ScriptFileName"
fi

cronCmd="$(which crontab) -l"
[ "$cronCmd" = " -l" ] && cronCmd="$(which cru) l"

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-18] ##
##----------------------------------------------##
# Save initial LEDs state to put it back later #
readonly LED_InitState="$(nvram get led_disable)"
LED_ToggleState="$LED_InitState"
Toggle_LEDs_PID=""

# To enable/disable the built-in "F/W Update Check" #
FW_UpdateCheckState="TBD"
FW_UpdateCheckScript="/usr/sbin/webs_update.sh"

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------##
# Background function to create a blinking LED effect #
Toggle_LEDs()
{
   if [ -z "$LED_ToggleState" ]
   then
       sleep 1
       Toggle_LEDs_PID=""
       return 1
   fi
   while true
   do
      LED_ToggleState="$((! LED_ToggleState))"
      nvram set led_disable="$LED_ToggleState"
      service restart_leds > /dev/null 2>&1
      sleep 2
      LED_ToggleState="$((! LED_ToggleState))"
      nvram set led_disable="$LED_ToggleState"
      service restart_leds > /dev/null 2>&1
      sleep 2
   done
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-21] ##
##----------------------------------------##
_Reset_LEDs_()
{
   # Check if the process with that PID is still running #
   if [ -n "$Toggle_LEDs_PID" ] && \
      kill -EXIT "$Toggle_LEDs_PID" 2>/dev/null
   then
       kill -TERM $Toggle_LEDs_PID
       wait $Toggle_LEDs_PID
       # Set LEDs to their "initial state" #
       nvram set led_disable="$LED_InitState"
       service restart_leds >/dev/null 2>&1
   fi
   Toggle_LEDs_PID=""
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-21] ##
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
    then urlDomain="$(nvram get lan_ipaddr)"
    else urlDomain="$(nvram get lan_hostname).$urlDomain"
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
   if [ $# -eq 0 ] || [ -z "$1" ] ; then echo ; return 1 ; fi
   local verNum  verStr

   verStr="$(echo "$1" | awk -F '_' '{print $1}')"
   verNum="$(echo "$verStr" | awk -F '.' '{printf ("%d%03d%03d\n", $1,$2,$3);}')"
   verNum="$(echo "$verNum" | sed 's/^0*//')"
   echo "$verNum" ; return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-28] ##
##----------------------------------------------##
_FWVersionStrToNum_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo ; return 1 ; fi

   local verNum  verStr="$1"

   if [ "$(echo "$1" | awk -F '.' '{print NF}')" -lt "$2" ]
   then verStr="$(nvram get firmver | sed 's/\.//g').$1" ; fi

   if [ "$2" -lt 4 ]
   then verNum="$(echo "$verStr" | awk -F '.' '{printf ("%d%03d%03d\n", $1,$2,$3);}')"
   else verNum="$(echo "$verStr" | awk -F '.' '{printf ("%d%d%03d%03d\n", $1,$2,$3,$4);}')"
   fi

   echo "$verNum" ; return 0
}

##--------------------------------------------##
## Modified by ExtremeFiretop [2023-Nov-26]   ##
##--------------------------------------------##
readonly NOct="\e[0m"
readonly REDct="\e[1;31m"
readonly GRNct="\e[1;32m"
readonly BLKct="\e[1;30m"
readonly YLWct="\e[1;33m"
readonly BLUEct="\e[1;34m"
readonly MAGENTAct="\e[1;35m"
readonly CYANct="\e[1;36m"
readonly WHITEct="\e[1;37m"

readonly FW_Update_CRON_DefaultSchedule="0 0 * * 0"

# To postpone a firmware update for a few days #
readonly FW_UpdateMinimumPostponementDays=0
readonly FW_UpdateDefaultPostponementDays=7
readonly FW_UpdateMaximumPostponementDays=30
readonly FW_UpdateNotificationDateFormat="%Y-%m-%d_12:00:00"

readonly MODEL_ID="$(_GetRouterModelID_)"
readonly PRODUCT_ID="$(_GetRouterProductID_)"
readonly FW_FileName="${PRODUCT_ID}_firmware"
readonly FW_URL_RELEASE="${FW_URL_BASE}/${PRODUCT_ID}/${FW_URL_RELEASE_SUFFIX}/"

readonly SETTINGS_DIR="${ADDONS_PATH}/$ScriptFNameTag"
readonly SETTINGSFILE="${SETTINGS_DIR}/custom_settings.txt"
readonly SCRIPTVERPATH="${SETTINGS_DIR}/version.txt"

##-----------------------------------------------##
## Original Author: ExtremeFiretop [2023-Nov-26] ##
## Modified by: Martinski W. [2023-Dec-01]       ##
##-----------------------------------------------##
_CheckForNewScriptUpdates_()
{
   local DLRepoVersionNum  ScriptVersionNum

   # Download the latest version file from the source repository
   curl --silent --retry 3 "${SCRIPT_URL_BASE}/version.txt" -o "$SCRIPTVERPATH"

   if [ ! -f "$SCRIPTVERPATH" ] ; then UpdateNotify=0 ; return 1 ; fi

   # Read in its contents for the current version file
   DLRepoVersion="$(cat "$SCRIPTVERPATH")"

   DLRepoVersionNum="$(_ScriptVersionStrToNum_ "$DLRepoVersion")"
   ScriptVersionNum="$(_ScriptVersionStrToNum_ "$SCRIPT_VERSION")"

   # Version comparison
   if [ "$DLRepoVersionNum" -gt "$ScriptVersionNum" ]
   then
      UpdateNotify="New script update available: v$SCRIPT_VERSION -> v$DLRepoVersion"
      Say "$(date +'%b %d %Y %X') $(nvram get lan_hostname) ${ScriptFNameTag}_[$$] - INFO: A new script update (v$DLRepoVersion) is available to download."
   else
      UpdateNotify=0
   fi
}

##-----------------------------------------------##
## Original Author: ExtremeFiretop [2023-Nov-26] ##
## Modified by: Martinski W. [2023-Dec-01]       ##
##-----------------------------------------------##
#a function that provides a UI to check for script updates and allows you to install the latest version...
_SCRIPTUPDATE_()
{
   # Check for the latest version from source repository
   _CheckForNewScriptUpdates_
   clear
   logo
   echo
   echo -e "${YLWct}Update Utility${NOct}"
   echo
   echo -e "${CYANct}Current Version: ${YLWct}${SCRIPT_VERSION}${NOct}"
   echo -e "${CYANct}Updated Version: ${YLWct}${DLRepoVersion}${NOct}"
   echo
   if [ "$SCRIPT_VERSION" = "$DLRepoVersion" ]
   then
      echo -e "${CYANct}You are on the latest version! Would you like to download anyways?${NOct}"
      echo -e "${CYANct}This will overwrite your currently installed version.${NOct}"
      if _WaitForYESorNO_ ; then
         echo ; echo
         echo -e "${CYANct}Downloading $SCRIPT_NAME ${CYANct}v$DLRepoVersion${NOct}"
         curl --silent --retry 3 "${SCRIPT_URL_BASE}/${SCRIPT_NAME}.sh" -o "${ScriptsDirPath}/${SCRIPT_NAME}.sh" && chmod +x "${ScriptsDirPath}/${SCRIPT_NAME}.sh"
         curl --silent --retry 3 "${SCRIPT_URL_BASE}/version.txt" -o "$SCRIPTVERPATH"
         echo
         echo -e "${CYANct}Download successful!${NOct}"
         echo -e "$(date) - $SCRIPT_NAME - Successfully downloaded $SCRIPT_NAME v$DLRepoVersion"
         echo
         _WaitForEnterKey_
         return
      else
         echo ; echo
         echo -e "${GRNct}Exiting Update Utility...${NOct}"
         sleep 1
         return
      fi
   elif [ "$UpdateNotify" != "0" ]
   then
      echo -e "${CYANct}Bingo! New version available! Would you like to update now?${NOct}"
      if _WaitForYESorNO_ ; then
         echo ; echo
         echo -e "${CYANct}Downloading $SCRIPT_NAME ${CYANct}v$DLRepoVersion${NOct}"
         curl --silent --retry 3 "${SCRIPT_URL_BASE}/${SCRIPT_NAME}.sh" -o "${ScriptsDirPath}/${SCRIPT_NAME}.sh" && chmod +x "${ScriptsDirPath}/${SCRIPT_NAME}.sh"
         curl --silent --retry 3 "${SCRIPT_URL_BASE}/version.txt" -o "$SCRIPTVERPATH"
         echo
         echo -e "${CYANct}Download successful!${NOct}"
         echo -e "$(date) - $SCRIPT_NAME - Successfully downloaded $SCRIPT_NAME v$DLRepoVersion"
         echo
         _WaitForEnterKey_
         return
      else
         echo ; echo
         echo -e "${GRNct}Exiting Update Utility...${NOct}"
         sleep 1
         return
      fi
   fi
}

##--------------------------------------##
## Added by Martinski W. [22023-Nov-24] ##
##--------------------------------------##
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
   local mounPointPath  retCode=0
   local mountPointRegExp="/dev/sd.* /tmp/mnt/.*"

   mounPointPath="$(grep -m1 "$mountPointRegExp" /proc/mounts | awk -F ' ' '{print $2}')"
   [ -z "$mounPointPath" ] && retCode=1
   echo "$mounPointPath" ; return "$retCode"
}

##----------------------------------------##
## Added by ExtremeFiretop [2023-Nov-26] ##
##----------------------------------------##
logo() {
  echo -e "${YLWct}"
  echo -e "    __  __           _ _               _    _ "
  echo -e "   |  \/  |         | (_)         /\  | |  | |"
  echo -e "   | \  / | ___ _ __| |_ _ __    /  \ | |  | |"
  echo -e "   | |\/| |/ _ | '__| | | '_ \  / /\ \| |  | |"
  echo -e "   | |  | |  __| |  | | | | | |/ ____ | |__| |"
  echo -e "   |_|  |_|\___|_|  |_|_|_| |_/_/    \_\____/ ${GRNct}v${SCRIPT_VERSION}"
  echo -e "                                              ${NOct}"
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

##------------------------------------------##
## Modified by ExtremeFiretop [2023-Nov-23] ##
##------------------------------------------##
_Init_Custom_Settings_Config_()
{
   [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

   if [ ! -f "$SETTINGSFILE" ]
   then
      {
         echo "FW_New_Update_Notification_Date TBD"
         echo "FW_New_Update_Notification_Vers TBD"
         echo "FW_New_Update_Postponement_Days=$FW_UpdateDefaultPostponementDays"
         echo "FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\""
         echo "FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\""
         echo "FW_New_Update_LOG_Directory_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\""
      } > "$SETTINGSFILE"
      return 1
   fi
   local retCode=0

   if ! grep -q "^FW_New_Update_Postponement_Days=" "$SETTINGSFILE"
   then
       sed -i "1 i FW_New_Update_Postponement_Days=$FW_UpdateDefaultPostponementDays" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_Cron_Job_Schedule=" "$SETTINGSFILE"
   then
       sed -i "2 i FW_New_Update_Cron_Job_Schedule=\"${FW_Update_CRON_DefaultSchedule}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_ZIP_Directory_Path=" "$SETTINGSFILE"
   then
       sed -i "3 i FW_New_Update_ZIP_Directory_Path=\"${FW_Update_ZIP_DefaultSetupDIR}\"" "$SETTINGSFILE"
       retCode=1
   fi
   if ! grep -q "^FW_New_Update_LOG_Directory_Path=" "$SETTINGSFILE"
   then
       sed -i "4 i FW_New_Update_LOG_Directory_Path=\"${FW_Update_LOG_BASE_DefaultDIR}\"" "$SETTINGSFILE"
       retCode=1
       # Default log directory path can be changed as needed
   fi
   return "$retCode"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2023-Nov-23] ##
##------------------------------------------##
# Function to get custom setting value from the settings file
Get_Custom_Setting()
{
    if [ $# -eq 0 ] || [ -z "$1" ] ; then echo "**ERROR**" ; return 1 ; fi
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    local setting_value  setting_type="$1"  default_value="TBD"
    [ $# -gt 1 ] && default_value="$2"

    if [ -f "$SETTINGSFILE" ]; then
        case "$setting_type" in
            "credentials_base64" | \
            "FW_New_Update_Notification_Date" | \
            "FW_New_Update_Notification_Vers")
                grep -q "^$setting_type" "$SETTINGSFILE" && grep "^$setting_type" "$SETTINGSFILE" | cut -f2 -d' ' || echo "$default_value"
                ;;
            "local")
                grep -q "^FirmwareVersion_setting" "$SETTINGSFILE" && grep "^FirmwareVersion_setting" "$SETTINGSFILE" | cut -f2 -d' ' || echo "$default_value"
                ;;
            "FW_New_Update_Postponement_Days"  | \
            "FW_New_Update_Cron_Job_Schedule"  | \
            "FW_New_Update_ZIP_Directory_Path" | \
            "FW_New_Update_LOG_Directory_Path")  # Added this line
                if ! grep -q "^${setting_type}=" "$SETTINGSFILE"
                then
                    setting_value="$default_value"
                else
                    setting_value="$(grep "^${setting_type}=" "$SETTINGSFILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                fi
                echo "$setting_value"
                ;;
            *)
                echo "$default_value"
                ;;
        esac
    else
        echo "$default_value"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-01] ##
##----------------------------------------##
Update_Custom_Settings()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] ; then return 1 ; fi

    local fixedVal  oldVal=""
    local setting_type="$1"  setting_value="$2"

    # Check if the directory exists, and if not, create it
    [ ! -d "$SETTINGS_DIR" ] && mkdir -m 755 -p "$SETTINGS_DIR"

    case "$setting_type" in
        "local" | "credentials_base64" | \
        "FW_New_Update_Notification_Date" | \
        "FW_New_Update_Notification_Vers")
            if [ -f "$SETTINGSFILE" ]; then
                if [ "$(grep -c "$setting_type" "$SETTINGSFILE")" -gt 0 ]; then
                    if [ "$setting_value" != "$(grep "^$setting_type" "$SETTINGSFILE" | cut -f2 -d' ')" ]; then
                        sed -i "s/$setting_type.*/$setting_type $setting_value/" "$SETTINGSFILE"
                    fi
                else
                    echo "$setting_type $setting_value" >> "$SETTINGSFILE"
                fi
            else
                echo "$setting_type $setting_value" > "$SETTINGSFILE"
            fi
            ;;
        "FW_New_Update_Postponement_Days"  | \
        "FW_New_Update_Cron_Job_Schedule"  | \
        "FW_New_Update_ZIP_Directory_Path" | \
        "FW_New_Update_LOG_Directory_Path")  # Added this line
            if [ -f "$SETTINGSFILE" ]
            then
                if grep -q "^${setting_type}=" "$SETTINGSFILE"
                then
                    oldVal="$(grep "^${setting_type}=" "$SETTINGSFILE" | awk -F '=' '{print $2}' | sed "s/['\"]//g")"
                    if [ -z "$oldVal" ] || [ "$oldVal" != "$setting_value" ]
                    then
                        fixedVal="$(echo "$setting_value" | sed 's/[\/.,*-]/\\&/g')"
                        sed -i "s/${setting_type}=.*/${setting_type}=\"${fixedVal}\"/" "$SETTINGSFILE"
                    fi
                else
                    echo "$setting_type=\"${setting_value}\"" >> "$SETTINGSFILE"
                fi
            else
                echo "$setting_type=\"${setting_value}\"" > "$SETTINGSFILE"
            fi
            if [ "$setting_type" = "FW_New_Update_Postponement_Days" ]
            then
                FW_UpdatePostponementDays="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_Cron_Job_Schedule" ]
            then
                FW_UpdateCronJobSchedule="$setting_value"
            #
            elif [ "$setting_type" = "FW_New_Update_ZIP_Directory_Path" ]
            then
                FW_ZIP_BASE_DIR="$setting_value"
                FW_ZIP_DIR="${setting_value}/$FW_ZIP_SUBDIR"
                FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"
            #
            elif [ "$setting_type" = "FW_New_Update_LOG_Directory_Path" ]
            then  # Addition for handling log directory path
                FW_LOG_BASE_DIR="$setting_value"
                FW_LOG_DIR="${setting_value}/$FW_LOG_SUBDIR"
            fi
            ;;
        *)
            echo "Invalid setting type: $setting_type"
            ;;
    esac
}

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-01] ##
##----------------------------------------##
_Set_FW_UpdateLOG_DirectoryPath_()
{
   local newLogBaseDirPath="$FW_LOG_BASE_DIR"  newLogFileDirPath=""

   while true
   do
      printf "\nEnter the directory path where the LOG subdirectory [${GRNct}${FW_LOG_SUBDIR}${NOct}] will be stored.\n"
      printf "[${theExitStr}] [CURRENT: ${GRNct}${FW_LOG_BASE_DIR}${NOct}]:  "
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
          printf "${REDct}INVALID input.${NOct}\n"
          continue
      fi

      if [ -d "$userInput" ]
      then newLogBaseDirPath="$userInput" ; break ; fi

      rootDir="${userInput%/*}"
      if [ ! -d "$rootDir" ]
      then
          printf "\n${REDct}**ERROR**${NOct}: Root directory path [${REDct}${rootDir}${NOct}] does NOT exist.\n\n"
          printf "${REDct}INVALID input.${NOct}\n"
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

   if [ "$newLogBaseDirPath" != "$FW_LOG_BASE_DIR" ] && [ -d "$newLogBaseDirPath" ]
   then
       if ! echo "$newLogBaseDirPath" | grep -qE "${FW_LOG_SUBDIR}$"
       then newLogFileDirPath="${newLogBaseDirPath}/$FW_LOG_SUBDIR" ; fi
       mkdir -p -m 755 "$newLogFileDirPath" 2>/dev/null
       if [ ! -d "$newLogFileDirPath" ]
       then
           printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${newLogFileDirPath}${NOct}].\n"
           _WaitForEnterKey_
           return 1
       fi
       # Move any existing log files to new directory #
       mv -f "${FW_LOG_DIR}"/*.log "$newLogFileDirPath" 2>/dev/null
       # Remove now the obsolete directory path #
       if [ "$FW_LOG_BASE_DIR" = "$FW_ZIP_BASE_DIR" ]
       then rm -fr "$FW_LOG_DIR"
       else rm -fr "${FW_LOG_BASE_DIR}/$ScriptFNameTag"
       fi
       # Update the log directory path after validation #
       Update_Custom_Settings FW_New_Update_LOG_Directory_Path "$newLogBaseDirPath"
       echo "The directory path for the log files was updated successfully."
       _WaitForEnterKey_ "$menuReturnPromptStr"
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-01] ##
##----------------------------------------##
_Set_FW_UpdateZIP_DirectoryPath_()
{
   local newZIP_BaseDirPath="$FW_ZIP_BASE_DIR"  newZIP_FileDirPath="" 

   while true
   do
      printf "\nEnter the directory path where the ZIP subdirectory [${GRNct}${FW_ZIP_SUBDIR}${NOct}] will be stored.\n"
      printf "[${theExitStr}] [CURRENT: ${GRNct}${FW_ZIP_BASE_DIR}${NOct}]:  "
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
          printf "${REDct}INVALID input.${NOct}\n"
          continue
      fi

      if [ -d "$userInput" ]
      then newZIP_BaseDirPath="$userInput" ; break ; fi

      rootDir="${userInput%/*}"
      if [ ! -d "$rootDir" ]
      then
          printf "\n${REDct}**ERROR**${NOct}: Root directory path [${REDct}${rootDir}${NOct}] does NOT exist.\n\n"
          printf "${REDct}INVALID input.${NOct}\n"
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

   if [ "$newZIP_BaseDirPath" != "$FW_ZIP_BASE_DIR" ] && [ -d "$newZIP_BaseDirPath" ]
   then
       if ! echo "$newZIP_BaseDirPath" | grep -qE "${FW_ZIP_SUBDIR}$"
       then newZIP_FileDirPath="${newZIP_BaseDirPath}/$FW_ZIP_SUBDIR" ; fi
       mkdir -p -m 755 "$newZIP_FileDirPath" 2>/dev/null
       if [ ! -d "$newZIP_FileDirPath" ]
       then
           printf "\n${REDct}**ERROR**${NOct}: Could NOT create directory [${REDct}${newZIP_FileDirPath}${NOct}].\n"
           _WaitForEnterKey_
           return 1
       fi
       # Remove now the obsolete directory path #
       if [ "$FW_ZIP_BASE_DIR" = "$FW_LOG_BASE_DIR" ]
       then rm -fr "$FW_ZIP_DIR"
       else rm -fr "${FW_ZIP_BASE_DIR}/$ScriptFNameTag"
       fi
       rm -f "${newZIP_FileDirPath}"/*.zip  "${newZIP_FileDirPath}"/*.sha256
       Update_Custom_Settings FW_New_Update_ZIP_Directory_Path "$newZIP_BaseDirPath"
       echo "The directory path for the F/W ZIP file was updated successfully."
       _WaitForEnterKey_ "$menuReturnPromptStr"
   fi
   return 0
}

_Init_Custom_Settings_Config_

##----------------------------------------##
## Modified by Martinski W. [2023-Dec-01] ##
##----------------------------------------##
# NOTE:
# Depending on available RAM & storage capacity of the 
# target router, it may be required to have USB-attached 
# storage for the ZIP file so that it can be downloaded
# in a separate directory from the firmware bin file.
#-----------------------------------------------------------
FW_BIN_BASE_DIR="/home/root"
FW_ZIP_BASE_DIR="$(Get_Custom_Setting FW_New_Update_ZIP_Directory_Path)"
FW_LOG_BASE_DIR="$(Get_Custom_Setting FW_New_Update_LOG_Directory_Path)"

readonly FW_LOG_SUBDIR="${ScriptFNameTag}/logs"
readonly FW_BIN_SUBDIR="${ScriptFNameTag}/$FW_FileName"
readonly FW_ZIP_SUBDIR="${ScriptFNameTag}/$FW_FileName"

FW_BIN_DIR="${FW_BIN_BASE_DIR}/$FW_BIN_SUBDIR"
FW_LOG_DIR="${FW_LOG_BASE_DIR}/$FW_LOG_SUBDIR"
FW_ZIP_DIR="${FW_ZIP_BASE_DIR}/$FW_ZIP_SUBDIR"
FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-24] ##
##----------------------------------------------##
# The built-in F/W hook script file to be used for
# setting up persistent jobs to run after a reboot.
readonly hookScriptFName="services-start"
readonly hookScriptFPath="${SCRIPTS_PATH}/$hookScriptFName"
readonly hookScriptTagStr="#Added by $ScriptFNameTag#"

# Postponement Days for F/W Update Check #
FW_UpdatePostponementDays="$(Get_Custom_Setting FW_New_Update_Postponement_Days)"

# Define the CRON job command to execute #
FW_UpdateCronJobSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
readonly CRON_JOB_RUN="sh $ScriptFilePath run_now"
readonly CRON_JOB_TAG="$ScriptFNameTag"
readonly CRON_SCRIPT_JOB="sh $ScriptFilePath addCronJob &  $hookScriptTagStr"
readonly CRON_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $CRON_SCRIPT_JOB"

# Define post-reboot run job command to execute #
readonly POST_REBOOT_SCRIPT_JOB="sh $ScriptFilePath postRebootRun &  $hookScriptTagStr"
readonly POST_REBOOT_SCRIPT_HOOK="[ -f $ScriptFilePath ] && $POST_REBOOT_SCRIPT_JOB"

if [ ! -d "$FW_LOG_DIR" ]
then
    mkdir -p -m 755 "$FW_LOG_DIR"
else
    # Log rotation - delete logs older than 30 days #
    find "$FW_LOG_DIR" -name '*.log' -mtime +30 -exec rm {} \;
fi

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------------##
loggerFlags="-t"
inMenuMode=true
isInteractive=false
menuReturnPromptStr="Press Enter to return to the main menu..."

if [ -n "$(tty)" ] && [ -n "$PS1" ]
then isInteractive=true ; fi

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------------##
_WaitForEnterKey_()
{
   ! "$isInteractive" && return 0
   local promptStr

   if [ $# -gt 0 ] && [ -n "$1" ]
   then promptStr="$1"
   else promptStr="Press Enter to continue..."
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
   then promptStr=" [yY|nN] N? "
   else promptStr="$1 [yY|nN] N? "
   fi

   printf "$promptStr" ; read -r YESorNO
   if echo "$YESorNO" | grep -qE "^([Yy](es)?)$"
   then echo "OK" ; return 0
   else echo "NO" ; return 1
   fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------##
Say(){
   printf "$@" | logger $loggerFlags "[$(basename "$0")] $$"
   "$isInteractive" && printf "${*}\n"
}

##-------------------------------------##
## Added by Martinski W. [2023-Oct-12] ##
##-------------------------------------##
# Directory for downloading & extracting firmware #
_CreateDirectory_()
{
    if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1 ; fi

    mkdir -p "$1"
    if [ ! -d "$1" ]
    then
        Say "${REDct}**ERROR**${NOct}: Unable to create directory [$1] to download firmware."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi
    # Clear directory in case any previous files still exist #
    rm -f "${1}"/*
    return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-28] ##
##----------------------------------------------##
_DelPostRebootRunScriptHook_()
{
   local hookScriptFile

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi
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

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-17] ##
##----------------------------------------------##
_AddPostRebootRunScriptHook_()
{
   local hookScriptFile  jobHookAdded=false

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi

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

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------------##
_GetCurrentFWInstalledLongVersion_()
{
   local theBranchVers  theVersionStr  extVersNum

   theBranchVers="$(nvram get firmver | sed 's/\.//g')"

   extVersNum="$(nvram get extendno)"
   [ -z "$extVersNum" ] && extVersNum=0

   theVersionStr="$(nvram get buildno).$extVersNum"
   [ -n "$theBranchVers" ] && theVersionStr="${theBranchVers}.${theVersionStr}"

   echo "$theVersionStr"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------##
_GetCurrentFWInstalledShortVersion_()
{
    local theVersionStr  extVersNum

    extVersNum="$(nvram get extendno | awk -F '-' '{print $1}')"
    [ -z "$extVersNum" ] && extVersNum=0

    theVersionStr="$(nvram get buildno).$extVersNum"
    echo "$theVersionStr"
}

get_free_ram() {
    # Using awk to sum up the 'free', 'buffers', and 'cached' columns.
    free | awk '/^Mem:/{print $4 + $6 + $7}'  # This will return the available memory in kilobytes.
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-22] ##
##----------------------------------------##
check_memory_and_reboot()
{
    # Ensure the firmware file path is passed to the function
    if [ $# -eq 0 ] || [ ! -f "$1" ]; then
        Say "${REDct}**ERROR**${NOct}: Firmware file path not provided or file does not exist."
        exit 1
    fi

    local firmware_file_path="$1"

    # sync cached data to permanent storage to prevent data loss #
    sync ; sleep 1 ; sync

    # Get firmware file size in kilobytes #
    firmware_size_kb="$(du -k "$firmware_file_path" | cut -f1)"
    free_ram_kb="$(get_free_ram)"

    if [ "$free_ram_kb" -lt "$firmware_size_kb" ]; then
        Say "Insufficient RAM available to proceed with the firmware update."

        # During an interactive shell session, ask user to confirm reboot #
        if _WaitForYESorNO_ "Reboot router now"
        then
            _AddPostRebootRunScriptHook_
            Say "Rebooting router..."
            /sbin/service reboot
        fi
        exit 1  # Although the reboot command should end the script, it's good practice to exit after.
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------##
_DoCleanUp_()
{
   # Stop the LEDs blinking #
   _Reset_LEDs_

   # Additional cleanup operations can be added here if needed #
   rm -f "${FW_ZIP_DIR}"/*
   if [ $# -gt 0 ] && [ "$1" -eq 1 ]
   then rm -f "${FW_BIN_DIR}"/* ; fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-07] ##
##----------------------------------------##
# Function to check if the current router model is supported
check_version_support() {
    # Minimum supported firmware version
    local minimum_supported_version="386.11.0"

    # Get the current firmware version
    local current_version="$(_GetCurrentFWInstalledShortVersion_)"

    local numFields="$(echo "$current_version" | awk -F '.' '{print NF}')"
    local numCurrentVers="$(_FWVersionStrToNum_ "$current_version" "$numFields")"
    local numMinimumVers="$(_FWVersionStrToNum_ "$minimum_supported_version" "$numFields")"

    # If the current firmware version is lower than the minimum supported firmware version, exit.
    if [ "$numCurrentVers" -lt "$numMinimumVers" ]
    then
        Say "${REDct}The installed firmware version '$current_version' is below '$minimum_supported_version' which is the minimum supported version required.${NOct}" 
        Say "${REDct}Exiting...${NOct}"
        exit 1
    fi
}

check_model_support() {
    # List of unsupported models as a space-separated string
    local unsupported_models="RT-AC68U"

    # Get the current model
    local current_model="$(_GetRouterProductID_)"

    # Check if the current model is in the list of unsupported models
    if echo "$unsupported_models" | grep -wq "$current_model"; then
        # Output a message and exit the script if the model is unsupported
        Say "The $current_model is an unsupported model. Exiting..."
        exit 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------##
_GetLoginCredentials_()
{
    echo "=== Login Credentials ==="
    local username  password  credsBase64

    # Get the username from nvram
    username="$(nvram get http_username)"

    # Prompt the user only for a password [-s flag hides the password input]
    printf "Enter password for user ${GRNct}${username}${NOct}: "
    read -rs password
    echo
    if [ -z "$password" ]
    then
        echo "The Username and Password cannot be empty. Credentials were not saved."
        _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Encode the username and password in Base64 #
    credsBase64="$(echo -n "${username}:${password}" | openssl base64 -A)"

    # Save the credentials to the SETTINGSFILE #
    Update_Custom_Settings credentials_base64 "$credsBase64"

    echo "Credentials saved."
    _WaitForEnterKey_ "$menuReturnPromptStr"
    return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-22] ##
##----------------------------------------------##
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

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-20] ##
##----------------------------------------##
_GetLatestFWUpdateVersionFromWebsite_()
{
    local url="$1"

    local links_and_versions="$(curl -s "$url" | grep -o 'href="[^"]*'"$PRODUCT_ID"'[^"]*\.zip' | sed 's/amp;//g; s/href="//' | 
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

    echo "$versionStr"
    echo "$correct_link"
}

##----------------------------------------##
## Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------##
change_build_type() {
    echo "Changing Build Type..."
    
    # Use Get_Custom_Setting to retrieve the previous choice
    previous_choice="$(Get_Custom_Setting "local" "n")"

    # If running in interactive mode, ask for user's choice
    if [ "$inMenuMode" = true ]; then
        printf "${REDct}Would you like to use the ROG build? (current choice: $previous_choice) (y/n)${NOct}\n"

        while true; do
            read -rp "Enter your choice [$previous_choice]: " choice
            choice="${choice:-$previous_choice}"
            choice="$(echo "$choice" | tr '[:upper:]' '[:lower:]')"

            if [ "$choice" = "y" ] || [ "$choice" = "yes" ] || [ "$choice" = "n" ] || [ "$choice" = "no" ]; then
                break
            else
                echo "Invalid input! Please enter 'y', 'yes', 'n', or 'no'."
            fi
        done

        if [ "$choice" = "y" ] || [ "$choice" = "yes" ]; then
            Update_Custom_Settings "local" "y"
        else
            Update_Custom_Settings "local" "n"
        fi
    else
        # If not in interactive mode, use the previous choice
        if [ "$previous_choice" = "y" ]; then
            echo "Using ROG build as per previous setting."
        else
            echo "Using pure build as per previous setting."
        fi
    fi

    _WaitForEnterKey_ "$menuReturnPromptStr"
}

# Function to translate cron schedule to English
translate_schedule() {
  case "$1" in
    "0 0 * * 0") schedule_english="Every Sunday at midnight" ;;
    "0 0 * * 1") schedule_english="Every Monday at midnight" ;;
    "0 0 * * 2") schedule_english="Every Tuesday at midnight" ;;
    "0 0 * * 3") schedule_english="Every Wednesday at midnight" ;;
    "0 0 * * 4") schedule_english="Every Thursday at midnight" ;;
    "0 0 * * 5") schedule_english="Every Friday at midnight" ;;
    "0 0 * * 6") schedule_english="Every Saturday at midnight" ;;
    "0 0 * * *") schedule_english="Every day at midnight" ;;
    *) schedule_english="Custom [$1]" ;; # for non-standard schedules
  esac
  echo "$schedule_english"
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------------##
_AddCronJobEntry_()
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
   if $cronCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
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
_DelCronJobEntry_()
{
   local retCode
   if $cronCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
   then
       cru d "$CRON_JOB_TAG" ; sleep 1
       if $cronCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
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

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------------##
_Set_FW_UpdatePostponementDays_()
{
   local validNumRegExp="([0-9]|[1-9][0-9])"
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

       printf "${REDct}INVALID input.${NOct}\n" 
   done

   if [ "$newPostponementDays" != "$oldPostponementDays" ]
   then
       Update_Custom_Settings FW_New_Update_Postponement_Days "$newPostponementDays"
       echo "The number of days to postpone F/W Update was updated successfully."
       _WaitForEnterKey_ "$menuReturnPromptStr"
   fi
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------##
_Set_FW_UpdateCronSchedule_()
{
    printf "Changing Firmware Update Schedule...\n"

    local retCode=1  current_schedule=""  new_schedule=""  userInput

    FW_UpdateCronJobSchedule="$(Get_Custom_Setting FW_New_Update_Cron_Job_Schedule)"
    if [ "$FW_UpdateCronJobSchedule" = "TBD" ] ; then FW_UpdateCronJobSchedule="" ; fi

    if [ -n "$FW_UpdateCronJobSchedule" ]
    then
        # Extract the schedule part (the first five fields) from the current cron job line
        current_schedule="$(echo "$FW_UpdateCronJobSchedule" | awk '{print $1, $2, $3, $4, $5}')"
        new_schedule="$current_schedule"

        # Translate the current schedule to English
        current_schedule_english="$(translate_schedule "$current_schedule")"
        printf "Current Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
    else
        new_schedule="$FW_Update_CRON_DefaultSchedule"
    fi

    while true; do  # Loop to keep asking for input
        printf "\nEnter new cron job schedule (e.g. '${GRNct}0 0 * * 0${NOct}' for every Sunday at midnight)"
        if [ -z "$current_schedule" ]
        then printf "\n[${theExitStr}] [Default Schedule: ${GRNct}${new_schedule}${NOct}]:  "
        else printf "\n[${theExitStr}] [Current Schedule: ${GRNct}${current_schedule}${NOct}]:  "
        fi
        read -r userInput

        # If the user enters 'e', break out of the loop and return to the main menu
        if [ -z "$userInput" ] || echo "$userInput" | grep -qE "^(e|exit|Exit)$"
        then break ; fi

        # Validate the input using grep
        if echo "$userInput" | grep -qE '^([0-9,*\/-]+[[:space:]]+){4}[0-9,*\/-]+$'
        then
            new_schedule="$(echo "$userInput" | awk '{print $1, $2, $3, $4, $5}')"
            break  # If valid input, break out of the loop
        else
            printf "${REDct}INVALID schedule.${NOct}\n"
        fi
    done

    [ "$new_schedule" = "$current_schedule" ] && return 0

    FW_UpdateCheckState="$(nvram get firmware_check_enable)"
    [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
    if [ "$FW_UpdateCheckState" -eq 1 ]
    then
        # Add/Update cron job ONLY if "F/W Update Check" is enabled #
        printf "Updating '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
        if _AddCronJobEntry_ "$new_schedule"
        then
            retCode=0
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was updated successfully.\n"
            current_schedule_english="$(translate_schedule "$new_schedule")"
            printf "Job Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
        else
            retCode=1
            printf "${REDct}**ERROR**${NOct}: Failed to add/update the cron job [${CRON_JOB_TAG}].\n"
        fi
    else
        Update_Custom_Settings FW_New_Update_Cron_Job_Schedule "$new_schedule"
        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was configured but not added.\n"
        printf "Firmware Update Check is currently ${REDct}DISABLED${NOct}.\n"
    fi

    _WaitForEnterKey_ "$menuReturnPromptStr"
    return "$retCode"
}

##-------------------------------------##
## Added by Martinski W. [2023-Oct-12] ##
##-------------------------------------##
_CheckNewUpdateFirmwareNotification_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local numVersionFields  fwNewUpdateVersNum

   numVersionFields="$(echo "$2" | awk -F '.' '{print NF}')"
   currentVersionNum="$(_FWVersionStrToNum_ "$1" "$numVersionFields")"
   releaseVersionNum="$(_FWVersionStrToNum_ "$2" "$numVersionFields")"

   if [ "$currentVersionNum" -ge "$releaseVersionNum" ]
   then
       Say "Current firmware version '$1' is up to date."
       Update_Custom_Settings FW_New_Update_Notification_Date TBD
       Update_Custom_Settings FW_New_Update_Notification_Vers TBD
       return 1
   fi

   fwNewUpdateNotificationVers="$(Get_Custom_Setting FW_New_Update_Notification_Vers TBD)"
   if [ -z "$fwNewUpdateNotificationVers" ] || [ "$fwNewUpdateNotificationVers" = "TBD" ]
   then
       fwNewUpdateNotificationVers="$2"
       Update_Custom_Settings FW_New_Update_Notification_Vers "$fwNewUpdateNotificationVers"
   else
       numVersionFields="$(echo "$fwNewUpdateNotificationVers" | awk -F '.' '{print NF}')"
       fwNewUpdateVersNum="$(_FWVersionStrToNum_ "$fwNewUpdateNotificationVers" "$numVersionFields")"
       if [ "$releaseVersionNum" -gt "$fwNewUpdateVersNum" ]
       then
           fwNewUpdateNotificationVers="$2"
           fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
           Update_Custom_Settings FW_New_Update_Notification_Vers "$fwNewUpdateNotificationVers"
           Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
       fi
   fi

   fwNewUpdateNotificationDate="$(Get_Custom_Setting FW_New_Update_Notification_Date TBD)"
   if [ -z "$fwNewUpdateNotificationDate" ] || [ "$fwNewUpdateNotificationDate" = "TBD" ]
   then
       fwNewUpdateNotificationDate="$(date +"$FW_UpdateNotificationDateFormat")"
       Update_Custom_Settings FW_New_Update_Notification_Date "$fwNewUpdateNotificationDate"
   fi
   return 0
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-12] ##
##----------------------------------------------##
_CheckTimeToUpdateFirmware_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ -z "$2" ]
   then echo "**ERROR** **NO_PARAMS**" ; return 1 ; fi

   local notifyTimeSecs  postponeTimeSecs  currentTimeSecs
   local fwNewUpdateNotificationDate  fwNewUpdateNotificationVers  fwNewUpdatePostponementDays

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

   postponeTimeSecs="$((fwNewUpdatePostponementDays * 86400))"
   currentTimeSecs="$(date +%s)"
   notifyTimeStrn="$(echo "$fwNewUpdateNotificationDate" | sed 's/_/ /g')"
   notifyTimeSecs="$(date +%s -d "$notifyTimeStrn")"

   if [ "$((currentTimeSecs - notifyTimeSecs))" -gt "$postponeTimeSecs" ]
   then return 0 ; fi

   upfwDateTimeSecs="$((notifyTimeSecs + postponeTimeSecs))"
   upfwDateTimeStrn="$(echo "$upfwDateTimeSecs" | awk '{print strftime("%Y-%b-%d",$1)}')"

   Say "The firmware update to '${2}' version is postponed for '${fwNewUpdatePostponementDays}' day(s)."
   Say "The firmware update is expected to occur on or after '${upfwDateTimeStrn}' depending on when your cron job is scheduled to check again."
   return 1
}

##------------------------------------------##
## Modified by ExtremeFiretop [2023-Nov-26] ##
##------------------------------------------##
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

   if ! _WaitForYESorNO_ "Do you want to ${fwUpdateCheckNewStateStr} the F/W Update Check?"
   then return 1 ; fi

   if "$fwUpdateCheckEnabled"
   then
       runfwUpdateCheck=false
       FW_UpdateCheckState=0
       fwUpdateCheckNewStateStr="${REDct}DISABLED${NOct}"
       _DelCronJobEntry_
       _DelCronJobRunScriptHook_
   else
       [ -x "$FW_UpdateCheckScript" ] && runfwUpdateCheck=true
       FW_UpdateCheckState=1
       fwUpdateCheckNewStateStr="${GRNct}ENABLED${NOct}"
       if _AddCronJobEntry_
       then
           printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
           _AddCronJobRunScriptHook_
       else
           printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
       fi
   fi

   nvram set firmware_check_enable="$FW_UpdateCheckState"
   printf "Router's built-in Firmware Update Check is now ${fwUpdateCheckNewStateStr}.\n"
   nvram commit

   "$runfwUpdateCheck" && sh $FW_UpdateCheckScript 2>&1 &
   _WaitForEnterKey_ "$menuReturnPromptStr"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2023-Dec-03] ##
##------------------------------------------##
# Embed functions from second script, modified as necessary.
_RunFirmwareUpdateNow_()
{
    # Define log file #
    LOG_FILE="${FW_LOG_DIR}/${MODEL_ID}_FW_Update_$(date '+%Y-%m-%d_%H_%M_%S').log"

    Say "Running the task now... Checking for F/W updates..."
	
    # Retrieve the expected USB mount point from the settings
    ExpectedUSBMountPoint="$(Get_Custom_Setting FW_New_Update_ZIP_Directory_Path)" 

    # Use _GetDefaultUSBMountPoint_ to check the current USB mount point
    CurrentUSBMountPoint="$(_GetDefaultUSBMountPoint_)"

    # Check if the expected USB mount point matches the current mount point
    if [ -n "$ExpectedUSBMountPoint" ] && [ "$ExpectedUSBMountPoint" != "/home/root" ]; then
        if [ "$CurrentUSBMountPoint" != "$ExpectedUSBMountPoint" ]; then
		    Say "Current Mount Point: $CurrentUSBMountPoint"
			Say "Expected Mount Point: $ExpectedUSBMountPoint"
            Say "${REDct}**ERROR**${NOct}: Required USB storage device is not connected or not mounted correctly."
            "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
            return 1
        fi
    fi

    local credsBase64=""
    local currentVersionNum=""  releaseVersionNum=""
    local current_version=""  release_version=""

	# Define the base directory for downloads based on user configuration
    FW_ZIP_BASE_DIR="$(Get_Custom_Setting FW_New_Update_ZIP_Directory_Path)"
    
    # If no custom path is defined or it's not accessible, fall back to /home/root
    if [ -z "$FW_ZIP_BASE_DIR" ] || [ ! -d "$FW_ZIP_BASE_DIR" ]; then
        FW_ZIP_BASE_DIR="/home/root"
        Say "Using fallback directory: $FW_ZIP_BASE_DIR"
    fi

    FW_ZIP_DIR="${FW_ZIP_BASE_DIR}/${FW_ZIP_SUBDIR}"
    FW_ZIP_FPATH="${FW_ZIP_DIR}/${FW_FileName}.zip"

    # Ensure the ZIP directory exists
    if ! _CreateDirectory_ "$FW_ZIP_DIR" ; then return 1 ; fi

    # In case ZIP directory is different from BIN directory
    if [ "$FW_ZIP_DIR" != "$FW_BIN_DIR" ] && ! _CreateDirectory_ "$FW_BIN_DIR" ; then return 1 ; fi

    # Get current firmware version #
    ##FOR DEBUG ONLY##current_version="$(_GetCurrentFWInstalledShortVersion_)"	
    current_version="388.3.0"

    #---------------------------------------------------------#
    # If the "F/W Update Check" in the WebGUI is disabled 
    # exit without further actions. This allows users to 
    # control the "F/W Auto-Update" feature from one place.
    # However, when running in "Menu Mode" the assumption
    # is that the user wants to do a MANUAL Update Check
    # regardless of the state of the "F/W Update Check."
    #---------------------------------------------------------#  
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
    # If no new F/W version update is available exit.
    #------------------------------------------------------
    ##FOR DEBUG ONLY##if ! release_version="$(_GetLatestFWUpdateVersionFromRouter_)" || \
    ##FOR DEBUG ONLY##   ! _CheckNewUpdateFirmwareNotification_ "$current_version" "$release_version"
    ##FOR DEBUG ONLY##then
    ##FOR DEBUG ONLY##    Say "No new firmware version update is found for [$PRODUCT_ID] router model."
    ##FOR DEBUG ONLY##    "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
    ##FOR DEBUG ONLY##    return 1
    ##FOR DEBUG ONLY##fi

    # Use set to read the output of the function into variables
    set -- $(_GetLatestFWUpdateVersionFromWebsite_ "$FW_URL_RELEASE")
    release_version="$1"
    release_link="$2"

    # Extracting the first octet to use in the curl
    firstOctet="$(echo "$release_version" | cut -d'.' -f1)"
    # Inserting dots between each number
    dottedVersion="$(echo "$firstOctet" | sed 's/./&./g' | sed 's/.$//')"

    if ! _CheckTimeToUpdateFirmware_ "$current_version" "$release_version"
    then
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 0
    fi

    ## Check for Login Credentials ##
    credsBase64="$(Get_Custom_Setting credentials_base64)"
    if [ -z "$credsBase64" ] || [ "$credsBase64" = "TBD" ]
    then
        Say "${REDct}**ERROR**${NOct}: No login credentials have been saved. Use the Main Menu to save login credentials."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi
	
	    #BEGIN: Redirect both stdout and stderr to log file #
    {
	
	if [ "$1" = "**ERROR**" ] && [ "$2" = "**NO_URL**" ] 
    then
        Say "${REDct}**ERROR**${NOct}: No firmware release URL was found for [$PRODUCT_ID] router model."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Compare versions before deciding to download
    if [ "$releaseVersionNum" -gt "$currentVersionNum" ]
    then
        # Background function to create a blinking LED effect #
        Toggle_LEDs & Toggle_LEDs_PID=$!
        trap "_DoCleanUp_; exit 0" EXIT HUP INT QUIT TERM

        Say "Latest release version is ${GRNct}${release_version}${NOct}."
        Say "Downloading ${GRNct}${release_link}${NOct}"
        echo
        wget -O "$FW_ZIP_FPATH" "$release_link"
    fi

    if [ ! -f "$FW_ZIP_FPATH" ]
    then
        Say "${REDct}**ERROR**${NOct}: Firmware ZIP file [$FW_ZIP_FPATH] was not downloaded."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Extracting the firmware binary image
    if unzip -o "$FW_ZIP_FPATH" -d "$FW_ZIP_DIR" -x README*
    then
        rm -f "$FW_ZIP_FPATH"
    else
        Say "${REDct}**ERROR**${NOct}: Unable to decompress the firmware ZIP file [$FW_ZIP_FPATH]."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Identify the exact name of the extracted firmware file
    cd "$FW_ZIP_DIR"
    firmware_file=$(ls | grep -i '.trx\|.w\|.chk\|.bin' | head -n 1)

    if [ -z "$firmware_file" ]; then
        Say "${REDct}**ERROR**${NOct}: Extracted firmware file not found in $FW_ZIP_DIR."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Construct the full path of the firmware file
    firmware_file_path="${FW_ZIP_DIR}/${firmware_file}"

    # Check if the firmware file exists
    if [ ! -f "$firmware_file_path" ]; then
        Say "${REDct}**ERROR**${NOct}: Firmware file not found at $firmware_file_path."
        "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
        return 1
    fi

    # Pass the firmware file path to the check_memory_and_reboot function
    check_memory_and_reboot "$firmware_file_path"

    # Use Get_Custom_Setting to retrieve the previous choice
    previous_choice="$(Get_Custom_Setting "local" "n")"

    # Logging user's choice
    # Check for the presence of "rog" in filenames in the extracted directory
    cd "$FW_ZIP_DIR"

    # Identify the ROG and pure firmware files
    rog_file="$(ls | grep -i '_rog_' | head -n 1)"
    pure_file="$(ls | grep -iE '_pureubi.w|_ubi.w' | grep -iv 'rog' | head -n 1)"

    # Get the user's previous choice (if any)
    previous_choice="$(Get_Custom_Setting "local" "n")"

    if [ -n "$rog_file" ]; then
        # If a ROG file is found
        if [ "$inMenuMode" = true ] || [ "$previous_choice" = "n" ]; then
            # If running in menu mode or if the previous choice was pure build
            printf "${REDct}Found ROG build: $rog_file. Would you like to use the ROG build? (y/n)${NOct}\n"
            read -rp "Enter your choice [$previous_choice]: " choice
            choice="${choice:-$previous_choice}"

            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                firmware_file="$rog_file"
                Update_Custom_Settings "local" "y"
            else
                firmware_file="$pure_file"
                Update_Custom_Settings "local" "n"
            fi
        elif [ "$previous_choice" = "y" ]; then
            # If the previous choice was the ROG build
            firmware_file="$rog_file"
        fi
    else
        # Default to pure build if no ROG build is found
        firmware_file="$pure_file"
        Update_Custom_Settings "local" "n"
    fi

    if [ -f "sha256sum.sha256" ] && [ -f "$firmware_file" ]; then
        fw_sig="$(openssl sha256 "$firmware_file" | cut -d' ' -f2)"
        dl_sig="$(grep "$firmware_file" sha256sum.sha256 | cut -d' ' -f1)"
        if [ "$fw_sig" != "$dl_sig" ]; then
            Say "${REDct}**ERROR**${NOct}: Extracted firmware does not match the SHA256 signature!"
            "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
            return 1
        fi
    fi

    routerURLstr="$(_GetRouterURL_)"
    # DEBUG: Print the LAN IP to ensure it's being set correctly
    printf "\n**DEBUG**: Router Web URL is: ${routerURLstr}\n"

    check_memory_and_reboot "$firmware_file_path"

    curl_response="$(curl "${routerURLstr}/login.cgi" \
    --referer ${routerURLstr}/Main_Login.asp \
    --user-agent 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Origin: ${routerURLstr}/" \
    -H 'Connection: keep-alive' \
    --data-raw "group_id=&action_mode=&action_script=&action_wait=5&current_page=Main_Login.asp&next_page=index.asp&login_authorization=${credsBase64}" \
    --cookie-jar /tmp/cookie.txt)"

    # IMPORTANT: Due to the nature of 'nohup' and the specific behavior of this 'curl' request,
    # the following 'curl' command MUST always be the last step in this block.
    # Do NOT insert any operations after it! (unless you understand the implications).

    printf "${GRNct}**IMPORTANT**:${NOct}\nThe firmware flash is about to start.\n"
    printf "Press Enter to stop now, or type ${GRNct}Y${NOct} to continue.\n"
    printf "Once started, the flashing process CANNOT be interrupted.\n"
    if ! _WaitForYESorNO_ "Continue"
    then _DoCleanUp_ 1 ; return 1 ; fi

    if echo "$curl_response" | grep -q 'url=index.asp'
    then
        Say "Flashing ${GRNct}${firmware_file}${NOct}... ${REDct}Please Wait for Reboot.${NOct}"
        echo

        nohup curl "${routerURLstr}/upgrade.cgi" \
        --referer ${routerURLstr}/Advanced_FirmwareUpgrade_Content.asp \
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
        sleep 60
    else
        Say "${REDct}**ERROR**${NOct}: Login failed. Please try the following:
1. Confirm you are not already logged into the router with a browser.
2. Update credentials by selecting \"Configure Router Login Credentials\" from the Main Menu."
        _DoCleanUp_ 1
    fi

    } 2>&1 | tee -a "$LOG_FILE"
    #END: Redirect both stdout and stderr to log file #

    # Stop the LEDs blinking #
    _Reset_LEDs_

    "$inMenuMode" && _WaitForEnterKey_ "$menuReturnPromptStr"
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-20] ##
##-------------------------------------##
_PostRebootRunNow_()
{
   _DelPostRebootRunScriptHook_

   local theWaitDelaySecs=10
   local maxWaitDelaySecs=360  #6 minutes#
   local curWaitDelaySecs=0
   #---------------------------------------------------------
   # Wait until all services are started, including NTP
   # so the system clock is updated with correct time.
   # By this time the USB drive should be mounted as well.
   #---------------------------------------------------------
   while [ "$curWaitDelaySecs" -lt "$maxWaitDelaySecs" ]
   do
      if [ -d "$FW_ZIP_BASE_DIR" ] && \
         [ "$(nvram get ntp_ready)" -eq 1 ] && \
         [ "$(nvram get start_service_ready)" -eq 1 ] && \
         [ "$(nvram get success_start_service)" -eq 1 ]
      then sleep 30 ; break; fi

      echo "Waiting for all services to be started [$theWaitDelaySecs secs.]..."
      sleep $theWaitDelaySecs
      curWaitDelaySecs="$((curWaitDelaySecs + theWaitDelaySecs))"
   done

   _RunFirmwareUpdateNow_
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------------##
_DelCronJobRunScriptHook_()
{
   local hookScriptFile

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi
   if [ ! -f "$hookScriptFile" ] ; then return 1 ; fi

   if grep -qE "$CRON_SCRIPT_JOB" "$hookScriptFile"
   then
       sed -i -e '/\/'"$ScriptFileName"' addCronJob &  '"$hookScriptTagStr"'/d' "$hookScriptFile"
       if [ $? -eq 0 ]
       then
           Say "Cron job hook was deleted successfully from '$hookScriptFile' script."
       fi
   else
       printf "Cron job hook does not exist in '$hookScriptFile' script.\n"
   fi
}

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Oct-17] ##
##----------------------------------------------##
_AddCronJobRunScriptHook_()
{
   local hookScriptFile  jobHookAdded=false

   if [ $# -gt 0 ] && [ -n "$1" ]
   then hookScriptFile="$1"
   else hookScriptFile="$hookScriptFPath"
   fi

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

##----------------------------------------------##
## Added/Modified by Martinski W. [2023-Dec-01] ##
##----------------------------------------------##
_DoUninstall_()
{
   printf "Are you sure you want to uninstall $ScriptFileName script now"
   ! _WaitForYESorNO_ && return 0

   _DelCronJobEntry_
   _DelCronJobRunScriptHook_
   _DelPostRebootRunScriptHook_
   if rm -fr "$SETTINGS_DIR" && \
      rm -fr "${FW_BIN_BASE_DIR}/$ScriptFNameTag" && \
      rm -fr "${FW_LOG_BASE_DIR}/$ScriptFNameTag" && \
      rm -fr "${FW_ZIP_BASE_DIR}/$ScriptFNameTag" && \
      rm -f "$ScriptFilePath"
   then
       Say "${GRNct}Successfully Uninstalled.${NOct}"
   else
       Say "${REDct}Error: Uninstallation failed.${NOct}"
   fi
   exit 0
}

##-------------------------------------##
## Added by Martinski W. [2023-Nov-21] ##
##-------------------------------------##
# Prevent running this script multiple times simultaneously #
procCount="$(ps -w | grep "$ScriptFileName" | grep -vE "grep ${ScriptFileName}|^[[:blank:]]*$$[[:blank:]]+" | wc -l)"
if [ "$procCount" -gt 1 ]
then
    printf "\n${REDct}**ERROR**${NOct}: The shell script '${ScriptFileName}' is already running [$procCount]. Exiting..."
    exit 1
fi

# Check if the router model is supported OR if
# it has the minimum firmware version supported.
check_model_support
check_version_support

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-28] ##
##----------------------------------------##
if [ $# -gt 0 ]
then
   inMenuMode=false
   case $1 in
       run_now) _RunFirmwareUpdateNow_ ; exit 0
           ;;
       addCronJob) _AddCronJobEntry_ ; exit 0
           ;;
       postRebootRun) _PostRebootRunNow_ ; exit 0
           ;;
       uninstall) _DoUninstall_ ; exit 0
           ;;

##FOR TEST/DEBUG ONLY##
##DBG##addPostRebootHook) _AddPostRebootRunScriptHook_ ; exit 0 ;;

##FOR TEST/DEBUG ONLY##
##DBG##delPostRebootHook) _DelPostRebootRunScriptHook_ ; exit 0 ;;

       *) printf "${REDct}INVALID Parameter.${NOct}\n" ; exit 1
           ;;
   esac
fi

# Download the latest version file from the source repository #
# to check if there's a new version update to notify the user #
_CheckForNewScriptUpdates_

##----------------------------------------##
## Modified by Martinski W. [2023-Nov-19] ##
##----------------------------------------##
FW_UpdateCheckState="$(nvram get firmware_check_enable)"
[ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
if [ "$FW_UpdateCheckState" -eq 1 ]
then
    # Add cron job ONLY if "F/W Update Check" is enabled #
    if ! $cronCmd | grep -qE "$CRON_JOB_RUN #${CRON_JOB_TAG}#$"
    then
        # Add the cron job if it doesn't exist
        printf "Adding '${GRNct}${CRON_JOB_TAG}${NOct}' cron job...\n"
        if _AddCronJobEntry_
        then
            printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' was added successfully.\n"
            current_schedule_english="$(translate_schedule "$FW_UpdateCronJobSchedule")"
            printf "Job Schedule: ${GRNct}${current_schedule_english}${NOct}\n"
        else
            printf "${REDct}**ERROR**${NOct}: Failed to add the cron job [${CRON_JOB_TAG}].\n"
        fi
    else
        printf "Cron job '${GRNct}${CRON_JOB_TAG}${NOct}' already exists.\n"
    fi
    _AddCronJobRunScriptHook_
    _WaitForEnterKey_
fi

rog_file=""

FW_RouterProductID="${GRNct}${PRODUCT_ID}${NOct}"
if [ "$PRODUCT_ID" = "$MODEL_ID" ]
then FW_RouterModelID="${FW_RouterProductID}"
else FW_RouterModelID="${FW_RouterProductID}/${GRNct}${MODEL_ID}${NOct}"
fi

FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
FW_InstalledVersion="${GRNct}$(_GetCurrentFWInstalledLongVersion_)${NOct}"

##------------------------------------------##
## Modified by ExtremeFiretop [2023-Dec-03] ##
##------------------------------------------##
show_menu()
{
   clear
   SEPstr="-----------------------------------------------------"
   logo
   printf "${YLWct}========= By ExtremeFiretop & Martinski W. ==========${NOct}\n\n"

   # New Script Update Notification #
   if [ "$UpdateNotify" != "0" ]; then
      Say "${REDct}${UpdateNotify}${NOct}"
   fi

   padStr="      "  arrowStr=" ${REDct}<<---${NOct}"

   printf "${SEPstr}"
   if ! FW_NewUpdateVersion="$(_GetLatestFWUpdateVersionFromRouter_ 1)"
   then FW_NewUpdateVersion="${REDct}NONE FOUND${NOct}"
   else FW_NewUpdateVersion="${GRNct}${FW_NewUpdateVersion}${NOct}$arrowStr"
   fi
   printf "\n${padStr}F/W Product/Model ID:  $FW_RouterModelID"
   printf "\n${padStr}F/W Update Available:  $FW_NewUpdateVersion"
   printf "\n${padStr}F/W Version Installed: $FW_InstalledVersion"
   printf "\n${padStr}USB Storage Connected: $USBConnected"

   printf "\n${SEPstr}"
   printf "\n  ${GRNct}1${NOct}.  Run Update F/W Check Now\n"
   printf "\n  ${GRNct}2${NOct}.  Configure Router Login Credentials\n"
   
   # Enable/Disable the ASUS Router's built-in "F/W Update Check" #
   FW_UpdateCheckState="$(nvram get firmware_check_enable)"
   [ -z "$FW_UpdateCheckState" ] && FW_UpdateCheckState=0
   if [ "$FW_UpdateCheckState" -eq 0 ]
   then
       printf "\n  ${GRNct}3${NOct}.  Enable F/W Update Check"
       printf "\n      [Currently ${REDct}DISABLED${NOct}]\n"
   else
       printf "\n  ${GRNct}3${NOct}.  Disable F/W Update Check"
       printf "\n      [Currently ${GRNct}ENABLED${NOct}]\n"
   fi
   
   printf "\n  ${GRNct}4${NOct}.  Set F/W Update Postponement Days"
   printf "\n      [Current Days: ${GRNct}${FW_UpdatePostponementDays}${NOct}]\n"

   printf "\n  ${GRNct}5${NOct}.  Set F/W Update Check Schedule"
   printf "\n      [Current Schedule: ${GRNct}${FW_UpdateCronJobSchedule}${NOct}]\n"

   printf "\n  ${GRNct}6${NOct}.  Set Directory Path for F/W Update ZIP File"
   printf "\n      [Current Path: ${GRNct}${FW_ZIP_DIR}${NOct}]\n"

   printf "\n  ${GRNct}7${NOct}.  Set Directory Path for F/W Update Log Files"
   printf "\n      [Current Path: ${GRNct}${FW_LOG_DIR}${NOct}]\n"

    # Check the current build type setting
    local current_build_setting="$(Get_Custom_Setting "local" "n")"

    # Check if the directory exists before attempting to navigate to it
    if [ -d "$FW_BIN_DIR" ]; then
        cd "$FW_BIN_DIR"

        # Display the "Change Build Type" option based on the current build setting
        if [ "$current_build_setting" = "y" ] || [ "$current_build_setting" = "n" ]; then
            printf "\n  ${GRNct}8${NOct}.  Change Update Build Type\n"
        fi
    fi

   # Check for new script updates #
   if [ "$UpdateNotify" != "0" ]; then
      printf "\n ${GRNct}up${NOct}.  Update $SCRIPT_NAME Script Now"
      printf "\n      [Version: ${GRNct}${DLRepoVersion}${NOct} Available for Download]\n"
   fi

   printf "\n ${GRNct}un${NOct}.  Uninstall\n"
   printf "\n  ${GRNct}e${NOct}.  Exit\n"
   printf "${SEPstr}\n"
}

##------------------------------------------##
## Modified by ExtremeFiretop [2023-Dec-03] ##
##------------------------------------------##
# Main Menu loop
inMenuMode=true
theExitStr="${GRNct}e${NOct}=Exit to main menu"

while true
do
   # Check the current build type setting
   current_build_setting="$(Get_Custom_Setting "local" "n")"
   show_menu

   # Check if the directory exists again before attempting to navigate to it
   if [ -d "$FW_BIN_DIR" ]; then
       cd "$FW_BIN_DIR"
       # Check for the presence of "rog" in filenames in the directory again
       rog_file="$(ls | grep -i '_rog_')"
   fi

   printf "Enter selection:  " ; read -r userChoice
   echo
   case $userChoice in
       1) _RunFirmwareUpdateNow_
          ;;
       2) _GetLoginCredentials_
          ;;
       3) _Toggle_FW_UpdateCheckSetting_
          ;;
       4) _Set_FW_UpdatePostponementDays_
          ;;
       5) _Set_FW_UpdateCronSchedule_
          ;;
       6) _Set_FW_UpdateZIP_DirectoryPath_
          ;;
       7) _Set_FW_UpdateLOG_DirectoryPath_
          ;;
       8) 
          if [ "$current_build_setting" = "y" ] || [ "$current_build_setting" = "n" ]; then
              change_build_type
          else
              printf "${REDct}The option to change the build type is not available.${NOct}\n"
              _WaitForEnterKey_
          fi
          ;;
      up) _SCRIPTUPDATE_
          ;;
      un) _DoUninstall_ && _WaitForEnterKey_
          ;;
  e|exit) exit 0
          ;;
       *) printf "${REDct}INVALID selection.${NOct} Please try again."
          _WaitForEnterKey_
          ;;
   esac
done

#EOF#
