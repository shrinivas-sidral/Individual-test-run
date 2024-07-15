#!/bin/bash

# export all the required varibles
source ~/ocs-upi-kvm/scripts/rerun.config

#funtion for - fetch data before executing the test cases
fetch_data(){

    while IFS= read -r T
    do

    if ! $UI_TEST ; then

        str=$(echo "$T" | awk -F "/" '{print $2}')
        if [[ $str == "ui" ]]
        then
            echo $T | sed "s/$1/SKIPPED/" | tee -a $FILE_PATH$BEFORE_TEST
            ((SKIPPED++))
        else
            echo "$T" | tee -a "$FILE_PATH$BEFORE_TEST"
            (($1++))
        fi

    else
        echo "$T" | tee -a "$FILE_PATH$BEFORE_TEST"
        (("$1"++))
    fi
    done < <(cat < "$FILENAME" | grep "^$1[[:space:]]\+" | sort | uniq)
}

#funtion for - run the test cases
run_test_case()
{
    # activate virtual env.
    source ~/venv/bin/activate

    # create directory
    mkdir -p "$FILE_PATH$LOG_DIR"

    #read test cases from file
    while IFS= read -r TEST_CASE
    do

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
     done < <(cat < "$FILENAME" | grep "^$1[[:space:]]\+" | awk '{print $2}' | sort | uniq)
}

#funtion for - test summary 
test_summary(){
        if [ -d "$FILE_PATH$LOG_DIR" ]; then

        > "$FILE_PATH$TEST_SUMMARY"
        echo ========="================== short test summary info ============================" | tee -a "$FILE_PATH$TEST_SUMMARY"
        
        # LOOP to fetch all log files in log dir
        for logfile in "$FILE_PATH$LOG_DIR"/*.log; do

            if [[ $(tail -n 2 $logfile |  grep -o passed) == "passed" ]]; then
                keyword=$(echo "$logfile" | awk -F "/" '{print $NF}'| awk -F "." '{print $1}')
                ptc=$(grep -i -F $keyword  $logfile | tail -n 1)
                echo "PASSED $ptc" | tee -a "$FILE_PATH$TEST_SUMMARY"
                    ((PASS++))

            elif [[ $(tail -n 2 $logfile |  grep -o failed) == "failed" ]]; then
                tail -n 2 $logfile | grep -v -B 1 failed | tee -a "$FILE_PATH$TEST_SUMMARY"
                ((FAIL++))

            else
                keyword=$(echo "$logfile" | awk -F "/" '{print $NF}'| awk -F "." '{print $1}')
                stc=$(grep -i -F $keyword  $logfile | tail -n 1)
                echo "SKIPED $stc" | tee -a "$FILE_PATH$TEST_SUMMARY"
                ((SKIP++)) 
            fi
        done
        echo "=======================$FAIL failed, $PASS passed, $SKIP skipped =========================" | tee -a "$FILE_PATH$TEST_SUMMARY"
    # exit if logs directory not exist.
    else
        echo "$LOG_DIR does not exist."
    fi
}


#check file exits or not
if [ ! -f "$FILENAME" ]; then
    echo "$FILENAME file not exists"
    exit 1

# collect the data before executing test cases
else
    echo "===============================Failed test cases from log file $FILENAME============================" | tee "$FILE_PATH$BEFORE_TEST"
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

read -p "Do you want to continue the test execution? (y/n): " answer
answer=${answer,,}

case $answer in
  "y")
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
   ;;
  "n")
     echo "Exiting.....!"
     rm -rf $FILE_PATH$BEFORE_TEST
   ;;
    *)
   echo "Invalid option..!"
   ;;
esac
