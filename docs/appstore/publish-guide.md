# 将 Markdown 发布为 App Store 可用页面

App Store Connect 的 `Privacy Policy URL`、`Support URL` 要求是可公开访问的 `HTTPS` 网页地址。  
仓库内 `Markdown` 文件本身不是最终 URL，需要先发布。

## 推荐方案：GitHub Pages（App-Store-pages 仓库）

本站点已迁移至统一仓库 [App-Store-pages](https://github.com/13098806890/App-Store-pages)，
使用 **GitHub Pages** 发布，地址为：

- 宣传页：https://13098806890.github.io/App-Store-pages/BasketballRecord/
- 隐私政策：https://13098806890.github.io/App-Store-pages/BasketballRecord/privacy-policy.html
- 使用条款：https://13098806890.github.io/App-Store-pages/BasketballRecord/terms-of-use.html
- 支持页面：https://13098806890.github.io/App-Store-pages/BasketballRecord/support.html

## 填写 App Store Connect

- `Privacy Policy URL`：填写隐私政策页面地址
- `Support URL`：填写支持页面地址
- `Marketing URL`（可选）：可填宣传页地址

## 发布前检查清单

- [ ] 所有 `TODO` 已替换（邮箱、日期、域名）
- [ ] 页面可在未登录状态下访问
- [ ] 页面使用 HTTPS
- [ ] 页面内容与应用当前行为一致（权限、数据处理方式）

