#!/usr/local/bin/bash
set -e

SRC_FILE="$1"

VERSION=1.0.0

info() {
     local green="\033[1;32m"
     local normal="\033[0m"
     echo -e "[${green}INFO${normal}] $1"
}

error() {
     local red="\033[1;31m"
     local normal="\033[0m"
     echo -e "[${red}ERROR${normal}] $1"
}

# Check ImageMagick
command -v convert >/dev/null 2>&1 || { error >&2 "The ImageMagick is not installed. Please use brew to install it first."; exit -1; }

# Check param
if [ $# != 1 ];then
	echo "[ERROR]: please only provide the icon source file as argument"
    exit -1
fi 

OUTPUT="generated"
mkdir -p ${OUTPUT}

APP_ICON=$1

#Datastructure for required sizes
declare -A iPhone
declare -A iPhoneSpotlight
declare -A iPhoneSettings
declare -A iPhoneNotifications
declare -A iPad
declare -A iPadSpotlight
declare -A iPadSettings
declare -A iPadNotifications
declare -A AppStore
declare -A WatchOS

iPhone=(
	['iPhone-60@2x']='120' 
	['iPhone-60@3x']='180'
)

iPad=(
	['iPad-76']='76'
	['iPad-76@2x']='152'
	['iPad-83.5@2x']='167'
)

iPhoneSpotlight=(
	['iPhone-Spotlight-40@2x']='80' 
	['iPhone-Spotlight-40@3x']='120'
)

iPadSpotlight=(
	['iPad-Spotlight-40']='40'
	['iPad-Spotlight-40@2x']='80'
)

iPhoneSettings=(
	['iPhone-Settings-29@2x']='58' 
	['iPhone-Settings-29@3x']='87'
)

iPadSettings=(
	['iPad-Settings-29']='29'
	['iPad-Settings-29@2x']='58'
)

iPhoneNotifications=(
	['iPhone-Notifications-20@2x']='40' 
	['iPhone-Notifications-20@3x']='60'
)

iPadNotifications=(
	['iPad-Notifications-20']='20'
	['iPad-Notifications-20@2x']='40'
)

WatchOS=(
	['WatchOS40x40@2x']='80'
	['WatchOS24x24@2x']='48'
	['WatchOS27.5x27.5@2x']='55'
	['WatchOS86x86@2x']='172'
	['WatchOS98x98@2x']='196'
	['WatchOS29x29@2x']='58'
	['WatchOS29x29@3x']='87'
)

AppStore=(
	['iTunesArtwork']='1024'
)

function process_array 
{
	local -n array
	array=$1
	folder_name=$2
	for key in "${!array[@]}";
	do
		value="${array[$key]}"
		info "Creating $key with resolution $value and source: $SRC_FILE"
		convert "$SRC_FILE" -resize "$value"x"$value" "$folder_name/$key.png"
	done
}

script_name=`basename "$0"`
if [[ -z "$APP_ICON" ]]; then
	echo "Usage: $script_name.sh <path_to_icon>"
	exit 1
fi

mkdir -p "$OUTPUT/iPhone"
mkdir -p "$OUTPUT/iPhoneSpotlight"
mkdir -p "$OUTPUT/iPhoneSettings"
mkdir -p "$OUTPUT/iPhoneNotifications"

mkdir -p "$OUTPUT/iPad"
mkdir -p "$OUTPUT/iPadSpotlight"
mkdir -p "$OUTPUT/iPadSettings"
mkdir -p "$OUTPUT/iPadNotifications"

mkdir -p "$OUTPUT/WatchOS"
mkdir -p "$OUTPUT/AppStore"

process_array iPhone "$OUTPUT/iPhone"
process_array iPhoneSpotlight "$OUTPUT/iPhoneSpotlight"
process_array iPhoneSettings "$OUTPUT/iPhoneSettings"
process_array iPhoneNotifications "$OUTPUT/iPhoneNotifications"

process_array iPad "$OUTPUT/iPad"
process_array iPadSpotlight "$OUTPUT/iPadSpotlight"
process_array iPadSettings "$OUTPUT/iPadSettings"
process_array iPadNotifications "$OUTPUT/iPadNotifications"

process_array WatchOS "$OUTPUT/WatchOS"
process_array AppStore "$OUTPUT/AppStore"
