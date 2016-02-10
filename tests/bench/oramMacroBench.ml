open Core_kernel.Std
open Testable

let connectAndInitialiseORAMOfSize desiredSizeInSectors =
  match Lwt_main.run (newORAM ~desiredSizeInSectors ~fileName:"disk1.img" ()) with
  | `Ok oram -> oram
  | `Error _ -> failwith (Printf.sprintf "Failed to connect to oram with size %Ld" desiredSizeInSectors)

let dataForORAM oram =
  let info = Lwt_main.run (O.get_info oram) in
  Some (Cstruct.create (info.O.sector_size))

let desiredSizes =
  let heights = List.range 0 10 in
  List.map ~f:(fun height -> Int64.of_int ((Int.pow 2 (height + 1) - 1) * 4)) heights

(* Loop around writing then reading over and over again! *)
let performExperiment oram desiredSizeInSectors data =
  let reverseOperation = function
    | O.Read -> O.Write
    | O.Write -> O.Read
  in
  let rec loop address operation = function
    | 0 -> Lwt.return (`Ok ())
    | n ->
       O.access oram operation address data >>= fun _ ->
       if address = Int64.(desiredSizeInSectors - 1L)
       then loop 0L (reverseOperation operation) (n - 1)
       else loop Int64.(address + 1L) operation (n - 1)
  in loop 0L O.Write 10

let () =
  List.iter desiredSizes
            ~f:(fun desiredSizeInSectors ->
              Printf.printf "%Ld, %!" desiredSizeInSectors;
              let oram = connectAndInitialiseORAMOfSize desiredSizeInSectors in
              let data = dataForORAM oram in
              let start = Time_ns.now () in
              begin match Lwt_main.run (performExperiment oram desiredSizeInSectors data) with
              | `Ok () -> ()
              | `Error _ -> failwith "Failed to perform experiment"
              end;
              let time = Time_ns.abs_diff start (Time_ns.now ()) in
              Printf.printf "%f\n%!" (Time_ns.Span.to_ms time))
