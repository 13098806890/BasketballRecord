# 将 Markdown 发布为 App Store 可用页面

App Store Connect 的 `Privacy Policy URL`、`Support URL` 要求是可公开访问的 `HTTPS` 网页地址。  
仓库内 `Markdown` 文件本身不是最终 URL，需要先发布。

## 推荐方案：GitHub Pages

## 1. 启用 Pages

1. 进入仓库 `Settings` → `Pages`
2. `Source` 选择主分支（或 docs 分支）
3. 保存后等待生成站点地址

## 2. 准备页面

将以下文件发布到网站：

- `docs/appstore/privacy-policy.md`
- `docs/appstore/support.md`
- `docs/appstore/terms-of-use.md`（可选）

## 3. 填写 App Store Connect

- `Privacy Policy URL`：填写隐私政策页面地址
- `Support URL`：填写支持页面地址
- `Marketing URL`（可选）：可填项目主页或说明页

## 4. 发布前检查清单

- [ ] 所有 `TODO` 已替换（邮箱、日期、域名）
- [ ] 页面可在未登录状态下访问
- [ ] 页面使用 HTTPS
- [ ] 页面内容与应用当前行为一致（权限、数据处理方式）

