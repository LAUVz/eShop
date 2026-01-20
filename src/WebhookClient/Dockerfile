# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["src/WebhookClient/WebhookClient.csproj", "src/WebhookClient/"]
COPY ["src/ServiceDefaults/ServiceDefaults.csproj", "src/ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/WebhookClient/WebhookClient.csproj"

# Copy all source files
COPY . .

# Build the project
WORKDIR "/src/src/WebhookClient"
RUN dotnet build "WebhookClient.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "WebhookClient.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
EXPOSE 8080

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "WebhookClient.dll"]
