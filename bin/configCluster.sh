#!/bin/sh

export LAUNCHER=srun
salloc -n 1 -c 1 -t 00:15:00 --mem-per-cpu=4000 configClusterWrapper.sh
STATUS=$?

exit $STATUS
