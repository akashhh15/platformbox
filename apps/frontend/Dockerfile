# syntax=docker/dockerfile:1
FROM nginx:1.31.0-alpine AS runtime

# Remove default site and copy our static assets and main config.
RUN rm -f /etc/nginx/conf.d/default.conf \
    && chown -R 101:101 /usr/share/nginx/html /var/cache/nginx /var/run /etc/nginx /tmp

COPY --chown=101:101 nginx-main.conf /etc/nginx/nginx.conf
COPY --chown=101:101 nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=101:101 src/ /usr/share/nginx/html/

USER 101:101

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["wget", "-qO-", "http://127.0.0.1:8080/"]

CMD ["nginx", "-g", "daemon off;"]
