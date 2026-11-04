-- ============================================================================
-- Especialidades da precificacao (ad.specialty_list / ad.specialty_save) e
-- alerta do valor cobrado hoje x custo (od.fn_pricing_calc, procedure_list).
--   Duda = administradora da empresa
--   Eva  = perfil "Financeiro": PRICING ler + criar (sem alterar)
-- Exemplo numerico (PJ 10%, cartao 4% + comissao 6%, estrutura manual 60/h,
-- hora clinica 60/h, lucro da filial 30%):
--   procedimento 60 min + outros materiais 30 -> custo direto = 30 + 60 + 60 = 150
--   lucro da filial 30%:          preco = 150 / (1 - 0,10 - 0,10 - 0,30) = 300,00
--   especialidade Implante 20%:   preco = 150 / 0,60 = 250,00; minimo = 150 / 0,80 = 187,50
--   lucro proprio 40%:            preco = 150 / 0,40 = 375,00
--   cobrado 260 -> ok | 200 -> abaixo do sugerido | 160 -> abaixo do minimo | 120 -> abaixo do custo
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/08_specialties.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000051', 'duda.esp@test.local', '{"name": "Duda Esp"}'),
  ('00000000-0000-0000-0000-000000000052', 'eva.esp@test.local',  '{"name": "Eva Esp"}');

-- ----------------------------------------------------------------------------
\echo '== Duda: especialidades, lucro por especialidade e alerta do valor cobrado'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000051","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _r    jsonb;
  _ca   bigint;
  _sg   bigint;
  _si   bigint;
  _p1   bigint;
  _p2   bigint;
  _pr   jsonb;
  _prof bigint;
  _uu   uuid := '0d6a1f3e-1b2c-4d5e-8f90-000000000005';
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Especialidade"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);

  perform ad.pricing_param_save(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
            'params', jsonb_build_object('vl_structure_hour_manual', 60, 'vl_professional_hour', 60,
                                         'pc_card', 4, 'pc_commission', 6,
                                         'it_tax_regime', 2, 'pc_tax_pj', 10, 'pc_profit', 30),
            'expenses', '[]'::jsonb, 'fees', '[]'::jsonb));

  -- cadastro
  _r  := ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', 'Clínica Geral'));
  _sg := (_r ->> 'nr_specialty')::bigint;
  assert _sg = 1, 'nr_specialty sequencial';
  _r  := ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', '  Implante ', 'pc_profit', 20));
  _si := (_r ->> 'nr_specialty')::bigint;
  assert (select vc_name from od.specialty where nr_company = _ca and nr_specialty = _si) = 'Implante', 'nome sem espacos';

  begin
    perform ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'implante'));
    raise exception 'FALHA: nome repetido aceito';
  exception when others then
    if sqlerrm not like '%SPECIALTY_NAME_IN_USE%' then raise; end if;
  end;
  begin
    perform ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', ' '));
    raise exception 'FALHA: nome vazio aceito';
  exception when others then
    if sqlerrm not like '%SPECIALTY_NAME_REQUIRED%' then raise; end if;
  end;
  begin
    perform ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'HOF', 'pc_profit', 101));
    raise exception 'FALHA: lucro acima de 100 aceito';
  exception when others then
    if sqlerrm not like '%SPECIALTY_PERCENT_INVALID%' then raise; end if;
  end;
  begin
    perform ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_specialty', 99, 'vc_name', 'X'));
    raise exception 'FALHA: especialidade inexistente alterada';
  exception when others then
    if sqlerrm not like '%SPECIALTY_NOT_FOUND%' then raise; end if;
  end;
  begin
    perform ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'X', 'nr_company', _ca, 'nr_branch', 1));
    raise exception 'FALHA: acao invalida aceita';
  exception when others then
    if sqlerrm not like '%SPECIALTY_ACTION_INVALID%' then raise; end if;
  end;

  -- procedimentos ligados as especialidades
  _r  := ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', 'Implante unitário', 'nr_specialty', _si,
           'qt_minutes', 60, 'vl_material_other', 30, 'vl_current_price', 260));
  _p1 := (_r ->> 'nr_procedure')::bigint;
  _r  := ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', 'Profilaxia', 'nr_specialty', _sg,
           'qt_minutes', 60, 'vl_material_other', 30));
  _p2 := (_r ->> 'nr_procedure')::bigint;
  begin
    perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'Z', 'nr_specialty', 99));
    raise exception 'FALHA: especialidade inexistente aceita no procedimento';
  exception when others then
    if sqlerrm not like '%PROCEDURE_SPECIALTY_INVALID%' then raise; end if;
  end;

  -- specialty_list: ordem por nome e contagem de procedimentos
  _r := ad.specialty_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'specialties') = 2, '2 especialidades';
  assert _r -> 'specialties' -> 0 ->> 'vc_name' = 'Clínica Geral', 'ordem por nome';
  assert (_r -> 'specialties' -> 1 ->> 'pc_profit')::numeric = 20, 'lucro da especialidade';
  assert (_r -> 'specialties' -> 1 ->> 'qt_procedures')::int = 1, 'Implante com 1 procedimento';

  -- lucro: especialidade (20%) x filial (30%) x proprio
  _r := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _si));
  assert jsonb_array_length(_r -> 'procedures') = 1, 'filtro por especialidade';
  assert _r -> 'procedures' -> 0 ->> 'vc_specialty' = 'Implante', 'nome da especialidade no procedimento';
  _pr := _r -> 'procedures' -> 0 -> 'pricing';
  assert (_pr ->> 'vl_direct_cost')::numeric = 150,    'custo direto 150, veio ' || (_pr ->> 'vl_direct_cost');
  assert (_pr ->> 'vl_price')::numeric       = 250,    'preco com lucro da especialidade 250, veio ' || (_pr ->> 'vl_price');
  assert (_pr ->> 'vl_price_min')::numeric   = 187.50, 'preco minimo 187,50, veio ' || (_pr ->> 'vl_price_min');

  _r := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'vc_search', 'geral'));
  assert jsonb_array_length(_r -> 'procedures') = 1, 'busca pelo nome da especialidade';
  assert (_r -> 'procedures' -> 0 -> 'pricing' ->> 'vl_price')::numeric = 300, 'especialidade sem lucro usa o da filial';
  assert (_r -> 'procedures' -> 0 -> 'pricing' ->> 'it_price_status')::int = 0, 'sem valor cobrado: status 0';
  assert not (_r -> 'procedures' -> 0 -> 'alerts' ? 'PRICE_BELOW_COST'), 'sem valor cobrado nao gera alerta de preco';

  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_procedure', _p2, 'pc_profit', 40));
  _r := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _sg));
  assert (_r -> 'procedures' -> 0 -> 'pricing' ->> 'vl_price')::numeric = 375, 'lucro proprio vence o da especialidade';

  -- valor cobrado: ok (260 >= 250)
  _r  := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _si));
  _pr := _r -> 'procedures' -> 0 -> 'pricing';
  assert (_pr ->> 'it_price_status')::int = 1, 'cobrado 260 ok';
  assert (_pr ->> 'vl_current_diff')::numeric = 10, 'diferenca 260 - 250';
  -- lucro hoje: 260 - 150 - 26 (cartao+comissao) - 26 (IR PJ) = 58 -> 22,31%
  assert (_pr ->> 'vl_current_profit')::numeric = 58, 'lucro com o valor cobrado 58, veio ' || (_pr ->> 'vl_current_profit');
  assert (_pr ->> 'pc_current_profit')::numeric = 22.31, 'margem com o valor cobrado 22,31%';
  assert _r -> 'procedures' -> 0 -> 'alerts' = '[]'::jsonb, 'sem alertas, veio ' || (_r -> 'procedures' -> 0 ->> 'alerts');

  -- abaixo do sugerido / do minimo / do custo
  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_procedure', _p1, 'vl_current_price', 200));
  _r := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _si));
  assert (_r -> 'procedures' -> 0 -> 'pricing' ->> 'it_price_status')::int = 2, 'cobrado 200: abaixo do sugerido';
  assert _r -> 'procedures' -> 0 -> 'alerts' ? 'PRICE_BELOW_SUGGESTED', 'alerta PRICE_BELOW_SUGGESTED';

  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_procedure', _p1, 'vl_current_price', 160));
  _r := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _si));
  assert (_r -> 'procedures' -> 0 -> 'pricing' ->> 'it_price_status')::int = 3, 'cobrado 160: abaixo do minimo';
  assert _r -> 'procedures' -> 0 -> 'alerts' = '["PRICE_BELOW_MIN"]'::jsonb, 'so PRICE_BELOW_MIN';

  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_procedure', _p1, 'vl_current_price', 120));
  _r  := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _si));
  _pr := _r -> 'procedures' -> 0 -> 'pricing';
  assert (_pr ->> 'it_price_status')::int = 4, 'cobrado 120: abaixo do custo';
  assert _r -> 'procedures' -> 0 -> 'alerts' = '["PRICE_BELOW_COST"]'::jsonb, 'so PRICE_BELOW_COST';
  -- PJ: 120 - 150 - 12 - 12 = -54
  assert (_pr ->> 'vl_current_profit')::numeric = -54, 'prejuizo PJ -54, veio ' || (_pr ->> 'vl_current_profit');
  -- PF: IR sobre o lucro, que e negativo -> IR zero: 120 - 150 - 12 = -42
  _r  := ad.procedure_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _si,
           'it_tax_regime', 1));
  assert (_r -> 'procedures' -> 0 -> 'pricing' ->> 'vl_current_profit')::numeric = -42, 'prejuizo PF sem IR -42';

  -- especialidade inativa: some da lista, procedimento continua nela, nao aceita vinculo novo
  perform ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_specialty', _si, 'it_status', 90));
  _r := ad.specialty_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'specialties') = 1, 'inativa some da lista padrao';
  _r := ad.specialty_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'id_include_inactive', true));
  assert jsonb_array_length(_r -> 'specialties') = 2, 'id_include_inactive traz as 2';
  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_procedure', _p1, 'nr_specialty', _si, 'qt_minutes', 60));
  begin
    perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_procedure', _p2, 'nr_specialty', _si));
    raise exception 'FALHA: procedimento ligado a especialidade inativa';
  exception when others then
    if sqlerrm not like '%PROCEDURE_SPECIALTY_INVALID%' then raise; end if;
  end;
  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_procedure', _p2, 'nr_specialty', null));
  assert (select nr_specialty from od.procedure where nr_company = _ca and nr_procedure = _p2) is null, 'null desliga a especialidade';

  -- perfil Financeiro (PRICING ler + criar) para a Eva
  _r := ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Financeiro', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', _uu, 'id_read', true, 'id_create', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_email', 'eva.esp@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));

  -- log de atividades
  assert (select count(*) from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'specialty') = 3,
    'eventos de especialidade (2 criadas + 1 inativada)';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Eva (Financeiro): cria, nao altera'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000052","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
  _r  jsonb;
begin
  _r := ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Ortodontia', 'pc_profit', 30));
  begin
    perform ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_specialty', (_r ->> 'nr_specialty')::bigint, 'pc_profit', 10));
    raise exception 'FALHA: Eva alterou especialidade';
  exception when others then
    if sqlerrm not like '%SPECIALTY_FORBIDDEN%' then raise; end if;
  end;
  assert (select count(*) from od.specialty) = 3, 'RLS: Eva ve as especialidades da filial';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.specialty_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou specialty_list';
  exception when insufficient_privilege then null;
  end;
  begin
    perform count(*) from od.specialty;
    raise exception 'FALHA: anon leu od.specialty';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 08_specialties'
