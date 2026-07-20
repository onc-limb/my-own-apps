(** モジュール依存グラフから Robert C. Martin のパッケージメトリクスを計算する。

    出典: Robert C. Martin, "OO Design Quality Metrics: An Analysis of
    Dependencies" (1994)。 *)

type module_metrics = {
  path : string;          (** 表示用パス *)
  ca : int;               (** 求心性結合: このモジュールに依存する内部モジュール数 *)
  ce : int;               (** 遠心性結合: このモジュールが依存する内部モジュール数 *)
  instability : float;    (** 不安定度 I = Ce / (Ca + Ce)。0=安定, 1=不安定 *)
  abstractness : float;   (** 抽象度 A = 抽象 export / 全 export。0=具体, 1=抽象 *)
  distance : float;       (** 主系列からの距離 D = |A + I - 1|。小さいほど良い *)
  external_deps : int;    (** 解決できない外部依存（バレ指定子など）の数 *)
}

(** [analyze entries] は [(表示用パス, Imports.module_info)] の一覧から
    各モジュールのメトリクスを計算する。

    モジュール解決:
    - 相対指定子（[.] で始まる）のみを内部依存として解決する。
      候補に [.ts/.tsx/.js/.jsx] と [index.*] を試す。
    - バレ指定子（[react] 等）や解決できない相対指定子は外部依存として数える。
    - 不安定度 I の Ce は内部依存のみで計算する（外部依存は別途 [external_deps]）。 *)
val analyze : (string * Imports.module_info) list -> module_metrics list
