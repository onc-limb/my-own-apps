(** 1 ファイル分の計測結果。 *)

type loc = {
  total : int;    (** 総行数 *)
  code : int;     (** コードを含む行 *)
  comment : int;  (** コメントのみの行 *)
  blank : int;    (** 空行 *)
}

type t = {
  loc : loc;
  cyclomatic : int;
      (** McCabe 循環的複雑度（ファイル全体）= 1 + 分岐点の数。
          分岐点 = if / for / while / case / catch、論理演算子 && || ??、
          三項演算子 ?:。
          出典: SonarSource "Cognitive Complexity" white paper。 *)
  cognitive : int;
      (** 認知的複雑度（近似値）。詳細は {!Cognitive}。 *)
  functions : int;
      (** おおまかな関数の個数（[function] キーワード + アロー [=>] の数）。 *)
}

(** [analyze src] は TypeScript/JavaScript ソース文字列を計測する。
    計測はファイル単位（関数単位の内訳は AST フロントエンド導入後に対応予定）。 *)
val analyze : string -> t
