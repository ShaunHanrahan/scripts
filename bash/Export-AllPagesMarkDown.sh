#!/bin/bash

# Define token, secret and API URLs
tokenId="hbPdZxer4i4SCv4A0Lc5i4O2hpDqPHbK"
tokenSecret="empJxrldP72fk8wtnBr77uBYfFwPNMJX"
listPagesUrl="https://docs.domain.com/api/pages"
exportMarkdownUrlTemplate="https://docs.domain.com/api/pages/%s/export/markdown"

# Define header with API token and secret
headers="Authorization: Token ${tokenId}:${tokenSecret}"

# Get all pages
pages=$(curl -s -H "${headers}" "${listPagesUrl}" | jq -c '.data[]')

# Loop through each page and export it
echo "${pages}" | while read page; do
    pageId=$(echo "${page}" | jq -r '.id')
    pageSlug=$(echo "${page}" | jq -r '.slug')
    exportMarkdownUrl=$(printf "${exportMarkdownUrlTemplate}" "${pageId}")

    # Get page export
    pageExport=$(curl -s -H "${headers}" "${exportMarkdownUrl}")

    # Export the page to markdown file
    echo "${pageExport}" > "${pageSlug}.md"
done
