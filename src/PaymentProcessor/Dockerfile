FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0-preview AS build
WORKDIR /src

# Copy ALL source first to avoid missing project references
COPY . .

# Restore and build
WORKDIR "/src/src/PaymentProcessor"
RUN dotnet restore "PaymentProcessor.csproj"
RUN dotnet publish "PaymentProcessor.csproj" -c Release -o /app/publish

# Runtime
FROM mcr.microsoft.com/dotnet/nightly/aspnet:10.0-preview
WORKDIR /app
EXPOSE 8086
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "PaymentProcessor.dll"]
