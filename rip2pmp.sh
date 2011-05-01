#!/bin/bash

##################################################################
#
# This script is a wrapper of Mencoder. It uses to transcode 
# the video file to h.264 format. Also it can generate videos that 
# fit PSP and IPod Touch.
#
# Usage:
# rip2pmp.sh -i input.anyformat -o output.mp4 -f [psp|psptv|ps3|ipod] -p [1|2]
#
# ex1:rip a file in one pass for psp 
# rip2pmp.sh -i input.anyformat -o output.mp4 -f psp 
#
# ex2:rip a file in two pass for ipod
# rip2pmp.sh -i input.anyformat -o output.mp4 -f ipod -p 2
#
# ex3: rip a file in standard h.264
# rip2pmp.sh -i input.anyformat -o output.mp4 
# 
# ex4: pass options to Mencoder
# rip2pmp.sh -i input.anyformat -o output.mp4 -M "-sid 0 -slang zh"
#
# Any comments, please mail to ashoyeh@gmail.com
#
# ChangeLog:
# 
# v.0.7:
# Add normal h.264 file generation. (audio is by pass)
# Remove "turbo" option in pass1.
#
# v.0.6.4:
# Filename fix with THM file.
#
# v.0.6.3:
# Bug fix with filename contains white space.
#
# v0.6.2.1:
# code refactoring.
#
# v0.6.2:
# Add -b option to specify the bitrate.
# default bitrates:
# PSP: 400
# PSPTV: 1000
# PS3: 1500
#
# v0.6.1:
# Add -T option to specify DVD track.
#
# v0.6:
# Add SHEYA mpeg4 format support.
#
#
# v0.5.2
# Add -t to invoke multi-thread encoding.
#
# v0.5.1
# Use libx264 to encode in psp format.
# Tested in PSP2000.
#
# v0.5
# Add x264 support
#
#
# v0.4.1
# Add better THM file naming.
#
# v0.4 
# add psptv. the resolution is set to 640:480
# vbitrate change to 1000.
# add "[-D dvd-root]: dvd node path or dvd iso file. e.g. /dev/scd0 or dvd.iso"
#
# v0.3
# fix the mencoder and ffmpeg path.
#
# v0.2
# fix generating a thumbnail when format is PSP
#
# v0.1 
# supports video format for PSP, PS3 and IPOD Touch.
#
##################################################################

test -z $MENCODER && MENCODER=`which mencoder`
test -z $FFMPEG && FFMPEG=`which ffmpeg`


### Variables
INPUT=""
OUTPUT=""
THM_OUTPUT=""
PASS="1"
FORMAT=""
OPT=""
FFMPEG_CMD=""
DVDROOT=""
TRACK=""
THREADS=1
BITRATE=""

# h264
OVC_OPT="-sws 10 -ovc x264 -x264encopts global_header:frameref=2:bframes=3:b_adapt:b_pyramid=none:weight_b:me_range=24:subq=7:psy-rd=0.8,0.2:me=umh:level_idc=30:partitions=p8x8,b8x8,i4x4:trellis=1:cabac:aq_mode=1:8x8dct=no:chroma_me:nofast_pskip:nodct_decimate:vbv_maxrate=4000:vbv_bufsize=2500"

# audio 
OAC_OPT="-oac faac -faacopts br=128:object=2:raw -channels 2"

# audio sample rate
AF="-af resample=48000,volume=10"

# file format
LAVF_OPT=""

# FrameRate
#OFPS="-ofps 30000/1001"


if [ $# == 0 ]
then
	echo "Usage:"
	echo "-o: output filename"
	echo "-i: input filename"
	echo "[-p pass_time]: 1 pass or 2 pass transcoding. Default is 1 pass"
	echo "[-f format]: "psp", rip to psp; "ipod", rip to ipod; "sheya", rip to sheya box format; "mp4", rip to normal mp4. Default is mp4"
	echo "[-M opt]: options passes to Mencoder"
	echo "[-D dvd-root]: dvd node path or dvd iso file. e.g. /dev/scd0 or dvd.iso"
	echo "[-T track no.]: specify DVD track number." 
	echo "[-j n_threads]: parallel encode jobs"
	exit 1
fi

while getopts "b:p:i:o:f:M:D:T:j:" option
do
	case $option in
		i) INPUT=$OPTARG;;
		o) OUTPUT=$OPTARG;;
		p) PASS=$OPTARG;;
		f) FORMAT=$OPTARG;;
		M) OPT=$OPTARG;;
		D) DVDROOT=$OPTARG;;
		T) TRACK=$OPTARG;;
		j) THREADS=$OPTARG;;
		b) BITRATE=$OPTARG;;
	esac
done

test -z $OUTPUT && echo "no output file" && exit 1;
OUTPUT_PREFIX="${OUTPUT::`expr ${#OUTPUT} - 4`}"
THM_OUTPUT="${OUTPUT_PREFIX}.THM"
OUTPUT=\"$OUTPUT\"

if [ -z "$DVDROOT" ]; then
	if [ -z $INPUT ]; then
		echo "no input file"
		exit 1;
	fi
	INPUT="\"$INPUT\""
else
	if [ -z "$TRACK" ]; then
		TRACK="dvd://`lsdvd -v "$DVDROOT" | grep "Longest track" | cut -f2 -d":" | sed -e"s/ //"`"
	else
		TRACK="dvd://$TRACK"

	fi
	DVDROOT="-dvd-device \"$DVDROOT\""
fi

case $FORMAT in
	ps*)
		if [ $FORMAT == "psp" ]; then
			LAVF_OPT="-of lavf -lavfopts format=psp"
			if [ -z $BITRATE ]; then
				BITRATE=400
			fi
			VF="-vf scale=480:272,harddup"
		elif [ $FORMAT == "psptv" ]; then
			LAVF_OPT="-of lavf -lavfopts format=psp"
			if [ -z $BITRATE ]; then
				BITRATE=1000
			fi
			VF="-vf harddup,scale=640:480"
		elif [ $FORMAT == "ps3" ]; then
			LAVF_OPT="-of lavf -lavfopts format=mp4"
			if [ -z $BITRATE ]; then
				BITRATE=1500
			fi
		fi
		OVC_OPT=$OVC_OPT:bitrate=$BITRATE:threads=$THREADS
		# grab a thumbnail
		FFMPEG_CMD="$FFMPEG -y -i $OUTPUT -f image2 -ss 180 -vframes 1 -s 160x120 $THM_OUTPUT"
		;;
	ipod) 
		LAVF_OPT="-of lavf -lavfopts format=mp4"
		if [ -z $BITRATE ]; then
			BITRATE=400
		fi
		OVC_OPT=$OVC_OPT:bitrate=$BITRATE:threads=$THREADS
		VF="-vf harddup,scale=480:320" # for ipod touch
		;;
	*)
		if [ -z $BITRATE ]; then
			BITRATE=1500
		fi
		LAVF_OPT=""
		OVC_OPT=$OVC_OPT:bitrate=$BITRATE:threads=$THREADS
		OAC_OPT="-oac copy"
		AF=""
		;;
esac

echo "input file: $INPUT"
echo "output filename: $OUTPUT"
echo "dvdroot: $DVDROOT"
echo "option pass to Mencoder: $OPT"
echo "Track: $TRACK"
echo "THM file: $THM_OUTPUT"

case $PASS in
	2)
	# FIXME:
	# No need to do pass2
	eval $MENCODER $OVC_OPT:pass=1 $OAC_OPT $LAVF_OPT $OFPS $INPUT \
		$VF $AF -o /dev/null $OPT $DVDROOT $TRACK
	eval $MENCODER $OVC_OPT:pass=2 $OAC_OPT $LAVF_OPT $OFPS $VF $AF $INPUT \
		-o $OUTPUT $OPT $DVDROOT $TRACK 
	rm -f divx2pass.log*
	;;
	*)
	# one pass only
	eval $MENCODER $OVC_OPT $OAC_OPT $LAVF_OPT $OFPS $INPUT $VF $AF -o $OUTPUT $DVDROOT $TRACK $OPT
	;;

esac

#grab a thumbnail if supported format
eval $FFMPEG_CMD
