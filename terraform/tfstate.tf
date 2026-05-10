# Login + subscription set
az login
az account set --subscription "<your-subscription-id>"

# State storage
RG="tfstate-rg"
LOC="southeastasia"
SA="hydrustfstate$RANDOM"   # wpuld be globally unique
CONTAINER="tfstate"

az group create -n $RG -l $LOC
az storage account create -n $SA -g $RG -l $LOC --sku Standard_LRS --encryption-services blob
az storage container create -n $CONTAINER --account-name $SA

echo "Storage Account: $SA"
echo "Container: $CONTAINER"
