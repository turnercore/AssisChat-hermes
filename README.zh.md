# AssisChat Hermes

[English](./README.md)

AssisChat Hermes 是一个面向 iOS/iPadOS 的 SwiftUI 聊天客户端分支，重点支持 Hermes、OpenAI 兼容接口和 Anthropic 兼容接口，并默认采用更严格的隐私设置。

特性:

- [x] iOS/iPadOS 原生 SwiftUI 聊天客户端
- [x] Hermes API Server 配置、健康检查、能力发现、模型、会话和 Runs 仪表盘
- [x] OpenAI 兼容与 Anthropic 兼容聊天适配器
- [x] Provider 密钥存储在 Keychain，并支持从旧设置一次性迁移
- [x] 现代默认主题与 Hermes Nous 主题
- [x] StoreKit、CloudKit 同步、推送通知权限和键盘发布入口已移除或禁用

## 构建

- 使用 Xcode 打开 `AssisChat.xcodeproj`。
- `AssisChat` target 使用 `com.turnercore.AssisChatHermes` 命名空间。
- App Group 使用 `group.com.turnercore.AssisChatHermes`。
- Keychain access group 使用 `BWDKW435B4.com.turnercore.AssisChatHermes.shared`。
- macOS 不属于此分支的目标平台。

## 鸣谢

本分支基于 MIT 许可的 AssisChat 项目。

- [GPT3 Tokenizer](https://github.com/aespinilla/GPT3-Tokenizer)
- [LDSwiftEventSource](https://github.com/launchdarkly/swift-eventsource)
- [Splash](https://github.com/JohnSundell/Splash)
- [swift-markdown-ui](https://github.com/gonzalezreal/MarkdownUI)
- [SwiftSoup](https://github.com/scinfu/SwiftSoup)

## 开源协议

MIT
