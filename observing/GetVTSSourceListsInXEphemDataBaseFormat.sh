# /bin/bash

#partial names that are selected
Names=("BSC" "Dark")

echo "Writing XEphem file for all VERITAS targets"
while read line
do 
    SRCID+=("$line")
done < <(mysql -B -u readonly -h romulus.ucsc.edu VERITAS --execute="select source_id from tblObserving_Sources")

#SRCID=( `mysql -B -u readonly -h romulus.ucsc.edu VERITAS --execute="select
#source_id from tblObserving_Sources"` )
SRCRA=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select degrees(ra) from tblObserving_Sources"` )
SRCDEC=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select degrees(decl) from tblObserving_Sources"` ) 
SRCEPOCH=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select epoch from tblObserving_Sources"` )

rm ~/.xephem/VTSSourceListAll.edb

for ((i=1;i<${#SRCID[@]};i++))
do
   RA=`echo "${SRCRA[i]}*12.0/180.0" | bc -l`
   echo "${SRCID[i]},f|T,${RA},${SRCDEC[i]},1.0,${SRCEPOCH[i]}" >>~/.xephem/VTSSourceListAll.edb
done

declare -a lists=( "primary_targets" "moonlight_targets" "secondary_targets" "reduced_HV_targets" "moonlight_bright" "blazar_filler_targets")

#loop over all lists
for Name in "${Names[@]}"
do

  echo "Writing list for ${Name}"
  SRCID=()
  while read line
  do 
     SRCID+=("$line")
     done < <(mysql -B -u readonly -h romulus.ucsc.edu VERITAS --execute="select source_id from tblObserving_Sources WHERE  tblObserving_Sources.source_id LIKE '%${Name}%'")

     SRCRA=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select degrees(ra) from tblObserving_Sources  WHERE  tblObserving_Sources.source_id LIKE '%${Name}%'"` )
     SRCDEC=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select degrees(decl) from tblObserving_Sources WHERE  tblObserving_Sources.source_id LIKE '%${Name}%'"` ) 
     SRCEPOCH=( `mysql -u readonly -h romulus.ucsc.edu VERITAS --execute="select epoch from tblObserving_Sources WHERE  tblObserving_Sources.source_id LIKE '%${Name}%'"` )

     rm ~/.xephem/VTS_${Name}.edb

     for ((i=1;i<${#SRCID[@]};i++))
       do
         RA=`echo "${SRCRA[i]}*12.0/180.0" | bc -l`
         echo "${SRCID[i]},f|T,${RA},${SRCDEC[i]},1.0,${SRCEPOCH[i]}" >>~/.xephem/VTS_${Name}.edb
     done
done
