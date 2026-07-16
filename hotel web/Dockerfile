FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production
ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/avast-web-shield-root.crt

RUN mkdir -p /usr/local/share/ca-certificates
COPY hotel_casablanca_flutter/certs/avast-web-shield-root.pem /usr/local/share/ca-certificates/avast-web-shield-root.crt

COPY package*.json ./
RUN npm ci --omit=dev

COPY index.js db.js ./
COPY controllers ./controllers
COPY routes ./routes
COPY middlewares ./middlewares
COPY uploads ./uploads

EXPOSE 4000

CMD ["node", "index.js"]
