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
	return_value=""
	for line in $result
	do
		algo=`echo $line|cut -d\  -f3,4`
		algo=${algo:1:-2}
		intersect=`echo $line|cut -d\  -f6`
		cycles=`echo $line|cut -d\  -f9`
		return_value="$return_value;$1,$algo,$intersect,$cycles"
	done
	echo ${return_value:1}
}

perf_stats="branches branch-misses cache-references cache-misses cycles instructions"

run() {
	if [ -d "build/$1" ]
	then
		old=$IFS
		IFS=$'\n'

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
		prev=''
		for stat in $stats
		do
			value=`echo $stat | cut -d/ -f1`
			percentage=''
			name=`echo $stat | cut -d/ -f3`
			case "$name" in
				"branch-misses"|"cache-misses"|"instructions")
					percentage=$(( (100 * $value) / $prev ))
				;;
			esac
			str_stats="$str_stats $value $percentage"
			prev=$value
		done

		echo "version $1 (3 run average): $r"
		echo "$1 $r $str_stats" >> last_run.csv
		IFS=$OLD
	else
		echo "Version $1 not built"
		exit 1
	fi
}


plot_command() {
	cmd="set xtics font ',6' ; set multiplot layout 3,2; set grid; set style data lines; set style fill solid 0.5; set style line 1 linewidth 3; set style data histogram; set format y '%.0s %c'; set y2tics;"


	# count=3
	# for stat in $perf_stats
	# do
	# 	fixed=`echo ${stat^^}|sed 's/-/_/g'`
	# 	cmd=$cmd"stats '< sort -k1 last_run.csv' using $count name '$fixed' nooutput; "
	# 	count=$(( $count + 1 ))
	# done


	cmd="$cmd plot '< sort -k1 last_run.csv' using 2:xticlabels(1) title 'K-cycles(app)' axes x1y2; "
	count=3
	for stat in $perf_stats
	do
		fixed=`echo ${stat^^}|sed 's/-/_/g'`
		# cmd=$cmd"'< sort -k1 last_run.csv' using 1:(delta1=\$$count-${fixed}_min, delta2=${fixed}_max-${fixed}_min, delta1/delta2) title '$stat',"
		# cmd=$cmd" plot '< sort -k1 last_run.csv' using 1:$count title '$stat';"

		case "$stat" in
			"branch-misses"|"cache-misses"|"instructions")
				div=1
				lbl='%'
				if [[ "$stat" == "instructions" ]]
				then
					lbl='insn p. cy'
					div=100
				fi
				p=$(( $count + 1 ))
				cmd=${cmd:0:-1}", '< sort -k1 last_run.csv' using (\$$count):xticlabels(1) title '$stat', '< sort -k1 last_run.csv' using (\$$p / $div) title '$lbl' with lines axes x1y2;"
				count=$(( $count + 1 ))
				;;
			*)
				cmd=$cmd" plot '< sort -k1 last_run.csv' using (\$$count):xticlabels(1) title '$stat';"
				;;
		esac

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
			patched=`echo ${perf_stats}|sed 's/misses/misses miss-%/g'`
			echo "# Version ${patched} insn/cycle" > last_run.csv

		;;
		"graph")
			cmd=$( plot_command )
			echo "'$cmd'"
			gnuplot -p -e "set termoption enhanced; set terminal x11 font 'Verdana,10'; $cmd"
		;;
		"image")
			cmd=$( plot_command )
			gnuplot -p -e "set output 'output.png'; set terminal png small size 1000,1000; ${cmd}"
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

