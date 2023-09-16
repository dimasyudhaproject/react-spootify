# First stage
FROM node@sha256:a1f9d027912b58a7c75be7716c97cfbc6d3099f3a97ed84aa490be9dee20e787 AS builder

# Set the Alpine repositories to specific versions and also include edge repositories.
# Clean up whitespace from the repository file.
RUN echo -e "https://dl-cdn.alpinelinux.org/alpine/v$(cut -d'.' -f1,2 /etc/alpine-release)/main/\n \
             https://dl-cdn.alpinelinux.org/alpine/v$(cut -d'.' -f1,2 /etc/alpine-release)/community/\n \
             https://dl-cdn.alpinelinux.org/alpine/edge/testing/\n \
             https://dl-cdn.alpinelinux.org/alpine/edge/community/\n \
             https://dl-cdn.alpinelinux.org/alpine/edge/main/" > /etc/apk/repositories && \
    sed -i 's/^[ \t]*//;s/[ \t]*$//' /etc/apk/repositories

# Update package list and install a specific version of yarn
RUN apk update && \
    apk add --no-cache yarn=1.22.19-r0

# Create a new group and user 'nonroot' with specific IDs
RUN addgroup -g 10001 \
             -S nonroot && \
    adduser  -u 10000 \
             -G nonroot \
             -h /home/nonroot \
             -S nonroot

# Set 'nonroot' as the active user
USER nonroot:nonroot

# Set working directory to 'nonroot' user's home
WORKDIR /home/nonroot

# Copy package.json and yarn.lock files into the working directory
COPY ./package.json ./yarn.lock ./

# Install npm packages using the locked versions
RUN yarn install --frozen-lockfile

# Copy all files from the current directory to the working directory
COPY . .

# Build the application using yarn
RUN yarn build

# Second stage
FROM nginx@sha256:c158a8722cc5c67d557697606a1d8d9b942e568b521df9f8723e1d8aa0227485

# Copy the Alpine repositories from the builder stage to ensure package consistency
COPY --from=builder /etc/apk/repositories /etc/apk

# Update package list and install specific versions of tini and bind-tools
RUN apk update && \
    apk add --no-cache tini=0.19.0-r1 \
                       bind-tools=9.18.16-r0

# Copy the built application from the builder stage to the nginx html directory
COPY --from=builder /home/nonroot/build /usr/share/nginx/html

# Use tini as the entrypoint to handle process signaling
ENTRYPOINT ["/sbin/tini", "--"]

# Start nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]