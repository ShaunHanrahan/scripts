#! /usr/bin/env bash

# Variables
PROJECT_ID="$1"
FILE_PATH="$2"

# Check if the user is logged in to GitHub
if ! gh auth status >/dev/null 2>&1; then
    echo "Please login to GitHub using 'gh auth login'"
    exit 1
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    echo "File not found: $FILE_PATH"
    exit 1
fi

# Loop through each line in the file and add item to the project
while IFS= read -r TITLE; do
    # Skip empty lines
    if [[ -z "$TITLE" ]]; then
        continue
    fi

    # Add item to the project
    gh api graphql -f query='
    mutation {
        addProjectV2DraftIssue(input: {projectId: "'"$PROJECT_ID"'",  title: "'"$TITLE"'", body: ""}) {
            projectItem {
                id
            }
        }
    }'

    # Feedback to the user for each line
    echo "Item '$TITLE' added to the project successfully!"
done < "$FILE_PATH"