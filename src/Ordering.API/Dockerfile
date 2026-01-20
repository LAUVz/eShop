FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy Directory.*.props files for central package management
COPY ["Directory.Build.props", "./"]
COPY ["Directory.Build.targets", "./"]
COPY ["Directory.Packages.props", "./"]

# Copy solution and project files
COPY ["src/Ordering.API/Ordering.API.csproj", "src/Ordering.API/"]
COPY ["src/Ordering.Domain/Ordering.Domain.csproj", "src/Ordering.Domain/"]
COPY ["src/Ordering.Infrastructure/Ordering.Infrastructure.csproj", "src/Ordering.Infrastructure/"]
COPY ["src/EventBus/EventBus.csproj", "src/EventBus/"]
COPY ["src/EventBusRabbitMQ/EventBusRabbitMQ.csproj", "src/EventBusRabbitMQ/"]
COPY ["src/IntegrationEventLogEF/IntegrationEventLogEF.csproj", "src/IntegrationEventLogEF/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/Ordering.API/Ordering.API.csproj"

# Copy source code
COPY . .

# Build and publish
WORKDIR "/src/src/Ordering.API"
RUN dotnet build "Ordering.API.csproj" -c Release -o /app/build
RUN dotnet publish "Ordering.API.csproj" -c Release -o /app/publish --no-restore

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
EXPOSE 8084
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8084
ENTRYPOINT ["dotnet", "Ordering.API.dll"]
