#!/bin/bash

# This script generates a report of all git changes from the last week.

(for project_dir in /home/nextor/Projects/*/ /var/www/html/*/ ; do
    if [ -d "${project_dir}/.git" ]; then
        project_name=$(basename "${project_dir}")
        # Check if repository has any commits before running git log
        if git -C "${project_dir}" rev-parse --git-dir > /dev/null 2>&1; then
            output=$(git -C "${project_dir}" log --since="1 week ago" --pretty=format:"%ad|${project_name}|%an|%B" --date=short 2>/dev/null | awk '
                /^[0-9]{4}-[0-9]{2}-[0-9]{2}\|/ { if (NR>1) print rec; rec=$0; next }
                { rec=rec " " $0 }
                END { if (rec) print rec }
            ')
            if [ -n "$output" ]; then
                echo "$output"
            fi
        fi
    fi
done | sort -t'|' -k1,1r | awk -F'|' '
    BEGIN {
        current_date = ""
    }
    {
        msg = $4
        for (i = 5; i <= NF; i++) msg = msg "|" $i
        if ($1 != current_date) {
            print "\n## " $1
            current_date = $1
        }
        print "- **" $2 "** (" $3 "): " msg
    }'
)
