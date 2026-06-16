# 数据分享功能计划

## 架构（方案 B：预签名 URL）

```
App → SCF（生成预签名 URL）→ 返回上传/下载链接 → App 直连 COS 传文件
```

- COS 私有桶，密钥只存在 SCF，App 不存密钥
- UUID 作为资源标识，URL 仅临时凭证

## Todo

### Phase 1：SCF 云函数

- [ ] 腾讯云 SCF 创建 Web 函数（Python 3.9），名称 `BasketballSigner`
- [ ] 填入 COS SecretId / SecretKey / Bucket / Region
- [ ] 实现三个接口：`upload`、`download`、`check`
- [ ] 部署并测试（获取签名 URL → curl 验证上传下载）

### Phase 2：Swift 数据导出格式

- [ ] Game / Team 序列化为 JSON 压缩编码（`.brd` 格式）
- [ ] 导出时生成 UUID，调 SCF 拿上传签名，上传文件

### Phase 3：Swift 数据导入

- [ ] 用户输入 UUID 或粘贴分享链接 → 解析 UUID
- [ ] 调 SCF 拿下载签名 → HTTP GET 下载 → 解压导入

### Phase 4：分享 UI

- [ ] 导出分享按钮（游戏详情 / 球队详情）
- [ ] 导入分享入口（UUID 输入框）
- [ ] 进度反馈、错误处理
