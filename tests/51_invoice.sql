-- ============================================================================
-- Nota fiscal de servico (NFS-e): ad.invoice_settings_get/save, invoice_save,
-- invoice_issue_check, invoice_result (service_role), invoice_list e
-- od.fn_invoice_missing. Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/51_invoice.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f7', 'nina.nf@test.local', '{"name": "Nina Nota"}'),
  ('00000000-0000-0000-0000-0000000000f8', 'olavo.nf@test.local', '{"name": "Olavo Outro"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f7","role":"authenticated"}', true);
set local role authenticated;

\echo '== Nina: configuracao e pendencias'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _r    jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Nota", "vc_cnpj": "11.222.333/0001-81"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);

  _r := ad.invoice_settings_get(_base);
  assert not (_r -> 'settings' ->> 'id_enabled')::boolean and _r -> 'settings' ->> 'vc_service_code' = '4.12'
     and (_r -> 'settings' ->> 'pc_iss')::numeric = 2 and not (_r -> 'settings' ->> 'id_saved')::boolean, 'padroes: ' || _r::text;
  assert _r -> 'missing' ? 'city_registration' and _r -> 'missing' ? 'address' and _r -> 'missing' ? 'settings', 'pendencias';

  perform pg_temp.expect_error('invoice_settings_save', _base || '{"vc_city_ibge": "123"}'::jsonb, 'INVOICE_IBGE_INVALID');
  perform pg_temp.expect_error('invoice_settings_save', _base || '{"pc_iss": 6}'::jsonb, 'INVOICE_VALUE_INVALID');
  perform pg_temp.expect_error('invoice_settings_save', _base || '{"vc_tpl_description": " "}'::jsonb, 'INVOICE_TEMPLATE_INVALID');
  _r := ad.invoice_settings_save(_base || '{"id_enabled": true, "pc_iss": 3.5, "vc_cnae": "8630-5/04"}'::jsonb);
  assert (_r ->> 'id_enabled')::boolean and _r -> 'missing' ? 'city_ibge' and not (_r -> 'missing' ? 'settings'), 'salva: ' || _r::text;
  assert (select vc_cnae from od.invoice_setting where nr_company = _ca) = '8630504', 'cnae so digitos';
end $$;

-- prestador completo (dados da clinica)
reset role;
update ad.branch set vc_cnpj = '11222333000181', vc_city_registration = '123456', it_tax_regime = 20, vc_zip_code = '80000000', vc_address = 'Rua A',
       vc_address_number = '10', vc_district = 'Centro', vc_city = 'Curitiba', vc_state = 'PR'
 where nr_company = current_setting('test.c')::bigint and nr_branch = 1;
set local role authenticated;

\echo '== Nina: rascunhos'
do $$
declare
  _ca   bigint := current_setting('test.c')::bigint;
  _base jsonb;
  _pa   bigint;
  _pm   bigint;
  _rec  bigint;
  _e    bigint;
  _n    bigint;
  _i    od.invoice;
  _r    jsonb;
begin
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Nota", "dt_birth": "1980-03-03",
           "vc_cpf": "52998224725", "vc_mobile": "41999990002", "vc_email": "Ana@Nota.local"}'::jsonb) ->> 'nr_patient')::bigint;
  -- menor com responsavel: a nota sai no nome do responsavel
  _pm := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Beto Menor',
           'dt_birth', (current_date - interval '10 years')::date, 'vc_cpf', '11144477735', 'vc_mobile', '41999990003',
           'vc_guardian_name', 'Carla Mae', 'vc_guardian_cpf', '390.533.447-05')) ->> 'nr_patient')::bigint;
  perform set_config('test.pa', _pa::text, false);

  perform ad.fin_setup(_base);
  _rec := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(ad.fin_catalog(_base) -> 'categories') x
            where x ->> 'vc_name' = 'Tratamentos');
  _e := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec, 'nr_patient', _pa,
          'vc_description', 'Restauração', 'vl_amount', 350, 'dt_due', '2026-11-10')) ->> 'nr_entry')::bigint;

  perform pg_temp.expect_error('invoice_save', _base || '{"vc_action": "I", "nr_patient": 999}'::jsonb, 'INVOICE_PATIENT_INVALID');
  perform pg_temp.expect_error('invoice_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pm, 'nr_entry', _e),
                               'INVOICE_ENTRY_INVALID');
  _n := (ad.invoice_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_entry', _e)) ->> 'nr_invoice')::bigint;
  select * into _i from od.invoice where nr_company = _ca and nr_invoice = _n;
  assert _i.it_status = 1 and _i.vl_service = 350 and _i.pc_iss = 3.5 and _i.vl_iss = 12.25
     and _i.vc_taker_name = 'Ana Nota' and _i.vc_taker_document = '52998224725' and _i.vc_taker_email = 'ana@nota.local'
     and _i.vc_description = 'Serviços odontológicos prestados a Ana Nota.', 'rascunho: ' || row_to_json(_i)::text;
  perform pg_temp.expect_error('invoice_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_entry', _e),
                               'INVOICE_ENTRY_EXISTS');

  _r := ad.invoice_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pm, 'vl_service', 200));
  assert (select vc_taker_name || '|' || vc_taker_document from od.invoice where nr_company = _ca and nr_invoice = 2)
         = 'Carla Mae|39053344705', 'responsavel do menor';
  perform pg_temp.expect_error('invoice_save', _base || '{"vc_action": "U", "nr_invoice": 2, "vc_taker_document": "123"}'::jsonb,
                               'INVOICE_TAKER_INVALID');
  perform pg_temp.expect_error('invoice_save', _base || '{"vc_action": "U", "nr_invoice": 2, "vl_service": 0}'::jsonb,
                               'INVOICE_VALUE_INVALID');
  -- descarta o rascunho do menor
  _r := ad.invoice_save(_base || '{"vc_action": "D", "nr_invoice": 2}'::jsonb);
  assert (_r ->> 'it_status')::int = 90, 'descartado';
  perform pg_temp.expect_error('invoice_save', _base || '{"vc_action": "U", "nr_invoice": 2, "vl_service": 10}'::jsonb,
                               'INVOICE_LOCKED');

  -- emissao: falta o IBGE
  perform pg_temp.expect_error('invoice_issue_check', _base || '{"vc_action": "ISSUE", "nr_invoice": 1}'::jsonb,
                               'INVOICE_SETUP_INCOMPLETE');
  perform ad.invoice_settings_save(_base || '{"vc_city_ibge": "4106902"}'::jsonb);
  perform pg_temp.expect_error('invoice_issue_check', _base || '{"vc_action": "CANCEL", "nr_invoice": 1}'::jsonb,
                               'INVOICE_STATUS_INVALID');
  _r := ad.invoice_issue_check(_base || '{"vc_action": "ISSUE", "nr_invoice": 1}'::jsonb);
  assert _r -> 'provider' ->> 'cnpj' = '11222333000181' and _r -> 'provider' ->> 'city_ibge' = '4106902'
     and _r -> 'taker' ->> 'document' = '52998224725' and (_r -> 'service' ->> 'vl_iss')::numeric = 12.25
     and _r -> 'service' ->> 'service_code' = '4.12' and _r ->> 'ref' like 'clinify-%-1-1', 'payload: ' || _r::text;
  assert (select it_status from od.invoice where nr_company = _ca and nr_invoice = 1) = 2, 'processando';
  perform pg_temp.expect_error('invoice_issue_check', _base || '{"vc_action": "ISSUE", "nr_invoice": 1}'::jsonb,
                               'INVOICE_STATUS_INVALID');
  perform pg_temp.expect_error('invoice_save', _base || '{"vc_action": "U", "nr_invoice": 1, "vl_service": 10}'::jsonb,
                               'INVOICE_LOCKED');
  -- o app nao grava resultado
  perform pg_temp.expect_error('invoice_result', _base || '{"vc_action": "ISSUE", "nr_invoice": 1, "id_ok": true}'::jsonb,
                               'permission denied');
end $$;

reset role;
\echo '== service_role: erro, reenvio, emitida e cancelada'
set local role service_role;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1,
                                    'nr_invoice', 1);
begin
  perform pg_temp.expect_error('invoice_result', _base || '{"vc_action": "ISSUE"}'::jsonb, 'INVOICE_VALUE_INVALID');
  perform pg_temp.expect_error('invoice_result', _base || '{"vc_action": "ISSUE", "id_ok": true}'::jsonb, 'INVOICE_VALUE_INVALID');
  perform pg_temp.expect_error('invoice_result', _base || '{"vc_action": "CANCEL", "id_ok": true}'::jsonb, 'INVOICE_NOT_FOUND');
  assert (ad.invoice_result(_base || '{"vc_action": "ISSUE", "id_ok": false, "vc_error": "INVOICE_NOT_CONFIGURED"}'::jsonb)
          ->> 'it_status')::int = 8, 'erro';
end $$;
reset role;
set local role authenticated;
select ad.invoice_issue_check(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint,
         'nr_branch', 1, 'nr_invoice', 1, 'vc_action', 'ISSUE'));
reset role;
set local role service_role;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1,
                                    'nr_invoice', 1);
begin
  assert (ad.invoice_result(_base || '{"vc_action": "ISSUE", "id_ok": true, "vc_number": "2026/123", "vc_verification": "AB12",
          "vc_pdf_url": "https://emissor.local/n/123.pdf", "vc_provider_ref": "ref-1"}'::jsonb) ->> 'it_status')::int = 3, 'emitida';
end $$;
reset role;
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  perform pg_temp.expect_error('invoice_issue_check', _base || '{"vc_action": "CANCEL", "nr_invoice": 1, "vc_cancel_reason": "curto"}'::jsonb,
                               'INVOICE_CANCEL_REASON_REQUIRED');
  _r := ad.invoice_issue_check(_base || '{"vc_action": "CANCEL", "nr_invoice": 1, "vc_cancel_reason": "Valor lançado errado na nota"}'::jsonb);
  assert _r ->> 'vc_provider_ref' = 'ref-1' and _r ->> 'vc_cancel_reason' = 'Valor lançado errado na nota', 'cancelamento';

  _r := ad.invoice_list(_base);
  assert jsonb_array_length(_r -> 'invoices') = 1 and (_r -> 'totals' ->> 'qt_issued')::int = 1
     and (_r -> 'totals' ->> 'vl_issued')::numeric = 350 and (_r ->> 'id_enabled')::boolean
     and jsonb_array_length(_r -> 'missing') = 0, 'lista: ' || _r::text;
  assert _r -> 'invoices' -> 0 ->> 'vc_number' = '2026/123' and _r -> 'invoices' -> 0 ->> 'vc_patient' = 'Ana Nota', 'linha';
  assert jsonb_array_length(ad.invoice_list(_base || '{"it_status": 90}'::jsonb) -> 'invoices') = 1, 'descartadas';
  assert jsonb_array_length(ad.invoice_list(_base || '{"vc_search": "2026/123"}'::jsonb) -> 'invoices') = 1, 'busca numero';
  perform pg_temp.expect_error('invoice_list', _base || '{"dt_start": "x"}'::jsonb, 'INVOICE_VALUE_INVALID');
end $$;
reset role;
set local role service_role;
select ad.invoice_result(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1,
         'nr_invoice', 1, 'vc_action', 'CANCEL', 'id_ok', true, 'vc_cancel_reason', 'Valor lançado errado na nota'));
reset role;
do $$
begin
  assert (select it_status = 90 and dh_cancelled is not null and vc_number = '2026/123' from od.invoice
           where nr_company = current_setting('test.c')::bigint and nr_invoice = 1), 'cancelada';
end $$;

\echo '== Olavo (outra empresa) nao ve nem emite'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('invoice_list', _base, 'INVOICE_FORBIDDEN');
  perform pg_temp.expect_error('invoice_settings_get', _base, 'INVOICE_FORBIDDEN');
  perform pg_temp.expect_error('invoice_issue_check', _base || '{"vc_action": "ISSUE", "nr_invoice": 1}'::jsonb, 'INVOICE_FORBIDDEN');
  assert (select count(*) from od.invoice) = 0 and (select count(*) from od.invoice_setting) = 0, 'RLS esconde';
end $$;

rollback;
\o
\echo 'OK: 51_invoice'
