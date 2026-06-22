# 腾讯云 AI 代理服务

## 架构

```
App ── transactionId + messages ──→ SCF ──→ Apple 验证订阅
                                         ──→ DeepSeek API（SCF 持有 Key）
App ←──────── AI 结果 ←──────────── SCF
```

DeepSeek API Key 仅在 SCF 环境变量中，App 拿不到，防止滥用。

## 部署

### 1. 创建函数

腾讯云控制台 → 云函数 SCF → 函数服务 → 新建

| 配置项 | 值 |
|-------|-----|
| 函数名称 | `BasketballAIService` |
| 运行环境 | Python 3.6 |
| 函数类型 | Web 函数 |
| 创建方式 | 模板 → Flask |

### 2. 替换代码

创建后，把 `ai-service/app.py` 的内容粘贴到代码编辑器，覆盖 `app.py`。

`bootstrap` 文件保持模板生成的不动。

### 3. 环境变量

函数配置 → 编辑 → 环境变量 → 添加：

| 变量名 | 值 |
|-------|-----|
| `APPSTORE_SERVER_P8` | App Store Server API 的 `.p8` 文件全部内容 |
| `BASKETBALL_DEEPSEEK_API_KEY` | DeepSeek API Key |

### 4. 测试

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"action":"chat","transactionId":"你的交易ID","messages":[{"role":"user","content":"Say hello"}]}' \
  你的访问路径
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `app.py` | Flask 主程序：验证订阅 + 代理 AI 请求 |
| `bootstrap` | SCF 启动脚本（参考） |

## API 接口

### `POST /`

#### 请求体

```json
{
  "action": "chat",
  "transactionId": "2000001182074853",
  "messages": [{"role": "user", "content": "你好"}],
  "systemPrompt": "你是篮球教练",
  "temperature": 0.6,
  "maxTokens": 2500
}
```

#### 成功响应

```json
{
  "choices": [{"message": {"content": "..."}}]
}
```

#### 失败响应

```json
{"error": "subscription not active"}
```
