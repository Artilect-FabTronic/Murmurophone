#!/bin/bash
#Project description
# Aim: an antique phone booth where people can hear and share their 'life story'. Will travel in the whole country
# When a person picks up the phone:
# 1. A random story is played from the collection of stories.
# 2. A prerecorded announcement tells people they will have 3 minutes to record their life story, or they can hang up then pickup to hear another one
# 3. The person is recorded
# 4. A prerecorded thank you message is played. People are invited to hang up.
#This project must use background tasks, because one must regularly check the state of the phone to see if the phone is hanged up. 
#On hanged up
# if a story is being read, kill the read process
# if an announcement is being read, kill the read process
# if a story is being recorded, kill the recording process

reinteger='^[0-9]+$'
storymaxseconds=180
storiespath="/mnt/usbhdd/stories/"
#in case one doesn't want to play new stories not vetted by the person in charge, this could be another folder
newstoriespath="/mnt/usbhdd/newstories/"
lastplayedstory=""
storytoplay=""
announcement=""
#announcementspath="/media/pi/CM16/announcements/"
announcementspath="/home/pi/announcements/"
newstoryfilename=""
sessionpid=""

announcementtoplay=""
error=false
usbkeynotfound=false
isInSession=false
# !! cbm gpio vs wiring gpiO. gpio readall
#phonepickeduppin=17 bcm -> 0 wiringPi
#buttonpin=27 bm -> 2 wiringPi
phonepickeduppin=0
buttonpin=2

isphonepickedup=false
isbuttonpressed=false
phonepickedup=0
buttonpressed=0
configisbuttonenabled=false
errormessage=""
DEBUG=on
#DEBUG=


function debecho () {
if [ ! -z "$DEBUG" ]; then
	echo "$1" >&2
#         ^^^ to stderr
fi
}

# Ignoring the case of the randomfile is the same as the previously played one
function randomstory() {
if [[ -d $storiespath ]] ; then	
		storytoplay=$(ls $storiespath | sort -R | head -1)
	else
		debecho  "Error: folder $storiespath not found"
	fi
	
}

function playstory() {
if [[ $storytoplay != "" ]] ; then
	local storyfile=$storiespath$storytoplay
	if [[ -f $storyfile ]] ; then
		debecho "reading $storytoplay"
		play $storyfile
	else
		debecho "Error: file $storytoplay not found"
	fi
else
	debecho "error: no story to read"
fi
}

function playannouncement() {
if [[ $announcement != "" ]] ; then
	local announcementfile=$announcementspath$announcement
	if [[ -f $announcementfile ]] ; then
		play $announcementfile
	else
		debecho "Error: file $announcement not found"
	fi
else
	debecho "error: no announcement to read"
fi
}

function newfilename() {
	newstoryfilename=$(date "+%Y%m%d-%H%M%S")
}
function recordstory() {
	newfilename
	newstoryfilename="$newstoriespath$newstoryfilename.mp3"
	debecho "Will record to: $newstoryfilename"
	rec -t mp3 -c 1 $newstoryfilename trim 0 $storymaxseconds
}


function launchsession() {
	debecho "Entered function launchsession"
	randomstory
	playstory
	announcement="murmurophoneenregistrer.mp3"
	playannouncement
	announcement="beep-09.wav"
	playannouncement
  	recordstory
	announcement="murmurophonemerci.mp3"
	playannouncement
	isInSession=false
}

function cleanupsession
{
	timestamp=$(date +%s)
	debecho "$timestamp Entered function cleanupsession"
	debecho '$$'
	debecho $$
	debecho '$!'
	debecho $!
	debecho "sessionpid=$sessionpid"
	$(kill -0 $sessionpid > /dev/null 2>&1)
	debecho "status of kill sessionpid $?"
	if [[ $? == 0  ]]; then
			kill $sessionpid
			killall "rec"
			killall "play"
	fi

	# the following line won't work because child processes cannot modify parent variables'
	#isInSession=false
}

#init
gpio mode $phonepickeduppin in
if [[ $configisbuttonenabled == true ]]; then
	gpio mode $buttonpin in
fi


#main forever loop
isInSession=false
while [ 1 ]
do
	timestamp=$(date +%s)
	phonepickedup=$(gpio read $phonepickeduppin )
	debecho "$timestamp main loop. isInSession=$isInSession"
	#Phone is picked up
	if [[ $phonepickedup == 1 ]]; then
		debecho "Phone is picked up"
		if [[ $isInSession == false ]]; then
			isInSession=true
			launchsession &
			sessionpid=$!
			debecho "$timestamp Launched session $sessionpid"
		else
			#Is isInSession really true? If we completed a complete session, no
			$(kill -0 $sessionpid > /dev/null 2>&1)
			debecho "status $?"
		fi
	
	#phone is hanged up
	else
		debecho "Phone is hanged up"
		if [[ $isInSession == true ]]; then
			#we need to find whether the session is finished or not, since session can't change parent variable^$isInSession
			$(kill -0 $sessionpid > /dev/null 2>&1)
			debecho "status $?"
			if [[ $? == 0  ]]; then
				cleanupsession
				isInSession=false
			fi
		else
			:
		# There is nothing to do: the phone is hanged up and no session is active
		fi
	fi

	#phone is hanged up
	sleep 1
done
