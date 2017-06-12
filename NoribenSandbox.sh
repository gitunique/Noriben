#!/bin/bash
#Noriben Sandbox Automation Script
#Responsible for:
#* Copying malware into a known VM
#* Running malware sample
#* Copying off results
#
#Ensure you set the environment variables below to match your system
NORIBEN_DEBUG=""
DELAY=10
VMRUN=~/vmrun
VMX=~/Documents/win7victim/Windows\ 7\ x64.vmx
VM_SNAPSHOT="baseline"
VM_USER=user
VM_PASS=password
NORIBEN_PATH="C:\\Users\\user\\Desktop\\tools\\Noriben\\Noriben.py"
ZIP_PATH="C:\\gnu32\\bin\\7z.exe"
LOG_PATH="C:\\Noriben_Logs"

# On a victim system configured with sysmon i
# (I use sysmon with the SwiftOnSecurity config)
DUMP_SYSMON="YES"

> /tmp/malware.bat

MALWAREFILE=$1
if [ ! -f $1 ]; then
    echo "Please provide executable filename as an argument."
    echo "For example:"
    echo "$0 ~/malware/ef8188aa1dfa2ab07af527bab6c8baf7"
    exit
fi

CMD_ARGS=$2

FILENAME=$(basename $MALWAREFILE)
if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMRUN" -T ws revertToSnapshot "$VMX" $VM_SNAPSHOT; fi
"$VMRUN" -T ws revertToSnapshot "$VMX" $VM_SNAPSHOT

if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMRUN" -T ws start "$VMX"; fi
"$VMRUN" -T ws start "$VMX"

if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMRUN" -gu $VM_USER  -gp $VM_PASS copyFileFromHostToGuest "$VMX" "$MALWAREFILE" C:\\Malware\\malware.exe; fi
"$VMRUN" -gu $VM_USER  -gp $VM_PASS copyFileFromHostToGuest "$VMX" "$MALWAREFILE" C:\\Malware\\malware.exe

if [ ! -z $CMD_ARGS ]; then echo "C:\\Malware\\malware.exe $CMD_ARGS" > /tmp/malware.bat; "$VMRUN" -gu $VM_USER  -gp $VM_PASS copyFileFromHostToGuest "$VMX" "/tmp/malware.bat" C:\\Malware\\malware.bat; fi

if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMRUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive "$NORIBEN_PATH" -d -t $DELAY --cmd "C:\\Malware\\Malware.exe" --output "$LOG_PATH"; fi

if [ ! -z $CMD_ARGS ]; then 
    "$VMRUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive "C:\\Users\\user\\AppData\Local\\Programs\\Python\\Python36\\python.exe" "$NORIBEN_PATH" -d -t $DELAY --cmd "C:\\Malware\\Malware.bat" --output "$LOG_PATH" 
else 
    "$VMRUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive "C:\\Users\\user\\AppData\Local\\Programs\\Python\\Python36\\python.exe" "$NORIBEN_PATH" -d -t $DELAY --cmd "C:\\Malware\\Malware.exe" --output "$LOG_PATH" 
fi

if [ $? -gt 0 ]; then
    echo "[!] File did not execute in VM correctly."
    exit
fi

# Use Windows evtutil to dump sysmon logs for collection
if [ ! -z $DUMP_SYSMON ]; then "$VMRUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive "c:\\windows\\system32\\wevtutil.exe" epl Microsoft-Windows-Sysmon/Operational "$LOG_PATH\\sysmon.evtx"; fi 

if [ ! -z $NORIBEN_DEBUG ]; then echo "$VMRUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive "$ZIP_PATH" -j C:\\NoribenReports.zip "$LOG_PATH\\*.*"; fi
"$VMRUN" -T ws -gu $VM_USER -gp $VM_PASS runProgramInGuest "$VMX" -activeWindow -interactive "$ZIP_PATH" a "C:\\NoribenReports.7z" "$LOG_PATH\\*.*"
if [ $? -eq 12 ]; then
    echo "[!] ERROR: No files found in Noriben output folder to ZIP."
    exit
fi
"$VMRUN" -gu $VM_USER -gp $VM_PASS copyFileFromGuestToHost "$VMX" "C:\\NoribenReports.7z" $PWD/NoribenReports_$FILENAME.7z


