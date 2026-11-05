-- ============================================================================
-- Financeiro, fase 4: contas recorrentes (ad.fin_recurrence_save / list e a
-- geracao em od.fn_fin_recurrence_fill), filtros de fin_entry_list
-- (competencia, so parceladas), dados bancarios da conta, dados do cartao e do
-- cheque nos recebiveis, Receita Saude com marcacao do exportado, consultas
-- sem fechamento (ad.appointment_pending_checkout) e anexos
-- (ad.fin_attachment_save / list).
--   Mel = administradora da empresa
--   Oto = usuario sem empresa
-- A recorrencia usa a data de hoje: as contas sao relativas a ela. Roda numa
-- unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/16_finance_phase4.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'mel.f4@test.local', '{"name": "Mel Fase4"}'),
  ('00000000-0000-0000-0000-0000000000d3', 'oto.f4@test.local', '{"name": "Oto Fase4"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Mel: contas recorrentes'
do $$
declare
  _r      jsonb;
  _ca     bigint;
  _base   jsonb;
  _rent   bigint;
  _rec    bigint;
  _nr     bigint;
  _today  date;
  _m0     date;
  _first  bigint;
  _paid   numeric;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Fase 4"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  perform ad.fin_setup(_base);
  -- "hoje" no fuso da filial, como as RPCs
  select (now() at time zone b.vc_timezone)::date into _today from ad.branch b where b.nr_company = _ca and b.nr_branch = 1;
  _m0 := date_trunc('month', _today)::date;
  _rent := (select nr_category from od.fin_category where nr_company = _ca and vc_name = 'Outras despesas');
  _rec  := (select nr_category from od.fin_category where nr_company = _ca and vc_name = 'Tratamentos');

  perform pg_temp.expect_error('fin_recurrence_save', _base || jsonb_build_object('vc_action', 'X'),
            'FIN_RECURRENCE_ACTION_INVALID');
  perform pg_temp.expect_error('fin_recurrence_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 2,
            'nr_category', _rec, 'vc_description', 'Aluguel', 'vl_amount', 100, 'dt_start', _m0),
            'FIN_ENTRY_CATEGORY_INVALID');
  perform pg_temp.expect_error('fin_recurrence_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 2,
            'nr_category', _rent, 'vc_description', 'Aluguel', 'vl_amount', 100, 'dt_start', _m0, 'it_day', 0),
            'FIN_RECURRENCE_DAY_INVALID');
  perform pg_temp.expect_error('fin_recurrence_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 2,
            'nr_category', _rent, 'vc_description', 'Aluguel', 'vl_amount', 100, 'dt_start', _m0,
            'dt_end', _m0 - 1), 'FIN_RECURRENCE_PERIOD_INVALID');

  -- todo dia 31, sem data final: mes atual + 12 meses
  _r := ad.fin_recurrence_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _rent,
          'vc_description', 'Aluguel clínica', 'vl_amount', 100, 'dt_start', _m0, 'it_day', 31, 'nr_account', 2));
  _nr := (_r ->> 'nr_recurrence')::bigint;
  assert (_r ->> 'qt_created')::int = 13, 'gera 13 meses: ' || (_r ->> 'qt_created');
  assert (select count(*) from od.fin_entry where nr_company = _ca and nr_recurrence = _nr
             and id_recurring and it_status = 1) = 13, '13 lancamentos em aberto';
  assert (select bool_and(dt_due = (date_trunc('month', dt_due) + interval '1 month - 1 day')::date)
            from od.fin_entry where nr_company = _ca and nr_recurrence = _nr), 'dia 31 vira o ultimo dia do mes';
  -- chamar de novo nao duplica
  perform ad.fin_recurrence_list(_base);
  assert (select count(*) from od.fin_entry where nr_company = _ca and nr_recurrence = _nr) = 13, 'nao duplica';

  _r := ad.fin_recurrence_list(_base || jsonb_build_object('it_kind', 2));
  assert jsonb_array_length(_r -> 'recurrences') = 1, 'lista a regra';
  assert (_r -> 'recurrences' -> 0 ->> 'qt_open')::int = 13 and (_r -> 'recurrences' -> 0 ->> 'vc_category') = 'Outras despesas',
    'abertos e categoria';

  -- consultar 2 anos a frente gera ate la
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', (_m0 + interval '13 months')::date,
          'dt_to', (_m0 + interval '25 months' - interval '1 day')::date));
  assert (select count(*) from od.fin_entry where nr_company = _ca and nr_recurrence = _nr) = 25, 'gera ate o fim do periodo';
  assert (_r -> 'entries' -> 0 ->> 'nr_recurrence')::bigint = _nr, 'lista traz a regra de origem';

  -- paga o primeiro e altera o valor: o pago fica, os futuros em aberto mudam
  select nr_entry into _first from od.fin_entry where nr_company = _ca and nr_recurrence = _nr order by dt_due limit 1;
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _first, 'nr_account', 2));
  _r := ad.fin_recurrence_save(_base || jsonb_build_object('vc_action', 'U', 'nr_recurrence', _nr, 'vl_amount', 150,
          'it_day', 10));
  assert (_r ->> 'qt_changed')::int = (select count(*) from od.fin_entry where nr_company = _ca and nr_recurrence = _nr
                                          and it_status = 1 and dt_due >= _today), 'futuros em aberto alterados';
  select vl_paid into _paid from od.fin_entry where nr_company = _ca and nr_entry = _first;
  assert _paid = 100, 'pago nao muda';
  assert not exists (select 1 from od.fin_entry where nr_company = _ca and nr_recurrence = _nr and it_status = 1
                       and dt_due >= _today and (vl_amount <> 150 or extract(day from dt_due) <> 10)),
    'valor e dia novos nos futuros';

  -- data final: cancela o que passou dela
  perform ad.fin_recurrence_save(_base || jsonb_build_object('vc_action', 'U', 'nr_recurrence', _nr,
            'dt_end', (_m0 + interval '3 months')::date));
  assert not exists (select 1 from od.fin_entry where nr_company = _ca and nr_recurrence = _nr and it_status = 1
                       and dt_due > (_m0 + interval '3 months')::date), 'depois da data final cancelados';

  -- encerra
  _r := ad.fin_recurrence_save(_base || jsonb_build_object('vc_action', 'CANCEL', 'nr_recurrence', _nr));
  assert not exists (select 1 from od.fin_entry where nr_company = _ca and nr_recurrence = _nr and it_status = 1
                       and dt_due >= _today), 'futuros cancelados';
  assert (select it_status from od.fin_entry where nr_company = _ca and nr_entry = _first) = 2, 'pago continua pago';
  perform pg_temp.expect_error('fin_recurrence_save', _base || jsonb_build_object('vc_action', 'U',
            'nr_recurrence', _nr, 'vl_amount', 1), 'FIN_RECURRENCE_CANCELLED');
  assert jsonb_array_length(ad.fin_recurrence_list(_base) -> 'recurrences') = 0, 'encerrada sai da lista';
  assert jsonb_array_length(ad.fin_recurrence_list(_base || '{"id_inactive": true}'::jsonb) -> 'recurrences') = 1,
    'encerrada com id_inactive';
end $$;

\echo '== Mel: filtros, banco, cartao, Receita Saude, sem fechamento, anexos'
do $$
declare
  _r      jsonb;
  _ca     bigint := current_setting('test.nr_company')::bigint;
  _base   jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _rent   bigint;
  _rec    bigint;
  _pa     bigint;
  _ana    bigint;
  _e1     bigint;
  _e2     bigint;
  _ap     bigint;
  _att    bigint;
begin
  _rent := (select nr_category from od.fin_category where nr_company = _ca and vc_name = 'Outras despesas');
  _rec  := (select nr_category from od.fin_category where nr_company = _ca and vc_name = 'Tratamentos');
  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Paciente F4',
           'dt_birth', '1990-01-01', 'vc_cpf', '529.982.247-25')) ->> 'nr_patient')::bigint;
  _ana := (ad.professional_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Dra. Ana'))
           ->> 'nr_professional')::bigint;

  -- competencia diferente do vencimento
  _e1 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _rent,
           'vc_description', 'Conta de luz', 'vl_amount', 80, 'dt_due', '2030-02-10',
           'dt_competence', '2030-01-31')) ->> 'nr_entry')::bigint;
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', '2030-01-01', 'dt_to', '2030-01-31',
          'vc_date', 'competence', 'vc_search', 'luz'));
  assert jsonb_array_length(_r -> 'entries') = 1, 'achou pela competencia';
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', '2030-01-01', 'dt_to', '2030-01-31',
          'vc_search', 'luz'));
  assert jsonb_array_length(_r -> 'entries') = 0, 'pelo vencimento nao esta em janeiro';
  perform pg_temp.expect_error('fin_entry_list', _base || jsonb_build_object('it_kind', 2, 'dt_from', '2030-01-01',
            'dt_to', '2030-01-31', 'vc_date', 'x'), 'FIN_LIST_FILTER_INVALID');
  -- so parceladas
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _rent,
            'vc_description', 'Cadeira', 'vl_amount', 300, 'dt_due', '2030-01-05', 'qt_installments', 3));
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', '2030-01-01', 'dt_to', '2030-12-31',
          'id_installments', true));
  assert jsonb_array_length(_r -> 'entries') = 3, 'so as 3 parcelas: ' || jsonb_array_length(_r -> 'entries');

  -- dados bancarios da conta
  perform pg_temp.expect_error('fin_account_save', _base || jsonb_build_object('vc_action', 'U', 'nr_account', 2,
            'vc_bank_code', '12'), 'FIN_ACCOUNT_BANK_INVALID');
  perform ad.fin_account_save(_base || jsonb_build_object('vc_action', 'U', 'nr_account', 2, 'vc_bank_code', '001',
            'vc_bank_name', 'Banco do Brasil', 'vc_agency', '1234-5', 'vc_account_number', '99887-0'));
  _r := ad.fin_catalog(_base);
  assert (select x ->> 'vc_bank_code' = '001' and x ->> 'vc_agency' = '1234-5'
            from jsonb_array_elements(_r -> 'accounts') x where (x ->> 'nr_account')::int = 2), 'banco e agencia';

  -- cartao: dados vao para os recebiveis
  perform ad.fin_rate_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Crédito 2 a 6x',
            'it_payment_method', 3, 'qt_installments_min', 1, 'qt_installments_max', 6, 'pc_fee', 4,
            'qt_days', 30, 'nr_account', 2));
  _e2 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
           'vc_description', 'Clareamento', 'vl_amount', 300, 'dt_due', '2026-11-10', 'nr_patient', _pa,
           'nr_professional', _ana)) ->> 'nr_entry')::bigint;
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e2,
            'nr_account', 1, 'dt_paid', '2026-11-10', 'it_payment_method', 3, 'qt_card_installments', 2,
            'vc_card_last4', '12'), 'FIN_RECEIVABLE_DETAILS_INVALID');
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e2, 'nr_account', 1,
            'dt_paid', '2026-11-10', 'it_payment_method', 3, 'qt_card_installments', 2, 'vc_card_brand', 'Visa',
            'vc_card_last4', '**** 4321', 'vc_authorization', 'A1B2', 'vc_holder_name', 'Paciente F4',
            'vc_holder_document', '529.982.247-25'));
  assert (select count(*) from od.fin_receivable where nr_company = _ca and nr_entry = _e2 and vc_card_brand = 'Visa'
            and vc_card_last4 = '4321' and vc_holder_document = '52998224725') = 2, 'dados nos 2 recebiveis';
  _r := ad.fin_receivable_list(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2027-01-31'));
  assert (_r -> 'receivables' -> 0 ->> 'vc_authorization') = 'A1B2', 'lista traz a autorizacao';

  -- Receita Saude: pendente -> marca -> exportado
  _r := ad.fin_health_export(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2026-11-30',
          'vc_export', 'pending'));
  assert (_r ->> 'qt_rows')::int = 1 and (_r -> 'rows' -> 0 ->> 'dh_exported') is null, 'um pendente';
  _r := ad.fin_health_export(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2026-11-30',
          'vc_export', 'pending', 'id_mark', true));
  assert (_r -> 'rows' -> 0 ->> 'dh_exported') is not null, 'marcado agora';
  assert (ad.fin_health_export(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2026-11-30',
            'vc_export', 'pending')) ->> 'qt_rows')::int = 0, 'nao sobra pendente';
  assert (ad.fin_health_export(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2026-11-30',
            'vc_export', 'exported')) ->> 'qt_rows')::int = 1, 'aparece nos exportados';
  assert (ad.fin_health_export(_base || jsonb_build_object('dt_from', '2026-11-01', 'dt_to', '2026-11-30',
            'nr_entries', jsonb_build_array(999))) ->> 'qt_rows')::int = 0, 'so as linhas escolhidas';

  -- consulta passada sem fechamento
  _ap := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
           'nr_professional', _ana, 'dh_start', '2024-03-04T09:00:00-03:00', 'dh_end', '2024-03-04T10:00:00-03:00'))
           ->> 'nr_appointment')::bigint;
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'it_type', 2, 'vc_title', 'Reunião',
            'dh_start', '2024-03-04T11:00:00-03:00', 'dh_end', '2024-03-04T12:00:00-03:00'));
  _r := ad.appointment_pending_checkout(_base || jsonb_build_object('dt_from', '2024-03-01', 'dt_to', '2024-03-31'));
  assert (_r ->> 'qt_total')::int = 1 and (_r -> 'appointments' -> 0 ->> 'nr_appointment')::bigint = _ap
     and (_r -> 'appointments' -> 0 ->> 'vc_patient') = 'Paciente F4', 'consulta sem fechamento (sem o compromisso)';
  perform ad.appointment_checkout(_base || jsonb_build_object('nr_appointment', _ap, 'vl_amount', 150,
            'dt_due', '2024-03-04'));
  assert (ad.appointment_pending_checkout(_base || jsonb_build_object('dt_from', '2024-03-01', 'dt_to', '2024-03-31'))
            ->> 'qt_total')::int = 0, 'fechada sai da lista';

  -- anexos
  perform pg_temp.expect_error('fin_attachment_save', _base || jsonb_build_object('vc_action', 'I', 'nr_entry', _e1,
            'vc_name', 'nota.exe', 'vc_mime', 'application/x-msdownload', 'qt_bytes', 10), 'FIN_ATTACHMENT_TYPE_INVALID');
  perform pg_temp.expect_error('fin_attachment_save', _base || jsonb_build_object('vc_action', 'I', 'nr_entry', _e1,
            'vc_name', 'nota.pdf', 'vc_mime', 'application/pdf', 'qt_bytes', 20000000), 'FIN_ATTACHMENT_TOO_LARGE');
  perform pg_temp.expect_error('fin_attachment_save', _base || jsonb_build_object('vc_action', 'I', 'nr_entry', 999,
            'vc_name', 'nota.pdf', 'vc_mime', 'application/pdf', 'qt_bytes', 10), 'FIN_ENTRY_NOT_FOUND');
  _r := ad.fin_attachment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_entry', _e1, 'it_type', 1,
          'vc_name', 'Nota luz.pdf', 'vc_mime', 'application/pdf', 'qt_bytes', 12345));
  _att := (_r ->> 'nr_attachment')::bigint;
  assert (_r ->> 'vc_path') like _ca || '/1/' || _e1 || '/%.pdf', 'caminho empresa/filial/conta: ' || (_r ->> 'vc_path');
  _r := ad.fin_attachment_list(_base || jsonb_build_object('nr_entry', _e1));
  assert jsonb_array_length(_r -> 'attachments') = 1 and (_r -> 'attachments' -> 0 ->> 'vc_name') = 'Nota luz.pdf'
     and (_r -> 'attachments' -> 0 ->> 'vc_user') = 'Mel Fase4', 'lista o anexo';
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', '2030-02-01', 'dt_to', '2030-02-28',
          'vc_search', 'luz'));
  assert (_r -> 'entries' -> 0 ->> 'qt_attachments')::int = 1, 'conta mostra 1 anexo';
  _r := ad.fin_attachment_save(_base || jsonb_build_object('vc_action', 'DELETE', 'nr_attachment', _att));
  assert (_r ->> 'vc_path') like '%.pdf', 'devolve o caminho para apagar';
  assert jsonb_array_length(ad.fin_attachment_list(_base || jsonb_build_object('nr_entry', _e1)) -> 'attachments') = 0,
    'excluido some';
  perform pg_temp.expect_error('fin_attachment_save', _base || jsonb_build_object('vc_action', 'DELETE',
            'nr_attachment', _att), 'FIN_ATTACHMENT_NOT_FOUND');
end $$;

-- ----------------------------------------------------------------------------
\echo '== Oto (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d3","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('fin_recurrence_save', _base || jsonb_build_object('vc_action', 'I'), 'FIN_RECURRENCE_FORBIDDEN');
  perform pg_temp.expect_error('fin_recurrence_list', _base, 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('fin_attachment_save', _base || jsonb_build_object('vc_action', 'I'), 'FIN_ATTACHMENT_FORBIDDEN');
  perform pg_temp.expect_error('fin_attachment_list', _base || jsonb_build_object('nr_entry', 1), 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('appointment_pending_checkout', _base || jsonb_build_object('dt_from', '2024-03-01',
            'dt_to', '2024-03-31'), 'FINANCE_FORBIDDEN');
  assert (select count(*) from od.fin_recurrence) = 0, 'RLS: Oto nao ve recorrentes';
  assert (select count(*) from od.fin_attachment) = 0, 'RLS: Oto nao ve anexos';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.fin_recurrence_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou fin_recurrence_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 16_finance_phase4'
