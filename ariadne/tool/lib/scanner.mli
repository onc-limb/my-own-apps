(** ファイルシステムを走査して解析対象を集め、各ファイルを計測する。 *)

type file_result = {
  path : string;       (** 走査起点からの表示用パス *)
  metrics : Metrics.t;
}

(** [collect_targets root] は [root] が
    - ファイルなら、それ 1 つ（拡張子に関わらず）
    - ディレクトリなら、配下の .ts/.tsx/.js/.jsx を再帰的に集める。

    node_modules / .git / _build / dist は走査から除外する。 *)
val collect_targets : string -> string list

(** [analyze_path root] は対象を集め、それぞれを計測して結果リストを返す。
    読めなかったファイルはスキップし、[on_error] が与えられていれば通知する。 *)
val analyze_path :
  ?on_error:(string -> string -> unit) -> string -> file_result list

(** [collect_sources root] は対象ファイルを集め、[(path, source)] の一覧を返す。
    依存グラフ解析のように生ソースが必要な処理で使う。 *)
val collect_sources :
  ?on_error:(string -> string -> unit) -> string -> (string * string) list
