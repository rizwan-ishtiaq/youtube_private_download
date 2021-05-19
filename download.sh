#!/bin/bash
set -e

scriptDir=$(dirname "$(readlink -f "$0")")
source $scriptDir/config.properties
source $scriptDir/functions.sh

if [ -z "$input" ]; then
  ERR set input file in config.properties file
  exit
fi

if [ ! -f "$scriptDir/$input" ] && [ ! -f "$input" ]; then
  ERR input file in config.properties is not a file
  exit
fi

if [ -f "$scriptDir/$input" ]; then
  input="${scriptDir}/${input}"
fi

installOrUpdateRequiredSoftwares

output=normal
youtube=(youtube-dl --ignore-config -f best)
if [[ $quality == "best" ]]; then
  output=best
  youtube=(youtube-dl --ignore-config -f bestvideo+bestaudio/best)
fi
TRACE "Creating or checking output directory"
mkdir -p $scriptDir/$output
cd $scriptDir/$output

index=0
function downloadVideo {
  url="$1"
  startTime="$2"
  endTime="$3"
  youtubeOptions=(--get-filename -o '%(title)s.%(ext)s' "${url}")
  name=$("${youtube[@]}" "${youtubeOptions[@]}") 
  name=$(linuxFriendlyFileName "${name}")
  fullName="$(printf "%03d" $index)-${name}"
  cutFile=$(concatStringBeforeExt "$fullName" "-trim")
  cutFileMkv=$(getFileNameWithoutExt "$fullName")"-trim.mkv"

  #if you download file before and trimed it don't download again
  #if file is not trimed and downloaded before youtube-dl will not download it
  if [ ! -f "$cutFile" ] && [ ! -f "$cutFileMkv" ]; then  
    youtubeOptions=(-o "${fullName}" "${url}")
    TRACE "${youtube[@]}" "${youtubeOptions[@]}"
    "${youtube[@]}" "${youtubeOptions[@]}"
  fi

  #WARNING: Requested formats are incompatible for merge and will be merged into mkv.
  #youtube-dl will create mkv file
  mkvFile=$(getFileNameWithoutExt "$fullName")".mkv"
  if [ -f "$mkvFile" ] || [ -f "$cutFileMkv" ]; then
    fullName="${mkvFile}"
    cutFile="${cutFileMkv}"
  fi

  #if already trimed then donot do it again
  if [ -n "$startTime" ] && [ ! -f "$cutFile" ]; then
    INFO triming video
    tool=(ffmpeg -i ${fullName} -ss ${startTime} -c copy ${cutFile})
    if [ -n "$endTime" ]; then
      tool=(ffmpeg -i ${fullName} -ss ${startTime} -to ${endTime} -c copy ${cutFile})
    fi
    "${tool[@]}" &> /dev/null
    rm -f "${fullName}"
  fi
}

INFO "Reading input.tsv tab seperated values file"
TRACE "using file descriptor 3 to avoid conflicts"
while IFS= read -r line <&3; do
  # ignore lines starting with #
  if [[ $line =~ ^\#.*$ ]] || [[ ${#line} == 0 ]] ; then
    TRACE "ignoring ${line}"
    continue;
  fi

  index=$((index+1))
  INFO "${index} -> downloading ${line}"
  IFS=$'\t' read -ra ARR <<<"$line"
  # run it in a sub-shell
  downloadVideo "${ARR[0]}" "${ARR[1]}" "${ARR[2]}"
  IFS=
  printf "\n"
done 3<"$input"
INFO programs terminates successfully

#youtube-dl params help
#https://github.com/ytdl-org/youtube-dl/blob/master/README.md
