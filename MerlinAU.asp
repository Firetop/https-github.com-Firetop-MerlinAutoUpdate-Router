<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" 
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<!-- Use router-provided CSS -->
<meta http-equiv="X-UA-Compatible" content="IE=Edge" />
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="-1" />
<link rel="shortcut icon" href="images/favicon.png" />
<link rel="icon" href="images/favicon.png" />
<link rel="stylesheet" type="text/css" href="index_style.css" />
<link rel="stylesheet" type="text/css" href="form_style.css" />
<title>MerlinAU add-on for ASUSWRT-Merlin Firmware</title>
<style>
.SettingsTable .Invalid { background-color: red !important; }
</style>
<!-- Native built-in JS files -->
<script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/js/httpApi.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmhist.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmmenu.js"></script>
<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script language="JavaScript" type="text/javascript">

/**----------------------------**/
/** Last Modified: 2025-Jan-13 **/
/** Intended for 1.4.0 Release **/
/**----------------------------**/

// Separate variables for server and AJAX settings //
var advanced_settings = {};
var custom_settings = {};
var server_custom_settings = {};
var ajax_custom_settings = {};

// Define color formatting //
const CYANct = "<span style='color:cyan;'>";
const REDct = "<span style='color:red;'>";
const GRNct = "<span style='color:green;'>";
const NOct = "</span>";

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-05] **/
/**-------------------------------------**/
const InvGRNct = '<span style="margin-left:4px; background-color:#229652; color:#f2f2f2;">&nbsp;'
const InvREDct = '<span style="margin-left:4px; background-color:#C81927; color:#f2f2f2;">&nbsp;'
const InvYLWct = '<span style="margin-left:4px; background-color:yellow; color:black;">&nbsp;'
const InvCYNct = '<span style="margin-left:4px; background-color:cyan; color:black;">&nbsp;'
const InvCLEAR = '&nbsp;</span>'

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-13] **/
/**-------------------------------------**/
// To support 'fwUpdatePostponement' element //
const fwPostponedDays =
{
   minVal: 0, maxVal: 199, maxLen: 3,
   ErrorMsg: function()
   {
      return (`The number of postponement days for F/W updates is INVALID.\nThe value must be between ${this.minVal} and ${this.maxVal} days.`);
   },
   LabelText: function()
   {
      return (`F/W Update Postponement (${this.minVal} to ${this.maxVal} days)`);
   },
   ValidateNumber: function(formField)
   {
      const inputVal = (formField.value * 1);
      const inputLen = formField.value.length;
      if (inputLen === 0 || inputLen > this.maxLen ||
          inputVal < this.minVal || inputVal > this.maxVal)
      { return false; }
      else
      { return true; }
   }
};

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-13] **/
/**-------------------------------------**/
function ValidatePostponedDays (formField)
{
   if (fwPostponedDays.ValidateNumber(formField))
   {
      $(formField).removeClass('Invalid');
      $(formField).off('mouseover');
      return true;
   }
   else
   {
      formField.focus();
      $(formField).addClass('Invalid');
      $(formField).on('mouseover',function(){return overlib(fwPostponedDays.ErrorMsg(),0,0);});
      $(formField)[0].onmouseout = nd;
      return false;
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-05] **/
/**-------------------------------------**/
function FormatNumericSetting(forminput)
{
   let inputvalue = forminput.value * 1;

   if (forminput.value.length === 0 || isNaN(inputvalue))
   {
       return false;
   }
   else
   {
       forminput.value = parseInt(forminput.value, 10);
       return true;
   }
}

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-13] **/
/**-------------------------------------**/
// To support 'routerPassword' element //
const loginPassword =
{
   minLen: 5, maxLen: 64, currLen: 0,
   ErrorMsg: function()
   {
      const errStr = 'The password string is INVALID.';
      if (this.currLen < this.minLen)
      {
         const excMinLen = (this.minLen - 1);
         return (`${errStr}\nThe string length must be greater than ${excMinLen} characters.`);
      }
      if (this.currLen > this.maxLen)
      {
         const excMaxLen = (this.maxLen + 1);
         return (`${errStr}\nThe string length must be less than ${excMaxLen} characters.`);
      }
   },
   ValidateString: function(formField)
   {
      const inputVal = formField.value;
      const inputLen = formField.value.length;
      this.currLen = inputLen;
      if (inputLen < this.minLen || inputLen > this.maxLen)
      { return false; }
      else
      { return true; }
   }
};

/**-------------------------------------**/
/** Added by Martinski W. [2025-Jan-13] **/
/**-------------------------------------**/
function ValidatePasswordString (formField)
{
   if (loginPassword.ValidateString(formField))
   {
      $(formField).removeClass('Invalid');
      $(formField).off('mouseover');
      return true;
   }
   else
   {
      formField.focus();
      $(formField).addClass('Invalid');
      $(formField).on('mouseover',function(){return overlib(loginPassword.ErrorMsg(),0,0);});
      $(formField)[0].onmouseout = nd;
      return false;
   }
}

function togglePassword()
{
    const passInput = document.getElementById('routerPassword');
    const eyeDiv = document.getElementById('eyeToggle');
    
    if (passInput.type === 'password')
    {
        passInput.type = 'text';
        eyeDiv.style.background = "url('/images/icon-invisible@2x.png') no-repeat center";
    } 
    else
    {
        passInput.type = 'password';
        eyeDiv.style.background = "url('/images/icon-visible@2x.png') no-repeat center";
    }
    eyeDiv.style.backgroundSize = 'contain';
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-11] **/
/**----------------------------------------**/
// Converts F/W version string with the format: "3006.102.5.2" //
// to a number of the format: '30061020502'  //
function FWVersionStrToNum(verStr)
{
    // If it's empty or null, treat as ZERO //
    if (!verStr) return 0;

    let nonProductionVersionWeight;
    foundAlphaBetaVersion = verStr.match (/([Aa]lpha|[Bb]eta)/);
    if (foundAlphaBetaVersion == null)
    {
       nonProductionVersionWeight = 0;
    }
    else
    {
       nonProductionVersionWeight = 100;
       verStr = verStr.replace (/([Aa]lpha|[Bb]eta)[0-9]*/,'0');
    }

    // Remove everything after the first non-numeric-and-dot character //
    // e.g. "3006.102.1.alpha1" => "3006.102.1" //
    verStr = verStr.split(/[^\d.]/, 1)[0];

    let segments = verStr.split('.');
    let partNum=0, partStr='', verNumStr='';

    for (var index=0 ; index < segments.length ; index++)
    {
        if (segments[index].length > 2)
        { partStr = segments[index]; }
        else
        { partStr = segments[index].padStart(2, '0'); }
        verNumStr = (verNumStr + partStr);
    }
    let verNum = (parseInt(verNumStr, 10) - nonProductionVersionWeight);

    return (verNum);
}

function LoadCustomSettings()
{
    server_custom_settings = <% get_custom_settings(); %>;
    console.log("Server Custom Settings Loaded:", server_custom_settings);
}

function prefixCustomSettings(settings, prefix)
{
    let prefixedSettings = {};
    for (let key in settings)
    {
        if (settings.hasOwnProperty(key)) {
            prefixedSettings[prefix + key] = settings[key];
        }
    }
    return prefixedSettings;
}

// Function to handle the visibility of the ROG and TUF F/W Build Type rows
function handleROGFWBuildTypeVisibility() 
{
        // Get the router model from the hidden input
        var firmwareProductModelElement = document.getElementById('firmwareProductModelID');
        var routerModel = firmwareProductModelElement ? firmwareProductModelElement.textContent.trim() : '';

        // ROG Model Check //
        var isROGModel = routerModel.includes('GT-');
        var hasROGFWBuildType = custom_settings.hasOwnProperty('FW_New_Update_ROGFWBuildType');
        var rogFWBuildRow = document.getElementById('rogFWBuildRow');

        if (!isROGModel || !hasROGFWBuildType)
        {  // Hide //
            if (rogFWBuildRow) { rogFWBuildRow.style.display = 'none'; }
        }
        else
        {  // Show //
            if (rogFWBuildRow) { rogFWBuildRow.style.display = ''; }
        }

        // TUF Model Check //
        var isTUFModel = routerModel.includes('TUF-');
        var hasTUFWBuildType = custom_settings.hasOwnProperty('FW_New_Update_TUFWBuildType');
        var tufFWBuildRow = document.getElementById('tuffFWBuildRow');

        if (!isTUFModel || !hasTUFWBuildType)
        {  // Hide //
            if (tufFWBuildRow) { tufFWBuildRow.style.display = 'none'; }
        }
        else
        {  // Show //
            if (tufFWBuildRow) { tufFWBuildRow.style.display = ''; }
        }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-13] **/
/**----------------------------------------**/
function initializeFields()
{
    console.log("Initializing fields...");
    let changelogCheckEnabled = document.getElementById('changelogCheckEnabled');
    let fwNotificationsDate = document.getElementById('fwNotificationsDate');
    let routerPassword = document.getElementById('routerPassword');
    let fwUpdatePostponement = document.getElementById('fwUpdatePostponement');
    let emailNotificationsEnabled = document.getElementById('emailNotificationsEnabled');
    let autobackupEnabled = document.getElementById('autobackupEnabled');
    let secondaryEmail = document.getElementById('secondaryEmail');
    let emailFormat = document.getElementById('emailFormat');
    let rogFWBuildType = document.getElementById('rogFWBuildType');
    let tuffFWBuildType = document.getElementById('tuffFWBuildType');
    let tailscaleVPNEnabled = document.getElementById('tailscaleVPNEnabled');
    let autoUpdatesScriptEnabled = document.getElementById('autoUpdatesScriptEnabled');
    let betaToReleaseUpdatesEnabled = document.getElementById('betaToReleaseUpdatesEnabled');
    let fwUpdateDirectory = document.getElementById('fwUpdateDirectory');

    // Instead of reading from firmware_check_enable, read from the custom_settings
    let storedFwUpdateEnabled = custom_settings.FW_Update_Check || 'DISABLED'; 
    // fallback to 'DISABLED' if custom_settings.FW_Update_Check is missing

    // Get the checkbox and status elements
    let FW_Update_Check = document.getElementById('FW_Update_Check');
    let fwUpdateCheckStatus = document.getElementById('fwUpdateCheckStatus');

    // Set the checkbox state based on "ENABLED" vs. "DISABLED" vs. "TBD"
    if (FW_Update_Check)
    { FW_Update_Check.checked = (storedFwUpdateEnabled === 'ENABLED'); }

    // Update the Firmware Status display //
    if (fwUpdateCheckStatus)
    {  // Pass the raw string ('ENABLED', 'DISABLED', or 'TBD') to our setStatus function
       setStatus('fwUpdateCheckStatus', storedFwUpdateEnabled);
    }

    // Safe value assignments //
    if (custom_settings)
    {
        if (routerPassword)
        { routerPassword.value = custom_settings.routerPassword || ''; }

        if (fwUpdatePostponement)
        {
            fwPosptonedDaysLabel = document.getElementById('fwUpdatePostponementLabel');
            fwPosptonedDaysLabel.textContent = fwPostponedDays.LabelText();
            fwUpdatePostponement.value = custom_settings.FW_New_Update_Postponement_Days || '15'; 
        }

        if (secondaryEmail)
        { secondaryEmail.value = custom_settings.FW_New_Update_EMail_CC_Address || ''; }

        if (emailFormat)
        { emailFormat.value = custom_settings.FW_New_Update_EMail_FormatType || 'HTML'; }

        if (rogFWBuildType)
        { rogFWBuildType.value = custom_settings.FW_New_Update_ROGFWBuildType || 'ROG'; }

        if (tuffFWBuildType)
        { tuffFWBuildType.value = custom_settings.FW_New_Update_TUFWBuildType || 'TUF'; }

        if (changelogCheckEnabled)
        { changelogCheckEnabled.checked = (custom_settings.CheckChangeLog === 'ENABLED'); }

        if (autobackupEnabled)
        {
            if (custom_settings.hasOwnProperty('FW_Auto_Backupmon'))
            {
                // If the setting exists, enable the checkbox and set its state
                autobackupEnabled.disabled = false;
                autobackupEnabled.checked = (custom_settings.FW_Auto_Backupmon === 'ENABLED');
                autobackupEnabled.style.opacity = '1'; // Fully opaque
            }
            else
            {
                // If the setting is missing, disable and gray out the checkbox
                autobackupEnabled.disabled = true;
                autobackupEnabled.checked = false; // Optionally uncheck
                autobackupEnabled.style.opacity = '0.5'; // Grayed out appearance
            }
        }
        if (emailNotificationsEnabled && emailFormat && secondaryEmail)
        {
            // Check if 'FW_New_Update_EMail_Notification' is present in custom_settings
            if (custom_settings.hasOwnProperty('FW_New_Update_EMail_Notification'))
            {
                // If the setting exists, enable the checkbox and controls
                emailNotificationsEnabled.disabled = false;
                emailNotificationsEnabled.checked = (custom_settings.FW_New_Update_EMail_Notification === 'ENABLED');
                emailNotificationsEnabled.style.opacity = '1';
                emailFormat.disabled = false;
                emailFormat.style.opacity = '1';
                secondaryEmail.disabled = false;
                secondaryEmail.style.opacity = '1';
            }
            else
            {
                // If the setting is missing, disable and gray out the checkbox, dropdown, and email input
                emailNotificationsEnabled.disabled = true;
                emailNotificationsEnabled.checked = false;
                emailNotificationsEnabled.style.opacity = '0.5';
                emailFormat.disabled = true;
                emailFormat.style.opacity = '0.5';
                secondaryEmail.disabled = true;
                secondaryEmail.style.opacity = '0.5';
            }
        }
        if (tailscaleVPNEnabled)
        { tailscaleVPNEnabled.checked = (custom_settings.Allow_Updates_OverVPN === 'ENABLED'); }

        if (autoUpdatesScriptEnabled)
        { autoUpdatesScriptEnabled.checked = (custom_settings.Allow_Script_Auto_Update === 'ENABLED'); }

        if (betaToReleaseUpdatesEnabled)
        { betaToReleaseUpdatesEnabled.checked = (custom_settings.FW_Allow_Beta_Production_Up === 'ENABLED'); }

        if (fwUpdateDirectory)
        { fwUpdateDirectory.value = custom_settings.FW_New_Update_ZIP_Directory_Path || ''; }

        // Update Settings Status Table //
        setStatus('changelogCheckStatus', custom_settings.CheckChangeLog);
        setStatus('betaToReleaseUpdatesStatus', custom_settings.FW_Allow_Beta_Production_Up);
        setStatus('tailscaleVPNAccessStatus', custom_settings.Allow_Updates_OverVPN);
        setStatus('autoUpdatesScriptEnabledStatus', custom_settings.Allow_Script_Auto_Update);
        setStatus('autobackupEnabledStatus', custom_settings.FW_Auto_Backupmon);
        setStatus('emailNotificationsStatus', custom_settings.FW_New_Update_EMail_Notification);

        // Handle fwNotificationsDate as a date //
        if (fwNotificationsDate && custom_settings.FW_New_Update_Notifications_Date)
        {
            let theDateTimeStr = custom_settings.FW_New_Update_Notifications_Date.split ('_');
            let notifyDatestr = theDateTimeStr[0] + ' ' + theDateTimeStr[1];
            fwNotificationsDate.innerHTML = InvYLWct + notifyDatestr + InvCLEAR;
        }
        else if (fwNotificationsDate)
        { fwNotificationsDate.innerHTML = InvYLWct + "TBD" + InvCLEAR; }

        // **Handle fwUpdateEstimatedRunDate Separately**
        var fwUpdateEstimatedRunDateElement = document.getElementById('fwUpdateEstimatedRunDate');

        // **Handle fwUpdateAvailable with Version Comparison**
        var fwUpdateAvailableElement = document.getElementById('fwUpdateAvailable');
        var fwVersionInstalledElement = document.getElementById('fwVersionInstalled');

        var isFwUpdateAvailable = false; // Initialize the flag

        if (fwUpdateAvailableElement && fwVersionInstalledElement)
        {
            var fwUpdateAvailable = FW_New_Update_Available
            var fwVersionInstalled = fwVersionInstalledElement.textContent.trim();

            // Convert both to numeric forms //
            var verNumAvailable = FWVersionStrToNum(fwUpdateAvailable);
            var verNumInstalled = FWVersionStrToNum(fwVersionInstalled);

            // If verNumAvailable is 0, maybe treat as "NONE FOUND" //
            if (verNumAvailable === 0)
            {
                fwUpdateAvailableElement.innerHTML = InvYLWct + "NONE FOUND" + InvCLEAR;
                isFwUpdateAvailable = false;
            }
            else if (verNumAvailable > verNumInstalled)
            {   // Update available //
                fwUpdateAvailableElement.innerHTML = InvYLWct + fwUpdateAvailable + InvCLEAR;
                isFwUpdateAvailable = true;
            } 
            else // No update //
            {
                fwUpdateAvailableElement.innerHTML = InvYLWct + "NONE FOUND" + InvCLEAR;
                isFwUpdateAvailable = false;
            }
        }
        else
        { console.error("Required elements for firmware version comparison not found."); }

        // **Update fwUpdateEstimatedRunDate Based on fwUpdateAvailable**
        if (fwUpdateEstimatedRunDateElement)
        {
            if (isFwUpdateAvailable && fwUpdateAvailable !== '')
            { fwUpdateEstimatedRunDateElement.innerHTML = InvYLWct + fwUpdateEstimatedRunDate + InvCLEAR; }
            else
            { fwUpdateEstimatedRunDateElement.innerHTML = InvYLWct + "TBD" + InvCLEAR; }
        }

        // **Handle Changelog Approval Display**
        var changelogApprovalElement = document.getElementById('changelogApproval');
        if (changelogApprovalElement)
        {   // Default to "Disabled" if missing //
            var approvalStatus = custom_settings.hasOwnProperty('FW_New_Update_Changelog_Approval') ? custom_settings.FW_New_Update_Changelog_Approval : "Disabled";
            if (approvalStatus === "TBD")
            { changelogApprovalElement.innerHTML = InvYLWct + approvalStatus + InvCLEAR; }
            else if (approvalStatus === "BLOCKED")
            { changelogApprovalElement.innerHTML = InvREDct + approvalStatus + InvCLEAR; }
            else if (approvalStatus === "APPROVED")
            { changelogApprovalElement.innerHTML = InvGRNct + approvalStatus + InvCLEAR; }
            else // Handle unexpected values gracefully //
            { changelogApprovalElement.innerHTML = InvREDct + approvalStatus + InvCLEAR; }
        }

        // **Control "Approve Changelog" Button State**
        var approveChangelogButton = document.getElementById('approveChangelogButton');
        if (approveChangelogButton)
        {
            var isChangelogCheckEnabled = (custom_settings.CheckChangeLog === 'ENABLED');
            var changelogApprovalValue = custom_settings.FW_New_Update_Changelog_Approval;

            // Always display the button
            approveChangelogButton.style.display = 'inline-block';

            // Condition: Enable button only if
            // 1. Changelog Check is enabled
            // 2. Changelog Approval is neither empty nor "TBD"
            if (isChangelogCheckEnabled && changelogApprovalValue && changelogApprovalValue !== 'TBD')
            {
                approveChangelogButton.disabled = false; // Enable the button
                approveChangelogButton.style.opacity = '1'; // Fully opaque
                approveChangelogButton.style.cursor = 'pointer'; // Pointer cursor for enabled state
            }
            else
            {
                approveChangelogButton.disabled = true; // Disable the button
                approveChangelogButton.style.opacity = '0.5'; // Grayed out appearance
                approveChangelogButton.style.cursor = 'not-allowed'; // Indicate disabled state
            }
        }

        // **New Logic to Update "F/W Variant Detected" Based on "extendno"**
        var extendnoElement = document.getElementById('extendno');
        var extendno = extendnoElement ? extendnoElement.value.trim() : '';

        var fwVariantDetectedElement = document.getElementById('fwVariantDetected');

        if (fwVariantDetectedElement)
        {   // Case-insensitive check for "gnuton" //
            if (/gnuton/i.test(extendno))
            { fwVariantDetectedElement.innerHTML = InvCYNct + "Gnuton" + InvCLEAR; }
            else
            { fwVariantDetectedElement.innerHTML = InvCYNct + "Merlin" + InvCLEAR; }
        }
        else
        { console.error("Element with id 'fwVariantDetected' not found."); }

        // Call the visibility handler //
        handleROGFWBuildTypeVisibility();
    }
    else
    { console.error("Custom settings NOT loaded."); }
}

function get_conf_file()
{
        $.ajax({
            url: '/ext/MerlinAU/config.htm',
            dataType: 'text',
            error: function(xhr)
            {
                console.error("Failed to fetch config.htm:", xhr.statusText);
                setTimeout(get_conf_file, 1000); // Retry after 1 second
            },
            success: function(data)
            {
                // Tokenize the data while respecting quoted values
                var tokens = tokenize(data);

                // Iterate through tokens to extract key-value pairs
                for (var i = 0; i < tokens.length; i++)
                {
                    var token = tokens[i];

                    if (token.includes('='))
                    {
                        // Handle key=value format
                        var splitIndex = token.indexOf('=');
                        var key = token.substring(0, splitIndex).trim();
                        var value = token.substring(splitIndex + 1).trim();

                        // Remove surrounding quotes if present
                        if (value.startsWith('"') && value.endsWith('"')) {
                            value = value.substring(1, value.length - 1);
                        }

                        assignAjaxSetting(key, value);
                    }
                    else
                    {
                        // Handle key value format
                        var key = token.trim();
                        var value = '';

                        // Ensure there's a next token for the value
                        if (i + 1 < tokens.length)
                        {
                            value = tokens[i + 1].trim();

                            // Remove surrounding quotes if present
                            if (value.startsWith('"') && value.endsWith('"')) {
                                value = value.substring(1, value.length - 1);
                            }

                            assignAjaxSetting(key, value);
                            i++; // Skip the next token as it's already processed
                        }
                        else
                        {
                            console.warn(`No value found for key: ${key}`);
                        }
                    }
                }

                console.log("AJAX Custom Settings Loaded:", ajax_custom_settings);

                // Merge both server and AJAX settings
                custom_settings = Object.assign({}, server_custom_settings, ajax_custom_settings);
                console.log("Merged Custom Settings:", custom_settings);

                // Initialize fields with the merged settings
                initializeFields();
            }
        });
}

// Helper function to tokenize the input string, respecting quoted substrings //
function tokenize(input)
{
    var regex = /(?:[^\s"]+|"[^"]*")+/g;
    return input.match(regex) || [];
}

// Helper function to assign settings based on key
function assignAjaxSetting(key, value)
{
        // Normalize key to uppercase for case-insensitive comparison
        var keyUpper = key.toUpperCase();

        switch (true) {
            case keyUpper === 'FW_NEW_UPDATE_POSTPONEMENT_DAYS':
                ajax_custom_settings.FW_New_Update_Postponement_Days = value;
                break;

            case keyUpper === 'FW_NEW_UPDATE_EXPECTED_RUN_DATE':
                fwUpdateEstimatedRunDate = value;  // We don't want to save it the custom_settings; only as-is for displaying it.
                break;

            case keyUpper === 'FW_NEW_UPDATE_EMAIL_NOTIFICATION':
                ajax_custom_settings.FW_New_Update_EMail_Notification = convertToStatus(value);
                break;

            case keyUpper === 'FW_NEW_UPDATE_EMAIL_FORMATTYPE':
                ajax_custom_settings.FW_New_Update_EMail_FormatType = value;
                break;

            case keyUpper === 'FW_NEW_UPDATE_ZIP_DIRECTORY_PATH':
                ajax_custom_settings.FW_New_Update_ZIP_Directory_Path = value;
                break;

            case keyUpper === 'ALLOW_UPDATES_OVERVPN':
                ajax_custom_settings.Allow_Updates_OverVPN = convertToStatus(value);
                break;

            case keyUpper === 'FW_NEW_UPDATE_NOTIFICATION_VERS':
                FW_New_Update_Available = value.trim();
                break;

            case keyUpper === 'FW_NEW_UPDATE_EMAIL_CC_ADDRESS':
                ajax_custom_settings.FW_New_Update_EMail_CC_Address = value;
                break;

            case keyUpper === 'CHECKCHANGELOG':
                ajax_custom_settings.CheckChangeLog = convertToStatus(value);
                break;

            case keyUpper === 'FW_UPDATE_CHECK':
                ajax_custom_settings.FW_Update_Check = convertToStatus(value);
                break;

            case keyUpper === 'ALLOW_SCRIPT_AUTO_UPDATE':
                ajax_custom_settings.Allow_Script_Auto_Update = convertToStatus(value);
                break;

            case keyUpper === 'FW_NEW_UPDATE_CHANGELOG_APPROVAL':
                ajax_custom_settings.FW_New_Update_Changelog_Approval = value; // Store as-is for display
                break;

            case keyUpper === 'FW_ALLOW_BETA_PRODUCTION_UP':
                ajax_custom_settings.FW_Allow_Beta_Production_Up = convertToStatus(value);
                break;

            case keyUpper === 'FW_AUTO_BACKUPMON':
                ajax_custom_settings.FW_Auto_Backupmon = convertToStatus(value);
                break;

            case keyUpper === 'CREDENTIALS_BASE64':
                try {
                    var decoded = atob(value);
                    var password = decoded.split(':')[1] || '';
                    ajax_custom_settings.routerPassword = password;
                } catch (e) {
                    console.error("Error decoding credentials_base64:", e);
                }
                break;

            case keyUpper === 'ROGBUILD':
                ajax_custom_settings.FW_New_Update_ROGFWBuildType = (value === 'ENABLED') ? 'ROG' : 'Pure';
                break;


            case keyUpper === 'TUFBUILD':
                ajax_custom_settings.FW_New_Update_TUFWBuildType = (value === 'ENABLED') ? 'TUF' : 'Pure';
                break;

            case keyUpper === 'FW_NEW_UPDATE_NOTIFICATION_DATE':
                ajax_custom_settings.FW_New_Update_Notifications_Date = value;
                break;

            // Additional AJAX settings can be handled here

            default:
                // Optionally handle or log unknown settings
                break;
        }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-05] **/
/**----------------------------------------**/
// Helper function to set status with color //
function setStatus(elementId, statusValue)
{
    let element = document.getElementById(elementId);
    if (element)
    {
        switch (statusValue)
        {
            case 'ENABLED':
                element.innerHTML = InvGRNct + "Enabled" + InvCLEAR;
                break;
            case 'DISABLED':
                element.innerHTML = InvREDct + "Disabled" + InvCLEAR;
                break;
            case 'TBD':
                // Yellow or Magenta?? //
                element.innerHTML = InvYLWct + "TBD" + InvCLEAR; 
                break;
            default:
                // Fallback if some unexpected string appears //
                element.innerHTML = InvREDct + "Disabled" + InvCLEAR;
                break;
        }
    }
}

function SetCurrentPage()
{
    /* Set the proper return pages */
    document.form.next_page.value = window.location.pathname.substring(1);
    document.form.current_page.value = window.location.pathname.substring(1);
}

function convertToStatus(value)
{
        if (typeof value === 'boolean') return value ? 'ENABLED' : 'DISABLED';
        if (typeof value === 'string') {
            return (value.toLowerCase() === 'true' || value.toLowerCase() === 'enabled') ? 'ENABLED' : 'DISABLED';
        }
        return 'DISABLED';
}

function initial()
{
        SetCurrentPage();
        LoadCustomSettings();
        get_conf_file();
        show_menu();

        // Debugging iframe behavior
        var hiddenFrame = document.getElementById('hidden_frame');
        if (hiddenFrame) {
            hiddenFrame.onload = function () {
                console.log("Hidden frame loaded with server response.");
            };

            initializeCollapsibleSections();
        }
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-13] **/
/**----------------------------------------**/
function SaveActionsConfig()
{
    // Clear amng_custom for any existing content before saving
    document.getElementById('amng_custom').value = '';

    // Collect Action form-specific settings //
    var passwordStr = document.getElementById('routerPassword')?.value || '';
    var usernameElement = document.getElementById('http_username');
    var username = usernameElement ? usernameElement.value.trim() : 'admin';

    // Validate that username is not empty //
    if (!username)
    {
        console.error("HTTP username is missing.");
        alert("HTTP username is not set. Please contact your administrator.");
        return false;
    }
    if (!ValidatePasswordString (document.getElementById('routerPassword')))
    {
        alert('Validation failed. Please correct invalid value and try again.\n\n' + loginPassword.ErrorMsg());
        return false;
    }
    if (!ValidatePostponedDays (document.form.fwUpdatePostponement))
    {
        alert('Validation failed. Please correct invalid value and try again.\n\n' + fwPostponedDays.ErrorMsg());
        return false;
    }

    // Encode credentials in Base64 //
    var credentials = username + ':' + passwordStr;
    var encodedCredentials = btoa(credentials);

    // Collect only Action form-specific settings
    var action_settings =
    {
        credentials_base64: encodedCredentials,
        FW_New_Update_Postponement_Days: document.getElementById('fwUpdatePostponement')?.value || '0',
        CheckChangeLog: document.getElementById('changelogCheckEnabled').checked ? 'ENABLED' : 'DISABLED',
        FW_Update_Check: document.getElementById('FW_Update_Check').checked ? 'ENABLED' : 'DISABLED'
    };
    // Prefix only Action settings
    var prefixedActionSettings = prefixCustomSettings(action_settings, 'MerlinAU_');

    // ***** FIX BUG WHERE MerlinAU_FW_Auto_Backupmon is saved from the wrong button *****
    // ***** Only when the Advanced Options section is saved first, and then Actions Section is saved second *****
    var ADVANCED_KEYS = [
        "MerlinAU_FW_Auto_Backupmon",
        "MerlinAU_FW_Allow_Beta_Production_Up",
        "MerlinAU_FW_New_Update_ZIP_Directory_Path",
        "MerlinAU_FW_New_Update_EMail_Notification",
        "MerlinAU_FW_New_Update_EMail_FormatType",
        "MerlinAU_FW_New_Update_EMail_CC_Address",
        "MerlinAU_Allow_Updates_OverVPN",
        "MerlinAU_Allow_Script_Auto_Update",
        "MerlinAU_FW_New_Update_ROGFWBuildType",
        "MerlinAU_FW_New_Update_TUFWBuildType"
    ];
    ADVANCED_KEYS.forEach(function (key) {
        if (server_custom_settings.hasOwnProperty(key)) {
            delete server_custom_settings[key];
        }
    });

    // Merge Server Custom Settings and prefixed Action form settings //
    var updatedSettings = Object.assign({}, server_custom_settings, prefixedActionSettings);

    // Save merged settings to the hidden input field //
    document.getElementById('amng_custom').value = JSON.stringify(updatedSettings);

    // Apply the settings //
    document.form.action_script.value = 'start_MerlinAUconfig';
    document.form.action_wait.value = 10;
    showLoading();
    document.form.submit();
    console.log("Actions Config Form submitted with settings:", updatedSettings);
}

function SaveAdvancedConfig()
{
        // Clear amng_custom for any existing content before saving
        document.getElementById('amng_custom').value = '';

        // 1) F/W Update Email Notifications - only if not disabled
        let emailNotificationsEnabled = document.getElementById('emailNotificationsEnabled');
        let emailFormat = document.getElementById('emailFormat');
        let secondaryEmail = document.getElementById('secondaryEmail');

        if (emailNotificationsEnabled && !emailNotificationsEnabled.disabled) {
            // The box is enabled, so we save these fields
            advanced_settings.FW_New_Update_EMail_Notification = emailNotificationsEnabled.checked ? 'ENABLED' : 'DISABLED';
        }

        if (emailFormat && !emailFormat.disabled) {
            advanced_settings.FW_New_Update_EMail_FormatType = emailFormat.value || 'HTML';
        }

        if (secondaryEmail && !secondaryEmail.disabled) {
            advanced_settings.FW_New_Update_EMail_CC_Address = secondaryEmail.value || 'TBD';
        }

        // 2) F/W Update Directory - always saved (or up to your requirements)
        let fwUpdateDirectory = document.getElementById('fwUpdateDirectory');
        if (fwUpdateDirectory) {
            advanced_settings.FW_New_Update_ZIP_Directory_Path = fwUpdateDirectory.value || '/tmp/mnt/USB1';
        }

        // 3) Tailscale/ZeroTier VPN Access - only if not disabled
        let tailscaleVPNEnabled = document.getElementById('tailscaleVPNEnabled');
        if (tailscaleVPNEnabled && !tailscaleVPNEnabled.disabled) {
            advanced_settings.Allow_Updates_OverVPN = tailscaleVPNEnabled.checked ? 'ENABLED' : 'DISABLED';
        }

        // 4) Auto-Updates for Script - only if not disabled
        let autoUpdatesScriptEnabled = document.getElementById('autoUpdatesScriptEnabled');
        if (autoUpdatesScriptEnabled && !autoUpdatesScriptEnabled.disabled) {
            advanced_settings.Allow_Script_Auto_Update = autoUpdatesScriptEnabled.checked ? 'ENABLED' : 'DISABLED';
        }

        // 5) Beta-to-Release Updates - only if not disabled
        let betaToReleaseUpdatesEnabled = document.getElementById('betaToReleaseUpdatesEnabled');
        if (betaToReleaseUpdatesEnabled && !betaToReleaseUpdatesEnabled.disabled) {
            advanced_settings.FW_Allow_Beta_Production_Up = betaToReleaseUpdatesEnabled.checked ? 'ENABLED' : 'DISABLED';
        }

        // 6) Auto-Backup - only if not disabled
        let autobackupEnabled = document.getElementById('autobackupEnabled');
        if (autobackupEnabled && !autobackupEnabled.disabled) {
            advanced_settings.FW_Auto_Backupmon = autobackupEnabled.checked ? 'ENABLED' : 'DISABLED';
        }

        // 7) ROG/TUF F/W Build Type - handle conditional rows if visible
        let rogFWBuildRow = document.getElementById('rogFWBuildRow');
        let rogFWBuildType = document.getElementById('rogFWBuildType');
        if (rogFWBuildRow && rogFWBuildRow.style.display !== 'none' && rogFWBuildType) {
            advanced_settings.FW_New_Update_ROGFWBuildType = rogFWBuildType.value || 'ROG';
        }

        let tufFWBuildRow = document.getElementById('tuffFWBuildRow');
        let tuffFWBuildType = document.getElementById('tuffFWBuildType');
        if (tufFWBuildRow && tufFWBuildRow.style.display !== 'none' && tuffFWBuildType) {
            advanced_settings.FW_New_Update_TUFWBuildType = tuffFWBuildType.value || 'TUF';
        }

        // Prefix only Advanced settings
        var prefixedAdvancedSettings = prefixCustomSettings(advanced_settings, 'MerlinAU_');

        // Remove any action keys from server_custom_settings to avoid overwriting
        var ACTION_KEYS = [
            "MerlinAU_credentials_base64",
            "MerlinAU_FW_New_Update_Postponement_Days",
            "MerlinAU_CheckChangeLog",
            "MerlinAU_FW_Update_Check"
        ];
        ACTION_KEYS.forEach(function (key) {
            if (server_custom_settings.hasOwnProperty(key)) {
                delete server_custom_settings[key];
            }
        });

        // Merge Server Custom Settings and prefixed Advanced settings
        var updatedSettings = Object.assign({}, server_custom_settings, prefixedAdvancedSettings);

        // Save merged settings to the hidden input field
        document.getElementById('amng_custom').value = JSON.stringify(updatedSettings);

        // Apply the settings
        document.form.action_script.value = 'start_MerlinAUconfig';
        document.form.action_wait.value = 10;
        showLoading();
        document.form.submit();
        console.log("Advanced Config Form submitted with settings:", updatedSettings);
}

function Uninstall()
{
   console.log("Uninstalling MerlinAU...");

   if (!confirm("Are you sure you want to completely uninstall MerlinAU?"))
   { return; }

   document.form.action_script.value = 'start_MerlinAUuninstall';
   document.form.action_wait.value = 10;

   showLoading();
   document.form.submit();
}

function changelogApproval()
{
   console.log("Approving Changelog...");

   if (!confirm("Are you sure you want to approve this changelog?"))
   { return; }

   document.form.action_script.value = 'start_MerlinAUapprovechangelog';
   document.form.action_wait.value = 10;

   showLoading();
   document.form.submit();
}

function checkFirmwareUpdate()
{
    console.log("Initiating F/W Update Check...");

    if (!confirm("NOTE:\nIf you have no postponement days set or remaining, the firmware could flash NOW!\nThis means logging you out of the WebUI and rebooting the router.\nContinue to check for firmware updates now?"))
    { return; }

    document.form.action_script.value = 'start_MerlinAUcheckupdate';
    document.form.action_wait.value = 60;

    showLoading();
    document.form.submit();
}

// Function to get the first non-empty value from a list of element IDs
function getFirstNonEmptyValue(ids)
{
    for (var i = 0; i < ids.length; i++)
    {
        var elem = document.getElementById(ids[i]);
        if (elem)
        {
            var value = elem.value.trim();
            if (value.length > 0) { return value; }
        }
    }
    return "";
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-05] **/
/**----------------------------------------**/
// Function to format and display the Router IDs //
function formatRouterIDs()
{
    // Define the order of NVRAM keys to search for Model ID and Product ID
    var modelKeys = ["nvram_odmpid", "nvram_wps_modelnum", "nvram_model", "nvram_build_name"];
    var productKeys = ["nvram_productid", "nvram_build_name", "nvram_odmpid"];

    // Retrieve the first non-empty values //
    var MODEL_ID = getFirstNonEmptyValue(modelKeys);
    var PRODUCT_ID = getFirstNonEmptyValue(productKeys);

    // Convert MODEL_ID to uppercase for comparison //
    var MODEL_ID_UPPER = MODEL_ID.toUpperCase();

    // Determine FW_RouterModelID based on comparison //
    var FW_RouterModelID = "";
    if (PRODUCT_ID === MODEL_ID_UPPER)
    { FW_RouterModelID = InvCYNct + PRODUCT_ID + InvCLEAR; }
    else
    { FW_RouterModelID = InvCYNct + PRODUCT_ID + ' / ' + MODEL_ID + InvCLEAR; }

    var productModelCell = document.getElementById('firmwareProductModelID');
    if (productModelCell)
    { productModelCell.innerHTML = FW_RouterModelID; }

    // Update the consolidated 'firmver' hidden input //
    var firmverInput = document.getElementById('firmver');
    if (firmverInput)
    {  // Optionally strip HTML tags //
       firmverInput.value = stripHTML(FW_RouterModelID);
    }
}

// Optional: Function to strip HTML tags from a string (to store plain text in hidden input)
function stripHTML(html)
{
    var tmp = document.createElement("DIV");
    tmp.innerHTML = html;
    return tmp.textContent || tmp.innerText || "";
}

/**----------------------------------------**/
/** Modified by Martinski W. [2025-Jan-05] **/
/**----------------------------------------**/
// Function to format the Firmware Version Installed //
function formatFirmwareVersion()
{
    var fwVersionElement = document.getElementById('fwVersionInstalled');
    if (fwVersionElement)
    {
        var version = fwVersionElement.textContent.trim();
        var parts = version.split('.');
        if (parts.length >= 4)
        {
            // Combine the first four parts without dots
            var firstPart = parts.slice(0, 4).join('');
            // Combine the remaining parts with dots
            var remainingParts = parts.slice(4).join('.');
            // Construct the formatted version
            var formattedVersion = firstPart + '.' + remainingParts;
            // Update the table cell with the formatted version
            fwVersionElement.innerHTML = InvCYNct + formattedVersion + InvCLEAR;
        }
        else
        { console.warn("Unexpected firmware version format:", version); }
    }
    else
    { console.error("Element with id 'fwVersionInstalled' not found."); }
}

// Modify the existing DOMContentLoaded event listener to include the new function
document.addEventListener("DOMContentLoaded", function() {
    formatRouterIDs();
    formatFirmwareVersion(); // Call the new formatting function
});

function initializeCollapsibleSections()
{
        if (typeof jQuery !== 'undefined')
        {
            $('.collapsible-jquery').each(function() {
                // Ensure sections are expanded by default
                $(this).addClass('active');  // Add 'active' class to indicate expanded state
                $(this).next('tbody').show();  // Make sure content is visible

                // Add a cursor pointer for better UX
                $(this).css('cursor', 'pointer');

                // Toggle logic on click
                $(this).on('click', function() {
                    $(this).toggleClass('active');
                    $(this).next('tbody').slideToggle();
                });
            });
        } else {
            console.error("jQuery is not loaded. Collapsible sections will not work.");
        }
}
</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

<form method="post" name="form" action="start_apply.htm" target="hidden_frame">
<input type="hidden" name="action_script" value="start_MerlinAUconfig" />
<input type="hidden" name="current_page" value="" />
<input type="hidden" name="next_page" value="" />
<input type="hidden" name="modified" value="0" />
<input type="hidden" name="action_mode" value="apply" />
<input type="hidden" name="action_wait" value="90" />
<input type="hidden" name="first_time" value="">
<input type="hidden" id="http_username" value="<% nvram_get("http_username"); %>" />
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>" />
<!-- Consolidated firmver input -->
<input type="hidden" name="extendno" id="extendno" value="<% nvram_get("extendno"); %>" />
<input type="hidden" name="firmver" id="firmver" value="<% nvram_get('firmver'); %>.<% nvram_get('buildno'); %>.<% nvram_get('extendno'); %>" />
<input type="hidden" id="nvram_odmpid" value="<% nvram_get("odmpid"); %>" />
<input type="hidden" id="nvram_wps_modelnum" value="<% nvram_get("wps_modelnum"); %>" />
<input type="hidden" id="nvram_model" value="<% nvram_get("model"); %>" />
<input type="hidden" id="nvram_build_name" value="<% nvram_get("build_name"); %>" />
<input type="hidden" id="nvram_productid" value="<% nvram_get("productid"); %>" />
<input type="hidden" name="installedfirm" value="<% nvram_get("innerver"); %>" />
<input type="hidden" name="amng_custom" id="amng_custom" value="" />

<table class="content" cellpadding="0" cellspacing="0" style="margin:0 auto;">
<tr>
<td width="17">&nbsp;</td>
<td width="202" valign="top">
   <div id="mainMenu"></div>
   <div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>

<table width="98%" border="0" cellpadding="0" cellspacing="0">
<tr>
<td valign="top">
<table width="760px" cellpadding="4" cellspacing="0" class="FormTitle" style="height: 1169px;">
<tbody>
<tr style="background-color:#4D595D;">
<td valign="top">
<div>&nbsp;</div>
<div class="formfonttitle" style="text-align:center;">MerlinAU Dashboard v1.4.0</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
<div class="formfontdesc">This is the MerlinAU add-on integrated into the router WebUI.</div>
<div style="line-height:10px;">&nbsp;</div>

<!-- Parent Table to Arrange Firmware and Settings Status Side by Side -->
<table width="100%" cellpadding="0" cellspacing="0" style="border: none; background-color: transparent;">
<tr>
<!-- Firmware Status Column -->
<td valign="top" width="57%" style="padding-right: 5px;">
<!-- Firmware Status Section -->
<table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
<thead class="collapsible-jquery" id="firmwareStatusSection">
   <tr>
      <!-- Adjust colspan to match the number of internal tables -->
      <td colspan="2">Firmware Status (click to expand/collapse)</td>
   </tr>
</thead>
<tbody>
<tr>
<!-- First internal table in the first column -->
<td style="vertical-align: top; width: 50%;">
<table style="margin: 0; text-align: left; width: 100%; border: none;">
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Product/Model ID:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="firmwareProductModelID"></td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Variant Detected:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwVariantDetected">Unknown</td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Version Installed:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwVersionInstalled">
      <% nvram_get("firmver"); %>.<% nvram_get("buildno"); %>.<% nvram_get("extendno"); %>
   </td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Update Available:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwUpdateAvailable">NONE FOUND</td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>Estimated Update Time:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwUpdateEstimatedRunDate">TBD</td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>Last Notificiation Date:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwNotificationsDate">TBD</td>
</tr>
<tr>
   <td style="padding: 4px; width: 165px;"><strong>F/W Update Check:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="fwUpdateCheckStatus">Disabled</td>
</tr>
</table></td></tr></tbody></table></td>

<!-- Settings Status Column -->
<td valign="top" width="43%" style="padding-left: 5px;">
<!-- Settings Status Section -->
<table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
<thead class="collapsible-jquery" id="settingsStatusSection">
   <tr>
      <!-- Adjust colspan to match the number of internal tables -->
      <td colspan="2">Settings Status (click to expand/collapse)</td>
   </tr>
</thead>
<tbody>
<tr>
<!-- Second internal table in the second column -->
<td style="vertical-align: top; width: 50%;">
<table style="margin: 0; text-align: left; width: 100%; border: none;">
<tr>
   <td style="padding: 4px; width: 175px;"><strong>Changelog Approval:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="changelogApproval">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 175px;"><strong>Changelog Check:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="changelogCheckStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 175px;"><strong>Beta-to-Release Updates:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="betaToReleaseUpdatesStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 175px;"><strong>Tailscale VPN Access:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="tailscaleVPNAccessStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 175px;"><strong>Auto-Backup Enabled:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="autobackupEnabledStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 175px;"><strong>Auto-Updates for Script:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="autoUpdatesScriptEnabledStatus">Disabled</td>
</tr>
<tr>
   <td style="padding: 4px; width: 175px;"><strong>Email-Notifications:</strong></td>
   <td style="padding: 4px; font-weight: bolder;" id="emailNotificationsStatus">Disabled</td>
</tr>
</table></td></tr></tbody></table></td></tr></table>

<div style="line-height:10px;">&nbsp;</div>

<!-- Actions Section -->
<table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
<thead class="collapsible-jquery" id="actionsSection">
   <tr><td colspan="2">Actions (click to expand/collapse)</td></tr>
</thead>
<tbody><tr><td colspan="2">
<div style="text-align: center; margin-top: 10px;">
<table width="100%" border="0" cellpadding="10" cellspacing="0" style="table-layout: fixed; border-collapse: collapse; background-color: transparent;">
<colgroup>
   <col style="width: 33%;" />
   <col style="width: 33%;" />
   <col style="width: 33%;" />
</colgroup>
<tr>
<td style="text-align: right; border: none;">
   <input type="submit" onclick="checkFirmwareUpdate(); return false;" value="F/W Update Check" class="button_gen savebutton" name="button">
</td>
<td style="text-align: center; border: none;" id="approveChangelogCell">
   <input type="submit" id="approveChangelogButton" onclick="changelogApproval(); return false;" value="Approve Changelog" class="button_gen savebutton" name="button">
</td>
<td style="text-align: left; border: none;">
   <input type="submit" onclick="Uninstall(); return false;" value="Uninstall" class="button_gen savebutton" name="button">
</td>
</tr>
</table>
</div>
<form id="actionsForm">
<table width="100%" border="0" cellpadding="5" cellspacing="5" style="table-layout: fixed;" class="FormTable SettingsTable">
<colgroup>
   <col style="width: 50%;" />
   <col style="width: 50%;" />
</colgroup>
<tr>
   <td style="text-align: left;">
     <label for="routerPassword">Router Login Password</label>
   </td>
   <td>
      <div style="display: inline-block;">
         <input
           type="password"
           id="routerPassword"
           name="routerPassword"
           placeholder="Enter password"
           style="width: 278px; display: inline-block;"
           maxlength="64"
           onKeyPress="return validator.isString(this, event)"
           onblur="ValidatePasswordString(this)"
           onkeyup="ValidatePasswordString(this)"
         />
         <div
             id="eyeToggle"
             onclick="togglePassword();"
             style="
               position: absolute;
               display: inline-block; 
               margin-left: 5px;
               vertical-align: middle;
               width:24px; height:24px; 
               background:url('/images/icon-visible@2x.png') no-repeat center;
               background-size: contain;
               cursor: pointer;"
         ></div>
      </div>
   </td>
</tr>
<tr>
   <td style="text-align: left;"><label for="FW_Update_Check">Enable F/W Update Check</label></td>
   <td><input type="checkbox" id="FW_Update_Check" name="FW_Update_Check" /></td>
</tr>
<tr>
   <td style="text-align: left;">
   <label id="fwUpdatePostponementLabel" for="fwUpdatePostponement">F/W Update Postponement</label>
   </td>
   <td class="settingvalue">
   <input autocomplete="off" type="text" id="fwUpdatePostponement" name="fwUpdatePostponement" style="width: 15%;"
     maxlength="3"
     onKeyPress="return validator.isNumber(this,event)"
     onblur="ValidatePostponedDays(this);FormatNumericSetting(this)"
     onkeyup="ValidatePostponedDays(this)" />
   </td>
</tr>
<tr>
   <td style="text-align: left;"><label for="changelogCheckEnabled">Enable Changelog Check</label></td>
   <td><input type="checkbox" id="changelogCheckEnabled" name="changelogCheckEnabled" /></td>
</tr>
</table>
<div style="text-align: center; margin-top: 10px;">
   <input type="submit" onclick="return SaveActionsConfig();" value="Save" class="button_gen savebutton" name="button">
</div>
</form>
</td>
</tr>
</tbody>
</table>

<div style="line-height:10px;">&nbsp;</div>

<!-- Advanced Options Section -->
<table width="100%" cellpadding="4" cellspacing="0" class="FormTable">
<thead class="collapsible-jquery" id="advancedOptionsSection">
   <tr><td colspan="2">Advanced Options (click to expand/collapse)</td></tr>
</thead>
<tbody>
<tr>
<td colspan="2">
<form id="advancedOptionsForm">
<table width="100%" border="0" cellpadding="5" cellspacing="5" style="table-layout: fixed;">
<colgroup>
   <col style="width: 50%;" />
   <col style="width: 50%;" />
</colgroup>
<tr>
   <td style="text-align: left;"><label for="fwUpdateDirectory">Set Directory for F/W Updates</label></td>
   <td><input type="text" id="fwUpdateDirectory" name="fwUpdateDirectory" style="width: 275px;" /></td>
</tr>
<tr>
   <td style="text-align: left;"><label for="betaToReleaseUpdatesEnabled">Beta-to-Release Updates</label></td>
   <td><input type="checkbox" id="betaToReleaseUpdatesEnabled" name="betaToReleaseUpdatesEnabled" /></td>
</tr>
<tr>
   <td style="text-align: left;"><label for="tailscaleVPNEnabled">Tailscale/ZeroTier VPN Access</label></td>
   <td><input type="checkbox" id="tailscaleVPNEnabled" name="tailscaleVPNEnabled" /></td>
</tr>
<tr>
   <td style="text-align: left;"><label for="autobackupEnabled">Enable Auto-Backups</label></td>
   <td><input type="checkbox" id="autobackupEnabled" name="autobackupEnabled" /></td>
</tr>
<tr>
   <td style="text-align: left;"><label for="autoUpdatesScriptEnabled">Auto-Updates for Script</label></td>
   <td><input type="checkbox" id="autoUpdatesScriptEnabled" name="autoUpdatesScriptEnabled" /></td>
</tr>
<tr id="rogFWBuildRow">
   <td style="text-align: left;"><label for="rogFWBuildType">ROG F/W Build Type</label></td>
   <td>
      <select id="rogFWBuildType" name="rogFWBuildType" style="width: 20%;">
         <option value="ROG">ROG</option>
         <option value="Pure">Pure</option>
      </select>
   </td>
</tr>
<tr id="tuffFWBuildRow">
   <td style="text-align: left;"><label for="tuffFWBuildType">TUF F/W Build Type</label></td>
   <td>
      <select id="tuffFWBuildType" name="tuffFWBuildType" style="width: 20%;">
         <option value="TUF">TUF</option>
         <option value="Pure">Pure</option>
      </select>
   </td>
</tr>
<tr>
   <td style="text-align: left;"><label for="emailNotificationsEnabled">Enable F/W Update Email Notifications</label></td>
   <td><input type="checkbox" id="emailNotificationsEnabled" name="emailNotificationsEnabled" /></td>
</tr>
<tr>
   <td style="text-align: left;"><label for="emailFormat">Email Format</label></td>
   <td>
      <select id="emailFormat" name="emailFormat" style="width: 28%;">
         <option value="HTML">HTML</option>
         <option value="PlainText">Plain Text</option>
      </select>
   </td>
</tr>
<tr>
   <td style="text-align: left;"><label for="secondaryEmail">Secondary Email for Notifications</label></td>
   <td><input type="email" id="secondaryEmail" name="secondaryEmail" style="width: 275px;" /></td>
</tr>
</table>
<div style="text-align: center; margin-top: 10px;">
   <input type="submit" onclick="SaveAdvancedConfig(); return false;" value="Save" class="button_gen savebutton" name="button">
</div>
</form></td></tr></tbody></table>
<div style="margin-top:10px;text-align:center;">MerlinAU v1.4.0 by ExtremeFiretop &amp; Martinski W.</div>
</td></tr></tbody></table></td></tr></table></td>
<td width="10"></td>
</tr></table></form>
<div id="footer"></div>
</body>
</html>
