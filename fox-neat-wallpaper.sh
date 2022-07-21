#!/bin/bash
IMG_NAME=fox-neat-wallpaper.png
WALLPAPER_PATH=$HOME/.fox-neat-wallpaper
INSTALL_PATH=/opt/fox-neat-wallpaper
IMAGE_SIZE_X=1920
IMAGE_SIZE_Y=1080
IMAGE_SIZE=${IMAGE_SIZE_X}x${IMAGE_SIZE_Y}
LOGO_SIZE_PRECENT=60

# reset those when running from root shell
# this is added for usage of xfconf-query
# otherwise dbus query from user as root fails
export XDG_RUNTIME_DIR="/run/user/$UID"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# functions to refresh/update global veriables about the user/system

get_display_resolution () {
	IMAGE_SIZE=$(xfconf-query -c displays -p /Default/eDP/Resolution)
	IMAGE_SIZE_X=$(echo $IMAGE_SIZE | cut -d'x' -f1)
	IMAGE_SIZE_Y=$(echo $IMAGE_SIZE | cut -d'x' -f2)
}

get_wallpaper_user_path () {
	WALLPAPER_PATH=$HOME/.fox-neat-wallpaper
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
		echo "$pkgname"
	done
}

get_current_packages () {
	echo "$(pacman -Q)"
}

# generate a list of all installed packages with outdated packages marked in red using pango supported tags
html_mark_outdated_packages () {
	local color="red"
	local packages="$(get_current_packages)"
	local outdated # delcare before setting to insure exit code is picked, otherwise bash will first set then make local which will allways exit with 0
	outdated="$(get_outdated_packages)"
	if [ $? -ne 0 ]; then
		# checkupdates might fail (for example if there is no network)
		# if that happends there is no point in updating anything
		return 1
	fi
	if [ -z "$outdated" ]; then
		# if empty avoid running the while loop
		# as sed would fit any string for empty $oldpkg
		# also avoid spending any additional time on marking red text, as there is none
		packages=$(echo $packages | tr '\n' ' ')
		echo "$packages"
		return
	fi
	while read -r oldpkg; do
		packages="$( echo "$packages" | sed 's,\('^"$oldpkg"'.*$\),<span foreground="'"$color"'">\1</span>,' )"
	done <<< "$(echo "$outdated")"
	packages=$(echo $packages | tr '\n' ' ')	# change newline to spaces for rendering the image
	echo "$packages"
}

generate_wallpaper () {
	cd /tmp
	local pango_text # delcare before setting to insure exit code is picked, otherwise bash will first set then make local which will allways exit with 0
	pango_text="$(html_mark_outdated_packages)\n"	# newline at the end for the justify to space out the last line
	# if html_mark_outdated_packages failed, dont remove the existing wallpaper with an empty one
	if [ $? -ne 0 ]; then
		return 1
	fi
	# generate image of background text
	convert -background black -fill green -font Liberation-Mono -size $IMAGE_SIZE -define pango:justify=true pango:"$pango_text" $IMG_NAME
	# add logo to the background
	convert $IMG_NAME -size $(expr $IMAGE_SIZE_X \* $LOGO_SIZE_PRECENT / 100)x -background none $INSTALL_PATH/logo.svg -gravity center -extent $IMAGE_SIZE -layers flatten $IMG_NAME
	# move the created wallpaper to user folder
	mkdir -p $WALLPAPER_PATH
	mv $IMG_NAME $WALLPAPER_PATH
}

# set xfce4 wallpaper for user using xfconf-query
set_wallpaper () {
xfconf-query \
  --channel xfce4-desktop \
  --property /backdrop/screen0/monitoreDP/workspace0/last-image \
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
