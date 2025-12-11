# Hugo Static Compilation Docker Build with BusyBox
# 使用 busybox:musl 作为基础镜像，提供基本shell环境

# 构建阶段 - 使用完整的构建环境
# FROM golang:1.21-alpine AS builder
FROM golang:alpine AS builder

WORKDIR /app

# 安装构建依赖（包括C++编译器和strip工具）
# 使用--no-scripts禁用触发器执行，避免busybox触发器在arm64架构下的兼容性问题
RUN set -eux && \
    FILENAME=caddy \
    && apk add --no-cache --no-scripts --virtual .build-deps \
    gcc \
    g++ \
    musl-dev \
    git \
    build-base \
    # 包含strip命令
    binutils \
    upx \
    ca-certificates \
    tzdata \
    # 直接下载并构建 caddy（无需本地源代码）
    && git clone --depth 1 https://github.com/caddyserver/caddy . \
    # 构建完全静态二进制文件（适用于scratch镜像）
    && CGO_ENABLED=1 go build \
    -tags extended,netgo,osusergo \
    -ldflags="-s -w -extldflags -static" \
    -o caddy \
    # 显示构建后的文件大小
    && echo "Binary size after build:" \
    && du -b caddy \
    # 使用strip进一步减小二进制文件大小
    && strip --strip-all caddy \
    && echo "Binary size after stripping:" \
    && du -b caddy
    # 注意：完全静态二进制文件（使用-extldflags -static）与UPX不兼容
    # 因此跳过UPX压缩，或者可以选择安装upx并使用动态链接
    # 如果需要UPX压缩，可以安装upx并取消注释下面的行
    # && upx --best --lzma caddy \
    # && echo "Binary size after upx:" \
    # && du -b caddy
    # 注意：这里故意不清理构建依赖，因为是多阶段构建，且清理会触发busybox触发器错误
    # 最终镜像只复制二进制文件，构建阶段的中间层不会影响最终镜像大小
    # # 清理构建依赖
    # && apk del --purge .build-deps \
    # && rm -rf /var/cache/apk/*

# 运行时阶段 - 使用busybox:musl（极小的基础镜像，包含基本shell）
# FROM busybox:musl
# FROM alpine:latest
FROM scratch AS pod
# FROM hectorm/scratch:latest AS pod


# 复制CA证书（用于HTTPS请求）
# COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 复制caddy二进制文件
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder --chown=1000 /app/caddy /caddy


EXPOSE 80 443 2019
# 创建非root用户（增强安全性）
# RUN adduser -D -u 1000 gowrk

ENV HOME=/caddydir \
    CADDYPATH=/caddydir/data \
    TZ=America/Montreal
# 设置工作目录
# WORKDIR /app

# 切换到非root用户
# USER gowrk

# Go 运行时优化：垃圾回收器（GC）调优
# GOGC 环境变量控制GC的频率。默认值是100，表示当堆大小翻倍时触发GC。
# 在内存充足的环境中，增大此值（例如 GOGC=200）可以减少GC的运行频率，
# 从而可能提升程序性能，但代价是消耗更多的内存。
# 您可以在 `docker run` 时通过 `-e GOGC=200` 来覆盖此默认设置。
ENV GOGC=100

# 设置入口点
VOLUME ["/caddydir"]
ENTRYPOINT ["/caddy"]
USER 1000

CMD ["run","--config","/caddydir/Caddyfile"]
# COPY --chown=1000 Caddyfile /caddydir/Caddyfile
# COPY --from=builder --chown=1000 /caddy/caddy /caddy
