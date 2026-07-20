open Cmdliner

(* `scan` サブコマンドの本体。 *)
let run_scan path json_out threshold =
  let results =
    Ariadne.Scanner.analyze_path
      ~on_error:(fun p msg -> Printf.eprintf "skip %s: %s\n" p msg)
      path
  in
  if json_out then print_string (Ariadne.Report.json results)
  else begin
    let threshold = if threshold > 0 then Some threshold else None in
    print_string (Ariadne.Report.text ?threshold results)
  end;
  (* しきい値超過があれば終了コード 1（CI ゲート用） *)
  if (not json_out) && threshold > 0
     && Ariadne.Report.exceeds threshold results > 0
  then 1
  else 0

let path_arg =
  let doc = "解析対象のファイルまたはディレクトリ。" in
  Arg.(value & pos 0 string "." & info [] ~docv:"PATH" ~doc)

let json_arg =
  let doc = "結果を JSON で出力する（CI などの機械処理向け）。" in
  Arg.(value & flag & info [ "json" ] ~doc)

let threshold_arg =
  let doc = "循環的複雑度がこの値以上のファイルに警告を付ける（0 で無効）。" in
  Arg.(value & opt int 0 & info [ "t"; "threshold" ] ~docv:"N" ~doc)

let scan_cmd =
  let doc = "TypeScript/JavaScript の複雑度と LOC を計測する" in
  let info = Cmd.info "scan" ~doc in
  Cmd.v info
    Term.(const run_scan $ path_arg $ json_arg $ threshold_arg)

(* `coupling` サブコマンド: import グラフから結合度メトリクスを計算する。 *)
let run_coupling path json_out =
  let sources =
    Ariadne.Scanner.collect_sources
      ~on_error:(fun p msg -> Printf.eprintf "skip %s: %s\n" p msg)
      path
  in
  let entries =
    List.map (fun (p, src) -> (p, Ariadne.Imports.extract src)) sources
  in
  let mods = Ariadne.Graph.analyze entries in
  if json_out then print_string (Ariadne.Report.coupling_json mods)
  else print_string (Ariadne.Report.coupling_text mods);
  0

let coupling_cmd =
  let doc = "import グラフから Ca/Ce・不安定度・抽象度・主系列距離を計算する" in
  let info = Cmd.info "coupling" ~doc in
  Cmd.v info Term.(const run_coupling $ path_arg $ json_arg)

let main_cmd =
  let doc = "アーキテクチャメトリクス計測ツール（Ariadne）" in
  let info = Cmd.info "ariadne" ~version:"0.2.0" ~doc in
  Cmd.group info [ scan_cmd; coupling_cmd ]

let () = exit (Cmd.eval' main_cmd)
