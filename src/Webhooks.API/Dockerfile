FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy Directory.*.props files for central package management
COPY ["Directory.Build.props", "./"]

# Copy solution and project files
COPY ["src/Webhooks.API/Webhooks.API.csproj", "src/Webhooks.API/"]
COPY ["src/EventBus/EventBus.csproj", "src/EventBus/"]
COPY ["src/EventBusRabbitMQ/EventBusRabbitMQ.csproj", "src/EventBusRabbitMQ/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/Webhooks.API/Webhooks.API.csproj"

# Copy source code
COPY . .

# Build and publish
WORKDIR "/src/src/Webhooks.API"
RUN dotnet build "Webhooks.API.csproj" -c Release -o /app/build
RUN dotnet publish "Webhooks.API.csproj" -c Release -o /app/publish --no-restore

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
EXPOSE 8085
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8085
ENTRYPOINT ["dotnet", "Webhooks.API.dll"]
