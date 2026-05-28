---
date: 2026-05-26
phase: phase0
category: hint
tags: [ocaml, exercises, adt, pattern-match, option, result]
---

# Phase0 練習問題（Verification 自己確認用）

## コンテキスト
[02-language-fundamentals.md](../../procedure/phase0/02-language-fundamentals.md) の
Verification 4 項目を自分の手で確認するための問題集。
解答は書かず、学習者が書いたコードを Claude がレビューする運用。

---

## 1. ADT と eval（Verification 1）

### 1-A: 算術演算の拡張
`expr` に `Sub`（引き算）と `Div`（割り算）を追加し、`eval` を更新せよ。

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Mul of expr * expr
  (* ↓ ここに追加 *)
```

**設計ポイント:** `Div` の 0 除算をどう扱うか？
- (a) 例外を投げる
- (b) `eval` の戻り値を `int option` にする
- (c) `eval` の戻り値を `(int, string) result` にする

(a)(b)(c) のうち、自分なら **どれを選ぶか・なぜか** を一行で答える。
（ヒント: phase0/02 の「例外と Result の使い分け方針」を思い出す）

### 1-B: 型と分岐の拡張（挑戦）
`expr` を拡張して **真偽値と条件分岐** を表現できるようにせよ。

```ocaml
| Bool of bool
| If of expr * expr * expr   (* if cond then a else b *)
| Eq of expr * expr          (* a = b *)
```

**設計ポイント:** これで困ることが出てくる。
- `Add (Int 1, Bool true)` のような **型的におかしい式** を作れてしまう
- これを **型レベルで防ぐ** にはどうしたらいい？（GADT という機能があるが、phase0 では「問題があることだけ気付ければ OK」）

---

## 2. 網羅性警告（Verification 2）

### 2-A: 警告を起こす
1-A で `Sub` / `Div` を追加した後、**`eval` の更新を忘れて** コンパイルするとどんな警告が出る？
dune または utop で実際に試して、警告メッセージを書き写す。

### 2-B: ワイルドカードの罠
次のコードはコンパイル警告が出ない。**なぜ危険か** を説明せよ。

```ocaml
let rec eval = function
  | Int n -> n
  | Add (a, b) -> eval a + eval b
  | _ -> failwith "not supported"   (* ← これが問題 *)
```

**ヒント:** 後で `Mul` 用の処理を書き忘れたら、コンパイラはそれを教えてくれる？

### 2-C: 正しく警告を活かす書き方
「全ケースを明示的に書く」 vs 「ワイルドカード `_` で省略する」を **使い分ける指針** を一行で書け。

---

## 3. Option / Result を型から読む（Verification 3）

### 3-A: `Option.value` の使い方を型から推測
utop で次を入力し、型を見るだけで「何をする関数か」を **自分の言葉で説明** せよ。
コードでの使用例も書き、utop で実行して予想と合うか確認する。

```ocaml
Option.value;;
(* val Option.value : 'a option -> default:'a -> 'a *)
```

**ヒント:** `default:` という名前付き引数が付いている理由は何だろう？

### 3-B: `Result.map` をカリー化視点で読む
次の型を、「`->` 右結合」を意識して **3 段階の読み下し** で説明せよ。

```ocaml
val Result.map : ('a -> 'b) -> ('a, 'e) result -> ('b, 'e) result
```

**ヒント:**
1. 何を受け取って、何を返す関数？
2. 部分適用 `Result.map (fun n -> n * 2)` の型は？
3. エラー側 `'e` には何が起こる？（変換される？されない？）

### 3-C: `List.find_opt` で使ってみる
`[1; 2; 3; 4]` から「最初の偶数」を取り出し、見つからなければ `0` を返す式を書け。
- (i) `match` で書くバージョン
- (ii) `Option.value` を使うバージョン

両方書き比べて、**どちらが読みやすいか** 自分の感覚を一行メモする。

---

## 4. 不正な状態を表現不能にする（Verification 4）

### 4-A: ユーザーのメール認証状態
次の設計は **不正な状態を作れてしまう**。

```ocaml
type user = {
  name: string;
  email: string;
  email_verified: bool;
  verification_token: string option;
}
```

**起こりうる不正な状態を 2 つ挙げよ。** 例:
- `email_verified = true` なのに `verification_token = Some "..."` がある
- ...

そして、これを **型レベルで防げる設計** に書き直せ。
**ヒント:** ADT を使う。「未認証ユーザー」と「認証済ユーザー」を別の variant にする。

### 4-B: ログイン状態
次の設計の問題点を指摘し、改善せよ。

```ocaml
type session = {
  is_logged_in: bool;
  user_id: int option;
  login_time: float option;
}
```

**ヒント:** `is_logged_in = true` のときだけ `user_id` と `login_time` が
意味を持つはず。`bool` と `option` を組み合わせるとどうしても矛盾が作れる。

### 4-C: 自分の言葉での説明
「不正な状態を表現不能にする (Make illegal states unrepresentable)」を、
**プログラミング未経験の友人に説明する一段落** を書け。
（Verification 項目そのもの。`notes/learnings/` に残す前提で書く）

---

## 進め方

1. **どれか 1 問** を選んで解く（順番通りでなくていい）
2. utop または `playground/` に書く
3. Claude に「これで合ってる？」と聞く → レビューする
4. 詰まったら問題ごと共有する → ヒントを出す
5. 解けたら次の問題、または `notes/learnings/` に学びを残す

---

## 関連
- [[2026-05-26-phase0-currying]]
- ../../procedure/phase0/02-language-fundamentals.md
