#!/bin/bash
# author feth@majerti.fr - do anything with this, freely, at own risk

if [ x$1 == x ]
    then
    REFSPEC=master
else
    REFSPEC=$1
fi

set -e
set -u

COMPLETED=false
SUDO_PROMPT='[sudo] %p@%H password to run command as %U> '

function warnerror() {
    echo "removing $tempdir ... "
    rm -fr $tempdir
    echo "done"

    if ! $COMPLETED
        then
        echo "Sync did not complete!"
        exit 4
    fi
}


trap 'warnerror' SIGINT EXIT

source sync.rc

tmp_template=`date +"/tmp/${SALTHOST}_salt_%Y-%m-%d_%Hh%Mm%S_XXX"`
tempdir=`mktemp -d ${tmp_template}`

echo -n "Archiving to ${tempdir} ... "
git archive $REFSPEC |tar -x -C ${tempdir}
echo "done"

SSH_DEST=$REMOTE_USER@$SALTHOST
echo -n "Syncing to $SSH_DEST ... "
if $NEED_SUDO
    then
        tmp_basename=`basename ${tempdir}`
        echo "uploading to $SSH_DEST:${tmp_basename}"
        rsync -rv ${tempdir}/salt_config/salt $SSH_DEST:${tmp_basename}
        backup_name=`date +"/root/backup_salt_%Y-%m-%d_%Hh%Mm%S"`
        REMOTE_SCRIPT=remote_script.sh
        ssh -t ${SSH_DEST} "cat<<EOF>${REMOTE_SCRIPT}
            echo \"backup of ${SALT_DIR} on ${SSH_DEST} if it exists...\"
            if [ -d ${SALT_DIR} ]
                then sudo -p \"${SUDO_PROMPT}\" mv ${SALT_DIR} ${backup_name}
            fi
            echo \"installation of new salt config...\"
            sudo -p \"${SUDO_PROMPT}\" cp -a ${tmp_basename}/salt ${SALT_DIR}
EOF
bash ${REMOTE_SCRIPT}"
    else
        rsync -rv $tempdir/salt/* $SSH_DEST:/$SALT_DIR
fi
if $USE_PILLAR_DIR
    then
    rsync -rv $tempdir/pillar/* $SSH_DEST:/$PILLAR_DIR
fi
echo done

COMPLETED=true
