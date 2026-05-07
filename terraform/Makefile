
#init — will backend storage configure
terraform init

# What will be the create in the plan dev environment-
terraform plan -var-file=environments/dev.tfvars -out=tfplan

# Apply
terraform apply tfplan

# Show output — ACR login server, AKS cluster name 
terraform output

# kubeconfig setup
az aks get-credentials --resource-group hydrus-dev-rg --name hydrus-dev-aks --overwrite-existing

# verify
kubectl get nodes
