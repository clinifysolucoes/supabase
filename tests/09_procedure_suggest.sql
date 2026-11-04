-- ============================================================================
-- Auto complete do cadastro de procedimento (ad.procedure_suggest): catalogo de
-- referencia (od.procedure_template) da especialidade, sem o que a filial ja
-- cadastrou, e procedimentos ja cadastrados para copiar.
--   Fabi = administradora da empresa
--   Gil  = usuario sem empresa
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/09_procedure_suggest.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000061', 'fabi.sug@test.local', '{"name": "Fabi Sug"}'),
  ('00000000-0000-0000-0000-000000000062', 'gil.sug@test.local',  '{"name": "Gil Sug"}');

do $$
begin
  assert (select count(*) from od.procedure_template) = 67, 'catalogo carregado pela migration (67 da planilha)';
  assert (select count(*) from od.procedure_template where vc_specialty = 'Clínica Geral') = 22, '22 de Clinica Geral';
  assert (select count(*) from od.procedure_template where vc_specialty = 'Endodontia') = 6, 'endodontia = codigos 4.x';
  assert (select vl_reference_price from od.procedure_template where vc_name = 'PROFILAXIA') = 150, 'valor de referencia da planilha';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Fabi: sugestoes do catalogo e dos procedimentos cadastrados'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000061","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _r   jsonb;
  _ca  bigint;
  _sg  bigint;
  _se  bigint;
  _m   bigint;
  _t   jsonb;
  _qt  integer;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Sugestao"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);

  -- especialidade casada pelo nome, sem diferenciar maiusculas
  _sg := (ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_name', 'clínica geral')) ->> 'nr_specialty')::bigint;
  _se := (ad.specialty_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_name', 'Estética')) ->> 'nr_specialty')::bigint;

  _r  := ad.procedure_suggest(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _sg));
  _qt := jsonb_array_length(_r -> 'templates');
  -- o catalogo nao e legivel direto (RLS sem policy): contagens fixas do seed
  assert _qt = 22, 'todo o catalogo de Clinica Geral, veio ' || _qt;
  assert _r -> 'procedures' = '[]'::jsonb, 'nada cadastrado ainda';
  _t := _r -> 'templates' -> 0;
  assert _t ->> 'vc_name' = 'PROFILAXIA' and _t ->> 'vc_code' = '1.0', 'ordem da planilha';
  assert (_t ->> 'qt_minutes')::numeric = 60 and (_t ->> 'vl_material_other')::numeric = 2
     and (_t ->> 'vl_reference_price')::numeric = 150, 'campos para preencher o formulario';

  _r := ad.procedure_suggest(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _se));
  assert _r -> 'templates' = '[]'::jsonb, 'especialidade fora do catalogo: sem sugestoes';

  _r := ad.procedure_suggest(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
          'nr_specialty', _sg, 'vc_search', 'extra'));
  assert jsonb_array_length(_r -> 'templates') = 6, 'busca no catalogo, veio ' || jsonb_array_length(_r -> 'templates');

  -- cadastrou a profilaxia (nome igual, outra caixa) e usou o codigo 3.0 em outro
  _m := (ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Luva', 'vl_package_price', 40, 'qt_yield', 100)) ->> 'nr_material')::bigint;
  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_code', '1.0', 'vc_name', 'Profilaxia', 'nr_specialty', _sg, 'qt_minutes', 45, 'vl_current_price', 180,
            'materials', jsonb_build_array(jsonb_build_object('nr_material', _m, 'qt_used', 2))));
  perform ad.procedure_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_code', '3.0', 'vc_name', 'Restauração própria', 'nr_specialty', _sg));

  _r := ad.procedure_suggest(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'nr_specialty', _sg));
  assert jsonb_array_length(_r -> 'templates') = _qt - 1, 'profilaxia ja cadastrada sai do catalogo';
  assert not exists (select 1 from jsonb_array_elements(_r -> 'templates') t where t ->> 'vc_name' = 'PROFILAXIA'),
    'sem profilaxia';
  assert (select t ->> 'vc_code' from jsonb_array_elements(_r -> 'templates') t
           where t ->> 'vc_name' = 'RESTAURAÇÃO SIMPLES 1 FACE') is null, 'codigo 3.0 em uso vem nulo';
  assert jsonb_array_length(_r -> 'procedures') = 2, 'cadastrados da especialidade';
  assert _r -> 'procedures' -> 0 ->> 'vc_name' = 'Profilaxia', 'ordem por codigo';
  assert (_r -> 'procedures' -> 0 -> 'materials' -> 0 ->> 'qt_used')::numeric = 2
     and (_r -> 'procedures' -> 0 -> 'materials' -> 0 ->> 'vl_unit_cost')::numeric = 0.40, 'materiais para copiar';
  assert (_r -> 'procedures' -> 0 ->> 'vl_current_price')::numeric = 180, 'valores para copiar';

  -- material inativo nao vai para a copia (o save recusaria)
  perform ad.material_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_material', _m, 'it_status', 90));
  _r := ad.procedure_suggest(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
          'nr_specialty', _sg, 'vc_search', 'profil'));
  assert _r -> 'templates' = '[]'::jsonb and jsonb_array_length(_r -> 'procedures') = 1, 'busca nos dois';
  assert _r -> 'procedures' -> 0 -> 'materials' = '[]'::jsonb, 'material inativo fora da copia';

  -- sem especialidade: catalogo inteiro menos o cadastrado
  _r := ad.procedure_suggest(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'templates') = 66,
    'sem especialidade: catalogo inteiro menos o cadastrado';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Gil (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000062","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
begin
  begin
    perform ad.procedure_suggest(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
    raise exception 'FALHA: Gil leu sugestoes de outra empresa';
  exception when others then
    if sqlerrm not like '%PRICING_FORBIDDEN%' then raise; end if;
  end;
  assert (select count(*) from od.procedure_template) = 0, 'RLS: catalogo nao e lido direto';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.procedure_suggest('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou procedure_suggest';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 09_procedure_suggest'
