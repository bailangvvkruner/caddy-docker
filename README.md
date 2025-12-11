# Caddy Docker 构建项目

这是一个用于构建和运行Caddy服务器的Docker项目。Caddy是一个现代化的、功能强大的Web服务器，支持自动HTTPS、HTTP/2、反向代理等特性。

## 项目特点

- 🐳 使用多阶段Docker构建，生成极小的镜像
- 🔒 完全静态二进制文件，增强安全性
- 📦 基于scratch基础镜像，最小化镜像大小
- 👤 使用非root用户运行，提高安全性
- 🔧 支持自定义Caddyfile配置

## 构建Docker镜像

### 1. 直接构建

```bash
# 构建镜像
docker build -t caddy-custom .

# 查看构建的镜像
docker images | grep caddy-custom
```

### 2. 使用构建缓存（推荐）

```bash
# 使用构建缓存加速后续构建
docker build --cache-from caddy-custom -t caddy-custom .
```

## 运行Caddy容器

### 1. 基本运行（使用默认配置）

```bash
# 创建本地目录用于存储配置和网站文件
mkdir -p ./caddy-data/{config,data,logs,www}

# 复制示例配置文件
cp Caddyfile ./caddy-data/config/

# 创建简单的测试网站
echo "<h1>Hello from Caddy!</h1>" > ./caddy-data/www/index.html

# 运行容器
docker run -d \
  --name caddy-server \
  -p 80:80 \
  -p 443:443 \
  -p 2019:2019 \
  -v $(pwd)/caddy-data:/caddydir \
  caddy-custom
```

### 2. 使用docker-compose（推荐）

创建 `docker-compose.yml` 文件：

```yaml
version: '3.8'

services:
  caddy:
    build: .
    container_name: caddy-server
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "2019:2019"
    volumes:
      - ./caddy-data:/caddydir
    environment:
      - TZ=Asia/Shanghai
      - CADDYPATH=/caddydir/data
    networks:
      - caddy-network

networks:
  caddy-network:
    driver: bridge
```

然后运行：

```bash
# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 3. 生产环境运行

```bash
docker run -d \
  --name caddy-production \
  --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -v /path/to/caddy-data:/caddydir \
  -v /etc/localtime:/etc/localtime:ro \
  -e TZ=Asia/Shanghai \
  -e CADDYPATH=/caddydir/data \
  caddy-custom
```

## 配置文件说明

### Caddyfile 配置

项目包含一个示例 `Caddyfile`，位于项目根目录。这个文件会在容器启动时被加载。主要配置包括：

1. **静态文件服务**：在 `localhost:8080` 提供 `/caddydir/www` 目录下的文件
2. **日志配置**：访问日志存储在 `/caddydir/logs/access.log`
3. **Gzip压缩**：启用响应压缩
4. **反向代理示例**：注释示例，可按需启用

### 自定义配置

要自定义配置，可以：

1. 直接修改 `Caddyfile` 文件
2. 或创建自己的配置文件并挂载到容器：

```bash
docker run -d \
  --name caddy-custom \
  -p 80:80 \
  -p 443:443 \
  -v $(pwd)/my-caddyfile:/caddydir/Caddyfile:ro \
  -v $(pwd)/website:/caddydir/www:ro \
  caddy-custom
```

## 目录结构

```
/caddydir/
├── Caddyfile      # Caddy配置文件
├── data/          # Caddy数据目录（自动HTTPS证书等）
├── logs/          # 日志文件目录
└── www/           # 网站文件目录
```

## 常用命令

### 查看日志

```bash
# 查看容器日志
docker logs caddy-server

# 实时查看日志
docker logs -f caddy-server
```

### 进入容器

```bash
# 进入容器shell（如果基础镜像支持）
docker exec -it caddy-server sh
```

### 管理容器

```bash
# 停止容器
docker stop caddy-server

# 启动容器
docker start caddy-server

# 重启容器
docker restart caddy-server

# 删除容器
docker rm caddy-server

# 删除镜像
docker rmi caddy-custom
```

## 故障排除

### 1. 权限问题

如果遇到权限问题，确保挂载目录的权限正确：

```bash
# 设置正确的目录权限
chown -R 1000:1000 ./caddy-data
chmod -R 755 ./caddy-data
```

### 2. 端口冲突

如果端口被占用，可以修改映射端口：

```bash
docker run -d \
  --name caddy-server \
  -p 8080:80 \
  -p 8443:443 \
  -v $(pwd)/caddy-data:/caddydir \
  caddy-custom
```

### 3. 配置文件错误

检查Caddyfile语法：

```bash
# 验证Caddyfile语法
docker run --rm \
  -v $(pwd)/caddy-data:/caddydir \
  caddy-custom validate
```

## 开发说明

### 构建优化

当前的Docker构建配置：

1. **多阶段构建**：构建阶段使用golang:alpine，运行阶段使用scratch
2. **静态链接**：使用 `-extldflags -static` 创建完全静态二进制文件
3. **二进制优化**：使用strip减少二进制文件大小
4. **安全加固**：使用非root用户运行

### 已知问题

1. **UPX压缩不兼容**：完全静态二进制文件与UPX压缩工具不兼容，因此跳过了UPX压缩步骤
2. **scratch镜像限制**：scratch镜像不包含shell，调试较为困难

## 许可证

本项目基于MIT许可证。Caddy本身基于Apache 2.0许可证。

## 参考链接

- [Caddy官方文档](https://caddyserver.com/docs/)
- [Caddy GitHub仓库](https://github.com/caddyserver/caddy)
- [Docker多阶段构建文档](https://docs.docker.com/build/building/multi-stage/)
