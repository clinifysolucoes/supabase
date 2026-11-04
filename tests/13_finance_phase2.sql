-- ============================================================================
-- Financeiro, fase 2: fechamento do atendimento (ad.appointment_checkout_get /
-- ad.appointment_checkout), comissao, selo na agenda, caixa do dia
-- (ad.fin_cash_open / close / status) e transferencias (ad.fin_transfer_save).
--   Mel = administradora da empresa
--   Noa = perfil "Recepcao": so AGENDA (ler), sem FINANCE
--   Oto = usuario sem empresa
-- O fechamento usa a data de hoje da filial: as datas sao calculadas, nao
-- fixas. Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/13_finance_phase2.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'mel.cx@test.local', '{"name": "Mel Caixa"}'),
  ('00000000-0000-0000-0000-0000000000a2', 'noa.cx@test.local', '{"name": "Noa Recepcao"}'),
  ('00000000-0000-0000-0000-0000000000a3', 'oto.cx@test.local', '{"name": "Oto Caixa"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

-- saldo de hoje pela RPC do app (od.fn_fin_balance e interna, sem grant)
create function pg_temp.bal(p_ca bigint, p_acc bigint) returns numeric language sql as $$
  select coalesce(sum((x ->> 'vl_balance')::numeric), 0)
    from jsonb_array_elements(ad.fin_catalog(jsonb_build_object('nr_version', 1, 'nr_company', p_ca, 'nr_branch', 1))
                              -> 'accounts') x
   where p_acc is null or (x ->> 'nr_account')::bigint = p_acc
$$;

-- ----------------------------------------------------------------------------
\echo '== Mel: fechamento do atendimento, comissao e caixa'
do $$
declare
  _r      jsonb;
  _ca     bigint;
  _base   jsonb;
  _pa     bigint;
  _ana    bigint;
  _proc   bigint;
  _a1     bigint;
  _a2     bigint;
  _a3     bigint;
  _today  date;
  _ses    bigint;
  _e      record;
  _prof   bigint;
  _ap     jsonb;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Caixa"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _today := (select (now() at time zone b.vc_timezone)::date from ad.branch b
              where b.nr_company = _ca and b.nr_branch = 1);

  perform ad.pricing_param_save(_base || jsonb_build_object('params', jsonb_build_object('pc_commission', 10)));
  _proc := (ad.procedure_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Limpeza',
             'qt_minutes', 30, 'vl_current_price', 300)) ->> 'nr_procedure')::bigint;
  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I',
           'vc_name', 'Paciente Caixa', 'dt_birth', '1990-01-01')) ->> 'nr_patient')::bigint;
  _ana := (ad.professional_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Dra. Ana'))
           ->> 'nr_professional')::bigint;
  _a1 := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
           'nr_professional', _ana, 'nr_procedure', _proc,
           'dh_start', '2026-11-03T09:00:00-03:00', 'dh_end', '2026-11-03T10:00:00-03:00'))
           ->> 'nr_appointment')::bigint;

  -- sem financeiro configurado
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', _a1,
            'vl_amount', 300), 'CHECKOUT_NOT_CONFIGURED');
  _r := ad.fin_setup(_base);
  assert exists (select 1 from od.fin_category where nr_company = _ca and it_kind = 2
                    and vc_name = 'Comissões' and it_cost_type = 2), 'setup cria Comissões (variavel)';

  -- selo: agendado sem nada = null; atendido sem recebimento = 1
  _ap := ad.appointment_list(_base || jsonb_build_object('dt_start', '2026-11-03', 'dt_end', '2026-11-03')) -> 'appointments' -> 0;
  assert _ap ->> 'it_fin_status' is null, 'agendado: sem selo';
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'it_status', 5));
  _ap := ad.appointment_list(_base || jsonb_build_object('dt_start', '2026-11-03', 'dt_end', '2026-11-03')) -> 'appointments' -> 0;
  assert (_ap ->> 'it_fin_status')::int = 1, 'atendido sem recebimento: pendente';

  -- dados do fechamento
  _r := ad.appointment_checkout_get(_base || jsonb_build_object('nr_appointment', _a1));
  assert (_r -> 'appointment' ->> 'vl_price')::numeric = 300, 'preco cobrado da precificacao';
  assert (_r -> 'appointment' ->> 'pc_commission')::numeric = 10, 'comissao padrao da filial';
  assert (_r -> 'appointment' ->> 'vc_patient') = 'Paciente Caixa', 'paciente';
  assert not (_r ->> 'id_done')::boolean and (_r ->> 'id_configured')::boolean, 'ainda nao fechado';
  assert (select vc_name from od.fin_category where nr_company = _ca
            and nr_category = (_r ->> 'nr_category')::bigint) = 'Tratamentos', 'receita padrao Tratamentos';
  assert _r ->> 'nr_session_account' is null, 'sem caixa aberto';

  -- caixa do dia na conta Caixa (1); Banco (2) nao e caixa
  perform pg_temp.expect_error('fin_cash_open', _base || jsonb_build_object('nr_account', 2), 'FIN_CASH_ACCOUNT_INVALID');
  _r := ad.fin_cash_open(_base || jsonb_build_object('nr_account', 1));
  _ses := (_r ->> 'nr_session')::bigint;
  assert (_r ->> 'vl_open')::numeric = 0, 'abertura = saldo atual';
  perform pg_temp.expect_error('fin_cash_open', _base || jsonb_build_object('nr_account', 1), 'FIN_CASH_USER_HAS_OPEN');
  assert (ad.appointment_checkout_get(_base || jsonb_build_object('nr_appointment', _a1))
            ->> 'nr_session_account')::bigint = 1, 'conta do caixa aberto do usuario';

  -- validacoes do fechamento
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', _a1,
            'vl_amount', 0), 'FIN_ENTRY_AMOUNT_INVALID');
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', _a1,
            'vl_amount', 300, 'qt_installments', 25), 'FIN_ENTRY_INSTALLMENTS_INVALID');
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', _a1,
            'vl_amount', 300, 'id_paid', true), 'FIN_ENTRY_PAID_ACCOUNT_REQUIRED');
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', _a1,
            'vl_amount', 300, 'pc_commission', 120), 'CHECKOUT_COMMISSION_INVALID');
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', 999,
            'vl_amount', 300), 'CHECKOUT_APPOINTMENT_NOT_FOUND');

  -- fecha: 300 em 3x, 1a recebida no Pix no caixa
  _r := ad.appointment_checkout(_base || jsonb_build_object('nr_appointment', _a1, 'vl_amount', 300,
          'qt_installments', 3, 'it_payment_method', 2, 'id_paid', true, 'nr_account', 1));
  assert (_r ->> 'qt_installments')::int = 3 and (_r ->> 'vl_commission')::numeric = 30, 'retorno do fechamento';
  assert (select count(*) from od.fin_entry where nr_company = _ca and nr_appointment = _a1 and it_kind = 1) = 3,
    '3 parcelas a receber';
  select * into _e from od.fin_entry where nr_company = _ca and nr_appointment = _a1 and it_kind = 1 and nr_installment = 1;
  assert _e.it_status = 2 and _e.vl_paid = 100 and _e.dt_paid = _today and _e.nr_cash_session = _ses
     and _e.nr_patient = _pa and _e.nr_professional = _ana and _e.dt_competence = '2026-11-03'
     and _e.vc_description = 'Limpeza (1/3)', '1a parcela recebida no caixa';
  select * into _e from od.fin_entry where nr_company = _ca and nr_appointment = _a1 and it_kind = 1 and nr_installment = 3;
  assert _e.it_status = 1 and _e.dt_due = (_today + interval '2 months')::date and _e.nr_cash_session is null,
    '3a parcela em aberto daqui a 2 meses';
  select * into _e from od.fin_entry where nr_company = _ca and nr_appointment = _a1 and it_kind = 2;
  assert _e.vl_amount = 30 and _e.it_status = 1 and _e.nr_professional = _ana
     and _e.dt_due = (date_trunc('month', _today) + interval '1 month 9 days')::date
     and _e.vc_description = 'Comissão Dra. Ana: Limpeza', 'comissao no dia 10 do mes seguinte';
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', _a1,
            'vl_amount', 300), 'CHECKOUT_ALREADY_DONE');
  assert (ad.appointment_checkout_get(_base || jsonb_build_object('nr_appointment', _a1)) ->> 'id_done')::boolean,
    'fechado';
  _ap := ad.appointment_list(_base || jsonb_build_object('dt_start', '2026-11-03', 'dt_end', '2026-11-03')) -> 'appointments' -> 0;
  assert (_ap ->> 'it_fin_status')::int = 2, 'recebimento em aberto';

  -- a lista de contas a pagar mostra o profissional e o atendimento
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', _today - 10, 'dt_to', _today + 60));
  assert (_r -> 'entries' -> 0 ->> 'vc_professional') = 'Dra. Ana'
     and (_r -> 'entries' -> 0 ->> 'nr_appointment')::bigint = _a1, 'comissao com profissional e atendimento';
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', _today - 10, 'dt_to', _today + 60,
          'nr_professional', _ana + 1));
  assert jsonb_array_length(_r -> 'entries') = 0, 'filtro por profissional';

  -- faltou e compromisso nao fecham
  _a2 := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
           'nr_professional', _ana, 'dh_start', '2026-11-04T09:00:00-03:00', 'dh_end', '2026-11-04T10:00:00-03:00',
           'it_status', 7)) ->> 'nr_appointment')::bigint;
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', _a2,
            'vl_amount', 100), 'CHECKOUT_APPOINTMENT_INVALID');
  _a3 := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'it_type', 2, 'vc_title', 'Reunião',
           'dh_start', '2026-11-04T12:00:00-03:00', 'dh_end', '2026-11-04T13:00:00-03:00')) ->> 'nr_appointment')::bigint;
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', _a3,
            'vl_amount', 100), 'CHECKOUT_APPOINTMENT_INVALID');

  -- fechamento sem comissao e sem cobrar no ato
  _a2 := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
           'nr_professional', _ana, 'dh_start', '2026-11-05T09:00:00-03:00', 'dh_end', '2026-11-05T10:00:00-03:00'))
           ->> 'nr_appointment')::bigint;
  _r := ad.appointment_checkout(_base || jsonb_build_object('nr_appointment', _a2, 'vl_amount', 150,
          'id_commission', false));
  assert (_r ->> 'vl_commission')::numeric = 0 and _r ->> 'nr_commission_entry' is null, 'sem comissao';
  assert (select it_status from od.appointment where nr_company = _ca and nr_appointment = _a2) = 5,
    'fechamento marca como atendido';
  assert (select vc_description from od.fin_entry where nr_company = _ca and nr_appointment = _a2) = 'Consulta',
    'sem procedimento = Consulta';

  -- transferencias
  perform pg_temp.expect_error('fin_transfer_save', _base || jsonb_build_object('vc_action', 'I', 'it_type', 3,
            'nr_account_from', 1, 'nr_account_to', 2, 'vl_amount', 10), 'FIN_TRANSFER_ACCOUNT_INVALID');
  perform pg_temp.expect_error('fin_transfer_save', _base || jsonb_build_object('vc_action', 'I',
            'nr_account_from', 1, 'nr_account_to', 1, 'vl_amount', 10), 'FIN_TRANSFER_SAME_ACCOUNT');
  perform pg_temp.expect_error('fin_transfer_save', _base || jsonb_build_object('vc_action', 'I',
            'nr_account_from', 1, 'nr_account_to', 2, 'vl_amount', -1), 'FIN_TRANSFER_AMOUNT_INVALID');
  _r := ad.fin_transfer_save(_base || jsonb_build_object('vc_action', 'I', 'it_type', 2,
          'nr_account_from', 1, 'nr_account_to', 2, 'vl_amount', 80));
  assert (_r ->> 'nr_cash_session')::bigint = _ses, 'sangria entra no caixa aberto';
  assert pg_temp.bal(_ca, 1) = 20 and pg_temp.bal(_ca, 2) = 80
     and pg_temp.bal(_ca, null) = 100, 'saldos com transferencia';
  _r := ad.fin_statement(_base || jsonb_build_object('nr_account', 2, 'dt_from', _today, 'dt_to', _today));
  assert (_r ->> 'vl_end')::numeric = 80 and (_r -> 'movements' -> 0 ->> 'it_kind')::int = 3
     and (_r -> 'movements' -> 0 ->> 'vl_value')::numeric = 80, 'extrato do banco com a sangria';
  _r := ad.fin_statement(_base || jsonb_build_object('dt_from', _today, 'dt_to', _today));
  assert (_r ->> 'vl_end')::numeric = 100, 'extrato de todas as contas: transferencia se anula';

  -- situacao do caixa
  _r := ad.fin_cash_status(_base);
  assert (_r -> 'mine' ->> 'vl_in')::numeric = 100 and (_r -> 'mine' -> 'by_method' ->> '2')::numeric = 100
     and (_r -> 'mine' ->> 'vl_transfer_out')::numeric = 80 and (_r -> 'mine' ->> 'vl_expected')::numeric = 20,
    'resumo do caixa aberto';
  assert (_r -> 'accounts' -> 0 ->> 'vc_user') = 'Mel Caixa', 'quem esta com o caixa';

  -- fecha com sobra de 5
  perform pg_temp.expect_error('fin_cash_close', _base || jsonb_build_object('vl_counted', -1), 'FIN_CASH_VALUE_INVALID');
  _r := ad.fin_cash_close(_base || jsonb_build_object('vl_counted', 25));
  assert (_r ->> 'vl_expected')::numeric = 20 and (_r ->> 'vl_difference')::numeric = 5, 'diferenca no fechamento';
  perform pg_temp.expect_error('fin_cash_close', _base || jsonb_build_object('nr_session', _ses, 'vl_counted', 1),
            'FIN_CASH_SESSION_CLOSED');
  _r := ad.fin_cash_status(_base);
  assert _r -> 'mine' = 'null'::jsonb and (_r -> 'sessions' -> 0 ->> 'vl_difference')::numeric = 5,
    'fechado aparece no historico';

  -- caixa fechado trava desfazer e cancelar transferencia
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('vc_action', 'UNDO',
            'nr_entry', (select nr_entry from od.fin_entry where nr_company = _ca and nr_appointment = _a1
                          and it_kind = 1 and nr_installment = 1)), 'FIN_CASH_SESSION_CLOSED');
  perform pg_temp.expect_error('fin_transfer_save', _base || jsonb_build_object('vc_action', 'CANCEL',
            'nr_transfer', 1), 'FIN_CASH_SESSION_CLOSED');

  -- transferencia fora de caixa: cancela e sai do saldo
  _r := ad.fin_transfer_save(_base || jsonb_build_object('vc_action', 'I', 'nr_account_from', 2,
          'nr_account_to', 1, 'vl_amount', 30));
  assert _r ->> 'nr_cash_session' is null, 'sem caixa aberto, sem sessao';
  perform ad.fin_transfer_save(_base || jsonb_build_object('vc_action', 'CANCEL', 'nr_transfer', (_r ->> 'nr_transfer')::bigint));
  assert pg_temp.bal(_ca, 2) = 80, 'transferencia cancelada nao conta';

  -- recebe as outras duas parcelas: selo "pago"
  for _e in select nr_entry from od.fin_entry
             where nr_company = _ca and nr_appointment = _a1 and it_kind = 1 and it_status = 1 loop
    perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e.nr_entry, 'nr_account', 2));
  end loop;
  _ap := ad.appointment_list(_base || jsonb_build_object('dt_start', '2026-11-03', 'dt_end', '2026-11-03')) -> 'appointments' -> 0;
  assert (_ap ->> 'it_fin_status')::int = 3, 'tudo recebido';
  assert (select nr_cash_session from od.fin_entry where nr_company = _ca and nr_appointment = _a1
            and it_kind = 1 and nr_installment = 2) is null, 'banco nao tem caixa: sem sessao';

  -- lancamento manual com profissional
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 2,
            'nr_category', (select nr_category from od.fin_category where nr_company = _ca and vc_name = 'Comissões'),
            'vc_description', 'Bônus', 'vl_amount', 50, 'dt_due', _today, 'nr_professional', 999),
            'FIN_ENTRY_PROFESSIONAL_INVALID');
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2,
            'nr_category', (select nr_category from od.fin_category where nr_company = _ca and vc_name = 'Comissões'),
            'vc_description', 'Bônus', 'vl_amount', 50, 'dt_due', _today, 'nr_professional', _ana));
  assert (select nr_professional from od.fin_entry where nr_company = _ca and vc_description = 'Bônus') = _ana,
    'lancamento com profissional';

  -- log sem dados pessoais
  assert exists (select 1 from ad.event_log where nr_company = _ca and vc_entity = 'appointment_checkout'
                    and vc_summary not like '%Paciente%'), 'log do fechamento sem o nome do paciente';
  assert exists (select 1 from ad.event_log where nr_company = _ca and vc_entity = 'fin_cash_session'), 'log do caixa';

  -- Noa: so agenda
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepcao', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000007',
                                                          'id_read', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'noa.cx@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));
end $$;

-- ----------------------------------------------------------------------------
\echo '== Noa (so agenda): sem selo e sem fechamento'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _ap   jsonb;
begin
  _ap := ad.appointment_list(_base || jsonb_build_object('dt_start', '2026-11-03', 'dt_end', '2026-11-03')) -> 'appointments' -> 0;
  assert _ap is not null and _ap ->> 'it_fin_status' is null, 'sem FINANCE nao ve o selo';
  perform pg_temp.expect_error('appointment_checkout_get', _base || jsonb_build_object('nr_appointment', 1), 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('appointment_checkout', _base || jsonb_build_object('nr_appointment', 1, 'vl_amount', 1),
            'FIN_ENTRY_FORBIDDEN');
  perform pg_temp.expect_error('fin_cash_open', _base || jsonb_build_object('nr_account', 1), 'FIN_CASH_FORBIDDEN');
  perform pg_temp.expect_error('fin_cash_status', _base, 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('fin_transfer_save', _base || jsonb_build_object('vc_action', 'I'), 'FIN_TRANSFER_FORBIDDEN');
end $$;

-- ----------------------------------------------------------------------------
\echo '== Oto (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('fin_cash_status', _base, 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('appointment_checkout_get', _base || jsonb_build_object('nr_appointment', 1), 'FINANCE_FORBIDDEN');
  assert (select count(*) from od.fin_cash_session) = 0, 'RLS: Oto nao ve sessoes de caixa';
  assert (select count(*) from od.fin_transfer) = 0, 'RLS: Oto nao ve transferencias';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.fin_cash_status('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou fin_cash_status';
  exception when insufficient_privilege then null;
  end;
  begin
    perform ad.appointment_checkout('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou appointment_checkout';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 13_finance_phase2'
