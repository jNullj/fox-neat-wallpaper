#!/bin/bash
IMG_NAME=fox-neat-wallpaper.png
WALLPAPER_PATH=$HOME/.fox-neat-wallpaper
INSTALL_PATH=/opt/fox-neat-wallpaper
HOST_CONFIG_PATH=/etc/opt/fox-neat-wallpaper/host.conf
USER_CONFIG_PATH=$HOME/.config/fox-neat-wallpaper/user.conf
IMAGE_SIZE_X=1920
IMAGE_SIZE_Y=1080
IMAGE_SIZE=${IMAGE_SIZE_X}x${IMAGE_SIZE_Y}
LOGO_SIZE_PRECENT=60
typeset -A config	# declare config as dictionary - make it global

# create the cahce folder
TEMP_PATH=${TMPDIR:-/tmp}
TEMP_PATH=$TEMP_PATH/fox-neat-wallpaper
mkdir -p $TEMP_PATH	# create directory if does not exist yet

isCacheFresh () {	# test if a file in cache is up-to-date (modified in the last 5 min)
	local FILE_PATH="$1"
	if [ ! -f "$FILE_PATH" ]; then
		return 2
	fi
	local MODIFICATION_TIMESTAMP=$(stat  -c %Y "$FILE_PATH")	# timestamp in seconds
	local CURRENT_TIMESTAMP=$(date +%s)
	local TIMESTAMP_DIFF=$(($CURRENT_TIMESTAMP-$MODIFICATION_TIMESTAMP))
	# if file is older then 5 min its not "fresh" and will be recreataed
	if [[ $TIMESTAMP_DIFF -gt 300 ]]; then
		return 1
	fi
	# if everything good, lets reuse from the 'fresh' cache
	return 0
}

cacheableResult () {	# perform command and cache the result, if the result already cached and fresh, return it
	local ret_code
	local COMMAND_RETURN=
	local COMMAND="$1"
	local CACHE_NAME="$2"
	local CACHE_FILE_PATH="$TEMP_PATH/$CACHE_NAME"

	# if cache is fresh, return from cache
	if isCacheFresh "$CACHE_FILE_PATH"; then
		cat $CACHE_FILE_PATH
		return 0
	fi
	# else run command and save to cache
	COMMAND_RETURN="$($COMMAND)"
	ret_code=$?
	if [ $ret_code -ne 0 ]; then
		# don't cache on error, pass error to caller
		return $ret_code
	fi
	echo "$COMMAND_RETURN" > "$CACHE_FILE_PATH"
	echo "$COMMAND_RETURN"	# return result
	return 0
}

# reset those when running from root shell
# this is added for usage of xfconf-query
# otherwise dbus query from user as root fails
export XDG_RUNTIME_DIR="/run/user/$UID"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# functions to refresh/update global veriables about the user/system

get_primary_display () {
	xfconf-query -c displays -p /Default -lv | grep "Primary" | grep "true" | cut -d "/" -f3
}

get_display_resolution () {
	local PRIMARY_DISPLAY=$(get_primary_display)
	IMAGE_SIZE=$(xfconf-query -c displays -p "/Default/$PRIMARY_DISPLAY/Resolution")
	IMAGE_SIZE_X=$(echo $IMAGE_SIZE | cut -d'x' -f1)
	IMAGE_SIZE_Y=$(echo $IMAGE_SIZE | cut -d'x' -f2)
}

get_wallpaper_user_path () {
	WALLPAPER_PATH=$HOME/.fox-neat-wallpaper
}

get_user_config_path () {
	USER_CONFIG_PATH=$HOME/.config/fox-neat-wallpaper/user.conf
}

get_config_file () {
	# set default config
	config=(
		[example]="example"
		[background-color]="black"
		[package-color]="green"
		[old-package-color]="red"
		[logo-image]="$INSTALL_PATH/logo.svg"
		[font-family]="'Courier New', Courier"
	)
	# read system-wide config
	read_config_file "$HOST_CONFIG_PATH"
	# read user config
	read_config_file "$USER_CONFIG_PATH"
}

read_config_file () {
	if [ ! -f "$1" ]; then	# test if file exists
		return 2
	fi
	OLDIFS=$IFS
	IFS="="
	while read -r name value
	do
		if [[ ! $name =~ ^\ *# && -n $name ]]; then
			# only non empty/none comment lines

			# this will not allow # in string quotes
			value="${value%%\#*}"    # Del in line right comments
			value="${value%%*( )}"   # Del trailing spaces
			value="${value%\"*}"     # Del opening string quotes 
			value="${value#\"*}"     # Del closing string quotes

			# only set value for known config values - was set earlier at defaults
			if [[ -v "config[${name}]" ]]; then
				config["${name}"]="${value}"
			fi
		fi
	done < $1
	IFS=$OLDIFS
	return 0
}

# echo a list of outdated packages seperated by a new line using pacman-contrip's checkupdates
get_outdated_packages () {
	local updates_output # delcare before setting to insure exit code is picked, otherwise bash will first set then make local which will allways exit with 0
	local ret_code
	updates_output="$(checkupdates)"
	ret_code=$?
	if [ $ret_code -ne 0 ]; then
		# will return 1 on failure or 2 when no updates are available
		return $ret_code
	fi
	echo "$updates_output" | while read -r pkgname old_ver arrow new_ver; do
		echo "$pkgname $old_ver;"
	done
}

get_current_packages () {
	local COMMAND="pacman -Q"
	local CACHENAME="get_current_packages"
	local RESULT="$(cacheableResult "$COMMAND" "$CACHENAME")"
	echo "$RESULT"
}

generate_wallpaper () {
	cd /tmp
	local all_pks # delcare before setting to insure exit code is picked, otherwise bash will first set then make local which will allways exit with 0
	local outdated
	local ret_code
	local up_to_date=0
	all_pks="$(get_current_packages | tr '\n' ' ')"
	local COMMAND="get_outdated_packages"
	local CACHENAME="get_outdated_packages"
	outdated="$(cacheableResult "$COMMAND" "$CACHENAME")"
	ret_code=$?
	# if get_outdated_packages failed, dont remove the existing wallpaper with an empty one
	if [ $ret_code -eq 1 ]; then
		# error code 1 indicates failed attempt to check for updates
		return 1
	fi
	if [ $ret_code -eq 2 ]; then
		# up to date
		up_to_date=1
	else
		outdated="$(echo $outdated | tr --d '\n')"
		outdated="${outdated::-1}"	# remove last semicolon to avoid marking new value when there is none
	fi
	# add get parameters
	RENDER_URL="file://$INSTALL_PATH/render.html?"
	RENDER_URL="${RENDER_URL}pkg_list=$all_pks"
	if [ $up_to_date -eq 0 ]; then
		RENDER_URL="${RENDER_URL}&outdated=$outdated"
	fi
	RENDER_URL="${RENDER_URL}&outdated=$outdated"
	RENDER_URL="${RENDER_URL}&height=$IMAGE_SIZE_Y"
	RENDER_URL="${RENDER_URL}&width=$IMAGE_SIZE_X"
	RENDER_URL="${RENDER_URL}&bg_color=${config[background-color]}"
	RENDER_URL="${RENDER_URL}&pkg_color=${config[package-color]}"
	RENDER_URL="${RENDER_URL}&old_color=${config[old-package-color]}"
	RENDER_URL="${RENDER_URL}&font=${config[font-family]}"
	# generate image of background text
	# chromium spams lots of undesired output while attempting to use gpu acceleration. to avoid that output is redirected to /dev/null
	chromium --headless --hide-scrollbars --window-size=$IMAGE_SIZE --screenshot=$IMG_NAME "$RENDER_URL" &> /dev/null
	# add logo to the background
	magick $IMG_NAME -size $(expr $IMAGE_SIZE_X \* $LOGO_SIZE_PRECENT / 100)x -background none ${config[logo-image]} -gravity center -extent $IMAGE_SIZE -layers flatten $IMG_NAME
	# move the created wallpaper to user folder
	mkdir -p $WALLPAPER_PATH
	mv $IMG_NAME $WALLPAPER_PATH
}

# set xfce4 wallpaper for user using xfconf-query
set_wallpaper () {
local PRIMARY_DISPLAY=$(get_primary_display)
xfconf-query \
  --channel xfce4-desktop \
  --property "/backdrop/screen0/monitor${PRIMARY_DISPLAY}/workspace0/last-image" \
  --set $WALLPAPER_PATH/$IMG_NAME
}

enable_timer () {
	systemctl --user enable fox-neat-wallpaper.service
	systemctl --user enable fox-neat-wallpaper.timer
	systemctl --user start fox-neat-wallpaper.service
	systemctl --user start fox-neat-wallpaper.timer
}

disable_timer () {
	systemctl --user disable fox-neat-wallpaper.service
	systemctl --user disable fox-neat-wallpaper.timer
	systemctl --user stop fox-neat-wallpaper.timer
}

help_msg () {
	echo "Usage: fox-neat-wallpaper [action]"
	echo ""
	echo "Actions:"
	echo "    update: update current wallpaper image based on current installed packages for current user"
	echo "    set:    automaticly set as background in xfce4 for current user"
	echo "    all:    runs both update and set"
	echo "    enable-timer:		enable a timer to auto-update the wallpaper for current user"
	echo "    disable-timer:	disable a timer to auto-update the wallpaper for current user"
}

# update user values
get_display_resolution
get_wallpaper_user_path
get_user_config_path
# get config
get_config_file

case "$1" in
	"update")
	generate_wallpaper
	;;
	"set")
	set_wallpaper
	;;
	"all")
	generate_wallpaper
	set_wallpaper
	;;
	"enable-timer")
	enable_timer
	;;
	"disable-timer")
	disable_timer
	;;
	"help")
	help_msg
	;;
	*)
	echo "unkown command - use help for available actions"
esac
