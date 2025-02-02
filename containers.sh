#!/bin/bash

_script="$(readlink -f ${BASH_SOURCE[0]})" ## who am i? ##
_base="$(dirname $_script)" ## Delete last component from $_script ##
source neurodesk/configparser.sh ${_base}/config.ini

install_all_containers="false"

if [ "$1" != "" ]; then
    echo "Installing all containers"
    install_all_containers="true"
fi

echo "------------------------------------"
echo "to install ALL containers, run:"
echo "bash containers.sh --all"
echo "------------------------------------"
echo "to install individual containers, run:"
for appsh in ${neurodesk_installdir}/bin/*.sh; do
    appfetch=$(sed -n 's/fetch_and_run.sh/fetch_containers.sh/p' $appsh)
    echo $appfetch
    if [ "$install_all_containers" = "true" ]; then
         eval $appfetch
        err=$?
        if [ $err -eq 0 ] ; then
            echo "Container successfully installed"
            echo "-------------------------------------------------------------------------------------"
            date
        else
            echo "======================================="
            echo "!!!!!!! Container install failed !!!!!!"
            echo "======================================="
            date
            exit
        fi
        
    fi
done