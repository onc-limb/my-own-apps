(** 計測結果を人間向けテキスト / 機械向け JSON で出力する。 *)

(** [text ?threshold results] は結果を循環的複雑度の降順に並べた表と
    集計サマリを文字列で返す。
    [threshold] を与えると、それ以上のファイルに警告マークを付ける。 *)
val text : ?threshold:int -> Scanner.file_result list -> string

(** [json results] は結果を JSON 文字列にする（CI などでの機械処理向け）。 *)
val json : Scanner.file_result list -> string

(** [exceeds threshold results] はしきい値（循環的複雑度）を超えたファイル数を返す。 *)
val exceeds : int -> Scanner.file_result list -> int

(** [coupling_text mods] は結合度メトリクスを主系列からの距離 D の降順で表にする。 *)
val coupling_text : Graph.module_metrics list -> string

(** [coupling_json mods] は結合度メトリクスを JSON 化する。 *)
val coupling_json : Graph.module_metrics list -> string
