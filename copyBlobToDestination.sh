Steps To Performed: 

Take Complete backup for the Azure Blob for Grafana Loki to the Destination Blob using azcopy.

#!/bin/bash
set -ex

SOURCE_SA_SAS_KEY=""
DESTINATION_SA_SAS_KEY=""
SOURCE_SA_URL=https://smartconxstgcontainerlog.blob.core.windows.net/chunks
DESTINATION_SA_URL=https://smartconxdevstorageacceu.blob.core.windows.net/chunks

azcopy copy "$SOURCE_SA_URL/?$SOURCE_SA_SAS_KEY" "$DESTINATION_SA_URL/?$DESTINATION_SA_SAS_KEY" --recursive


Final output for the above script:


100.0 %, 460737 Done, 0 Failed, 0 Pending, 0 Skipped, 460737 Total,
 

Job 1b438bae-db1c-c645-55b2-589e4108b2b4 summary
Elapsed Time (Minutes): 0.0668
Number of File Transfers: 460737
Number of Folder Property Transfers: 0
Number of Symlink Transfers: 0
Total Number of Transfers: 460737
Number of File Transfers Completed: 460737
Number of Folder Transfers Completed: 0
Number of File Transfers Failed: 0
Number of Folder Transfers Failed: 0
Number of File Transfers Skipped: 0
Number of Folder Transfers Skipped: 0
Total Number of Bytes Transferred: 23972947337
Final Job Status: Completed


if there are any failed transfers, run below command to list failed transactions, replace the JOB_ID from the above output


azcopy jobs show JOB_ID --with-status Failed



Resume the Failed Jobs using below commands:

provide Source Storage Account SAS TOKEN and Destination SAS TOKEN

azcopy jobs resume JOB_ID --source-sas "" --destination-sas ""




Move Grafana and Prometheus Disks to EU region:

        Replace the required Variables for source and target  in the scipt



#!/bin/bash
set -ex

TARGET_DISK_TARGET_RESOURCE_GROUP=SMARTCONX-DEV-RG-EU
TARGET_DISK_NAME=Prometheus-Dev
TARGET_DISK_SKU=StandardSSD_ZRS
TARGET_DISK_LOCATION=germanywestcentral
#Provide the size of the disks in GB. It should be greater than the VHD file size.
TARGET_DISK_SIZE=26

SOURCE_DISK_NAME=prometheus-dev
SOURCE_DISK_RESOURCE_GROUP=SmartconX-Dev-RG

DURATION_SECONDS=3600
STORAGE_ACCOUNT_NAME=smartconxdevstorageacceu
STORAGE_ACCOUNT_RESOURCE_GROUP=${TARGET_DISK_TARGET_RESOURCE_GROUP}
STORAGE_ACCOUNT_CONTAINER_NAME=${SOURCE_DISK_NAME}
STORAGE_ACCOUNT_BLOB_VHD_FILE_NAME="${STORAGE_ACCOUNT_CONTAINER_NAME}.vhd"



SAS_URL=$(az disk grant-access --resource-group $SOURCE_DISK_RESOURCE_GROUP --name $SOURCE_DISK_NAME --duration-in-seconds $DURATION_SECONDS --query [accessSas] -o tsv)

echo "Using SAS URL: $SAS_URL"

STORAGE_ACCOUNT_KEY=$(az storage account keys list \
 --account-name $STORAGE_ACCOUNT_NAME \
 --resource-group $STORAGE_ACCOUNT_RESOURCE_GROUP \
 --query "[0].value" \
 --output tsv)

# Create Container
az storage container create --name $STORAGE_ACCOUNT_CONTAINER_NAME --account-key $STORAGE_ACCOUNT_KEY --account-name $STORAGE_ACCOUNT_NAME

az storage blob copy start \
 --account-name $STORAGE_ACCOUNT_NAME \
 --account-key $STORAGE_ACCOUNT_KEY \
 --destination-container $STORAGE_ACCOUNT_CONTAINER_NAME \
 --destination-blob $STORAGE_ACCOUNT_BLOB_VHD_FILE_NAME \
 --source-uri $SAS_URL

## CHECK FOR STATUS TO BE SUCCESS 
while true; do
  copy_status=$(az storage blob show \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --container-name "$STORAGE_ACCOUNT_CONTAINER_NAME" \
    --name "$STORAGE_ACCOUNT_BLOB_VHD_FILE_NAME" \
    --query "properties.copy.status" \
    --output tsv)

  echo "Current copy status: $copy_status"

  if [[ "$copy_status" == "success" ]]; then
    echo "✅ Copy completed successfully."
    break
  elif [[ "$copy_status" == "failed" || "$copy_status" == "aborted" ]]; then
    echo "❌ Copy failed or was aborted."
    exit 1
  fi

  sleep 10  # Wait 10 seconds before checking again
done

vhd_blob_url=https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${STORAGE_ACCOUNT_CONTAINER_NAME}/${STORAGE_ACCOUNT_BLOB_VHD_FILE_NAME}

echo "using vhd_blob_url: ${vhd_blob_url}"

# create Disk from Blob VHD
az disk create --resource-group $TARGET_DISK_TARGET_RESOURCE_GROUP --name $TARGET_DISK_NAME --sku $TARGET_DISK_SKU --location $TARGET_DISK_LOCATION --size-gb $TARGET_DISK_SIZE --source $vhd_blob_url



Deploy to EU region Cluster using GitLab Pipelines.
