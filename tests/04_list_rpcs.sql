-- ============================================================================
-- RPCs de listagem (branch_list, access_profile_list, company_user_list,
-- access_log_list): o que cada papel enxerga.
--   Ana  = administradora da empresa A (matriz + Filial Centro)
--   Bia  = usuaria comum da A, so na matriz
--   Caio = usuario sem empresa
-- Roda numa unica transacao e termina com ROLLBACK (banco fica limpo).
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/04_list_rpcs.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000011', 'ana.list@test.local',  '{"name": "Ana Lista"}'),
  ('00000000-0000-0000-0000-000000000012', 'bia.list@test.local',  '{"name": "Bia Lista"}'),
  ('00000000-0000-0000-0000-000000000013', 'caio.list@test.local', '{"name": "Caio Lista"}');

do $$
begin
  perform set_config('test.nr_user_ana', (select nr_user::text from ad.app_user where vc_email = 'ana.list@test.local'), false);
  perform set_config('test.nr_user_bia', (select nr_user::text from ad.app_user where vc_email = 'bia.list@test.local'), false);
end $$;

-- ----------------------------------------------------------------------------
\echo '== Ana cria a empresa A com 2 filiais, perfil Dentista e vincula Bia na matriz'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000011","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _r  jsonb;
  _ca bigint;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Lista"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company_a', _ca::text, false);

  perform ad.branch_create(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_name', 'Filial Centro'));
  perform ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca,
                                                    'vc_name', 'Dentista', 'it_level', 10));
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca,
                                                  'vc_email', 'bia.list@test.local',
                                                  'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', 2))));
  -- acesso da Ana abrindo a filial 2 (vai para o log)
  perform ad.session_context(jsonb_build_object('it_app', 1, 'nr_company', _ca, 'nr_branch', 2, 'vc_device', 'teste-ana'));
end $$;

-- ----------------------------------------------------------------------------
\echo '== Bia faz login (log sem empresa escolhida)'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000012","role":"authenticated"}', true);
set local role authenticated;
select ad.session_context('{"it_app": 2, "vc_device": "teste-bia"}'::jsonb);

-- ----------------------------------------------------------------------------
\echo '== Ana (admin): listas completas'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000011","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company_a')::bigint;
  _ua bigint := current_setting('test.nr_user_ana')::bigint;
  _ub bigint := current_setting('test.nr_user_bia')::bigint;
  _r  jsonb;
begin
  -- filiais: admin ve as 2
  _r := ad.branch_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert jsonb_array_length(_r -> 'branches') = 2, 'Ana deveria ver 2 filiais';
  assert (_r -> 'branches' -> 0 ->> 'id_main')::boolean, 'matriz deveria vir primeiro';

  -- perfis: 3 ativos, qt_users certo
  _r := ad.access_profile_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert jsonb_array_length(_r -> 'profiles') = 3, 'deveriam ser 3 perfis';
  assert (select (p ->> 'qt_users')::int from jsonb_array_elements(_r -> 'profiles') p where p ->> 'vc_name' = 'Administrador') = 1,
    'Administrador deveria ter 1 usuario';
  assert (select (p ->> 'qt_users')::int from jsonb_array_elements(_r -> 'profiles') p where p ->> 'vc_name' = 'Dentista') = 0,
    'Dentista deveria ter 0 usuarios';
  assert (_r -> 'profiles' -> 0 ->> 'it_level')::int = 100, 'maior nivel deveria vir primeiro';

  -- perfil inativo some do default e aparece com id_include_inactive
  perform ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca,
                                                    'nr_profile', 3, 'it_status', 90));
  _r := ad.access_profile_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert jsonb_array_length(_r -> 'profiles') = 2, 'inativo nao deveria aparecer por default';
  _r := ad.access_profile_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'id_include_inactive', true));
  assert jsonb_array_length(_r -> 'profiles') = 3, 'id_include_inactive deveria trazer o inativo';

  -- usuarios: 2, Bia com 1 filial e perfil Usuario, Ana admin
  _r := ad.company_user_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert (_r ->> 'qt_total')::int = 2, 'deveriam ser 2 usuarios';
  assert (select (u ->> 'id_admin')::boolean from jsonb_array_elements(_r -> 'users') u where (u ->> 'nr_user')::bigint = _ua),
    'Ana deveria ser admin na lista';
  assert (select jsonb_array_length(u -> 'branches') from jsonb_array_elements(_r -> 'users') u where (u ->> 'nr_user')::bigint = _ub) = 1,
    'Bia deveria ter 1 filial';
  assert (select u -> 'branches' -> 0 ->> 'vc_profile' from jsonb_array_elements(_r -> 'users') u where (u ->> 'nr_user')::bigint = _ub) = 'Usuário',
    'perfil da Bia deveria ser Usuário';

  -- filtros e paginacao
  _r := ad.company_user_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_search', 'BIA'));
  assert (_r ->> 'qt_total')::int = 1 and _r -> 'users' -> 0 ->> 'vc_name' = 'Bia Lista', 'busca por nome falhou';
  _r := ad.company_user_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_search', 'ana.list@'));
  assert (_r ->> 'qt_total')::int = 1, 'busca por e-mail falhou';
  _r := ad.company_user_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 2));
  assert (_r ->> 'qt_total')::int = 1 and (_r -> 'users' -> 0 ->> 'nr_user')::bigint = _ua, 'filtro por filial falhou';
  _r := ad.company_user_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'it_status', 80));
  assert (_r ->> 'qt_total')::int = 0 and jsonb_array_length(_r -> 'users') = 0, 'filtro por situacao falhou';
  _r := ad.company_user_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'qt_page_size', 1, 'nr_page', 2));
  assert (_r ->> 'qt_total')::int = 2 and jsonb_array_length(_r -> 'users') = 1 and (_r ->> 'qt_page_size')::int = 1,
    'paginacao falhou';
  begin
    perform ad.company_user_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'it_status', 7));
    raise exception 'FALHA: it_status invalido aceito';
  exception when others then
    if sqlerrm not like '%COMPANY_USER_LIST_STATUS_INVALID%' then raise; end if;
  end;

  -- logs: admin ve o proprio (com filial) e o da Bia (sem empresa)
  _r := ad.access_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert (_r ->> 'qt_total')::int = 2, 'admin deveria ver 2 acessos, viu ' || (_r ->> 'qt_total');
  assert (select count(*) from jsonb_array_elements(_r -> 'logs') l where l ->> 'vc_branch' = 'Filial Centro') = 1,
    'acesso da Ana deveria trazer o nome da filial';
  _r := ad.access_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_user', _ub));
  assert (_r ->> 'qt_total')::int = 1 and (_r -> 'logs' -> 0 ->> 'it_app')::int = 2, 'filtro por usuario falhou';
  _r := ad.access_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'it_app', 3));
  assert (_r ->> 'qt_total')::int = 0, 'filtro por app falhou';
  _r := ad.access_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca,
                                              'dh_from', (now() - interval '1 day')::text, 'dh_to', now()::text));
  assert (_r ->> 'qt_total')::int = 2, 'periodo explicito falhou';
  begin
    perform ad.access_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca,
                                                  'dh_from', now()::text, 'dh_to', (now() - interval '1 day')::text));
    raise exception 'FALHA: periodo invertido aceito';
  exception when others then
    if sqlerrm not like '%ACCESS_LOG_LIST_PERIOD_INVALID%' then raise; end if;
  end;
end $$;

-- ----------------------------------------------------------------------------
\echo '== Bia (usuaria comum): so o que e dela'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000012","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company_a')::bigint;
  _ub bigint := current_setting('test.nr_user_bia')::bigint;
  _r  jsonb;
begin
  _r := ad.branch_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert jsonb_array_length(_r -> 'branches') = 1 and (_r -> 'branches' -> 0 ->> 'id_main')::boolean,
    'Bia deveria ver so a matriz';

  _r := ad.access_profile_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert jsonb_array_length(_r -> 'profiles') = 2, 'Bia deveria listar os perfis ativos';

  begin
    perform ad.company_user_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
    raise exception 'FALHA: usuaria comum listou usuarios da empresa';
  exception when others then
    if sqlerrm not like '%COMPANY_USER_LIST_FORBIDDEN%' then raise; end if;
  end;

  -- mesmo pedindo os acessos da Ana, so recebe os proprios
  _r := ad.access_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca,
                                              'nr_user', current_setting('test.nr_user_ana')::bigint));
  assert (_r ->> 'qt_total')::int = 1 and (_r -> 'logs' -> 0 ->> 'nr_user')::bigint = _ub,
    'Bia deveria ver apenas o proprio acesso';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Caio (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000013","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company_a')::bigint;
begin
  begin
    perform ad.branch_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
    raise exception 'FALHA: usuario de fora listou filiais';
  exception when others then
    if sqlerrm not like '%BRANCH_LIST_FORBIDDEN%' then raise; end if;
  end;
  begin
    perform ad.access_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
    raise exception 'FALHA: usuario de fora listou logs';
  exception when others then
    if sqlerrm not like '%ACCESS_LOG_LIST_FORBIDDEN%' then raise; end if;
  end;
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.branch_list('{"nr_version": 1, "nr_company": 1}'::jsonb);
    raise exception 'FALHA: anon conseguiu chamar ad.branch_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 04_list_rpcs'
