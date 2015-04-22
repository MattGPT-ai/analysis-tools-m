#!/bin/bash 

priority=0

cmd="$1"
export q_command="$1"
set -- $cmd

if [ $2 ]; then
    priority=$2 #doesn't work right
fi
#echo $priority

qsub <<EOF
#!/bin/sh -f 
#PBS -V
#PBS -j oe
#PBS -o $HOME/log/PBSlog.txt
#PBS -N $1

$cmd
#while [ "$1" != "" ]; do
#shift
#done

EOF
#PBS -p $priority
#PBS -N "${cmd/ /}"

exit 0 # success
