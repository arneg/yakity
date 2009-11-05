MURL=$1
BURL=$2
N=$3
EACH=$4

PID=""
SIGTERM=15

for num in `seq 0 $N`
do
	echo "$num"
	MIN=$(echo "$num * $EACH"|bc)
	MAX=$(echo "($num + 1) * $EACH - 1"|bc)
	echo "pike -M YakityChat-local/lib/ client.pike $MURL $BURL $MIN $MAX > stats/$num.plot"
	pike -M YakityChat-local/lib/ client.pike $MURL $BURL $MIN $MAX > stats/$num.plot &
	PID="$PID $!" 
	sleep 2
done

echo "started processes $PID"

trap 'echo "stopped"; kill $PID; echo "killed processes $PID"' 15 2 18

wait $PID
