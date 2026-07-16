FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY certs/avast-web-shield-root.pem /usr/local/share/ca-certificates/avast-web-shield-root.crt
RUN update-ca-certificates

COPY pubspec.yaml pubspec.lock analysis_options.yaml ./
RUN flutter pub get

COPY . .

ARG API_URL=http://localhost:4000/api
ARG GOOGLE_CLIENT_ID=
RUN flutter build web --release --dart-define=API_URL=${API_URL} --dart-define=GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}

FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
