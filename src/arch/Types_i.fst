module Types_i

open Types_s
open TypesNative_i
open Collections.Seqs_i
open Words_s
open Words.Two_i

let lemma_BitwiseXorCommutative x y =
  lemma_ixor_nth_all 32;
  lemma_equal_nth 32 (x *^ y) (y *^ x)

let lemma_BitwiseXorWithZero n =
  lemma_ixor_nth_all 32;
  lemma_zero_nth 32;
  lemma_equal_nth 32 (n *^ 0) n

let lemma_BitwiseXorCancel n =
  lemma_ixor_nth_all 32;
  lemma_zero_nth 32;
  lemma_equal_nth 32 (n *^ n) 0

let lemma_BitwiseXorCancel64 (n:nat64) =
  lemma_ixor_nth_all 64;
  lemma_zero_nth 64;
  lemma_equal_nth 64 (ixor n n) 0 

let lemma_BitwiseXorAssociative x y z =
  lemma_ixor_nth_all 32;
  lemma_equal_nth 32 (x *^ (y *^ z)) ((x *^ y) *^ z)

let xor_lemmas () =
  FStar.Classical.forall_intro_2 lemma_BitwiseXorCommutative;
  FStar.Classical.forall_intro lemma_BitwiseXorWithZero;
  FStar.Classical.forall_intro lemma_BitwiseXorCancel;
  FStar.Classical.forall_intro lemma_BitwiseXorCancel64;
  FStar.Classical.forall_intro_3 lemma_BitwiseXorAssociative;
  ()

let lemma_quad32_xor () =
  xor_lemmas()

let lemma_reverse_reverse_bytes_nat32 (n:nat32) :
  Lemma (reverse_bytes_nat32 (reverse_bytes_nat32 n) == n)
  =
  let r = reverse_seq (nat32_to_be_bytes n) in
  be_bytes_to_nat32_to_be_bytes r;
  ()

let lemma_reverse_bytes_quad32 (q:quad32) =
  reveal_reverse_bytes_quad32 q;
  reveal_reverse_bytes_quad32 (reverse_bytes_quad32 q);
  ()

let lemma_reverse_reverse_bytes_nat32_seq (s:seq nat32) :
  Lemma (ensures reverse_bytes_nat32_seq (reverse_bytes_nat32_seq s) == s)
  =
  reveal_reverse_bytes_nat32_seq s;
  reveal_reverse_bytes_nat32_seq (reverse_bytes_nat32_seq s);
  assert (equal (reverse_bytes_nat32_seq (reverse_bytes_nat32_seq s)) s)


let push_pop_xmm (x y:quad32) : Lemma 
  (let x' = insert_nat64 (insert_nat64 y (hi64 x) 1) (lo64 x) 0 in
   x == x')
   =
//   assert (nat_to_two 32 (hi64 x) == two_select (four_to_two_two x) 1);
   ()


#reset-options "--z3rlimit 10 --max_fuel 0 --max_ifuel 0 --using_facts_from '* -FStar.Seq.Properties'"
let le_bytes_to_seq_quad32_to_bytes_one_quad (b:quad32) :
  Lemma (le_bytes_to_seq_quad32 (le_quad32_to_bytes b) == create 1 b)
(* This expands into showing:
   le_bytes_to_seq_quad32 (le_quad32_to_bytes b)
 == { definition of le_bytes_to_seq_quad32 }
   seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b))
 == { definition of le_quad32_to_bytes }
   seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))))
 == { definition of seq_nat8_to_seq_nat32_LE }
   seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)))))
 == { seq_to_seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)) }
   seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_map (nat_to_four 8) (four_to_seq_LE b)))
 == { seq_map_inverses (four_to_nat 8) (nat_to_four 8) (four_to_seq_LE b) }
   seq_to_seq_four_LE (four_to_seq_LE b)
 == { four_to_seq_LE_is_seq_four_to_seq_LE b }
   seq_to_seq_four_LE (seq_four_to_seq_LE (create 1 b))
 == { seq_to_seq_four_to_seq_LE (create 1 b) }
   create 1 b
 *)
  =
  seq_to_seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b));
  seq_map_inverses (nat_to_four 8) (four_to_nat 8) (four_to_seq_LE b);
  four_to_seq_LE_is_seq_four_to_seq_LE b;
  seq_to_seq_four_to_seq_LE (create 1 b) ;
  (*
  assert (le_bytes_to_seq_quad32 (le_quad32_to_bytes b) == seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b)));
  assert (le_quad32_to_bytes b == seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)));
  assert ((le_bytes_to_seq_quad32 (le_quad32_to_bytes b)) == 
          (seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)))))
          ); 
  let annoying_definition_expander (x:seq nat8{length x % 4 == 0}) :
    Lemma ( (seq_nat8_to_seq_nat32_LE (x)) ==
           (seq_map (four_to_nat 8) (seq_to_seq_four_LE x) )) = () in

  let (s:seq nat8{length s % 4 == 0}) = seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)) in
  //annoying_definition_expander s;
  assert ( (seq_nat8_to_seq_nat32_LE (s)) ==
           (seq_map (four_to_nat 8) (seq_to_seq_four_LE s) ));
           
  assert ( (le_bytes_to_seq_quad32 (le_quad32_to_bytes b)) ==
           seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE s)) );           
  assert (seq_to_seq_four_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))) ==
          seq_map (nat_to_four 8) (four_to_seq_LE b));
  assert ( (le_bytes_to_seq_quad32 (le_quad32_to_bytes b)) ==
           seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_map (nat_to_four 8) (four_to_seq_LE b))) );
  (*
  assert ( (seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))))))
                   ==
                  (seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_map (nat_to_four 8) (four_to_seq_LE b)))));
                  *)
  //assert (equal (le_bytes_to_seq_quad32 (le_quad32_to_bytes b)) (create 1 b));
  //admit();
  *)
  ()
 

(*
  Let s4 = seq_map (nat_to_four 8) (four_to_seq_LE b) in
  let s4wrapped = seq_to_seq_four_LE (seq_four_to_seq_LE s4) in
  assert (s4wrapped == s4);
  seq_map_inverses (nat_to_four 8) (four_to_nat 8) (four_to_seq_LE b);
  seq_to_seq_four_to_seq_LE (create 1 b);
  four_to_seq_LE_is_seq_four_to_seq_LE b;

  assert (le_bytes_to_seq_quad32 (le_quad32_to_bytes b) ==
            seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b)));
  assert (equal (le_quad32_to_bytes b) (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))));
  (*
  assert (equal (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b)) 
                (seq_nat8_to_seq_nat32_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)))));
  *)
  admit();
  assert (equal (seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b)))
          (seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))))));
  admit();
  ()
*)


let le_bytes_to_seq_quad32_to_bytes (s:seq quad32) :
  Lemma (le_bytes_to_seq_quad32 (le_seq_quad32_to_bytes s) == s)
(* This expands into showing:
   le_bytes_to_seq_quad32 (le_quad32_to_bytes s)
 == { definition of le_bytes_to_seq_quad32 }
   seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_seq_quad32_to_bytes s))
 == { definition of le_seq_quad32_to_bytes }
   seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (seq_nat32_to_seq_nat8_LE (seq_four_to_seq_LE s)))
 == { definition of seq_nat8_to_seq_nat32_LE }
   seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (seq_nat32_to_seq_nat8_LE (seq_four_to_seq_LE s))))
 == { definition of seq_nat32_to_seq_nat8_LE }
    seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (seq_four_to_seq_LE s)))))
 *)
  =
  seq_to_seq_four_to_seq_LE (seq_map (nat_to_four 8) (seq_four_to_seq_LE s));
  seq_map_inverses (nat_to_four 8) (four_to_nat 8) (seq_four_to_seq_LE s);
  seq_to_seq_four_to_seq_LE (s) ;
  ()
