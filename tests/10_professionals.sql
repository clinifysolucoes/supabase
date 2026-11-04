-- ============================================================================
-- Agenda, parte 1: profissionais e horario de atendimento
-- (ad.professional_list / ad.professional_save, tela AGENDA).
--   Hana = administradora da empresa
--   Ivo  = perfil "Recepcao": AGENDA ler + criar (sem alterar)
--   Jade = usuario sem empresa
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/10_professionals.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000071', 'hana.ag@test.local', '{"name": "Hana Agenda"}'),
  ('00000000-0000-0000-0000-000000000072', 'ivo.ag@test.local',  '{"name": "Ivo Agenda"}'),
  ('00000000-0000-0000-0000-000000000073', 'jade.ag@test.local', '{"name": "Jade Agenda"}');

do $$
begin
  assert (select uu_screen from ad.screen where vc_code = 'AGENDA') = '0d6a1f3e-1b2c-4d5e-8f90-000000000007',
    'tela AGENDA deveria existir com o uuid fixo';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Hana: cadastro de profissionais e horarios'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000071","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _r     jsonb;
  _ca    bigint;
  _p1    bigint;
  _p2    bigint;
  _hana  bigint := (select nr_user from ad.app_user where vc_email = 'hana.ag@test.local');
  _prof  bigint;
  _uu    uuid := '0d6a1f3e-1b2c-4d5e-8f90-000000000007';
  _pr    jsonb;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Agenda"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);

  -- sem cor: paleta padrao; horario manha + tarde na segunda, manha no sabado
  _r  := ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', '  Dra. Ana ', 'vc_council', 'CRO-PR 12345', 'nr_user', _hana,
           'schedules', jsonb_build_array(
             jsonb_build_object('it_weekday', 1, 'qt_minute_start', 840, 'qt_minute_end', 1080),
             jsonb_build_object('it_weekday', 1, 'qt_minute_start', 480, 'qt_minute_end', 720),
             jsonb_build_object('it_weekday', 6, 'qt_minute_start', 480, 'qt_minute_end', 720))));
  _p1 := (_r ->> 'nr_professional')::bigint;
  assert _p1 = 1, 'nr_professional sequencial';
  _r  := ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', 'Dr. Bruno', 'vc_color', '#2ed3c6', 'qt_slot_minutes', 20));
  _p2 := (_r ->> 'nr_professional')::bigint;

  assert (select vc_name || '|' || vc_color || '|' || qt_slot_minutes from od.professional where nr_company = _ca and nr_professional = _p1)
       = 'Dra. Ana|#0E8C86|30', 'nome sem espacos, cor da paleta e intervalo padrao';
  assert (select vc_color from od.professional where nr_company = _ca and nr_professional = _p2) = '#2ED3C6', 'cor em maiusculas';

  _r := ad.professional_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'professionals') = 2, '2 profissionais';
  _pr := _r -> 'professionals' -> 1;
  assert _pr ->> 'vc_name' = 'Dra. Ana', 'ordem por nome';
  assert _pr ->> 'vc_user_name' = 'Hana Agenda', 'usuario vinculado';
  assert jsonb_array_length(_pr -> 'schedules') = 3, '3 faixas';
  assert (_pr -> 'schedules' -> 0 ->> 'qt_minute_start')::int = 480, 'faixas em ordem de dia e hora';
  assert jsonb_array_length(_r -> 'users') = 1, 'usuarios ativos da empresa para o vinculo';

  -- validacoes
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'dra. ana'));
    raise exception 'FALHA: nome repetido aceito';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_NAME_IN_USE%' then raise; end if;
  end;
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'X', 'vc_color', 'verde'));
    raise exception 'FALHA: cor invalida aceita';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_COLOR_INVALID%' then raise; end if;
  end;
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'X', 'qt_slot_minutes', 2));
    raise exception 'FALHA: intervalo invalido aceito';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_SLOT_INVALID%' then raise; end if;
  end;
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
              'vc_name', 'X', 'nr_user', 999999));
    raise exception 'FALHA: usuario fora da empresa aceito';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_USER_INVALID%' then raise; end if;
  end;
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_professional', _p2, 'nr_user', _hana));
    raise exception 'FALHA: usuario em dois profissionais';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_USER_IN_USE%' then raise; end if;
  end;
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_professional', _p2, 'schedules', jsonb_build_array(
                jsonb_build_object('it_weekday', 7, 'qt_minute_start', 480, 'qt_minute_end', 720))));
    raise exception 'FALHA: dia da semana invalido aceito';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_SCHEDULE_INVALID%' then raise; end if;
  end;
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_professional', _p2, 'schedules', jsonb_build_array(
                jsonb_build_object('it_weekday', 2, 'qt_minute_start', 720, 'qt_minute_end', 600))));
    raise exception 'FALHA: faixa invertida aceita';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_SCHEDULE_INVALID%' then raise; end if;
  end;
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_professional', _p2, 'schedules', jsonb_build_array(
                jsonb_build_object('it_weekday', 3, 'qt_minute_start', 480, 'qt_minute_end', 720),
                jsonb_build_object('it_weekday', 3, 'qt_minute_start', 700, 'qt_minute_end', 900))));
    raise exception 'FALHA: faixas sobrepostas aceitas';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_SCHEDULE_OVERLAP%' then raise; end if;
  end;
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_professional', 99, 'vc_name', 'X'));
    raise exception 'FALHA: profissional inexistente alterado';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_NOT_FOUND%' then raise; end if;
  end;

  -- update parcial: horario substituido, faixas encostadas (12h-12h) valem, sem horario nao mexe
  perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_professional', _p2, 'schedules', jsonb_build_array(
              jsonb_build_object('it_weekday', 3, 'qt_minute_start', 480, 'qt_minute_end', 720),
              jsonb_build_object('it_weekday', 3, 'qt_minute_start', 720, 'qt_minute_end', 1080))));
  assert (select count(*) from od.professional_schedule where nr_company = _ca and nr_professional = _p2) = 2, 'faixas encostadas';
  perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_professional', _p1, 'vc_council', null, 'nr_user', null));
  assert (select vc_council is null and nr_user is null from od.professional where nr_company = _ca and nr_professional = _p1),
    'null limpa conselho e desvincula usuario';
  assert (select count(*) from od.professional_schedule where nr_company = _ca and nr_professional = _p1) = 3,
    'sem schedules o horario fica';

  -- inativar
  perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_professional', _p2, 'it_status', 90));
  _r := ad.professional_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'professionals') = 1, 'inativo some da lista padrao';
  _r := ad.professional_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'id_include_inactive', true));
  assert jsonb_array_length(_r -> 'professionals') = 2, 'id_include_inactive traz os 2';

  -- perfil Recepcao (AGENDA ler + criar) para o Ivo
  _r := ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', _uu, 'id_read', true, 'id_create', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_email', 'ivo.ag@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));

  assert (select count(*) from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'professional') = 5,
    'eventos de profissional (2 criados + 3 alterados), veio '
      || (select count(*) from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'professional');
end $$;

-- ----------------------------------------------------------------------------
\echo '== Ivo (Recepcao): le e cria, nao altera'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000072","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
  _r  jsonb;
begin
  _r := ad.professional_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
  assert jsonb_array_length(_r -> 'professionals') = 1, 'Ivo le os profissionais';
  perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_name', 'ASB Carla'));
  begin
    perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_professional', 1, 'vc_name', 'Outro'));
    raise exception 'FALHA: Ivo alterou profissional';
  exception when others then
    if sqlerrm not like '%PROFESSIONAL_FORBIDDEN%' then raise; end if;
  end;
  assert (select count(*) from od.professional) = 3, 'RLS: Ivo ve os profissionais da filial';
  assert (select count(*) from od.professional_schedule) = 5, 'RLS: Ivo ve os horarios da filial';
end $$;

-- ----------------------------------------------------------------------------
\echo '== Jade (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000073","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
begin
  begin
    perform ad.professional_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1));
    raise exception 'FALHA: Jade leu profissionais de outra empresa';
  exception when others then
    if sqlerrm not like '%AGENDA_FORBIDDEN%' then raise; end if;
  end;
  assert (select count(*) from od.professional) = 0, 'RLS: Jade nao ve profissionais';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.professional_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou professional_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 10_professionals'
