FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# نسخ pubspec أولاً لاستخدام Docker cache
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# نسخ باقي الملفات
COPY . .

# بناء الـ web
RUN flutter build web --release --base-href "/"

# ── Nginx ──────────────────────────────────────────────────
FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

# إعداد Nginx المخصص (SPA + proxy للـ backend API)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
