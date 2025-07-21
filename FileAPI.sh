#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 服务管理函数
start_service() {
    echo -e "${YELLOW}正在启动文件API服务...${NC}"
    systemctl start fileapi
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}服务启动成功！${NC}"
        systemctl status fileapi
    else
        echo -e "${RED}服务启动失败！${NC}"
        systemctl status fileapi
    fi
}

stop_service() {
    echo -e "${YELLOW}正在停止文件API服务...${NC}"
    systemctl stop fileapi
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}服务已停止！${NC}"
    else
        echo -e "${RED}服务停止失败！${NC}"
        systemctl status fileapi
    fi
}

restart_service() {
    echo -e "${YELLOW}正在重启文件API服务...${NC}"
    systemctl restart fileapi
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}服务重启成功！${NC}"
        systemctl status fileapi
    else
        echo -e "${RED}服务重启失败！${NC}"
        systemctl status fileapi
    fi
}

status_service() {
    echo -e "${YELLOW}正在查看服务状态...${NC}"
    systemctl status fileapi
}

check_logs() {
    echo -e "${YELLOW}正在查看服务日志...${NC}"
    echo -e "标准输出日志：${GREEN}/var/log/fileapi.log${NC}"
    echo -e "错误日志：${RED}/var/log/fileapi.error.log${NC}"
    echo -e "\n=== 最新日志内容 ===\n"
    tail -n 50 /var/log/fileapi.log
    echo -e "\n=== 最新错误日志 ===\n"
    tail -n 50 /var/log/fileapi.error.log
}

echo "=========================================="
echo "开始部署文件上传API服务器..."
echo "=========================================="

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 请以root用户运行此脚本${NC}"
    echo "请使用: sudo -i"
    echo "然后: cd /opt"
    echo "最后: ./FileAPI.sh"
    exit 1
fi

# 检查是否在/opt目录
if [ "$(pwd)" != "/opt" ]; then
    echo -e "${RED}错误: 请在/opt目录下运行此脚本${NC}"
    echo "当前目录: $(pwd)"
    echo "请使用: cd /opt"
    exit 1
fi

echo -e "${GREEN}检查通过，开始部署...${NC}"
echo "当前目录: $(pwd)"
echo "当前用户: $(whoami)"
echo "=========================================="

# 创建服务器目录和上传目录
echo -e "${YELLOW}创建必要目录...${NC}"
mkdir -p /opt/FileAPI
mkdir -p /opt/uploads
cd /opt/FileAPI

# 检查Node.js是否已安装
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js未安装，开始安装...${NC}"
    
    # 安装开发工具和依赖
    echo -e "${YELLOW}安装必要的开发工具和依赖...${NC}"
    yum groupinstall -y "Development Tools"
    yum install -y wget tar xz

    # 下载并安装Node.js 12
    echo -e "${YELLOW}下载并安装Node.js 12...${NC}"
    cd /usr/local/src
    wget https://nodejs.org/download/release/v12.22.12/node-v12.22.12-linux-x64.tar.xz
    tar -xf node-v12.22.12-linux-x64.tar.xz
    rm -rf /usr/local/node
    mv node-v12.22.12-linux-x64 /usr/local/node

    # 创建软链接
    ln -sf /usr/local/node/bin/node /usr/bin/node
    ln -sf /usr/local/node/bin/npm /usr/bin/npm

    # 返回工作目录
    cd /opt/FileAPI
else
    echo -e "${GREEN}Node.js已安装，版本: $(node -v)${NC}"
fi

# 获取node路径
NODE_PATH=$(which node)
if [ -z "$NODE_PATH" ]; then
    echo -e "${RED}无法找到node执行文件${NC}"
    exit 1
fi

# 检查package.json是否存在
if [ ! -f package.json ] || ! grep -q "file-type" package.json; then
    echo -e "${YELLOW}创建package.json...${NC}"
    cat > package.json << 'EOL'
{
    "name": "file-api",
    "version": "1.0.0",
    "description": "File Upload API Server",
    "main": "server.js",
    "scripts": {
        "start": "node server.js"
    },
    "dependencies": {
        "cors": "^2.8.5",
        "express": "^4.18.2",
        "morgan": "^1.10.0",
        "multer": "^1.4.5-lts.1",
        "uuid": "^9.0.0"
    }
}
EOL
    # 安装依赖
    echo -e "${YELLOW}安装依赖...${NC}"
    npm install
    # 强制安装 file-type@16 兼容 Node.js 12
    npm install file-type@16
else
    echo -e "${GREEN}package.json已存在且内容一致，跳过安装依赖${NC}"
fi

# 检查server.js是否存在并比较内容
if [ ! -f server.js ]; then
    echo -e "${YELLOW}创建server.js...${NC}"
    cat > server.js << 'EOL'
const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const morgan = require('morgan');
const FileType = require('file-type');

const app = express();
const port = 3000;
const uploadDir = '/opt/uploads';

if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

app.use(morgan('combined'));

app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
    maxAge: 86400
}));

app.options('*', cors());

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        console.log('保存文件到目录:', uploadDir);
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        console.log('原始文件名:', file.originalname);
        const filename = file.originalname || (uuidv4() + path.extname(file.originalname));
        console.log('生成的文件名:', filename);
        cb(null, filename);
    }
});

const upload = multer({
    storage: storage,
    limits: {
        fileSize: 10 * 1024 * 1024 // 10MB
    }
}).single('file');

app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.post('/upload', async (req, res) => {
    console.log('收到上传请求');
    console.log('请求头:', req.headers);
    try {
        await new Promise((resolve, reject) => {
            upload(req, res, function(err) {
                if (err) {
                    console.error('Multer错误:', err);
                    reject(err);
                } else {
                    resolve();
                }
            });
        });
        if (!req.file) {
            console.log('没有文件被上传');
            return res.status(400).json({
                code: 400,
                message: '没有文件被上传'
            });
        }
        console.log('文件已保存到磁盘:', req.file.path);
        console.log('文件信息:', {
            originalname: req.file.originalname,
            mimetype: req.file.mimetype,
            size: req.file.size
        });
        try {
            const buffer = await fs.promises.readFile(req.file.path);
            const type = await FileType.fromBuffer(buffer);
            const allowedTypes = [
                'image/jpeg', 'image/png', 'image/gif', 'image/bmp',
                'image/webp', 'image/svg+xml', 'image/tiff', 'image/x-icon'
            ];
            if (!type || !allowedTypes.includes(type.mime)) {
                await fs.promises.unlink(req.file.path);
                return res.status(400).json({
                    code: 400,
                    message: '只允许上传图片文件(jpg, jpeg, png, gif, bmp, webp, svg, tiff, ico)'
                });
            }
            const protocol = req.headers['x-forwarded-proto'] || req.protocol;
            const host = req.headers['x-forwarded-host'] || req.get('host');
            const fileUrl = `${protocol}://${host}/files/${req.file.filename}`;
            res.json({
                code: 200,
                message: "上传成功",
                data: {
                    file_url: fileUrl,
                    file_name: req.file.filename
                }
            });
        } catch (error) {
            console.error('文件处理错误:', error);
            if (req.file && req.file.path) {
                try {
                    await fs.promises.unlink(req.file.path);
                } catch (unlinkError) {
                    console.error('清理临时文件失败:', unlinkError);
                }
            }
            res.status(400).json({
                code: 400,
                message: '文件处理失败: ' + error.message
            });
        }
    } catch (error) {
        console.error('上传处理错误:', error);
        if (error instanceof multer.MulterError) {
            if (error.code === 'LIMIT_FILE_SIZE') {
                return res.status(400).json({
                    code: 400,
                    message: '文件大小不能超过10MB'
                });
            }
            return res.status(400).json({
                code: 400,
                message: `上传错误: ${error.message}`
            });
        }
        res.status(400).json({
            code: 400,
            message: error.message
        });
    }
});

app.get('/files/:filename', (req, res) => {
    const filename = req.params.filename;
    const filepath = path.join(uploadDir, filename);
    if (!fs.existsSync(filepath)) {
        return res.status(404).json({
            code: 404,
            message: '文件不存在'
        });
    }
    res.sendFile(filepath);
});

app.use((err, req, res, next) => {
    console.error('全局错误处理:', err);
    res.status(400).json({
        code: 400,
        message: err.message
    });
});

app.listen(port, '0.0.0.0', () => {
    console.log(`文件API服务器运行在 http://0.0.0.0:${port}`);
    console.log('上传目录:', uploadDir);
    console.log('支持的接口:');
    console.log('- GET  /health - 健康检查');
    console.log('- POST /upload - 文件上传');
    console.log('- GET  /files/:filename - 文件访问');
});
EOL
else
    echo -e "${GREEN}server.js已存在，跳过创建${NC}"
fi

# 检查systemd服务文件是否存在
if [ ! -f /etc/systemd/system/fileapi.service ]; then
    echo -e "${YELLOW}创建systemd服务文件...${NC}"
    cat > /etc/systemd/system/fileapi.service << EOL
[Unit]
Description=File Upload API Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/FileAPI
ExecStart=${NODE_PATH} /opt/FileAPI/server.js
Restart=always
Environment=NODE_ENV=production
Environment=PATH=/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
StandardOutput=file:/var/log/fileapi.log
StandardError=file:/var/log/fileapi.error.log

[Install]
WantedBy=multi-user.target
EOL
    # 重新加载systemd配置
    echo -e "${YELLOW}重新加载systemd配置...${NC}"
    systemctl daemon-reload
else
    echo -e "${GREEN}systemd服务文件已存在，跳过创建${NC}"
fi

# 确保日志文件存在
touch /var/log/fileapi.log
touch /var/log/fileapi.error.log
chmod 644 /var/log/fileapi.log
chmod 644 /var/log/fileapi.error.log

# 设置文件权限
echo -e "${YELLOW}设置文件权限...${NC}"
chmod 755 /opt/FileAPI
chmod 644 /opt/FileAPI/package.json
chmod 644 /opt/FileAPI/server.js
chmod 644 /etc/systemd/system/fileapi.service
chmod 755 /opt/uploads

# 重启服务
echo -e "${YELLOW}重启服务...${NC}"
systemctl restart fileapi
systemctl enable fileapi

# 检查服务状态
echo -e "${YELLOW}检查服务状态...${NC}"
systemctl status fileapi

echo -e "${GREEN}部署完成！${NC}"
echo -e "文件API服务器已启动，访问地址: http://localhost:3000"
echo -e "文件存储位置: ${GREEN}/opt/uploads${NC}"
echo -e "日志文件位置："
echo -e "  - 标准输出：${GREEN}/var/log/fileapi.log${NC}"
echo -e "  - 错误日志：${GREEN}/var/log/fileapi.error.log${NC}"
echo -e "可以使用以下命令管理服务："
echo -e "  启动服务：${GREEN}systemctl start fileapi${NC}"
echo -e "  停止服务：${GREEN}systemctl stop fileapi${NC}"
echo -e "  重启服务：${GREEN}systemctl restart fileapi${NC}"
echo -e "  查看状态：${GREEN}systemctl status fileapi${NC}"
echo -e "  查看日志：${GREEN}journalctl -u fileapi${NC}"

# 添加命令行参数处理
case "$1" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        status_service
        ;;
    logs)
        check_logs
        ;;
    *)
        echo -e "使用方法: $0 {start|stop|restart|status|logs}"
        echo -e "  start   - 启动服务"
        echo -e "  stop    - 停止服务"
        echo -e "  restart - 重启服务"
        echo -e "  status  - 查看状态"
        echo -e "  logs    - 查看日志"
        ;;
esac 
