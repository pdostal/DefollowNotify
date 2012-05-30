#!/bin/bash

###############################################################################
# @Author : Ennio Giliberto aka Lightuono / Toshidex
# @Name : Defollow Notify
# @Copyright : 2012
# @Site : http://www.toshidex.org
# @License : GNU AGPL v3 http://www.gnu.org/licenses/agpl.html
###############################################################################

DFN_RC="/usr/local/src/defollownotify/defollownotify.rc"
OAuth_sh=$(which TwitterOAuth.sh)
HOME_IDS="$HOME/.defollownotify"
screen_name=()

(( $? != 0 )) && echo 'Unable to locate TwitterOAuth.sh! Make sure it is in searching PATH.' && exit 1
source "$OAuth_sh"


usage(){

	cat << "USAGE"
        
Use: defollownotify [OPTION]
        
   -B      Enable Bastard Mode - Notification via Twitter

   -v	   Print Version
USAGE

}


load_config() {
	
	[[ ! -d "$HOME/.defollownotify" ]] && mkdir $HOME/.defollownotify
	
	[[ -f "$DFN_RC" ]] && . "$DFN_RC" || echo -e "\n defollownotify.rc: File not found!\n $(exit)"
	
	[[ "$oauth_consumer_key" == "" ]] && echo -e "\n The variable [ oauth_consumer_key ] not found!\n" && exit 1
        [[ "$oauth_consumer_secret" == "" ]] && echo -e "\n The variable [ oauth_consumer_secret ] not found!\n" && exit 1
	[[ "$USER_NAME" == "" ]] && echo -e "\n You have not insert an account Twitter!\n" && exit 1
	[[ ! ("$BASTARD_MODE" == "TRUE" || "$BASTARD_MODE" == "FALSE") ]] && echo -e "\n You have not insert an value BOOLEAN (TRUE|FALSE)!\n" && exit 1

	TO_init

	if [[ "$oauth_token" == "" ]] || [[ "$oauth_token_secret" == "" ]]; then
		TO_access_token_helper
		if (( $? == 0 )); then
			oauth_token=${TO_ret[0]}
			oauth_token_secret=${TO_ret[1]}
			echo "oauth_token='${TO_ret[0]}'" >> "$DFN_RC"
			echo "oauth_token_secret='${TO_ret[1]}'" >> "$DFN_RC"
			echo "Token saved."
		else
			echo 'Unable to get access token'
			exit 1
		fi
	fi
}

print_error() {


	[[ ! -z $1 ]] && echo -e "\e[0;1;31m\n*ERROR:$error\e[m\n" && exit 1
}

convert_ids() {

	name=$(curl -s "https://api.twitter.com/1/users/show.xml?user_id=$1" | grep "<screen_name>" | sed -e 's/<screen_name>//g' -e 's/<\/scre.*//g' -e 's/  //g')
	if [[ "$name" == "" ]]; then
		echo -e "\e[0;1;34mUser [\e[m\e[0;1;31m $1 \e[m\e[0;1;34m] not found.\n\e[m" 
		return
	fi
	screen_name=( ${screen_name[@]} $name )
	
}

compare_ids() {

	list_defollow="$(diff $HOME_IDS/ids.xml $HOME_IDS/ids_new.xml | grep "<" | awk -F'<| ' '{ print $3}')"
	list_follower="$(diff $HOME_IDS/ids.xml $HOME_IDS/ids_new.xml | grep ">" | awk -F'>| ' '{ print $3}')"


	if [[ $list_defollow == "" ]]; then
		echo -e "\n* Info Diff:"
		echo -e "       \e[0;1;34m - New Follower: $(echo "$list_follower" | wc -w) \e[m"
		echo -e "       \e[0;1;31m - New Defollow: $(echo "$list_defollow" | wc -w) :( \e[m\n"
		mv $HOME_IDS/ids_new.xml $HOME_IDS/ids.xml
		exit 0
	else
		echo -e "\n* Info Diff:"
		echo -e "       \e[0;1;34m - New Follower: $(echo "$list_follower" | wc -w) \e[m"
		echo -e "       \e[0;1;32m - New Defollow: $(echo "$list_defollow" | wc -w) :) \e[m"
		
		echo -e "\n* Conversion ID to Nickname: \n"
		i=0
		for ids_index in $list_defollow; do
			convert_ids "$ids_index"
			echo -n "$((++i)).."	
		done
		mv $HOME_IDS/ids_new.xml $HOME_IDS/ids.xml
		echo -n -e "Conversion completed!\n"
	fi

}

create_ids() {

	filename="$1"

	if [[ $filename == "/tmp/ids.xml" ]]; then
			
		#delete the first three rows
		sed -i '1,3d' $filename

		#delete tags <id> and </id>
		sed -i -e 's/<id>//g' -e 's/<\/id>//g' $filename

		#inversion file and delete the first three rows
		tac $filename > /tmp/idsxx.xml
		sed -i '1,2d' /tmp/idsxx.xml
		tac /tmp/idsxx.xml > $filename	
	
		#move temporany file into original directory
		mv $filename $HOME_IDS
		rm /tmp/idsxx.xml
	else	
		#CREATE SECOND FILE IDS
		#delete the first three rows
                sed -i '1,3d' $filename

                #delete tags <id> and </id>
                sed -i -e 's/<id>//g' -e 's/<\/id>//g' $filename

                #inversion file and delete the first three rows
                tac $filename > /tmp/ids_newxx.xml
                sed -i '1,2d' /tmp/ids_newxx.xml
         	tac /tmp/ids_newxx.xml > $filename

                #move temporany file into original directory
                mv $filename $HOME_IDS
                rm /tmp/ids_newxx.xml
	fi
}

download_ids_list() {

	if [ -f $HOME/.defollownotify/ids.xml ]; then
		echo -e "\n* Download ids list.."
 		curl -s -o /tmp/ids_new.xml "https://api.twitter.com/1/followers/ids.xml?cursor=-1&screen_name=$USER_NAME"
		
		local error=$(grep "<error>" /tmp/ids_new.xml | sed -e 's/<error>//g' -e 's/<\/err.*//g') #GET ERROR
		print_error $error
		
		local next_cursor=$(grep "<next_cursor>" /tmp/ids_new.xml | sed -e 's/<next_cursor>//g' -e 's/<\/next.*//g') #GET NEXT_CURSOR
		if [ $next_cursor -eq 0 ]; then
			create_ids "/tmp/ids_new.xml"
			compare_ids
		else
			echo "The number of follower >5000. The function has not implemented!"
			exit 1
		fi
        else
		echo -e "\n* Download ids list.."
                curl -s -o /tmp/ids.xml "https://api.twitter.com/1/followers/ids.xml?cursor=-1&screen_name=$USER_NAME"
		
		local error=$(grep "<error>" /tmp/ids.xml | sed -e 's/<error>//g' -e 's/<\/err.*//g') #GET ERROR
		print_error $error
	
		local next_cursor=$(grep "<next_cursor>" /tmp/ids.xml | sed -e 's/<next_cursor>//g' -e 's/<\/next.*//g') #GET NEXT_CURSOR
		if [ $next_cursor -eq 0 ]; then
			create_ids "/tmp/ids.xml"
		else
			echo "The number of follower >5000. The function has not implemented!"
			exit 1
        	fi
	fi
}


notify_me() {

	lenght=${#screen_name[@]}
	echo ""
	local i=0
	for index in $(seq 0 $lenght); do
		if [ -z ${screen_name[$index]} ]; then exit 0; fi

		if [[ $BASTARD_MODE == "TRUE" ]]; then
			TO_statuses_update '' "News for @$USER_NAME: The user [ @${screen_name[$index]} ] not following you more. http://t.co/RfXKjgbU" ""
			echo -e "\e[0;1;34m$((++i)). [\e[m\e[0;1;31m @${screen_name[$index]}\e[m\e[0;1;34m ] not following you more. Notification sent!\e[m"
		else
			echo -e "\e[0;1;34m$((++i)). [\e[m \e[0;1;31m@${screen_name[$index]}\e[m \e[0;1;34m] not following you more!\e[m"
		fi
	done
}


load_config

while getopts ":Bvh" opt; do
	case $opt in
		"B")
			BASTARD_MODE="TRUE"
		;;
		"v")
			echo -e "\nDefollowNotify - $(cat /usr/local/src/defollownotify/VERSION) \n";
			exit 0
		;;
		"h")
			usage
			exit 0
		;;
		\?)
			usage
			exit 0
		;;
	esac
done

download_ids_list
notify_me

exit 0
