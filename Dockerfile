# Use a lightweight Linux base image
FROM alpine:latest

# Install prerequisites
RUN apk add --no-cache \
    bash \
    exiftool \
    jq \
    coreutils

# Copy the script and entrypoint
COPY google-photos-takeout.sh /usr/local/bin/google-photos-takeout.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/google-photos-takeout.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["entrypoint.sh"]
