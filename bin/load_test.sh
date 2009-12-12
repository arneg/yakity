#!/bin/sh
MURL=$1
BURL=$2
N=$3
EACH=$4

if [ $# -ne 4 ]
then 
	echo "load_test.sh <meteorurl> <psycurl> <processes> <clients per process>"
	exit 1
else
	echo "starting $N processes with $EACH clients each." 
fi

rm $DIR/../stats/*.plot

PID=""
SIGTERM=15
DIR=`dirname "$0"`

for num in `seq 1 $N`
do
	echo "$num"
	MIN=$(echo "$num * $EACH"|bc)
	MAX=$(echo "($num + 1) * $EACH - 1"|bc)
	WAIT=$(echo "($EACH * 0.01) + 2"|bc)
	echo "pike -M $DIR/../lib/ $DIR/client.pike $MURL $BURL $MIN $MAX > $DIR/../stats/$num.plot"
	pike -M $DIR/../lib/ $DIR/client.pike $MURL $BURL $MIN $MAX > $DIR/../stats/$num.plot &
	PID="$PID $!" 
	if [ $num -ne $N ]
	then
		echo "sleep $WAIT"
		sleep $WAIT
	fi
done

echo "started processes $PID"

trap 'echo "stopped"; kill $PID; echo "killed processes $PID"' 15 2 18

wait $PID
