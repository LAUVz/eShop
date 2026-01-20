FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0-preview AS build
WORKDIR /src

# Copy ALL source first to avoid missing project references
COPY . .

# Restore and build
WORKDIR "/src/src/Catalog.API"
RUN dotnet restore "Catalog.API.csproj"
RUN dotnet publish "Catalog.API.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/nightly/aspnet:10.0-preview
WORKDIR /app
EXPOSE 8082
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Catalog.API.dll"]
