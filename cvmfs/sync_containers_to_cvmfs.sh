#!/usr/bin/env bash
# set -e

#This script runs on the CVMFS STRATUM 0 server

#sudo vi /etc/cron.d/sync_containers_to_cvmfs
#*/5 * * * * ec2-user cd ~ && bash /home/ec2-user/neurocommand/cvmfs/sync_containers_to_cvmfs.sh

cd ~/neurocommand/

# update application list (the log.txt file get's build in the neurocommand action once all containers are uploaded.):
git pull
cd cvmfs

# check if there is enough free space - otherwise don't do anything:
FREE=`df -k --output=avail /storage | tail -n1`
if [[ $FREE -lt 400000000 ]]; then               # 400GB = 
    echo "There is not enough free disk space!"
    exit 1
fi;

# download and unpack containers on cvmfs
# curl -s https://raw.githubusercontent.com/NeuroDesk/neurocommand/master/cvmfs/log.txt
# export IMAGENAME_BUILDDATE=fsl_6.0.3_20200905
# export IMAGENAME_BUILDDATE=mrtrix3_3.0.1_20200908
# export IMAGENAME_BUILDDATE=spm12_r7219_20201120
# export LINE='fsl_6.0.4_20210105 categories:functional imaging,structural imaging,diffusion imaging,image segmentation,image registration,'

Field_Separator=$IFS
echo $Field_Separator


while IFS= read -r LINE
do
    echo "LINE: $LINE"
    IMAGENAME_BUILDDATE="$(cut -d' ' -f1 <<< ${LINE})"
    echo "IMAGENAME_BUILDDATE: $IMAGENAME_BUILDDATE"

    CATEGORIES=`echo $LINE | awk -F"categories:" '{print $2}'`
    echo "CATEGORIES: $CATEGORIES"

    echo "check if $IMAGENAME_BUILDDATE is in module files:"
    TOOLNAME="$(cut -d'_' -f1 <<< ${IMAGENAME_BUILDDATE})"
    TOOLVERSION="$(cut -d'_' -f2 <<< ${IMAGENAME_BUILDDATE})"
    BUILDDATE="$(cut -d'_' -f3 <<< ${IMAGENAME_BUILDDATE})"
    echo "[DEBUG] TOOLNAME: $TOOLNAME"
    echo "[DEBUG] TOOLVERSION: $TOOLVERSION"
    echo "[DEBUG] BUILDDATE: $BUILDDATE"

    echo "check if $IMAGENAME_BUILDDATE is already on cvmfs:"
    if [[ -f "/cvmfs/neurodesk.ardc.edu.au/containers/$IMAGENAME_BUILDDATE/commands.txt" ]]
    then
        echo "$IMAGENAME_BUILDDATE exists on cvmfs"
    else
        echo "$IMAGENAME_BUILDDATE is not yet on cvmfs. Downloading now!"

        #sync object storages:
        rclone sync oracle-2021-us-bucket:/neurodesk nectar:/neurodesk/
        rclone copy oracle-2021-us-bucket:/neurodesk oracle-2021-sydney-bucket:/neurodesk
        
        # check if singularity image is already in object storage
        if curl --output /dev/null --silent --head --fail "https://objectstorage.us-ashburn-1.oraclecloud.com/n/sd63xuke79z3/b/neurodesk/o/${IMAGENAME_BUILDDATE}.simg"; then
            echo "[DEBUG] ${IMAGENAME_BUILDDATE}.simg exists in ashburn oracle cloud"
            # in case of problems:
            # cvmfs_server check
            # If you get bad whitelist error, check if the repository is signed: sudo /usr/bin/cvmfs_server resign neurodesk.ardc.edu.au
            cvmfs_server transaction neurodesk.ardc.edu.au

            cd /cvmfs/neurodesk.ardc.edu.au/containers/
            git clone https://github.com/NeuroDesk/transparent-singularity $IMAGENAME_BUILDDATE
            cd $IMAGENAME_BUILDDATE
            export SINGULARITY_BINDPATH=/cvmfs
            ./run_transparent_singularity.sh $IMAGENAME_BUILDDATE --unpack true

            cd && cvmfs_server publish -m "added $IMAGENAME_BUILDDATE" neurodesk.ardc.edu.au
        fi
    fi

    # set internal field separator for the string list
    echo $CATEGORIES
    IFS=','
    for CATEGORY in $CATEGORIES;
    do
        echo $CATEGORY
        CATEGORY="${CATEGORY// /_}"

        if [[ -a "/cvmfs/neurodesk.ardc.edu.au/neurodesk-modules/$CATEGORY/$TOOLNAME/$TOOLVERSION" ]]
        then
            echo "$IMAGENAME_BUILDDATE exists in module $CATEGORY"
        else
            cvmfs_server transaction neurodesk.ardc.edu.au
            mkdir -p /cvmfs/neurodesk.ardc.edu.au/neurodesk-modules/$CATEGORY/$TOOLNAME/
            cp /cvmfs/neurodesk.ardc.edu.au/containers/modules/$TOOLNAME/$TOOLVERSION /cvmfs/neurodesk.ardc.edu.au/neurodesk-modules/$CATEGORY/$TOOLNAME/$TOOLVERSION
            cd && cvmfs_server publish -m "added modules for $IMAGENAME_BUILDDATE" neurodesk.ardc.edu.au
            if  [[ -f /cvmfs/neurodesk.ardc.edu.au/neurodesk-modules/$CATEGORY/$TOOLNAME/$TOOLVERSION ]]; then
                echo "module file $CATEGORY/$TOOLNAME/$TOOLVERSION written. This worked!"
            else
                echo "Something went wrong: cp /cvmfs/neurodesk.ardc.edu.au/containers/modules/$TOOLNAME/$TOOLVERSION /cvmfs/neurodesk.ardc.edu.au/neurodesk-modules/$CATEGORY/$TOOLNAME/$TOOLVERSION"
                exit 2
            fi
        fi
    done
    
    IFS=$Field_Separator

done < /home/ec2-user/neurocommand/cvmfs/log.txt


# check if catalog is OK:
# cvmfs_server list-catalogs -e


# garbage collection:
# sudo cvmfs_server gc neurodesk.ardc.edu.au

# Display tags
cvmfs_server tag -l