#!/bin/bash

if [[ $UID -ne '0' ]]
then
    echo 'Error: You need to be root user to run this test!'
    exit ${XCCDF_RESULT_ERROR}
fi

RET=${XCCDF_RESULT_PASS}
REPO='/etc/yum.repos.d'
SSHD_CONFIG='/etc/ssh/sshd_config'

function setup () {
    #Check whether the repositories are configured
    if [ ! -d $REPO ]; then
        echo "FATAL ERROR: Repositories are not configured for setup to continue!"
        exit ${XCCDF_RESULT_ERROR}
    fi

    #Download the required packages
    for package in scap-security-guide openscap openscap-scanner; do
        if ! rpm -qa | grep -qw $package; then
            dnf install $package -y
        fi
    done

    #Check if sshd_config file exists
    if [ ! -f $SSHD_CONFIG ]; then
        echo 'FATAL ERROR: SSH config file does not exist!'
        exit ${XCCDF_RESULT_ERROR}
    fi
    
    #Make a copy of the config file to restore configuration from in cleanup()
    cp $SSHD_CONFIG /etc/ssh/sshd_backupconfig

    #If the system has to act as an SSH server, the OpenSSH daemon configuration file needs to be modified
    if ! grep -qc "^PermitRootLogin" $SSHD_CONFIG;
    then
        echo "PermitRootLogin no" >> $SSHD_CONFIG
    else
        sed -i 's/.*\PermitRootLogin\b.*/PermitRootLogin no/' $SSHD_CONFIG
    fi

    if ! grep -qc "^PermitEmptyPasswords" $SSHD_CONFIG;
    then
        echo "PermitEmptyPasswords no" >> $SSHD_CONFIG
    else
        sed -i 's/.*\PermitEmptyPasswords\b.*/PermitEmptyPasswords no/' $SSHD_CONFIG
    fi

    echo "Success: Setup Complete!"
    echo ""
}

function openscap_eval() {
    #Evaluating the rule
    oscap xccdf eval --profile pci-dss --rule \
        xccdf_org.ssgproject.content_rule_sshd_set_idle_timeout \
        /usr/share/xml/scap/ssg/content/ssg-fedora-ds.xml | tee /tmp/oscap_output.txt > /dev/null 2>&1
}

function test_scenario_correct_configuration() {
    echo "==========================Test Scenario 1=========================="

    #Make the correct changes to the sshd_config file
    if ! grep -qc "^ClientAliveCountMax" $SSHD_CONFIG;
    then
        echo "ClientAliveCountMax 0" >> $SSHD_CONFIG
    else
        sed -i 's/.*\ClientAliveCountMax\b.*/ClientAliveCountMax 0/' $SSHD_CONFIG
    fi

    if ! grep -qc "^ClientAliveInterval" $SSHD_CONFIG;
    then
        #Setting idle interval time of 5 minutes
        echo "ClientAliveInterval 300" >> $SSHD_CONFIG
    else
        sed -i 's/.*\ClientAliveInterval\b.*/ClientAliveInterval 300/' $SSHD_CONFIG
    fi

    openscap_eval

    echo "SUMMARY: In this scenario, we configure the sshd_config file with the CORRECT VALUES of ClientAliveCountMax and ClientAliveInterval"
    echo -e "\t This configuration is based on the PCI-DSS v3.2.1 Control Baseline for Fedora."
    echo -e "\t Since we set the ClientAliveCountMax value to 0, we terminate an idle connection after ClientAliveInterval seconds."

    if grep -q "pass" /tmp/oscap_output.txt; then
        echo "RESULT: PASS"
    else 
        echo "RESULT: FAIL"
    fi

    echo ""

}

function test_scenario_incorrect_configuration() {
    echo "==========================Test Scenario 2=========================="

    if ! grep -qc "^ClientAliveCountMax" $SSHD_CONFIG;
    then
        echo "ClientAliveCountMax 10" >> $SSHD_CONFIG
    else
        sed -i 's/.*\ClientAliveCountMax\b.*/ClientAliveCountMax 10/' $SSHD_CONFIG
    fi

    if ! grep -qc "^ClientAliveInterval" $SSHD_CONFIG;
    then
        #Setting idle interval time of 5 minutes
        echo "ClientAliveInterval 300" >> $SSHD_CONFIG
    else
        sed -i 's/.*\ClientAliveInterval\b.*/ClientAliveInterval 300/' $SSHD_CONFIG
    fi

    openscap_eval

    echo "SUMMARY: In this scenario, we configure the sshd_config file with the INCORRECT VALUE of ClientAliveCountMax"
    echo -e "\t ClientAliveCountMax is the number of null packets that will be sent to an unresponsive client."
    echo -e "\t Since we set the ClientAliveCountMax value to 10, the server will send 10 checkalive messages to the client without"
    echo -e "\t receiving a response. Due to rule dependency, we want this value to be set to 0 in the sshd_config file."

    if grep -q "pass" /tmp/oscap_output.txt; then
        echo "RESULT: PASS"
    else 
        echo "RESULT: FAIL"
    fi
    
    echo ""

}

function test_scenario_invalid_configuration() {
    echo "==========================Test Scenario 3=========================="

    if ! grep -qc "^ClientAliveCountMax" $SSHD_CONFIG;
    then
        echo "ClientAliveCountMax 0" >> $SSHD_CONFIG
    else
        sed -i 's/.*\ClientAliveCountMax\b.*/ClientAliveCountMax 0/' $SSHD_CONFIG
    fi

    if ! grep -qc "^ClientAliveInterval" $SSHD_CONFIG;
    then
        #Setting idle interval time to an invalid value
        echo "ClientAliveInterval abc" >> $SSHD_CONFIG
    else
        sed -i 's/.*\ClientAliveInterval\b.*/ClientAliveInterval abc/' $SSHD_CONFIG
    fi

    openscap_eval
    
    echo "SUMMARY: In this scenario, we configure the sshd_config file with the INVALID VALUE of ClientAliveInterval"
    echo -e "\t ClientAliveInterval is the number of seconds the server will wait before sending a null packet to the client to keep the connection alive."
    echo -e "\t Since it's 'number' of seconds, a string such as 'abc' is an invalid value to assign."

    if grep -q "pass" /tmp/oscap_output.txt; then
        echo "RESULT: PASS"
    else 
        echo "RESULT: FAIL"
    fi
    
    echo ""

}

function clean () {
    #openscap-scanner and scap-security-guide are dependencies of openscap and get uninstalled together
    dnf remove openscap -y

    #Restore original sshd_config file
    rm $SSHD_CONFIG
    mv /etc/ssh/sshd_backupconfig $SSHD_CONFIG

    #Remove temporary output file
    rm /tmp/oscap_output.txt

    echo "Success: Cleanup Complete!"
    exit $RET
}

#Main: Calling the functions
setup
test_scenario_correct_configuration
test_scenario_incorrect_configuration
test_scenario_invalid_configuration
clean
