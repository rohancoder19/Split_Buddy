FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
COPY --from=build /app/build/web /app/build/web

EXPOSE 8080
CMD ["dart", "bin/server.dart"]
