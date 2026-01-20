FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0-preview AS build
WORKDIR /src

# Copy ALL source first to avoid missing project references
COPY . .

# Remove global.json to allow Docker SDK version flexibility
RUN rm -f global.json

# Restore and build
WORKDIR "/src/src/Webhooks.API"
RUN dotnet restore "Webhooks.API.csproj"
RUN dotnet publish "Webhooks.API.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/nightly/aspnet:10.0-preview
WORKDIR /app
EXPOSE 8085
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Webhooks.API.dll"]
