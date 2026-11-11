-- ============================================================================
-- Estoque (ad.stock_list / _item_save / _movement_save / _movement_list e a
-- baixa automatica pela evolucao clinica).
--   Tom = administrador da empresa
--   Ugo = almoxarife (STOCK ler/criar/alterar; sem Financeiro e Precificacao)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/36_stock.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', 'tom.stock@test.local', '{"name": "Tom Stock"}'),
  ('00000000-0000-0000-0000-0000000000f2', 'ugo.stock@test.local', '{"name": "Ugo Stock"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

create function pg_temp.stock(p_ca bigint, p_mat bigint) returns numeric language sql as $$
  select qt_stock from od.stock_item where nr_company = p_ca and nr_branch = 1 and nr_material = p_mat
$$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Tom: controle, entradas, saidas, ajustes e baixa pela evolucao'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _sup   bigint;
  _luva  bigint;
  _res   bigint;
  _gaze  bigint;
  _proc  bigint;
  _nb    bigint;
  _ev1   bigint;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Stock"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Ana Stock', 'dt_birth', '1980-05-10',
           'vc_cpf', '529.982.247-25')) ->> 'nr_patient')::bigint;
  perform ad.fin_setup(_base);
  _sup := (ad.fin_supplier_save(_base || '{"vc_action": "I", "vc_name": "Dental Sul"}'::jsonb) ->> 'nr_supplier')::bigint;
  _luva := (ad.material_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Luva', 'vc_package', 'Caixa 50 pares',
            'vl_package_price', 100, 'qt_yield', 50, 'vc_unit', 'par')) ->> 'nr_material')::bigint;
  _res := (ad.material_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Resina', 'vc_package', 'Seringa',
            'vl_package_price', 90, 'qt_yield', 100, 'vc_unit', 'aplicação')) ->> 'nr_material')::bigint;
  _gaze := (ad.material_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Gaze', 'vc_package', 'Pacote 500',
            'vl_package_price', 50, 'qt_yield', 500, 'vc_unit', 'unidade')) ->> 'nr_material')::bigint;
  _proc := (ad.procedure_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Restauração',
            'qt_minutes', 30, 'materials', jsonb_build_array(
              jsonb_build_object('nr_material', _luva, 'qt_used', 2),
              jsonb_build_object('nr_material', _res, 'qt_used', 3),
              jsonb_build_object('nr_material', _gaze, 'qt_used', 1)))) ->> 'nr_procedure')::bigint;
  perform set_config('test.nr_luva', _luva::text, false);

  -- controle de estoque
  _r := ad.stock_item_save(_base || jsonb_build_object('nr_material', _luva, 'id_control', true, 'qt_min', 20));
  assert (_r ->> 'id_control')::boolean and (_r ->> 'qt_min')::numeric = 20 and (_r ->> 'qt_stock')::numeric = 0, 'luva controlada';
  perform ad.stock_item_save(_base || jsonb_build_object('nr_material', _res, 'id_control', true));
  perform pg_temp.expect_error('stock_item_save', _base || '{"nr_material": 999, "id_control": true}'::jsonb,
            'STOCK_MATERIAL_NOT_FOUND');
  perform pg_temp.expect_error('stock_item_save', _base || jsonb_build_object('nr_material', _luva, 'qt_min', -1),
            'STOCK_VALUE_INVALID');

  -- consistencias do movimento
  perform pg_temp.expect_error('stock_movement_save', _base || jsonb_build_object('nr_material', _gaze, 'it_type', 1,
            'qt_quantity', 10), 'STOCK_NOT_CONTROLLED');
  perform pg_temp.expect_error('stock_movement_save', _base || jsonb_build_object('nr_material', _luva, 'it_type', 4,
            'qt_quantity', 10), 'STOCK_TYPE_INVALID');
  perform pg_temp.expect_error('stock_movement_save', _base || jsonb_build_object('nr_material', _luva, 'it_type', 1,
            'qt_quantity', 0), 'STOCK_VALUE_INVALID');
  perform pg_temp.expect_error('stock_movement_save', _base || jsonb_build_object('nr_material', _luva, 'it_type', 1,
            'qt_quantity', 1, 'dt_movement', current_date + 2), 'STOCK_VALUE_INVALID');
  perform pg_temp.expect_error('stock_movement_save', _base || jsonb_build_object('nr_material', _luva, 'it_type', 2,
            'qt_quantity', 1), 'STOCK_INSUFFICIENT');
  perform pg_temp.expect_error('stock_movement_save', _base || jsonb_build_object('nr_material', _luva, 'it_type', 1,
            'qt_packages', 1, 'id_payable', true), 'STOCK_SUPPLIER_REQUIRED');

  -- compra de 2 caixas: conta a pagar e preco novo da embalagem
  _r := ad.stock_movement_save(_base || jsonb_build_object('nr_material', _luva, 'it_type', 1, 'qt_packages', 2,
          'vl_total', 220, 'nr_supplier', _sup, 'vc_document', 'NF 123', 'id_payable', true,
          'dt_due', current_date + 30, 'id_update_price', true));
  assert (_r ->> 'qt_stock')::numeric = 100 and (_r ->> 'nr_entry') is not null, 'entrada: ' || _r::text;
  perform set_config('test.nr_entry', _r ->> 'nr_entry', false);
  assert (select vl_package_price from od.material where nr_company = _ca and nr_material = _luva) = 110, 'preco atualizado';

  -- resina: entrada sem valor, ajuste de inventario
  perform ad.stock_movement_save(_base || jsonb_build_object('nr_material', _res, 'it_type', 1, 'qt_quantity', 10));
  _r := ad.stock_movement_save(_base || jsonb_build_object('nr_material', _res, 'it_type', 3, 'qt_counted', 8,
          'vc_notes', 'Inventário'));
  assert (_r ->> 'qt_stock')::numeric = 8 and (_r ->> 'id_changed')::boolean, 'ajuste';
  _r := ad.stock_movement_save(_base || jsonb_build_object('nr_material', _res, 'it_type', 3, 'qt_counted', 8));
  assert not (_r ->> 'id_changed')::boolean and _r ->> 'nr_movement' is null, 'ajuste sem diferenca';

  -- saida manual
  _r := ad.stock_movement_save(_base || jsonb_build_object('nr_material', _luva, 'it_type', 2, 'qt_quantity', 4,
          'vc_notes', 'Perda'));
  assert (_r ->> 'qt_stock')::numeric = 96, 'saida';

  -- evolucao com o procedimento: baixa a ficha tecnica (gaze sem controle fica de fora)
  _ev1 := (ad.clinical_evolution_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'vc_text', 'Restauração feita.', 'nr_procedure', _proc)) ->> 'nr_evolution')::bigint;
  assert pg_temp.stock(_ca, _luva) = 94 and pg_temp.stock(_ca, _res) = 5, 'baixa da evolucao';
  assert not exists (select 1 from od.stock_movement where nr_company = _ca and nr_material = _gaze), 'gaze sem controle';

  -- item de orcamento com quantidade 2: baixa em dobro e o saldo pode ficar negativo
  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'dt_budget', current_date,
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _proc, 'vc_description', 'Restauração',
                                                        'qt_quantity', 2, 'vl_unit', 100))))) -> 'budget' ->> 'nr_budget')::bigint;
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 1,
            'dt_first_due', current_date + 10, 'it_payment_method', 2));
  perform ad.clinical_evolution_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'vc_text', 'Duas restaurações.', 'nr_budget', _nb, 'nr_item', 1));
  assert pg_temp.stock(_ca, _luva) = 90 and pg_temp.stock(_ca, _res) = -1, 'baixa do item x2';

  -- lista: resina negativa em alerta; valor do estoque so com saldo positivo
  _r := ad.stock_list(_base);
  assert jsonb_array_length(_r -> 'items') = 2 and (_r -> 'totals' ->> 'qt_low')::int = 1
     and (_r -> 'totals' ->> 'vl_stock')::numeric = 198, 'lista: ' || (_r -> 'totals')::text;
  assert _r -> 'items' -> 0 ->> 'vc_name' = 'Resina' and (_r -> 'items' -> 0 ->> 'id_low')::boolean, 'alerta primeiro';
  assert jsonb_array_length(ad.stock_list(_base || '{"vc_filter": "all"}'::jsonb) -> 'items') = 3, 'todos';
  assert jsonb_array_length(ad.stock_list(_base || '{"vc_filter": "low"}'::jsonb) -> 'items') = 1, 'em alerta';
  assert jsonb_array_length(_r -> 'suppliers') = 1, 'fornecedores';

  -- exclusao da evolucao estorna a baixa
  perform ad.clinical_evolution_save(_base || jsonb_build_object('vc_action', 'D', 'nr_patient', _pa, 'nr_evolution', _ev1));
  assert pg_temp.stock(_ca, _luva) = 92 and pg_temp.stock(_ca, _res) = 2, 'estorno';

  -- movimentos do dia: 2 entradas, 1 ajuste, 1 saida, 4 baixas, 2 estornos
  _r := ad.stock_movement_list(_base);
  assert jsonb_array_length(_r -> 'movements') = 10, 'movimentos: ' || jsonb_array_length(_r -> 'movements');
  assert (_r -> 'summary' ->> 'vl_in')::numeric = 220, 'resumo: ' || (_r -> 'summary')::text;
  assert jsonb_array_length(ad.stock_movement_list(_base || jsonb_build_object('nr_material', _luva, 'it_type', 4))
           -> 'movements') = 2, 'filtro';
  perform pg_temp.expect_error('stock_movement_list', _base || '{"dt_start": "2026-01-10", "dt_end": "2026-01-01"}'::jsonb,
            'STOCK_PERIOD_INVALID');

  -- desligar o controle: para a baixa automatica
  perform ad.stock_item_save(_base || jsonb_build_object('nr_material', _luva, 'id_control', false));
  perform ad.clinical_evolution_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'vc_text', 'Outra.', 'nr_procedure', _proc));
  assert pg_temp.stock(_ca, _luva) = 92 and pg_temp.stock(_ca, _res) = -1, 'luva sem controle nao baixa';
  perform ad.stock_item_save(_base || jsonb_build_object('nr_material', _luva, 'id_control', true));

  -- Ugo: estoque sem Financeiro e sem Precificacao
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Almoxarifado', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000013',
                                                          'id_read', true, 'id_create', true, 'id_update', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ugo.stock@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
  perform set_config('test.nr_sup', _sup::text, false);
end $$;

-- a conta a pagar da compra
reset role;
do $$
begin
  assert (select e.it_kind = 2 and e.vl_amount = 220 and e.vc_description = 'Compra: Luva (NF 123)'
                 and e.dt_due = current_date + 30
            from od.fin_entry e
           where e.nr_company = current_setting('test.nr_company')::bigint
             and e.nr_entry = current_setting('test.nr_entry')::bigint), 'conta a pagar da compra';
end $$;

\echo '== Ugo: compra sem conta a pagar e sem mexer no preco'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1,
                                    'nr_material', current_setting('test.nr_luva')::bigint, 'it_type', 1);
begin
  perform pg_temp.expect_error('stock_movement_save', _base || jsonb_build_object('qt_packages', 1, 'vl_total', 100,
            'nr_supplier', current_setting('test.nr_sup')::bigint, 'id_payable', true), 'STOCK_FINANCE_FORBIDDEN');
  perform pg_temp.expect_error('stock_movement_save', _base || jsonb_build_object('qt_packages', 1, 'vl_total', 100,
            'id_update_price', true), 'STOCK_PRICE_FORBIDDEN');
  assert (ad.stock_movement_save(_base || '{"qt_packages": 1, "vl_total": 100}'::jsonb) ->> 'qt_stock')::numeric = 142,
    'entrada simples';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.stock_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou stock_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 36_stock'
