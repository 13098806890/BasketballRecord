# 数据分享服务（Cloud Share Service）

## 架构

```
App ── PUT /v2/upload ──→ SCF ──→ COS（数据直存）
App ←── 201 { uuid }  ←── SCF

App ── POST /v2/download { uuid } ──→ SCF ──→ COS（读取数据）
App ←── 200 原数据 ←── SCF
```

- COS 私有桶，密钥只存在 SCF 环境变量，App 不持有密钥
- UUID 作为资源标识
- 数据经过 SCF 中转写入 COS，无需额外 SDK

## 部署

### 1. 创建函数

腾讯云控制台 → 云函数 SCF → 函数服务 → 新建

| 配置项 | 值 |
|-------|-----|
| 函数名称 | `BasketballShareService` |
| 运行环境 | Python 3.6 |
| 函数类型 | Web 函数 |
| 创建方式 | 模板 → Flask |

### 2. 复制代码

将 `app.py` 的全部内容粘贴到代码编辑器，保存并部署。

### 3. 环境变量

函数配置 → 编辑 → 环境变量 → 添加：

| 变量名 | 值 |
|-------|-----|
| `COS_BUCKET` | 存储桶名称（如 `basketball-record-share-125xxxxxxx`） |
| `COS_REGION` | 地域（如 `ap-shanghai`） |
| `COS_SECRET_ID` | 腾讯云 API 密钥 SecretId |
| `COS_SECRET_KEY` | 腾讯云 API 密钥 SecretKey |

> 密钥仅存在 SCF 环境变量中，不会泄漏到 App 端。

### 4. 测试

```bash
# 健康检查
curl https://<你的访问路径>/health

# 上传数据
curl -X PUT -H "Content-Type: application/octet-stream" \
  -d '{"hello":"world"}' \
  https://<你的访问路径>/v2/upload

# 下载数据
curl -X POST -H "Content-Type: application/json" \
  -d '{"uuid":"xxx-xxx-xxx"}' \
  https://<你的访问路径>/v2/download

# 检查是否存在
curl https://<你的访问路径>/v2/check/xxx-xxx-xxx
```

## API

### `PUT /v2/upload`

请求体为原始二进制数据。

```json
// Response 201
{ "uuid": "a1b2c3d4-..." }
```

### `POST /v2/download`

```json
// Request
{ "uuid": "a1b2c3d4-..." }

// Response 200
原始二进制数据

// Response 404
{ "error": "not found" }
```

### `GET /v2/check/<uuid>`

```json
// Response 200
{ "exists": true }
```

### `GET /health`

```json
{ "status": "ok" }
```

## 本地开发

```bash
# 启动本地服务
COS_BUCKET=xxx COS_SECRET_ID=xxx COS_SECRET_KEY=xxx python3 app.py

# 测试
curl http://localhost:9000/health
```
