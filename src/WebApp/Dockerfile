FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy all project files for restore
COPY ["src/WebApp/WebApp.csproj", "src/WebApp/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore
RUN dotnet restore "src/WebApp/WebApp.csproj"

# Copy everything and build
COPY . .
WORKDIR "/src/src/WebApp"
RUN dotnet publish "WebApp.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
EXPOSE 8080
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "WebApp.dll"]
