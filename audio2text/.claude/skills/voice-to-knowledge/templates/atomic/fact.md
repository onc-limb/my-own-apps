---
template: atomic-fact
applies_to_type: fact
saved_to: facts/
---

# Atomic Template: Fact

「再利用可能な事実・知識」を1単位で記録する。技術知識、業務上の事実、業界情報など、後で参照する可能性のある **客観的情報**。

## 抽出基準

- 自分の意見ではなく、**事実として共有された情報**
- 仕様、API の挙動、規則、数値、歴史的経緯など
- 個人的な感想・評価は insight 側に

## 出力フォーマット

```markdown
---
type: fact
title: <事実を表す簡潔な文（"JWT は signature 部分を Base64URL で エンコードする" のように）>
created_at: <ISO8601 datetime>
recorded_at: <YYYY-MM-DD>
source: sources/<category>/<source-file>.md
domain: <例: tech/security, business/compliance, industry/finance>
confidence: high | medium | low      # 情報の確度
informant: <情報源となった話者 or unknown>
people:
  - <名前>
project: <プロジェクト名>
tags:
  - <キーワード>
---

# <Title>

## 内容

<事実を明確かつ簡潔に。複雑なら箇条書き>

## 文脈

<どういう状況で出てきた話か。前提条件、適用範囲>

## 検証状況

<事実の確からしさ、裏取りした場合の参照>

- Verified by: <ドキュメント / URL / 別の情報源>
- Confidence note: <なぜ high/medium/low なのか一行>

## 例 / 反例

<理解を助ける具体例があれば>

## 関連

- Source: [[<source-link>]]
- Related concepts: [[<concept-link>]]
- Related facts: [[<related-fact>]]
- Contradicts: [[<conflicting-fact>]]   # 矛盾する事実があれば
```

## confidence の目安

- `high`: 公式ドキュメント・複数ソースで裏取り済み
- `medium`: 信頼できる人物の発言だが裏取り未済
- `low`: 不確かな伝聞・記憶違いの可能性あり
