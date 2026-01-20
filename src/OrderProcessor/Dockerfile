FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0-preview AS build
WORKDIR /src

# Copy ALL source first to avoid missing project references
COPY . .

# Restore and build
WORKDIR "/src/src/OrderProcessor"
RUN dotnet restore "OrderProcessor.csproj"
RUN dotnet publish "OrderProcessor.csproj" -c Release -o /app/publish /p:GenerateDocumentationFile=false

# Runtime
FROM mcr.microsoft.com/dotnet/nightly/aspnet:10.0-preview
WORKDIR /app
EXPOSE 8087
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "OrderProcessor.dll"]
