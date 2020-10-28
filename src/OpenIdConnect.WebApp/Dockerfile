FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS base
WORKDIR /app
EXPOSE 5000
EXPOSE 5001
EXPOSE 5050

FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
WORKDIR /src
COPY ["src/OpenIdConnect.WebApp/OpenIdConnect.WebApp.csproj", "src/OpenIdConnect.WebApp/"]
RUN dotnet restore "src/OpenIdConnect.WebApp/OpenIdConnect.WebApp.csproj"
COPY . .
WORKDIR "/src/src/OpenIdConnect.WebApp"
RUN dotnet build "OpenIdConnect.WebApp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "OpenIdConnect.WebApp.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "OpenIdConnect.WebApp.dll"]
