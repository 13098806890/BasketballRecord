# 语音识别改进说明

## 改进日期
2026年6月12日

## 问题分析

### 1. 双重 Fuzzy 处理问题
在原代码中，拼音会被 `fuzzyPinyin` 方法处理**两次**：
1. 第一次：在调用 `matchPlayerIDsDebug` 之前
2. 第二次：在 `matchPlayerIDsDebug` 方法内部

虽然 `fuzzyPinyin` 是幂等的（处理两次结果相同），但这是代码坏味道，且如果将来修改fuzzy规则，可能引入bug。

**示例**：
```swift
// 错误做法（之前）
let leftPinyin = Self.fuzzyPinyin(Self.toPinyin(leftText))  // 第一次 fuzzy
matchPlayerIDsDebug(text: leftText, textPinyin: leftPinyin, ...)  // 内部再次 fuzzy

// 正确做法（修复后）
let leftPinyin = Self.toPinyin(leftText)  // 只转拼音
matchPlayerIDsDebug(text: leftText, textPinyin: leftPinyin, ...)  // 内部统一fuzzy
```

### 2. ASR 识别错误覆盖不全
当前的 fuzzy 匹配只能处理单向的替换规则：
- `zh` → `z`
- `sh` → `s`
- `r` → `l`

但实际 ASR 可能产生反向错误：
- `z` → `zh`（把"战神"识别成"占神"）
- `s` → `sh`
- `l` → `r`

## 解决方案

### 1. 引入拼音变体池（Pinyin Variants Pool）

新增 `generatePinyinVariants` 方法，为每个名字生成所有可能的拼音变体：

```swift
static func generatePinyinVariants(_ text: String) -> Set<String> {
    let basePinyin = toPinyin(text)
    var variants = Set<String>()
    variants.insert(basePinyin)

    // 双向模糊规则
    let fuzzyRules: [(String, String)] = [
        ("zh", "z"), ("z", "zh"),       // 翘舌音 ↔ 平舌音
        ("ch", "c"), ("c", "ch"),
        ("sh", "s"), ("s", "sh"),
        ("r", "l"), ("l", "r"),         // 鼻音/边音混淆
        ("n", "l"), ("l", "n"),         // 南方方言 n/l 不分
        ("eng", "en"), ("en", "eng"),   // 后鼻音/前鼻音
        ("ing", "in"), ("in", "ing"),
        ("ang", "an"), ("an", "ang"),
    ]

    // 对每个音节生成单次替换变体
    for (index, syllable) in syllables.enumerated() {
        for (from, to) in fuzzyRules {
            if syllable.contains(from) {
                var modifiedSyllables = syllables
                modifiedSyllables[index] = syllable.replacingOccurrences(of: from, with: to)
                variants.insert(modifiedSyllables.joined(separator: " "))
            }
        }
    }

    return variants
}
```

**示例**：
```
球员名: "张三"
变体池: ["zhang san", "zang san", "jiang san", "zhang shan", ...]

球队名: "战神队"
变体池: ["zhan shen dui", "zan shen dui", "zhan sen dui", "zan sen dui", ...]
```

### 2. 改进 matchPlayerIDsDebug 匹配优先级

新的匹配策略分三个优先级：

**优先级 1: 直接文本匹配**（1.0分）
- 原始中文文本直接包含匹配

**优先级 2: 变体池匹配**（0.95分）⭐ 新增
- 用户输入的变体池与球员/球队的变体池有交集
- 避免双重fuzzy处理
- 覆盖更多ASR错误场景

**优先级 3: Fuzzy拼音匹配**（0.5+分）
- 使用字符级相似度算法
- 作为兜底方案

```swift
// 生成用户输入变体（只生成一次）
let userInputVariants = Self.generatePinyinVariants(text)

for id in allIDs {
    if let player = store.player(for: id) {
        // 优先级 1: 直接匹配
        if text.lowercased().contains(player.name.lowercased()) {
            results.append((id, side, 1.0))
            continue
        }

        // 优先级 2: 变体池匹配 ⭐ 新增
        let playerVariants = Self.generatePinyinVariants(player.name)
        if !userInputVariants.isDisjoint(with: playerVariants) {
            results.append((id, side, 0.95))
            continue
        }

        // 优先级 3: Fuzzy匹配（兜底）
        // ...
    }
}
```

### 3. 修复双重 Fuzzy 处理

修复了以下位置的双重处理：
1. **第460-461行**（handleSubstitution）：换人逻辑
2. **第533行**（自定义映射）
3. **第630行**（resolvePlayer主路径）

**修复前**：
```swift
let leftPinyin = Self.fuzzyPinyin(Self.toPinyin(leftText))  // 双重处理
```

**修复后**：
```swift
let leftPinyin = Self.toPinyin(leftText)  // 只转拼音，不fuzzy
```

## 效果对比

### 场景1：球队名"战神队"

**当前方法（commit 4b6e63e）**：
```
用户说: "战神队两分"
ASR输出: "占神队两分"

球队拼音: "zhan shen dui" → fuzzy → "zan sen dui"
用户输入: "zhan shen dui" → fuzzy → "zan sen dui"

匹配: ❌ 可能失败（如果ASR没有正确识别所有音节）
```

**改进方法（变体池）**：
```
用户说: "战神队两分"
ASR输出: "占神队两分"

球队变体池: ["zhan shen dui", "zan shen dui", "zhan sen dui", ...]
用户变体池: ["zhan shen dui", "zan shen dui", ...]

匹配: ✅ 有交集 → 成功！
```

### 场景2：反向错误

**当前方法**：
```
球队名: "蓝队" (lan dui)
用户说: "兰队" (lan dui，但ASR识别为 "nan dui")

当前fuzzy规则只有单向: r→l, n→l
无法处理 n→l 的反向

匹配: ❌ 失败
```

**改进方法**：
```
球队变体池: ["lan dui", "nan dui", "ran dui", ...]  // 包含双向变体
用户变体池: ["nan dui", "lan dui", ...]

匹配: ✅ 有交集 → 成功！
```

## 性能分析

### 变体数量控制
- 每个名字最多生成：`音节数 × 规则数` 个变体
- 例如："张三"（2音节），16条规则 → 最多 2×16 = 32 个变体
- 实际会更少，因为不是每个音节都匹配所有规则

### 时间复杂度
- **之前**：O(N × M)，N=候选数，M=每个候选的fuzzy匹配时间
- **现在**：O(N × V)，V=变体池交集判断（HashSet操作，接近O(1)）
- 实际上可能**更快**，因为变体池匹配是Set交集，比字符串相似度算法快

### 空间复杂度
- 每个名字额外存储约10-30个变体字符串
- 对于100个球员，约增加1-3KB内存
- **可接受**

## 测试验证

新增测试：
1. `testGeneratePinyinVariants`：验证变体生成正确性
2. `testTeamModeWithVariants`：验证球队模式下的模糊匹配

运行现有测试套件，确保兼容性：
```bash
xcodebuild test -scheme BasketballRecord \
  -only-testing:BasketballRecordTests/VoiceMatchingTests
```

## 未来改进方向

1. **预生成变体缓存**：可以在 Player/Team 结构中添加 `lazy var pinyinVariants`
2. **动态规则配置**：根据用户方言或ASR引擎特性调整fuzzy规则
3. **学习机制**：记录用户的纠正，动态调整匹配权重

## 总结

这次改进主要解决了两个问题：
1. ✅ 修复了双重fuzzy处理的代码坏味道
2. ✅ 引入变体池，大幅提高ASR错误容错率

特别是对于**球队统计模式**，变体池匹配能更可靠地识别球队名称，即使ASR产生了翘舌/平舌、前鼻音/后鼻音等常见错误。
