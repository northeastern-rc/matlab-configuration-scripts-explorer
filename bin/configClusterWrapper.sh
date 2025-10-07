#!/bin/sh
## Title:    configClusterWrapper.sh
## Purpose:  runs configCluster.m from scheduled job to configure MATLAB for multi-node parallelism
## Author:   MathWorks
## Date:     2022

$LAUNCHER matlab -nodisplay -r "try, configCluster, exit(0), catch E, disp(E.message), exit(1), end" -logfile /dev/null
STATUS=$?

if [ $STATUS -eq 0 ] ; then
    echo "MATLAB is configured for multi-node parallelism."
    echo
else
    echo "MATLAB failed to be configured for multi-node parallelism."
    echo
fi

exit $STATUS
