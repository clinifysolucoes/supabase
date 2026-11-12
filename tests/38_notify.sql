-- ============================================================================
-- Alertas por e-mail e SMS (ad.notify_settings_get/save, ad.notify_message_list,
-- ad.notify_dispatch e od.fn_notify_enqueue).
--   Ana = administradora da empresa
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/38_notify.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b1', 'ana.notify@test.local', '{"name": "Ana Notify"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Ana: configura os canais'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _lia   bigint;
  _beto  bigint;
  _caio  bigint;
  _prof  bigint;
  _ap    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Notify"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _lia := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Lia Souza", "dt_birth": "1990-01-01",
            "vc_cpf": "52998224725", "vc_mobile": "(41) 99999-1234", "vc_email": "Lia@Test.local"}'::jsonb) ->> 'nr_patient')::bigint;
  _beto := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Beto Lima", "dt_birth": "1980-01-01",
            "vc_cpf": "11144477735", "vc_mobile": "41988887777", "id_no_email": true}'::jsonb) ->> 'nr_patient')::bigint;
  _caio := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Caio Reis', 'dt_birth', '1970-01-01',
            'vc_cpf', '39053344705', 'vc_email', 'caio@test.local', 'dt_return_alert',
            (now() at time zone 'America/Sao_Paulo')::date, 'vc_return_alert', 'Limpeza semestral.')) ->> 'nr_patient')::bigint;
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Rosa"}'::jsonb) ->> 'nr_professional')::bigint;
  _ap := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'it_type', 1, 'nr_patient', _lia,
          'nr_professional', _prof, 'dh_start', now() + interval '20 hours', 'dh_end', now() + interval '21 hours'))
          -> 'appointment' ->> 'nr_appointment')::bigint;
  if _ap is null then
    select max(nr_appointment) into _ap from od.appointment where nr_company = _ca;
  end if;
  perform set_config('test.nr_appointment', _ap::text, false);
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'it_type', 1, 'nr_patient', _beto,
            'nr_professional', _prof, 'dh_start', now() + interval '3 days', 'dh_end', now() + interval '3 days 1 hour'));

  -- padroes sem gravar nada
  _r := ad.notify_settings_get(_base);
  assert not (_r -> 'settings' ->> 'id_email')::boolean and not (_r -> 'settings' ->> 'id_saved')::boolean
     and (_r -> 'settings' ->> 'qt_reminder_hours')::int = 24
     and _r -> 'settings' ->> 'vc_tpl_reminder' like 'Olá, {{nome}}!%{{link}}', 'padroes: ' || (_r -> 'settings')::text;
  assert not exists (select 1 from od.notify_setting where nr_company = _ca), 'get nao grava';

  perform pg_temp.expect_error('notify_settings_save', _base || '{"vc_email_reply_to": "x@"}'::jsonb, 'NOTIFY_EMAIL_INVALID');
  perform pg_temp.expect_error('notify_settings_save', _base || '{"qt_reminder_hours": 100}'::jsonb, 'NOTIFY_VALUE_INVALID');
  perform pg_temp.expect_error('notify_settings_save', _base || '{"vc_tpl_booked": "  "}'::jsonb, 'NOTIFY_TEMPLATE_INVALID');
  perform ad.notify_settings_save(_base || '{"id_email": true, "id_sms": true, "id_return": true, "qt_send_hour": 6,
            "vc_email_reply_to": " Contato@Clinica.local ", "vc_email_from_name": "Clínica Notify"}'::jsonb);
  _r := ad.notify_settings_get(_base);
  assert (_r -> 'settings' ->> 'id_sms')::boolean and _r -> 'settings' ->> 'vc_email_reply_to' = 'contato@clinica.local'
     and (_r -> 'settings' ->> 'id_saved')::boolean, 'salvo: ' || (_r -> 'settings')::text;

  begin
    perform ad.notify_dispatch('{"nr_version": 1, "vc_action": "CLAIM"}'::jsonb);
    raise exception 'FALHA: authenticated chamou notify_dispatch';
  exception when insufficient_privilege then null;
  end;
end $$;

\echo '== service_role: fila, lote, resultado e confirmacao'
reset role;
set local role service_role;
do $$
declare
  _r      jsonb;
  _ca     bigint := current_setting('test.nr_company')::bigint;
  _ret    integer := case when extract(hour from now() at time zone 'America/Sao_Paulo') >= 6 then 1 else 0 end;
  _tok    text;
  _m      jsonb;
  _queued integer;
begin
  -- Lia: lembrete + agendamento por e-mail e SMS (4); Beto: agendamento so por SMS (sem e-mail);
  -- Caio: retorno so por e-mail (sem celular), a partir das 6h
  _r := ad.notify_dispatch('{"nr_version": 1, "vc_action": "CLAIM", "qt_limit": 2}'::jsonb);
  assert (_r ->> 'qt_enqueued')::int = 5 + _ret, 'enfileiradas: ' || (_r ->> 'qt_enqueued');
  assert jsonb_array_length(_r -> 'messages') = 2, 'lote limitado';
  assert (select count(*) from od.notify_message where nr_company = _ca and it_status = 5) = 2, 'enviando';

  select to_jsonb(m) into _m from od.notify_message m
   where m.nr_company = _ca and m.it_kind = 1 and m.it_channel = 1;
  assert _m ->> 'vc_to' = 'lia@test.local' and _m ->> 'tx_body' like 'Olá, Lia! Lembrete da sua consulta na %'
     and _m ->> 'tx_body' like '%com Dra. Rosa. Confirme: {{link}}' and _m ->> 'uu_token' is not null
     and _m ->> 'vc_subject' like 'Lembrete: consulta em %', 'lembrete por e-mail: ' || _m::text;
  assert (select vc_to from od.notify_message where nr_company = _ca and it_kind = 2 and it_channel = 2
            and nr_patient = (select nr_patient from od.patient where nr_company = _ca and vc_name = 'Beto Lima'))
         = '5541988887777', 'sms do Beto';
  assert not exists (select 1 from od.notify_message where nr_company = _ca and it_channel = 1
                       and nr_patient = (select nr_patient from od.patient where nr_company = _ca and vc_name = 'Beto Lima')),
    'sem e-mail para quem nao tem';
  assert not exists (select 1 from od.notify_message where nr_company = _ca and it_kind <> 1 and uu_token is not null),
    'token so no lembrete';
  assert not exists (select 1 from od.notify_message where nr_company = _ca and tx_body ~ '\{\{(?!link)'), 'campos trocados';
  if _ret = 1 then
    assert (select tx_body from od.notify_message where nr_company = _ca and it_kind = 4)
           = 'Olá, Caio! Está na hora do seu retorno na ' || (select vc_name from ad.branch where nr_company = _ca and nr_branch = 1)
             || '. Limpeza semestral. Entre em contato para agendar.', 'retorno';
  end if;

  -- de novo: nada novo (indice unico)
  _r := ad.notify_dispatch('{"nr_version": 1, "vc_action": "CLAIM", "qt_limit": 1}'::jsonb);
  assert (_r ->> 'qt_enqueued')::int = 0, 'sem repetir';
  assert (_r -> 'messages' -> 0 ->> 'vc_from_name') = 'Clínica Notify'
     and (_r -> 'messages' -> 0 ->> 'vc_reply_to') = 'contato@clinica.local', 'remetente';

  -- resultado: uma enviada, uma com erro
  _r := ad.notify_dispatch(jsonb_build_object('nr_version', 1, 'vc_action', 'RESULT', 'results', (
          select jsonb_agg(jsonb_build_object('nr_company', x.nr_company, 'nr_branch', x.nr_branch, 'nr_message', x.nr_message)
                   || case when x.rn = 1 then jsonb_build_object('vc_provider_id', 'prov-1')
                           else jsonb_build_object('vc_error', 'Falhou') end)
            from (select m.*, row_number() over (order by m.nr_message) as rn
                    from od.notify_message m where m.nr_company = _ca and m.it_status = 5) x)));
  assert (_r ->> 'qt_updated')::int = 3, 'resultado: ' || _r::text;
  assert (select count(*) from od.notify_message where nr_company = _ca and it_status = 2 and dh_sent is not null) = 1
     and (select count(*) from od.notify_message where nr_company = _ca and it_status = 9 and vc_error = 'Falhou') = 2,
    'enviada e erro';

  -- confirmacao pelo link
  select uu_token::text into _tok from od.notify_message where nr_company = _ca and it_kind = 1 and it_channel = 1;
  _r := ad.notify_dispatch(jsonb_build_object('nr_version', 1, 'vc_action', 'CONFIRM', 'uu_token', _tok));
  assert (_r ->> 'it_result')::int = 1 and _r ->> 'vc_patient' = 'Lia' and _r ->> 'vc_professional' = 'Dra. Rosa',
    'confirmada: ' || _r::text;
  assert (select it_status from od.appointment where nr_company = _ca
            and nr_appointment = current_setting('test.nr_appointment')::bigint) = 2, 'consulta confirmada';
  assert (ad.notify_dispatch(jsonb_build_object('nr_version', 1, 'vc_action', 'CONFIRM', 'uu_token', _tok))
           ->> 'it_result')::int = 2, 'ja confirmada';
  assert (ad.notify_dispatch('{"nr_version": 1, "vc_action": "CONFIRM", "uu_token": "abc"}'::jsonb) ->> 'it_result')::int = 0,
    'token invalido';
  assert (ad.notify_dispatch(jsonb_build_object('nr_version', 1, 'vc_action', 'CONFIRM', 'uu_token', gen_random_uuid()))
           ->> 'it_result')::int = 0, 'token desconhecido';
  assert (select dh_confirmed from od.notify_message where uu_token::text = _tok) is not null, 'marcada';

  _queued := (select count(*) from od.notify_message where nr_company = _ca and it_status = 1 and it_channel = 2);
  perform set_config('test.sms_queued', _queued::text, false);
end $$;

\echo '== Ana: desligar o SMS cancela a fila dele; historico'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca   bigint := current_setting('test.nr_company')::bigint;
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  perform ad.notify_settings_save(_base || '{"id_sms": false}'::jsonb);
  assert (select count(*) from od.notify_message where nr_company = _ca and it_channel = 2 and it_status = 90)
         = current_setting('test.sms_queued')::int, 'sms cancelados';
  assert not exists (select 1 from od.notify_message where nr_company = _ca and it_channel = 2 and it_status = 1), 'fila sms vazia';

  _r := ad.notify_message_list(_base);
  assert (_r ->> 'qt_total')::int = (select count(*) from od.notify_message where nr_company = _ca), 'historico';
  assert (ad.notify_message_list(_base || '{"it_channel": 1}'::jsonb) ->> 'qt_total')::int
         = (select count(*) from od.notify_message where nr_company = _ca and it_channel = 1), 'filtro canal';
  assert jsonb_array_length(ad.notify_settings_get(_base) -> 'totals') > 0, 'resumo';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.notify_settings_get('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou notify_settings_get';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 38_notify'
