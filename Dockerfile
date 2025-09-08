# Use Node.js base image
FROM node:18-alpine

# Create app directory
WORKDIR /app

# Create a simple HTTP server
COPY server.js .

# Expose port
EXPOSE 8080


# Run the server
CMD ["node", "server.js"]
