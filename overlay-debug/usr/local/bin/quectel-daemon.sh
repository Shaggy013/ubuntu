#!/bin/bash

TARGET_XML_FLIE="/etc/apns-conf.xml"
LAST_APN="/etc/last_apn"
APN_MATCH_LIST="/etc/apn_match_list"
QUERY_APN="/tmp/query.tmp"
ATDEV=/dev/atdev
DEBUGLOG=/tmp/log_4g

AUTO_MODE=0
MANUAL_MODE=0
DEBUG=0
LA_LINK=
LA_MCC=
LA_MNC=
LA_CARRIER=
LA_APN=
LA_USER=
LA_PASSWORD=
MCC=
MNC=
CARRIER=
APN=
USER=
PASSWORD=
MNC03=

print(){
   if [ $DEBUG -eq 1 ]; then
      echo $@
   fi
}

function AT_COMMAND {
   sleep 1
   echo -e "at+cops?\r\n" > $ATDEV
   sleep 1
   echo -e "at+cimi\r\n" > $ATDEV
}

function query_apn {
   ####clean the tmp file
   touch $QUERY_APN
   > $QUERY_APN

   #### set the config for serial port
   stty -F $ATDEV ignbrk -brkint -icrnl -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke
   AT_COMMAND &

   #### wait 4s and loop to read the return string of serial port
   pre_line="hello"
   while read -t 4 line
   do
	if [[ ${pre_line:0:8} == "at+cops?" ]]; then
	   IFS=","
	   array=($line)
	   CARRIER=`echo ${array[2]} | sed 's#\"##g'`
           print "CARRIER length: "${#CARRIER}
           CARRIER=`echo $CARRIER | sed 's/^[ \t]*//g'`
           CARRIER=`echo $CARRIER | sed 's/[ \t]*$//g'`
	   print "CARRIER length second: "${#CARRIER}
           print "CARRIER="$CARRIER >> $QUERY_APN
           if [ -z $CARRIER ]; then
		wait
                return 1
           fi
   	fi

        if [[ ${pre_line:0:7} == "at+cimi" ]]; then
	   MCC=${line:0:3}
	   MNC=${line:3:2}
	   MNC03=${line:3:3}

           if echo $MCC | grep -q '[^0-9]'
           then
		 wait
                 return 1
           fi
           if echo $MNC | grep -q '[^0-9]'
           then
		 wait
                 return 1
           fi
           if echo $MNC03 | grep -q '[^0-9]'
           then
                 wait
                 return 1
           fi

           print "MCC="$MCC >> $QUERY_APN
           print "MNC="$MNC >> $QUERY_APN
           print "MNC03="$MNC03 >> $QUERY_APN
        fi
        pre_line=$line
   done < $ATDEV
   wait
   return 0
}

function analy_xml {
    touch $APN_MATCH_LIST
    > $APN_MATCH_LIST

    count=0
    local IFS=\>
    while read -d \< ENTITY CDATA
    do
        local TAG_NAME=${ENTITY%% *}
	ENTITY=`echo -e $ENTITY | sed ":a;N;s#\n# #g;ta"  | sed "s#\t##g"`
        ENTITY=${ENTITY#* }
        ENTITY=${ENTITY%/*}
	if [[ $TAG_NAME == "apn" ]] ; then
		echo $ENTITY | grep "mcc=\"$MCC\"" | grep -E "mnc=\"$MNC\""\|"mnc=\"$MNC03\"" | grep -i -E "carrier=\"$CARRIER\""\|"name=\"$CARRIER\"" > /dev/null
		if [ $? -eq 0 ]; then
                    ############################################################
                    #record all of the matching items, But auto use the first one
                    ############################################################
		    echo $ENTITY >> $APN_MATCH_LIST
		    if [ $count -eq 0 ]; then
		        while read -d \" ENTRY
		        do
		    	    ENTRY=`echo -e $ENTRY | sed "s/^[ ]*//g"`
		            if [[ $PRE_ENTRY == "mcc=" ]]; then
			             MCC=$ENTRY
		            elif [[ $PRE_ENTRY == "mnc=" ]]; then
			             MNC=$ENTRY
		            elif [[ $PRE_ENTRY == "carrier=" ]]; then
			             CARRIER=$ENTRY
		            elif [[ $PRE_ENTRY == "name=" ]]; then
			             CARRIER=$ENTRY
		            elif [[ $PRE_ENTRY == "apn=" ]]; then
			             APN=$ENTRY
		            elif [[ $PRE_ENTRY == "user=" ]]; then
			             USER=$ENTRY
		            elif [[ $PRE_ENTRY == "password=" ]]; then
			             PASSWORD=$ENTRY
		            else
			              :
		            fi
		    	    PRE_ENTRY=$ENTRY
		        done <<< $ENTITY
		        count=$((count+1))
                    fi
		fi
	fi
    done < $1
    if [ $count -eq 0 ]; then
        return 1
    fi
    return 0
}

function get_last {
    if [ ! -e $LAST_APN ]; then
        print "get_last: Don't have last apn list"
        return 1
    fi

    while read line
    do
        local TAG_NAME=${line%=*}
        local TAG_VALUE=${line#*=}
        if [[ $TAG_NAME == "linkmode" ]]; then
                LA_LINK=$TAG_VALUE
	elif [[ $TAG_NAME == "mcc" ]]; then
		LA_MCC=$TAG_VALUE
	elif [[ $TAG_NAME == "mnc" ]]; then
		LA_MNC=$TAG_VALUE
	elif [[ $TAG_NAME == "carrier" ]]; then
		LA_CARRIER=$TAG_VALUE
	elif [[ $TAG_NAME == "name" ]]; then
		LA_CARRIER=$TAG_VALUE
	elif [[ $TAG_NAME == "apn" ]]; then
		LA_APN=$TAG_VALUE
	elif [[ $TAG_NAME == "user" ]]; then
		LA_USER=$TAG_VALUE
	elif [[ $TAG_NAME == "password" ]]; then
		LA_PASSWORD=$TAG_VALUE
	else
		:
	fi
    done < $LAST_APN
    if [[ -z "$LA_APN" ]]; then
        print "fail last apn null"
        return 1
    fi
    return 0
}

function save_last_apn {
    touch  /tmp/last_apn.tmp
    > /tmp/last_apn.tmp
    echo "linkmode="$1 >> /tmp/last_apn.tmp
    echo "mcc="$MCC >> /tmp/last_apn.tmp
    echo "mnc="$MNC >> /tmp/last_apn.tmp
    echo "carrier="$CARRIER >> /tmp/last_apn.tmp
    echo "apn="$APN >> /tmp/last_apn.tmp
    echo "user="$USER >> /tmp/last_apn.tmp
    echo "password="$PASSWORD >> /tmp/last_apn.tmp
    mv /tmp/last_apn.tmp $LAST_APN
}

function fake_query {
    while read line
    do
	if [[ ${line%%=*} == "MCC" ]]; then
		MCC=${line#*=}
	elif [[ ${line%%=*} == "MNC" ]]; then
		MNC=${line#*=}
	elif [[ ${line%%=*} == "MNC03" ]]; then
		MNC03=${line#*=}
	elif [[ ${line%%=*} == "CARRIER" ]]; then
		CARRIER=${line#*=}
	else
		echo "others"
	fi
    done < $QUERY_APN
}

function cmp_last_query {
    if [ x$MCC = x$LA_MCC ] && [ x$MNC = x$LA_MNC -o x$MNC03 = x$LA_MNC ] && (echo "$CARRIER" | grep -qi "$LA_CARRIER")
    then
	print "cmp_last_query: Match with last boot"
	APN=$LA_APN
        USER=$LA_USER
        PASSWORD=$LA_PASSWORD
        return 0
    else
	print "cmp_last_query: Don't match with last boot"
        return 1
    fi
}

function queryapn {
	query_apn
        ret=$?
	while [ $ret -ne 0 ]
        do
            echo "AT get fail, try"
            query_apn
            ret=$?
        done

	#fake_query
        echo "QUERY RESULT: "$CARRIER" "$MCC" "$MNC" "$MNC03"."

}

function getapn {
	#use AT instruments to get the MCC MNC CARRIER
        queryapn

        get_last
        ret=$?
        if [ $ret -eq 0 ]; then
	    cmp_last_query
            ret=$?
        fi

	if [ $ret -ne 0 ]; then
	    if [ -e "${TARGET_XML_FLIE}" ];  then
                print "getapn: Search apn from "$TARGET_XML_FLIE
		analy_xml ${TARGET_XML_FLIE}
                ret=$?
                if [ $ret -ne 0 ]; then
                     echo "getapn: can't get the matching item from apn xml"
                     return 1
                fi

    		save_last_apn "auto"
	    else
		echo "getapn: apn xml don't exit"
                return 2
	    fi
        fi
        return 0
}

function Checkdriver {
    count=0

    until [ -e $ATDEV ]
    do
        count=$((count+1))
        sleep 5
        if [ $count -eq 20 ]; then
                echo "4g modem driver is not ready, please check it, failed"
                exit  1
        fi
    done
}

function killcurrent {
     killall quectel-CM
}

function auto_connect {
     getapn
     ret=$?
     if [ $ret -eq 0 ]; then
           quectel-CM -s $APN $USER $PASSWORD  1>$DEBUGLOG  2>&1
     else
           print "auto_connect: can't get the APN, try to link without apn"
           quectel-CM
     fi
}

function manual_connect {
     save_last_apn "manual"
     quectel-CM -s $APN $USER $PASSWORD  1>$DEBUGLOG  2>&1
}

show_help()
{
     echo "$0: "
     echo "usage:"
     echo "    $0 options <Paramters>"
     echo "    $0 has two modes: auto and manual"
     echo " "
     echo "info: "
     echo "    It will use auto mode at the first system booting by default"
     echo "    It will choice the last mode if you run without -a or -m"
     echo " "
     echo "options"
     echo "-h|--help     show the help information"
     echo "-d|--debug    show the debug log"
     echo "-q|--query    use AT instruction query the informantion of SIM current"
     echo "-a|--auto     auto connect network by the APN query from SIM"
     echo "-m|--manual   \"[APN [USER PASSWORD]]\""
     echo "              connect network according to your manual input, Please make sure that"
     echo "              Use double quotation contains the APN/USER/PASSWORD if more one parameter"
}


echo "quectel-daemon.sh version 1.0.0"
####make sure the driver init has been completed
Checkdriver

parameter=`getopt -o adhqm: -l auto,debug,help,query,manual:,  -n "$0" -- "$@"`
if [ $? != 0 ]; then
     echo "Terminating ......" >&2
     exit 1
fi
eval set -- "$parameter"

while true
do
     case "$1" in
          -a|--auto)             AUTO_MODE=1 ; shift ;;
          -d|--debug)            DEBUG=1 ; shift ;;
          -h|--help)             show_help ; shift ;exit 0;;
          -q|--query)            queryapn ; shift ;exit 0;;
          -m|--manual)           MANUAL_MODE=1; MANUAL_APN=$2 ; shift 2;;
          --)                    shift ; break ;;
          *)                     echo "Internal error!" ; exit 1 ;;
     esac
done

killcurrent

if [ $AUTO_MODE -eq 1 ]; then
    auto_connect
elif [ $MANUAL_MODE -eq 1 ]; then
    apn_array=($MANUAL_APN)
    APN=${apn_array[0]}
    USER=${apn_array[1]}
    PASSWORD=${apn_array[2]}
    print $APN" "$USER" "$PASSWORD
    manual_connect
else
    print "Don't set the link mode, use the last mode"
    get_last
    ret=$?
    if [[ "$LA_LINK" = "manual" ]] && [[ $ret -eq 0 ]]; then
         APN=$LA_APN
         USER=$LA_USER
         PASSWORD=$LA_PASSWORD
         manual_connect
    else
        auto_connect
    fi
fi





