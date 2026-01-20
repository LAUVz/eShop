FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/Basket.API/Basket.API.csproj", "src/Basket.API/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/Basket.API/Basket.API.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/Basket.API"
RUN dotnet publish "Basket.API.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8083
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Basket.API.dll"]
