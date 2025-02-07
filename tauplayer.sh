#!/bin/bash
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
#               Terminal Audio (tau) Player
#         Copyright (c) 2024 <jarvenja@gmail.com>
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#

# About principles
# - bash scripting has somewhat different rules than programming languages
# - ...

about () {
	resetScreen "About"
	print "Terminal Audio Player (${APP_NAME})\n\n"
	print "The current version is ${VERSION}\n\n"
	print "${COPYRIGHT}\n\n"
	print "Features:\n\n"
	print "> Easy playing local playlists\n"
	print "> Easy playing radio streams\n"
	print "> Managing named collections of streams\n"
	print "> Playback support via mplayer\n\n"
	print "- Does not support spaces in file names.\n\n"
	print "Your terminal type is '${TERM}',\n"
	print "which may affect to display correct UI colors."
	inputKey
}

addStream () { # validName validUrl
	local err file
	file=$(getCollectionPath)
	err=$(echo "${1},${2}" >> "${file}")
	echo "${err}"
}

# FixMe! Some extra text visible
archive () { # collection
	local bak f
	f=$(getCollectionPath "${1}")
	bak=$(getBackupPath "${1}")
	if mv -v "${f}" "${bak}" >/dev/null; then
		inform "${1} archived."
	else
		inform "Cannot remove ${1}!"
	fi
}

changePlaylistDir () {
	resetScreen "Change Playlist Directory"
	print "Type full path to existing directory\n\n"
	while :; do
		read -r -p "> New directory: " -i "${PLAYLIST_DIR}" -e dir
		if [ -z "${dir}" ] || [ "${dir}" == "${PLAYLIST_DIR}" ]; then
			clearMsg
			return
		fi
		if [ -d "${dir}" ]; then
			PLAYLIST_DIR="${dir}"
			inform "Playlist directory changed."
			return
		fi
	done
}

clearMsg () {
	MSG=""
}

collectionMenu () { # action
	local c line
	local -a entries
	while read -r line; do
		c="${line##*/}"
		c="${c%.cvs}"
		entries+=("${c}" "")
	done < <(find "${COLLECTION_DIR}" -name "*.cvs" | sort)
    [ "${#entries[@]}" -eq 0 ] && fatal "No collections found in ${COLLECTION_DIR}."
	clearMsg
	tput civis # hides cursor
	c=$(dialog \
		--stdout \
 		--backtitle "$(getTitle)" \
 		--title " ${1} Collection " \
 		--clear \
		--cancel-label "Cancel" \
		--ok-label "Select" \
		--menu "\n${MSG}" 0 0 16 \
		"${entries[@]}"
	)
	if [ "$?" -eq 0 ]; then
		case "${1}" in
			Change) COLLECTION="${c}" ;;
			Remove) archive "${c}" ;;
			*) invalidArg "${1}" ;;
		esac
	fi
	tput cnorm # unhide cursor
}

createCollection () { # validName
	local f
	f=$(getCollectionPath "${1}")
	if [ -f "${f}" ]; then
		fatal "File ${f} already exists!"
	else
		touch "${f}"
		[ $? -ne 0 ] && fatal "Couldn\'t create collection ${1}!"
	fi
}

die () {
	popd > /dev/null
	tput cnorm
	tput init
	clear
	saveSettings
	echo "Bye!"
}

ensureBash () {
	local t
	t=$(getShellType)
	[ "${t}" != "bash" ] && fatal "Must be run by bash instead of ${t}"
}

ensureCfg() {
  [ -f "${DIALOGRC}" ] || fatal ".dialogrc file not found in directory!"
  eval command -v mplayer &>/dev/null
  [ $? -eq 0 ] && PLAYER="mplayer" || fatal "Please install required 'mplayer' first."
  [ -d "${COLLECTION_DIR}" ] || mkdir -p "${COLLECTION_DIR}"
  if [ -f "${SETTINGS}" ]; then
    loadSettings "${SETTINGS}"
  else # ensure tauplayer.cvs and ./collections/favorites.cvs
    touch $(getCollectionPath "${COLLECTION1}")
    COLLECTION="${COLLECTION1}"
    PLAYLIST_DIR="${HOME}"
    saveSettings
  fi
}

ensureDir () { # dir
	[ -d "${1}" ] || fatal "Invalid directory ${1}!"
}

ensureFile () { # file
	[ -f "${1}" ] || fatal "File ${1} not found!"
}

ensureInternet () {
	local code
	code=$(getHttpResponseStatus "${GG}")
	[ "${code}" -eq 200 ] || fatal "No connection available to reach ${GG}!"
}

error () { # msg
	echo -ne "  ${YELLOW}Error: ${1}${FG0}" >&2
}

fail () { # reason
	echo -ne " ${YELLOW}[${1}]" # ${COFF}"
	inputKey
}

fatal () { # msg
	echo -e "${RED}Fatal Error: ${1}${FG0}" >&2
	exit 1
}

getBackupPath () { # collectionName
	local initial path
	initial="${COLLECTION_DIR}/${1}"
	path="${initial}.bak"
	for ((i=1; -f "${path}" ;i++)); do
		path="${initial}-${i}.bak"
	done
	echo "${path}"
}

getCollectionPath () { # [collectionName]
	echo "${COLLECTION_DIR}/${1:-${COLLECTION}}.cvs"
}

# Based on https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#server_error_responses
getHttpResponseName () { # code
	[ $# -eq 1 ] || wrongArgCount "$@"
  	case "${1}" in
		000) echo "No response" ;;
    	100) echo "Continue" ;;
     	101) echo "Switching Protocols" ;;
     	102) echo "Processing" ;;
     	103) echo "Early Hints" ;;
 		200) echo "OK" ;;
     	201) echo "Created" ;;
		202) echo "Accepted" ;;
 		203) echo "Non-Authoritative Information" ;;
 		204) echo "No Content" ;;
 		205) echo "Reset Content" ;;
 		206) echo "Partial Content" ;;
 		300) echo "Multiple Choices" ;;
 		301) echo "Moved Permanently" ;;
 		302) echo "Found" ;;
 		303) echo "See Other" ;;
		304) echo "Not Modified" ;;
 		305) echo "Use Proxy" ;;
 		306) echo "Status not defined" ;;
 		307) echo "Temporary Redirect" ;;
 		308) echo "Permanent Redirect" ;;
		400) echo "Bad Request" ;;
		401) echo "Unauthorized" ;;
		402) echo "Payment Required" ;;
		403) echo "Forbidden" ;;
		404) echo "Not Found" ;;
		405) echo "Method Not Allowed" ;;
		406) echo "Not Acceptable" ;;
		407) echo "Proxy Authentication Required" ;;
		408) echo "Request Timeout" ;;
 		409) echo "Conflict" ;;
 		410) echo "Gone" ;;
		411) echo "Length Required" ;;
 		412) echo "Precondition Failed" ;;
 		413) echo "Request Entity Too Large" ;;
 		414) echo "Request-URI Too Long" ;;
 		415) echo "Unsupported Media Type" ;;
 		416) echo "Requested Range Not Satisfiable" ;;
 		417) echo "Expectation Failed" ;;
 		418) echo "I'm a teapot" ;;
 		421) echo "Misdirected Request" ;;
 		422) echo "Unprocessable content" ;;
 		423) echo "Locked" ;;
 		424) echo "Failed Dependency" ;;
 		425) echo "Too Early" ;;
 		426) echo "Upgrade Required" ;;
 		428) echo "Precondition Required" ;;
 		429) echo "Too Many Requests" ;;
 		431) echo "Request Header Fields Too Large" ;;
 		451) echo "Unavailable For Legal Reasons" ;;
 		500) echo "Internal Server Error" ;;
 		501) echo "Not Implemented" ;;
 		502) echo "Bad Gateway" ;;
 		503) echo "Service Unavailable" ;;
 		504) echo "Gateway Timeout" ;;
 		505) echo "HTTP Version Not Supported" ;;
		506) echo "Variant Also Negotiates" ;;
		507) echo "Insufficient Storage" ;;
		508) echo "Loop Detected" ;;
		510) echo "Not Extended" ;;
		511) echo "Network Authentication Required" ;;
     	*) echo "Undefined" ;; # Non-standard or customized
	esac
}

getHttpResponseStatus () { # url
	local code
	code=$(curl -o /dev/null --silent --head --write-out "%{http_code}\n" "${1}")
	echo "${code}"
}

getKeyValue () { # key
	local f value
	f=$(getCollectionPath "${COLLECTION}")
	ensureFile "${f}"
	value=$(grep "${1}," "${f}" | cut -d"," -f2-)
	echo "${value}"
}

getShellType () {
	local x
	x=$(ps -p $$)
	echo "${x##* }"
}

getTitle () {
	echo -ne "${BGR} ${APP_NAME} ${VERSION} -=- [${COLLECTION}]"
}

haspace () { # str
	[[ ${1} =~ [[:space:]]+ ]]
}

horizon () { # [width]
	local -i n
	n="${1:-$(tput cols)}"
	# echo -ne "${BBG}"
	while ((n-- > 0)); do
		printf "${DASH}"
	done
}

inform () { # msg
	MSG="-> ${1}"
}

informUnavailability () { # streamName url code
	local responseName
	[ $# -eq 3 ] || wrongArgCount "$@"
	resetScreen "Stream Not Available"
	print "Pre-check failed with the following details:\n\n"
	print "Type: Stream\n"
	print "Name: ${1}\n"
	print " URL: ${2}\n\n"
	responseName=$(getHttpResponseName "${code}")
	print "HTTP ->"
	fail "${code} ${responseName}"
}

inputKey () {
	echo; echo
	print ">> Press a key to continue..."
	read -rsn 1
}

inputNewCollection () {
	local file key name
	key="?"
	name=""
	resetScreen "New Collection"
	print "Type an unique name for collection.\n"
	print "- Only letters, numbers and dash (-) are allowed.\n"
	print "- Use left arrow [<-] to remove last.\n\n"
	print "> Collection Name: "
	# TODO add cancel key
	IFS=
	while [ "${key}" != '' ]; do
		read -rsn 1 key
		if [ "${key}" == ${ESC} ]; then
			read -rsn 2 key
			if [[ -n "${name}" && "${key}" == '[D' ]]; then
				echo -ne "\b \b"
				name="${name::-1}"
			fi
		else
			if [[ "${key}" =~ ${FILENAME_CHAR} ]]; then
				name+="${key}"
				echo -ne "${key}"
			fi
		fi
	done
	[ -z "${name}" ] && return
	file=$(getCollectionPath "${name}")
	if [ -f "${file}" ]; then
		fail "Already exists"
	else
		createCollection "${name}"
		COLLECTION="${name}"
	fi
}

# FixMe prevent invalid name characters
inputNewStream () {
	local err name url
	resetScreen "Add New Stream"
	print "Type an unique name and URL or leave blank to cancel\n\n"
	print "x Collection: ${COLLECTION}\n"
	while :; do
		read -r -p " > Name: " name
		case "${name}" in
			'') return ;;
			"*[,;]*") fail "Invalid characters" ;;
			*) break ;;
		esac
	done
	url=$(getKeyValue "${name}")
	if [ -n "${url}" ]; then fail "Already exists"
	else
		read -r -p " > URL: " url
		if [ -n "${url}" ]; then
			# TODO $(checkUrl url)
			err=$(addStream "${name}" "${url}")
			[ -z "${err}" ] && print "Stream added.\n" || fatal "${err}"
			inputKey
		fi
	fi
}

invalidArg () { # arg
	fatal "Invalid argument '${1}' in ${FUNCNAME[1]}"
}

loadSettings () { # settingsFile
	local collection file pld
	IFS=, read collection pld < "${1}"
	[ -d "${pld}" ] && PLAYLIST_DIR="${pld}" || PLAYLIST_DIR="${HOME}"
	COLLECTION="${COLLECTION1}"
	if [[ -n "${collection}" ]]; then
		file=$(getCollectionPath "${collection}")
		[ -f "${file}" ] && COLLECTION="${collection}"
	fi
}

log () { # msg
	[ "${LOGGING}" == true ] && echo "${1}" >> "${LOG}"
}

mainMenu () {
	local -a menu
	local action choice
	while :; do
		menu=( \
			"v" "Audio Settings..." \
			"k" "View Music Player Controls..." \
			"p" "Change Playlist directory..." \
			"c" "Change Collection..." \
			"n" "Create New Collection..." \
			"r" "Remove Collection from list..." \
			"o" "Play list in order..." \
			"s" "Play shuffled list..." \
			"t"	"Play Stream..."
			"m" "Module information is $(printBool ${MODULE_INFO})" \
			"h" "Player cache is $(printBool ${USE_CACHE})" \
			"a" "Add New Stream..." \
			"u" "Update Stream..." \
			"d" "Remove Stream..." \
			"i" "About ${APP_NAME}..."
		)
		tput civis # hide cursor
		choice=$(dialog \
			--stdout \
			--backtitle "$(getTitle)" \
			--title " Options " \
			--clear \
			--cancel-label "Exit" \
			--ok-label "Select" \
			--menu "\n${MSG}" 0 44 16 \
 			"${menu[@]}"
			)
    	[ $? -ne 0 ] && break
		tput cnorm
		OPTIONS=()
		case "${choice}" in
			i) about ;;
	    	v) alsamixer ;;
			k) printFullKeys ;;
			p) changePlaylistDir ;;
			c) collectionMenu "Change" ;;
			n) inputNewCollection ;;
			r) collectionMenu "Remove" ;;
			t) action="Listen" ;;&
			u) action="Update" ;&
			t|u) streamMenu "${action}" ;;
			a) inputNewStream ;;
			d) streamMenu "Remove" ;;
			m) toggleModuleInfo ;;
			h) toggleCache ;;
			s) OPTIONS+=("-shuffle") ;&
			o|s) playList ;;
			*) invalidArg "${choice}" ;;
		esac
	done
	tput cnorm # unhide cursor
}

play () { # playlist|name url
	local keys label line mp3floats prev
	if [ "${1}" = "${PLAYLIST}" ]; then
		keys="printLocalKeys"
		label="[>]"
	else
		keys="printStreamKeys"
		label="(( A ))  ${1} @"
	fi
	$(echo -ne mplayer -msgcolor -quiet -noautosub -nolirc -ao alsa -afm ffmpeg "${OPTIONS[@]}" "${2}") |
	{	echo
		mp3floats=false
		prev=""
		while IFS= read -r line; do
			if [[ "${line}" == *"[mp3float"* ]]; then
				if [ "${mp3floats}" == false ]; then
					error "Bad audio quality (mp3float)!"
					mp3floats=true
				fi
			else
				case "${line}" in
					Playing*) # new screen for each...
						resetScreen "${PLAYER}"
						($keys)
          				echo -ne "\n${BAR} ${label} ${2} ${BG0}\n"
						;;
					'') ;;
					*"="*|*"audio codec"*|*AO:*|*AUDIO:*|*"ICY Info:"*|*libav*|*Video:*)
						[ "${MODULE_INFO}" == true ] && print "${line}"
						;;
					*)	if [ "${line}" == "${prev}" ]; then
							echo -ne "${YELLOW}|"
						else
							echo -ne "\n ${line} "
							prev="${line}"
						fi
						;;
				esac
			fi
  		done
	}
}

# FixMe!
playList () {
	local url
	url=$(playlistMenu)
	if [ -n "${url}" ]; then
		[ "${USE_CACHE}" == true ] && OPTIONS+=(-cache "${CACHE_SIZE}" -cache-min "${CACHE_MIN}")
		OPTIONS+=(-playlist)
		printf '%s\n' "${OPTIONS[@]}"
		# log "playList <1> ${url}"
		play "${PLAYLIST}" "${url}"
	fi
}

playlistMenu () {
	local f
	local -a entries
	while read -r line; do
		haspace "${line}" || entries+=("${line}" "")
	done < <(find "${PLAYLIST_DIR}" -name "*.m3u" | sort)
	if [[ "${#entries[@]}" -eq 0 ]]; then
		MSG="No playlists found."
	else
		clearMsg
		tput civis # hide cursor
		f=$(dialog \
			--stdout \
			--clear \
			--backtitle "$(getTitle)" \
			--title " Listen Playlist " \
			--cancel-label "Back" \
			--ok-label "Play" \
			--menu "\n${MSG}" 0 0 16 \
 			"${entries[@]}"
		)
		tput cnorm # unhide cursor
	    [ $? -eq 0 ] && echo "${f}"
	fi
}

playStream() { # name url
  local code
  [ "$#" -eq 2 ] || wrongArgCount "$@"
  clear
  echo -ne "${HIGHLIGHT}Loading...${C0}"
  code=$(getHttpResponseStatus "${2}")
  case "${code}" in
    200|302|400|404|405)
      saveLastPlayedStream "${1}" "${2}"
      play "${1}" "${2}"
      mainMenu
      ;;
    *)
      informUnavailability "${1}" "${2}" "${code}"
      ;;
  esac
}

print () { # line
	# create one space margin
	echo -ne " ${1}"
}

printBool () { # boolStr
	[ "${1}" == true ] && echo 'ON' || echo 'OFF'
}

printFullKeys () {
	resetScreen "${PLAYER} Controls"
	echo -e "${BBG} ${GREEN}$(horizon 6) Track $(horizon 15)"
    printKey "        Stop" "[Esc]"
	printKey "       Pause" "P [Space]"
	printKey "   Prev/Next" "< >"
	printKey "      -/+10s" "<- ->"
	printKey "     -/+1min" "[Up] [Down]"
	printKey "    -/+10min" "[Pg] [PgUp]"
	echo -e "${BBG} ${GREEN}$(horizon 3) Playback Speed $(horizon 9)"
	printKey "        100%" "[BkSp]"
	printKey "         50%" "{"
	printKey "      -/+10%" "[ ]"
	printKey "          x2" "  }"
	echo -e "${BBG} ${GREEN}$(horizon 5) Volume $(horizon 15)"
	printKey "        Vol-" "9 /"
	printKey "        Vol+" "0 *"
	printKey "        Mute" "M"
	printKey "     Balance" "( )"
	echo -e "${BBG} ${GREEN}$(horizon 28)"
	inputKey
}

printKey () { # function key
    echo -ne "${BBG}"
	echo -e " ${GREEN}${1}  ${HIGHLIGHT}${2}${C0}"
}

# FixMe
printLocalKeys () {
	echo -e "${BAR}  Stop  Pause  Prev  Next -10s  +10s -1min  +1min         ${BBG}"
	echo -e "${HIGHLIGHT} [Esc]  [Spc]   [<]  [>]  [<-]  [->]  [Up]  [Down]        ${BBG}"
	echo
	echo -e "${BAR}  100%   50%  -10%  +10%   x2   Vol-  Vol+  Mute  Balance ${BBG}"
	echo -e "${HIGHLIGHT} [BkSpc]  {     [    ]     }    9 /   0 *    M      (  )  ${BBG}"
}

# FixMe
printStreamKeys () {
	echo -e "${BAR}  Stop  Pause  Prev  Next -10s  +10s -1min  +1min          ${BBG}"
	echo -e "${HIGHLIGHT} [Esc]  [Spc]   [<]  [>]  [<-]  [->]  [Up]  [Down]         ${BBG}"
	echo
	echo -e "${BAR}  100%   50%  -10%  +10%   x2   Vol-  Vol+  Mute  Balance  ${BBG}"
	echo -e "${HIGHLIGHT} [BkSpc]  {     [    ]     }    9 /   0 *    M      (  )   ${BBG}"
}

# FixMe!
putStream () { # [name url]
	local action file name new url
	case "$#" in
		0) action="Add New"; new=true ;;
		2) action="Update"; new=false ;;
		*) wrongArgCount "$@" ;;
	esac
	resetScreen "${action} Stream"
	tput cnorm # FixMe! Actual problem code
	read -p "> Name: " -i "${1}" -e name
	read -p ">  URL: " -i "${2:-https://}" -e url
	file=$(getCollectionPath)
	[ new ] && addStream "${name}" "${url}" || $(sed -i "s|${1},${2}|${name},${url}|" "${file}")
	[ $? -eq 0 ] && inform "Stream updated." || fail "Update failed."
}

removeCollection () {
	local c
	c=$(collectionMenu "Remove")
	[ -n "${c}" ] && archiveFile getCollectionPath "${c}"
}

removeKey () { # key value filepath
	$(sed -i '/^$1,/s/.*/${2}/' "${3}")
}

removeStream () { # name url
	local file
	file=$(getCollectionPath)
	$(sed -i "/${1}/d" "${file}")
	if [ $? -eq 0 ]; then
		inform "Stream removed."
	else
		fatal "Failed to remove stream '${1}' with data ${2}"
	fi
}

replaceKeyValue () { # key value filepath
	$(sed -i '/^$1,/s/.*/${2}/' "${3}")
	[ $? -eq 0 ] || error "Unable to update key '${1}'!"
}

resetScreen () { # header
	clear
	echo -ne " ${GREEN}> ${APP_NAME} ${VERSION} -=- ${1}\n"
	horizon
	echo; echo
}

saveSettings () {
	$(echo "${COLLECTION},${PLAYLIST_DIR}" > "${SETTINGS}")
	[ $? -eq 0 ] && echo -ne "Settings saved. "
}

start() {
  ensureCfg
  log ">>> ${USER} started on $(date '+%a %d-%m-%Y %T')"
  ensureInternet
  clearMsg
  echo -e "${BBG}"
  if [ "${RESUME}" == true ]; then
    loadLastPlayedStream
  else
    mainMenu
  fi
}

streamMenu () { # action
	local c line name url
	local -i items
	local -a streams=()
	[ "${#1}" -ne 6 ] && fatal "Invalid action '${1}' in call!"
	c=$(getCollectionPath)
	while IFS=";" read -r line; do
		name="${line%%,*}"
		[ -n "${name}" ] && streams+=("${name}" "${line#$name,}")
	done < "${c}"
	items="${#streams[@]}"
 	if [ "${items}" -eq 0 ]; then
		inform "No Streams in collection."
		return
	fi
	clearMsg
	tput civis # hide cursor
	name=$(dialog \
		--stdout \
		--backtitle "$(getTitle)" \
		--title " ${1} Stream " \
		--clear \
		--ok-label "${1}" \
		--menu "\n${MSG}" 0 0 16 \
		"${streams[@]}"
	)
   	if [ $? -eq 0 ]; then
		# get url from array rather than file again
		for ((i=0; i<items; i=i+2)); do
			if [ "${streams[${i}]}" == "${name}" ]; then
				url="${streams[++i]}"
				break
			fi
		done
		case "${1}" in
			Listen) playStream "${name}" "${url}" ;;
			Remove) removeStream "${name}" "${url}" ;;
			Update) updateStream "${name}" "${url}" ;;
			*) invalidArg "${1}" ;;
		esac
	fi
	tput cnorm # unhide cursor
}

# TODO Cancel input
#terminate () {
#	echo "User interruption."
#	quit
#}

toggleCache () {
	[ "${USE_CACHE}" == true ] && USE_CACHE=false || USE_CACHE=true
}

toggleModuleInfo () {
	[ "${MODULE_INFO}" == true ] && MODULE_INFO=false || MODULE_INFO=true
}

usage () {
	echo "*** ${APP_NAME} ${VERSION} - ${COPYRIGHT}"
	echo; echo "First run setup.sh to install missing dependencies."
	echo; echo "Usage: ${0} [--help]"
	echo "        (no args)    starts the application"
	echo "        --help       show this information"
}

wrongArgCount () { # args...
	fatal "Wrong number ($#) of arguments {$@} in ${FUNCNAME[1]}!"
}

saveLastPlayedStream() { # name url
  echo "${1},${2}" > "${LAST_PLAYED_FILE}"
}

loadLastPlayedStream() {
  if [ -f "${LAST_PLAYED_FILE}" ]; then
    IFS=, read -r name url < "${LAST_PLAYED_FILE}"
    playStream "${name}" "${url}"
  else
    fatal "No last played stream found!"
  fi
}


### App info
readonly APP_NAME="tau Player"
readonly COPYRIGHT="Copyright 2024 J. Järvenpää <jarvenja@gmail.com>"
readonly VERSION="v0.1 (beta)"
### Colors
DIALOGRC=".dialogrc"
export DIALOGRC
readonly BAR="\e[0;42m" # key labels
readonly BBG="\e[48;5;0m" # black bg
readonly BG0="\e[49m"
readonly C0="\e[42m"
readonly FG="\e[38;5;"
readonly FG0="\e[39m"
readonly FGC="\e[0;92m" # default
readonly GREEN="\e[38;5;2m" # default text color
readonly RED="\e[1;91m" # error color
readonly HIGHLIGHT="\e[37m" #38;5;248m"
readonly YELLOW="\e[1;93m" # failures, warnings
readonly WHITE="\e[1;97m"
### Special chars
readonly BGR="\u2261"
readonly DASH="\u2500"
readonly ESC=$(printf "\u1b")
### Constant strings
readonly CONFIG_DIR="${HOME}/.config/tauplayer"
readonly COLLECTION_DIR="./collections"
readonly LAST_PLAYED_FILE="${CONFIG_DIR}/last_played_stream.cvs"
readonly COLLECTION1="favorites"
readonly FILENAME_CHAR="[a-zA-Z0-9\-]"
readonly GG="https://www.google.com"
readonly LOG="./tauplayer.log"
readonly PLAYLIST="PLAYLIST;" # placeholder key
### Settings
readonly SETTINGS="${CONFIG_DIR}/tauplayer.cvs"
declare -i -r CACHE_MIN=80
declare -i -r CACHE_SIZE=16384
LOGGING=false
MODULE_INFO=false
USE_CACHE=true
### Main
set -uo pipefail
ensureBash
pushd "${PWD}" >/dev/null
RESUME=false
case "$#" in
  0) start ;;
  1)
    case "${1}" in
      --help) usage ;;
      --resume) RESUME=true; start ;;
      *) invalidArg "${1}" ;;
    esac
    ;;
  *) wrongArgCount "${@}" ;;
esac
