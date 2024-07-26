#!/bin/bash

# export all the required varibles
source ~/ocs-upi-kvm/scripts/individual-test-run/rerun.config

#funtion for - fetch data before executing the test cases
fetch_data(){

    while IFS= read -r T
    do
    if ! $UI_TEST ; then
    #skip UI test
    str=$(echo "$T" | grep -Eo "/ui/")
	if [ $? -eq 0 ]
        then
            echo $T | sed "s/$1/SKIPPED/" | tee -a $BEFORE_TEST
            #delete Skipped test from overall summary
             escaped_pattern=$(echo "$T" | sed 's/[[]/\\[/g; s/[]]/\\]/g; s/\//\\\//g')
             sed -i "/$escaped_pattern$/d" $OVERALL_TEST_SUMMARY
             #skip count before test
            ((SKIPPED++))

        else
            echo "$T" | tee -a "$BEFORE_TEST"
            (("$1"++))
    fi

    else
        echo "$T" | tee -a "$BEFORE_TEST"
        (("$1"++))
    fi
    done < <(cat < "$FILE_PATH$FILENAME" | grep "^$1[[:space:]]\+" | awk -F '::' '{print $NF " " $0}' | sort | awk '{print $2 " "  $3}' | uniq)
}

#funtion for - run the test cases
run_test_case()
{
    #change the namespace
    oc project openshift-storage

    # activate virtual env.
    source ~/venv/bin/activate

    # create directory
    mkdir -p "$LOG_DIR"

    #read test cases from file
    while IFS= read -r TEST_CASE; do
        #ceph health and storagecluster phase check
        ceph_status=$(oc get cephcluster | grep -Eo "HEALTH_OK")
        storage_status=$(oc get storagecluster | grep -Eo "Ready")
        if [ "$ceph_status" == "HEALTH_OK" ] && [ "$storage_status" == "Ready" ]; then
            if ! $UI_TEST ; then
                #skip UI test
                str=$(echo "$TEST_CASE" | grep -Eo "/ui/")
                if [ $? -eq 0 ]; then
                    echo "Following failure is UI related and ignored"
                    continue
                fi
            else
                #extract test name for log filename
                LOG_FILE_NAME=$(awk -F '::' '{print $3}'<<<"$TEST_CASE")
                #change directory
                cd ~/ocs-upi-kvm/src/ocs-ci/
                #run test cases
                nohup run-ci -m "tier$TIER_NO" --ocs-version $OCS_VERSION --ocsci-conf=conf/ocsci/production_powervs_upi.yaml --ocsci-conf conf/ocsci/lso_enable_rotational_disks.yaml --ocsci-conf /root/ocs-ci-conf.yaml --cluster-name "ocstest" --cluster-path /root/ --collect-logs "$TEST_CASE" | tee "$LOG_DIR$LOG_FILE_NAME.log" 2>&1
            fi
        else
            if [ "$ceph_status" != "HEALTH_OK" ]; then
                echo "ceph health is not HEALTH_OK"
                #execute ceph health script
                bash $CEPH_HEALTH_SCRIPT
                echo "sleep 5m"
                sleep 5m
            fi
            if [ "$storage_status" != "Ready" ]; then
                echo "storage cluster is not Ready."
                echo "sleep 5m"
                sleep 5m
            fi
        fi
    done < <(cat < "$FILE_PATH$FILENAME" | grep "^$1[[:space:]]\+" | awk '{print $2}' | sort | uniq)
}

#funtion for - test summary 
test_summary() {
    if [ -d "$LOG_DIR" ]; then     
        # LOOP to fetch all log files in log dir
        for logfile in "$LOG_DIR"*.log; do
           temp=$1
           #check passed test cases
            if [[ $(tail -n 2 $logfile | grep -o passed) == "passed" ]]; then
                keyword=$(echo "$logfile" | awk -F "/" '{print $NF}' | awk -F "." '{print $1}')
                ptc=$(grep -i -F $keyword $logfile | tail -n 1)
                echo "PASSED $ptc" | tee -a "$INDIVIDUAL_TEST_SUMMARY"
                #pass count for summary
                ((PASS++))
                #delete passed test case from overall summary
                escaped_pattern=$(echo "$temp $ptc" | sed 's/[[]/\\[/g; s/[]]/\\]/g; s/\//\\\//g')
                sed -i "/$escaped_pattern$/d" $OVERALL_TEST_SUMMARY
            #check failed test cases
            elif [[ $(tail -n 2 $logfile | grep -o failed) == "failed" ]]; then
                tail -n 2 $logfile | grep -v -B 1 failed | tee -a "$INDIVIDUAL_TEST_SUMMARY"
                #fail count for summary
                ((FAIL++))
            #if not pass or fail found then considered as skipped test
            else
                keyword=$(echo "$logfile" | awk -F "/" '{print $NF}' | awk -F "." '{print $1}')
                stc=$(grep -i -F $keyword $logfile | tail -n 1)
                echo "SKIPPED $stc" | tee -a "$INDIVIDUAL_TEST_SUMMARY"
                #delete sipped test case from overall summary
                escaped_pattern=$(echo "$temp $stc" | sed 's/[[]/\\[/g; s/[]]/\\]/g; s/\//\\\//g')
                sed -i "/$escaped_pattern$/d" $OVERALL_TEST_SUMMARY
                #skip count for overall summary
                ((SKIP++))
            fi
        done
                #fetch overall counts from overall test summary file
                sum_str=$(grep "^= " $OVERALL_TEST_SUMMARY)
                #extract the counts
                tf=$(grep "^= " $OVERALL_TEST_SUMMARY | awk '{print $2}')
                tp=$(grep "^= " $OVERALL_TEST_SUMMARY | awk '{print $4}')
                ts=$(grep "^= " $OVERALL_TEST_SUMMARY | awk '{print $6}')
                te=$(grep "^= " $OVERALL_TEST_SUMMARY | awk '{print $12}')
                #calculate the counts
                ltf=$(($tf - $PASS - $SKIP - $SKIPPED))
                ltp=$(($tp + $PASS))
                lts=$(($ts + $SKIP + $SKIPPED))
                lte=$(($te - $PASS))
                #delete the tier test counts from overall test summray file
                sed -i "\|^$sum_str\$|d" $OVERALL_TEST_SUMMARY
                #modify the counts
                sum_str=$(echo $sum_str | sed "s/\b$tf\b/$ltf/g")
                sum_str=$(echo $sum_str | sed "s/\b$tp\b/$ltp/g")
                sum_str=$(echo $sum_str | sed "s/\b$ts\b/$lts/g")
                sum_str=$(echo $sum_str | sed "s/\b$te\b/$lte/g")
                #add the counts line
                echo $sum_str >> $OVERALL_TEST_SUMMARY
        sed -i "1i =========================== short test summary info ============================" $OVERALL_TEST_SUMMARY
        echo "=======================$FAIL failed, $PASS passed, $SKIP skipped =========================" | tee -a "$INDIVIDUAL_TEST_SUMMARY"
    # exit if logs directory not exist.
    else
        echo "$LOG_DIR does not exist."
    fi
}

fld=FAILED
#variabl used when ERROR test enables
err=ERROR
#check file exits or not
if [ ! -f "$FILE_PATH$FILENAME" ]; then
    echo "$FILE_PATH$FILENAME file not exists"
    exit 1

# collect the data before executing test cases
else
    #generate the overall test summary file 
    >$OVERALL_TEST_SUMMARY
        echo "=========================== short test summary info ============================" | tee "$INDIVIDUAL_TEST_SUMMARY"

        line_number=$(grep -n "short test summary info" $FILE_PATH$FILENAME | cut -d: -f1 | head -n 1)
                if [ -n "$line_number" ]; then
                    total_lines=$(wc --l <"$FILE_PATH$FILENAME")
                    while IFS= read -r LINE; do
                       echo $LINE >> "$OVERALL_TEST_SUMMARY"
                    done < <(tail -n +$((line_number + 1)) $FILE_PATH$FILENAME | head -n $(($total_lines - $line_number - 4)))
                fi
    echo "===============================Failed test cases from log file $FILE_PATH$FILENAME============================" | tee "$BEFORE_TEST"
    
    # execute fetch date for FAILED
    fetch_data $fld
    # execute fetch data for ERROR
    if $ERROR_TEST ; then
            fetch_data $err
    fi
    echo "============================$FAILED Failed, $ERROR Errors, $SKIPPED skipped=========================" | tee -a  "$BEFORE_TEST"
fi
    # execute run test for FAILED
    run_test_case $fld
    # execute run test for ERROR
    if $ERROR_TEST ; then
        run_test_case $err
    fi
    # execute test summary for FAILED 
    test_summary $fld
    if $ERROR_TEST ; then
        # execute test summary for ERROR
        test_summary $err
    fi
 
