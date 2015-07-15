#! /bin/bash
# set -x

function _count {
  table="$1"
  value="$2"

  declare -i count
  count=$(/usr/bin/sqlite3 $db_file "SELECT COUNT(*) FROM $table WHERE fname = '$value';" | tr -d '\r' | tr -d '\n' )

  return $count
}

_trim (){
  eval trimVar="\${$1}"
  trimVar=$(echo $trimVar | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  eval $1=\$trimVar
}

_warning () {
  messageID="$1"

  cMessage="$(_current_date) ${TR_TORRENT_NAME} ${messageID}"
  echo "${cMessage}"  >> $(dirname $0)/videoMover.err
}

_current_date () {
  date '+%Y-%m-%d %H:%M:%S'
}

# BOUCLE FILMS #
_main_video () {
  # Copie du fichier & log
  cp "${TR_TORRENT_DIR}/${line}" "${downloaded_dir}/${fileName}.tmp"
  mv "${downloaded_dir}/${fileName}.tmp" "${downloaded_dir}/${fileName}"
  chmod 0775 "${downloaded_dir}/${filename}"

  /usr/bin/sqlite3 $db_file \
    "INSERT INTO
      video(tname,fname)
      values('${TR_TORRENT_NAME}','$lineForSql');"
}


###################
# Debut
###################
# Source fichier de conf.
confFile=$(dirname $0)/etc/videoMover.conf
[ ! -f ${confFile} ] && _warning "fichier de conf non present : ${confFile}" && exit 1
. ${confFile}
CR=$?
[ $CR != 0 ] && _warning "Pb export du fichier de conf : ${confFile} " && exit 1

# Variable
# TR_TORRENT_NAME
# TR_TORRENT_DIR
# TR_TORRENT_ID
# TR_TORRENT_HASH
# TR_APP_VERSION
# TR_TIME_LOCALTIME



while getopts ":t:" opt ; do
  case $opt in
    t)  TR_TORRENT_ID=$OPTARG
        TR_TORRENT_NAME=$(/usr/bin/transmission-remote -t${TR_TORRENT_ID} -i | egrep "^  Name:" | cut -c9-)
        TR_TORRENT_DIR=$download_dir
        if [ "x$TR_TORRENT_NAME" == "x" ] ; then 
          echo "inexistant ID : torrent $TR_TORRENT_ID"
          exit 1
        fi
    ;;
    \?)  echo " option $OPTARG  INVALIDE" 
        exit 1
    ;;
  esac
done

mySupportFile=`echo "$support_file$" | sed 's/,/$|/g'`

# delete tracker
/usr/bin/transmission-remote -t${TR_TORRENT_ID} --tracker-remove "${tracker}/${key2}/${announce}"
/usr/bin/transmission-remote -t${TR_TORRENT_ID} --tracker-add "${tracker}/${key1}/${announce}"

# Boucle principale : Movie / TVShow
# Get torrrent file
/usr/bin/transmission-remote -t${TR_TORRENT_ID} --files | grep ": 100%" | grep -E "$mySupportFile$" |cut -c35- | while read line ; do
  lineForSql=$(echo "$line" | sed "s/'/''/g")

  # controle si existe deja
  _count "video" "$lineForSql"
  if [ "$?" -ne "0" ]  ; then
    echo "existe deja : $lineForSql "
    continue
  else
    echo "On continue : $lineForSql "
  fi

  fileName=$(echo $line| awk -F\/ '{print $NF}')

  # video
  _main_video
  sleep 2
done
