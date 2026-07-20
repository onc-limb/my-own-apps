type file_result = {
  path : string;
  metrics : Metrics.t;
}

let target_exts = [ ".ts"; ".tsx"; ".js"; ".jsx" ]
let excluded_dirs = [ "node_modules"; ".git"; "_build"; "dist"; "build" ]

let has_target_ext path =
  List.exists (fun e -> Filename.check_suffix path e) target_exts

(* ディレクトリを深さ優先で再帰し、対象拡張子のファイルパスを集める。 *)
let rec walk acc dir =
  let entries = try Sys.readdir dir with Sys_error _ -> [||] in
  Array.fold_left
    (fun acc name ->
      let full = Filename.concat dir name in
      if Sys.is_directory full then
        if List.mem name excluded_dirs then acc else walk acc full
      else if has_target_ext full then full :: acc
      else acc)
    acc entries

let collect_targets root =
  if not (Sys.file_exists root) then []
  else if Sys.is_directory root then List.sort compare (walk [] root)
  else [ root ]

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let collect_sources ?on_error root =
  collect_targets root
  |> List.filter_map (fun path ->
         match read_file path with
         | src -> Some (path, src)
         | exception Sys_error msg ->
           (match on_error with Some f -> f path msg | None -> ());
           None)

let analyze_path ?on_error root =
  collect_sources ?on_error root
  |> List.map (fun (path, src) -> { path; metrics = Metrics.analyze src })
