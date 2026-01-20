FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/WebhookClient/WebhookClient.csproj", "src/WebhookClient/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/WebhookClient/WebhookClient.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/WebhookClient"
RUN dotnet publish "WebhookClient.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8088
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "WebhookClient.dll"]
