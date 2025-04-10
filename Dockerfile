# syntax=docker/dockerfile:1
FROM lwthiker/curl-impersonate:0.6-chrome-slim-bullseye as curlStage

FROM node:22

RUN apt-get update \
    && apt-get install -y wget gnupg \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 zstd \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Copy the impersonate library from the first stage
COPY --from=curlStage /usr/local/lib/libcurl-impersonate.so /usr/local/lib/libcurl-impersonate.so

# Create group and user
RUN groupadd -r jina && useradd -r -g jina -G audio,video -m jina

# Switch to the new user; if permission issues occur during build, you'll handle this in the copy command instead
USER jina

WORKDIR /app

# Copy package files and set ownership during copy using --chown
COPY --chown=jina:jina package.json package-lock.json ./

# Run npm ci (this should now work since the files already have the correct ownership)
RUN npm ci

# Copy the rest of the source code (setting ownership during copy)
COPY --chown=jina:jina build ./build
COPY --chown=jina:jina public ./public
COPY --chown=jina:jina licensed ./licensed

RUN rm -rf ~/.config/chromium && mkdir -p ~/.config/chromium

RUN NODE_COMPILE_CACHE=node_modules npm run dry-run

# Set environment variables
ENV OVERRIDE_CHROME_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
ENV LD_PRELOAD=/usr/local/lib/libcurl-impersonate.so CURL_IMPERSONATE=chrome116 CURL_IMPERSONATE_HEADERS=no
ENV NODE_COMPILE_CACHE=node_modules
ENV PORT=8080

# Expose only port 8080 (if that’s the one your application uses)
EXPOSE 8080

ENTRYPOINT ["node"]
CMD [ "build/stand-alone/crawl.js" ]
