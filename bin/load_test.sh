#!/bin/sh
MURL=$1
BURL=$2
N=$3
EACH=$4

if [ $# -eq 4 ]
then 
    START=0
    echo "starting $N processes with $EACH clients each." 
else 
    if [ $# -lt 4]
    then
	echo "load_test.sh <meteorurl> <psycurl> <processes> <clients per process>"
	exit 1
    else
	START=$5
    fi
fi

PID=""
SIGTERM=15
DIR=`dirname "$0"`

rm $DIR/../stats/*.plot

for num in `seq 1 $N`
do
	echo "$num"
	MIN=$(($num * $EACH + $START))
	MAX=$((($num + 1) * $EACH - 1 + $START))
	WAIT=$(echo "($EACH * 0.05) + 2"|bc)
	echo "pike -M $DIR/../lib/ $DIR/client.pike $MURL $BURL $MIN $MAX > $DIR/../stats/$num.plot"
	#pike -DTUNICAST -M $DIR/../ppp/lib -M $DIR/../lib/ $DIR/client.pike $MURL $BURL $MIN $MAX > $DIR/../stats/$num.plot &
	pike -tg -DTRACE_SOFT_MEMLEAKS -DMEASURE_THROUGHPUT -M $DIR/../ppp/lib -M $DIR/../lib/ $DIR/client.pike $MURL $BURL $MIN $MAX > $DIR/../stats/$num.plot &
	PID="$PID $!" 
	if [ $num -ne $N ]
	then
		trap 'echo "stopped"; kill $PID; echo "killed processes $PID"; exit 1;' 15 2 18
		echo "sleep $WAIT"
		sleep $WAIT
		#sleep 5
	fi
done

echo "started processes $PID"

trap 'echo "stopped"; kill $PID; echo "killed processes $PID"' 15 2 18

wait $PID
