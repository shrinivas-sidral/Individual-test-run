#!/bin/bash

# export all the required varibles
source ~/ocs-upi-kvm/scripts/Individual-test-run/rerun.config

#funtion for - fetch data before executing the test cases
fetch_data(){

    while IFS= read -r T
    do

    if ! $UI_TEST ; then

        str=$(echo "$T" | awk -F "/" '{print $2}')
	str1=$(echo "$T" | awk -F "/" '{print $4}')
	if [ $str == "ui" ] || [ $str1 == "ui" ]
        then
            echo $T | sed "s/$1/SKIPPED/" | tee -a $FILE_PATH$BEFORE_TEST
            ((SKIPPED++))
        else
            echo "$T" | tee -a "$FILE_PATH$BEFORE_TEST"
            (("$1"++))
    fi

    else
        echo "$T" | tee -a "$FILE_PATH$BEFORE_TEST"
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
    mkdir -p "$FILE_PATH$LOG_DIR"

    #read test cases from file
    while IFS= read -r TEST_CASE; do
        ceph_status=$(oc get cephcluster | grep -Eo "HEALTH_OK")
        storage_status=$(oc get storagecluster | grep -Eo "Ready")

        if [ "$ceph_status" == "HEALTH_OK" ] && [ "$storage_status" == "Ready" ]; then
            str1=$(echo "$TEST_CASE" | awk -F "/" '{print $2}')

            if [[ $str1 == "ui" ]]
            then
                echo "Following failure is UI related and ignored"
                continue
            else
                
                LOG_FILE_NAME=$(awk -F '::' '{print $3}'<<<"$TEST_CASE")
                #change directory
                cd ~/ocs-upi-kvm/src/ocs-ci/
                #run test cases
                nohup run-ci -m "tier$TIER_NO" --ocs-version $OCS_VERSION --ocsci-conf=conf/ocsci/production_powervs_upi.yaml --ocsci-conf conf/ocsci/lso_enable_rotational_disks.yaml --ocsci-conf /root/ocs-ci-conf.yaml --cluster-name "ocstest" --cluster-path /root/ --collect-logs "$TEST_CASE" | tee ~/ocs-upi-kvm/scripts/rerun-logs/"$LOG_FILE_NAME".log 2>&1
            fi
        else
            echo "Current ceph health status : $ceph_status."
            echo "Current storage cluter phase: $storage_status."
            echo "Sleep 5 sec"
            sleep 5
            
        fi
    done < <(cat < "$FILE_PATH$FILENAME" | grep "^$1[[:space:]]\+" | awk '{print $2}' | sort | uniq)
}

#funtion for - test summary 
test_summary() {
    if [ -d "$FILE_PATH$LOG_DIR" ]; then
    >$FILE_PATH$OVERALL_TEST_SUMMARY
        echo "=========================== short test summary info ============================" | tee "$FILE_PATH$INDIVIDUAL_TEST_SUMMARY"

        line_number=$(grep -n "short test summary info" $FILE_PATH$FILENAME | cut -d: -f1 | head -n 1)
                if [ -n "$line_number" ]; then
                    total_lines=$(wc --l <"$FILE_PATH$FILENAME")
                    while IFS= read -r LINE; do
                       echo $LINE >> "$FILE_PATH$OVERALL_TEST_SUMMARY"
                    done < <(tail -n +$((line_number + 1)) $FILE_PATH$FILENAME | head -n $(($total_lines - $line_number - 4)))
                fi
        
        # LOOP to fetch all log files in log dir
        for logfile in "$FILE_PATH$LOG_DIR"/*.log; do

            if [[ $(tail -n 2 $logfile | grep -o passed) == "passed" ]]; then
                keyword=$(echo "$logfile" | awk -F "/" '{print $NF}' | awk -F "." '{print $1}')
                ptc=$(grep -i -F $keyword $logfile | tail -n 1)
                echo "PASSED $ptc" | tee -a "$FILE_PATH$INDIVIDUAL_TEST_SUMMARY"
                ((PASS++))
                sed -i "\|^FAILED $ptc\$|d" $FILE_PATH$OVERALL_TEST_SUMMARY
                sum_str=$(grep "^= " $FILE_PATH$OVERALL_TEST_SUMMARY)
                tf=$(grep "^= " $FILE_PATH$OVERALL_TEST_SUMMARY | awk '{print $2}')
                tp=$(grep "^= " $FILE_PATH$OVERALL_TEST_SUMMARY | awk '{print $4}')
                te=$(grep "^= " $FILE_PATH$OVERALL_TEST_SUMMARY | awk '{print $12}')
                ltf=$(($tf - $PASS))
                ltp=$(($tp + $PASS))
                lte=$(($te - $PASS))
                sed -i "\|^$sum_str\$|d" $FILE_PATH$OVERALL_TEST_SUMMARY
                sum_str=$(echo $sum_str | sed "s/\b$tf\b/$ltf/g")
                sum_str=$(echo $sum_str | sed "s/\b$tp\b/$ltp/g")
                sum_str=$(echo $sum_str | sed "s/\b$te\b/$lte/g")
                echo $sum_str >> $FILE_PATH$OVERALL_TEST_SUMMARY


            elif [[ $(tail -n 2 $logfile | grep -o failed) == "failed" ]]; then
                tail -n 2 $logfile | grep -v -B 1 failed | tee -a "$FILE_PATH$INDIVIDUAL_TEST_SUMMARY"
                ((FAIL++))

            else
                keyword=$(echo "$logfile" | awk -F "/" '{print $NF}' | awk -F "." '{print $1}')
                stc=$(grep -i -F $keyword $logfile | tail -n 1)
                echo "SKIPED $stc" | tee -a "$FILE_PATH$INDIVIDUAL_TEST_SUMMARY"
                ((SKIP++))
            fi
        done
        sed -i "1i =========================== short test summary info ============================" $FILE_PATH$OVERALL_TEST_SUMMARY
        echo "=======================$FAIL failed, $PASS passed, $SKIP skipped =========================" | tee -a "$FILE_PATH$INDIVIDUAL_TEST_SUMMARY"
    # exit if logs directory not exist.
    else
        echo "$LOG_DIR does not exist."
    fi
}

#check file exits or not
if [ ! -f "$FILE_PATH$FILENAME" ]; then
    echo "$FILE_PATH$FILENAME file not exists"
    exit 1

# collect the data before executing test cases
else
    echo "===============================Failed test cases from log file $FILE_PATH$FILENAME============================" | tee "$FILE_PATH$BEFORE_TEST"
    fld=FAILED
    err=ERROR
    
    # execute fetch date for FAILED
    fetch_data $fld
    
    # execute fetch data for ERROR
    if $ERROR_TEST ; then
            fetch_data $err
    fi

    echo "============================$FAILED Failed, $ERROR Errors, $SKIPPED skipped=========================" | tee -a  "$FILE_PATH$BEFORE_TEST"
fi

    fld=FAILED
    err=ERROR
    # execute run test for FAILED
    run_test_case $fld
    # execute run test for ERROR
    if $ERROR_TEST ; then
        run_test_case $err
    fi
    # execute test summary
    test_summary


        










