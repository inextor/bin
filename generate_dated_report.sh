#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <start_date> <end_date>"
    echo "Example: $0 2025-08-01 2025-08-08"
    exit 1
fi

start_date=$1
end_date=$2

# Create a report file
report_file="/home/nextor/Projects/changes_report_${start_date}_to_${end_date}.md"
echo "# Git Changes Report from $start_date to $end_date" > "$report_file"
echo "Author filter: nextor" >> "$report_file"

# Loop through each day in the date range
current_date=$(date -I -d "$start_date")
while [ "$current_date" != $(date -I -d "$end_date + 1 day") ]; do
    echo -e "\n## $current_date" >> "$report_file"

    # Find all git repositories and get the logs for the current date
    (for project_dir in /home/nextor/Projects/*/ ; do
        if [ -d "${project_dir}/.git" ]; then
            project_name=$(basename "${project_dir}")
            # Use a non-printable character as a delimiter
            git -C "${project_dir}" log --since="$current_date 00:00:00" --until="$current_date 23:59:59" --author="nextor" --pretty=format:"${project_name}%x1d%an%x1d%B"
        fi
    done | sort -t$'\x1d' -k1,1 | awk -F'\x1d' '
        BEGIN {
            current_project = ""
        }
        {
            if ($1 != current_project) {
                print "\n### " $1;
                current_project = $1;
            }
            gsub(/\n/, "\n    ", $3);
            print "- " $3 " (" $2 ")";
        }' >> "$report_file"
    )

    current_date=$(date -I -d "$current_date + 1 day")
done

echo -e "\nReport generated: $report_file"
