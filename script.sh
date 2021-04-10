#!/bin/bash

if [[ $UID -ne '0' ]]
then
    echo 'Error: You need to be root user to run this test!'
    exit ${XCCDF_RESULT_FAIL}
fi

RET=${XCCDF_RESULT_PASS}
REPO='/etc/yum.repos.d'
SSHD_CONFIG='/etc/ssh/sshd_config'

function setup () {
    #If repositories are not configured
    if [ ! -d $REPO ]; then
        echo "FATAL ERROR: Repositories are not configured for setup to continue!"
    fi

    #Download the required packages
    for package in scap-security-guide openscap openscap-scanner; do
        if ! rpm -qa | grep -qw $package; then
            dnf install $package -y
        fi
    done
    echo 'Success: Packages installed!'
    echo "Success: Setup Complete!"
}

function check_sshd_config_exists() {
    #Check if sshd config file exists
    if [ ! -f $SSHD_CONFIG ]; then
        echo 'FATAL ERROR: SSH config file does not exit!'
    else echo 'Pass: SSH config file exists'
    fi
}

function check_client_alive_count() {
    if ! grep -qP "^(?=[\s]*+[^#])[^#]*(ClientAliveCountMax 0)" $SSHD_CONFIG; then
        echo 'ERROR: ClientAliveCountMax needs to be set to 0 in the sshd_config file!'
        echo 'Expected Value: This is number of null packets that will be sent to an unresponsive client.'
    else echo 'Pass: ClientAliveCountMax configured correctly in sshd_config'
    fi
}

function check_client_alive_interval() {
    if ! grep -qP "^(?=[\s]*+[^#])[^#]*(ClientAliveInterval [0-9])" $SSHD_CONFIG; then
        echo 'ERROR: ClientAliveInterval needs to be set in the sshd_config file!'
        echo 'Expected Value: This is number of seconds the server will wait before sending a null packet to the client to keep the connection alive.'
    else echo 'Pass: ClientAliveInterval configured correctly in sshd_config'
    fi
}

function openscap_report() {
    #Evaluating the rule
    oscap xccdf eval --profile pci-dss --rule \
        xccdf_org.ssgproject.content_rule_sshd_set_idle_timeout \
        /usr/share/xml/scap/ssg/content/ssg-fedora-ds.xml
}

function clean () {
    #openscap-scanner and scap-security-guide are dependencies of openscap and get uninstalled together
    dnf remove openscap -y
    echo "Success: Cleanup Complete!"
    exit $RET
}

#Main: Calling the functions
setup
check_sshd_config_exists
check_client_alive_count
check_client_alive_interval
openscap_report
clean
