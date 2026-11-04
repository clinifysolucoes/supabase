-- ============================================================================
-- Precificacao (RPCs em ad, tabelas em od): parametros, despesas, taxas, materiais,
-- procedimentos, formula do preco (PJ x PF), permissao por tela PRICING e RLS.
--   Ana  = administradora da empresa
--   Bia  = perfil "Financeiro": PRICING ler + criar (sem alterar)
--   Caio = usuario sem empresa
-- Exemplo numerico (mesmo do PricingCalculator do app):
--   2 salas x 40 h/semana x 4 semanas = 320 h; ocupacao 50% -> 160 h produtivas
--   despesas: 8000 fixas + 1000 variaveis + 2400/12 anuais + 800 publicidade = 10000/mes
--   custo da estrutura = 10000 / 160 = 62,50/h; hora clinica 60/h
--   cartao 4% + comissao 6% + ISS 5% (ativa) = 15%; lucro 25%; PJ 10%
--   procedimento: 30 min, lab 20, materiais 3 x 2,00 + 2 x 1,00 + outros 2 = 10
--   custo direto = 10 + 20 + 31,25 + 30 = 91,25
--   PJ: preco = 91,25 / (1 - 0,15 - 0,10 - 0,25) = 182,50; minimo = 91,25 / 0,75 = 121,67
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/06_pricing.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000031', 'ana.preco@test.local',  '{"name": "Ana Preco"}'),
  ('00000000-0000-0000-0000-000000000032', 'bia.preco@test.local',  '{"name": "Bia Preco"}'),
  ('00000000-0000-0000-0000-000000000033', 'caio.preco@test.local', '{"name": "Caio Preco"}');

do $$
begin
  assert (select uu_screen from ad.screen where vc_code = 'PRICING') = '0d6a1f3e-1b2c-4d5e-8f90-000000000005',
    'tela PRICING deveria existir com o uuid fixo';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Ana: parametros, materiais, procedimentos e formula'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000031","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _r    jsonb;
  _ca   bigint;
  _m1   bigint;
  _m2   bigint;
  _m3   bigint;
  _p1   bigint;
  _p2   bigint;
  _pr   jsonb;
  _prof bigint;
  _uu   uuid := '0d6a1f3e-1b2c-4d5e-8f90-000000000005';
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Preco"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);

  -- parametros ainda nao salvos: padroes + sugestoes
  _r := ad.pricing_param_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert not (_r -> 'params' ->> 'id_saved')::boolean, 'id_saved deveria ser false antes de salvar';
  assert (_r -> 'params' ->> 'pc_profit')::numeric = 30, 'lucro padrao deveria ser 30';
  assert jsonb_array_length(_r -> 'expenses') = 20, 'deveriam vir 20 despesas sugeridas';
  assert jsonb_array_length(_r -> 'fees') = 7, 'deveriam vir 7 taxas sugeridas';
  assert (_r -> 'permission' ->> 'id_update')::boolean, 'admin deveria poder alterar';
  assert (_r -> 'summary' ->> 'vl_structure_hour')::numeric = 0, 'sem despesas o custo da estrutura e zero';

  begin
    perform ad.pricing_param_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
    raise exception 'FALHA: sem filial aceito';
  exception when others then
    if sqlerrm not like '%PRICING_BRANCH_REQUIRED%' then raise; end if;
  end;

  -- salva parametros + despesas + taxas
  _r := ad.pricing_param_save(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
          'params', jsonb_build_object('qt_rooms', 2, 'qt_hours_week', 40, 'qt_weeks_month', 4, 'pc_occupancy', 50,
                                       'vl_professional_hour', 60, 'pc_card', 4, 'pc_commission', 6,
                                       'it_tax_regime', 2, 'pc_tax_pf', 27.5, 'pc_tax_pj', 10, 'pc_profit', 25),
          'expenses', jsonb_build_array(
            jsonb_build_object('vc_name', 'Aluguel',  'it_type', 1, 'vl_amount', 8000),
            jsonb_build_object('vc_name', 'Limpeza',  'it_type', 2, 'vl_amount', 1000),
            jsonb_build_object('vc_name', '13º',      'it_type', 3, 'vl_amount', 2400),
            jsonb_build_object('vc_name', 'Anúncios', 'it_type', 4, 'vl_amount', 800)),
          'fees', jsonb_build_array(
            jsonb_build_object('vc_name', 'ISS',           'pc_rate', 5, 'id_active', true),
            jsonb_build_object('vc_name', 'Inadimplência', 'pc_rate', 3, 'id_active', false))));
  assert (_r ->> 'id_saved')::boolean, 'save deveria devolver id_saved';

  _r := ad.pricing_param_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (_r -> 'params' ->> 'id_saved')::boolean, 'id_saved deveria ser true';
  assert (_r -> 'summary' ->> 'vl_monthly_cost')::numeric = 10000, 'custo mensal esperado 10000, veio ' || (_r -> 'summary' ->> 'vl_monthly_cost');
  assert (_r -> 'summary' ->> 'qt_hours_month')::numeric = 320, 'horas por mes esperado 320';
  assert (_r -> 'summary' ->> 'qt_productive_hours')::numeric = 160, 'horas produtivas esperado 160';
  assert (_r -> 'summary' ->> 'vl_structure_hour')::numeric = 62.50, 'custo estrutura/h esperado 62,50, veio ' || (_r -> 'summary' ->> 'vl_structure_hour');
  assert (_r -> 'summary' ->> 'pc_fees')::numeric = 5, 'so a taxa ativa entra';
  assert (_r -> 'summary' ->> 'pc_tax')::numeric = 10, 'IR do regime PJ';
  assert jsonb_array_length(_r -> 'expenses') = 4 and jsonb_array_length(_r -> 'fees') = 2, 'listas substituidas';
  assert _r -> 'params' ->> 'vl_structure_hour_manual' is null, 'sem valor manual de estrutura';

  -- estrutura por hora manual substitui o calculo; null volta ao calculo
  perform ad.pricing_param_save(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
            'params', jsonb_build_object('vl_structure_hour_manual', 70)));
  _r := ad.pricing_param_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (_r -> 'summary' ->> 'vl_structure_hour')::numeric = 70, 'estrutura manual deveria valer 70';
  assert (_r -> 'summary' ->> 'vl_structure_hour_calc')::numeric = 62.50, 'calculo continua disponivel';
  perform ad.pricing_param_save(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
            'params', jsonb_build_object('vl_structure_hour_manual', null)));
  _r := ad.pricing_param_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (_r -> 'summary' ->> 'vl_structure_hour')::numeric = 62.50, 'null limpa o valor manual';
  begin
    perform ad.pricing_param_save(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
              'params', jsonb_build_object('vl_structure_hour_manual', -1)));
    raise exception 'FALHA: estrutura manual negativa aceita';
  exception when others then
    if sqlerrm not like '%PRICING_PARAM_INVALID%' then raise; end if;
  end;

  -- percentuais impossiveis: desfaz a transacao da RPC inteira
  begin
    perform ad.pricing_param_save(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
              'params', jsonb_build_object('pc_profit', 90)));
    raise exception 'FALHA: percentuais >= 100%% aceitos';
  exception when others then
    if sqlerrm not like '%PRICING_PERCENT_TOO_HIGH%' then raise; end if;
  end;
  _r := ad.pricing_param_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (_r -> 'params' ->> 'pc_profit')::numeric = 25, 'lucro deveria continuar 25 apos rollback';

  begin
    perform ad.pricing_param_save(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
              'params', jsonb_build_object('pc_occupancy', 0)));
    raise exception 'FALHA: ocupacao zero aceita';
  exception when others then
    if sqlerrm not like '%PRICING_PARAM_INVALID%' then raise; end if;
  end;

  -- materiais
  _r := ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Luva de procedimento', 'vc_package', 'Caixa 50 pares', 'vl_package_price', 100, 'qt_yield', 50, 'vc_unit', 'par'));
  _m1 := (_r ->> 'nr_material')::bigint;
  _r := ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Resina composta', 'vc_package', 'Seringa 4 g', 'vl_package_price', 90, 'qt_yield', 100, 'vc_unit', '0,1 g', 'pc_waste', 10));
  _m2 := (_r ->> 'nr_material')::bigint;
  _r := ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Gaze', 'vc_package', 'Pacote 500', 'qt_yield', 500));
  _m3 := (_r ->> 'nr_material')::bigint;
  assert _m1 = 1 and _m2 = 2 and _m3 = 3, 'nr_material sequencial por filial';

  begin
    perform ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'luva de PROCEDIMENTO'));
    raise exception 'FALHA: nome repetido aceito';
  exception when others then
    if sqlerrm not like '%MATERIAL_NAME_IN_USE%' then raise; end if;
  end;
  begin
    perform ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'X', 'qt_yield', 0));
    raise exception 'FALHA: rendimento zero aceito';
  exception when others then
    if sqlerrm not like '%MATERIAL_YIELD_INVALID%' then raise; end if;
  end;

  _r := ad.material_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'materials') = 3, 'deveriam listar 3 materiais';
  assert (select (m ->> 'vl_unit_cost')::numeric from jsonb_array_elements(_r -> 'materials') m where m ->> 'vc_name' = 'Luva de procedimento') = 2.0000,
    'custo unitario da luva deveria ser 2,00';
  assert (select (m ->> 'vl_unit_cost')::numeric from jsonb_array_elements(_r -> 'materials') m where m ->> 'vc_name' = 'Resina composta') = 1.0000,
    'custo unitario da resina (10% de perda) deveria ser 1,00';
  assert (select m ->> 'dh_price_updated' from jsonb_array_elements(_r -> 'materials') m where m ->> 'vc_name' = 'Gaze') is null,
    'material sem preco nao tem data de preco';
  _r := ad.material_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', 'resina'));
  assert jsonb_array_length(_r -> 'materials') = 1, 'busca por nome';

  -- procedimento com materiais
  _r := ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_code', '1.0', 'vc_name', 'Restauração 1 face', 'vc_category', 'Clínica Geral',
          'qt_minutes', 30, 'vl_lab_cost', 20, 'vl_material_other', 2, 'vl_current_price', 150,
          'materials', jsonb_build_array(
            jsonb_build_object('nr_material', _m1, 'qt_used', 3),
            jsonb_build_object('nr_material', _m2, 'qt_used', 2))));
  _p1 := (_r ->> 'nr_procedure')::bigint;
  assert _p1 = 1, 'nr_procedure sequencial';

  begin
    perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'Y', 'materials', jsonb_build_array(jsonb_build_object('nr_material', 999, 'qt_used', 1))));
    raise exception 'FALHA: material inexistente aceito';
  exception when others then
    if sqlerrm not like '%PROCEDURE_MATERIAL_INVALID%' then raise; end if;
  end;
  begin
    perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'Y', 'materials', jsonb_build_array(jsonb_build_object('nr_material', _m1, 'qt_used', 0))));
    raise exception 'FALHA: quantidade zero aceita';
  exception when others then
    if sqlerrm not like '%PROCEDURE_QUANTITY_INVALID%' then raise; end if;
  end;
  begin
    perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_code', '1.0', 'vc_name', 'Outro'));
    raise exception 'FALHA: codigo repetido aceito';
  exception when others then
    if sqlerrm not like '%PROCEDURE_CODE_IN_USE%' then raise; end if;
  end;

  -- formula no regime dos parametros (PJ)
  _r  := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'procedures') = 1, 'deveria listar 1 procedimento';
  assert _r -> 'categories' = '["Clínica Geral"]'::jsonb, 'categorias distintas';
  _pr := _r -> 'procedures' -> 0 -> 'pricing';
  assert jsonb_array_length(_r -> 'procedures' -> 0 -> 'materials') = 2, '2 materiais no procedimento';
  assert _r -> 'procedures' -> 0 -> 'alerts' = '[]'::jsonb, 'sem alertas, veio ' || (_r -> 'procedures' -> 0 ->> 'alerts');
  assert (_pr ->> 'vl_material')::numeric     = 10,     'materiais 3x2 + 2x1 + 2 = 10, veio ' || (_pr ->> 'vl_material');
  assert (_pr ->> 'vl_structure')::numeric    = 31.25,  'estrutura 0,5h x 62,50';
  assert (_pr ->> 'vl_professional')::numeric = 30,     'profissional 0,5h x 60';
  assert (_pr ->> 'vl_direct_cost')::numeric  = 91.25,  'custo direto 91,25';
  assert (_pr ->> 'vl_price')::numeric        = 182.50, 'preco PJ esperado 182,50, veio ' || (_pr ->> 'vl_price');
  assert (_pr ->> 'vl_price_min')::numeric    = 121.67, 'preco minimo esperado 121,67, veio ' || (_pr ->> 'vl_price_min');
  assert (_pr ->> 'vl_tax')::numeric          = 18.25,  'IR PJ 10% do preco';
  assert (_pr ->> 'vl_card')::numeric         = 7.30,   'cartao 4% do preco';
  assert (_pr ->> 'vl_commission')::numeric   = 10.95,  'comissao 6% do preco';
  assert (_pr ->> 'pc_profit_real')::numeric  = 25,     'lucro real deveria bater com o desejado (25%), veio ' || (_pr ->> 'pc_profit_real');
  assert (_pr ->> 'id_valid')::boolean, 'preco valido';
  assert (_r -> 'summary' ->> 'it_tax_regime')::int = 2, 'regime dos parametros';

  -- simulacao PF: IR sobre o lucro, lucro real continua 25%
  _r  := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'it_tax_regime', 1));
  _pr := _r -> 'procedures' -> 0 -> 'pricing';
  assert (_pr ->> 'it_tax_regime')::int = 1, 'regime simulado PF';
  assert (_pr ->> 'pc_profit_real')::numeric = 25, 'lucro real PF deveria ser 25%, veio ' || (_pr ->> 'pc_profit_real');
  assert abs((_pr ->> 'vl_tax')::numeric - round(0.275 * ((_pr ->> 'vl_price')::numeric - 91.25 - 0.15 * (_pr ->> 'vl_price')::numeric), 2)) < 0.02,
    'IR PF deveria incidir sobre o lucro antes do IR';
  -- (1 - 0,275) x 91,25 / ((1 - 0,275) x (1 - 0,15) - 0,25) = 66,15625 / 0,36625 = 180,63
  assert (_pr ->> 'vl_price')::numeric = 180.63, 'preco PF esperado 180,63, veio ' || (_pr ->> 'vl_price');

  begin
    perform ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'it_tax_regime', 3));
    raise exception 'FALHA: regime invalido aceito';
  exception when others then
    if sqlerrm not like '%PROCEDURE_LIST_REGIME_INVALID%' then raise; end if;
  end;

  -- alertas: sem tempo, material sem preco
  _r := ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Curativo', 'qt_minutes', 0,
          'materials', jsonb_build_array(jsonb_build_object('nr_material', _m3, 'qt_used', 2))));
  _p2 := (_r ->> 'nr_procedure')::bigint;
  _r  := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', 'curativo'));
  assert jsonb_array_length(_r -> 'procedures') = 1, 'busca por nome';
  assert _r -> 'procedures' -> 0 -> 'alerts' ? 'NO_TIME', 'alerta NO_TIME';
  assert _r -> 'procedures' -> 0 -> 'alerts' ? 'NO_MATERIAL', 'alerta NO_MATERIAL (gaze sem preco = material zero)';
  assert _r -> 'procedures' -> 0 -> 'alerts' ? 'MATERIAL_NO_PRICE', 'alerta MATERIAL_NO_PRICE';

  -- update parcial + substituir materiais por lista vazia + inativar
  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_procedure', _p2, 'qt_minutes', 15, 'materials', '[]'::jsonb, 'it_status', 90));
  assert (select count(*) from od.procedure_material where nr_company = _ca and nr_procedure = _p2) = 0, 'materiais substituidos por nada';
  _r := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'procedures') = 1, 'inativo some da lista padrao';
  _r := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'id_include_inactive', true));
  assert jsonb_array_length(_r -> 'procedures') = 2, 'id_include_inactive traz os 2';

  -- material_list: em quantos procedimentos cada material e usado
  _r := ad.material_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (select (m ->> 'qt_procedures')::int from jsonb_array_elements(_r -> 'materials') m where m ->> 'vc_name' = 'Luva de procedimento') = 1,
    'luva usada em 1 procedimento';

  -- material: alterar preco atualiza dh_price_updated; nome igual ao proprio nao conflita
  perform ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_material', _m3, 'vc_name', 'Gaze', 'vl_package_price', 20, 'it_price_source', 2, 'vc_price_source', 'Loja Exemplo'));
  assert (select dh_price_updated is not null and it_price_source = 2 from od.material where nr_company = _ca and nr_material = _m3),
    'preco alterado deveria marcar a data e a origem';

  -- perfil Financeiro (PRICING ler + criar) para a Bia
  _r := ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Financeiro', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', _uu, 'id_read', true, 'id_create', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_email', 'bia.preco@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));

  -- log de atividades na tela PRICING
  _r := ad.event_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'uu_screen', _uu));
  assert (_r ->> 'qt_total')::int >= 7, 'eventos da precificacao, veio ' || (_r ->> 'qt_total');
end $$;

-- ----------------------------------------------------------------------------
\echo '== Bia (Financeiro): le e cria, nao altera'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000032","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
  _r  jsonb;
  _p  jsonb;
begin
  _r := ad.session_context(jsonb_build_object('it_app', 1, 'nr_company', _ca, 'nr_branch', 1));
  _p := _r -> 'companies' -> 0 -> 'branches' -> 0 -> 'permissions';
  assert (select (x ->> 'id_create')::boolean and not (x ->> 'id_update')::boolean
            from jsonb_array_elements(_p) x where x ->> 'vc_code' = 'PRICING'),
    'Bia deveria ter PRICING ler+criar sem alterar';

  _r := ad.pricing_param_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert (_r -> 'permission' ->> 'id_create')::boolean and not (_r -> 'permission' ->> 'id_update')::boolean, 'permission no get';

  _r := ad.material_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'materials') = 3, 'Bia le os materiais da filial';

  perform ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_name', 'Sugador', 'vl_package_price', 14, 'qt_yield', 40));

  begin
    perform ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_material', 1, 'vl_package_price', 120));
    raise exception 'FALHA: Bia alterou material';
  exception when others then
    if sqlerrm not like '%MATERIAL_FORBIDDEN%' then raise; end if;
  end;
  begin
    perform ad.pricing_param_save(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
              'params', jsonb_build_object('pc_profit', 20)));
    raise exception 'FALHA: Bia alterou parametros';
  exception when others then
    if sqlerrm not like '%PRICING_FORBIDDEN%' then raise; end if;
  end;
  begin
    perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_procedure', 1, 'qt_minutes', 45));
    raise exception 'FALHA: Bia alterou procedimento';
  exception when others then
    if sqlerrm not like '%PROCEDURE_FORBIDDEN%' then raise; end if;
  end;

  -- RLS: so as linhas da propria filial
  assert (select count(*) from od.material) = 4, 'RLS: Bia ve os 4 materiais da filial';
  assert (select count(*) from od.procedure) = 2, 'RLS: Bia ve os procedimentos da filial';
  assert (select count(*) from od.pricing_param) = 1, 'RLS: parametros da filial';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Caio (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000033","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
begin
  begin
    perform ad.pricing_param_get(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
    raise exception 'FALHA: Caio leu parametros de outra empresa';
  exception when others then
    if sqlerrm not like '%PRICING_FORBIDDEN%' then raise; end if;
  end;
  begin
    perform ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1, 'vc_name', 'Z'));
    raise exception 'FALHA: Caio criou material';
  exception when others then
    if sqlerrm not like '%MATERIAL_FORBIDDEN%' then raise; end if;
  end;
  assert (select count(*) from od.material) = 0, 'RLS: Caio nao ve materiais';
  assert (select count(*) from od.procedure) = 0, 'RLS: Caio nao ve procedimentos';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.material_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou od.material_list';
  exception when insufficient_privilege then null;
  end;
  begin
    perform count(*) from od.material;
    raise exception 'FALHA: anon leu od.material';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 06_pricing'
