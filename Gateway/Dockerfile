FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src
RUN mkdir -p /data && chown node:node /data

USER node
EXPOSE 8080

CMD ["node", "src/index.js"]
