#!/bin/bash
 set -x

confFile=$(dirname $0)/videoMover.conf
[ ! -f ${confFile} ] && _warning "fichier de conf non present : ${confFile}" && exit 1
. ${confFile}
CR=$?
[ $CR != 0 ] && _warning "Pb export du fichier de conf : ${confFile} " && exit 1

# Controle user
if [ "$(whoami)" != "${user}" ] ; then exit 0 ; fi


# Boucle Principale
/usr/bin/transmission-remote -l| grep -Ev "^ID|^Sum" | while read line ; do
  id=$(echo "$line" | awk '{print $1}')

  if [ "x$id" == "x" ] ; then continue ; fi

  downlaod=$(echo "$line" | cut -c42- | awk -F\. '{print $1}')

  if [ ${downlaod} -gt 0 ] ; then
    /usr/bin/transmission-remote -t${id} -i | grep "^  Magnet" | grep "${key2}"
    if [ $? -eq 0 ] ; then
      # echo "${id} - $(/usr/bin/transmission-remote -t${id} -i | grep "^  Name")"
      /usr/bin/transmission-remote -t${id} --tracker-remove "${tracker}/${key2}/${announce}"
    fi
  fi
done
