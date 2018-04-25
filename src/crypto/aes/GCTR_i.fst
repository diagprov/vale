module GCTR_i

open Words_s
open Types_s
open Types_i
open FStar.Mul
open FStar.Seq
open AES_s
open GCTR_s 
open FStar.Math.Lemmas
open Collections.Seqs_i

let bytes_to_quad_size (num_bytes:nat) =
    ((num_bytes + 15) / 16)

let make_gctr_plain_LE (p:seq nat8) : gctr_plain_LE = 
  if 4096 * length p < pow2_32 then p else createEmpty

let slice_work_around (s:seq 'a) (i:int) =
  if 0 <= i && i < length s then slice s 0 i 
  else slice s 0 0

let extra_bytes_helper (n:nat) : Lemma
  (requires n % 16 <> 0)
  (ensures bytes_to_quad_size n == n / 16 + 1)
  =
  ()

let gctr_encrypt_block_offset (icb_BE:quad32) (plain_LE:quad32) (alg:algorithm) (key:aes_key_LE alg) (i:int) :
  Lemma (gctr_encrypt_block icb_BE plain_LE alg key i ==
         gctr_encrypt_block (inc32 icb_BE i) plain_LE alg key 0)
  =
  ()
  
(*
let rec seq_map_i_indexed' (#a:Type) (#b:Type) (f:int->a->b) (s:seq a) (i:int) : 
  Tot (s':seq b { length s' == length s /\
                  (forall j . {:pattern index s' j} 0 <= j /\ j < length s ==> index s' j == f (i + j) (index s j))
                }) 
      (decreases (length s))
  =
  if length s = 0 then createEmpty
  else cons (f i (head s)) (seq_map_i_indexed f (tail s) (i + 1))

let rec test (icb_BE:quad32) (plain_LE:gctr_plain_internal_LE) 
	 (alg:algorithm) (key:aes_key_LE alg) (i:int) :
  Lemma (ensures
     (let gctr_encrypt_block_curried (j:int) (p:quad32) = gctr_encrypt_block icb_BE p alg key j in
     
      gctr_encrypt_recursive icb_BE plain_LE alg key i == seq_map_i_indexed' gctr_encrypt_block_curried plain_LE i)) 
     (decreases (length plain_LE))
  = 
  let gctr_encrypt_block_curried (j:int) (p:quad32) = gctr_encrypt_block icb_BE p alg key j in
  let g = gctr_encrypt_recursive icb_BE plain_LE alg key i in
  let s = seq_map_i_indexed' gctr_encrypt_block_curried plain_LE i in
  if length plain_LE = 0 then (
    assert(equal (g) (s));
    ()
  ) else (
    test icb_BE (tail plain_LE) alg key (i+1);
    assert (gctr_encrypt_recursive icb_BE (tail plain_LE) alg key (i+1) == seq_map_i_indexed' gctr_encrypt_block_curried (tail plain_LE) (i+1))
  )
*)

let aes_encrypt_BE (alg:algorithm) (key:aes_key_LE alg) (p_BE:quad32) =
  let p_LE = reverse_bytes_quad32 p_BE in
  aes_encrypt_LE alg key p_LE

logic let gctr_partial (bound:nat) (plain cipher:seq quad32) (key:aes_key_LE AES_128) (icb:quad32) =
  let bound = min bound (min (length plain) (length cipher)) in
  forall j . {:pattern (index cipher j)} 0 <= j /\ j < bound ==>
    index cipher j == quad32_xor (index plain j) (aes_encrypt_BE AES_128 key (inc32 icb j))
  
let rec gctr_encrypt_recursive_length (icb:quad32) (plain:gctr_plain_internal_LE)
                                      (alg:algorithm) (key:aes_key_LE alg) (i:int) : Lemma
  (requires True)
  (ensures length (gctr_encrypt_recursive icb plain alg key i) == length plain)
  (decreases %[length plain])
  [SMTPat (length (gctr_encrypt_recursive icb plain alg key i))]
  =
  if length plain = 0 then ()
  else gctr_encrypt_recursive_length icb (tail plain) alg key (i + 1)

#reset-options "--z3rlimit 20" 
let rec gctr_encrypt_length (icb_BE:quad32) (plain:gctr_plain_LE)
                             (alg:algorithm) (key:aes_key_LE alg) :
  Lemma(length (gctr_encrypt_LE icb_BE plain alg key) == length plain)
  [SMTPat (length (gctr_encrypt_LE icb_BE plain alg key))]
  =
  let num_extra = (length plain) % 16 in
  let result = gctr_encrypt_LE icb_BE plain alg key in
  if num_extra = 0 then (
    let plain_quads_LE = le_bytes_to_seq_quad32 plain in
    gctr_encrypt_recursive_length icb_BE plain_quads_LE alg key 0
  ) else ( 
    let full_bytes_len = (length plain) - num_extra in
    let full_blocks, final_block = split plain full_bytes_len in
    
    let full_quads_LE = le_bytes_to_seq_quad32 full_blocks in
    let final_quad_LE = le_bytes_to_quad32 (pad_to_128_bits final_block) in
    
    let cipher_quads_LE = gctr_encrypt_recursive icb_BE full_quads_LE alg key 0 in
    let final_cipher_quad_LE = gctr_encrypt_block icb_BE final_quad_LE alg key (full_bytes_len / 16) in
    
    let cipher_bytes_full_LE = le_seq_quad32_to_bytes cipher_quads_LE in
    let final_cipher_bytes_LE = slice (le_quad32_to_bytes final_cipher_quad_LE) 0 num_extra in
    
    gctr_encrypt_recursive_length icb_BE full_quads_LE alg key 0;
    assert (length result == length cipher_bytes_full_LE + length final_cipher_bytes_LE);
    assert (length cipher_quads_LE == length full_quads_LE);
    assert (length cipher_bytes_full_LE == 16 * length cipher_quads_LE);
    assert (16 * length full_quads_LE == length full_blocks);
    assert (length cipher_bytes_full_LE == length full_blocks);
    ()
  )
#reset-options

//#reset-options "--use_two_phase_tc true" // Needed so that indexing cipher and plain knows that their lengths are equal
let rec gctr_indexed_helper (icb:quad32) (plain:gctr_plain_internal_LE)
                            (alg:algorithm) (key:aes_key_LE alg) (i:int) : Lemma
  (requires True)
  (ensures (let cipher = gctr_encrypt_recursive icb plain alg key i in
            length cipher == length plain /\
           (forall j . {:pattern index cipher j} 0 <= j /\ j < length plain ==>
           index cipher j == quad32_xor (index plain j) (aes_encrypt_BE alg key (inc32 icb (i + j)) ))))
  (decreases %[length plain])
=
  if length plain = 0 then ()
  else
      let tl = tail plain in
      let cipher = gctr_encrypt_recursive icb plain alg key i in
      let r_cipher = gctr_encrypt_recursive icb tl alg key (i+1) in
      let helper (j:int) :
        Lemma ((0 <= j /\ j < length plain) ==> (index cipher j == quad32_xor (index plain j) (aes_encrypt_BE alg key (inc32 icb (i + j)) )))
        =
        if 0 < j && j < length plain then (
          gctr_indexed_helper icb tl alg key (i+1);
          assert(index r_cipher (j-1) == quad32_xor (index tl (j-1)) (aes_encrypt_BE alg key (inc32 icb (i + 1 + j - 1)) )) // OBSERVE
        ) else ()
      in
      FStar.Classical.forall_intro helper

let rec gctr_indexed (icb:quad32) (plain:gctr_plain_internal_LE)
                     (alg:algorithm) (key:aes_key_LE alg) (cipher:seq quad32) : Lemma
  (requires  length cipher == length plain /\
             (forall i . {:pattern index cipher i} 0 <= i /\ i < length cipher ==>
             index cipher i == quad32_xor (index plain i) (aes_encrypt_BE alg key (inc32 icb i) )))
  (ensures  cipher == gctr_encrypt_recursive icb plain alg key 0)
=
  gctr_indexed_helper icb plain alg key 0;
  let c = gctr_encrypt_recursive icb plain alg key 0 in
  assert(equal cipher c)  // OBSERVE: Invoke extensionality lemmas


let gctr_partial_completed (plain cipher:seq quad32) (key:aes_key_LE AES_128) (icb:quad32) : Lemma
  (requires length plain == length cipher /\
            256 * (length plain) < pow2_32 /\
            gctr_partial (length cipher) plain cipher key icb)
  (ensures cipher == gctr_encrypt_recursive icb plain AES_128 key 0)
  =
  gctr_indexed icb plain AES_128 key cipher;
  ()

let gctr_partial_to_full_basic (icb_BE:quad32) (plain:seq quad32) (alg:algorithm) (key:aes_key_LE alg) (cipher:seq quad32) : Lemma
  (requires (cipher == gctr_encrypt_recursive icb_BE plain alg key 0) /\
            (4096 * (length plain) * 16 < pow2_32))
  (ensures le_seq_quad32_to_bytes cipher == gctr_encrypt_LE icb_BE (le_seq_quad32_to_bytes plain) alg key)
  =
  let p = le_seq_quad32_to_bytes plain in
  assert (length p % 16 == 0);
  let plain_quads_LE = le_bytes_to_seq_quad32 p in
  let cipher_quads_LE = gctr_encrypt_recursive icb_BE plain_quads_LE alg key 0 in
  let cipher_bytes = le_seq_quad32_to_bytes cipher_quads_LE in
  le_bytes_to_seq_quad32_to_bytes plain;
  ()


let split_commutes_le_seq_quad32_to_bytes (s:seq quad32) (n:nat{n < length s}) :
  Lemma(split (le_seq_quad32_to_bytes s) (16 * n) == 
        (let s0, s1 = split s n in
         (le_seq_quad32_to_bytes s0), (le_seq_quad32_to_bytes s1)))
  =
  admit()

// Want to show that:
//   slice (le_seq_quad32_to_bytes (buffer128_as_seq(mem, out_b))) 0 num_bytes
//   ==
//   gctr_encrypt_LE icb_BE (slice (le_seq_quad32_to_bytes (buffer128_as_seq(mem, in_b))) 0 num_bytes) ...


(*
let gctr_partial_to_full_advanced (icb_BE:quad32) (plain:seq quad32) (alg:algorithm) (key:aes_key_LE alg) (num_bytes:nat) : Lemma
  (requires (1 <= num_bytes /\ num_bytes < 16 * length plain /\
             16 * (length plain - 1) < num_bytes /\
             num_bytes % 16 <> 0 /\ 4096 * num_bytes < pow2_32))
  (ensures (let plain_bytes = slice (le_seq_quad32_to_bytes plain) 0 num_bytes in
            let cipher_bytes = gctr_encrypt_LE icb_BE plain_bytes alg key in
            let cipher_quads = gctr_encrypt_recursive icb_BE plain alg key 0 in
            let cipher_quads_bytes = le_seq_quad32_to_bytes cipher_quads in
            cipher_bytes == slice cipher_quads_bytes 0 num_bytes))
  =
  let plain_bytes = slice (le_seq_quad32_to_bytes plain) 0 num_bytes in
  let cipher_bytes = gctr_encrypt_LE icb_BE plain_bytes alg key in
  let cipher_quads = gctr_encrypt_recursive icb_BE plain alg key 0 in
  let cipher_quads_bytes = le_seq_quad32_to_bytes cipher_quads in
  let num_extra = num_bytes % 16 in
  let full_blocks = (num_bytes - num_extra) / 16 in
  let full_bytes = le_seq_quad32_to_bytes (slice plain 0 full_blocks) in
  let plain_bytes_prefix = slice plain_bytes 0 (full_blocks * 16) in
    let prefix_match (i:int) : Lemma (0 <= i /\ i < full_blocks * 16 ==> index full_bytes i == index plain_bytes_prefix i) 
    =
    ()
    in
  //assert (equal full_bytes (slice plain_bytes 0 (full_blocks * 16)));
(*
  let plain_quads = le_bytes_to_seq_quad32 (pad_to_128_bits plain_bytes) in
    let plain_match (i:int) : Lemma (0 <= i /\ i < length plain - 1 ==> index plain_quads i == index plain i) 
    =
    ()
    in
*)
  admit()
*)

let gctr_encrypt_one_block (icb_BE plain:quad32) (alg:algorithm) (key:aes_key_LE alg) :
  Lemma(gctr_encrypt_LE icb_BE (le_quad32_to_bytes plain) alg key =
        le_seq_quad32_to_bytes (create 1 (quad32_xor plain (aes_encrypt_BE alg key icb_BE)))) =
  assert(inc32 icb_BE 0 == icb_BE);
  let encrypted_icb = aes_encrypt_BE alg key icb_BE in
  let p = le_quad32_to_bytes plain in
  let plain_quads_LE = le_bytes_to_seq_quad32 p in
  let p_seq = create 1 plain in
  assert (length p == 16);
  le_bytes_to_seq_quad32_to_bytes_one_quad plain;
  assert (p_seq == plain_quads_LE);
  let cipher_quads_LE = gctr_encrypt_recursive icb_BE plain_quads_LE alg key 0 in  
  assert (cipher_quads_LE == cons (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0) (gctr_encrypt_recursive icb_BE (tail plain_quads_LE) alg key (1)));
  assert (head plain_quads_LE == plain);

  assert (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0 == 
          (let icb_LE = reverse_bytes_quad32 (inc32 icb_BE 0) in
           quad32_xor (head plain_quads_LE) (aes_encrypt_LE alg key icb_LE)));
  assert (quad32_xor plain (aes_encrypt_LE alg key (reverse_bytes_quad32 icb_BE))
          ==
          (let icb_LE = reverse_bytes_quad32 (inc32 icb_BE 0) in
           quad32_xor (head plain_quads_LE) (aes_encrypt_LE alg key icb_LE)));
  assert (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0 == quad32_xor plain (aes_encrypt_LE alg key (reverse_bytes_quad32 icb_BE)));
  assert (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0 == quad32_xor plain (aes_encrypt_BE alg key icb_BE));
  assert (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0 == quad32_xor plain encrypted_icb);
  assert(gctr_encrypt_recursive icb_BE (tail p_seq) alg key 1 == createEmpty);   // OBSERVE
  //assert(gctr_encrypt_LE icb p alg key == cons (quad32_xor plain encrypted_icb) createEmpty);
  let x = quad32_xor plain encrypted_icb in
  append_empty_r (create 1 x);                 // This is the missing piece
  ()
 
