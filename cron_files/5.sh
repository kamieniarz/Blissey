#!/bin/bash

folder="$(cd ../ && pwd)"
source $folder/config.ini

# Logging
mkdir -p $folder/logs
touch $folder/logs/log_$(date '+%Y%m').log

# stderr to logfile
exec 2>> $folder/logs/log_$(date '+%Y%m').log

# rpl 5 worker stats
if "$workerstats"
then
  start=$(date '+%Y%m%d %H:%M:%S')
  MYSQL_PWD=$sqlpass mysql -u$sqluser -h$dbip -P$dbport $controllerdb < $folder/cron_files/5_worker.sql
  stop=$(date '+%Y%m%d %H:%M:%S')
  diff=$(printf '%02dm:%02ds\n' $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))/60)) $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))%60)))
  echo "[$start] [$stop] [$diff] rpl5 worker stats processing" >> $folder/logs/log_$(date '+%Y%m').log
fi

# rpl 5 mon area stats
if "$monareastats"
then
  start=$(date '+%Y%m%d %H:%M:%S')
  MYSQL_PWD=$sqlpass mysql -u$sqluser -h$dbip -P$dbport $blisseydb < $folder/cron_files/5_mon_area.sql
  stop=$(date '+%Y%m%d %H:%M:%S')
  diff=$(printf '%02dm:%02ds\n' $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))/60)) $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))%60)))
  echo "[$start] [$stop] [$diff] rpl5 mon area stats processing" >> $folder/logs/log_$(date '+%Y%m').log
fi

# rpl 5 quest area stats
if "$questareastats"
then
  start=$(date '+%Y%m%d %H:%M:%S')
  MYSQL_PWD=$sqlpass mysql -u$sqluser -h$dbip -P$dbport $blisseydb -NB -e "SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; call rpl5questarea();"
  stop=$(date '+%Y%m%d %H:%M:%S')
  diff=$(printf '%02dm:%02ds\n' $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))/60)) $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))%60)))
  echo "[$start] [$stop] [$diff] rpl5 quest area stats processing" >> $folder/logs/log_$(date '+%Y%m').log
fi

# device outage reporting
if [[ $outage_report == "true" ]] && [[ ! -z $outage_webhook ]]
then
  rm -f $folder/tmp/outage.txt
  curl -s $rotom_api_host:$rotom_api_port/api/status | jq -r '.devices[] | .origin+" "+(.dateLastMessageReceived|tostring)' | awk '{ if($2 <= systime()*1000-180000) print $1" "strftime("%Y%m%d_%H:%M:%S", $2/1000)}' > $folder/tmp/outage.txt
  cd $folder/default_files && ./discord.sh --username "Containers, no update in 3m" --color "16711680" --avatar "https://www.iconsdb.com/icons/preview/red/exclamation-xxl.png" --webhook-url "$outage_webhook" --description "$(jq -Rs . < "$folder/tmp/outage.txt" | cut -c 2- | rev | cut -c 2- | rev)"
fi

# rpl 5 dragonite log processing
if [[ $dragonitelog == "true" ]]
then
  cd $folder/cron_files && ./5_dragonitelog.sh
#  sleep 1s
  cd $folder/cron_files && ./5_accountstats.sh
#  sleep 1s
  cd $folder/cron_files && ./5_forts.sh
fi

# table cleanup golbat pokemon_area_stats
if [[ ! -z $area_raw ]] ;then
  start=$(date '+%Y%m%d %H:%M:%S')
  MYSQL_PWD=$sqlpass mysql -h$dbip -P$dbport -u$sqluser $scannerdb -e "delete from pokemon_area_stats where datetime < UNIX_TIMESTAMP(now() - interval $area_raw day);"
  stop=$(date '+%Y%m%d %H:%M:%S')
  diff=$(printf '%02dm:%02ds\n' $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))/60)) $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))%60)))
  echo "[$start] [$stop] [$diff] cleanup golbat table pokemon_area_stats" >> $folder/logs/log_$(date '+%Y%m').log
fi

# table cleanup controller stats_workers
if [[ ! -z $worker_raw ]] && [[ $workerstats == "true" ]] ;then
  start=$(date '+%Y%m%d %H:%M:%S')
  MYSQL_PWD=$sqlpass mysql -u$sqluser -h$dbip -P$dbport $controllerdb -e "delete from stats_workers where datetime < utc_timestamp() - interval $worker_raw day;"
  stop=$(date '+%Y%m%d %H:%M:%S')
  diff=$(printf '%02dm:%02ds\n' $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))/60)) $(($(($(date -d "$stop" +%s) - $(date -d "$start" +%s)))%60)))
  echo "[$start] [$stop] [$diff] cleanup controller table stats_workers" >> $folder/logs/log_$(date '+%Y%m').log
fi
