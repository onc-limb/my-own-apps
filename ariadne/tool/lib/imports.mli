(** 1 つのソースファイルから、依存グラフと抽象度の計算に必要な情報を取り出す。 *)

type module_info = {
  specifiers : string list;
      (** import / export-from / dynamic import / require が参照する
          モジュール指定子（[./foo] や [react] など）。重複あり。 *)
  abstract_exports : int;
      (** 抽象的な公開要素の数: interface / type エイリアス / abstract class。 *)
  concrete_exports : int;
      (** 具体的な公開要素の数: class（非 abstract）/ function / const / let /
          var / enum。 *)
}

(** [extract src] はソース文字列から [module_info] を取り出す。

    v0 の方針:
    - コメントは除去し、文字列リテラルは残したうえで正規表現で抽出する。
    - 抽象度はトップレベルの [export] 宣言のみを数える（再エクスポートや
      名前空間内宣言は数えない近似）。 *)
val extract : string -> module_info
