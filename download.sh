#!/bin/bash
set -e

scriptDir=$(dirname "$(readlink -f "$0")")
source $scriptDir/config.properties
if [ -z "$input" ]; then
  echo set input file in config.properties file
  exit
fi

if [ ! -f "$scriptDir/$input" ] || [ ! -f "$input" ]; then
  echo input file in config.properties is not a file
  exit
fi

if [ -f "$scriptDir/$input" ]; then
  input="${scriptDir}/${input}"
fi

function install {
  echo "installing youtube-del at /usr/local/bin/youtube-dl as sudo"
  sudo wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl &> /dev/null
  sudo chmod a+rx /usr/local/bin/youtube-dl

  echo "Importing youtube-dl public key into keyring"
  wget https://dstftw.github.io/keys/18A9236D.asc -O youtube-dl.asc &> /dev/null
  gpg2 --import youtube-dl.asc
  rm -f youtube-dl.asc

  
  echo "Verifying installed youtube-dl signature"
  wget https://yt-dl.org/downloads/latest/youtube-dl.sig -O youtube-dl.sig &> /dev/null
  gpg --verify youtube-dl.sig /usr/local/bin/youtube-dl
  rm -f youtube-dl.sig
  
  echo "Installed youtube-dl successfull"
  echo "http://ytdl-org.github.io/youtube-dl/download.html"
}

if ! command -v youtube-dl &> /dev/null
then
  echo "youtube-dl could not be found"
  install
else
  echo "Updating youtube-dl"
  youtube-dl -U
fi

if ! command -v ffmpeg &> /dev/null
then
  echo "ffmpeg could not be found"
  echo "Installing ffmpeg with snap as sudo"
  sudo snap install ffmpeg
else
  echo "You might conside to update ffmpeg"
  echo sudo snap refresh ffmpeg
fi

output=normal
youtube="youtube-dl --ignore-config -f best "
if [[ $quality == "best" ]]; then
  output=best
  youtube="youtube-dl --ignore-config -f bestvideo+bestaudio/best "
fi
echo "Creating or checking output directory"
mkdir -p $scriptDir/$output
cd $scriptDir/$output

index=0
function downloadVideo {
  url="$1"
  startTime="$2"
  endTime="$3"
  name=$($youtube --get-filename -o '%(title)s.%(ext)s' ${url} | tr -dc '[:alnum:] .' | tr -s ' ' | tr ' ' '-') #| tr '[:upper:]' '[:lower:]'
  fullName="$(printf "%03d" $index)-${name}"
  cutFile=$(echo $fullName | sed 's/\.\([^.]*\)$/-trim.\1/')

  #if you download file before and trimed it don't download again
  #if file is not trimed and downloaded before youtube-dl will not download it
  if [ ! -f "$cutFile" ]; then  
    $youtube -o "${fullName}" $url
  fi

  #if already trimed then donot do it again
  if [ -n "$startTime" ] && [ ! -f "$cutFile" ]; then
    echo Starting to trim video
    tool="ffmpeg -i ${fullName} -ss ${startTime} -c copy ${cutFile}"
    if [ -n "$endTime" ]; then
      tool="ffmpeg -i ${fullName} -ss ${startTime} -to ${endTime} -c copy ${cutFile}"
    fi
    $tool &> /dev/null
    rm -f "${fullName}"
  fi
}

date
echo "Reading input.tsv tab seperated values file"
while IFS= read -r line
do
  echo "line ${line}"
  # ignore lines starting with #
  if [[ $line =~ ^\#.*$ ]] || [[ ${#line} == 0 ]] ; then
    continue;
  fi
  index=$((index+1))
  echo "downloading ${line}"
  IFS=$'\t' read -ra ARR <<<"$line"
  # run it in a sub-shell
  (downloadVideo "${ARR[0]}" "${ARR[1]}" "${ARR[2]}")
done < "$input"
date

#youtube-dl params help
#https://github.com/ytdl-org/youtube-dl/blob/master/README.md
