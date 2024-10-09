# Stage 1: Build instance
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build

WORKDIR /src                                                                    
COPY ./src ./

# Build the NopCommerce main project
WORKDIR /src/Presentation/Nop.Web
RUN dotnet build Nop.Web.csproj -c Release

# Build all plugins and specify the output directory
WORKDIR /src/Plugins
RUN set -eux; \
    for dir in *; do \
        if [ -d "$dir" ]; then \
            dotnet build "$dir/$dir.csproj" -c Release -o /app/published/plugins/"$dir"; \
        fi; \
    done

# Publish the main NopCommerce project
WORKDIR /src/Presentation/Nop.Web
RUN dotnet publish Nop.Web.csproj -c Release -o /app/published

# Adjust permissions for the necessary directories
WORKDIR /app/published
RUN mkdir logs bin
RUN chmod 775 App_Data \
              App_Data/DataProtectionKeys \
              bin \
              logs \
              Plugins \
              wwwroot/bundles \
              wwwroot/db_backups \
              wwwroot/files/exportimport \
              wwwroot/icons \
              wwwroot/images \
              wwwroot/images/thumbs \
              wwwroot/images/uploaded \
              wwwroot/sitemaps

# Stage 2: Runtime instance
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime 

# Add globalization support
RUN apk add --no-cache icu-libs icu-data-full
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Install required packages
RUN apk add tiff --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/main/ --allow-untrusted
RUN apk add libgdiplus --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community/ --allow-untrusted
RUN apk add libc-dev tzdata --no-cache

# Copy the entrypoint script and adjust permissions
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

# Set working directory and copy the published app from the build stage
WORKDIR /app
COPY --from=build /app/published .

# Expose the application on port 80
ENV ASPNETCORE_URLS=http://+:80
EXPOSE 80
                            
# Set the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]
