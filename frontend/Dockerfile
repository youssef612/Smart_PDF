FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# نسخ الملفات
COPY . .

# تثبيت الـ dependencies
RUN flutter pub get

# بناء الـ web
RUN flutter build web --release

# ─── Nginx لخدمة الـ Flutter web ───────────────────────
FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

# إعداد Nginx
RUN echo 'server { \
    listen 80; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
