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
    #If repositories are not configured
    if [ ! -d $REPO ]; then
        RET=${XCCDF_RESULT_FAIL}
        echo "Error: Repositories are not configured to continue to setup"
        exit ${RET}
    fi

    #dnf update
    for package in scap-security-guide openscap openscap-scanner; do
        if ! rpm -qa | grep -qw $package; then
            dnf install $package -y
        fi
    done
    echo 'Success: Packages installed!'

    #If this isn't there already - make changes
    #if ! grep -Fxq "ClientAliveInterval 0" $SSHD_CONFIG; then
    #    echo "ClientAliveInterval 200" >> $SSHD_CONFIG
    #fi

    #if ! grep -Fxq "ClientAliveCountMax 0" $SSHD_CONFIG; then
    #    echo "ClientAliveCountMax 0" >> $SSHD_CONFIG
    #fi

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
        #exit $XCCDF_RESULT_FAIL
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

#Status does nothing to the overall result
function check_sshd_status() {
    systemctl show sshd | grep -iq "activestate=active"
	if [ $? -ne 0 ]; then
		echo "ERROR: SSH daemon is not running!"
	fi
}

#gpgcheck is disabled?

function openscap_report() {
    oscap xccdf eval --profile pci-dss --rule \
        xccdf_org.ssgproject.content_rule_sshd_set_idle_timeout \
        /usr/share/xml/scap/ssg/content/ssg-fedora-ds.xml
}

function clean () {
    #sed -i '/ClientAliveCountMax 0/d' $SSHD_CONFIG
    #sed -i '/ClientAliveInterval 200/d' $SSHD_CONFIG

    dnf remove openscap -y
    echo "Success: Cleanup Complete!"
}

#Calling the functions
setup
check_sshd_config_exists
check_client_alive_count
check_client_alive_interval
openscap_report
clean
