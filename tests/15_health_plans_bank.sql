-- ============================================================================
-- Financeiro, fase 3b: convenios (ad.health_plan_save / list), guias
-- (ad.health_guide_save / settle / list) e conciliacao bancaria
-- (ad.fin_bank_import / list / reconcile).
--   Mel = administradora da empresa
--   Oto = usuario sem empresa
-- Datas fixas; roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/15_health_plans_bank.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', 'mel.conv@test.local', '{"name": "Mel Convenio"}'),
  ('00000000-0000-0000-0000-0000000000c3', 'oto.conv@test.local', '{"name": "Oto Convenio"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

create function pg_temp.bal(p_ca bigint, p_acc bigint) returns numeric language sql as $$
  select coalesce(sum((x ->> 'vl_balance')::numeric), 0)
    from jsonb_array_elements(ad.fin_catalog(jsonb_build_object('nr_version', 1, 'nr_company', p_ca, 'nr_branch', 1))
                              -> 'accounts') x
   where (x ->> 'nr_account')::bigint = p_acc
$$;

\echo '== Mel: convenios e guias'
do $$
declare
  _r      jsonb;
  _ca     bigint;
  _base   jsonb;
  _pa     bigint;
  _ana    bigint;
  _p1     bigint;
  _p2     bigint;
  _plan   bigint;
  _g1     bigint;
  _g2     bigint;
  _g3     bigint;
  _entry  bigint;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Convenio"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  perform ad.fin_setup(_base);
  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Paciente Convenio',
           'dt_birth', '1990-01-01')) ->> 'nr_patient')::bigint;
  _ana := (ad.professional_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Dra. Ana'))
           ->> 'nr_professional')::bigint;
  _p1 := (ad.procedure_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Limpeza',
           'vl_current_price', 200)) ->> 'nr_procedure')::bigint;
  _p2 := (ad.procedure_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Restauração',
           'vl_current_price', 300)) ->> 'nr_procedure')::bigint;

  -- convenio
  perform pg_temp.expect_error('health_plan_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X',
            'vc_ans', '12'), 'HEALTH_PLAN_ANS_INVALID');
  perform pg_temp.expect_error('health_plan_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X',
            'prices', jsonb_build_array(jsonb_build_object('nr_procedure', 999, 'vl_price', 10))), 'HEALTH_PLAN_PRICE_INVALID');
  _r := ad.health_plan_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Odonto Plus',
          'vc_ans', '123.456', 'vc_document', '11.222.333/0001-81', 'qt_payment_days', 45, 'nr_account', 2,
          'prices', jsonb_build_array(jsonb_build_object('nr_procedure', _p1, 'vl_price', 80, 'vc_code', '85100099'),
                                      jsonb_build_object('nr_procedure', _p2, 'vl_price', 120))));
  _plan := (_r ->> 'nr_plan')::bigint;
  assert (_r ->> 'qt_prices')::int = 2, '2 precos';
  assert (select vc_ans = '123456' and vc_document = '11222333000181' from od.health_plan
           where nr_company = _ca and nr_plan = _plan), 'ANS e CNPJ so com digitos';
  perform pg_temp.expect_error('health_plan_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'odonto plus'),
            'HEALTH_PLAN_NAME_IN_USE');
  _r := ad.health_plan_list(_base);
  assert (_r -> 'plans' -> 0 -> 'prices' -> 0 ->> 'vc_procedure') = 'Limpeza'
     and (_r -> 'plans' -> 0 -> 'prices' -> 0 ->> 'vl_private')::numeric = 200, 'tabela com o preco particular';

  -- guias
  perform pg_temp.expect_error('health_guide_save', _base || jsonb_build_object('vc_action', 'I', 'nr_plan', _plan,
            'nr_patient', _pa, 'dt_service', '2026-11-03', 'items', '[]'::jsonb), 'HEALTH_GUIDE_ITEMS_REQUIRED');

  _r := ad.health_guide_save(_base || jsonb_build_object('vc_action', 'I', 'nr_plan', _plan, 'nr_patient', _pa,
          'nr_professional', _ana, 'vc_guide_number', 'G-001', 'vc_card_number', '0001',
          'dt_service', '2026-11-03',
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _p1),
                                     jsonb_build_object('nr_procedure', _p2, 'qt_quantity', 2, 'vc_tooth', '16'))));
  _g1 := (_r ->> 'nr_guide')::bigint;
  assert (_r ->> 'vl_total')::numeric = 320, 'total pela tabela: 80 + 2 x 120';
  _r := ad.health_guide_save(_base || jsonb_build_object('vc_action', 'I', 'nr_plan', _plan, 'nr_patient', _pa,
          'dt_service', '2026-11-04', 'items', jsonb_build_array(jsonb_build_object('nr_procedure', _p1, 'vl_unit', 90))));
  _g2 := (_r ->> 'nr_guide')::bigint;
  assert (_r ->> 'vl_total')::numeric = 90, 'valor informado vale sobre a tabela';
  _r := ad.health_guide_save(_base || jsonb_build_object('vc_action', 'I', 'nr_plan', _plan, 'nr_patient', _pa,
          'dt_service', '2026-11-05', 'items', jsonb_build_array(jsonb_build_object('nr_procedure', _p1))));
  _g3 := (_r ->> 'nr_guide')::bigint;
  perform ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'CANCEL', 'nr_guide', _g3));
  perform pg_temp.expect_error('health_guide_save', _base || jsonb_build_object('vc_action', 'U', 'nr_guide', _g3,
            'vc_notes', 'x'), 'HEALTH_GUIDE_LOCKED');

  -- faturar as duas juntas: uma conta a receber de 410
  _r := ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'INVOICE', 'nr_guides', jsonb_build_array(_g1, _g2),
          'dt_invoiced', '2026-11-10'));
  _entry := (_r ->> 'nr_entry')::bigint;
  assert (select vl_amount = 410 and dt_due = '2026-12-25' and nr_account = 2 and it_status = 1 and nr_patient is null
            from od.fin_entry where nr_company = _ca and nr_entry = _entry), 'conta a receber do convenio em 45 dias';
  assert (select vc_name from od.fin_category c join od.fin_entry e using (nr_company, nr_branch, nr_category)
           where e.nr_company = _ca and e.nr_entry = _entry) = 'Convênios', 'categoria Convenios';
  perform pg_temp.expect_error('health_guide_save', _base || jsonb_build_object('vc_action', 'U', 'nr_guide', _g1,
            'vc_notes', 'x'), 'HEALTH_GUIDE_LOCKED');

  -- desfaz o faturamento de uma: a conta cai para 320
  perform ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'UNINVOICE', 'nr_guide', _g2));
  assert (select vl_amount from od.fin_entry where nr_company = _ca and nr_entry = _entry) = 320, 'conta ajustada';
  perform ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'INVOICE', 'nr_guide', _g2,
          'dt_invoiced', '2026-11-10'));

  -- paga a guia 1 com glosa de 40 no item 2: conta 1 baixada com 280 (so ela no faturamento)
  _r := ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_guide', _g1, 'dt_paid', '2026-12-26',
          'denials', jsonb_build_array(jsonb_build_object('nr_item', 2, 'vl_denied', 40))));
  assert (select vl_paid = 280 and vl_denied = 40 and it_status = 3 from od.health_guide
           where nr_company = _ca and nr_guide = _g1), 'paga com glosa';
  assert (select it_status = 2 and vl_paid = 280 and dt_paid = '2026-12-26' from od.fin_entry
           where nr_company = _ca and nr_entry = _entry), 'conta baixada com o pago';
  assert pg_temp.bal(_ca, 2) = 280, 'repasse no banco';
  perform pg_temp.expect_error('health_guide_settle', _base || jsonb_build_object('vc_action', 'UNINVOICE', 'nr_guide', _g1),
            'HEALTH_GUIDE_STATUS_INVALID');

  -- desfaz o pagamento
  perform ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'UNPAY', 'nr_guide', _g1));
  assert (select it_status from od.fin_entry where nr_company = _ca and nr_entry = _entry) = 1, 'conta volta a aberta';
  assert pg_temp.bal(_ca, 2) = 0, 'saldo desfeito';
  -- glosa total: conta cancelada
  perform ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_guide', _g1, 'vl_paid', 0,
          'dt_paid', '2026-12-26'));
  assert (select it_status from od.fin_entry where nr_company = _ca and nr_entry = _entry) = 90, 'glosa total cancela';
  perform ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'UNPAY', 'nr_guide', _g1));
  assert (select it_status from od.fin_entry where nr_company = _ca and nr_entry = _entry) = 1, 'volta de cancelada';
  perform ad.health_guide_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_guide', _g1, 'dt_paid', '2026-12-26'));
  assert (select vl_paid from od.fin_entry where nr_company = _ca and nr_entry = _entry) = 320, 'sem glosa paga o total';

  _r := ad.health_guide_list(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2026-11-30'));
  assert (_r -> 'totals' ->> 'qt_total')::int = 3 and (_r -> 'totals' ->> 'vl_paid')::numeric = 320
     and (_r -> 'totals' ->> 'vl_invoiced')::numeric = 90, 'totais das guias';
  assert exists (select 1 from jsonb_array_elements(_r -> 'guides') x
                  where (x ->> 'nr_guide')::bigint = _g1 and x ->> 'vc_professional' = 'Dra. Ana'
                    and jsonb_array_length(x -> 'items') = 2 and x -> 'items' -> 1 ->> 'vc_tooth' = '16'), 'guia com itens';
  perform pg_temp.expect_error('health_guide_settle', _base || jsonb_build_object('vc_action', 'INVOICE',
            'nr_guides', jsonb_build_array(_g2, _g3)), 'HEALTH_GUIDE_STATUS_INVALID');
end $$;

\echo '== Mel: conciliacao bancaria'
do $$
declare
  _ca    bigint := current_setting('test.nr_company')::bigint;
  _base  jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r     jsonb;
  _rent  bigint;
  _e     bigint;
  _l     record;
  _fee   bigint;
begin
  _rent := (select nr_category from od.fin_category where nr_company = _ca and it_kind = 2 order by nr_category limit 1);
  -- despesa paga no banco em 01/12 e transferencia do caixa para o banco em 02/12
  _e := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _rent,
          'vc_description', 'Aluguel', 'vl_amount', 1500, 'dt_due', '2026-12-01', 'id_paid', true,
          'nr_account', 2, 'dt_paid', '2026-12-01')) ->> 'nr_entry')::bigint;
  perform ad.fin_transfer_save(_base || jsonb_build_object('vc_action', 'I', 'nr_account_from', 1, 'nr_account_to', 2,
            'vl_amount', 500, 'dt_transfer', '2026-12-02'));

  perform pg_temp.expect_error('fin_bank_import', _base || jsonb_build_object('nr_account', 2, 'lines', '[]'::jsonb),
            'FIN_BANK_LINES_INVALID');
  perform pg_temp.expect_error('fin_bank_import', _base || jsonb_build_object('nr_account', 2,
            'lines', jsonb_build_array(jsonb_build_object('vc_fitid', 'X', 'dt_posted', '2026-12-01', 'vl_amount', 0))),
            'FIN_BANK_LINE_INVALID');
  _r := ad.fin_bank_import(_base || jsonb_build_object('nr_account', 2, 'lines', jsonb_build_array(
          jsonb_build_object('vc_fitid', 'F1', 'dt_posted', '2026-12-01', 'vl_amount', -1500, 'vc_memo', 'PAG ALUGUEL'),
          jsonb_build_object('vc_fitid', 'F2', 'dt_posted', '2026-12-03', 'vl_amount', 500, 'vc_memo', 'TED'),
          jsonb_build_object('vc_fitid', 'F3', 'dt_posted', '2026-12-05', 'vl_amount', -12.9, 'vc_memo', 'TARIFA'),
          jsonb_build_object('vc_fitid', 'F4', 'dt_posted', '2026-12-26', 'vl_amount', 320, 'vc_memo', 'REPASSE CONV'))));
  assert (_r ->> 'qt_new')::int = 4 and (_r ->> 'qt_matched')::int = 2, 'aluguel e repasse conciliados sozinhos (mesmo dia)';
  _r := ad.fin_bank_import(_base || jsonb_build_object('nr_account', 2, 'lines', jsonb_build_array(
          jsonb_build_object('vc_fitid', 'F1', 'dt_posted', '2026-12-01', 'vl_amount', -1500))));
  assert (_r ->> 'qt_new')::int = 0 and (_r ->> 'qt_duplicated')::int = 1, 'reimportar nao duplica';

  _r := ad.fin_bank_list(_base || jsonb_build_object('nr_account', 2, 'dt_from', '2026-12-01', 'dt_to', '2026-12-31'));
  assert (_r -> 'totals' ->> 'qt_pending')::int = 2 and (_r -> 'totals' ->> 'qt_matched')::int = 2, 'pendentes e conciliadas';
  select x.* into _l from jsonb_to_recordset(_r -> 'lines') x(nr_line bigint, vc_fitid text, candidates jsonb)
   where x.vc_fitid = 'F2';
  assert (_l.candidates -> 0 ->> 'it_source')::int = 2 and (_l.candidates -> 0 ->> 'qt_days')::int = 1,
    'TED sugere a transferencia de 1 dia antes';
  assert jsonb_array_length(_r -> 'unmatched') = 1 and (_r -> 'unmatched' -> 0 ->> 'vl_value')::numeric = 500,
    'transferencia ainda nao apareceu conciliada';

  -- concilia a TED com a transferencia
  perform pg_temp.expect_error('fin_bank_reconcile', _base || jsonb_build_object('vc_action', 'MATCH',
            'nr_line', _l.nr_line, 'nr_entry', _e), 'FIN_BANK_MATCH_INVALID');
  perform ad.fin_bank_reconcile(_base || jsonb_build_object('vc_action', 'MATCH', 'nr_line', _l.nr_line,
            'nr_transfer', (_l.candidates -> 0 ->> 'nr_ref')::bigint));
  perform pg_temp.expect_error('fin_transfer_save', _base || jsonb_build_object('vc_action', 'CANCEL',
            'nr_transfer', (_l.candidates -> 0 ->> 'nr_ref')::bigint), 'FIN_BANK_RECONCILED');

  -- a tarifa vira despesa direto do extrato
  select x.* into _l from jsonb_to_recordset(_r -> 'lines') x(nr_line bigint, vc_fitid text, candidates jsonb)
   where x.vc_fitid = 'F3';
  _fee := (select nr_category from od.fin_category where nr_company = _ca and it_kind = 2 order by nr_category desc limit 1);
  perform pg_temp.expect_error('fin_bank_reconcile', _base || jsonb_build_object('vc_action', 'CREATE',
            'nr_line', _l.nr_line, 'nr_category', (select nr_category from od.fin_category where nr_company = _ca
                                                    and it_kind = 1 limit 1)), 'FIN_BANK_CATEGORY_INVALID');
  _r := ad.fin_bank_reconcile(_base || jsonb_build_object('vc_action', 'CREATE', 'nr_line', _l.nr_line,
          'nr_category', _fee));
  assert (select it_kind = 2 and vl_paid = 12.9 and dt_paid = '2026-12-05' and nr_account = 2
                 and vc_description = 'TARIFA' from od.fin_entry
           where nr_company = _ca and nr_entry = (_r ->> 'nr_entry')::bigint), 'despesa criada pelo extrato';
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('vc_action', 'UNDO',
            'nr_entry', (_r ->> 'nr_entry')::bigint), 'FIN_BANK_RECONCILED');
  -- desfaz e ignora
  perform ad.fin_bank_reconcile(_base || jsonb_build_object('vc_action', 'UNDO', 'nr_line', _l.nr_line));
  perform ad.fin_bank_reconcile(_base || jsonb_build_object('vc_action', 'IGNORE', 'nr_line', _l.nr_line));
  perform pg_temp.expect_error('fin_bank_reconcile', _base || jsonb_build_object('vc_action', 'IGNORE',
            'nr_line', _l.nr_line), 'FIN_BANK_STATUS_INVALID');

  _r := ad.fin_bank_list(_base || jsonb_build_object('nr_account', 2, 'dt_from', '2026-12-01', 'dt_to', '2026-12-31'));
  assert (_r -> 'totals' ->> 'qt_pending')::int = 0 and (_r -> 'totals' ->> 'qt_ignored')::int = 1
     and (_r -> 'totals' ->> 'vl_bank')::numeric = 320 - 1500 + 500, 'tudo conciliado';
  -- o repasse do convenio esta conciliado: desfazer o pagamento da guia e bloqueado
  perform pg_temp.expect_error('health_guide_settle', _base || jsonb_build_object('vc_action', 'UNPAY', 'nr_guide', 1),
            'FIN_BANK_RECONCILED');
end $$;

-- ----------------------------------------------------------------------------
\echo '== Oto (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('health_plan_list', _base, 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('health_guide_save', _base || jsonb_build_object('vc_action', 'I'), 'HEALTH_GUIDE_FORBIDDEN');
  perform pg_temp.expect_error('fin_bank_import', _base || jsonb_build_object('nr_account', 2), 'FIN_BANK_FORBIDDEN');
  perform pg_temp.expect_error('fin_bank_list', _base || jsonb_build_object('nr_account', 2, 'dt_from', '2026-12-01',
            'dt_to', '2026-12-31'), 'FINANCE_FORBIDDEN');
  assert (select count(*) from od.health_guide) = 0, 'RLS: Oto nao ve guias';
  assert (select count(*) from od.fin_bank_line) = 0, 'RLS: Oto nao ve extrato';
  assert (select count(*) from od.health_plan) = 0, 'RLS: Oto nao ve convenios';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.fin_bank_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou fin_bank_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 15_health_plans_bank'
