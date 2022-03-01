#!/bin/bash

BLOCK_SIZE=512
DEBUG=0
CUSTOM_PATITION=/dev/block/by-name/backup
#CUSTOM_PATITION=./resource.img
TMP_DIR=~/.custom_logo/
MAX_SIZE=33554432
BACKUP_IMAGE_OFFSET=

print(){
    if [ $DEBUG -eq 1 ]; then
         echo $@
    fi
}

get_table_entry(){
   offset=$(($tbl_offset+$tbl_entry_size*$1))
   print "=====>table "$1" "$offset
   dd if=$CUSTOM_PATITION of=/tmp/entry bs=$BLOCK_SIZE skip=$offset count=1 status=none
   dd if=/tmp/entry of=/tmp/content_name bs=1 skip=4 count=256 status=none
   content_name=`cat /tmp/content_name`
   content_offset=$(od -A n -X -j 260 -N 4 /tmp/entry | sed 's/ //g' | sed 's/^0*//g')
   content_offset=$((16#$content_offset))
   content_size=$(od -A n -X -j 264 -N 4 /tmp/entry | sed 's/ //g' | sed 's/^0*//g')
   content_size=$((16#$content_size))
   print "name "$content_name
   print "offset "$content_offset" size"$content_size
   return $(($content_offset+($content_size/$BLOCK_SIZE+1)))
}

check_current_custom(){
   dd if=$CUSTOM_PATITION of=/tmp/magic bs=4 count=1 status=none
   MAGIC=`cat /tmp/magic`
   if [[ $MAGIC != "RSCE" ]]; then
       print "Don't have custom logo resouce"
       return 1
   fi

   dd if=$CUSTOM_PATITION of=/tmp/head bs=$BLOCK_SIZE count=1 status=none
   head_size=$(od -A n -X -j 8 -N 1 /tmp/head | sed 's/ //g' | sed 's/^0*//g')
   head_size=$((16#$head_size))
   tbl_offset=$(od -A n -X -j 9 -N 1 /tmp/head | sed 's/ //g' | sed 's/^0*//g')
   tbl_offset=$((16#$tbl_offset))
   tbl_entry_size=$(od -A n -X -j 10 -N 1 /tmp/head | sed 's/ //g' | sed 's/^0*//g')
   tbl_entry_size=$((16#$tbl_entry_size))
   tbl_entry_num=$(od -A n -X -j 12 -N 4 /tmp/head | sed 's/ //g' | sed 's/^0*//g')
   tbl_entry_num=$((16#$tbl_entry_num))

   print $head_size $tbl_offset $tbl_entry_size $tbl_entry_num

   for((i=0;i<$tbl_entry_num;i++))
   do
       get_table_entry $i
   done
   BACKUP_IMAGE_OFFSET=$?
   print "backup partition current size: "$(($BACKUP_IMAGE_OFFSET*$BLOCK_SIZE))
   return 0
}

check_logo_file(){
    Bsize=`ls -all $1| awk '{print $5}'`
    size=$(($Bsize*8))
    OLDIFS=${IFS}
    IFS=','
    file_info=`file $1`
    depth=0
    for i in ${file_info}
    do
        resolution=`echo $i | sed 's/ //g' | grep "[0-9]\{2,4\}x[0-9]\{2,4\}x[0-9]\{1,2\}"`
        if [[ -n "$resolution" ]]; then
            IFS='x'
            array=($resolution)
            width=${array[0]}
            height=${array[1]}
            depth=${array[2]}
        fi
    done
    IFS=$OLDIFS
    print "picture:"$width"x"$height"x"$depth
    if [[ "$depth" -ne 8 ]] && [[ "$depth" -ne 24 ]]; then
         echo "failed, please check the depth bit of logo, must be 24b or 8b"
         exit 1
    fi
}

clear_backup(){
    check_current_custom
    ret=$?
    if [ $ret -eq 0 ]; then
        dd if=/dev/zero of=$CUSTOM_PATITION bs=$BLOCK_SIZE count=$BACKUP_IMAGE_OFFSET status=none
    fi
}

flash_backup(){
   if [ -e $1 ] && [ -e $CUSTOM_PATITION ]; then
       if [ ! -d $TMP_DIR ]; then
           mkdir $TMP_DIR
       fi
       check_logo_file $1

       cp $1 $TMP_DIR/logo_custom.bmp
       cd $TMP_DIR
       resource_tool --pack logo_custom.bmp
       if [ -e resource.img ]; then
            rsize=`ls -all resource.img | awk '{print $5}'`
            if [[ $rsize -gt $MAX_SIZE ]]; then
                echo "fail, the resource image is too big"
                exit 3
            fi
            dd if=resource.img of=$CUSTOM_PATITION status=none
       else
            echo "create resource image failed"
            exit 2
       fi
       cd -
    else
        echo "don't exist the custom logo or partition"
        exit 1
    fi
}

show_help()
{
     echo "$0: "
     echo "usage:"
     echo "    $0 options <Paramters>"
     echo "    $0 set the custom logo path or clear to revert to the default logo"
     echo " "
     echo "options"
     echo "-h|--help        show the help information"
     echo "-d|--debug       show the debug log"
     echo "-c|--clear       clear the custom logo, and revert to the default"
     echo "-s|--set <PATH>  set the custom logo to the bmp at the specified path"
}


parameter=`getopt -o dhcs: -l clear,debug,help,set:,  -n "$0" -- "$@"`
if [ $? != 0 ]; then
     echo "Terminating ......" >&2
     exit 1
fi
eval set -- "$parameter"

while true
do
     case "$1" in
          -d|--debug)            DEBUG=1 ; shift ;;
          -h|--help)             show_help ; shift ;exit 0;;
          -c|--clear)            clear_backup ; shift ;exit 0;;
          -s|--set)              flash_backup $2 ; shift 2;exit 0;;
          --)                    shift ; break ;;
          *)                     echo "Internal error!" ; exit 1 ;;
     esac
done
