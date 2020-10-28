#!/bin/bash
version=${1:-3.1}
repo=dotnet-samples/openidconnect
az acr login
az acr build -t ${repo}:latest -t ${repo}:${version}-{{.Run.ID}} -f ./src/OpenIdConnect.WebApp/Dockerfile .
