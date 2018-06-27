module X64.Vale.StateLemmas_i
open X64.Machine_s
open X64.Vale.State_i
open FStar.FunctionalExtensionality
module S = X64.Semantics_s
module M = TransparentMap
module BS = X64.Bytes_Semantics_s
module ME = X64.Memory_i_s
module TS = X64.Taint_Semantics_s
module MT = X64.Vale.Memtaint_i
open Taint_interop

unfold let ok' s = s.ME.state.BS.ok
unfold let regs' s = s.ME.state.BS.regs
unfold let xmms' s = s.ME.state.BS.xmms
unfold let flags' s = s.ME.state.BS.flags
unfold let mem' = ME.Mkstate'?.mem
unfold let trace' = TS.MktraceState?.trace
unfold let memTaint' = TS.MktraceState?.memTaint

val state_to_S : s:state -> GTot TS.traceState
val state_of_S : s:TS.traceState -> GTot state

val lemma_to_ok : s:state -> Lemma
  (ensures s.ok == ok' (state_to_S s).TS.state)
  [SMTPat s.ok]

val lemma_to_flags : s:state -> Lemma
  (ensures s.flags == flags' (state_to_S s).TS.state)
  [SMTPat s.flags]

val lemma_to_mem : s:state -> Lemma
  (ensures s.mem == mem' (state_to_S s).TS.state)
  [SMTPat s.mem]
  
val lemma_to_reg : s:state -> r:reg -> Lemma
  (ensures s.regs r == regs' (state_to_S s).TS.state r)
  [SMTPat (s.regs r)]

val lemma_to_xmm : s:state -> x:xmm -> Lemma
  (ensures s.xmms x == xmms' (state_to_S s).TS.state x)
  [SMTPat (s.xmms x)]


val lemma_to_trace : s:state -> Lemma
  (ensures s.trace == trace' (state_to_S s))
  [SMTPat s.trace]

val lemma_to_memTaint : s:state -> Lemma
  (ensures s.memTaint == up_taint (memTaint' (state_to_S s)) s.mem)
  [SMTPat s.memTaint]

val lemma_to_memTaint2 : s:state -> Lemma
  (ensures down_taint s.memTaint s.mem == memTaint' (state_to_S s))
  [SMTPat s.memTaint]

val lemma_to_eval_operand : s:state -> o:operand -> Lemma
  (ensures eval_operand o s == S.eval_operand o (state_to_S s).TS.state)
  [SMTPat (eval_operand o s)]

val lemma_to_eval_xmm : s:state -> x:xmm -> Lemma
  (ensures eval_xmm x s == S.eval_xmm x (state_to_S s).TS.state)
  [SMTPat (eval_xmm x s)]

val lemma_to_valid_operand : s:state -> o:operand -> Lemma
  (ensures valid_operand o s ==> S.valid_operand o (state_to_S s).TS.state)
  [SMTPat (valid_operand o s)]

val lemma_of_to : s:state -> Lemma
  (ensures s == state_of_S (state_to_S s))
  [SMTPat (state_of_S (state_to_S s))]

val lemma_to_of : s:TS.traceState -> Lemma
  (ensures s == state_to_S (state_of_S s))
  [SMTPat (state_to_S (state_of_S s))]

unfold let op_String_Access (#a:eqtype) (#b:Type) (x:Map.t a b) (y:a) : Tot b = Map.sel x y

val lemma_valid_taint64: (b:X64.Memory_i.buffer64) ->
			 (memTaint:MT.t) ->
			 (mem:X64.Memory_i.mem) ->
			 (i:nat{i < X64.Memory_i.buffer_length b}) ->
			 (t:taint) -> Lemma
  (requires valid_taint_buf64 b memTaint t)
  (ensures (down_taint memTaint mem).[X64.Memory_i.buffer_addr b mem + 8 `op_Multiply` i] == t)

val lemma_valid_taint128: (b:X64.Memory_i.buffer128) ->
			 (memTaint:MT.t) ->
			 (mem:X64.Memory_i.mem) ->
			 (i:nat{i < X64.Memory_i.buffer_length b}) ->
			 (t:taint) -> Lemma
  (requires valid_taint_buf128 b memTaint t)
  (ensures (down_taint memTaint mem).[X64.Memory_i.buffer_addr b mem + 16 `op_Multiply` i] == t)


val modify_trace: (s0:state) -> (b:bool) -> Lemma
  (state_to_S ({s0 with trace=BranchPredicate(b)::s0.trace}) == ({(state_to_S s0) with TS.trace = BranchPredicate(b)::(state_to_S s0).TS.trace}))

val same_memTaint: (b:X64.Memory_i.buffer64) -> 
                   (mem0:X64.Memory_i.mem) ->
		   (mem1:X64.Memory_i.mem) ->
		   (memtaint0:MT.t) ->
		   (memtaint1:MT.t) -> Lemma
  (requires (X64.Memory_i.modifies (X64.Memory_i.loc_buffer b) mem0 mem1 /\ 
    (forall p. Map.sel (down_taint memtaint0 mem0) p == Map.sel (down_taint memtaint1 mem1) p)))
  (ensures memtaint0 == memtaint1)

val same_memTaint128: (b:X64.Memory_i.buffer128) -> 
                   (mem0:X64.Memory_i.mem) ->
		   (mem1:X64.Memory_i.mem) ->
		   (memtaint0:MT.t) ->
		   (memtaint1:MT.t) -> Lemma
  (requires (X64.Memory_i.modifies (X64.Memory_i.loc_buffer b) mem0 mem1 /\ 
    (forall p. Map.sel (down_taint memtaint0 mem0) p == Map.sel (down_taint memtaint1 mem1) p)))
  (ensures memtaint0 == memtaint1)
