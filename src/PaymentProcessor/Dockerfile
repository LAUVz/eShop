FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy Directory.*.props files for central package management
COPY ["Directory.Build.props", "./"]

# Copy solution and project files
COPY ["src/PaymentProcessor/PaymentProcessor.csproj", "src/PaymentProcessor/"]
COPY ["src/EventBus/EventBus.csproj", "src/EventBus/"]
COPY ["src/EventBusRabbitMQ/EventBusRabbitMQ.csproj", "src/EventBusRabbitMQ/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/PaymentProcessor/PaymentProcessor.csproj"

# Copy source code
COPY . .

# Build and publish
WORKDIR "/src/src/PaymentProcessor"
RUN dotnet build "PaymentProcessor.csproj" -c Release -o /app/build
RUN dotnet publish "PaymentProcessor.csproj" -c Release -o /app/publish --no-restore

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
EXPOSE 8086
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8086
ENTRYPOINT ["dotnet", "PaymentProcessor.dll"]
