timeStart=\`date +%s\`

$cmd

exitCode=\$?
timeEnd=\`date +%s\`

echo "Process completed in:"
date -d @\$((timeEnd-timeStart)) -u +%H:%M:%S

#exit $exitCode 
