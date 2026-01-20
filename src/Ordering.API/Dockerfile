FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/Ordering.API/Ordering.API.csproj", "src/Ordering.API/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/Ordering.API/Ordering.API.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/Ordering.API"
RUN dotnet publish "Ordering.API.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8084
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Ordering.API.dll"]
