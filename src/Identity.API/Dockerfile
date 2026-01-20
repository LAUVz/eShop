FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/Identity.API/Identity.API.csproj", "src/Identity.API/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/Identity.API/Identity.API.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/Identity.API"
RUN dotnet publish "Identity.API.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8081
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Identity.API.dll"]
