-- ============================================================================
-- Administrador para imprimir e exportar (ad.access_request,
-- ad.access_authorize, ad.data_export, ad.company_update, ad.settings_get).
--   Eli = administradora da empresa
--   Bia = recepcao (configuracoes: alterar; pacientes: ler)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/46_access_authorization.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', 'eli.aa@test.local', '{"name": "Eli AA"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'bia.aa@test.local', '{"name": "Bia AA"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;
grant execute on function pg_temp.expect_error(text, jsonb, text) to authenticated;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Eli: empresa, Bia e as regras'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _r    jsonb;
  _p    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica AA"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000009', 'id_read', true, 'id_update', true),
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true))));
  _p := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'bia.aa@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _p))));

  -- sem a exigencia: nada a pedir
  _r := ad.access_request(_base || '{"it_kind": 1, "vc_target": "Orçamento 1"}'::jsonb);
  assert not (_r ->> 'id_required')::boolean and _r ->> 'uu_request' is null, 'sem exigencia';
  perform pg_temp.expect_error('access_request', _base || '{"it_kind": 3, "vc_target": "X"}'::jsonb, 'ACCESS_REQUEST_INVALID');

  perform ad.company_update(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'id_auth_print', true, 'id_auth_export', true));
  _r := ad.settings_get(_base);
  assert (_r -> 'security' ->> 'id_auth_print')::boolean and (_r -> 'security' ->> 'id_auth_export')::boolean, 'regras ligadas';
end $$;

\echo '== Bia: pede para exportar'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  perform pg_temp.expect_error('data_export', _base || '{"vc_kind": "patients"}'::jsonb, 'EXPORT_AUTH_REQUIRED');
  _r := ad.access_request(_base || '{"it_kind": 2, "vc_target": "Exportar pacientes"}'::jsonb);
  assert (_r ->> 'id_required')::boolean and _r ->> 'uu_request' is not null, 'pedido aberto';
  perform set_config('test.uu', _r ->> 'uu_request', false);
  -- a propria recepcao nao libera
  perform pg_temp.expect_error('access_authorize', jsonb_build_object('nr_version', 1, 'uu_request', _r ->> 'uu_request'),
            'ACCESS_AUTHORIZE_FORBIDDEN');
  perform pg_temp.expect_error('data_export', _base || jsonb_build_object('vc_kind', 'patients', 'uu_authorization', _r ->> 'uu_request'),
            'EXPORT_AUTH_REQUIRED');
end $$;

\echo '== Eli: libera (sessao do administrador)'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _r jsonb;
begin
  _r := ad.access_authorize(jsonb_build_object('nr_version', 1, 'uu_request', current_setting('test.uu')));
  assert (_r ->> 'id_authorized')::boolean and _r ->> 'vc_admin' = 'Eli AA', 'liberado';
  perform pg_temp.expect_error('access_authorize', jsonb_build_object('nr_version', 1, 'uu_request', current_setting('test.uu')),
            'ACCESS_AUTHORIZE_EXPIRED');
  perform pg_temp.expect_error('access_authorize', jsonb_build_object('nr_version', 1, 'uu_request', gen_random_uuid()),
            'ACCESS_AUTHORIZE_NOT_FOUND');
  assert exists (select 1 from ad.event_log e where e.nr_company = current_setting('test.c')::bigint
                   and e.vc_entity = 'access_authorization' and e.vc_summary like 'Exportação liberada por Eli AA para Bia AA%'),
    'log da liberacao';
end $$;

\echo '== Bia: exporta uma vez'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1,
                                    'vc_kind', 'patients', 'uu_authorization', current_setting('test.uu'));
  _r    jsonb;
begin
  _r := ad.data_export(_base);
  assert _r ? 'columns', 'exportou';
  perform pg_temp.expect_error('data_export', _base, 'EXPORT_AUTH_REQUIRED');
  -- pedido vencido nao e liberado
  _r := ad.access_request(_base || '{"it_kind": 1, "vc_target": "Recibo 3"}'::jsonb);
  perform set_config('test.uu2', _r ->> 'uu_request', false);
end $$;

reset role;
update ad.access_authorization set dh_expires = now() - interval '1 minute' where uu_request = current_setting('test.uu2')::uuid;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  perform pg_temp.expect_error('access_authorize', jsonb_build_object('nr_version', 1, 'uu_request', current_setting('test.uu2')),
            'ACCESS_AUTHORIZE_EXPIRED');
  assert (select count(*) from ad.access_authorization where nr_company = current_setting('test.c')::bigint) = 2,
    'administradora ve os pedidos';
end $$;

reset role;
rollback;
\o
\echo 'OK: 46_access_authorization'
