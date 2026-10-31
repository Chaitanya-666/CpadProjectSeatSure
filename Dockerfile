# One image = API + web app.
# Stage 1 builds the Flutter web app (Render has no Flutter SDK, so the
# build happens here). Stage 2 is a small Node image that runs the API and
# serves the built web files from api/public.

# Flutter is installed at the exact version used for development (3.47.7):
# the prebuilt Flutter images lag behind and fail the app's Dart SDK constraint.
FROM debian:bookworm-slim AS web
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH=/opt/flutter/bin:$PATH
RUN flutter config --no-analytics --no-cli-animations && flutter precache --web
WORKDIR /src/app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get
COPY app/ ./
RUN flutter build web --release

FROM node:24-alpine
WORKDIR /srv/api
ENV NODE_ENV=production
COPY api/package.json api/package-lock.json ./
RUN npm ci --omit=dev
COPY api/ ./
COPY --from=web /src/app/build/web ./public
EXPOSE 3000
USER node
# Apply any new migrations, then start. Safe to repeat: applied files are skipped.
CMD ["sh", "-c", "node scripts/migrate.js && node src/server.js"]
