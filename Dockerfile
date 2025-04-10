# syntax=docker/dockerfile:1
FROM lwthiker/curl-impersonate:0.6-chrome-slim-bullseye as curlStage

FROM node:22

# Install required packages
RUN apt-get update \
    && apt-get install -y wget gnupg \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 zstd \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Copy the impersonate library from the previous stage
COPY --from=curlStage /usr/local/lib/libcurl-impersonate.so /usr/local/lib/libcurl-impersonate.so

# Create group and user (adjust if needed)
RUN groupadd -r jina && useradd -r -g jina -G audio,video -m jina

# Switch to the new user; if permission issues occur during build, run as root first, then switch before runtime.
USER jina

WORKDIR /app

# Copy package files and set correct ownership
COPY package.json package-lock.json ./
# Fix permissions - ensure the jina user can write to node_modules:
RUN chown -R jina:jina /app
RUN npm ci

# Copy all source code
COPY build ./build
COPY public ./public
COPY licensed ./licensed

# Prepare chromium config directory
RUN rm -rf ~/.config/chromium && mkdir -p ~/.config/chromium

RUN NODE_COMPILE_CACHE=node_modules npm run dry-run

# Set environment variables (modify as needed)
ENV OVERRIDE_CHROME_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
ENV LD_PRELOAD=/usr/local/lib/libcurl-impersonate.so CURL_IMPERSONATE=chrome116 CURL_IMPERSONATE_HEADERS=no
ENV NODE_COMPILE_CACHE=node_modules
ENV PORT=8080

# Expose the required ports
EXPOSE 8080

ENTRYPOINT ["node"]
CMD [ "build/stand-alone/crawl.js" ]
