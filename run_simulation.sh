source ./mychimere/statcodes_paths.sh

#TODO  load this var with parameters
firstdate=2013061500
lastdate=2013083100
incday=5``
parfile=my_chimere.par
#----------------------------------------------------------------------
curdate=${firstdate}
nh=‘expr ${incday} \* 24‘
#----------------------------------------------------------------------
# prod or devel
typmod=prod
#----------------------------------------------------------------------
# simulation
# First block, no restart
chimrestart=no
while [ $curdate -le $lastdate ] ; do
  datestr=‘date +"%Y%m%d%H%M%S"‘
  curlog=${logdir}/${logfile}.${datestr}.log
  ./chimere.sh ${parfile} f ${curdate} ${nh} --${typmod} --restart ${chimrestart} 2>&1 | tee ${curlog} || exit 1
  echo "Log file for this simulation: "${curlog}
  chimrestart=yes
  curdate=$(date -u -d "${curdate:0:8} ${curdate:8:2} ${nh} hour" +%Y%m%d%H)
done