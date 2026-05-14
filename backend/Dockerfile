# Use Node.js 22 LTS as the base image
FROM node:22-alpine AS development

# Create app directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install app dependencies
RUN npm install

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Production stage
FROM node:22-alpine AS production

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

WORKDIR /usr/src/app

# Copy package files for production
COPY package*.json ./

# Install only production dependencies
RUN npm install --omit=dev

# Copy built artifacts from the development stage
COPY --from=development /usr/src/app/dist ./dist

# Start the server
CMD ["node", "dist/main"]
