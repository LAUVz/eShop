FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/PaymentProcessor/PaymentProcessor.csproj", "src/PaymentProcessor/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/PaymentProcessor/PaymentProcessor.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/PaymentProcessor"
RUN dotnet publish "PaymentProcessor.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8086
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "PaymentProcessor.dll"]
