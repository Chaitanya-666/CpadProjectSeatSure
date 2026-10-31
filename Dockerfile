# One image = API + web app.
# Stage 1 builds the Flutter web app (Render has no Flutter SDK, so the
# build happens here). Stage 2 is a small Node image that runs the API and
# serves the built web files from api/public.

FROM ghcr.io/cirruslabs/flutter:stable AS web
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
