# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["src/Basket.API/Basket.API.csproj", "src/Basket.API/"]
COPY ["src/ServiceDefaults/ServiceDefaults.csproj", "src/ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/Basket.API/Basket.API.csproj"

# Copy all source files
COPY . .

# Build the project
WORKDIR "/src/src/Basket.API"
RUN dotnet build "Basket.API.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "Basket.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
EXPOSE 8080

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Basket.API.dll"]
