#!/bin/bash
INSTALL_PATH=/opt/fox-neat-wallpaper

check_user_uses_xfce () {
	if  [ -d "/home/$1/.config/xfce4" ]
	then
		return 0
	else
		return 1
	fi
}

check_user_uses_app () {
	if  [ -d "/home/$1/.fox-neat-wallpaper" ]
	then
		return 0
	else
		return 1
	fi
}

run_per_user () {
	getent passwd | while IFS=: read -r name password uid gid gecos home shell; do
		if check_user_uses_xfce $name && check_user_uses_app $name
		then
			echo "generating wallpaper for $name"
			su $name -c "$shell $1"
		fi
	done
}

run_per_user "$INSTALL_PATH/fox-neat-wallpaper.sh all"