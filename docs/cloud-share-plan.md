# 项目计划

## Phase 0：DeepSeek Key 安全分发（进行中）

```
App 调 AI 前 → 检查 Keychain 有无 key
   → 无：读取 App Store receipt（base64）
       → POST SCF { receipt, action: "getDeepSeekKey" }
       → SCF 转发 receipt 到 Apple verifyReceipt
       → 验证通过 → 返回 DeepSeek Key
       → App 存入 Keychain
   → 有：直接用 Keychain 里的 key
```

- [x] SCF Web 函数基础代码（`docs/scf_get_key.py`）
- [ ] 部署 SCF 到腾讯云
- [ ] SCF 添加 Apple Receipt 验证
- [ ] Swift 端读取 receipt + 调 SCF
- [ ] Swift 端缓存 key 到 Keychain

---

## Phase 1：数据分享（预签名 URL）

### 架构

```
App → SCF（生成预签名 URL）→ 返回上传/下载链接 → App 直连 COS 传文件
```

- COS 私有桶，密钥只存在 SCF，App 不存密钥
- UUID 作为资源标识，URL 仅临时凭证

### Todo

- [ ] SCF 添加 upload、download、check 接口
- [ ] Game / Team 序列化为 .brd 格式
- [ ] 分享 UI（导出 / 导入 / UUID 输入）
- [ ] 进度反馈、错误处理
