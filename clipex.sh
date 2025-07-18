#! /usr/bin/bash
# A script that utlizes ffmpeg to extract video clips from a video.
# Version 1.0
# I use mainly .mkv containers so this is mainly for that. I might expand it, or I might not.
# We'll see.
# As far as I'm aware, the scfript uses the same video and auidio codec settings as in the
# original file. This is by design, because I tried and failed to set manual setttings that
# were better than the ones used in the original video.
# 
# There ARE a few dependencies neccessary:
# - ffmpeg (obviously!)
# - getopt
# - bc
# - awk
FILENAME="${0}"
PARAMATERS="c:o:i:ktshq"
LONG_PARAMATERS="clip:,outputdirectory:,input:,addkeyframes,tmpdir:,help,quiet,silent,noerrors,nvidia:"
# Parse command line options
parsed_options=$(getopt --options "${PARAMATERS}" --longoptions "${LONG_PARAMATERS}" -- "$@")
RETURN_VALUE=$?
# Check for errors in parsing
if [ "${RETURN_VALUE}" -ne "0" ]; then
    exit 1
fi
# Evaluate the parsed options
eval set -- "$parsed_options"

function timestampToSeconds() {
    awk -F: 'NF==3 { print ($1 * 3600) + ($2 * 60) + $3 } NF==2 { print ($1 * 60) + $2 } NF==1 { print 0 + $1 }' <<< "${1}"
}

if [[ $# -lt 2 ]] && [[ ! $* =~ "-h" ]] && [[ ! $* =~ "--help" ]]; then
    if [[ $# -eq 0 ]]; then
        EXITERRORMSG="At least 2 argument required. None provided. See ${FILENAME} --help for more information. Exiting."
    elif [[ $# -eq 1 ]]; then
        EXITERRORMSG="At least 2 argument required. Only ${#} provided. See ${FILENAME} --help for more information. Exiting."
    fi
    echo "${EXITERRORMSG}"
    exit 1
fi

function help() {
    if [ "${1}" == 'long' ]; then
        echo "${FILENAME} was created by Mirdarthos, originally cobbled together in about"
        echo "a week. I kept tinkering afterwards, though, so have lost track of time"
        echo "spent on it."
        echo "Feel free to do with it what you want, except using to to harm or cause harm"
        echo "to others. See also: https://firstdonoharm.dev"
        echo
        echo "Usage: ${FILENAME} [parameter]"
        echo "Available parameters:"
        echo "  -c, --clip               The timestamp of the clip to extract, in format: HH:mm:ss-HH:mm:ss."
        echo "                           Can be specified muliple times."
        echo "  -o, --outputdirectory    The directory in which the clips should be saved."
        echo "  -i, --input              The full path to the video from which the clipps should be extracted."
        echo "  -k, --addkeyframes       Add keyframes at the timestamps specified with -c, or --clips before"
        echo "                           starting the extraction progress."
        echo "  --nvidia <param>         Use the <param> nvidia encoder to do the job."
        echo "                           a List of nvidia coders that can be used is available in the second"
        echo "                           column of the output of command 'ffmpeg -encoders | grep NVIDIA'."
        echo "  -q, --quiet              Be less verbose with the output, although not completely silent."
        echo "                           This effectively silences ffmpeg."
        echo "  -s, --silent             Don't print anything but errors to the terminal."
        echo "      --noerrors           Do not print any errors to the terminal."
        echo "  -t, --tmpdir             The temporary directory for adding the keyframes. If not specified, "
        echo "                           the video file is used as-is."
        echo "  -h                       Show slightly shorter help."
        echo "      --help               Show this help."
    elif [ "${1}" == 'short' ]; then
        echo "Usage: ${FILENAME} [parameter]"
        echo "Available parameters:"
        echo "  -c, --clip               The timestamp of the clip to extract, in format: HH:mm:ss-HH:mm:ss."
        echo "  -o, --outputdirectory    The directory in which the clips should be saved."
        echo "  -i, --input              The full path to the video from which the clipps should be extracted."
        echo "  -k, --addkeyframes       Add keyframes at the timestamps specified with -c, or --clips before"
        echo "                           starting the extraction progress."r
        echo "  --nvidia <param>         Use the <param> nvidia encoder to do the job."
        echo "  -q, --quiet              Be less verbose with the output, although not completely silent."
        echo "  -s, --silent             Don't print anything but errors to the terminal."
        echo "      --noerrors           Do not print any errors to the terminal."
        echo "  -t, --tmpdir             The temporary directory for adding the keyframes. If not specified, "
        echo "                           the video file is used as-is."
        echo "  -h                       Show this help."
        echo "      --help               Show slightly longer help."
    fi
    exit 0
}
declare EXTRACTIONERRORMESSAGES=()
declare EXTRACTIONMESSAGES=()
TIMESTAMPSTOEXTRACT=()
KEYFRAMETIMESTAMPS=""
declare -A TEXTFORMATTING=(
    [RED]=$(tput setaf 1)
    [GREEN]=$(tput setaf 2)
    [YELLOW]=$(tput setaf 3)
    [BRIGHT]=$(tput bold)
    [NORMAL]=$(tput sgr0)
)
while true; do
    case "$1" in
        -c|--clip)
            TIMESTAMPSTOEXTRACT+=("${2}")
            shift 2 # past value
        ;;
        -o|--outputdirectory)
            ARG=$(tr -d '\0' <<<"${2}")
            OUTPUTDIR=$(realpath --no-symlinks --zero "${ARG}")            
            shift 2 # past value
        ;;
        -i|--input)
            INPUTFILEPATH="${2}"
            shift 2 # past value
        ;;
        -k|--addkeyframes)
            ADDKEYFRAMES=true
            shift
        ;;
        -t|--tmpdir)
            ARG=$(tr -d '\0' <<<"${2}")
            TMPSTORAGEDIR=$(realpath --no-symlinks --zero "${ARG}")
            shift 2 # past value
        ;;
        --nvidia)
            ENCODER="${2}"
            shift 2
        ;;
        -q|--quiet)
            QUIETOUTPUT=true
            shift
        ;;
        -s|--silent)
            QUIETOUTPUT=true
            SILENT=true
            shift
        ;;
        --noerrors)
            NOERRORS=true
            shift
        ;;
        -h)
            help short
        ;;
        --help)
            help long
        ;;
        --)
            shift
            break
        ;;
    esac
done

## Let's get the creation date of the input file
if [ -f "${INPUTFILEPATH}" ]; then
    if ! FILEBIRTHDATE=$(stat -c '%w' "${INPUTFILEPATH}" | awk '{print $1}' | sed 's/-/./g'); then
        printf "%sCould not determine the birth date of the file, %s. Using today's date.%s\n" "${TEXTFORMATTING[RED]}" "${INPUTFILEPATH}" "${TEXTFORMATTING[NORMAL]}"
        FILEBIRTHDATE=$(date +%Y.%m.%d)
    fi
fi
# Change the output directory to reflect this
OUTPUTDIR="${OUTPUTDIR}/${FILEBIRTHDATE}"

# Check if the output directory exists, ask to attempt creating it if not and attempt it if affirmative.
if [ ! -d "${OUTPUTDIR}" ]; then
    printf "%s%sSpecified output directory, %s, does not exist!%s\n" "${TEXTFORMATTING[BRIGHT]}" "${TEXTFORMATTING[YELLOW]}" "${OUTPUTDIR}" "${TEXTFORMATTING[NORMAL]}"
    read -r -p "Attemptt to create it? [Y/n]: " CREATEOUTPUTDIR
    CREATEOUTPUTDIR=${CREATEOUTPUTDIR:-Y}
    if [[ ${CREATEOUTPUTDIR} =~ [yY] ]]; then
        if [ ! "${SILENT}" == true ]; then
            printf "Attempting to create output directory, %s.\n" "${OUTPUTDIR}"
        fi
        if ! mkdir "${OUTPUTDIR}"; then
            if [ ! "${NOERRORS}" == true ]; then
                printf "%sUnable to create output directory. Please ensure it exists and try again.%s\n" "${TEXTFORMATTING[BRIGHT]}${TEXTFORMATTING[RED]}" "${TEXTFORMATTING[NORMAL]}"
                exit 9
            fi
        else
            if [ ! "${SILENT}" == true ]; then
                printf "%sSuccessfully created output directory, %s%s.\n" "${TEXTFORMATTING[BRIGHT]}${TEXTFORMATTING[GREEN]}" "${OUTPUTDIR}" "${TEXTFORMATTING[NORMAL]}"
            fi
        fi
    else
        if [ ! "${NOERRORS}" == true ]; then
            printf "%sOutput directory does not exist. Please ensure it exists and try again.%s\n" "${TEXTFORMATTING[BRIGHT]}${TEXTFORMATTING[RED]}" "${TEXTFORMATTING[NORMAL]}"
        fi
        exit 8
    fi
fi

if [ ! -w "${OUTPUTDIR}" ]; then
    if [ ! "${NOERRORS}" == true ]; then
        printf "%sOutput directory not writable for %s${USER}%s Please rectify and try again.%s\n" "${TEXTFORMATTING[RED]}" "${TEXTFORMATTING[BRIGHT]}" "${TEXTFORMATTING[NORMAL]}${TEXTFORMATTING[RED]}" "${TEXTFORMATTING[NORMAL]}"
    fi
    exit 10
fi

for clipTimes in "${TIMESTAMPSTOEXTRACT[@]}"; do
    IFS=- read -r clipStart clipEnd <<< "${clipTimes}"
    if [ "${KEYFRAMETIMESTAMPS}" == "" ]; then
        KEYFRAMETIMESTAMPS="${KEYFRAMETIMESTAMPS}${clipStart}"
        KEYFRAMETIMESTAMPS="${KEYFRAMETIMESTAMPS},${clipEnd}"
    else
        KEYFRAMETIMESTAMPS="${KEYFRAMETIMESTAMPS},${clipStart}"
        KEYFRAMETIMESTAMPS="${KEYFRAMETIMESTAMPS},${clipEnd}"
    fi
done
if [ "${ADDKEYFRAMES}" == true ]; then
    if [ ! "${SILENT}" == true ]; then
        printf "%sAdding keyframes to the file before extracting process can begin.%s\n" "${TEXTFORMATTING[BRIGHT]}${TEXTFORMATTING[GREEN]}" "${TEXTFORMATTING[NORMAL]}"
    fi
    if [ -d "${TMPSTORAGEDIR}" ]  && [ -w "${TMPSTORAGEDIR}" ]; then
        ffmpeg ${QUIETOUTPUT:+-loglevel warning} -hide_banner -i "${INPUTFILEPATH}" ${ENCODER:+-c:v $ENCODER} -force_key_frames "${KEYFRAMETIMESTAMPS}" "${TMPSTORAGEDIR}/$(basename "${INPUTFILEPATH}")"
        RETURN_RESULT=$?
    else
        if ffmpeg ${QUIETOUTPUT:+-loglevel warning} -hide_banner -i "${INPUTFILEPATH}" ${ENCODER:+-c:v $ENCODER} -force_key_frames "${KEYFRAMETIMESTAMPS}" -y "/tmp/$(basename "${INPUTFILEPATH}")"; then
            if [ ! "${SILENT}" == true ]; then
                printf "%sReplacing ${INPUTFILEPATH} with /tmp/$(basename "${INPUTFILEPATH}")...%s\n" "${TEXTFORMATTING[BRIGHT]}${TEXTFORMATTING[YELLOW]}" "${TEXTFORMATTING[NORMAL]}"
            fi
            if mv --force "/tmp/$(basename "${INPUTFILEPATH}")" "${INPUTFILEPATH}"; then
                if [ ! "${SILENT}" == true ]; then
                    printf "%sSuccessfully replaced %s%s\n" "${TEXTFORMATTING[BRIGHT]}${TEXTFORMATTING[GREEN]}" "${INPUTFILEPATH}" "${TEXTFORMATTING[NORMAL]}"
                fi
                
            fi
        else
            if [ ! "${NOERRORS}" == true ]; then
                printf "%sAdding keyframes to file,%s %s%s, failed.%s\n" "${TEXTFORMATTING[RED]}" "${TEXTFORMATTING[BRIGHT]}" "${INPUTFILEPATH}" "${TEXTFORMATTING[NORMAL]}${TEXTFORMATTING[RED]}" "${TEXTFORMATTING[NORMAL]}"
            fi
        fi
        RETURN_RESULT=$?
    fi
    if [ "${RETURN_RESULT}" == "0" ]; then
        if [ ! "${SILENT}" == true ]; then
            printf "%s%sFinished adding key frames. Let the extracting begin!%s\n" "${TEXTFORMATTING[BRIGHT]}" "${TEXTFORMATTING[GREEN]}" "${TEXTFORMATTING[NORMAL]}" 
        fi
    fi
fi 
if [ -z ${CLIPNO+x} ]; then 
    CLIPNO=0
fi 
for clipTimes in "${TIMESTAMPSTOEXTRACT[@]}"; do
    CLIPNO=$(bc <<<"${CLIPNO}+1")
    IFS=- read -r clipStart clipEnd <<< "${clipTimes}"
    if [[ "$(declare -p | grep -q TMPSTORAGEDIR)" -eq 0 ]] && [ "${TMPSTORAGEDIR}" != "" ] ; then
        if [ ! "${SILENT}" == true ]; then
            printf "%sUsing the temporary file was with the added keyframes that was created for %s.%s\n" "${TEXTFORMATTING[BRIGHT]}" "${INPUTFILEPATH}" "${TEXTFORMATTING[NORMAL]}"
        fi
        clipStartSeconds=$(timestampToSeconds "${clipStart}")
        clipEndSeconds=$(timestampToSeconds "${clipEnd}")
        clipDuration=$(bc <<< "(${clipEndSeconds} + 0.01) - ${clipStartSeconds}" | awk '{ printf "%.4f", $0 }')
        if ffmpeg ${QUIETOUTPUT:+-loglevel warning} -hide_banner -ss "${clipStartSeconds}" -i "${TMPSTORAGEDIR}/$(basename "${INPUTFILEPATH}")" ${ENCODER:+-c:v $ENCODER} -t "${clipDuration}" "${OUTPUTDIR}/${CLIPNO}.mkv"; then
            EXTRACTIONMESSAGES+=("Clip #${CLIPNO}: ${OUTPUTDIR}/${CLIPNO}.mkv was successfully extracted from ${INPUTFILEPATH}")
        else
            EXTRACTIONERRORMESSAGES+=("Clip #${CLIPNO}: There were one or more errors while attempting to extract ${OUTPUTDIR}/${CLIPNO}.mkv from ${INPUTFILEPATH}. ffmpeg returned an $? error code.")
        fi
    else
        if clipStartSeconds=$(timestampToSeconds "${clipStart}"); then
            if [ "${QUIETOUTPUT}" == true ]; then
                CLIPMESSAGE="Clip #${CLIPNO}: Will start at ${clipStartSeconds} seconds"
            elif [ ! "${SILENT}" == true ]; then
                echo "Clip #${CLIPNO}: will start at ${clipStartSeconds} seconds."
            fi
        fi
        if clipEndSeconds=$(timestampToSeconds "${clipEnd}"); then
            if [ "${QUIETOUTPUT}" == true ]; then
                CLIPMESSAGE="${CLIPMESSAGE}, will end at ${clipEndSeconds} seconds"
            elif [ ! "${SILENT}" == true ]; then
                echo "Clip #${CLIPNO}: will end at ${clipEndSeconds} seconds."
            fi
        fi
        if clipDuration=$(bc <<< "(${clipEndSeconds} + 0.01) - ${clipStartSeconds}" | awk '{ printf "%.4f", $0 }'); then
            if [ "${QUIETOUTPUT}" == true ]; then
                CLIPMESSAGE="${CLIPMESSAGE}, and be approximately $(date -d@"${clipDuration}" -u '+%-M minutes and %-S seconds') long."
            elif [ ! "${SILENT}" == true ]; then
                echo "Clip #${CLIPNO}: will be approximately $(date -d@"${clipDuration}" -u '+%-M minutes and %-S seconds') long."
            fi
        fi
        if [ -n "${CLIPMESSAGE+x}" ] && [ ! "${SILENT}" == true ]; then
            printf "%s\n" "${CLIPMESSAGE}"
        fi

        if ffmpeg ${QUIETOUTPUT:+-loglevel warning} -hide_banner -ss "${clipStartSeconds}" -i "${INPUTFILEPATH}" ${ENCODER:+-c:v $ENCODER} -t "${clipDuration}" "${OUTPUTDIR}/${CLIPNO}.mkv"; then
            if [ ! "${SILENT}" == true ]; then
                EXTRACTIONMESSAGES+=("Clip #${CLIPNO}: ${OUTPUTDIR}/${CLIPNO}.mkv was successfully extracted from \"$(basename "${INPUTFILEPATH}")\".")
            fi
        else
            EXTRACTIONERRORMESSAGES+=("Clip #${CLIPNO}: There one or more errors while attempting to extract ${OUTPUTDIR}/${CLIPNO}.mkv from \"$(basename "${INPUTFILEPATH}")\". ffmpeg returned an $? error code.")
        fi
    fi
done

# Show any error messages there might have been
if [ ! "${NOERRORS}" == true ]; then
    if [[ ${#EXTRACTIONERRORMESSAGES[@]} -gt 0 ]]; then
        printf "%sThere are %s%s%s error messages:%s\n" "${TEXTFORMATTING[RED]}" "${TEXTFORMATTING[BRIGHT]}" "${#EXTRACTIONERRORMESSAGES[@]}" "${TEXTFORMATTING[NORMAL]}${TEXTFORMATTING[RED]}" "${TEXTFORMATTING[BRIGHT]}"
        for message in "${EXTRACTIONERRORMESSAGES[@]}"; do
            printf "%s%s%s%s%s\n" "${TEXTFORMATTING[RED]}" "Clip #${message} error: " "${TEXTFORMATTING[BRIGHT]}" "${message}" "${TEXTFORMATTING[NORMAL]}"
        done
    fi
fi
# Show any messages
if [[ ${#EXTRACTIONMESSAGES[@]} -gt 0 ]]; then
    if [ ! "${SILENT}" == true ]; then
        printf "%sThere are %s${#EXTRACTIONMESSAGES[@]}%s messages:%s\n" "${TEXTFORMATTING[GREEN]}" "${TEXTFORMATTING[BRIGHT]}" "${TEXTFORMATTING[NORMAL]}${TEXTFORMATTING[GREEN]}" "${TEXTFORMATTING[BRIGHT]}"
        for message in "${EXTRACTIONMESSAGES[@]}"; do
            printf "%s%s%s%s\n" "${TEXTFORMATTING[GREEN]}" "${TEXTFORMATTING[BRIGHT]}" "${message}" "${TEXTFORMATTING[NORMAL]}"
        done
    fi
fi
# a Bit of housekeeping:
if [ -w "${TMPSTORAGEDIR}" ]; then
    if file "${TMPSTORAGEDIR}/$(basename "${INPUTFILEPATH}")"; then
        if [ ! "${SILENT}" == true ]; then
            printf "Removing temporarily file: %s%s%s"  "${TEXTFORMATTING[BRIGHT]}" "${TMPSTORAGEDIR}/$(basename "${INPUTFILEPATH}")" "${TEXTFORMATTING[NORMAL]}"
        fi
        rm "${TMPSTORAGEDIR}/$(basename "${INPUTFILEPATH}")"
    fi
fi

unset EXTRACTIONERRORMESSAGES EXTRACTIONMESSAGES TIMESTAMPSTOEXTRACT KEYFRAMETIMESTAMPS TEXTFORMATTING timestampToSeconds
exit 0
