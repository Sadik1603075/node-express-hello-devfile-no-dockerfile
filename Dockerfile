FROM node:lts-alpine3.22 AS build

# Set working directory
WORKDIR /usr/src/app

# Install only production dependencies
COPY package*.json ./
RUN npm install --only=production

COPY . .

# RUNTIME STAGE 
FROM node:lts-alpine3.22 AS runtime

# Create app directory
WORKDIR /usr/src/app

# Copy node_modules and app files from build stage
COPY --from=build /usr/src/app .

# Set environment variables for production
ENV NODE_ENV=production
ENV PORT=3000

# Expose the application port
EXPOSE 3000

# Start the application
CMD ["node", "app.js"]
