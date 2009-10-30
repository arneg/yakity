URL=$1
MIN=$2
MAX=$3

PID=""
SIGTERM=15

for a in `seq $MIN $MAX`
do 
	pike -M YakityChat-local/lib/ client.pike $URL $a > stats/$a.log &
	PID="$PID $!" 
done

echo "started processes $PID"

trap 'echo "stopped"; kill $PID; echo "killed processes $PID"' 15 2 18

wait $PID
