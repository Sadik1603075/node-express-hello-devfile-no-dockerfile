# BUILD STAGE
FROM node:lts-alpine3.22 AS build

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install --only=production

COPY . .

# RUNTIME STAGE 
FROM node:lts-alpine3.22 AS runtime

WORKDIR /usr/src/app

COPY --from=build /usr/src/app .

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["node", "app.js"]
