# param(
#     [Parameter(Mandatory = $true)]
#     [string]$JsonString,

#     [Parameter(Mandatory = $true)]
#     [string]$StorageAccount,

#     [Parameter(Mandatory = $true)]
#     [string]$ResourceGroup,

#     [Parameter(Mandatory = $true)]
#     [string]$TableName
# )


     $AZURE_SUBSCRIPTION_ID_DEV = $env:subscriptionId  
     $AZURE_TENANT_ID = $env:AZURE_TENANT_ID  
     $AzSubscName = $env:Subsciption_Name                
 
     $StorageAccount = $env:StorageAccount        
     $ResourceGroup = $env:ResourceGroup 
     $JsonString = $env:JsonString
     $TableName = $env:TableName


     Write-Output " Subscription ID =  $($env:subscriptionId) "
     Write-Output " Tenant ID =  $($env:AZURE_TENANT_ID) "
     Write-Output " Subscription Name =  $($env:Subsciption_Name) "
     Write-Output " Storage Account =  $($env:StorageAccount) "
     Write-Output " Resource Group =  $($env:ResourceGroup) "
     Write-Output " Table Name =  $($env:TableName) "
     Write-Output " MetaData =  $($env:JsonString) "
     



# Define schema based on Terraform entity
$schema = @(
    "partition_key","dst_app","dst_en_kv_key","dst_encrypt","dst_filename","dst_folder",
    "dst_pgp_gpg","dst_sftp_host","dst_sftp_kv_key","dst_sftp_usrname","dst_folder_backup",
    "dst_kdmz_host_pull_bkp","SinkDirectory","dst_type","dst_kdmz_host_push","dst_kdmz_kv_key_push",
    "dst_kdmz_usrname_push","spo_path","src_de_kv_key","Src_pullinterfacename","src_encrypt",
    "src_filename","src_folder","src_path_folder","src_type","base_url","category",
    "src_sftp_host_pull","src_sftp_kv_key_pull","src_sftp_usrname_pull","dummy1","dummy2","dummy3","dummy4"
)

# Convert input string to object
try {
    $jsonData = $JsonString | ConvertFrom-Json
} catch {
    throw "Invalid JSON string provided."
}

# Handle both single object and array
if ($jsonData -isnot [System.Collections.IEnumerable]) {
    $jsonData = @($jsonData)
}

foreach ($row in $jsonData) {
    $rowProps = $row.PSObject.Properties.Name

    # Validate schema
    $missing = $schema | Where-Object { $_ -notin $rowProps }
    $extra   = $rowProps | Where-Object { $_ -notin $schema }

    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        throw "Schema mismatch! Missing: $($missing -join ', ') | Extra: $($extra -join ', ')"
    }
}

Write-Host "Schema validation passed. Inserting rows..."

# Get storage context and table reference
$ctx   = (Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccount).Context
$table = Get-AzStorageTable –Name $TableName –Context $ctx

# Insert rows
foreach ($row in $jsonData) {
    $partitionKey = $row.partition_key
    $rowKey = [guid]::NewGuid().ToString()   # Or replace with your JSON RowKey

    $entity = @{}
    foreach ($field in $schema) {
        if ($field -ne "partition_key") {
            $entity[$field] = $row.$field
        }
    }

    Add-AzTableRow -Table $table.CloudTable -PartitionKey $partitionKey -RowKey $rowKey -Property $entity
    Write-Host "✔ Inserted row with PartitionKey=$partitionKey RowKey=$rowKey"
}

Write-Host "All rows inserted successfully."
