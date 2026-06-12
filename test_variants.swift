#!/usr/bin/env swift

// 简单测试脚本：验证拼音变体生成逻辑

import Foundation

func toPinyin(_ s: String) -> String {
    let mutable = NSMutableString(string: s) as CFMutableString
    CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
    CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
    return (mutable as String).lowercased().trimmingCharacters(in: .whitespaces)
}

func generatePinyinVariants(_ text: String) -> Set<String> {
    let basePinyin = toPinyin(text)
    var variants = Set<String>()
    variants.insert(basePinyin)

    let syllables = basePinyin.split(separator: " ").map(String.init)
    guard !syllables.isEmpty else { return variants }

    let fuzzyRules: [(String, String)] = [
        ("zh", "z"), ("z", "zh"),
        ("ch", "c"), ("c", "ch"),
        ("sh", "s"), ("s", "sh"),
        ("r", "l"), ("l", "r"),
        ("n", "l"), ("l", "n"),
        ("eng", "en"), ("en", "eng"),
        ("ing", "in"), ("in", "ing"),
        ("ang", "an"), ("an", "ang"),
    ]

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

// 测试用例
print("测试1: 张三")
let variants1 = generatePinyinVariants("张三")
print("  原始拼音: \(toPinyin("张三"))")
print("  变体数量: \(variants1.count)")
print("  变体列表: \(variants1.sorted())")
print()

print("测试2: 战神队")
let variants2 = generatePinyinVariants("战神队")
print("  原始拼音: \(toPinyin("战神队"))")
print("  变体数量: \(variants2.count)")
print("  变体列表: \(variants2.sorted())")
print()

print("测试3: 英格兰")
let variants3 = generatePinyinVariants("英格兰")
print("  原始拼音: \(toPinyin("英格兰"))")
print("  变体数量: \(variants3.count)")
print("  包含 'yin ge lan': \(variants3.contains("yin ge lan"))")
print("  包含 'ying ge lan': \(variants3.contains("ying ge lan"))")
print()

print("测试4: 红队")
let variants4 = generatePinyinVariants("红队")
print("  原始拼音: \(toPinyin("红队"))")
print("  变体数量: \(variants4.count)")
print("  变体列表: \(variants4.sorted())")
print()

// 测试匹配
print("测试5: 模拟匹配场景")
let team1Variants = generatePinyinVariants("战神队")
let user1Variants = generatePinyinVariants("占神队")  // ASR 可能的误识别
let hasMatch1 = !team1Variants.isDisjoint(with: user1Variants)
print("  球队名: 战神队, ASR输出: 占神队")
print("  匹配结果: \(hasMatch1 ? "✅ 成功" : "❌ 失败")")
if hasMatch1 {
    let intersection = team1Variants.intersection(user1Variants)
    print("  匹配的变体: \(intersection)")
}
