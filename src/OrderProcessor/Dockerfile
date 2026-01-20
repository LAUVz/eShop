FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy Directory.*.props files for central package management
COPY ["Directory.Build.props", "./"]
COPY ["Directory.Build.targets", "./"]
COPY ["Directory.Packages.props", "./"]

# Copy solution and project files
COPY ["src/OrderProcessor/OrderProcessor.csproj", "src/OrderProcessor/"]
COPY ["src/EventBus/EventBus.csproj", "src/EventBus/"]
COPY ["src/EventBusRabbitMQ/EventBusRabbitMQ.csproj", "src/EventBusRabbitMQ/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/OrderProcessor/OrderProcessor.csproj"

# Copy source code
COPY . .

# Build and publish
WORKDIR "/src/src/OrderProcessor"
RUN dotnet build "OrderProcessor.csproj" -c Release -o /app/build
RUN dotnet publish "OrderProcessor.csproj" -c Release -o /app/publish --no-restore

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
EXPOSE 8087
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8087
ENTRYPOINT ["dotnet", "OrderProcessor.dll"]
