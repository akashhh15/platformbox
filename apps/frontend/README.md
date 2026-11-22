# Frontend

Static single-page application for the Platform in a Box demo. Served by nginx.

## Local development

Open `src/index.html` in a browser, or serve it with any static server:

```bash
cd apps/frontend/src
python -m http.server 8080
```

Set `window.API_BASE` in the browser console to point at the API if it runs on
a different origin.

## Docker

```bash
docker build -t platformbox-frontend:dev apps/frontend
docker run --rm -p 8080:8080 platformbox-frontend:dev
```
