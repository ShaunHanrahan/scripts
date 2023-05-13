# Define token, secret and API URLs
$tokenId = "hbPdZxer4i4SCv4A0Lc5i4O2hpDqPHbK"
$tokenSecret = "empJxrldP72fk8wtnBr77uBYfFwPNMJX"
$listPagesUrl = "https://docs.domain.com/api/pages"
$exportMarkdownUrlTemplate = "https://docs.domain.com/api/pages/{0}/export/markdown"

# Define header with API token and secret
$headers = @{
    'Authorization' = "Token $($tokenId):$($tokenSecret)"
}

# Get all pages
$response = Invoke-RestMethod -Uri $listPagesUrl -Method Get -Headers $headers
$pages = $response.data

# Loop through each page and export it
foreach ($page in $pages) {
    $pageId = $page.id
    $exportMarkdownUrl = $exportMarkdownUrlTemplate -f $pageId
    $pageExport = Invoke-RestMethod -Uri $exportMarkdownUrl -Method Get -Headers $headers

    # Export the page to markdown file
    $pageExport | Out-File -FilePath "$($page.slug).md"
}
