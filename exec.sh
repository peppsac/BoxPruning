#!/bin/bash

build() {
	if [ -d "BoxPruning$1" ]
	then
		folder=build/$1
		mkdir -p $folder
		p=$PWD
		cd $folder
		if [ "$2" == "yes" ]
		then
			make clean > /dev/null
		fi
		cmake ../.. -DBOX_PRUNING_VERSION=$1 -DCMAKE_BUILD_TYPE=Release  > /dev/null
		make -j4  > /dev/null
		if [ "$?" -ne "0" ]
		then
			echo "Failed to build version $1"
			exit 1
		fi

		cd $p
	else
		echo "Invalid version $1"
	fi
}

_run_impl() {
	result=`./build/${1}/BoxPruning${1} ${2} | grep found`
	OLD=$IFS
	IFS=$'\n'
	return_value=""
	for line in $result
	do
		algo=`echo $line|cut -d\  -f3,4`
		algo=${algo:1:-2}
		intersect=`echo $line|cut -d\  -f6`
		cycles=`echo $line|cut -d\  -f9`
		return_value="$return_value;$1,$algo,$intersect,$cycles"
	done
	IFS=$OLD
	echo ${return_value:1}
}

perf_stats="branches branch-misses cache-misses instructions cycles"

run() {
	if [ -d "build/$1" ]
	then
		folder=build/$1
		_run_impl $1 "brute-force"

		total=0
		for i in $(seq 1 3)
		do
			result=$( _run_impl $1 "box-pruning" )
			cycles=`echo $result | cut -d, -f4`
			total=$(( $cycles + $total ))
		done
		r=$(( $total / 3 ))

		#gather perf stats
		# stats=`perf stat -x / --log-fd 1 -e branches,branch-misses,cache-misses,instructions,cycles ./${folder}/BoxPruning${1} "box-pruning"`
		# echo "AVANRT '$stats'"
		# stats=`echo $stats | grep -v K-cycles`

		comma_stats=`echo $perf_stats | sed 's/ /,/g'`
		# yay...
		stats=$((
		(
		perf stat -r 3 -x / -e $comma_stats taskset 0x00000001 ./${folder}/BoxPruning${1} "box-pruning"
		) 1>/dev/null
		) 2>&1)

		str_stats=""
		for stat in $stats
		do
			value=`echo $stat | cut -d/ -f1`
			str_stats="$str_stats $value"
		done
		echo "version $1 (3 run average): $r"
		echo "$1 $r $str_stats" >> last_run.csv
	else
		echo "Version $1 not built"
		exit 1
	fi
}


plot_command() {
	cmd="set multiplot layout 3,2; set grid; set style data lines; set style line 1 linewidth 3; set style data histogram;"


	count=3
	for stat in $perf_stats
	do
		fixed=`echo ${stat^^}|sed 's/-/_/g'`
		cmd=$cmd"stats '< sort -k1 last_run.csv' using $count name '$fixed' nooutput; "
		count=$(( $count + 1 ))
	done


	cmd="$cmd plot '< sort -k1 last_run.csv' using 2:xticlabels(1) title 'K-cycles(app)' axes x1y2; "
	count=3
	for stat in $perf_stats
	do
		fixed=`echo ${stat^^}|sed 's/-/_/g'`
		# cmd=$cmd"'< sort -k1 last_run.csv' using 1:(delta1=\$$count-${fixed}_min, delta2=${fixed}_max-${fixed}_min, delta1/delta2) title '$stat',"
		# cmd=$cmd" plot '< sort -k1 last_run.csv' using 1:$count title '$stat';"
		cmd=$cmd" plot '< sort -k1 last_run.csv' using (\$$count/1024):xticlabels(1) title 'K-$stat';"
		count=$(( $count + 1 ))
	done

	echo ${cmd:0:-1}
}

for arg in "$@"
do
	case $arg in
		"build"|"run"|"rebuild")
			command=$arg
		;;
		"reset")
			echo "# Version ${perf_stats}" > last_run.csv

		;;
		"graph")
			cmd=$( plot_command )
			echo "'$cmd'"
			gnuplot -p -e "$cmd"
		;;
		"image")
			gnuplot -p -e "set output 'output.gif'; set terminal gif; plot '< sort -k1 last_run.csv' ${plot_post_args}"
		;;
		*)
			case $command in
				"build") build ${arg} "no"
				;;
				"rebuild") build ${arg} "yes"
				;;
				"run")   run ${arg}
				;;
			esac
		;;
		esac
done

