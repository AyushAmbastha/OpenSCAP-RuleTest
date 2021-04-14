# OpenSCAP scanner rule test

This repository contains a script to check whether the rule ‘sshd_set_idle_timeout’ from scap-security-guide is correctly evaluated by the openscap scanner.

The script doesn't do any remidiation. It prepares the environment by installing the packages and preparing the files, executes the test/evaluation functions, and cleans up after itself.

The rule 'sshd_set_idle_timeout’ is a part of the profile PCI-DSS v3.2.1 Control Baseline for Fedora.

Test Scenarios explored in the script - 
1. When the sshd_config file is correctly configured. 
Expected result: Pass
2. When the ClientAliveCountMax value in sshd_config is not equal to 0. 
Expected Result: Fail
3. When the ClientAliveInterval value in sshd_config is invalid, i.e set to something other than a numeric value. 
Expected Result: Fail

Result Map, set as environment variables - 
"XCCDF_RESULT_PASS" = 101
"XCCDF_RESULT_FAIL" = 102
"XCCDF_RESULT_ERROR" = 103