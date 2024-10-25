Script to convert Github issues to a format mostly recognisable by
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
