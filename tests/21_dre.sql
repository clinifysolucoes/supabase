-- ============================================================================
-- DRE (ad.fin_dre): receita bruta, impostos estimados, custos variaveis,
-- margem, custos fixos, outras despesas, IRPJ/CSLL, resultado e investimentos,
-- por competencia e por caixa; aliquotas em ad.settings_save.
--   Mel = administradora da empresa
-- Datas fixas (2030); termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/21_dre.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f9', 'mel.dre@test.local', '{"name": "Mel DRE"}'),
  ('00000000-0000-0000-0000-0000000000fa', 'oto.dre@test.local', '{"name": "Oto DRE"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f9","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

-- valor da linha (total ou do mes i, 1 = primeiro)
create function pg_temp.dre(p_r jsonb, p_key text, p_i integer default null) returns numeric language sql as $$
  select case when p_i is null then (l ->> 'vl_total')::numeric else (l -> 'values' ->> (p_i - 1))::numeric end
    from jsonb_array_elements(p_r -> 'lines') l where l ->> 'vc_key' = p_key
$$;

\echo '== Mel: DRE'
do $$
declare
  _r    jsonb;
  _ca   bigint;
  _base jsonb;
  _cat  jsonb;
  _rec  bigint;
  _mat  bigint;
  _rent bigint;
  _eqp  bigint;
  _oth  bigint;
  _e1   bigint;
  _cx   bigint;
  _per  jsonb := '{"dt_from": "2030-01-01", "dt_to": "2030-02-28"}'::jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica DRE"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  perform ad.fin_setup(_base);
  _cat := ad.fin_catalog(_base);
  _rec := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x where x ->> 'vc_name' = 'Tratamentos');
  _mat := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x where x ->> 'vc_name' = 'Materiais');
  _eqp := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x where x ->> 'vc_name' = 'Equipamentos');
  _oth := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x where x ->> 'vc_name' = 'Outras despesas');
  _cx  := (select (x ->> 'nr_account')::bigint from jsonb_array_elements(_cat -> 'accounts') x where x ->> 'vc_name' = 'Caixa');
  _rent := (ad.fin_category_save(_base || '{"vc_action": "I", "vc_name": "Aluguel DRE", "it_kind": 2, "it_cost_type": 1}'::jsonb)
            ->> 'nr_category')::bigint;

  -- validacoes
  perform pg_temp.expect_error('fin_dre', _base, 'FIN_DRE_PERIOD_INVALID');
  perform pg_temp.expect_error('fin_dre', _base || '{"dt_from": "2030-01-01", "dt_to": "2032-06-01"}'::jsonb, 'FIN_DRE_PERIOD_INVALID');
  perform pg_temp.expect_error('fin_dre', _base || _per || '{"vc_basis": "x"}'::jsonb, 'FIN_DRE_PERIOD_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"pc_dre_csll": 60}'::jsonb, 'SETTINGS_DRE_INVALID');

  -- janeiro: receita 1000, materiais 200, aluguel 300, equipamento 400; fevereiro: receita 500, aluguel 300, outras 50
  _e1 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
           'vc_description', 'Tratamento', 'vl_amount', 1000, 'dt_due', '2030-01-10')) ->> 'nr_entry')::bigint;
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec,
           'vc_description', 'Tratamento', 'vl_amount', 500, 'dt_due', '2030-02-10'));
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _mat,
           'vc_description', 'Resinas', 'vl_amount', 200, 'dt_due', '2030-01-15'));
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _rent,
           'vc_description', 'Aluguel', 'vl_amount', 300, 'dt_due', '2030-01-05'));
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _rent,
           'vc_description', 'Aluguel', 'vl_amount', 300, 'dt_due', '2030-02-05'));
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _eqp,
           'vc_description', 'Autoclave', 'vl_amount', 400, 'dt_due', '2030-01-20'));
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_category', _oth,
           'vc_description', 'Diversos', 'vl_amount', 50, 'dt_due', '2030-02-20'));

  -- competencia, sem aliquotas
  _r := ad.fin_dre(_base || _per);
  assert _r -> 'months' = '["2030-01", "2030-02"]'::jsonb and _r ->> 'vc_basis' = 'competence', 'meses';
  assert pg_temp.dre(_r, 'gross') = 1500 and pg_temp.dre(_r, 'gross', 1) = 1000, 'receita bruta';
  assert pg_temp.dre(_r, 'cat:' || _rec) = 1500, 'linha da categoria';
  assert pg_temp.dre(_r, 'margin', 1) = 800 and pg_temp.dre(_r, 'fixed', 2) = 300, 'margem e fixos';
  assert pg_temp.dre(_r, 'other', 2) = 50 and pg_temp.dre(_r, 'before_tax', 2) = 150, 'outras e resultado fev';
  assert pg_temp.dre(_r, 'result') = 650 and pg_temp.dre(_r, 'investment') = 400, 'resultado e investimento fora';
  assert not exists (select 1 from jsonb_array_elements(_r -> 'lines') l where l ->> 'vc_key' in ('revenue_tax', 'income_tax')),
    'sem aliquota, sem estimativa';
  assert (select (l ->> 'pc_revenue')::numeric from jsonb_array_elements(_r -> 'lines') l where l ->> 'vc_key' = 'result') = 43.3,
    'percentual sobre a receita';

  -- com aliquotas: 6% sobre a receita, IRPJ 15% + CSLL 9% sobre o resultado
  perform ad.settings_save(_base || '{"pc_dre_revenue_tax": 6, "pc_dre_income_tax": 15, "pc_dre_csll": 9}'::jsonb);
  _r := ad.fin_dre(_base || _per);
  assert pg_temp.dre(_r, 'revenue_tax', 1) = 60 and pg_temp.dre(_r, 'net', 1) = 940, 'imposto sobre a receita';
  assert pg_temp.dre(_r, 'before_tax', 1) = 440 and pg_temp.dre(_r, 'income_tax', 1) = 105.6, 'IRPJ e CSLL';
  assert pg_temp.dre(_r, 'result', 1) = 334.4, 'resultado liquido jan';
  assert (_r -> 'rates' ->> 'pc_dre_csll')::numeric = 9, 'aliquotas no retorno';

  -- caixa: so o que foi pago, pelo mes do pagamento
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e1, 'nr_account', _cx,
            'dt_paid', '2030-02-02', 'vl_paid', 1000));
  _r := ad.fin_dre(_base || _per || '{"vc_basis": "cash"}'::jsonb);
  assert pg_temp.dre(_r, 'gross', 1) = 0 and pg_temp.dre(_r, 'gross', 2) = 1000 and pg_temp.dre(_r, 'fixed') = 0,
    'caixa: pago em fevereiro, despesas em aberto fora';
end $$;

\echo '== Oto (sem empresa): nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000fa","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  perform pg_temp.expect_error('fin_dre', jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint,
            'nr_branch', 1, 'dt_from', '2030-01-01', 'dt_to', '2030-02-01'), 'FINANCE_FORBIDDEN');
end $$;

reset role;
rollback;
\o
\echo 'OK: 21_dre'
