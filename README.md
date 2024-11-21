Script to convert Github issues to a format mostly recognisable by
Jira CSV-importer.

First run this script, then goto your Jira-project > Issues > "..." >
Import issues from CSV.

```bash
Usage:
    ./github_to_jira.sh
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
```


# Extras

`jq` and `csvtool` can be helpful when inspecting and merging json and
csv files.

e.g.
```bash
$ ./github_to_jira.sh -c -d
gh_issues_closed_2024-11-21T15:22:35+01:00.json
$ ./github_to_jira.sh -d
gh_issues_open_2024-11-21T15:24:45+01:00.json
$ jq -s '.[0] + .[1]' gh_issues_closed_2024-11-21T15:22:35+01:00.json gh_issues_open_2024-11-21T15:24:45+01:00.json > gh_issues_all_$(date --iso-8601=seconds).json
$ ./github_to_jira.sh -j gh_issues_all_2024-11-21T15:33:15+01:00.json
jira_issues_2024-11-21T15:48:45+01:00.csv
$ csvtool col 2,4-5 jira_issues_2024-11-21T15:48:45+01:00.csv | head
Issue Key,Status,Reporter
42,CLOSED,sebastiw
666,DONE,sebastiw
1337,DONE,sebastiw
```

