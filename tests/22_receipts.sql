-- ============================================================================
-- Recibos: ad.fin_receipt_issue / ad.fin_receipt_get / ad.fin_receipt_cancel,
-- numeracao da filial (prefixo e proximo numero em ad.settings_save) e o
-- recibo ativo em ad.fin_entry_list.
--   Mel = administradora da empresa
--   Ivo = financeiro so leitura
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/22_receipts.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000fb', 'mel.rec@test.local', '{"name": "Mel Recibo"}'),
  ('00000000-0000-0000-0000-0000000000fc', 'ivo.rec@test.local', '{"name": "Ivo Recibo"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000fb","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Mel: emitir, reemitir e cancelar'
do $$
declare
  _r    jsonb;
  _ca   bigint;
  _base jsonb;
  _cat  jsonb;
  _rec  bigint;
  _cx   bigint;
  _pa   bigint;
  _e1   bigint;
  _e2   bigint;
  _e3   bigint;
  _n1   bigint;
  _prof bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Recibo"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  perform ad.fin_setup(_base);
  _cat := ad.fin_catalog(_base);
  _rec := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x where x ->> 'vc_name' = 'Tratamentos');
  _cx  := (select (x ->> 'nr_account')::bigint from jsonb_array_elements(_cat -> 'accounts') x where x ->> 'vc_name' = 'Caixa');
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Recibo", "dt_birth": "1990-01-01",
           "vc_cpf": "529.982.247-25"}'::jsonb) ->> 'nr_patient')::bigint;
  perform ad.branch_update(_base || '{"vc_technical_name": "Dra. Mel", "vc_technical_cro": "1234", "vc_technical_cro_state": "PR"}'::jsonb);

  _e1 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec, 'nr_patient', _pa,
           'vc_description', 'Restauração', 'vl_amount', 250, 'dt_due', '2030-03-04')) ->> 'nr_entry')::bigint;
  _e2 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
           'vc_description', 'Avulso', 'vl_amount', 80, 'dt_due', '2030-03-04')) ->> 'nr_entry')::bigint;
  _e3 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec, 'nr_patient', _pa,
           'vc_description', 'Limpeza', 'vl_amount', 120, 'dt_due', '2030-03-04')) ->> 'nr_entry')::bigint;

  -- so conta a receber paga
  perform pg_temp.expect_error('fin_receipt_issue', _base || jsonb_build_object('nr_entry', _e1), 'FIN_RECEIPT_NOT_PAID');
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e1, 'nr_account', _cx,
            'dt_paid', '2030-03-04', 'it_payment_method', 2));
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e2, 'nr_account', _cx,
            'dt_paid', '2030-03-04'));
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e3, 'nr_account', _cx,
            'dt_paid', '2030-03-05'));

  -- prefixo e proximo numero
  perform pg_temp.expect_error('settings_save', _base || '{"vc_receipt_prefix": "rec #"}'::jsonb, 'SETTINGS_RECEIPT_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"nr_next_receipt": 0}'::jsonb, 'SETTINGS_RECEIPT_INVALID');
  perform ad.settings_save(_base || '{"vc_receipt_prefix": "rec-", "nr_next_receipt": 10}'::jsonb);

  -- emite com o paciente como pagador
  _r := ad.fin_receipt_issue(_base || jsonb_build_object('nr_entry', _e1));
  assert _r -> 'receipt' ->> 'vc_number' = 'REC-000010' and not (_r ->> 'id_existing')::boolean, 'numero com prefixo';
  assert _r -> 'receipt' ->> 'vc_payer_name' = 'Ana Recibo' and _r -> 'receipt' ->> 'vc_payer_document' = '52998224725',
    'pagador = paciente';
  assert (_r -> 'receipt' ->> 'vl_amount')::numeric = 250 and (_r -> 'receipt' ->> 'it_payment_method')::int = 2, 'valor e forma';
  assert _r -> 'issuer' ->> 'vc_technical_name' = 'Dra. Mel', 'emitente';
  _n1 := (_r -> 'receipt' ->> 'nr_receipt')::bigint;
  assert (ad.settings_get(_base) -> 'settings' ->> 'nr_next_receipt')::int = 11, 'proximo 11';

  -- reemitir devolve o mesmo
  _r := ad.fin_receipt_issue(_base || jsonb_build_object('nr_entry', _e1));
  assert (_r ->> 'id_existing')::boolean and (_r -> 'receipt' ->> 'nr_receipt')::bigint = _n1, 'mesmo recibo';
  assert (select count(*) from od.fin_receipt where nr_company = _ca) = 1, 'nao duplicou';

  -- sem paciente: pagador obrigatorio; documento validado
  perform pg_temp.expect_error('fin_receipt_issue', _base || jsonb_build_object('nr_entry', _e2), 'FIN_RECEIPT_PAYER_REQUIRED');
  perform pg_temp.expect_error('fin_receipt_issue', _base || jsonb_build_object('nr_entry', _e2,
            'vc_payer_name', 'Carlos', 'vc_payer_document', '123'), 'FIN_RECEIPT_DOCUMENT_INVALID');
  _r := ad.fin_receipt_issue(_base || jsonb_build_object('nr_entry', _e2, 'vc_payer_name', 'Carlos',
          'vc_payer_document', '11.222.333/0001-81', 'vc_description', 'Clareamento'));
  assert _r -> 'receipt' ->> 'vc_number' = 'REC-000011' and _r -> 'receipt' ->> 'vc_description' = 'Clareamento'
     and _r -> 'receipt' ->> 'vc_payer_document' = '11222333000181', 'pagador informado';

  -- lista mostra o recibo ativo
  assert (select x ->> 'vc_receipt_number' from jsonb_array_elements(ad.fin_entry_list(_base || '{"it_kind": 1,
            "dt_from": "2030-03-01", "dt_to": "2030-03-31"}'::jsonb) -> 'entries') x
           where (x ->> 'nr_entry')::bigint = _e1) = 'REC-000010', 'recibo na lista';

  -- cancelar: motivo obrigatorio; o numero nao volta
  perform pg_temp.expect_error('fin_receipt_cancel', _base || jsonb_build_object('nr_receipt', _n1), 'FIN_RECEIPT_REASON_REQUIRED');
  perform ad.fin_receipt_cancel(_base || jsonb_build_object('nr_receipt', _n1, 'vc_reason', 'Valor errado'));
  perform pg_temp.expect_error('fin_receipt_cancel', _base || jsonb_build_object('nr_receipt', _n1, 'vc_reason', 'x'),
            'FIN_RECEIPT_NOT_FOUND');
  perform pg_temp.expect_error('fin_receipt_get', _base || jsonb_build_object('nr_entry', _e1), 'FIN_RECEIPT_NOT_FOUND');
  assert (ad.fin_receipt_get(_base || jsonb_build_object('nr_receipt', _n1)) -> 'receipt' ->> 'it_status')::int = 90, 'cancelado';
  _r := ad.fin_receipt_issue(_base || jsonb_build_object('nr_entry', _e1));
  assert _r -> 'receipt' ->> 'vc_number' = 'REC-000012', 'novo numero depois do cancelamento';

  -- proximo numero voltado para tras pula os ja usados
  perform ad.settings_save(_base || '{"nr_next_receipt": 10}'::jsonb);
  _r := ad.fin_receipt_issue(_base || jsonb_build_object('nr_entry', _e3));
  assert _r -> 'receipt' ->> 'vc_number' = 'REC-000013', 'pulou os usados, veio ' || (_r -> 'receipt' ->> 'vc_number');

  assert exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'fin_receipt'
                    and e.vc_summary = 'Recibo REC-000010 cancelado'), 'log do cancelamento';

  -- Ivo: financeiro so leitura
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Consulta', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000008', 'id_read', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ivo.rec@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));
  perform set_config('test.nr_entry', _e2::text, false);
  perform set_config('test.nr_receipt', (select nr_receipt from od.fin_receipt where nr_company = _ca and nr_entry = _e2)::text, false);
end $$;

\echo '== Ivo: le, nao emite nem cancela'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000fc","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  assert ad.fin_receipt_get(_base || jsonb_build_object('nr_entry', current_setting('test.nr_entry')::bigint))
           -> 'receipt' ->> 'vc_payer_name' = 'Carlos', 'Ivo le o recibo';
  perform pg_temp.expect_error('fin_receipt_issue', _base || jsonb_build_object('nr_entry', current_setting('test.nr_entry')::bigint),
            'FIN_RECEIPT_FORBIDDEN');
  perform pg_temp.expect_error('fin_receipt_cancel', _base || jsonb_build_object('nr_receipt', current_setting('test.nr_receipt')::bigint,
            'vc_reason', 'x'), 'FIN_RECEIPT_FORBIDDEN');
  assert (select count(*) from od.fin_receipt) = 4, 'RLS: Ivo ve os recibos da filial';
end $$;

reset role;
rollback;
\o
\echo 'OK: 22_receipts'
