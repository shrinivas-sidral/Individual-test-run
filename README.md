# Individual Test Run

Before running `rerun-test.sh`, change the required fields in the `rerun.config` file.

## Contents of `rerun.config` File to Change:

- `TIER_NO=<tier-number>`  
- `FILENAME=<tier-test-log-file-name>`  
- `OCS_VERSION=<ocs-version>`  
- `UI_TEST=<true/false>`  
- `ERROR_TEST=<true/false>`  

### Description of Fields:

- **TIER_NO**: Change the value to the tier test number (1, 2, 3, 4b, 4c).
- **FILENAME**: Add the log file name that contains the tier test log summary.
- **OCS_VERSION**: Change the version accordingly.
- **UI_TEST**: If you want to include UI tests, set the value to `true`, otherwise set it to `false`.
- **ERROR_TEST**: If you want to include ERROR tests, set the value to `true`, otherwise set it to `false`.

## Additional Settings in `rerun.config` File

- `FILE_PATH=~/ocs-upi-kvm/scripts/`
- `LOG_DIR="rerun-logs"`
- `BEFORE_TEST="before-rerun.log"`
- `INDIVIDUAL_TEST_SUMMARY="individual-test-summary.log"`
- `OVERALL_TEST_SUMMARY="overall-test-summary.log"`

### Description of Additional Settings:

- **FILE_PATH**: Refers to the tier test log file path.
- **LOG_DIR**: Individual log files are stored in `~/ocs-upi-kvm/scripts/rerun-logs`.
- **BEFORE_TEST**: Before executing individual test cases, the script generates a log of the total failed test cases and stores it in `before-rerun.log`.
- **INDIVIDUAL_TEST_SUMMARY**: The summary of individual test cases is stored in `individual-test-summary.log`. This file collects data from individual log files and generates the test summary.
- **OVERALL_TEST_SUMMARY**: The summary of tier test and individual test cases is stored in `overall-test-summary.log`. This file collects data from teir test log and individual log files and generates the overall test summary.

Make sure to update these fields before running your tests to ensure proper configuration and logging.


