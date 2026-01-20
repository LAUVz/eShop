FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0-preview AS build
WORKDIR /src

# Copy ALL source first to avoid missing project references
COPY . .

# Remove global.json to allow Docker SDK version flexibility
RUN rm -f global.json

# Restore and build
WORKDIR "/src/src/WebhookClient"
RUN dotnet restore "WebhookClient.csproj"
RUN dotnet publish "WebhookClient.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/nightly/aspnet:10.0-preview
WORKDIR /app
EXPOSE 8088
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "WebhookClient.dll"]
