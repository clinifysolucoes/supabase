-- ============================================================================
-- Teste de RLS e das functions RPC, simulando o PostgREST:
--   set_config('request.jwt.claims', ...) + SET LOCAL ROLE authenticated
-- Roda numa unica transacao e termina com ROLLBACK (banco fica limpo).
-- Ids gerados sao guardados em GUCs test.* (psql nao interpola :var dentro de $$).
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/01_rls_smoke.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios no Supabase Auth (trigger cria ad.app_user)'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000001', 'ana@test.local', '{"name": "Ana Admin"}'),
  ('00000000-0000-0000-0000-000000000002', 'bia@test.local', '{"name": "Bia"}'),
  ('00000000-0000-0000-0000-000000000003', 'caio@test.local', '{}');

do $$
begin
  assert (select count(*) from ad.app_user where vc_email like '%@test.local') = 3,
    'trigger auth.users -> ad.app_user nao criou os 3 usuarios';
  assert (select vc_name from ad.app_user where vc_email = 'caio@test.local') = 'caio',
    'nome default deveria ser a parte local do e-mail';
  perform set_config('test.nr_user_ana', (select nr_user::text from ad.app_user where vc_email = 'ana@test.local'), false);
  perform set_config('test.nr_user_bia', (select nr_user::text from ad.app_user where vc_email = 'bia@test.local'), false);
end $$;

-- ----------------------------------------------------------------------------
\echo '== anon: nenhum acesso ao schema ad'
set local role anon;
do $$
begin
  begin
    perform count(*) from ad.company;
    raise exception 'FALHA: anon conseguiu ler ad.company';
  exception when insufficient_privilege then null;
  end;
  begin
    perform ad.session_context('{}'::jsonb);
    raise exception 'FALHA: anon conseguiu chamar ad.session_context';
  exception when insufficient_privilege then null;
  end;
  begin
    perform private.fn_my_branches();
    raise exception 'FALHA: anon conseguiu chamar private.fn_my_branches';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- ----------------------------------------------------------------------------
\echo '== Ana (authenticated) cria a empresa A'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

do $$
begin
  begin
    perform ad.company_create('{"nr_version": 2, "vc_name": "X"}'::jsonb);
    raise exception 'FALHA: versao errada aceita';
  exception when others then
    assert sqlerrm like '%VERSION_MISMATCH%', 'esperado VERSION_MISMATCH, veio: ' || sqlerrm;
  end;
  begin
    perform ad.company_create('{"nr_version": 1, "vc_name": "X", "vc_cnpj": "11.222.333/0001-80"}'::jsonb);
    raise exception 'FALHA: CNPJ invalido aceito';
  exception when others then
    assert sqlerrm like '%COMPANY_CREATE_CNPJ_INVALID%', 'esperado CNPJ_INVALID, veio: ' || sqlerrm;
  end;
  begin
    perform ad.company_create('{"nr_version": 1, "vc_name": "  "}'::jsonb);
    raise exception 'FALHA: nome vazio aceito';
  exception when others then
    assert sqlerrm like '%COMPANY_CREATE_NAME_REQUIRED%', 'esperado NAME_REQUIRED, veio: ' || sqlerrm;
  end;

  perform set_config('test.nr_company_a',
    ad.company_create('{"nr_version": 1, "vc_name": "Clinica A", "vc_cnpj": "11.222.333/0001-81", "vc_email": "Contato@A.local", "vc_state": "sp"}'::jsonb) ->> 'nr_company',
    false);

  assert (select count(*) from ad.company) = 1, 'Ana deve ver exatamente 1 empresa';
  assert (select vc_cnpj from ad.company) = '11222333000181', 'CNPJ deveria estar normalizado';
  assert (select vc_email from ad.company) = 'contato@a.local', 'e-mail deveria estar em minusculo';
  assert (select vc_state from ad.company) = 'SP', 'UF deveria estar em maiusculo';
  assert (select count(*) from ad.branch where id_main) = 1, 'matriz nao criada';
  assert (select count(*) from ad.access_profile) = 2, 'perfis padrao nao criados';
  assert (select count(*) from ad.company_user) = 1, 'vinculo empresa x usuario do criador nao criado';
  assert (select count(*) from ad.branch_user_profile) = 1, 'vinculo filial x usuario x perfil do criador nao criado';
  assert (select nr_operator from ad.company) = (select private.fn_current_user_nr()), 'trigger de auditoria nao gravou nr_operator';
end $$;

\echo '== Ana: escrita direta e function interna sao negadas'
do $$
begin
  begin
    insert into ad.company (vc_name) values ('hack');
    raise exception 'FALHA: INSERT direto permitido em ad.company';
  exception when insufficient_privilege then null;
  end;
  begin
    update ad.company set vc_name = 'hack';
    raise exception 'FALHA: UPDATE direto permitido em ad.company';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from ad.branch_user_profile;
    raise exception 'FALHA: DELETE direto permitido';
  exception when insufficient_privilege then null;
  end;
  begin
    perform ad.fn_company_has_admin(1);
    raise exception 'FALHA: function interna executavel por authenticated';
  exception when insufficient_privilege then null;
  end;
end $$;

\echo '== Ana: session_context'
do $$
declare _s jsonb;
begin
  _s := ad.session_context('{"it_app": 1, "vc_device": "teste"}'::jsonb);
  assert _s -> 'user' ->> 'vc_name' = 'Ana Admin', 'user.vc_name errado';
  assert jsonb_array_length(_s -> 'companies') = 1, 'Ana deveria ter 1 empresa na sessao';
  assert (_s -> 'companies' -> 0 ->> 'id_admin')::boolean, 'Ana deveria ser admin';
  assert jsonb_array_length(_s -> 'companies' -> 0 -> 'branches') = 1, 'Ana deveria ter 1 filial';
  assert (_s -> 'companies' -> 0 -> 'branches' -> 0 ->> 'it_level')::int = 100, 'nivel da filial deveria ser 100';
  assert jsonb_array_length(_s -> 'blocked') = 0, 'Ana nao deveria ter bloqueios';
  assert (select count(*) from ad.access_log) = 1, 'access_log deveria ter 1 linha visivel para Ana';
end $$;

\echo '== Ana: user_update com CPF'
do $$
begin
  begin
    perform ad.user_update('{"nr_version": 1, "vc_cpf": "111.111.111-11"}'::jsonb);
    raise exception 'FALHA: CPF invalido aceito';
  exception when others then
    assert sqlerrm like '%USER_UPDATE_CPF_INVALID%', 'esperado CPF_INVALID, veio: ' || sqlerrm;
  end;
  assert (ad.user_update('{"nr_version": 1, "vc_cpf": "529.982.247-25", "vc_mobile": "11999990000"}'::jsonb) ->> 'vc_cpf') = '52998224725',
    'CPF valido nao gravado normalizado';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Bia cria a empresa B e so enxerga a B'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

do $$
declare _ca bigint := current_setting('test.nr_company_a')::bigint;
begin
  perform set_config('test.nr_company_b',
    ad.company_create('{"nr_version": 1, "vc_name": "Clinica B"}'::jsonb) ->> 'nr_company', false);

  assert (select count(*) from ad.company) = 1, 'Bia deve ver exatamente 1 empresa';
  assert (select vc_name from ad.company) = 'Clinica B', 'Bia deveria ver so a Clinica B';
  assert (select count(*) from ad.app_user) = 1, 'Bia deve ver so o proprio cadastro';
  begin
    perform ad.company_update(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_name', 'hack'));
    raise exception 'FALHA: Bia alterou a empresa da Ana';
  exception when others then
    assert sqlerrm like '%COMPANY_UPDATE_FORBIDDEN%', 'esperado FORBIDDEN, veio: ' || sqlerrm;
  end;
end $$;

-- ----------------------------------------------------------------------------
\echo '== Ana vincula Bia na empresa A (perfil Usuario, matriz)'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company_a')::bigint;
  _ub bigint := current_setting('test.nr_user_bia')::bigint;
begin
  begin
    perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca,
      'vc_email', 'ninguem@test.local', 'branches', '[{"nr_branch": 1, "nr_profile": 2}]'::jsonb));
    raise exception 'FALHA: e-mail inexistente aceito';
  exception when others then
    assert sqlerrm like '%COMPANY_USER_EMAIL_NOT_FOUND%', 'esperado EMAIL_NOT_FOUND, veio: ' || sqlerrm;
  end;
  begin
    perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca,
      'vc_email', 'bia@test.local', 'branches', '[]'::jsonb));
    raise exception 'FALHA: vinculo sem filial aceito';
  exception when others then
    assert sqlerrm like '%COMPANY_USER_BRANCHES_REQUIRED%', 'esperado BRANCHES_REQUIRED, veio: ' || sqlerrm;
  end;
  begin
    perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca,
      'vc_email', 'bia@test.local', 'branches', '[{"nr_branch": 99, "nr_profile": 2}]'::jsonb));
    raise exception 'FALHA: filial inexistente aceita';
  exception when others then
    assert sqlerrm like '%COMPANY_USER_BRANCH_INVALID%', 'esperado BRANCH_INVALID, veio: ' || sqlerrm;
  end;

  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca,
    'vc_email', 'BIA@test.local', 'branches', '[{"nr_branch": 1, "nr_profile": 2}]'::jsonb));

  assert (select count(*) from ad.company_user) = 2, 'Ana (admin) deve ver os 2 vinculos da empresa A';
  assert (select count(*) from ad.app_user) = 2, 'Ana (admin) deve ver o cadastro da Bia';
  assert (select nr_company_user from ad.company_user where nr_user = _ub) = 2, 'Bia deveria ser o usuario 2 da empresa';
end $$;

\echo '== Bia agora enxerga A e B; nao e admin de A'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca bigint := current_setting('test.nr_company_a')::bigint;
  _s  jsonb;
begin
  assert (select count(*) from ad.company) = 2, 'Bia deve ver 2 empresas';
  _s := ad.session_context('{}'::jsonb);
  assert jsonb_array_length(_s -> 'companies') = 2, 'sessao da Bia deveria ter 2 empresas';
  assert not (select (c ->> 'id_admin')::boolean from jsonb_array_elements(_s -> 'companies') c where (c ->> 'nr_company')::bigint = _ca),
    'Bia nao deveria ser admin da A';
  assert (select count(*) from ad.company_user) = 2, 'Bia ve so os proprios vinculos (A e B)';
  assert (select count(*) from ad.app_user) = 1, 'Bia nao administra ninguem alem dela: ve so o proprio cadastro';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Ana bloqueia Bia na empresa A; Bia perde o acesso e ve o motivo'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U',
    'nr_company', current_setting('test.nr_company_a')::bigint,
    'nr_user',    current_setting('test.nr_user_bia')::bigint,
    'it_status', 80, 'vc_block_reason', 'Teste de bloqueio'));
end $$;

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
do $$
declare _s jsonb;
begin
  assert (select count(*) from ad.company) = 1, 'Bia bloqueada deve ver so a B';
  _s := ad.session_context('{}'::jsonb);
  assert jsonb_array_length(_s -> 'companies') = 1, 'sessao da Bia deveria ter 1 empresa';
  assert jsonb_array_length(_s -> 'blocked') = 1, 'sessao da Bia deveria ter 1 bloqueio';
  assert _s -> 'blocked' -> 0 ->> 'vc_reason_key' = 'SESSION_USER_COMPANY_BLOCKED', 'chave do motivo errada';
  assert _s -> 'blocked' -> 0 ->> 'vc_reason' = 'Teste de bloqueio', 'motivo nao veio';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Ana cria filial 2, nao consegue sair sendo a unica admin, promove Bia e sai'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca bigint := current_setting('test.nr_company_a')::bigint;
  _ua bigint := current_setting('test.nr_user_ana')::bigint;
  _ub bigint := current_setting('test.nr_user_bia')::bigint;
  _r  jsonb;
begin
  _r := ad.branch_create(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_name', 'Unidade Centro', 'vc_timezone', 'America/Manaus'));
  assert (_r ->> 'nr_branch')::int = 2, 'segunda filial deveria ser nr_branch 2';
  assert (select count(*) from private.fn_my_branches()) = 2, 'Ana deveria acessar 2 filiais';
  assert (select vc_timezone from ad.branch where nr_branch = 2) = 'America/Manaus', 'timezone nao gravado';

  begin
    perform ad.branch_create(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'vc_name', 'X', 'vc_timezone', 'Marte/Olympus'));
    raise exception 'FALHA: timezone invalido aceito';
  exception when others then
    assert sqlerrm like '%BRANCH_CREATE_TIMEZONE_INVALID%', 'esperado TIMEZONE_INVALID, veio: ' || sqlerrm;
  end;

  begin
    perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'D', 'nr_company', _ca, 'nr_user', _ua));
    raise exception 'FALHA: unica admin conseguiu sair da empresa';
  exception when others then
    assert sqlerrm like '%COMPANY_USER_LAST_ADMIN%', 'esperado LAST_ADMIN, veio: ' || sqlerrm;
  end;

  begin
    perform ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_profile', 1, 'it_level', 50));
    raise exception 'FALHA: rebaixou o unico perfil admin';
  exception when others then
    assert sqlerrm like '%ACCESS_PROFILE_LAST_ADMIN%', 'esperado LAST_ADMIN (perfil), veio: ' || sqlerrm;
  end;

  _r := ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'vc_name', 'Dentista', 'it_level', 10));
  assert (_r ->> 'nr_profile')::int = 3, 'novo perfil deveria ser 3';

  /* reativa Bia como admin nas duas filiais e Ana sai */
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_user', _ub,
    'it_status', 1, 'branches', '[{"nr_branch": 1, "nr_profile": 1}, {"nr_branch": 2, "nr_profile": 1}]'::jsonb));
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'D', 'nr_company', _ca, 'nr_user', _ua));

  assert (select count(*) from ad.company) = 0, 'Ana saiu: nao deveria ver empresa nenhuma';
  assert jsonb_array_length(ad.session_context('{}'::jsonb) -> 'companies') = 0, 'sessao da Ana deveria estar vazia (onboarding)';
end $$;

\echo '== Bia e admin da A com 2 filiais e motivo de bloqueio limpo'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca bigint := current_setting('test.nr_company_a')::bigint;
  _s  jsonb;
begin
  _s := ad.session_context('{}'::jsonb);
  assert jsonb_array_length(_s -> 'companies') = 2, 'Bia deveria ter 2 empresas';
  assert (select jsonb_array_length(c -> 'branches') from jsonb_array_elements(_s -> 'companies') c where (c ->> 'nr_company')::bigint = _ca) = 2,
    'Bia deveria ter 2 filiais na A';
  assert (select vc_block_reason from ad.company_user where nr_company = _ca) is null, 'motivo deveria ter sido limpo ao reativar';
  assert (select count(*) from ad.company_user where nr_company = _ca) = 1, 'so Bia deveria restar na A';
  assert (select count(*) from ad.app_user) = 1, 'Bia administra A e B, mas so ela esta vinculada: ve so o proprio cadastro';
end $$;

reset role;
rollback;
\o
\echo 'OK: 01_rls_smoke'
