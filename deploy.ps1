#region 0 — Variables
# Defines all the names/values we'll reuse throughout the script
$ResourceGroup = "rg-imen.abdelmoula-3929"
$AppName       = "app-imen-abdelmoula-3929"
$PlanName      = "plan-imen-abdelmoula-3929"
$Location      = "swedencentral"
$Sku           = "B1"
$Runtime       = "PYTHON:3.13"
$StartupCmd    = "python app.py"
$SourceDir     = if ($PSScriptRoot) { $PSScriptRoot } else {
    "C:\student-ai-assistant"
}
$ZipPath       = Join-Path $SourceDir "\student-ai-assistant.zip"
#endregion
#verification region0:$AppName

#region 1 — (optional) Confirm you are logged in to the right subscription
# Confirms you're connected to the right Azure account
# Prevents deploying to the wrong subscription by mistake
az account show -o table
#endregion

#region 2 — Create the Linux App Service plan
# Reserves the RESOURCES (CPU, RAM) on Azure
az appservice plan create -g $ResourceGroup -n $PlanName --is-linux --sku $Sku `
  --query "{Name:name, Tier:sku.tier, Size:sku.name, Location:location, State:provisioningState}" -o table
#endregion

#region 3 — Create the web app
# Creates the SERVER that will host your code
az webapp create -g $ResourceGroup -p $PlanName -n $AppName --runtime $Runtime `
  --query "{Name:name, Host:defaultHostName, State:state, Location:location}" -o table
#endregion

#region 4 — Config values
# Prepares the environment variables LOCALLY in PowerShell
# So they can be sent to Azure in region 5
$FoundryEndpoint = "https://student-assistant-resource.services.ai.azure.com/api/projects/student-assistant"
$AgentName       = "StudentAssistant"
$FlaskSecretKey = "b06925f6b1fc4ebad2cce02112399884c8ac9b18005d5e0f17a318b9e0829c52"
#endregion

#region 5 — Set the config values on Azure
# 1) build automation, so pip installs requirements.txt during the deploy
az webapp config appsettings set -g $ResourceGroup -n $AppName `
  --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true | Out-Null
# 2) startup command (the container can't launch without it)
az webapp config set -g $ResourceGroup -n $AppName --startup-file $StartupCmd | Out-Null
# 3) app settings the code reads at startup
az webapp config appsettings set -g $ResourceGroup -n $AppName --settings `
  "FLASK_SECRET_KEY=$FlaskSecretKey" `
  "FOUNDRY_ENDPOINT=$FoundryEndpoint" `
  "AGENT_NAME=$AgentName" | Out-Null

# Show what actually got stored. (The 'set' command always echoes value:null, which looks like a
# failure but isn't — this list proves the values landed. CLIENTSECRET is hidden so it stays off-camera.)
az webapp config appsettings list -g $ResourceGroup -n $AppName `
  --query "[?name!='FLASK_SECRET_KEY'].{name:name, value:value}" -o table
#endregion

#region 6 — Managed Identity
# Grants the App Service PERMISSION to call Foundry
# Without this, Azure blocks your app from accessing Foundry
$principalId = az webapp identity assign -g $ResourceGroup -n $AppName --query principalId -o tsv

$FoundryResourceName = ([uri]$FoundryEndpoint).Host.Split('.')[0]
$foundryScope = az cognitiveservices account list `
  --query "[?name=='$FoundryResourceName'].id | [0]" -o tsv

az role assignment create `
  --assignee-object-id $principalId `
  --assignee-principal-type ServicePrincipal `
  --role "Foundry User" `
  --scope $foundryScope -o table
#endregion

#region 7 — Zip + Deploy
# Compresses your code (app.py, templates, static) and uploads it to Azure
# This is the moment your actual code lands on the server
$exclude = @(".venv", ".env", "deploy.ps1", "student-ai-assistant.zip", "app.zip", "__pycache__", ".git")
$items   = Get-ChildItem -Path $SourceDir -Force |
           Where-Object { $exclude -notcontains $_.Name }
Compress-Archive -Path $items.FullName -DestinationPath $ZipPath -Force
az webapp deploy -g $ResourceGroup -n $AppName --src-path $ZipPath --type zip
#endregion