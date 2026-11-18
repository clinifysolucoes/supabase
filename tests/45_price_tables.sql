-- ============================================================================
-- Tabelas de preco particulares (ad.price_table_save / price_table_list,
-- od.fn_procedure_price) e o orcamento com tabela (ad.budget_save / get).
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/45_price_tables.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b7', 'eli.pt@test.local', '{"name": "Eli PT"}'),
  ('00000000-0000-0000-0000-0000000000b8', 'bia.pt@test.local', '{"name": "Bia PT"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b7","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Eli: tabelas e orcamentos'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _pa   bigint;
  _lim  bigint;
  _res  bigint;
  _t1   bigint;
  _t2   bigint;
  _r    jsonb;
  _b    jsonb;
  _p    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica PT"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Lia PT", "dt_birth": "1990-01-01",
           "vc_cpf": "52998224725", "vc_mobile": "41999990001"}'::jsonb) ->> 'nr_patient')::bigint;
  _lim := (ad.procedure_save(_base || '{"vc_action": "I", "vc_name": "Limpeza", "vl_current_price": 200}'::jsonb) ->> 'nr_procedure')::bigint;
  _res := (ad.procedure_save(_base || '{"vc_action": "I", "vc_name": "Restauração", "vl_current_price": 300}'::jsonb) ->> 'nr_procedure')::bigint;

  _t1 := (ad.price_table_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Parceria Empresa X',
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim, 'vl_price', 150)))) ->> 'nr_price_table')::bigint;
  _t2 := (ad.price_table_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Particular Pinhais', 'id_default', true,
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim, 'vl_price', 180),
                                     jsonb_build_object('nr_procedure', _res, 'vl_price', 280)))) ->> 'nr_price_table')::bigint;
  perform pg_temp.expect_error('price_table_save', _base || '{"vc_action": "I", "vc_name": "particular pinhais"}'::jsonb,
            'PRICE_TABLE_NAME_IN_USE');
  perform pg_temp.expect_error('price_table_save', _base || jsonb_build_object('vc_action', 'U', 'nr_price_table', _t1,
            'items', '[{"nr_procedure": 999, "vl_price": 10}]'::jsonb), 'PRICE_TABLE_ITEM_INVALID');
  perform pg_temp.expect_error('price_table_save', _base || jsonb_build_object('vc_action', 'U', 'nr_price_table', _t1,
            'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim, 'vl_price', -1))), 'PRICE_TABLE_ITEM_INVALID');

  _r := ad.price_table_list(_base);
  assert jsonb_array_length(_r -> 'tables') = 2 and (_r -> 'tables' -> 0 ->> 'id_default')::boolean
     and jsonb_array_length(_r -> 'tables' -> 0 -> 'items') = 2
     and (_r -> 'tables' -> 0 -> 'items' -> 0 ->> 'vl_current_price')::numeric = 200, 'lista: ' || _r::text;

  -- orcamento novo traz a tabela padrao
  _b := ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim), jsonb_build_object('nr_procedure', _res))));
  assert (_b -> 'budget' ->> 'nr_price_table')::bigint = _t2 and _b -> 'budget' ->> 'vc_price_table' = 'Particular Pinhais'
     and (_b -> 'budget' ->> 'vl_gross')::numeric = 460, 'padrao: ' || (_b -> 'budget')::text;
  -- outra tabela: so a limpeza tem preco nela, a restauracao fica no valor cobrado hoje
  _b := ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_price_table', _t1,
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim), jsonb_build_object('nr_procedure', _res))));
  assert (_b -> 'budget' ->> 'vl_gross')::numeric = 450, 'tabela 1: ' || (_b -> 'budget')::text;
  -- sem tabela: valor cobrado hoje
  _b := ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_price_table', null,
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim))));
  assert (_b -> 'budget' ->> 'vl_gross')::numeric = 200 and _b -> 'budget' ->> 'nr_price_table' is null, 'sem tabela';

  -- reducao como desconto compara com o preco da tabela
  perform ad.settings_save(_base || '{"id_budget_reduction_as_discount": true, "pc_budget_max_discount": 5,
            "id_budget_request_approval": false}'::jsonb);
  perform ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_price_table', _t1,
            'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim, 'vl_unit', 145))));
  perform pg_temp.expect_error('budget_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_price_table', _t1,
            'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim, 'vl_unit', 100))), 'BUDGET_DISCOUNT_OVER_MAX');

  -- inativar tira a padrao e bloqueia em orcamento novo
  perform ad.price_table_save(_base || jsonb_build_object('vc_action', 'U', 'nr_price_table', _t2, 'it_status', 90));
  assert not (select id_default from od.price_table where nr_company = _ca and nr_price_table = _t2), 'inativa nao e padrao';
  perform pg_temp.expect_error('budget_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_price_table', _t2,
            'items', jsonb_build_array(jsonb_build_object('nr_procedure', _lim))), 'BUDGET_PRICE_TABLE_INVALID');
  assert jsonb_array_length(ad.price_table_list(_base) -> 'tables') = 1, 'inativa fora da lista';

  -- Bia: so orcamentos (le a lista, nao altera)
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000010', 'id_read', true,
                                                          'id_create', true))));
  _p := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'bia.pt@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _p))));
end $$;

\echo '== Bia: le, nao altera'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
begin
  assert jsonb_array_length(ad.price_table_list(_base) -> 'tables') = 1, 'Bia le';
  perform pg_temp.expect_error('price_table_save', _base || '{"vc_action": "I", "vc_name": "Bia"}'::jsonb, 'PRICE_TABLE_FORBIDDEN');
end $$;

reset role;
rollback;
\o
\echo 'OK: 45_price_tables'
