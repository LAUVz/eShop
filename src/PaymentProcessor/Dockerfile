# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy solution and project files
COPY ["src/PaymentProcessor/PaymentProcessor.csproj", "src/PaymentProcessor/"]
COPY ["src/ServiceDefaults/ServiceDefaults.csproj", "src/ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/PaymentProcessor/PaymentProcessor.csproj"

# Copy all source files
COPY . .

# Build the project
WORKDIR "/src/src/PaymentProcessor"
RUN dotnet build "PaymentProcessor.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "PaymentProcessor.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "PaymentProcessor.dll"]
