-- ============================================================================
-- Telas (ad.screen), permissoes por perfil (ad.access_profile_screen),
-- permissoes efetivas no session_context, log de atividades (ad.event_log /
-- event_log_list), pre-checagem do cadastro (user_create_check) e metadata
-- de CPF/telefone no trigger do Auth.
--   Ana  = administradora da empresa A
--   Bia  = recepcao da A (perfil "Recepção": USERS leitura, PROFILES leitura+criar)
--   Caio = usuario sem empresa
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/05_screens_permissions.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios (Bia com cpf/telefone na metadata)'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000021', 'ana.perm@test.local',  '{"name": "Ana Perm"}'),
  ('00000000-0000-0000-0000-000000000022', 'bia.perm@test.local',  '{"name": "Bia Perm", "cpf": "529.982.247-25", "phone": "(11) 3333-4444", "mobile": "(11) 98765-4321"}'),
  ('00000000-0000-0000-0000-000000000023', 'caio.perm@test.local', '{"name": "Caio Perm", "cpf": "111.111.111-11"}');

do $$
begin
  assert (select vc_cpf from ad.app_user where vc_email = 'bia.perm@test.local') = '52998224725',
    'trigger deveria gravar o CPF da metadata sem mascara';
  assert (select vc_mobile from ad.app_user where vc_email = 'bia.perm@test.local') = '(11) 98765-4321',
    'trigger deveria gravar o celular da metadata';
  assert (select vc_cpf from ad.app_user where vc_email = 'caio.perm@test.local') is null,
    'CPF invalido na metadata deveria ser ignorado, nao falhar';
  perform set_config('test.nr_user_ana', (select nr_user::text from ad.app_user where vc_email = 'ana.perm@test.local'), false);
  perform set_config('test.nr_user_bia', (select nr_user::text from ad.app_user where vc_email = 'bia.perm@test.local'), false);
end $$;

-- ----------------------------------------------------------------------------
\echo '== Ana: telas, perfil Recepcao com permissoes, vincula Bia'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000021","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _r        jsonb;
  _ca       bigint;
  _uu_users uuid;
  _uu_prof  uuid;
  _uu_logs  uuid;
  _nr_prof  bigint;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Perm"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company_a', _ca::text, false);

  -- catalogo de telas
  _r := ad.screen_list('{"nr_version": 1}'::jsonb);
  assert jsonb_array_length(_r -> 'screens') = 6, 'deveriam existir 6 telas';
  assert _r -> 'screens' -> 0 ->> 'vc_code' = 'DASHBOARD', 'DASHBOARD deveria vir primeiro';
  select (s ->> 'uu_screen')::uuid into _uu_users from jsonb_array_elements(_r -> 'screens') s where s ->> 'vc_code' = 'USERS';
  select (s ->> 'uu_screen')::uuid into _uu_prof  from jsonb_array_elements(_r -> 'screens') s where s ->> 'vc_code' = 'PROFILES';
  select (s ->> 'uu_screen')::uuid into _uu_logs  from jsonb_array_elements(_r -> 'screens') s where s ->> 'vc_code' = 'LOGS';
  assert _uu_users = '0d6a1f3e-1b2c-4d5e-8f90-000000000002', 'uuid da tela USERS deveria ser o fixo do seed';

  -- tela invalida reprova
  begin
    perform ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca,
      'vc_name', 'Ruim', 'screens', jsonb_build_array(jsonb_build_object('uu_screen', 'nao-e-uuid'))));
    raise exception 'FALHA: tela invalida aceita';
  exception when others then
    if sqlerrm not like '%ACCESS_PROFILE_SCREEN_INVALID%' then raise; end if;
  end;

  -- perfil Recepcao: USERS so leitura, PROFILES leitura + criar, LOGS sem nada (ignorada)
  _r := ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(
            jsonb_build_object('uu_screen', _uu_users, 'id_read', true),
            jsonb_build_object('uu_screen', _uu_prof,  'id_read', true, 'id_create', true),
            jsonb_build_object('uu_screen', _uu_logs,  'id_read', false))));
  _nr_prof := (_r ->> 'nr_profile')::bigint;
  perform set_config('test.nr_profile_rec', _nr_prof::text, false);
  assert (select count(*) from ad.access_profile_screen where nr_company = _ca and nr_profile = _nr_prof) = 2,
    'deveriam ter sido gravadas 2 telas (a sem permissao e ignorada)';

  -- lista traz as telas do perfil
  _r := ad.access_profile_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert (select jsonb_array_length(p -> 'screens') from jsonb_array_elements(_r -> 'profiles') p where p ->> 'vc_name' = 'Recepção') = 2,
    'access_profile_list deveria trazer 2 telas da Recepção';
  assert (select (s ->> 'id_create')::boolean from jsonb_array_elements(_r -> 'profiles') p, jsonb_array_elements(p -> 'screens') s
           where p ->> 'vc_name' = 'Recepção' and s ->> 'vc_code' = 'PROFILES'),
    'PROFILES deveria vir com id_create';

  -- substituir as telas em 'U'
  perform ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca,
            'nr_profile', _nr_prof, 'screens', jsonb_build_array(
              jsonb_build_object('uu_screen', _uu_users, 'id_read', true, 'id_update', true))));
  assert (select count(*) from ad.access_profile_screen where nr_company = _ca and nr_profile = _nr_prof) = 1,
    'U com screens deveria substituir todas';
  -- e devolver ao estado anterior
  perform ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca,
            'nr_profile', _nr_prof, 'screens', jsonb_build_array(
              jsonb_build_object('uu_screen', _uu_users, 'id_read', true),
              jsonb_build_object('uu_screen', _uu_prof,  'id_read', true, 'id_create', true))));

  -- Bia na matriz com Recepcao
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_email', 'bia.perm@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _nr_prof))));

  -- admin: session_context traz todas as telas com tudo liberado
  _r := ad.session_context(jsonb_build_object('it_app', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'companies' -> 0 -> 'branches' -> 0 -> 'permissions') = 6,
    'admin deveria ter as 6 telas';
  assert (select bool_and((p ->> 'id_create')::boolean and (p ->> 'id_update')::boolean)
            from jsonb_array_elements(_r -> 'companies' -> 0 -> 'branches' -> 0 -> 'permissions') p),
    'admin deveria poder criar e alterar em todas';

  -- pre-checagem do cadastro
  _r := ad.user_create_check(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_email', 'novo.perm@test.local'));
  assert not (_r ->> 'id_auth_exists')::boolean, 'conta nova nao deveria existir no Auth';
  _r := ad.user_create_check(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_email', 'caio.perm@test.local'));
  assert (_r ->> 'id_auth_exists')::boolean and (_r ->> 'nr_user') is not null, 'Caio existe no Auth e nao esta vinculado';
  begin
    perform ad.user_create_check(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_email', 'bia.perm@test.local'));
    raise exception 'FALHA: Bia ja vinculada deveria reprovar';
  exception when others then
    if sqlerrm not like '%COMPANY_USER_ALREADY_LINKED%' then raise; end if;
  end;
  begin
    perform ad.user_create_check(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_email', 'sem-arroba'));
    raise exception 'FALHA: e-mail invalido aceito';
  exception when others then
    if sqlerrm not like '%USER_CREATE_EMAIL_INVALID%' then raise; end if;
  end;

  -- log de atividades: perfil criado, 2 alteracoes, usuaria vinculada (+ empresa criada)
  _r := ad.event_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert (_r ->> 'qt_total')::int >= 5, 'admin deveria ver os eventos da empresa, viu ' || (_r ->> 'qt_total');
  _r := ad.event_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_action', 'CREATE', 'uu_screen', _uu_prof));
  assert (_r ->> 'qt_total')::int = 1 and _r -> 'events' -> 0 ->> 'vc_summary' like 'Perfil Recepção%',
    'filtro por tela + acao deveria achar o perfil criado';
  _r := ad.event_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_search', 'vinculado'));
  assert (_r ->> 'qt_total')::int = 1 and _r -> 'events' -> 0 ->> 'vc_screen_code' = 'USERS',
    'busca por texto deveria achar o vinculo da Bia';
  begin
    perform ad.event_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_action', 'XPTO'));
    raise exception 'FALHA: acao invalida aceita';
  exception when others then
    if sqlerrm not like '%EVENT_LOG_LIST_ACTION_INVALID%' then raise; end if;
  end;
end $$;

-- ----------------------------------------------------------------------------
\echo '== Bia (Recepcao): permissoes efetivas e o que enxerga'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000022","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company_a')::bigint;
  _ub bigint := current_setting('test.nr_user_bia')::bigint;
  _r  jsonb;
  _p  jsonb;
begin
  _r := ad.session_context(jsonb_build_object('it_app', 2, 'nr_company', _ca, 'nr_branch', 1));
  _p := _r -> 'companies' -> 0 -> 'branches' -> 0 -> 'permissions';
  assert jsonb_array_length(_p) = 3, 'Bia deveria ter DASHBOARD + USERS + PROFILES, tem ' || jsonb_array_length(_p);
  assert (select bool_or(x ->> 'vc_code' = 'LOGS') from jsonb_array_elements(_p) x) is not true, 'Bia nao deveria ter LOGS';
  assert (select (x ->> 'id_create')::boolean from jsonb_array_elements(_p) x where x ->> 'vc_code' = 'PROFILES'),
    'Bia deveria poder criar em PROFILES';
  assert not (select (x ->> 'id_update')::boolean from jsonb_array_elements(_p) x where x ->> 'vc_code' = 'PROFILES'),
    'Bia nao deveria poder alterar em PROFILES';
  assert not (select (x ->> 'id_create')::boolean from jsonb_array_elements(_p) x where x ->> 'vc_code' = 'USERS'),
    'Bia nao deveria poder criar em USERS';

  -- usuaria comum: so os proprios eventos (nenhum ainda)
  _r := ad.event_log_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca));
  assert (_r ->> 'qt_total')::int = 0, 'Bia nao deveria ver eventos da Ana';

  -- e nao pode fazer a pre-checagem do cadastro
  begin
    perform ad.user_create_check(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_email', 'x@test.local'));
    raise exception 'FALHA: usuaria comum fez a pre-checagem';
  exception when others then
    if sqlerrm not like '%USER_CREATE_FORBIDDEN%' then raise; end if;
  end;
end $$;

-- ----------------------------------------------------------------------------
\echo '== Caio (sem empresa) ve o catalogo, anon nao'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000023","role":"authenticated"}', true);
set local role authenticated;
do $$
declare _r jsonb;
begin
  _r := ad.screen_list('{"nr_version": 1}'::jsonb);
  assert jsonb_array_length(_r -> 'screens') = 6, 'qualquer logado lista as telas';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.screen_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou screen_list';
  exception when insufficient_privilege then null;
  end;
  begin
    perform count(*) from ad.screen;
    raise exception 'FALHA: anon leu ad.screen';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 05_screens_permissions'
