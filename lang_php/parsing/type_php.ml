(*s: type_php.ml *)
(*s: Facebook copyright *)
(* Yoann Padioleau
 * 
 * Copyright (C) 2009-2010 Facebook
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
(*e: Facebook copyright *)

open Common
(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(* 
 * It would be more convenient to move this file elsewhere like in analyse_php/
 * but we want our AST to contain type annotations so it's convenient to 
 * have the type definition of PHP types here in parsing_php/. 
 * If later we decide to make a 'a expr, 'a stmt, and have a convenient 
 * mapper between some 'a expr to 'b expr, then maybe we can move
 * this file to a better place.
 * 
 * TODO? have a scalar supertype ? that enclose string/int/bool ?
 * after automatic string interpolation of basic types are useful.
 * Having to do those %s %d in ocaml sometimes sux.
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)
(*s: type phptype *)
type phptype = phptypebis list  (* sorted list, cf typing_php.ml *)
   (* old: | Union of phptype list *)

  and phptypebis = 
    | Basic       of basictype

    | ArrayFamily of arraytype

    (* duck typing style, dont care too much about the name of the class 
     * TODO qualified name ?phpmethod_type list * string list ? *)
    | Object      of string list (* sorted list, class names *)

    (* opened file or mysql connection *)
    | Resource 

    (* PHP 5.3 has closure *)
    | Function of  
        phptype option (* when have default value *) list * 
        phptype (* return type *)

    | Null

    (* TypeVar is used by the type inference and unifier algorithn.
     * It should use a counter for fresh typevariables but it's
     * better to use a string so can give readable type variable like 
     * x_1 for the typevar of the $x parameter.
     *)
    | TypeVar of string

    (* kind of bottom *)
    | Unknown
    (* Top aka Variant, but should never be used *)
    | Top 
(*x: type phptype *)
    and basictype =
      | Bool
      | Int
      | Float
      | String
          
      (* in PHP certain expressions are really more statements *)
      | Unit 
(*x: type phptype *)
    and arraytype = 
      | Array  of phptype
      | Hash   of phptype
      (* duck typing style, ordered list by fieldname *)
      | Record of (string * phptype) list

 (*s: tarzan annotation *)
  (* with tarzan *)
 (*e: tarzan annotation *)
(*e: type phptype *)

exception BadType of string

(*****************************************************************************)
(* String of *)
(*****************************************************************************)

(* generated by ocamltarzan *)

let rec vof_phptype v = Ocaml.vof_list vof_phptypebis v
and vof_phptypebis =
  function
  | Basic v1 -> let v1 = vof_basictype v1 in Ocaml.VSum (("Basic", [ v1 ]))
  | ArrayFamily v1 ->
      let v1 = vof_arraytype v1 in Ocaml.VSum (("ArrayFamily", [ v1 ]))
  | Object v1 ->
      let v1 = Ocaml.vof_list Ocaml.vof_string v1
      in Ocaml.VSum (("Object", [ v1 ]))
  | Resource -> Ocaml.VSum (("Resource", []))
  | Function ((v1, v2)) ->
      let v1 = Ocaml.vof_list (Ocaml.vof_option vof_phptype) v1
      and v2 = vof_phptype v2
      in Ocaml.VSum (("Function", [ v1; v2 ]))
  | Null -> Ocaml.VSum (("Null", []))
  | TypeVar v1 ->
      let v1 = Ocaml.vof_string v1 in Ocaml.VSum (("TypeVar", [ v1 ]))
  | Unknown -> Ocaml.VSum (("Unknown", []))
  | Top -> Ocaml.VSum (("Top", []))
and vof_basictype =
  function
  | Bool -> Ocaml.VSum (("Bool", []))
  | Int -> Ocaml.VSum (("Int", []))
  | Float -> Ocaml.VSum (("Float", []))
  | String -> Ocaml.VSum (("String", []))
  | Unit -> Ocaml.VSum (("Unit", []))
and vof_arraytype =
  function
  | Array v1 -> let v1 = vof_phptype v1 in Ocaml.VSum (("Array", [ v1 ]))
  | Hash v1 -> let v1 = vof_phptype v1 in Ocaml.VSum (("Hash", [ v1 ]))
  | Record v1 ->
      let v1 =
        Ocaml.vof_list
          (fun (v1, v2) ->
             let v1 = Ocaml.vof_string v1
             and v2 = vof_phptype v2
             in Ocaml.VTuple [ v1; v2 ])
          v1
      in Ocaml.VSum (("Record", [ v1 ]))
  

let string_of_phptype t =
  let v = vof_phptype t in
  Ocaml.string_of_v v
(*e: type_php.ml *)
