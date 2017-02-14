From QuickChick Require Import QuickChick Tactics.
Require Import String. Open Scope string.

From mathcomp Require Import ssreflect ssrfun ssrbool ssrnat eqtype seq.

Import GenLow GenHigh.
Require Import List.
Import ListNotations.
Import QcDefaultNotation. Open Scope qc_scope.
Import QcDoNotation.

Set Bullet Behavior "Strict Subproofs".

(* Probably also add a logic programming execution mode? *)
Class DepGen (A : Type) (P : A -> Prop) :=
  {
    depGen : G (option A)
  }. 

(* TODO (maybe): Find a way to unify these? *)
Class DepDec1 (A : Type) (P : A -> Prop) :=
  {
    depDec1 : forall (x : A), {P x} + {~ (P x)}
  }.

Class DepDec2 (A B : Type) (P : A -> B -> Prop) :=
  {
    depDec2 : forall (x : A) (y : B), {P x y} + {~ (P x y)}
  }.

Class DepDec3 (A B C : Type) (P : A -> B -> C -> Prop) :=
  {
    depDec3 : forall (x : A) (y : B) (z : C), {P x y z} + {~ (P x y z)}
  }.

(* I can't seem to get this to work 
Class DepDec (P : Prop) := { depDec : {P} + {~ P} }.
Instance DepDecFun {A} (x : A) (P : A -> Type) `{_ : DepDec (P} : DepDec (P x).
*)

Inductive Foo :=
| Foo1 : Foo 
| Foo2 : Foo -> Foo
| Foo3 : nat -> Foo -> Foo.

DeriveArbitrary Foo as "arbFoo" "genFooSized'".
DeriveShow Foo as "showFoo'".

(* Use custom formatting of generated code, and prove them equal (by reflexivity) *)

(* begin show_foo *)
Fixpoint showFoo (x : Foo) := 
  match x with 
  | Foo1 => "Foo1  " ++ ""
  | Foo2 f => "Foo2  " ++ ("( " ++ showFoo f ++ " )") ++ " " ++ ""
  | Foo3 n f => "Foo3  " ++ ("( " ++ show     n ++ " )") ++
                     " " ++ ("( " ++ showFoo f ++ " )") ++ " " ++ ""
  end%string.
(* end show_foo *)

Lemma show_foo_equality : showFoo = (@show Foo _).
Proof. reflexivity. Qed.

(* begin genFooSized *)
Fixpoint genFooSized (size : nat) := 
  match size with 
  | O => returnGen Foo1
  | S size' => freq [ (1, returnGen Foo1) 
                    ; (size, do! f <- genFooSized size'; 
                             returnGen (Foo2 f))
                    ; (size, do! n <- arbitrary; 
                             do! f <- genFooSized size';
                             returnGen (Foo3 n f)) 
                    ]
  end.                 
(* end genFooSized *)                                           

(* begin shrink_foo *)
Fixpoint shrink_foo x := 
  match x with
  | Foo1 => []
  | Foo2 f => ([f] ++ map (fun f' => Foo2 f') (shrink_foo f) ++ []) ++ []
  | Foo3 n f => (map (fun n' => Foo3 n' f) (shrink n) ++ []) ++
                ([f] ++ map (fun f' => Foo3 n f') (shrink_foo f) ++ []) ++ []
  end.
(* end shrink_foo *)

Lemma genFooSizedNotation : genFooSized = genFooSized'.
Proof. reflexivity. Qed.

Lemma shrinkFoo_equality : shrink_foo = @shrink Foo _.
Proof. reflexivity. Qed.

(* Completely unrestricted case *)
(* begin good_foo *)
Inductive goodFoo : nat -> Foo -> Prop :=
| GoodFoo : forall n foo, goodFoo n foo.
(* end good_foo *)

DeriveDependent goodFoo for 2 as "genGoodFoo'".

(* Simple generator for goodFoos *)
(* begin gen_good_foo_simple *)
Definition genGoodFoo {_ : Arbitrary Foo} (n : nat) : G Foo := arbitrary.
(* end gen_good_foo_simple *)

(* begin gen_good_foo *)
Definition genGoodFoo {_ : Arbitrary Foo} (n : nat) :=
  let fix aux_arb size n := 
    match size with 
    | 0   => backtrack [(1, do! foo <- arbitrary; returnGen (Some foo))]
    | S _ => backtrack [(1, do! foo <- arbitrary; returnGen (Some foo))]
    end
  in fun sz => aux_arb sz n.
(* end gen_good_foo *)

Lemma genGoodFoo_equality : genGoodFoo = genGoodFoo'.
Proof. reflexivity. Qed.

(* Copy to extract just the relevant generator part *)
Definition genGoodFoo'' {_ : Arbitrary Foo} (n : nat) :=
  let fix aux_arb size n := 
    match size with 
    | 0   => backtrack [(1, 
(* begin gen_good_foo_gen *)
  do! foo <- arbitrary; returnGen (Some foo)
(* end gen_good_foo_gen *)
                        )]
    | S _ => backtrack [(1, do! foo <- arbitrary; returnGen (Some foo))]
    end
  in fun sz => aux_arb sz n.

Lemma genGoodFoo_equality' : genGoodFoo = genGoodFoo''.
Proof. reflexivity. Qed.

(* Basic Unification *)
(* begin good_unif *)
Inductive goodFooUnif : nat -> Foo -> Prop := 
| GoodUnif : forall n, goodFooUnif n Foo1.
(* end good_unif *)

DeriveDependent goodFooUnif for 2 as "genGoodUnif'".

Definition genGoodUnif (n : nat) :=
  let fix aux_arb size n := 
    match size with 
    | 0   => backtrack [(1, 
(* begin good_foo_unif_gen *)
  returnGen (Some Foo1)
(* end good_foo_unif_gen *)
                        )] 
    | S _ => backtrack [(1, returnGen (Some Foo1))] 
    end
  in fun sz => aux_arb sz n.

Lemma genGoodUnif_equality : genGoodUnif = genGoodUnif'.
Proof. reflexivity. Qed.

(* Requires input nat to match 0 *)
(* begin good_input_match *)
Inductive goodFooMatch : nat -> Foo -> Prop := 
| GoodMatch : goodFooMatch 0 Foo1.
(* end good_input_match *)

DeriveDependent goodFooMatch for 2 as "genGoodMatch'".

Definition genGoodMatch (n : nat) :=
  let fix aux_arb size n := 
    match size with 
    | 0   => backtrack [(1, 
(* begin good_foo_unif_gen *)
  match n with
  | 0 => returnGen (Some Foo1)
  | _.+1 => returnGen None
  end
(* end good_foo_unif_gen *)
                        )]
    | S _ => backtrack [(1,
           match n with
           | 0 => returnGen (Some Foo1)
           | _.+1 => returnGen None
           end)]
    end
  in fun sz => aux_arb sz n.

Lemma genGoodUnif_equality : genGoodUnif = genGoodUnif'.
Proof. reflexivity. Qed.


genGoodMatch' = 
fun input0 : nat =>
let
  fix aux_arb (size0 input1 : nat) {struct size0} : 
  G (option Foo) :=
    match size0 with
    | 0 =>
        backtrack
          [(1,
    | _.+1 =>
        backtrack
          [(1,
           match input1 with
           | 0 => returnGen (Some Foo1)
           | _.+1 => returnGen None
           end)]
    end in
aux_arb^~ input0
     : nat -> nat -> G (option Foo)



(* The foo is generated by arbitrary *)
Inductive goodFoo3 : nat -> Foo -> Prop :=
| Good3 : forall n foo, goodFoo3 n (Foo2 foo).

(* Requires recursive call of generator *)
Inductive goodFooRec : nat -> Foo -> Prop :=
| GoodRecBase : forall n, goodFooRec n Foo1
| GoodRec : forall n foo, goodFooRec 0 foo -> goodFooRec n (Foo2 foo).

(* Precondition *)
Inductive goodFooPrec : nat -> Foo -> Prop :=
| GoodPrecBase : forall n, goodFooPrec n Foo1
| GoodPrec : forall n foo, goodFooPrec 0 Foo1 -> goodFooPrec n foo.

(* Generation followed by check - backtracking necessary *)
Inductive goodFooNarrow : nat -> Foo -> Prop :=
| GoodNarrowBase : forall n, goodFooNarrow n Foo1
| GoodNarrow : forall n foo, goodFooNarrow 0 foo -> 
                             goodFooNarrow 1 foo -> 
                             goodFooNarrow n foo.

(* Non-linear constraint *)
Inductive goodFooNL : nat -> nat -> Foo -> Prop :=
| GoodNL : forall n foo, goodFooNL n n foo.

(* DepGen seems to be the correct way to use typeclasses *)
(*
Axiom genGoodFooTarget : forall (sz : nat) (n : nat), G (option Foo).
Instance depGenGoodFoo (n : nat) : DepGen Foo (goodFoo n) := 
  {| depGen := sized (fun sz => genGoodFooTarget sz n) |}.
*)
DeriveDependent goodFoo for 2 as "genGoodFoo". 

Inductive Bar A B :=
| Bar1 : A -> Bar A B
| Bar2 : Bar A B -> Bar A B
| Bar3 : A -> B -> Bar A B -> Bar A B -> Bar A B.

Arguments Bar1 {A} {B} _.
Arguments Bar2 {A} {B} _.
Arguments Bar3 {A} {B} _ _ _ _.

Inductive goodBar {A B : Type} (n : nat) : Bar A B -> Prop :=
| goodBar1 : forall a, goodBar n (Bar1 a)
| goodBar2 : forall bar, goodBar 0 bar -> goodBar n (Bar2 bar)
| goodBar3 : forall a b bar,
            goodBar n bar ->
            goodBar n (Bar3 a b (Bar1 a) bar).

DeriveDependent goodBar for 2 as "genGoodBar".

