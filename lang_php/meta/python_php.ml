(* Yoann Padioleau
 *
 * Copyright (C) 2010 Facebook
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

open Common

module O = Ocaml

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*
 * Python stub generator using ocamltarzan and ocaml.ml reflective tower.
 * Inspired by http://docs.python.org/library/ast.html and astgen.py in 
 * Python source (thx to Eugene).
 * 
 * Need to generate both the classes, and a big series of nested new Xxx()
 * that build objects from those classes corresponding to an actual Ast value.
 * Could also add a read() function that takes the JSON of the AST
 * as output by pfff -json and build a value.
 *
 * Alternatives: 
 * 
 * - Could have done it on sexp, but have no sexp of type!! have sexp of value
 * for now. So need sexp of type, but while at it, let's have a more precise
 * sexp of type, let's use directly Ocaml.t
 * 
 * - Could have done it via camlp4 directly on ast_php.ml, not that hard, but  
 * why not use my recent ocaml.ml (in the end it will use in some way camlp4, 
 * but indirectly, via ocamltarzan). Moreover camlp4 is not made to 
 * generate stuff that is not ocaml code but here we have to generate python
 * code.
 * 
 * - Could have done it via astgen.py, but would need to feed astgen.py with
 * a ast.txt file which looks weird. astgen.py does not take a .asdl 
 * as I first suspected. So simpler to generate the code by myself.
 * Then if eugene want customization, it's also arguably easier
 * (well we could hack astgen.py too of course, but astgen.py
 * does not have as much info as me on ast_php.ml via 
 * meta_ast_php_tof.ml
 * 
 * ----------------------------------------------------------------------
 * notes:
 * ----------------------------------------------------------------------
 * http://docs.python.org/library/language.html 
 * "Python provides a number of modules to assist in working with the
 * Python language. These modules support tokenizing, parsing, syntax
 * analysis, bytecode disassembly, and various other facilities."
 * => good language, good citizen
 * 
 * file:/usr/local/lib/python2.6/ast.py
 * 
 * >>> ast.dump(ast.parse("1+1"))
 * 'Module(body=[Expr(value=BinOp(left=Num(n=1), op=Add(), right=Num(n=1)))])'
 * 
 * ast.dump(ast.parse("1+1", include_attributes=True))
 * 
 * file:/usr/local/lib/python2.6/compiler/ast.py
 * This file is automatically generated by Tools/compiler/astgen.py
 * 
 * http://docs.python.org/library/compiler.html
 * 
 * 
 * http://svn.python.org/view/python/trunk/Demo/parser/unparse.py?view=markup
 * 
 * http://asdl.sourceforge.net/
 * Abstract Syntax Description Lanuguage (ASDL)
 * is a language designed to describe the tree-like data structures in compilers
 * 
 * done by Appel :) (ML), Ramsey/Hanson noweb literate programming 
 * I have to use it!
 * 
 * 
 * file:software-src/Python-2.6.4/Parser/asdl.py
 * An implementation of the Zephyr Abstract Syntax Definition Language.
 * See http://asdl.sourceforge.net/ and
 * http://www.cs.princeton.edu/~danwang/Papers/dsl97/dsl97-abstract.html.
 * Only supports top level module decl, not view.  I'm guessing that view
 * is intended to support the browser and I'm not interested in the
 * 
 * file:~/software-src/Python-2.6.4/Parser/Python.asdl
 * but it's an AST really, not CST, so lose token info.
 * 
 * 
 * eugene: also PyPy project, python in python, may have good infrastructure 
 * for compiler then as the compiler/interpreter is written in Python
 * 
 * http://www.python.org/dev/peps/pep-0339/
 * on asdl in python and about ASTs
 * ----------------------------------------------------------------------
 * 
 *)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)


let prelude = "
\"\"\"Php abstract syntax node definitions

This file is automatically generated by ffi and ast_php.ml
\"\"\"

class Node:
    \"\"\"Abstract base class for ast nodes.\"\"\"
    def getChildren(self):
        pass # implemented by subclasses
    def __iter__(self):
        for n in self.getChildren():
            yield n
    def asList(self): # for backwards compatibility
        return self.getChildren()

class EmptyNode(Node):
    pass

"
(* pad: no need make diff between nodes and so nodes I think of:
 *   def getChildNodes(self):
 *       pass # implemented by subclasses
 *)

(*****************************************************************************)
(* Main entry point for class generation *)
(*****************************************************************************)

(* 
 * here is an example of python class that we may like to generate
 * src: python-src/compiler/ast.py
 * 
 * class Add(Node):
 *     def __init__(self, (left, right), lineno=None):
 *         self.left = left
 *         self.right = right
 *         self.lineno = lineno
 * 
 *     def getChildren(self):
 *         return self.left, self.right
 * 
 *     def getChildNodes(self):
 *         return self.left, self.right
 * 
 *     def __repr__(self):
 *         return "Add((%s, %s))" % (repr(self.left), repr(self.right))
 * 
 * 
 * Here is an example of a element of a Sum (an OCaml value of a metatype):
 * ("Binary",
 *  [O.Var "expr"; O.Apply ("wrap", O.Var "binaryOp"); O.Var "expr"]);
 * 
 * The mapping algorithm is quite obvious then.
 * 
 * A few pbs:
 *  what to do with type alias, like 
 *    type program = toplevel list
 *  or with polymorphic types like
 *    type 'a wrap = 'a * info 
 *  ?
 * class program(Node):
 *   def __init__(self, toplevels):
 *     self.toplevel_list = toplevel_list;
 * Will have to take care at construction time to call the appropriate
 * new XXX, including defining classes for List and Option.
 *)

let rec name_of_arg t = 
  match t with
  | O.Var s -> s
  | O.Apply (s, x) -> 
      name_of_arg x  ^ "_" ^ s
  | O.List x -> 
      name_of_arg x  ^ "_" ^ "list"
  | O.Option x -> 
      name_of_arg x  ^ "_" ^ "option"

  | O.Int -> "aint"
  | O.String -> "astring"
  | O.Char -> "achar"
  | O.Float -> "afloat"
  | O.Bool -> "abool"
  | O.Unit -> "aunit"

  | O.Poly s ->
      "poly_" ^ s

  | O.Tuple xs -> 
      xs +> List.map name_of_arg +> Common.join "_" +> (fun s -> s ^ "_tuple")
      
  | O.TTODO s -> "TTODO_" ^ s
  | O.Arrow (_, _) -> 
      raise Todo

  | O.Sum _|O.Dict _
      -> raise Impossible (* can not nest type defs inside defs *)

let rec uniquify_names xs = 
  match xs with
  | [] -> []
  | x::xs ->
      if List.mem x xs
      then
        let cnt = ref 0 in
        incr cnt;
        let x' = x ^ (i_to_s !cnt) in
        let xs' = 
          xs +> List.map (fun s ->
            if s = x 
            then begin 
              incr cnt;
              x ^ (i_to_s !cnt)
            end
            else s
          )
        in
        x'::uniquify_names xs'
      else x::uniquify_names xs
let _ = 
  Common.example 
    (uniquify_names ["expr";"tok";"expr"] = ["expr1";"tok";"expr2"])


let generate_class ~super ~theclass ~args =
  pr (spf "class %s(%s):" theclass super);
  let args_names = 
    match args with
    | Left args_t -> args_t +> List.map name_of_arg +> uniquify_names 
    | Right args_s -> args_s
  in


  pr (spf "  def __init__(%s):"
         (Common.join ", " ("self"::args_names)));
  args_names +> List.iter (fun arg ->
    pr (spf "    self.%s = %s" arg arg)
  );
  if null args_names then pr "    pass";

  pr "";

  pr ("  def getChildren(self):");
  pr (spf "    return %s" 
         (args_names +> List.map (fun arg -> spf "self.%s" arg)
           +> Common.join ","));
  pr "";

  
  pr "  def __repr(self):";
  pr (spf "    return \"%s((%s)) %% (%s)\""
         theclass
         (args_names +> List.map (fun _ -> "%s") +> Common.join ",")
         (args_names +> List.map (fun arg -> spf "repr(self.%s)" arg)
           +> Common.join ","));
  pr "";
  ()


let generate_classes (typename, typ) =
  pr "#-----------------------------------------------------------------------";
  match typ with
  | O.Sum xs ->

      pr (spf "class %s(Node):" typename);
      pr ("    pass");

      xs |> List.iter (fun (constructor, args) ->
        generate_class ~super:typename ~theclass:constructor ~args:(Left args)
      )
  | O.Tuple args -> 
      generate_class ~super:"Node" ~theclass:typename ~args:(Left args);
  | O.Var s -> 
      let args = [O.Var s] in
      generate_class ~super:"Node" ~theclass:typename ~args:(Left args);

  | O.List _ | O.Option _ -> 
      let args = [typ] in
      generate_class ~super:"Node" ~theclass:typename ~args:(Left args);


  | O.Dict xs ->
      let args = 
        xs +> List.map (fun (s, rw_ro, t) ->
          s
        )
      in
      generate_class ~super:"Node" ~theclass:typename ~args:(Right args)


  | (O.TTODO _|O.Apply (_, _)|O.Arrow (_, _)|O.Poly _|
     O.Int|O.String|O.Char|O.Float|O.Bool|O.Unit) ->
      raise Todo

(*****************************************************************************)
(* Main entry point for object generation *)
(*****************************************************************************)
