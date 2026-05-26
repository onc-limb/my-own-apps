# Phase 4 / 07 — Real-world Validation

## Goal
自分の実プロジェクトに対して Ariadne を走らせ、結果を**そのまま信用してリファクタ判断ができるか**を検証する。実用性の最終確認。

## Prerequisites
- [05 Error Handling](05-error-handling.md) 完了（[06 Performance] は任意）

## Steps

### 1. 対象プロジェクトを選ぶ

- 自分が書いた TypeScript プロジェクト（規模感: ファイル 50 以上が望ましい）
- `node_modules` が入っている実環境

### 2. 一度走らせて生の結果を見る

```bash
ariadne ~/work/some-project --format=text > scan.txt
ariadne ~/work/some-project --format=json > scan.json
```

何件の違反が出るかを確認。経験則:
- 健全な小規模 TS: 違反 0-3 件
- 普通の中規模: 数件〜十数件
- レガシー混じり: 数十件以上

### 3. 違反トップ 5 を手で検証

最も CC が高い関数 5 つを実コードで眺める。次を自問する。

- 「本当に複雑か？」 → 自分の直感と Ariadne の数値が一致しているか
- 一致しない場合「なぜズレるか」を言語化する
  - 構文上は分岐が多いが、実は意味的に単純
  - 大きな switch dispatcher で、各 case が短い場合など
  - その場合は **Cog の方が直感に近いはず** — そうなっているか確認
- 「リファクタ余地はあるか？」 → 「ある」と判断できるなら、ツールは実用できている

### 4. 偽陽性／偽陰性の記録

`docs/findings.md` に書く:
```
## False positives (ツールが warning するが、改修不要と判断したもの)
- `src/router.ts` `dispatch` — switch 25 ケース。意図的な dispatcher

## False negatives (ツールが見逃したが、人間が見ると複雑なもの)
- `src/utils/parse.ts` `tokenize` — CC 9 / Cog 7 だが、文字列処理の暗黙状態が複雑
```

これがツール改善の次のチケットになる。

### 5. しきい値の調整

実プロジェクトで違反が 100 件を超えるようなら、**しきい値を下げるべきではない**（最初は緩く始めて、改善とともに下げる）。

逆に違反が 0 件になるしきい値はゲートとして意味がない。最初の `ariadne.yaml` は次のような戦略にする。

```yaml
thresholds:
  cyclomatic: 20   # 既存違反 = 数件くらいに収まる値
  cognitive: 25
  lines: 100
```

数ヶ月運用してから 15 / 20 / 80 に下げる。

### 6. レポートを誰かに見せる

- 自分以外の人（同僚 / 友人 / ChatGPT でも可）に出力を見せ、読めるかを確認
- 用語（cc / cog）が伝わるかチェック
- 伝わらないなら表ヘッダや README で補強

### 7. 実用上の問題リスト

実プロジェクトで気づいた問題点を全部書き出す。次のフェーズや改修のチケットにする。

例:
- `__tests__` の関数を除外したい
- 引数 1 つの簡潔なアロー関数を「関数」として数えるか判断したい
- 行範囲が空行で過大評価される

`ASSUMPTIONS.md` または `docs/known-issues.md` に集約。

## Verification

- [ ] 自分の実プロジェクトでクラッシュなく完走する
- [ ] トップ 5 違反が自分の直感と概ね一致する
- [ ] 偽陽性 / 偽陰性が文書化されている
- [ ] 「このツールを案件で使い続けるか」に Yes と答えられる

## Pitfalls / Tips
- 「100% 正しい」を求めない — 静的解析はサンプリングであって正解の生成器ではない
- 「ツールが指摘した = リファクタ必要」ではない — 人間の判断を補助するもの
- 違反ゼロを目指して数値を下げ続けると逆効果。設計の指針としてのバランスを意識する

## Outputs
- 自分の実コードへの実行レポート
- `docs/findings.md` の偽陽性/陰性記録
- 改善 TODO リスト
- Phase 4 完了の納得感

## Next
- Phase 4 完了。roadmap の Completion Criteria を確認
- [Phase 5 / 01 CI Integration](../phase5/01-ci-integration.md)
