open OUnit
open Pci

let resident_pages () =
  let with_channel c f =
    try let r = f c in close_in c; r
    with exn -> close_in_noerr c; raise exn in
  let statm_path = List.fold_left Filename.concat "/"
    [ "proc"; Unix.getpid () |> string_of_int; "statm" ] in
  let statm = with_channel (open_in statm_path) input_line in
  Scanf.sscanf statm "%d %d %d %d %d %d %d" (fun _ res _ _ _ _ _ -> res)

let smoke_test () =
  with_access (fun a -> let (_: Pci_dev.t list) = get_devices a in ())

let test_with_access_cleanup () =
  (* Get overhead for calling the fuction and the measuremnt functions *)
  let _ = Gc.compact (); resident_pages () in
  for i = 1 to 1000 do with_access ~cleanup:true (fun _ -> ()) done;
  let mem = Gc.compact (); resident_pages () in
  (* The incremental cost of calling with_access should be 0 *)
  for i = 1 to 1000 do with_access ~cleanup:true (fun _ -> ()) done;
  let mem' = Gc.compact (); resident_pages () in
  assert_equal ~printer:(Printf.sprintf "VmRSS = %d pages") mem mem';
  (* Checking for a difference with cleanup=false as a negative test *)
  for i = 1 to 1000 do with_access ~cleanup:false (fun _ -> ()) done;
  let mem'' = Gc.compact (); resident_pages () in
  assert_raises (OUnitTest.OUnit_failure "not equal") (fun () ->
    assert_equal mem' mem'')

let _ =
  let suite = "pci" >:::
    [
      "smoke_test" >:: smoke_test;
      "test_with_access_cleanup" >:: test_with_access_cleanup;
    ]
  in
  run_test_tt suite
