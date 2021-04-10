# OpenSCAP scanner rule test

This repository contains a script to check whether the rule ‘sshd_set_idle_timeout’ from scap-security-guide is correctly evaluated by the openscap scanner.

The script doesn't do any remidiation. It prepares the environment by installing the packages, executes the test/evaluation functions, and cleans up after itself.

The rule 'sshd_set_idle_timeout’ is a part of the profile PCI-DSS v3.2.1 Control Baseline for Fedora.

Result Map, set as environment variables - 
"XCCDF_RESULT_PASS" = 101
"XCCDF_RESULT_FAIL" = 102
"XCCDF_RESULT_ERROR" = 103