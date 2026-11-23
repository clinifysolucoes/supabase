-- ============================================================================
-- Avaliacao no Google depois do atendimento (od.fn_notify_enqueue it_kind 5,
-- ad.notify_settings_save/get). O fuso da filial e ajustado para que "agora"
-- caia ao meio-dia local (dentro da janela de envio 08:00 a 20:59) qualquer
-- que seja a hora em que o teste roda. Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/48_google_review.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f2', 'gil.rv@test.local', '{"name": "Gil Review"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f2","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Gil: configuracao da avaliacao'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _pa   bigint;
  _pb   bigint;
  _pr   bigint;
  _r    jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Review"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Review", "dt_birth": "1990-01-01",
           "vc_cpf": "52998224725", "vc_mobile": "41999991234", "vc_email": "ana@test.local"}'::jsonb) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Bia Review", "dt_birth": "1991-01-01",
           "vc_cpf": "11144477735", "vc_mobile": "41999995678", "vc_email": "bia@test.local"}'::jsonb) ->> 'nr_patient')::bigint;
  _pr := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Rosa"}'::jsonb) ->> 'nr_professional')::bigint;
  perform set_config('test.pa', _pa::text, false);
  -- Ana: duas consultas atendidas (vai uma avaliacao so); Bia: so agendada
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _pr,
            'dh_start', now() - interval '6 hours', 'dh_end', now() - interval '5 hours'));
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _pr,
            'dh_start', now() - interval '4 hours', 'dh_end', now() - interval '3 hours'));
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pb, 'nr_professional', _pr,
            'dh_start', now() - interval '8 hours', 'dh_end', now() - interval '7 hours'));

  _r := ad.notify_settings_get(_base);
  assert not (_r -> 'settings' ->> 'id_review')::boolean and (_r -> 'settings' ->> 'qt_review_hours')::int = 2
     and _r -> 'settings' ->> 'vc_tpl_review' like '%{{avaliacao}}%', 'padroes: ' || _r::text;

  perform pg_temp.expect_error('notify_settings_save', _base || '{"id_review": true}'::jsonb, 'NOTIFY_REVIEW_URL_REQUIRED');
  perform pg_temp.expect_error('notify_settings_save', _base || '{"vc_review_url": "http://g.page/x"}'::jsonb,
                               'NOTIFY_REVIEW_URL_INVALID');
  perform pg_temp.expect_error('notify_settings_save', _base || '{"vc_review_url": "https://g.page/a b"}'::jsonb,
                               'NOTIFY_REVIEW_URL_INVALID');
  perform pg_temp.expect_error('notify_settings_save', _base || '{"qt_review_hours": 0}'::jsonb, 'NOTIFY_VALUE_INVALID');
  perform pg_temp.expect_error('notify_settings_save', _base || '{"vc_tpl_review": " "}'::jsonb, 'NOTIFY_TEMPLATE_INVALID');

  _r := ad.notify_settings_save(_base || '{"id_email": true, "id_reminder": false, "id_booked": false,
          "id_review": true, "vc_review_url": "https://g.page/r/clinica-review/review", "qt_review_hours": 2}'::jsonb);
  _r := ad.notify_settings_get(_base);
  assert (_r -> 'settings' ->> 'id_review')::boolean
     and _r -> 'settings' ->> 'vc_review_url' = 'https://g.page/r/clinica-review/review', 'salvo: ' || _r::text;

  -- sem a URL com a avaliacao ligada: nao deixa limpar
  perform pg_temp.expect_error('notify_settings_save', _base || '{"vc_review_url": null}'::jsonb, 'NOTIFY_REVIEW_URL_REQUIRED');
end $$;

reset role;

-- envelhece as avaliacoes (o trigger de auditoria fixa dh_created; sem triggers so aqui)
create function pg_temp.age_reviews(p_c bigint) returns void language plpgsql as $$
begin
  perform set_config('session_replication_role', 'replica', true);
  update od.notify_message set dh_created = now() - interval '200 days' where nr_company = p_c and it_kind = 5;
  perform set_config('session_replication_role', 'origin', true);
end $$;

-- fuso que deixa "agora" ao meio-dia local
do $$
declare
  _off integer := 12 - extract(hour from now() at time zone 'UTC')::int;
begin
  update ad.branch set vc_timezone = 'Etc/GMT' || case when _off > 0 then '-' || _off when _off < 0 then '+' || (-_off) else '' end
   where nr_company = current_setting('test.c')::bigint and nr_branch = 1;
end $$;

\echo '== fila: so atendidas, uma por paciente, a cada 180 dias'
do $$
declare
  _c  bigint := current_setting('test.c')::bigint;
  _pa bigint := current_setting('test.pa')::bigint;
  _m  od.notify_message;
begin
  -- nenhuma atendida ainda
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 5) = 0, 'sem atendimento, sem avaliacao';

  update od.appointment set it_status = 5 where nr_company = _c;
  -- a consulta da Bia terminou ha 7h, a mais recente da Ana ha 3h: com 4h so a Bia
  update od.notify_setting set qt_review_hours = 4 where nr_company = _c;
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 5) = 2,
    'Bia e Ana (a consulta da Ana de 5h atras ja passou de 4h)';
  select * into _m from od.notify_message where nr_company = _c and it_kind = 5 and nr_patient = _pa;
  assert _m.it_channel = 1 and _m.vc_to = 'ana@test.local', 'por e-mail: ' || row_to_json(_m)::text;
  assert _m.tx_body like 'Olá, Ana!%https://g.page/r/clinica-review/review', 'texto: ' || _m.tx_body;
  assert _m.vc_subject like 'Como foi sua consulta?%', 'assunto';
  assert _m.uu_token is null, 'sem token';

  -- a outra consulta da Ana passa da hora: nao repete (180 dias)
  update od.notify_setting set qt_review_hours = 2 where nr_company = _c;
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 5) = 2, 'uma por paciente';

  -- avaliacao desligada: nada novo mesmo depois de 180 dias
  perform pg_temp.age_reviews(_c);
  update od.notify_setting set id_review = false where nr_company = _c;
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 5) = 2, 'desligada';

  -- ligada de novo depois de 180 dias: pede outra vez (consultas recentes)
  update od.notify_setting set id_review = true where nr_company = _c;
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 5 and nr_patient = _pa) = 2,
    'Ana de novo depois de 180 dias';

  -- consulta antiga (mais de 2 dias de atraso) nao entra
  perform pg_temp.age_reviews(_c);
  update od.appointment set dh_start = dh_start - interval '5 days', dh_end = dh_end - interval '5 days' where nr_company = _c;
  delete from od.notify_message where nr_company = _c and it_kind = 5 and dh_created > now() - interval '1 day';
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 5
            and dh_created > now() - interval '1 day') = 0, 'consulta antiga nao entra';
end $$;

rollback;
\o
\echo 'OK: 48_google_review'
