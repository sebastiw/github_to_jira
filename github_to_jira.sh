#!/bin/env bash

GH=/usr/bin/gh
IMPORT_TIME="$(date --iso-8601=seconds)"
STATE=open

function _err {
    local OUT="$1"
    1>&2 echo "ERROR: ${OUT}"
    exit 1
}

function _help {
    cat <<END
  Script to convert Github issues toa format mostly recognisable by
  Jira CSV-importer.

  First run this script, then goto your Jira-project > Issues > "..." >
  Import issues from CSV.

  Usage:
      $(basename "$0")
                  [-h] [-c]
                  [-l LABEL]
                  [-j path/to/GITHUB-ISSUES.JSON]
                  [-s path/to/GITHUB-STATES.JSON]
                  [-u path/to/GITHUB-USERS.JSON]

  PARAMETERS
     -h: This help-text

     -l <GITHUB LABEL>:
         Github label to filter on.
         Recommended.

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
         JSON-file to map Github states to Jira Statuses; the Github
         state is the key, and the Jira status is the value.
         Beware, if no key is found for a value, then the value will
         be used as is. Meaning: if not mapping is made, then the
         Github state name will be used.

         Example:
             { "github-state": "jira-status", "closed": "done" }

    -c:
         Instead of fetching Github issues with state OPEN, fetch
         issues with state=CLOSED
         Not recommended.
END
}

JQ="$(command -v jq)"
[[ -x "${JQ}" ]] || _err "jq needed. See https://jqlang.github.io/jq/"

JSON_FILE=""
LOGIN_FILE=""
STATE_FILE=""

while getopts 'hl:j:u:s:c' OPTION
do
    case "${OPTION}" in
        h)
            _help
            exit 0
            ;;
        l)
            LABEL_OPTION="--label ${OPTARG}"
            LABEL_STRING="_${OPTARG}"
            ;;
        j)
            JSON_FILE="${OPTARG}"
            ;;
        u)
            LOGIN_FILE="${OPTARG}"
            ;;
        s)
            STATE_FILE="${OPTARG}"
            ;;
        c)
            STATE=closed
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
    JSON_FILE="gh_issues${LABEL_STRING}_${IMPORT_TIME}.json"
    "${GH}" issue list \
          "${LABEL_OPTION}" \
          --state "${STATE}" \
          --limit 50000 \
          --json assignees,author,body,closed,closedAt,comments,createdAt,id,labels,milestone,number,projectCards,projectItems,reactionGroups,state,title,updatedAt,url \
          > "./${JSON_FILE}"
else
    _err "Github CLI needed. See https://cli.github.com/manual/"
fi

NUM_COLUMNS_ASSIGNEES=$("${JQ}" '[(.[].assignees | length)] | max' "${JSON_FILE}")
NUM_COLUMNS_LABELS=$("${JQ}" '[(.[].labels | length)] | max' "${JSON_FILE}")
NUM_COLUMNS_COMMENTS=$("${JQ}" '[(.[].comments | length)] | max' "${JSON_FILE}")

# shellcheck disable=SC2016
JQ_MAPPED_AUTHOR='(if (.author.login | in($logins[0])) then $logins[0][.author.login] else .author.login end)'

HEADER="Id,Issue Key,Title,Status,Reporter,Date Created"
JQ_PREFIX_FIELDS='.id,.number,.title,.state,'"${JQ_MAPPED_AUTHOR}"',.createdAt'

JQ_ASSIGNEES=""
for ((i=0; i < NUM_COLUMNS_ASSIGNEES; i++))
do
    HEADER="${HEADER},Assignee"
    JQ_ASSIGNEES="${JQ_ASSIGNEES},.assignees[${i}].login"
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
    JQ_COMMENTS="${JQ_COMMENTS},(if .comments[${i}] then (.comments[${i}] | .createdAt + \";\" + ${JQ_MAPPED_AUTHOR} + \";\" + .body) else null end)"
done
JQ_COMMENTS="${JQ_COMMENTS:1}"

echo "${HEADER}"

SLURP_LOGINS=""
if [[ -r "${LOGIN_FILE}" ]]
then
    SLURP_LOGINS="--slurpfile logins ${LOGIN_FILE}"
fi

SLURP_STATES=""
if [[ -r "${STATE_FILE}" ]]
then
    SLURP_STATES="--slurpfile states ${STATE_FILE}"
fi

# shellcheck disable=SC2086
"${JQ}" -r ${SLURP_LOGINS} ${SLURP_STATES} '.[] | ['"${JQ_PREFIX_FIELDS}"','"${JQ_ASSIGNEES}"','"${JQ_LABELS}"','"${JQ_COMMENTS}"'] | @csv' "${JSON_FILE}"
