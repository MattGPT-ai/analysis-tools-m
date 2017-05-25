# /bin/bash

declare -a lists=( "primary_targets" "moonlight_targets" "secondary_targets" "reduced_HV_targets" "moonlight_bright" "filler_targets" "snapshot_targets" "uv_filter_targets")

#loop over all lists
for list in "${lists[@]}"
do
  SRCID=()
  echo "Writing ~/.xephem/${list}.fav"
  while read line
  do 
      SRCID+=("$line")
  done < <(mysql -B -u readonly -h romulus.ucsc.edu VERITAS --execute="select tblObserving_Collection.source_id from tblObserving_Sources  JOIN tblObserving_Collection ON tblObserving_Sources.source_id = tblObserving_Collection.source_id  WHERE tblObserving_Collection.collection_id='${list}'")

  #SRCID=( `mysql -B -u readonly -h romulus.ucsc.edu VERITAS --execute="select
  #source_id from tblObserving_Sources"` )
  SRCRA=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select degrees(ra) from tblObserving_Sources JOIN tblObserving_Collection ON tblObserving_Sources.source_id = tblObserving_Collection.source_id  WHERE tblObserving_Collection.collection_id='${list}'"` )
  SRCDEC=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select degrees(decl) from tblObserving_Sources JOIN tblObserving_Collection ON tblObserving_Sources.source_id = tblObserving_Collection.source_id  WHERE tblObserving_Collection.collection_id='${list}'"` ) 
  SRCEPOCH=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select epoch from tblObserving_Sources  JOIN tblObserving_Collection ON tblObserving_Sources.source_id = tblObserving_Collection.source_id  WHERE tblObserving_Collection.collection_id='${list}'"` )

  #write file with targets
  echo "<Favorites>" > ~/.xephem/${list}.fav
  echo "  <favorite on='true'>Sun,P</favorite>">> ~/.xephem/${list}.fav
  echo "  <favorite on='true'>Moon,P</favorite>">> ~/.xephem/${list}.fav

  for ((i=1;i<${#SRCID[@]};i++))
  do
     #echo "${SRCID[i]} ${SRCRA[i]} ${SRCDEC[i]} ${SRCEPOCH[i]}"
     RA=`echo "${SRCRA[i]}*12.0/180.0" | bc -l` #convert from degrees to hours
     echo "  <favorite on='true'>${SRCID[i]},f|T,${RA},${SRCDEC[i]},1.0,${SRCEPOCH[i]},0</favorite>" >>~/.xephem/${list}.fav
  done
  echo "</Favorites>" >> ~/.xephem/${list}.fav
done
