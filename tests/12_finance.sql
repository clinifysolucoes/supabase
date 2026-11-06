-- ============================================================================
-- Financeiro, fase 1: contas, plano de contas, fornecedores, lancamentos,
-- baixa, visao geral, fluxo de caixa e extrato (RPCs ad.fin_*, tela FINANCE).
--   Mel = administradora da empresa
--   Noa = perfil "Financeiro": FINANCE ler + criar (sem alterar)
--   Oto = usuario sem empresa
-- Datas fixas em novembro/2026 para os calculos nao dependerem de hoje.
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/12_finance.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000091', 'mel.fin@test.local', '{"name": "Mel Financeiro"}'),
  ('00000000-0000-0000-0000-000000000092', 'noa.fin@test.local', '{"name": "Noa Financeiro"}'),
  ('00000000-0000-0000-0000-000000000093', 'oto.fin@test.local', '{"name": "Oto Financeiro"}');

do $$
begin
  assert (select uu_screen from ad.screen where vc_code = 'FINANCE') = '0d6a1f3e-1b2c-4d5e-8f90-000000000008',
    'tela FINANCE com o uuid fixo';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Mel: configuracao, cadastros e lancamentos'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000091","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

do $$
declare
  _r      jsonb;
  _ca     bigint;
  _base   jsonb;
  _cx     bigint;
  _bk     bigint;
  _rec    bigint;
  _aluguel bigint;
  _mat    bigint;
  _sup    bigint;
  _pa     bigint;
  _e1     bigint;
  _e2     bigint;
  _e3     bigint;
  _uu     uuid := '0d6a1f3e-1b2c-4d5e-8f90-000000000008';
  _prof   bigint;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Financeira"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);

  -- despesas da precificacao viram categorias no setup
  perform ad.pricing_param_save(_base || jsonb_build_object(
            'params', jsonb_build_object('pc_profit', 30),
            'expenses', jsonb_build_array(
              jsonb_build_object('vc_name', 'Aluguel', 'it_type', 1, 'vl_amount', 3700),
              jsonb_build_object('vc_name', 'Limpeza', 'it_type', 2, 'vl_amount', 200),
              jsonb_build_object('vc_name', '13º salário', 'it_type', 3, 'vl_amount', 2500),
              jsonb_build_object('vc_name', 'Anúncios', 'it_type', 4, 'vl_amount', 4000))));

  _r := ad.fin_overview(_base || jsonb_build_object('dt_ref', '2026-11-10'));
  assert not (_r ->> 'id_configured')::boolean, 'filial nova ainda nao configurada';

  _r := ad.fin_setup(_base);
  assert (_r ->> 'qt_accounts')::int = 2 and (_r ->> 'qt_categories')::int = 8,
    'setup: 2 contas, 3 receitas e 4 despesas da precificacao, veio ' || _r::text;
  _r := ad.fin_setup(_base);
  assert (_r ->> 'qt_accounts')::int = 0 and (_r ->> 'qt_categories')::int = 0, 'setup de novo nao duplica';

  _r := ad.fin_catalog(_base);
  assert jsonb_array_length(_r -> 'accounts') = 2, 'Caixa e Banco';
  assert (select x ->> 'it_cost_type' from jsonb_array_elements(_r -> 'categories') x where x ->> 'vc_name' = 'Aluguel') = '1',
    'aluguel = custo fixo';
  assert (select x ->> 'it_cost_type' from jsonb_array_elements(_r -> 'categories') x where x ->> 'vc_name' = 'Anúncios') = '2',
    'publicidade = custo variavel';
  assert (select x ->> 'it_cost_type' from jsonb_array_elements(_r -> 'categories') x where x ->> 'vc_name' = '13º salário') = '1',
    'eventual anual = custo fixo';
  _cx := (select (x ->> 'nr_account')::bigint from jsonb_array_elements(_r -> 'accounts') x where x ->> 'vc_name' = 'Caixa');
  _bk := (select (x ->> 'nr_account')::bigint from jsonb_array_elements(_r -> 'accounts') x where x ->> 'vc_name' = 'Banco');
  _rec := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_r -> 'categories') x where x ->> 'vc_name' = 'Tratamentos');
  _aluguel := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_r -> 'categories') x where x ->> 'vc_name' = 'Aluguel');

  -- cadastros
  perform ad.fin_account_save(_base || jsonb_build_object('vc_action', 'U', 'nr_account', _bk, 'vl_opening', 1000));
  perform pg_temp.expect_error('fin_account_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'caixa'), 'FIN_ACCOUNT_NAME_IN_USE');
  perform pg_temp.expect_error('fin_account_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X', 'it_type', 5), 'FIN_ACCOUNT_TYPE_INVALID');
  _mat := (ad.fin_category_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Materiais', 'it_kind', 2, 'it_cost_type', 2)) ->> 'nr_category')::bigint;
  perform pg_temp.expect_error('fin_category_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X', 'it_kind', 3), 'FIN_CATEGORY_KIND_INVALID');
  perform pg_temp.expect_error('fin_category_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X', 'it_kind', 2, 'it_cost_type', 9), 'FIN_CATEGORY_COST_TYPE_INVALID');
  -- mesmo nome em receita e despesa pode
  perform ad.fin_category_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Materiais', 'it_kind', 1));
  _sup := (ad.fin_supplier_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Dental Sul',
             'vc_document', '11.222.333/0001-81', 'vc_phone', '(41) 3333-4444', 'vc_email', 'Vendas@DentalSul.com')) ->> 'nr_supplier')::bigint;
  assert (select vc_document || '|' || vc_phone || '|' || vc_email from od.fin_supplier where nr_company = _ca and nr_supplier = _sup)
       = '11222333000181|4133334444|vendas@dentalsul.com', 'fornecedor normalizado';
  perform pg_temp.expect_error('fin_supplier_save', _base || jsonb_build_object('vc_action', 'I', 'vc_name', 'X', 'vc_document', '111.111.111-11'), 'FIN_SUPPLIER_DOCUMENT_INVALID');

  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Paciente Fin', 'dt_birth', '1990-01-01', 'vc_cpf', '12345678062')) ->> 'nr_patient')::bigint;

  -- lancamentos: parcelado (300 em 3 de 100), recorrente (aluguel 12x), unico ja pago
  _r := ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec, 'nr_patient', _pa,
          'vc_description', 'Tratamento', 'vl_amount', 1000, 'dt_due', '2026-11-05', 'qt_installments', 3, 'it_payment_method', 3));
  _e1 := (_r ->> 'nr_entry')::bigint;
  assert (_r ->> 'qt_created')::int = 3 and _r ->> 'uu_group' is not null, '3 parcelas no mesmo grupo';
  assert (select string_agg(vl_amount::text || '@' || dt_due::text, ',' order by nr_installment)
            from od.fin_entry where nr_company = _ca and uu_group = (_r ->> 'uu_group')::uuid)
       = '333.33@2026-11-05,333.33@2026-12-05,333.34@2027-01-05', 'centavos na ultima, vencimentos mensais';
  assert (select vc_description from od.fin_entry where nr_company = _ca and nr_entry = _e1) = 'Tratamento (1/3)', 'descricao da parcela';

  _r := ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _aluguel,
          'vc_description', 'Aluguel', 'vl_amount', 3700, 'dt_due', '2026-11-10', 'id_recurring', true, 'qt_repeat', 12));
  _e2 := (_r ->> 'nr_entry')::bigint;
  assert (_r ->> 'qt_created')::int = 12, '12 meses de aluguel';
  assert (select count(*) from od.fin_entry where nr_company = _ca and uu_group = (_r ->> 'uu_group')::uuid and vl_amount = 3700
            and vc_description = 'Aluguel') = 12, 'recorrente com o mesmo valor e descricao';

  _r := ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _mat, 'nr_supplier', _sup,
          'nr_account', _cx, 'vc_description', 'Resinas', 'vl_amount', 250, 'dt_due', '2026-11-03',
          'id_paid', true, 'dt_paid', '2026-11-03', 'it_payment_method', 2));
  _e3 := (_r ->> 'nr_entry')::bigint;
  assert (select it_status = 2 and vl_paid = 250 from od.fin_entry where nr_company = _ca and nr_entry = _e3), 'nasce paga';

  -- validacoes
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _aluguel,
            'vc_description', 'X', 'vl_amount', 10, 'dt_due', '2026-11-01'), 'FIN_ENTRY_CATEGORY_INVALID');
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
            'vc_description', 'X', 'vl_amount', 0, 'dt_due', '2026-11-01'), 'FIN_ENTRY_AMOUNT_INVALID');
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
            'vc_description', 'X', 'vl_amount', 10), 'FIN_ENTRY_DUE_REQUIRED');
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
            'vc_description', 'X', 'vl_amount', 10, 'dt_due', 'ontem'), 'FIN_ENTRY_VALUE_INVALID');
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
            'vc_description', 'X', 'vl_amount', 10, 'dt_due', '2026-11-01', 'qt_installments', 2, 'id_recurring', true), 'FIN_ENTRY_INSTALLMENTS_INVALID');
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
            'vc_description', 'X', 'vl_amount', 10, 'dt_due', '2026-11-01', 'id_paid', true), 'FIN_ENTRY_PAID_ACCOUNT_REQUIRED');

  -- baixa: recebe a 1a parcela no banco; pago trava valor; desfaz e paga de novo
  perform ad.fin_entry_settle(_base || jsonb_build_object('nr_entry', _e1, 'vc_action', 'PAY', 'nr_account', _bk, 'dt_paid', '2026-11-06'));
  assert (select it_status = 2 and vl_paid = 333.33 and nr_account = _bk from od.fin_entry where nr_company = _ca and nr_entry = _e1),
    'paga com o valor da parcela';
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'U', 'nr_entry', _e1, 'vl_amount', 1), 'FIN_ENTRY_PAID_LOCKED');
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'U', 'nr_entry', _e1, 'vc_notes', 'Cartão em 3x'));
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('nr_entry', _e1, 'vc_action', 'PAY', 'nr_account', _bk), 'FIN_SETTLE_STATUS_INVALID');
  perform ad.fin_entry_settle(_base || jsonb_build_object('nr_entry', _e1, 'vc_action', 'UNDO'));
  assert (select it_status = 1 and dt_paid is null from od.fin_entry where nr_company = _ca and nr_entry = _e1), 'pagamento desfeito';
  perform ad.fin_entry_settle(_base || jsonb_build_object('nr_entry', _e1, 'vc_action', 'PAY', 'nr_account', _bk,
            'dt_paid', '2026-11-06', 'vl_paid', 330));
  -- aluguel de novembro pago no caixa
  perform ad.fin_entry_settle(_base || jsonb_build_object('nr_entry', _e2, 'vc_action', 'PAY', 'nr_account', _cx, 'dt_paid', '2026-11-10'));
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('nr_entry', _e2 + 1, 'vc_action', 'PAY'), 'FIN_ENTRY_ACCOUNT_INVALID');

  -- cancela o aluguel de fevereiro em diante (dezembro e janeiro ficam)
  _r := ad.fin_entry_settle(_base || jsonb_build_object('nr_entry', _e2 + 3, 'vc_action', 'CANCEL', 'id_following', true));
  assert (_r ->> 'qt_changed')::int = 9, 'fev a out canceladas, veio ' || (_r ->> 'qt_changed');
  perform ad.fin_entry_settle(_base || jsonb_build_object('nr_entry', _e2 + 11, 'vc_action', 'REOPEN'));
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'U', 'nr_entry', _e2 + 3, 'vc_notes', 'x'), 'FIN_ENTRY_CANCELLED_LOCKED');

  -- saldo: caixa 0 - 250 - 3700 = -3950; banco 1000 + 330 = 1330
  _r := ad.fin_catalog(_base);
  assert (select (x ->> 'vl_balance')::numeric from jsonb_array_elements(_r -> 'accounts') x where x ->> 'vc_name' = 'Caixa') = -3950, 'saldo do caixa';
  assert (select (x ->> 'vl_balance')::numeric from jsonb_array_elements(_r -> 'accounts') x where x ->> 'vc_name' = 'Banco') = 1330, 'saldo do banco';

  -- lista de contas a pagar de novembro
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', '2026-11-01', 'dt_to', '2026-11-30'));
  assert (_r -> 'totals' ->> 'qt_total')::int = 2, 'resinas e aluguel de novembro';
  assert (_r -> 'totals' ->> 'vl_paid')::numeric = 3950, 'pago em novembro';
  assert (_r -> 'totals' -> 'by_cost_type' ->> '1')::numeric = 3700 and (_r -> 'totals' -> 'by_cost_type' ->> '2')::numeric = 250, 'por tipo de custo';
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 1, 'dt_from', '2026-11-01', 'dt_to', '2027-01-31', 'vc_status', 'open'));
  assert (_r -> 'totals' ->> 'qt_total')::int = 2 and (_r -> 'totals' ->> 'vl_open')::numeric = 666.67, 'parcelas em aberto';
  assert _r -> 'entries' -> 0 ->> 'vc_patient' = 'Paciente Fin' and _r -> 'entries' -> 0 ->> 'vc_category' = 'Tratamentos', 'nomes';
  _r := ad.fin_entry_list(_base || jsonb_build_object('it_kind', 2, 'dt_from', '2026-11-01', 'dt_to', '2027-10-31',
          'vc_status', 'cancelled', 'vc_search', 'alug'));
  assert (_r -> 'totals' ->> 'qt_total')::int = 8, 'canceladas (9 - 1 reaberta)';
  perform pg_temp.expect_error('fin_entry_list', _base || jsonb_build_object('it_kind', 2, 'dt_from', '2026-01-01', 'dt_to', '2028-12-31'), 'FIN_LIST_FILTER_INVALID');

  -- visao geral em 05/12: aluguel e parcela de dezembro no mes; nada vencido ainda
  _r := ad.fin_overview(_base || jsonb_build_object('dt_ref', '2026-12-05'));
  assert (_r ->> 'id_configured')::boolean, 'configurada';
  assert (_r ->> 'vl_balance')::numeric = -2620, 'saldo total (-3950 + 1330)';
  assert (_r -> 'today' ->> 'vl_receivable')::numeric = 333.33, 'parcela vence no dia';
  assert (_r -> 'month' ->> 'vl_to_pay')::numeric = 3700 and (_r -> 'month' ->> 'vl_to_receive')::numeric = 333.33, 'mes de dezembro';
  assert (_r -> 'overdue' ->> 'qt_receivable')::int = 0, 'nada vencido em 05/12';
  _r := ad.fin_overview(_base || jsonb_build_object('dt_ref', '2026-12-20'));
  assert (_r -> 'overdue' ->> 'vl_receivable')::numeric = 333.33 and (_r -> 'overdue' ->> 'qt_payable')::int = 1, 'vencidos em 20/12';
  assert jsonb_array_length(_r -> 'next') >= 2, 'proximos vencimentos';

  -- fluxo de caixa de novembro: saldo antes = banco 1000; entradas 330 (06/11), saidas 250 (03/11) + 3700 (10/11)
  _r := ad.fin_cashflow(_base || jsonb_build_object('nr_year', 2026, 'nr_month', 11));
  assert (_r ->> 'vl_opening')::numeric = 1000, 'saldo antes de novembro';
  assert jsonb_array_length(_r -> 'days') = 30, '30 dias';
  assert (_r -> 'totals' ->> 'vl_in')::numeric = 330 and (_r -> 'totals' ->> 'vl_out')::numeric = 3950, 'realizado';
  assert (_r -> 'days' -> 29 ->> 'vl_balance')::numeric = -2620, 'saldo no fim do mes';
  -- dezembro: a parcela de 05/12 e o aluguel de 10/12 previstos
  _r := ad.fin_cashflow(_base || jsonb_build_object('nr_year', 2026, 'nr_month', 12));
  assert (_r -> 'totals' ->> 'vl_in_planned')::numeric = 333.33 and (_r -> 'totals' ->> 'vl_out_planned')::numeric = 3700, 'previsto';
  assert (_r -> 'days' -> 30 ->> 'vl_projected')::numeric = -2620 + 333.33 - 3700, 'saldo projetado';

  -- extrato do caixa em novembro
  _r := ad.fin_statement(_base || jsonb_build_object('nr_account', _cx, 'dt_from', '2026-11-01', 'dt_to', '2026-11-30'));
  assert (_r ->> 'vl_start')::numeric = 0 and (_r ->> 'vl_end')::numeric = -3950, 'saldos do extrato';
  assert jsonb_array_length(_r -> 'movements') = 2 and (_r -> 'movements' -> 1 ->> 'vl_balance')::numeric = -3950, 'saldo apos cada movimento';
  _r := ad.fin_statement(_base || jsonb_build_object('dt_from', '2026-11-07', 'dt_to', '2026-11-30'));
  assert (_r ->> 'vl_start')::numeric = 1000 - 250 + 330 and (_r ->> 'vl_out')::numeric = 3700, 'extrato de todas a partir de 07/11';

  -- log sem nome de paciente
  assert not exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'fin_entry'
                       and (e.vc_summary ilike '%Paciente%' or e.js_detail::text ilike '%Paciente Fin%')), 'log sem dados pessoais';

  -- perfil Financeiro (ler + criar) para a Noa
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Financeiro', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', _uu, 'id_read', true, 'id_create', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'noa.fin@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));
end $$;

-- ----------------------------------------------------------------------------
\echo '== Noa (Financeiro): le e lanca, nao baixa nem altera'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000092","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca   bigint := current_setting('test.nr_company')::bigint;
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  _r := ad.fin_catalog(_base);
  assert (_r -> 'permission' ->> 'id_create')::boolean and not (_r -> 'permission' ->> 'id_update')::boolean, 'permissao no catalogo';
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2,
            'nr_category', (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_r -> 'categories') x
                             where x ->> 'vc_name' = 'Limpeza'),
            'vc_description', 'Produtos', 'vl_amount', 80, 'dt_due', '2026-11-20'));
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('nr_entry', 1, 'vc_action', 'UNDO'), 'FIN_ENTRY_FORBIDDEN');
  perform pg_temp.expect_error('fin_account_save', _base || jsonb_build_object('vc_action', 'U', 'nr_account', 1, 'vl_opening', 5), 'FIN_ACCOUNT_FORBIDDEN');
end $$;

-- ----------------------------------------------------------------------------
\echo '== Oto (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000093","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('fin_overview', _base, 'FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('fin_entry_save', _base || jsonb_build_object('vc_action', 'I'), 'FIN_ENTRY_FORBIDDEN');
  assert (select count(*) from od.fin_entry) = 0, 'RLS: Oto nao ve lancamentos';
  assert (select count(*) from od.fin_account) = 0, 'RLS: Oto nao ve contas';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.fin_overview('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou fin_overview';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 12_finance'
