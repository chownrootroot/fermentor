#!/bin/bash

# Config
iGPIOOutRelay=2
iGPIOInTemp=3
sFallbackTemp=8

sSPFile="/home/pi/git/fermentor/setpoint.var"
sPVFile="/home/pi/git/fermentor/processval.var"
sFallbackFile="/home/pi/git/fermentor/fallback.var"
sScheduleFile="/home/pi/git/fermentor/schedule.csv"
sLogFile="/home/pi/git/fermentor/logfile.log"
sStatusFile="/home/pi/git/fermentor/status.log"
sBannerFile="/home/pi/git/fermentor/banner"
sTempBusPath="/sys/bus/w1/devices/28-041753e4e2ff/w1_slave"
iHyst=300
iCycleFreq=60

iSwitchOn=
iSwitchOff=
sScheduleDay=
sScheduleSelSP=
iScriptStarted=1

# Activate GPIO
if [ ! -d "/sys/class/gpio/gpio${iGPIOOutRelay}" ]; then
    printf "%s\n" ${iGPIOOutRelay} > /sys/class/gpio/export
    printf "%s\n" "out" > /sys/class/gpio/gpio${iGPIOOutRelay}/direction
fi

# Create file for PV
if [ ! -f "${sPVFile}" ]; then
    printf "%s\n" "1" > ${sPVFile}
fi

# Print start to log
sTimestamp=$(date +%Y%m%d" "%H:%M:%S)
if [ ! -f "${sLogFile}" ]; then
    printf "%s\n" "Time;PV;SP;PowerOn;Fallback;Comment" > ${sLogFile}
fi

# Main loop
while [ 1 -eq 1 ]; do

    sTimestamp=$(date +%Y%m%d" "%H:%M:%S)
    sDay=$(date +%Y%m%d)

    # Check schedule
    printf "%s\n" ${sFallbackTemp} > ${sSPFile}
    touch ${sFallbackFile}
    cat ${sScheduleFile} | while read line; do
        sScheduleDay=$(printf "%s\n" ${line} | awk -F ";" '{printf "%s\n", $1}')
	if [ "${sScheduleDay}" = "${sDay}" ]; then
	    sScheduleSelSP=$(printf "%s\n" ${line} | awk -F ";" '{printf "%s\n", $2}')
	    printf "%s\n" ${sScheduleSelSP} > ${sSPFile}
	    rm ${sFallbackFile}
	    break
	fi
    done

    # Fallback active
    if [ -f "${sFallbackFile}" ]; then
        iFallbackActive=1
    else
        iFallbackActive=0
    fi

    # Read from w1 bus
    cat ${sTempBusPath} | awk -F "t=" '{printf "%s", $2}' > ${sPVFile}

    # Read files
    iSP=$(cat ${sSPFile})
    iPV=$(cat ${sPVFile})

    # Set triggers
    iSwitchOn=$((${iSP}+${iHyst}))
    iSwitchOff=${iSP}

    # Evaluate temperature
    if [ "${iPV}" -gt "${iSwitchOn}" ]; then
        iPowerOn=1
    elif [ "${iPV}" -lt "${iSwitchOff}" ]; then
        iPowerOn=0
    fi

    # Control output
    if [ "${iPowerOn}" = "1" ]; then
        echo 1 > /sys/class/gpio/gpio${iGPIOOutRelay}/value
    else
        echo 0 > /sys/class/gpio/gpio${iGPIOOutRelay}/value
    fi

    # Log file
    if [ "${iScriptStarted}" = "1" ]; then
        printf "%s;%s;%s;%s;%s;%s\n" "${sTimestamp}" "${iPV}" "${iSP}" "${iPowerOn}" "${iFallbackActive}" "Script started" >> ${sLogFile}
        iScriptStarted=0
    else
        printf "%s;%s;%s;%s;%s;\n" "${sTimestamp}" "${iPV}" "${iSP}" "${iPowerOn}" "${iFallbackActive}" >> ${sLogFile}
    fi

    # Print status
    cat ${sBannerFile} > ${sStatusFile}
    printf "%-20s%-10s\n" "Last cycle:" "${sTimestamp}" >> ${sStatusFile}
    printf "%-20s%10s\n" "Temperature:" "${iPV}" >> ${sStatusFile}
    printf "%-20s%10s\n" "Setpoint:" "${iSP}" >> ${sStatusFile}
    printf "%-20s%10s\n" "Switch on @:" "${iSwitchOn}" >> ${sStatusFile}
    printf "%-20s%10s\n" "Switch off @:" "${iSwitchOff}" >> ${sStatusFile}
    printf "%-20s%10s\n" "Relay status:" "${iPowerOn}" >> ${sStatusFile}
    printf "%-20s%10s\n" "Fallback active:" "${iFallbackActive}" >> ${sStatusFile}

    sleep ${iCycleFreq}
done

exit 0
