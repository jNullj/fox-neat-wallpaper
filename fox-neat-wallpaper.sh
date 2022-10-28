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
	if [ $ret_code -ne 0 ] && [ $ret_code -ne 2 ]; then
		# signal there is an issue and stop wallpaper rewrite
		return 1
	fi
	echo "$updates_output" | while read -r pkgname old_ver arrow new_ver; do
		echo "$pkgname $old_ver;"
	done
}

get_current_packages () {
	echo "$(pacman -Q)"
}

generate_wallpaper () {
	cd /tmp
	local all_pks # delcare before setting to insure exit code is picked, otherwise bash will first set then make local which will allways exit with 0
	local outdated
	all_pks="$(get_current_packages | tr '\n' ' ')"
	outdated="$(get_outdated_packages)"
	# if get_outdated_packages failed, dont remove the existing wallpaper with an empty one
	if [ $? -ne 0 ]; then
		# checkupdates might fail (for example if there is no network)
		# if that happends there is no point in updating anything
		return 1
	fi
	outdated="$(echo $outdated | tr --d '\n')"
	outdated="${outdated::-1}"	# remove last semicolon to avoid marking new value when there is none
	# generate image of background text
	# chromium spams lots of undesired output while attempting to use gpu acceleration. to avoid that output is redirected to /dev/null
	chromium --headless --hide-scrollbars --window-size=$IMAGE_SIZE --screenshot=$IMG_NAME "file://$INSTALL_PATH/render.html?pkg_list=$all_pks&outdated=$outdated&height=$IMAGE_SIZE_Y&width=$IMAGE_SIZE_X&bg_color=${config[background-color]}&pkg_color=${config[package-color]}" &> /dev/null
	# add logo to the background
	convert $IMG_NAME -size $(expr $IMAGE_SIZE_X \* $LOGO_SIZE_PRECENT / 100)x -background none $INSTALL_PATH/logo.svg -gravity center -extent $IMAGE_SIZE -layers flatten $IMG_NAME
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
