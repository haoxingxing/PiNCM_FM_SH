#!/bin/bash
#requirement: curl jq wget ffmpeg
clear
echo "[Initialization]Start"
PIFM_BIN_NAME="fm_transmitter" #https://github.com/somu1795/fm_transmitter
PIFM_BIN_WHERE="./"
PIFM_FREQ="99.9"

API_Server="localhost:3000" #https://github.com/Binaryify/NeteaseCloudMusicApi
PlayListID="510113940"

TMP_FILE=".playlist.json"
MusicIDArray=""
MusicDir=".music"

allseconds=0;
all=0

if [ ! -d "${MusicDir}" ]; then
    mkdir ${MusicDir}
fi

echo "[Initialization]Done"

processbar() {
    local current=$1;
    let "current=current+1"
    local total=$2;
    local maxlen=$(tput cols);
    local maxlen=$((maxlen/10*7))
    local barlen=$((maxlen));
    local perclen=$((maxlen/10*4));
    local format="%-${barlen}s%$((maxlen-barlen))s"
    local perc="[$current/$total]"
    local progress=$((current*barlen/total))
    local prog=$(for i in `seq 0 $progress`; do printf '#'; done)
    printf "\r\033[33;1m[$format\033[0m" $prog "]"$perc
}
UpdatePlayList()
{
    echo -e "\033[33;1m[PlayList]Updating\033[0m"
    echo $(curl --silent --show-error --fail ${API_Server}"/playlist/detail?id="${PlayListID}) > ${TMP_FILE}
    loop=0
    all=$(jq -r '.playlist.trackIds|length' ${TMP_FILE})
    MusicIDArray[${loop}]=$(jq -r '.playlist.trackIds['${loop}']' ${TMP_FILE})
    files=""
    processbar -1 $all
    while (( $loop<$all ))
    do
        MusicIDArray[${loop}]=$(jq -r '.playlist.trackIds['${loop}'].id' ${TMP_FILE})
        if [ ! -f  "${MusicDir}/${MusicIDArray[${loop}]}.mp3" ];
        then
            $(wget http://music.163.com/song/media/outer/url?id=${MusicIDArray[${loop}]}.mp3 -O ${MusicDir}/${MusicIDArray[${loop}]}.mp3 --quiet -c)
        fi
        files=${files}"|${MusicDir}/${MusicIDArray[${loop}]}.mp3"
        processbar $loop $all
        let "loop++"
    done
    echo ""
    if [  -e "${MusicDir}/all.wav" ]; then
	if [ "$(cat .music_last_succ)"x == "${files}"x ]; then
	 echo  -e "\033[32;1m[PlayerList] NothingChanged\033[0m"
        else
         $(rm -rf ${MusicDir}/all.wav)
         echo -e "\033[34m[PlayList]Merge Music Files\033[0m"
         $(ffmpeg -i "concat:${files:1}" -loglevel panic -c:a copy -c:v copy -f s16le -ar 22.05k -ac 1 ${MusicDir}/all.wav)
	 echo ${files} > .music_last_succ
        fi
    else
       echo -e "\033[34m[PlayList]Merge Music Files\033[0m"
       $(ffmpeg -i "concat:${files:1}" -loglevel panic -c:a copy -c:v copy -f s16le -ar 22.05k -ac 1 ${MusicDir}/all.wav)
       echo ${files} > .music_last_succ
    fi
    alltime=$(ffmpeg -i ${MusicDir}/all.wav 2>&1 | grep 'Duration' | cut -d ' ' -f 4 | sed s/,//)
    ifs_backup=$IFS
    IFS=: DIRS=($alltime)
    declare -p DIRS > /dev/null 2>&1
    IFS=$ifs_backup
    s0=$(echo ${DIRS[0]}| awk '{print int($0)}')
    s1=$(echo ${DIRS[1]}| awk '{print int($0)}')
    s2=$(echo ${DIRS[2]}| awk '{print int($0)}')
    allseconds=$[$[$s0*3600]+$[$s1*60]+$s2]
    echo -e "\033[33m[PlayList]All ${allseconds} sec.\033[0m";
    echo -e "\033[32;1m[PlayList]Done\033[0m"
}
while true
do

    clear
    UpdatePlayList
    loopandreupdate=0
    echo -e "\033[37;1m[Player]Playing\033[0m"
    while (( $loopandreupdate<3 ))
    do
        sn=0
        #$(echo "87940733" | sudo -S "${PIFM_BIN_WHERE}${PIFM_BIN_NAME}" "-f" ${PIFM_FREQ} " -r "${MusicDir}/"all.wav"& )
        while (( ${sn}<${allseconds} ))
        do
            processbar ${sn} ${allseconds}
            sleep 1
            let "sn++"
        done
        #echo "87940733" | sudo -S killall ${PIFM_BIN_NAME}
        echo -e "\033[37;1m[Player]$((3-${loopandreupdate})) loop(s) left to refresh the song list\033[0m"
        let "loopandreupdate++"
    done
done
