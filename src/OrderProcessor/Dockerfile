# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["src/OrderProcessor/OrderProcessor.csproj", "src/OrderProcessor/"]
COPY ["src/ServiceDefaults/ServiceDefaults.csproj", "src/ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/OrderProcessor/OrderProcessor.csproj"

# Copy all source files
COPY . .

# Build the project
WORKDIR "/src/src/OrderProcessor"
RUN dotnet build "OrderProcessor.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "OrderProcessor.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "OrderProcessor.dll"]
