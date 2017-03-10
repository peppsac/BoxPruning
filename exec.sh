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
	result=`./${folder}/BoxPruning${1} ${2} | grep found`
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
	echo ${return_value:1}
}

run() {
	if [ -d "build/$1" ]
	then
		folder=build/$1
		_run_impl $1 "brute-force"

		str=$1
		for i in $(seq 1 3)
		do
			result=$( _run_impl $1 "box-pruning" )
			cycles=`echo $result | cut -d, -f4`
			str="$str $cycles"
			echo $result
		done
		echo $str >> last_run.csv
	else
		echo "Version $1 not built"
		exit 1
	fi
}


plot_pre_args="set grid; set style fill solid; set style data histogram;"
plot_post_args="using 2:xticlabels(1) title 'run 1', '' using 3 title 'run 2', '' using 4 title 'run 3'"

for arg in "$@"
do
	case $arg in
		"build"|"run"|"rebuild")
			command=$arg
		;;
		"reset")
			echo '' > last_run.csv
		;;
		"graph")
			gnuplot -p -e "${plot_pre_args} plot '< sort -k1 last_run.csv' ${plot_post_args}"
		;;
		"image")
			gnuplot -p -e "${plot_pre_args} set output 'output.gif'; set terminal gif; plot '< sort -k1 last_run.csv' ${plot_post_args}"
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

