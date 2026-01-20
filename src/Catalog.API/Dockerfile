FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/Catalog.API/Catalog.API.csproj", "src/Catalog.API/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/Catalog.API/Catalog.API.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/Catalog.API"
RUN dotnet publish "Catalog.API.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8082
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Catalog.API.dll"]
