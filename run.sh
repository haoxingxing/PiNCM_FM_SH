#!/bin/bash
#requirement: curl jq wget ffmpeg
#PiFmRds https://github.com/ChristopheJacquet/PiFmRds
clear
echo "[Initialization]Start"
PIFM_BIN="sudo ./pi_fm_rds"
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
    printf "\r[$format" $prog "]"$perc
}
UpdatePlayList()
{
    echo "[PlayList]Updating"
    echo $(curl --silent --show-error --fail ${API_Server}"/playlist/detail?id="${PlayListID}) > ${TMP_FILE}
    loop=0
    all=$(jq -r '.playlist.trackIds|length' ${TMP_FILE})
    MusicIDArray[${loop}]=$(jq -r '.playlist.trackIds['${loop}']' ${TMP_FILE})
    files=""
    while (( $loop<$all ))
    do
        processbar $loop $all
        MusicIDArray[${loop}]=$(jq -r '.playlist.trackIds['${loop}'].id' ${TMP_FILE})
        if [ ! -f  "${MusicDir}/${MusicIDArray[${loop}]}.mp3" ]; 
        then
        $(wget http://music.163.com/song/media/outer/url?id=${MusicIDArray[${loop}]}.mp3 -O ${MusicDir}/${MusicIDArray[${loop}]}.mp3 --quiet -c)
        fi
        files=${files}"|${MusicDir}/${MusicIDArray[${loop}]}.mp3"    
        let "loop++"
    done
    echo ""
    $(rm -rf ${MusicDir}/all.wav)
    echo "[PlayList]Merge Music Files"
    $(ffmpeg -i "concat:${files:1}" -loglevel panic -c:a copy -c:v copy -f s16le -ar 22.05k -ac 1 ${MusicDir}/all.wav)
    alltime=$(ffmpeg -i ${MusicDir}/all.wav 2>&1 | grep 'Duration' | cut -d ' ' -f 4 | sed s/,//)
    IFS=: DIRS=($alltime)
    declare -p DIRS > /dev/null 2>&1
    s=$(echo ${DIRS[2]}| awk '{print int($0)}')
    allseconds=$[$[${DIRS[0]}*3600]+$[${DIRS[1]}*60]+$s]
    echo "[PlayList]All ${allseconds} sec.";
    echo "[PlayList]Done"
}
while true
do
    clear
    UpdatePlayList
    loopandreupdate=0
    echo "[Player]Playing"
    while (( $loopandreupdate<5 ))
    do
        sn=0
        $(${PIFM_BIN} "-freq" ${PIFM_FREQ} "-audio "${MusicDir}/"all.wav"& )
        while (( ${sn}<${allseconds} ))
        do
            processbar $sn $allseconds
            sleep 1
            let "sn++"
        done
        killall ${PIFM_BIN}
        let "loopandreupdate++"
    done
done
