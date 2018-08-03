module X64.Vale.InsLemmas_i

open X64.Machine_s
open X64.Vale.State_i
open X64.Vale.Decls_i

val lemma_valid_taint64_operand (m:maddr) (t:taint) (s:va_state) : Lemma
  (requires valid_operand (TMem m t) s)
  (ensures taint_at s.memTaint (eval_maddr m s) == t)
  [SMTPat (eval_maddr m s); SMTPat (TMem m t)]

