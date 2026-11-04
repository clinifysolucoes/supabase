-- ============================================================================
-- Financeiro, fase 3a: taxas (ad.fin_rate_save), recebiveis na baixa em
-- cartao/boleto/cheque (od.fn_fin_receivable_make), confirmacao
-- (ad.fin_receivable_settle), lista (ad.fin_receivable_list) e exportacao
-- Receita Saude (ad.fin_health_export).
--   Mel = administradora da empresa
--   Oto = usuario sem empresa
-- Datas de pagamento fixas; roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/14_finance_receivables.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b1', 'mel.rec@test.local', '{"name": "Mel Recebiveis"}'),
  ('00000000-0000-0000-0000-0000000000b3', 'oto.rec@test.local', '{"name": "Oto Recebiveis"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
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

\echo '== Mel: taxas, recebiveis e exportacao'
do $$
declare
  _r      jsonb;
  _ca     bigint;
  _base   jsonb;
  _pa     bigint;
  _pb     bigint;
  _ana    bigint;
  _rec    bigint;
  _e1     bigint;
  _e2     bigint;
  _clear  bigint;
  _rv     record;
  _r1     bigint;
  _a1     bigint;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Recebiveis", "vc_cnpj": "11.222.333/0001-81"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  perform ad.fin_setup(_base);
  _rec := (select nr_category from od.fin_category where nr_company = _ca and vc_name = 'Tratamentos');
  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Paciente Cartao',
           'dt_birth', '1990-01-01', 'vc_cpf', '529.982.247-25')) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Paciente Sem CPF',
           'dt_birth', '1991-01-01')) ->> 'nr_patient')::bigint;
  _ana := (ad.professional_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Dra. Ana'))
           ->> 'nr_professional')::bigint;

  -- taxas
  perform pg_temp.expect_error('fin_rate_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Pix',
            'it_payment_method', 2, 'nr_account', 2), 'FIN_RATE_METHOD_INVALID');
  perform pg_temp.expect_error('fin_rate_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X',
            'it_payment_method', 3, 'nr_account', 2, 'pc_fee', 120), 'FIN_RATE_FEE_INVALID');
  perform pg_temp.expect_error('fin_rate_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X',
            'it_payment_method', 3, 'nr_account', 2, 'qt_installments_min', 3, 'qt_installments_max', 2),
            'FIN_RATE_INSTALLMENTS_INVALID');
  perform pg_temp.expect_error('fin_rate_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X',
            'it_payment_method', 3, 'nr_account', 99), 'FIN_RATE_ACCOUNT_INVALID');
  perform ad.fin_rate_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Crédito à vista',
            'it_payment_method', 3, 'pc_fee', 3, 'qt_days', 30, 'nr_account', 2));
  perform ad.fin_rate_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Crédito 2 a 6x',
            'it_payment_method', 3, 'qt_installments_min', 2, 'qt_installments_max', 6, 'pc_fee', 4,
            'qt_days', 30, 'nr_account', 2));
  perform ad.fin_rate_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Débito',
            'it_payment_method', 4, 'pc_fee', 1.5, 'qt_days', 1, 'nr_account', 2,
            'qt_installments_max', 5));
  perform pg_temp.expect_error('fin_rate_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'débito',
            'it_payment_method', 4, 'nr_account', 2), 'FIN_RATE_NAME_IN_USE');
  _r := ad.fin_catalog(_base);
  assert jsonb_array_length(_r -> 'rates') = 3, 'catalogo com as taxas';
  assert (select qt_installments_max from od.fin_card_rate where nr_company = _ca and vc_name = 'Débito') = 1,
    'debito nao parcela';

  -- conta a receber de 300 paga no credito em 3x
  _e1 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
           'vc_description', 'Clareamento', 'vl_amount', 300, 'dt_due', '2026-11-10', 'nr_patient', _pa,
           'nr_professional', _ana)) ->> 'nr_entry')::bigint;
  _r := ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e1, 'nr_account', 1,
          'dt_paid', '2026-11-10', 'it_payment_method', 3, 'qt_card_installments', 3, 'vc_reference', 'NSU 123'));
  assert (_r ->> 'qt_receivables')::int = 3, '3 recebiveis';
  select nr_account into _clear from od.fin_account where nr_company = _ca and it_type = 4;
  assert _clear is not null and (select vc_name from od.fin_account where nr_company = _ca and nr_account = _clear)
         = 'Recebíveis', 'conta de passagem criada';
  assert (select nr_account from od.fin_entry where nr_company = _ca and nr_entry = _e1) = _clear,
    'pagamento vai para Recebiveis';
  assert pg_temp.bal(_ca, _clear) = 300 and pg_temp.bal(_ca, 1) = 0, 'saldo na conta de passagem';
  select * into _rv from od.fin_receivable where nr_company = _ca and nr_entry = _e1 and nr_installment = 3;
  assert _rv.vl_gross = 100 and _rv.vl_fee = 4 and _rv.vl_net = 96 and _rv.dt_expected = '2026-12-10'::date + 60
     and _rv.nr_account = 2 and _rv.vc_reference = 'NSU 123'
     and _rv.nr_rate = (select nr_rate from od.fin_card_rate where nr_company = _ca and vc_name = 'Crédito 2 a 6x'),
    '3a parcela: 4% e +60 dias, taxa da faixa 2 a 6x';

  _r := ad.fin_receivable_list(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2027-03-31',
          'vc_status', 'pending'));
  assert (_r -> 'totals' ->> 'vl_gross')::numeric = 300 and (_r -> 'totals' ->> 'vl_fee')::numeric = 12
     and (_r -> 'totals' ->> 'vl_net')::numeric = 288, 'totais';
  assert (_r -> 'receivables' -> 0 ->> 'vc_patient') = 'Paciente Cartao'
     and (_r -> 'receivables' -> 0 ->> 'vc_rate') = 'Crédito 2 a 6x', 'paciente e taxa na lista';
  perform pg_temp.expect_error('fin_receivable_list', _base || jsonb_build_object('dt_from', '2026-01-01',
            'dt_to', '2027-12-31'), 'FIN_LIST_FILTER_INVALID');

  -- desfazer o pagamento antes de confirmar: cancela os recebiveis
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'UNDO', 'nr_entry', _e1));
  assert (select count(*) from od.fin_receivable where nr_company = _ca and nr_entry = _e1 and it_status = 90) = 3,
    'recebiveis cancelados no desfazer';
  -- paga de novo, a vista: taxa 3%
  _r := ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e1, 'nr_account', 1,
          'dt_paid', '2026-11-10', 'it_payment_method', 3));
  select * into _rv from od.fin_receivable where nr_company = _ca and nr_entry = _e1 and it_status = 1;
  assert _rv.vl_gross = 300 and _rv.vl_fee = 9 and _rv.dt_expected = '2026-12-10', 'credito a vista 3% em 30 dias';
  _r1 := _rv.nr_receivable;

  -- confirmar: caiu 290 (taxa real 10)
  perform pg_temp.expect_error('fin_receivable_settle', _base || jsonb_build_object('vc_action', 'CONFIRM',
            'nr_receivable', _r1, 'vl_received', 301), 'FIN_RECEIVABLE_VALUE_INVALID');
  perform pg_temp.expect_error('fin_receivable_settle', _base || jsonb_build_object('vc_action', 'CONFIRM',
            'nr_receivable', _r1, 'nr_account', _clear), 'FIN_RECEIVABLE_ACCOUNT_INVALID');
  _r := ad.fin_receivable_settle(_base || jsonb_build_object('vc_action', 'CONFIRM', 'nr_receivable', _r1,
          'vl_received', 290, 'dt_received', '2026-12-11'));
  assert (_r ->> 'vl_fee')::numeric = 10, 'taxa real';
  assert pg_temp.bal(_ca, 2) = 290 and pg_temp.bal(_ca, _clear) = 0, 'banco recebeu, passagem zerou';
  assert exists (select 1 from od.fin_entry e join od.fin_category c using (nr_company, nr_branch, nr_category)
                  where e.nr_company = _ca and c.vc_name = 'Taxas de recebimento' and c.it_cost_type = 2
                    and e.vl_paid = 10 and e.it_status = 2 and e.dt_paid = '2026-12-11'), 'despesa da taxa';
  perform pg_temp.expect_error('fin_receivable_settle', _base || jsonb_build_object('vc_action', 'CONFIRM',
            'nr_receivable', _r1), 'FIN_RECEIVABLE_STATUS_INVALID');
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('vc_action', 'UNDO', 'nr_entry', _e1),
            'FIN_RECEIVABLE_CONFIRMED');
  -- desfaz a confirmacao
  perform ad.fin_receivable_settle(_base || jsonb_build_object('vc_action', 'UNDO', 'nr_receivable', _r1));
  assert pg_temp.bal(_ca, 2) = 0 and pg_temp.bal(_ca, _clear) = 300, 'confirmacao desfeita';
  assert (select e.it_status from od.fin_entry e join od.fin_category c using (nr_company, nr_branch, nr_category)
           where e.nr_company = _ca and c.vc_name = 'Taxas de recebimento') = 90, 'taxa cancelada';
  -- confirma pelo liquido previsto
  perform ad.fin_receivable_settle(_base || jsonb_build_object('vc_action', 'CONFIRM', 'nr_receivable', _r1));
  assert pg_temp.bal(_ca, 2) = 291, 'liquido previsto';

  -- Pix nao tem taxa: fica na conta escolhida
  _e2 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
           'vc_description', 'Consulta', 'vl_amount', 150, 'dt_due', '2026-11-12', 'nr_patient', _pb)) ->> 'nr_entry')::bigint;
  _r := ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e2, 'nr_account', 1,
          'dt_paid', '2026-11-12', 'it_payment_method', 2));
  assert (_r ->> 'qt_receivables')::int = 0 and pg_temp.bal(_ca, 1) = 150, 'pix sem recebivel';

  -- debito com caixa aberto: vai para Recebiveis, fora do caixa
  perform ad.fin_cash_open(_base || jsonb_build_object('nr_account', 1));
  _e2 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
           'vc_description', 'Limpeza', 'vl_amount', 200, 'dt_due', '2026-11-13', 'nr_patient', _pa,
           'id_paid', true, 'nr_account', 1, 'dt_paid', '2026-11-13', 'it_payment_method', 4)) ->> 'nr_entry')::bigint;
  select * into _rv from od.fin_receivable where nr_company = _ca and nr_entry = _e2;
  assert _rv.vl_fee = 3 and _rv.dt_expected = '2026-11-14', 'debito 1,5% em 1 dia (lancamento ja pago)';
  assert (select nr_account = _clear and nr_cash_session is null from od.fin_entry
           where nr_company = _ca and nr_entry = _e2), 'cartao nao entra no caixa da gaveta';

  -- fechamento da consulta no credito 2x
  _a1 := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
           'nr_professional', _ana, 'dh_start', '2026-11-03T09:00:00-03:00', 'dh_end', '2026-11-03T10:00:00-03:00'))
           ->> 'nr_appointment')::bigint;
  perform ad.appointment_checkout(_base || jsonb_build_object('nr_appointment', _a1, 'vl_amount', 400,
            'id_paid', true, 'nr_account', 1, 'it_payment_method', 3, 'qt_card_installments', 2,
            'id_commission', false));
  assert (select count(*) from od.fin_receivable r join od.fin_entry e using (nr_company, nr_branch, nr_entry)
           where r.nr_company = _ca and e.nr_appointment = _a1 and r.it_status = 1) = 2,
    'fechamento no credito 2x gera 2 recebiveis';

  -- Receita Saude
  _r := ad.fin_health_export(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2026-11-30'));
  -- o fechamento recebe a 1a parcela hoje: entra so se hoje cair em novembro/2026
  assert (_r ->> 'qt_rows')::int = 3 + (select count(*)::int from ad.branch b where b.nr_company = _ca and b.nr_branch = 1
           and (now() at time zone b.vc_timezone)::date between '2026-11-01' and '2026-11-30')
     and (_r ->> 'qt_missing_cpf')::int = 1, 'pagamentos e sem CPF';
  assert (_r ->> 'vc_company_document') = '11222333000181', 'CNPJ da empresa';
  assert exists (select 1 from jsonb_array_elements(_r -> 'rows') x
                  where x ->> 'vc_cpf' = '52998224725' and x ->> 'vc_professional' = 'Dra. Ana'
                    and (x ->> 'vl_paid')::numeric = 300), 'linha com CPF e profissional';
  perform pg_temp.expect_error('fin_health_export', _base || jsonb_build_object('dt_from', '2026-01-01',
            'dt_to', '2027-02-01'), 'FIN_LIST_FILTER_INVALID');
  assert exists (select 1 from ad.event_log where nr_company = _ca and vc_entity = 'fin_health_export'
                    and vc_summary not like '%Paciente%'), 'log da exportacao sem dados pessoais';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Oto (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b3","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('fin_receivable_list', _base || jsonb_build_object('dt_from', '2026-11-01',
            'dt_to', '2026-11-30'), 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('fin_health_export', _base || jsonb_build_object('dt_from', '2026-11-01',
            'dt_to', '2026-11-30'), 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('fin_receivable_settle', _base || jsonb_build_object('vc_action', 'CONFIRM',
            'nr_receivable', 1), 'FIN_RECEIVABLE_FORBIDDEN');
  perform pg_temp.expect_error('fin_rate_save', _base || jsonb_build_object('vc_action', 'I'), 'FIN_RATE_FORBIDDEN');
  assert (select count(*) from od.fin_receivable) = 0, 'RLS: Oto nao ve recebiveis';
  assert (select count(*) from od.fin_card_rate) = 0, 'RLS: Oto nao ve taxas';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.fin_receivable_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou fin_receivable_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 14_finance_receivables'
