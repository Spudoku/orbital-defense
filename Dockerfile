# Use a lightweight Linux base image
FROM ubuntu:noble

# Install required dependencies for Godot headless/server builds
RUN apt-get update && apt-get install -y \
	ca-certificates \
	libfontconfig1 \
	&& rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /app

# Copy your exported Godot server binary and its .pck file into the container
COPY export/server/ /app/

# Make sure the binary has execution permissions
RUN chmod +x /app/game_server.x86_64

# Expose the internal port (Railway will look for an EXPOSE command or PORT env)
EXPOSE 8910

# Run the server using your custom command-line argument flag
CMD ["./game_server.x86_64", "--server"]