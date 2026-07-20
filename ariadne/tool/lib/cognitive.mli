(** 認知的複雑度 (Cognitive Complexity)。

    出典: G. Ann Campbell, "Cognitive Complexity — A new way of measuring
    understandability", SonarSource white paper (2017)。

    循環的複雑度がテスト容易性を測るのに対し、認知的複雑度は
    「読んで理解する難しさ」を測る。3 つの原則で加点する:
    - B1. 線形な流れを断ち切る構造に基本加点 (+1): if / else if / else /
      for / while / do / switch / catch / 三項 / 論理演算子の列
    - B2. ネストした構造にはネスト深さぶんを追加加点
      （深くネストした if ほど重くなる）
    - B3. 読みやすさを損なわない要素（else if の if 重複、case 個別）は加点しない

    本実装はトークン列ベースの「近似」であり、完全な AST 解析とは差が出る。
    本実装で意図的に簡略化している点:
    - ネストの単位は波括弧で近似する（波括弧なしの単文 if 等では子のネストを数えない）。
    - トップレベル関数本体はネスト 0。ネストした関数（[nesting > 0] の波括弧内に
      現れる関数）のみネストを 1 段加算する。コールバックがネスト 0 にある場合は
      その内部をネスト加算しない（過小評価方向）。
    - [??] も論理演算子の列として扱う。
    - 型レベルの条件型 [T extends U ? X : Y] の [?] も三項として数えてしまう。
    これらは tree-sitter（AST）フロントエンド導入時に解消予定。 *)

(** [complexity tokens] は [Lexer.tokenize] が返したトークン列から
    ファイル全体の認知的複雑度（近似値）を計算する。 *)
val complexity : Lexer.token list -> int
