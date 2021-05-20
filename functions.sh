function linuxFriendlyFileName {
  fileNameContainingExt="$1"
  echo $fileNameContainingExt | tr -dc '[:alnum:] .' | tr -s ' ' | tr ' ' '-' # | tr '[:upper:]' '[:lower:]'
}

function getFileNameWithoutExt {
  fileNameContainingExt="$1"
  echo $fileNameContainingExt | rev | cut -d'.' -f2- | rev
}

function getFileExtWithoutDot {
  fileNameContainingExt="$1"
  echo $fileNameContainingExt | awk -F'.' '{print $NF}'
}

function concatStringBeforeExt {
  fileNameContainingExt="$1"
  stringToConcat="$2"
  
  name=$(getFileNameWithoutExt "$fileNameContainingExt")
  ext=$(getFileExtWithoutDot "$fileNameContainingExt")
  echo $name$stringToConcat.$ext
}

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

function installOrUpdateYoutubeDl {
  if ! command -v youtube-dl &> /dev/null
  then
    echo "youtube-dl could not be found"
    install
  else
    echo "Updating youtube-dl"
    youtube-dl -U
  fi
}

function installOrUpdateFfmpeg {
  if ! command -v ffmpeg &> /dev/null
  then
    echo "ffmpeg could not be found"
    echo "Installing ffmpeg with snap as sudo"
    sudo snap install ffmpeg
  else
    echo "You might conside to update ffmpeg"
    echo sudo snap refresh ffmpeg
  fi
}

function installOrUpdateRequiredSoftwares {
  installOrUpdateYoutubeDl
  installOrUpdateFfmpeg
  printf "\n\n"
}

function ERR {
  echo -n "$(date) ERROR: "
  cat <<< "$@"
}

function INFO {
  echo -n "$(date) INFO: "
  cat <<< "$@"
}

function WARN {
  echo -n "$(date) WARNING: "
  cat <<< "$@"
}

function TRACE {
  if [[ "$trace" == "on" ]]; then
    echo -n "$(date) DEBUG: "
    cat <<< "$@"
  fi
}