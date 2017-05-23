while :
do
	D=$(date +"%d-%m-%Y %H:%M:%S")
	U=$(top -b -n 1 | grep Cpu)
	echo $D $U
	sleep 1
done

