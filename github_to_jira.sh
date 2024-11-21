#!/bin/env bash

GH=/usr/bin/gh
IMPORT_TIME="$(date --iso-8601=seconds)"

function _err {
    local OUT="$1"
    1>&2 echo "ERROR: ${OUT}"
    exit 1
}

function _help {
    cat <<END
  Script to convert Github issues to a format mostly recognisable by
  Jira CSV-importer.

  First run this script, then goto your Jira-project > Issues > "..." >
  Import issues from CSV.

  Usage:
      $(basename "$0")
                  [-h]
                  [-a ASSIGNEE]
                  [-A AUTHOR]
                  [-l LABEL]
                  [-c] [-d]
                  [-j path/to/GITHUB-ISSUES.JSON]
                  [-u path/to/GITHUB-USERS.JSON]
                  [-s path/to/GITHUB-STATUSES.JSON]
                  [-p GITHUB_PROJECT_NAME]

  GENERAL PARAMETERS
     -h: This help-text


  STAGE 1 (GITHUB/JSON) PARAMETERS
     -a <GITHUB ASSIGNEE>:
         Github assignee to filter on.

     -A <GITHUB AUTHOR>:
         Github author to filter on.

     -l <GITHUB LABEL>:
         Github label to filter on.
         Recommended.

    -c:
         Instead of fetching Github issues with state OPEN, fetch
         issues with state=CLOSED
         Not recommended.

    -d:
         Download only, do not convert to CSV.
         Stops script after downloading the Github issues.

  STAGE 2 (JIRA/CSV) PARAMETERS
     -j <JSON>:
         Instead of using Github CLI to access and download the
         issues, a previous downloaded file can be used.

     -u <JSON>:
         JSON-file to map Github login names to Jira usernames; the
         Github login name is the key, and the Jira username the
         value.
         Beware, if no key is found for a value, then the value will
         be used as is. Meaning: if not mapping is made, then the
         Github login name will be used.

         Example:
             { "github-login": "jira-username", "sebastiw": "sebastiw@jira.com" }

     -s <JSON>:
         JSON-file to map Github statuses to Jira statuses; the Github
         status is the key, and the Jira status is the value.
         Beware, if no key is found for a value, then the value will
         be used as is. Meaning: if not mapping is made, then the
         Github status will be used.

         Example:
             { "github-status": "jira-status", "CLOSED": "Done" }

     -p <GITHUB PROJECT NAME>:
         Github project name to map statuses from. Used in conjunction
         with '-s'.
         If the Github project is not found in the issue, the Github
         state (OPEN, CLOSED) will be used instead.
END
}

JQ="$(command -v jq)"
[[ -x "${JQ}" ]] || _err "jq needed. See https://jqlang.github.io/jq/"

JSON_FILE=""
LOGIN_FILE=""
STATUS_FILE=""
STATE=open
GH_OPTIONS=()
OUTPUT_FILENAME_STRING=""
DOWNLOAD_ONLY=false

while getopts 'a:A:l:cdj:u:p:s:h' OPTION
do
    case "${OPTION}" in
        ### STAGE 1 (Github) OPTIONS ###
        a)
            GH_OPTIONS+=(--assignee "${OPTARG}")
            OUTPUT_FILENAME_STRING="_${OPTARG}${OUTPUT_FILENAME_STRING}"
            ;;

        A)
            GH_OPTIONS+=(--author "${OPTARG}")
            OUTPUT_FILENAME_STRING="_${OPTARG}${OUTPUT_FILENAME_STRING}"
            ;;

        l)
            GH_OPTIONS+=(--label "${OPTARG}")
            OUTPUT_FILENAME_STRING="_${OPTARG}${OUTPUT_FILENAME_STRING}"
            ;;

        c)
            STATE=closed
            GH_OPTIONS+=(--state "${STATE}")
            ;;

        d)
            DOWNLOAD_ONLY=true
            ;;

        ### STAGE 2 (Jira) OPTIONS ###
        j)
            JSON_FILE="${OPTARG}"
            ;;

        u)
            LOGIN_FILE="${OPTARG}"
            ;;

        p)
            PROJECT_NAME="${OPTARG}"
            ;;

        s)
            STATUS_FILE="${OPTARG}"
            ;;

        ### GENERAL OPTIONS ###
        h)
            _help
            exit 0
            ;;

        *)
            _help
            exit 1
            ;;
    esac
done

if [[ -n "${JSON_FILE}" ]]
then
   [[ -r "${JSON_FILE}" ]] || _err "${JSON_FILE} not readable"
elif [[ -x "${GH}" ]]
then
    OUTPUT_FILENAME_STRING="_${STATE}${OUTPUT_FILENAME_STRING}"
    JSON_FILE="gh_issues${OUTPUT_FILENAME_STRING}_${IMPORT_TIME}.json"
    "${GH}" issue list \
          "${GH_OPTIONS[@]}" \
          --limit 50000 \
          --json assignees,author,body,closed,closedAt,comments,createdAt,id,labels,milestone,number,projectCards,projectItems,reactionGroups,state,title,updatedAt,url \
          > "./${JSON_FILE}"
else
    _err "Github CLI needed. See https://cli.github.com/manual/"
fi

if [[ "${DOWNLOAD_ONLY}" == "true" ]]
then
    exit 0
fi

NUM_COLUMNS_ASSIGNEES=$("${JQ}" '[(.[].assignees | length)] | max' "${JSON_FILE}")
NUM_COLUMNS_LABELS=$("${JQ}" '[(.[].labels | length)] | max' "${JSON_FILE}")
NUM_COLUMNS_COMMENTS=$("${JQ}" '[(.[].comments | length)] | max' "${JSON_FILE}")

# shellcheck disable=SC2016
JQ_LOGIN_FILTER=' as $username | if ($username | in($logins[0])) then $logins[0][$username] else $username end'

# shellcheck disable=SC2016
JQ_STATUS_FILTER=' as $status | if ($status | in($statuses[0])) then $statuses[0][$status] else $status end'

PROJECT_STATUS=".state"
if [[ -n "${PROJECT_NAME}" ]]
then
    PROJECT_STATUS='((.projectItems[]|select("'"${PROJECT_NAME}"'" == .title)|.status.name) // .state)'
fi

HEADER="Id,Issue Key,Title,Status,Reporter,Date Created"
JQ_PREFIX_FIELDS='.id,.number,.title,('"${PROJECT_STATUS}"' '"${JQ_STATUS_FILTER}"'),(.author.login '"${JQ_LOGIN_FILTER}"'),.createdAt'

JQ_ASSIGNEES=""
for ((i=0; i < NUM_COLUMNS_ASSIGNEES; i++))
do
    HEADER="${HEADER},Assignee"
    JQ_ASSIGNEES="${JQ_ASSIGNEES},((.assignees[${i}].login//\"\") ${JQ_LOGIN_FILTER})"
done
JQ_ASSIGNEES="${JQ_ASSIGNEES:1}"

JQ_LABELS=""
for ((i=0; i < NUM_COLUMNS_LABELS; i++))
do
    HEADER="${HEADER},Label"
    JQ_LABELS="${JQ_LABELS},.labels[${i}].name"
done
JQ_LABELS="${JQ_LABELS:1}"

JQ_COMMENTS=""
for ((i=0; i < NUM_COLUMNS_COMMENTS; i++))
do
    HEADER="${HEADER},Comment"
    JQ_COMMENTS="${JQ_COMMENTS},(if .comments[${i}] then (.comments[${i}] | .createdAt + \";\" + (.author.login ${JQ_LOGIN_FILTER}) + \";\" + .body) else null end)"
done
JQ_COMMENTS="${JQ_COMMENTS:1}"

echo "${HEADER}"

SLURP_LOGINS=(--argjson logins "[]")
if [[ -r "${LOGIN_FILE}" ]]
then
    SLURP_LOGINS=(--slurpfile logins "${LOGIN_FILE}")
fi

SLURP_STATUSES=(--argjson statuses "[]")
if [[ -r "${STATUS_FILE}" ]]
then
    SLURP_STATUSES=(--slurpfile statuses "${STATUS_FILE}")
fi

"${JQ}" -r "${SLURP_LOGINS[@]}" "${SLURP_STATUSES[@]}" '.[] | ['"${JQ_PREFIX_FIELDS}"','"${JQ_ASSIGNEES}"','"${JQ_LABELS}"','"${JQ_COMMENTS}"'] | @csv' "${JSON_FILE}"
