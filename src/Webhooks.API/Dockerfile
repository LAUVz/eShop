FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/Webhooks.API/Webhooks.API.csproj", "src/Webhooks.API/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/Webhooks.API/Webhooks.API.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/Webhooks.API"
RUN dotnet publish "Webhooks.API.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8085
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Webhooks.API.dll"]
