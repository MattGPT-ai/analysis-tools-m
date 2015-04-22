#!/bin/bash

rmLaser="false"
rm1="false"
rm2="false"
rm4="false"
rm5="false"
rmQueue="false"

extension=""

args=`getopt 1245las:e:q $*`
set -- $args

for i; do
    case "$i" in
	-1) rm1="true"
	    shift ;;
	-2) rm2="true"
	    shift ;;
	-4) rm4="true"
	    shift ;;
	-5) rm5="true"
	    shift ;;
	-l) rmLaser="true"
	    shift ;;
	-a) rm1="true"; rm2="true"; rm4="true"; rm5="true"; rmLaser="true"; rmQueue="true"
	    shift ;;
	-q) rmQueue="true"
	    shift ;;
	-s) subDir=$2
	    shift; shift ;;
	-e) extension=$2
	    shift; shift ;;
	--) shift; break ;;
    esac
done # loop over command line arguments    



cycleList() {
    runMode=$1
    
    while read -r line
      do
      
      set -- $line
      
      runDate=$1
      runNum=$2

      if [ $rmLaser = "true" ]; then

	  for laser in $3 $4 $5 $6; do
	      laserFile=$VEGASWORK/processed/${laser}_laser.root
	      if [ -f $laserFile ]; then
		  if [ $runMode = "listOnly" ]; then
		      echo $laserFile
		  elif [ $runMode = "delete" ]; then
		      rm $laserFile
		      if [ $rmQueue = "true" ]; then
			  rm $VEGASWORK/queue/${laser}_laser
		      fi
		  fi
	      fi
	  done

	  combinedLaser=$VEGASWORK/processed/laserCombined_${runDate}.root
	  if [ -f $combinedLaser ]; then
	      if [ $runMode = "listOnly" ]; then
		  echo $combinedLaser
	      elif [ $runMode = "delete" ]; then
		  rm $combinedLaser
	      fi
	  fi
      
	  if [ $rmQueue = "true" ]; then
              rm -f $VEGASWORK/queue/${laser}_laser
	  fi

      fi # remove laser

      stage1File=$VEGASWORK/processed/${runNum}.stage1.root
      if [ $rm1 = "true" ]; then
	  if [ -f $stage1File ]; then
              if [ $runMode = "listOnly" ]; then
		  echo $stage1File
              elif [ $runMode = "delete" ]; then
		  rm $stage1File
              fi
	  fi

	  if [ $rmQueue = "true" -a -f $VEGASWORK/queue/${runNum}.stage1 ]; then
              rm  $VEGASWORK/queue/${runNum}.stage1
	  fi	  
      fi # remove stage 1


      
      stage2File=$VEGASWORK/processed/${runNum}.stage2.root
      if [ $rm2 = "true" ]; then
	  if [ -f $stage2File ]; then
              if [ $runMode = "listOnly" ]; then
		  echo $stage2File
              elif [ $runMode = "delete" ]; then
		  rm $stage2File
              fi
	  fi
	  
	  if [ $rmQueue = "true" -a -f $VEGASWORK/queue/${runNum}.stage2 ]; then
              rm  $VEGASWORK/queue/${runNum}.stage2
          fi
      fi # remove stage 2

      stage4File=$VEGASWORK/processed/${runNum}.stage4${extension}.root
      if [ $rm4 = "true" ]; then
	  if [ -f $stage4File ]; then
              if [ $runMode = "listOnly" ]; then
		  echo $stage4File
              elif [ $runMode = "delete" ]; then
		  rm $stage4File
              fi
	  fi

	  if [ $rmQueue = "true" -a -f $VEGASWORK/queue/${runNum}.stage4 ]; then
              rm  $VEGASWORK/queue/${runNum}.stage4
          fi
      fi # remove stage 4

      stage5File=$VEGASWORK/processed/${subDir}/${runNum}.stage5${extension}.root
      if [ $rm5 = "true" ]; then
	  if [ -f $stage5File ]; then
	      if [ $runMode = "listOnly" ]; then
		  echo $stage5File
              elif [ $runMode = "delete" ]; then
		  rm $stage5File
	      fi
	  fi

	  if [ $rmQueue = "true" -a -f $VEGASWORK/queue/${runNum}.stage5 ]; then
              rm  $VEGASWORK/queue/${runNum}.stage5
          fi
      fi # remove stage 5

    done < $readList

} # cycleList 


if [ $1 ]; then
    
    readList=$1

    echo "about to delete files listed in $readList!"
    echo "laser: $rmLaser stage1: $rm1 stage2: $rm2 stage4: $rm4 stage5: $rm5 queue: $rmQueue"

    cycleList "listOnly"

    echo "Press 'Y' if this is okay!"
    read response

    if [ $response = "Y" ]; then
	cycleList delete
    fi
    
else
    echo "no runlist specified! run ls mode?"
    read response

    if [ $response == "Y" ]; then
	
	for f in `ls`; do
	    if [ -f $f ]; then
		SIZE=$(du $f | cut -f 1)
		if((SIZE < 1200)); then
		    echo $f
		fi
	    fi
	done # loop over files in ls
    fi # response is yes to run ls mode

    echo "The following files are to be deleted. Press 'Y' if this is okay!"
    read response
    
    if [ $response == "Y" ]; then
	for f in `ls`; do
	    if [ -f $f ]; then
		SIZE=$(du $f | cut -f 1)
		if((SIZE < 1200)); then
		    rm $f
		fi
	    fi
	done
    fi
fi # runlist is specified

exit 0 # success
