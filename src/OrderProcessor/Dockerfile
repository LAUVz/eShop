FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/OrderProcessor/OrderProcessor.csproj", "src/OrderProcessor/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/OrderProcessor/OrderProcessor.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/OrderProcessor"
RUN dotnet publish "OrderProcessor.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8087
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "OrderProcessor.dll"]
