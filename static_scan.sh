#!/usr/bin/env bash


APPSCAN_APP_ID=${APPSCAN_APP_ID:-"266048bc-1695-e711-80ba-002324b5f40c"}
APPSCAN_SCAN_NAME="catalog-api"
APPSCAN_URL="https://ui.appscan.ibmcloud.com/AsoCUI/serviceui/main/myapps/oneapp/$APPSCAN_APP_ID/scans"


# install necessary features
echo ""
echo "Setting up prerequisites for IBM Security Static Analyzer.  This will likely take several minutes"
echo "enabling i386 architechture"
sudo dpkg --add-architecture i386 >/dev/null 2>&1
sudo apt-get update >/dev/null 2>&1
echo "installing i386 libraries"
sudo apt-get install -y libc6:i386 libc6-i686 g++-multilib >/dev/null 2>&1

echo "installing bc"
sudo apt-get install -y bc >/dev/null 2>&1
echo "installing unzip"
sudo apt-get install -y unzip >/dev/null 2>&1
echo "installing grunt-idra3"
npm install -g grunt-idra3 &>/dev/null
echo "done installing prereqs"
echo ""


cur_dir=`pwd`
cd ..


wget https://appscan.ibmcloud.com/api/SCX/StaticAnalyzer/SAClientUtil?os=linux -O SAClientUtil.zip -o /dev/null
unzip -o -qq SAClientUtil.zip


if [ $? -eq 9 ]; then
    echo "Unable to download SAClient"
    exit 1
fi


cd `ls -d SAClient*/`
export APPSCAN_INSTALL_DIR=`pwd`
cd $cur_dir
export PATH=$APPSCAN_INSTALL_DIR/bin:$PATH
export PATH=/opt/IBM/node-v4.2/bin:$PATH


#############################
#export PATH=$PATH:~/Downloads/SAClientUtil.6.0.1142/bin
#echo $PATH
#############################


appscan.sh version
appscan.sh api_login -P $APPSCAN_KEY_SECRET -u $APPSCAN_KEY_ID -persist
appscan.sh prepare -v -X -n $APPSCAN_SCAN_NAME
output=$(appscan.sh queue_analysis -a $APPSCAN_APP_ID -f "$APPSCAN_SCAN_NAME.irx" -n $APPSCAN_SCAN_NAME)


#
# Capture the job_id
while read -r line; do
    if [ "$line" = "100% transferred" ]; then
        echo "$line"
        continue
    else
        job_id="$line"
    fi
done <<< "$output"


echo ""
echo "IBM Application Security on Cloud UI: $APPSCAN_URL"
echo ""


#
# Wait for scan to complete.  Then push results to DLMS.
while true; do
    status=$(appscan.sh status -i $job_id)

    # Possible status states
    #  0 = Pending
    #  1 = Starting
    #  2 = Running
    #  3 = FinishedRunning                - True
    #  4 = FinishedRunningWithErrors      - True
    #  5 = PendingSupport
    #  6 = Ready                          - True
    #  7 = ReadyIncomplete                - True
    #  8 = FailedToScan                   - True
    #  9 = ManuallyStopped                - True
    #  10 = None                          - True
    #  11 = Initiating
    #  12 = MissingConfiguration          - True
    #  13 = PossibleMissingConfiguration  - True

    echo `date` "- Status for scan ($job_id): $status"

    if [ "$status" = "FinishedRunning" ] || [ "$status" = "FinishedRunningWithErrors" ] || \
       [ "$status" = "Ready" ] || [ "$status" = "ReadyIncomplete" ] || \
       [ "$status" = "FailedToScan" ] || [ "$status" = "ManuallyStopped" ] || \
       [ "$status" = "None" ] || [ "$status" = "MissingConfiguration" ] || \
       [ "$status" = "PossibleMissingConfiguration" ]
    then
        appscan.sh get_result -i $job_id -d "$APPSCAN_SCAN_NAME.zip" -t zip
        unzip "$APPSCAN_SCAN_NAME.zip" -d "$APPSCAN_SCAN_NAME"
        break
    fi

    sleep 180

done