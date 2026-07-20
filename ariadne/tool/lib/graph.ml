type module_metrics = {
  path : string;
  ca : int;
  ce : int;
  instability : float;
  abstractness : float;
  distance : float;
  external_deps : int;
}

let exts = [ ".ts"; ".tsx"; ".js"; ".jsx" ]

(* パスを絶対化し、. / .. を字句的に解決した正規形にする（突き合わせ用の ID）。 *)
let canon p =
  let abs =
    if Filename.is_relative p then Filename.concat (Sys.getcwd ()) p else p
  in
  Fpath.v abs |> Fpath.normalize |> Fpath.to_string

(* dir からの相対指定子 spec を、既知ファイル集合 fileset 内のモジュールに解決する。
   解決できなければ None（= 外部依存扱い）。 *)
let resolve fileset dir spec =
  if String.length spec = 0 || spec.[0] <> '.' then None
  else begin
    let base = canon (Filename.concat dir spec) in
    let candidates =
      (base :: List.map (fun e -> base ^ e) exts)
      @ List.map (fun e -> canon (Filename.concat base ("index" ^ e))) exts
    in
    List.find_opt (fun c -> Hashtbl.mem fileset c) candidates
  end

let analyze (entries : (string * Imports.module_info) list) : module_metrics list =
  let mods = List.map (fun (p, info) -> (p, canon p, info)) entries in
  let fileset = Hashtbl.create 64 in
  List.iter (fun (_, c, _) -> Hashtbl.replace fileset c ()) mods;

  (* 各モジュールの内部依存先（distinct）と外部依存数を先に求める。 *)
  let ca_tbl = Hashtbl.create 64 in
  let bump k =
    Hashtbl.replace ca_tbl k (1 + (try Hashtbl.find ca_tbl k with Not_found -> 0))
  in
  let pre =
    List.map
      (fun (p, c, info) ->
        let dir = Filename.dirname c in
        let specs = List.sort_uniq compare info.Imports.specifiers in
        let internal =
          List.filter_map (fun s -> resolve fileset dir s) specs
          |> List.sort_uniq compare
          |> List.filter (fun t -> t <> c)  (* 自己参照は除く *)
        in
        let external_deps =
          List.length (List.filter (fun s -> resolve fileset dir s = None) specs)
        in
        (* 依存先の求心性結合 Ca を加算 *)
        List.iter bump internal;
        (p, c, info, internal, external_deps))
      mods
  in

  List.map
    (fun (p, c, info, internal, external_deps) ->
      let ce = List.length internal in
      let ca = try Hashtbl.find ca_tbl c with Not_found -> 0 in
      let instability =
        if ca + ce = 0 then 0.0 else float_of_int ce /. float_of_int (ca + ce)
      in
      let total_exports =
        info.Imports.abstract_exports + info.Imports.concrete_exports
      in
      let abstractness =
        if total_exports = 0 then 0.0
        else float_of_int info.Imports.abstract_exports /. float_of_int total_exports
      in
      let distance = abs_float (abstractness +. instability -. 1.0) in
      { path = p; ca; ce; instability; abstractness; distance; external_deps })
    pre
