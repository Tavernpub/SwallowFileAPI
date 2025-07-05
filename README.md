# SwallowPro 文件上传服务

一个基于 Node.js + Express + Multer 的文件上传服务，支持图片文件上传、存储和访问，配合 Nginx 反向代理提供完整的文件服务解决方案。

## 项目特性

- 🚀 **高性能**: 基于 Express.js 构建，支持高并发文件上传
- 🔒 **安全可靠**: 文件类型验证、大小限制、错误处理
- 📁 **灵活存储**: 支持自定义存储目录，文件命名策略
- 🌐 **跨域支持**: 完整的 CORS 配置，支持前端跨域访问
- 🔄 **反向代理**: 支持 Nginx 反向代理，提供域名访问
- 📊 **详细日志**: 完整的请求日志和错误日志记录
- 🛠️ **一键部署**: 自动化部署脚本，支持 systemd 服务管理

## 技术栈

- **后端**: Node.js + Express.js
- **文件处理**: Multer
- **跨域处理**: CORS
- **日志记录**: Morgan
- **服务管理**: Systemd
- **反向代理**: Nginx

## 快速开始

### 环境要求

- CentOS 7/8 或 Ubuntu 18.04+
- Node.js 12+
- Nginx (可选，用于反向代理)
- 宝塔面板 (可选，用于图形化管理)

### 一键部署

1. **上传脚本到服务器**
   ```bash
   # 下载FileAPI.sh文件，将文件上传至云服务器根目录的/opt/文件夹
  
   ```

2. **运行部署脚本**
   ```bash
   # 在opt文件夹下的终端输入以下命令
   ./FileAPI.sh
   ```

3. **验证服务**
   ```bash
   # 检查服务状态
   ./FileAPI.sh status
   
   # 查看日志
   ./FileAPI.sh logs
   ```

### 服务命令管理

```bash
# 启动服务
./FileAPI.sh start
  ```
# 停止服务
./FileAPI.sh stop
  ```
# 重启服务
./FileAPI.sh restart
  ```
# 查看状态
./FileAPI.sh status
  ```
# 查看日志
./FileAPI.sh logs
```

## API 文档

### 基础信息

- **服务地址**: `http://localhost:3000` 
- **文件存储**: `/opt/uploads`
- **最大文件大小**: 10MB
- **支持格式**: JPEG, PNG, GIF

### 接口列表

#### 1. 健康检查

```http
GET /health
```

**响应示例**:
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### 2. 文件上传

```http
POST /upload
Content-Type: multipart/form-data
```

**请求参数**:
- `file`: 图片文件 (必需)

**响应示例**:
```json
{
  "code": 200,
  "message": "上传成功",
  "data": {
    "file_url": "https://file.swallowpro.top/files/example.jpg",
    "file_name": "example.jpg"
  }
}
```

**错误响应**:
```json
{
  "code": 400,
  "message": "只允许上传图片文件"
}
```

#### 3. 文件访问

```http
GET /files/{filename}
```

**参数**:
- `filename`: 文件名 (必需)

**响应**: 直接返回文件内容

## Nginx 反向代理配置

### 宝塔面板配置

1. **添加站点**
   - 域名: `file.swallowpro.top`（填写你的文件服务器域名）
   - php版本:纯静态
     

2. **配置反向代理**
   点击域名进入站点修改
   找到反向代理添加一个代理
   目标url填写127.0.1:3030
   在新添加的反向代理下点击配置文件，将下面内容填写进去

```nginx
# 文件上传接口
location /upload {
    proxy_pass http://localhost:3000/upload;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    client_max_body_size 10M;
}

# 文件访问接口
location /files/ {
    proxy_pass http://localhost:3000/files/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# 健康检查接口
location /health {
    proxy_pass http://localhost:3000/health;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### 手动配置

如果使用手动配置的 Nginx，在 `/etc/nginx/sites-available/` 中创建配置文件:

```nginx
server {
    listen 80;
    server_name file.swallowpro.top;
    
    # 文件上传接口
    location /upload {
        proxy_pass http://localhost:3000/upload;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 10M;
    }
    
    # 文件访问接口
    location /files/ {
        proxy_pass http://localhost:3000/files/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 健康检查接口
    location /health {
        proxy_pass http://localhost:3000/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 前端集成示例

### JavaScript (uni-app)

```javascript
// 上传图片
uni.uploadFile({
  url: 'https://file.swallowpro.top/upload',
  filePath: tempFilePath,
  name: 'file',
  success: (res) => {
    const data = JSON.parse(res.data);
    if (data.code === 200) {
      console.log('上传成功:', data.data.file_url);
    } else {
      console.error('上传失败:', data.message);
    }
  },
  fail: (err) => {
    console.error('上传错误:', err);
  }
});
```

### JavaScript (原生)

```javascript
// 上传图片
const formData = new FormData();
formData.append('file', fileInput.files[0]);

fetch('https://file.swallowpro.top/upload', {
  method: 'POST',
  body: formData
})
.then(response => response.json())
.then(data => {
  if (data.code === 200) {
    console.log('上传成功:', data.data.file_url);
  } else {
    console.error('上传失败:', data.message);
  }
})
.catch(error => {
  console.error('上传错误:', error);
});
```


```

## 配置说明

### 环境变量

- `NODE_ENV`: 运行环境 (production/development)
- `PORT`: 服务端口 (默认: 3000)

### 文件配置

- **上传目录**: `/opt/uploads`
- **日志文件**: 
  - `/var/log/fileapi.log` (标准输出)
  - `/var/log/fileapi.error.log` (错误日志)
- **服务文件**: `/etc/systemd/system/fileapi.service`

## 常见问题

### Q: 上传大文件失败
A: 检查 Nginx 配置中的 `client_max_body_size` 设置，确保大于文件大小限制。

### Q: 无法访问上传的文件
A: 检查文件权限和 Nginx 反向代理配置，确保 `/opt/uploads` 目录可读。

### Q: 服务启动失败
A: 查看错误日志 `/var/log/fileapi.error.log`，检查端口是否被占用。

### Q: 跨域请求失败
A: 确认 CORS 配置正确，或检查前端请求头设置。

## 开发指南

### 本地开发

1. **安装依赖**
   ```bash
   cd FileAPI
   npm install
   ```

2. **启动服务**
   ```bash
   npm start
   ```

3. **测试接口**
   ```bash
   curl -X POST -F "file=@test.jpg" http://localhost:3000/upload
   ```

### 自定义配置

修改 `server.js` 中的配置:

```javascript
const port = process.env.PORT || 3000;
const uploadDir = process.env.UPLOAD_DIR || '/opt/uploads';
const maxFileSize = 10 * 1024 * 1024; // 10MB
```

## 许可证

Tavern版权所有



## 联系方式

如有问题，请通过以下方式联系:


- 发送邮件至 tavernpub@yeah.net
- QQ 2196008384

---

**注意**: 本服务仅用于学习和开发目的。 
