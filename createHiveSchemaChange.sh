#!/bin/bash
# This script is helpful in create files for a new schema change in hive.
# Hive has support for 5 DB types and it is tedious to get the names correct.
# this script updates the cdh.order.upgrade file along with creating shell schema scripts.

usage() {
  echo "Usage: "
  echo "  $0 -create <NEW_VERSION>"
  echo "OR"
  echo "  $0 -rename <NEW_VERSION>"
  echo " "
  echo "NEW_VERSION:"
  echo "  Version string in 4 part form"
  echo "  7.2.16.0-Update1 is the right form"
  echo "  7.2.16-Update1 is incorrect form"
  echo "Examples:"
  echo "  -create 7.2.16.0-Update1  Creates skeleton schema files for upgrading from current"
  echo "                  latest version to the version specified. Also updates the"
  echo "                  cdh.upgrade.order.* files as well."
  echo " "
  echo "  -rename 7.2.15.0-Update3 7.2.16.0-Update1"
  echo "                  Renames the files related to the 7.2.15.0-Update3 to 7.2.16.0-Update1"
  echo "                  Also updates the cdh.upgrade.order.* files as well."
  echo
}

if [ $# -lt 2 ]; then
  usage && exit 1
fi

if [[ ( $1 != "-create" ) && ( $1 != "-rename" ) ]]; then
  echo "Error: unrecognized $1 option."
  echo
  usage && exit 1
else
  OPTYPE="$1"
fi

LOG_FILE="/tmp/create-schema.log"
isDebugEnabled=0
BASE_VERSION="3.1.3000"
if [ "$OPTYPE" = "-create" ]; then
  newCdhVersion="$2"
  if [[ "$3" = "-debug" ]];then
    isDebugEnabled=1
  fi
elif [ "$OPTYPE" = "-rename" ]; then
  versionToRemove="$2"
  fullVersionToRemove="$BASE_VERSION.$2"
  newCdhVersion="$3"
  if [[ "$4" = "-debug" ]];then
    isDebugEnabled=1
  fi

fi

if [[ $newCdhVersion = $BASE_VERSION* ]]
then
  echo "Use only the short version like 7.2.15.0-Update3: $newCdhVersion"
  usage && exit 1;
else
  verParts=( ${newCdhVersion//./ } ) # replace dots, split into array
  len=${#verParts[@]}
  for (( i=0; i<$len; i++ )); do echo "${verParts[$i]}" ; done
  if [ $len -lt 4 ]; then
    echo "Version string does not conform to convention: $len"
    usage && exit 1
  fi
fi

echo "Version string conforms to convention"

SRC_ROOT="./src/main/sql"
CDH_ORDER_FILE_PREFIX="cdh.upgrade.order"
DB_DERBY="derby"
DB_MSSQL="mssql"
DB_MYSQL="mysql"
DB_ORACLE="oracle"
DB_POSTGRES="postgres"
CURRENT="" # stores the highest current version of schema from the cdh.upgrade.order file
PREVIOUS="" # stores the version prior to the highest version from the cdh.uprade.order file
supportedDBs=($DB_DERBY $DB_MSSQL $DB_MYSQL $DB_ORACLE $DB_POSTGRES)

echo "Generating schema files for version $BASE_VERSION.$newCdhVersion"

getTime() {
  echo `date +"[%m-%d-%Y %H:%M:%S]"`
}

# method to print messages to the log file
log() {
  printf "%s %s\n" "$(getTime) $@" >> $LOG_FILE
}

# method to print messages to STDOUT
CONSOLE() {
  if [[ "$isDebugEnabled" -eq 1 ]]; then
    printf "%s %s\n" "$(getTime) $@"
  fi
  log "$@"
}

DEBUG() {
  printf "%s %s\n" "$(getTime) $@"
}

INFO() {
  printf "%s %s\n" "$(getTime) $@"
}

countFiles() {
  ls | grep  | wc -l
}

versionExists=0
checkForExistingVersion() {
  CONSOLE "Checking in $SRC_ROOT/$1/$CDH_ORDER_FILE_PREFIX.$1"
  if grep -q "$2" "$SRC_ROOT/$1/$CDH_ORDER_FILE_PREFIX.$1"; then
    versionExists=1
  else
    versionExists=0
  fi
}

checkVersionOrdering() {
  CONSOLE "Comparing $CURRENT with $BASE_VERSION.$newCdhVersion"
  if [[ "$CURRENT" > "$BASE_VERSION.$newCdhVersion" ]]; then
    echo "New version specified <$newCdhVersion> is lower than existing version <$CURRENT>"
    exit 1
  fi
}

getSQLHeaderFor() {
  case "${1}" in
    $DB_DERBY )
      retString="-- Upgrade MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion\n"
      echo -e "$retString"
      ;;
    $DB_MSSQL )
      retString="SELECT 'Upgrading MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion' AS MESSAGE;"
      echo -e "$retString"
      ;;
    $DB_MYSQL )
      retString="SELECT 'Upgrading MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion' AS MESSAGE;"
      echo -e "$retString"
      ;;
    $DB_ORACLE )
      retString="SELECT 'Upgrading MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion' AS Status from dual;"
      echo -e "$retString"
      ;;
    $DB_POSTGRES )
      retString="SELECT 'Upgrading MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion';"
      echo -e "$retString"
      ;;
    * )
      echo "ERROR: Not a supported version"
  esac
}

getSQLFooterFor() {
  case "${1}" in
    $DB_DERBY )
      retString="-- These lines need to be last.  Insert any changes above.\nUPDATE \"APP\".CDH_VERSION SET SCHEMA_VERSION='$BASE_VERSION.$newCdhVersion', VERSION_COMMENT='Hive release version $BASE_VERSION for CDH $newCdhVersion' where VER_ID=1;"
      echo -e "$retString"
      ;;
    $DB_MSSQL )
      retString="-- These lines need to be last.  Insert any changes above.\nUPDATE CDH_VERSION SET SCHEMA_VERSION='$BASE_VERSION.$newCdhVersion', VERSION_COMMENT='Hive release version $BASE_VERSION for CDH $newCdhVersion' where VER_ID=1;\nSELECT 'Finished upgrading MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion' AS MESSAGE;"
      echo -e "$retString"
      ;;
    $DB_MYSQL )
      retString="-- These lines need to be last.  Insert any changes above.\nUPDATE CDH_VERSION SET SCHEMA_VERSION='$BASE_VERSION.$newCdhVersion', VERSION_COMMENT='Hive release version $BASE_VERSION for CDH $newCdhVersion' where VER_ID=1;\nSELECT 'Finished upgrading MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion';"
      echo -e "$retString"
      ;;
    $DB_ORACLE )
      retString="-- These lines need to be last.  Insert any changes above.\nUPDATE CDH_VERSION SET SCHEMA_VERSION='$BASE_VERSION.$newCdhVersion', VERSION_COMMENT='Hive release version $BASE_VERSION for CDH $newCdhVersion' where VER_ID=1;\nSELECT 'Finished upgrading MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion' AS Status from dual;"
      echo -e "$retString"
      ;;
    $DB_POSTGRES )
      retString="-- These lines need to be last.  Insert any changes above.\nUPDATE \"CDH_VERSION\" SET \"SCHEMA_VERSION\"='$BASE_VERSION.$newCdhVersion', \"VERSION_COMMENT\"='Hive release version $BASE_VERSION for CDH $newCdhVersion' where \"VER_ID\"=1;\nSELECT 'Finished upgrading MetaStore schema from $CURRENT to $BASE_VERSION.$newCdhVersion';"
      echo -e "$retString"
      ;;
    * )
      echo "ERROR: Not a supported version"
  esac
}

checkUniformityAcrossDBs() {
  currLastLine=""
  prevLastLine=""
  for i in "${supportedDBs[@]}"
  do
    CONSOLE "Searching for version in $i"
    checkForExistingVersion "$i" $newCdhVersion
    if [[ "$versionExists" -eq 1 ]]
    then
      CONSOLE "Specified version already exists. Use a different version"
      exit 1
    fi

    local DB_ROOT="$SRC_ROOT/$i"
    CONSOLE "DB_ROOT is $DB_ROOT"
    local DB_ORDER_FILE="$DB_ROOT/$CDH_ORDER_FILE_PREFIX.$i"
    CONSOLE "Order file is $DB_ORDER_FILE"
    # confirm that last line of each order file is a same across add DBs
    currLastLine=$(tail -n 1 $DB_ORDER_FILE)
    if [[ "$prevLastLine" = "" ]];
    then
      prevLastLine=$currLastLine
    else
      if [[ ! "$currLastLine" = "$prevLastLine" ]];
      then
        CONSOLE "Latest versions across dbs do not match:$i"
        exit 1
      fi
    fi
  done

  CONSOLE "All files have $prevLastLine"
  PREVIOUS=`echo $currLastLine | awk -F-to- '{print $1}'`
  CURRENT=`echo $currLastLine | awk -F-to- '{print $2}'`
}

checkUniformityAcrossDBs
CONSOLE "Schema versions across all DBs are consistent"

CONSOLE "Current schema version is $CURRENT"
checkVersionOrdering

doCreate() {
  for i in "${supportedDBs[@]}"
  do
    DB_ROOT="$SRC_ROOT/$i"
    CONSOLE "DB_ROOT is $DB_ROOT"
    DB_ORDER_FILE="$DB_ROOT/$CDH_ORDER_FILE_PREFIX.$i"
    CONSOLE "Order file is $DB_ORDER_FILE"
    DB_SCHEMA_FILE="$DB_ROOT/upgrade-$CURRENT-to-$BASE_VERSION.$newCdhVersion.$i.sql"
    CONSOLE "Schema file is $DB_SCHEMA_FILE"

    touch "$DB_SCHEMA_FILE"
    getSQLHeaderFor "$i" > $DB_SCHEMA_FILE
    echo "" >> $DB_SCHEMA_FILE
    echo "" >> $DB_SCHEMA_FILE
    echo "" >> $DB_SCHEMA_FILE
    getSQLFooterFor "$i" >> $DB_SCHEMA_FILE

    # update the cdh.upgrade.order file
    echo "$CURRENT-to-$BASE_VERSION.$newCdhVersion" >> $DB_ORDER_FILE
  done
  CONSOLE "DONE CREATING"
}

doRename() {
  CONSOLE "Removing $fullVersionToRemove"

  for i in "${supportedDBs[@]}"
  do
    checkForExistingVersion "$i" $fullVersionToRemove
    if [[ "$versionExists" -eq 0 ]]
    then
      CONSOLE "Specified fromVersion $fullVersionToRemove does not exist. Please check the version."
      exit 1
    fi

    DB_ROOT="$SRC_ROOT/$i"
    CONSOLE "DB_ROOT is $DB_ROOT"
    DB_ORDER_FILE="$DB_ROOT/$CDH_ORDER_FILE_PREFIX.$i"
    CONSOLE "Order file is $DB_ORDER_FILE"
    OLD_DB_SCHEMA_FILE="$DB_ROOT/upgrade-$PREVIOUS-to-$fullVersionToRemove.$i.sql"
    NEW_DB_SCHEMA_FILE="$DB_ROOT/upgrade-$PREVIOUS-to-$BASE_VERSION.$newCdhVersion.$i.sql"

    # update the cdh.upgrade.order file
    sedcmd="sed -i .orig "s/-to-$fullVersionToRemove/-to-$BASE_VERSION.$newCdhVersion/g" $DB_ORDER_FILE"
    CONSOLE "Executing stringsub using $cmd"
    #`sed -i '.orig' 's/-to-$fullVersionToRemove/-to-$BASE_VERSION.$newCdhVersion/g' $DB_ORDER_FILE`
    success=$($sedcmd)
    CONSOLE "success=$success with string sub $#"
    if [[ "$success" -eq 0 ]];then
      CONSOLE "String sub succeeded, renaming file $OLD_DB_SCHEMA_FILE to $NEW_DB_SCHEMA_FILE"
      sedcmd="sed -i .orig "s/$versionToRemove/$newCdhVersion/g" $OLD_DB_SCHEMA_FILE"
      CONSOLE "Executing $sedcmd"
      success=$($sedcmd)
      if [[ "$success" -eq 0 ]];then
        CONSOLE "Renaming file $OLD_DB_SCHEMA_FILE to $NEW_DB_SCHEMA_FILE"
        success=$(mv "$OLD_DB_SCHEMA_FILE" "$NEW_DB_SCHEMA_FILE")
        success=$?
        if [[ "$success" -eq 0 ]];then
          CONSOLE "Rename $OLD_DB_SCHEMA_FILE to $NEW_DB_SCHEMA_FILE succeeded"
          CONSOLE "Deleting backup files"
          rmcmd="rm $DB_ROOT/*.orig"
          $($rmcmd)
        fi
      else
        # rollback
        CONSOLE "Rolling back the changes to $DB_ORDER_FILE"
        sedcmd="sed -i .orig "s/-to-$BASE_VERSION.$newCdhVersion/-to-$fullVersionToRemove/g" $DB_ORDER_FILE"
        success=$($sedcmd)
        if [[ "$success" -eq 0 ]];then
          CONSOLE "Deleting backup files"
          rmcmd="rm $DB_ROOT/*.orig"
          success=$($rmcmd)
          success=$?
        fi
      fi
    fi
  done
}

if [ "$OPTYPE" = "-create" ]; then
  doCreate
else
  doRename
fi
