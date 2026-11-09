-- ============================================================================
-- WhatsApp: configuracao (SETTINGS), fila (CLAIM), resultado do envio,
-- webhook (situacoes e resposta Confirmar/Remarcar) e historico.
-- A Meta e as Edge Functions nao entram aqui.
--   Rita = administradora da empresa
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/31_whatsapp.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a9', 'rita.wa@test.local', '{"name": "Rita Wa"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a9","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Rita: configura e cria a consulta'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _pb    bigint;
  _prof  bigint;
  _ap    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica WA"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Lia Souza", "dt_birth": "1990-01-01",
           "vc_cpf": "529.982.247-25", "vc_mobile": "(41) 99999-1234"}'::jsonb) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Beto Lima', 'dt_birth',
           (current_date - interval '30 years')::date, 'vc_cpf', '11144477735', 'vc_mobile', '41988887777')) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Rosa"}'::jsonb) ->> 'nr_professional')::bigint;
  _ap := (ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'it_type', 1, 'nr_patient', _pa,
          'nr_professional', _prof, 'dh_start', now() + interval '20 hours', 'dh_end', now() + interval '21 hours'))
          -> 'appointment' ->> 'nr_appointment')::bigint;
  if _ap is null then
    select max(nr_appointment) into _ap from od.appointment where nr_company = _ca;
  end if;
  perform set_config('test.nr_appointment', _ap::text, false);

  _r := ad.whatsapp_settings_get(_base);
  assert not (_r -> 'settings' ->> 'id_enabled')::boolean and not (_r -> 'settings' ->> 'id_token')::boolean, 'padrao';
  perform pg_temp.expect_error('whatsapp_settings_save', _base || '{"id_enabled": true, "vc_phone_number_id": "123456789"}'::jsonb,
            'WHATSAPP_NOT_CONFIGURED');
  perform pg_temp.expect_error('whatsapp_settings_save', _base || '{"vc_tpl_reminder": "Lembrete Consulta!"}'::jsonb,
            'WHATSAPP_TEMPLATE_INVALID');
  perform pg_temp.expect_error('whatsapp_settings_save', _base || '{"qt_reminder_hours": 100}'::jsonb, 'WHATSAPP_VALUE_INVALID');
  perform ad.whatsapp_settings_save(_base || '{"vc_phone_number_id": "1234-5678-90", "id_birthday": true, "qt_send_hour": 6,
            "vc_tpl_reminder": " LEMBRETE_consulta "}'::jsonb);
  _r := ad.whatsapp_settings_get(_base);
  assert _r -> 'settings' ->> 'vc_phone_number_id' = '1234567890' and _r -> 'settings' ->> 'vc_tpl_reminder' = 'lembrete_consulta',
    'normalizado';
  -- a chave nao e legivel por authenticated
  begin
    perform 1 from od.whatsapp_secret;
    raise exception 'FALHA: authenticated leu whatsapp_secret';
  exception when insufficient_privilege then null;
  end;
end $$;

\echo '== authenticated nao chama o dispatch'
do $$
begin
  begin
    perform ad.whatsapp_dispatch('{"nr_version": 1, "vc_action": "CLAIM"}'::jsonb);
    raise exception 'FALHA: authenticated chamou whatsapp_dispatch';
  exception when insufficient_privilege then null;
  end;
end $$;

\echo '== service_role: chave, fila, resultado e webhook'
reset role;
set local role service_role;
do $$
declare
  _ca   bigint := current_setting('test.nr_company')::bigint;
  _ap   bigint := current_setting('test.nr_appointment')::bigint;
  _r    jsonb;
  _m    jsonb;
  _base jsonb;
begin
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  perform pg_temp.expect_error('whatsapp_dispatch', _base || '{"vc_action": "SECRET", "vc_token_enc": "texto-puro"}'::jsonb,
            'WHATSAPP_VALUE_INVALID');
  _r := ad.whatsapp_dispatch(_base || '{"vc_action": "SECRET", "vc_token_enc": "v1:AAAA:BBBB"}'::jsonb);
  assert _r ? 'dh_saved', 'chave salva';
  _r := ad.whatsapp_dispatch(_base || '{"vc_action": "CONFIG"}'::jsonb);
  assert _r ->> 'vc_phone_number_id' = '1234567890' and _r ->> 'vc_token_enc' = 'v1:AAAA:BBBB', 'config';

  -- desligado: nada na fila
  _r := ad.whatsapp_dispatch('{"nr_version": 1, "vc_action": "CLAIM"}'::jsonb);
  assert (select count(*) from od.whatsapp_message where nr_company = _ca) = 0, 'desligado nao enfileira';

  update od.whatsapp_setting set id_enabled = true where nr_company = _ca;
  _r := ad.whatsapp_dispatch('{"nr_version": 1, "vc_action": "CLAIM"}'::jsonb);
  select m into _m from jsonb_array_elements(_r -> 'messages') m where (m ->> 'nr_company')::bigint = _ca and (m ->> 'it_kind')::int = 1;
  assert _m is not null, 'lembrete na fila: ' || (_r)::text;
  assert _m ->> 'vc_to' = '5541999991234' and _m -> 'js_params' ->> 0 = 'Lia' and _m -> 'js_params' ->> 4 = 'Dra. Rosa'
     and _m ->> 'vc_token_enc' = 'v1:AAAA:BBBB', 'dados do lembrete';
  assert exists (select 1 from jsonb_array_elements(_r -> 'messages') m
                  where (m ->> 'nr_company')::bigint = _ca and (m ->> 'it_kind')::int = 3), 'aniversario do Beto';
  -- rodar de novo nao repete
  perform ad.whatsapp_dispatch('{"nr_version": 1, "vc_action": "CLAIM"}'::jsonb);
  assert (select count(*) from od.whatsapp_message where nr_company = _ca and it_kind = 1) = 1, 'nao repete';

  perform ad.whatsapp_dispatch(jsonb_build_object('nr_version', 1, 'vc_action', 'RESULT', 'results', jsonb_build_array(
            jsonb_build_object('nr_company', _ca, 'nr_branch', 1, 'nr_message', (_m ->> 'nr_message')::bigint, 'vc_wa_id', 'wamid.TESTE1'))));
  assert (select it_status from od.whatsapp_message where nr_company = _ca and it_kind = 1) = 2, 'enviada';

  perform ad.whatsapp_dispatch('{"nr_version": 1, "vc_action": "WEBHOOK",
            "statuses": [{"vc_wa_id": "wamid.TESTE1", "vc_status": "read"}, {"vc_wa_id": "wamid.TESTE1", "vc_status": "delivered"}],
            "replies": [{"vc_wa_id": "wamid.TESTE1", "vc_payload": "CONFIRM"}]}'::jsonb);
  assert (select it_status = 4 and vc_reply = 'CONFIRM' from od.whatsapp_message where nr_company = _ca and it_kind = 1),
    'lida (nao volta para entregue) e respondida';
  assert (select it_status from od.appointment where nr_company = _ca and nr_appointment = _ap) = 2, 'consulta confirmada';
end $$;

\echo '== Rita: historico e desligar cancela a fila'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a9","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  _r := ad.whatsapp_message_list(_base || '{"it_kind": 1}'::jsonb);
  assert (_r ->> 'qt_total')::int = 1 and _r -> 'messages' -> 0 ->> 'vc_patient' = 'Lia Souza'
     and _r -> 'messages' -> 0 ->> 'vc_reply' = 'CONFIRM', 'historico';
  _r := ad.whatsapp_settings_get(_base);
  assert (_r -> 'settings' ->> 'id_token')::boolean and (_r -> 'totals' ->> '4')::int = 1, 'totais';
  _r := ad.appointment_list(_base || jsonb_build_object('dt_start', current_date, 'dt_end', current_date + 2));
  assert (select a ->> 'vc_wa_reply' = 'CONFIRM' and (a ->> 'it_wa_status')::int = 4 from jsonb_array_elements(_r -> 'appointments') a
           where (a ->> 'nr_appointment')::bigint = current_setting('test.nr_appointment')::bigint), 'agenda mostra a resposta';
  perform ad.whatsapp_settings_save(_base || '{"id_enabled": false}'::jsonb);
  assert not exists (select 1 from od.whatsapp_message where nr_company = current_setting('test.nr_company')::bigint
                        and it_status = 1), 'fila cancelada';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.whatsapp_settings_get('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou whatsapp_settings_get';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 31_whatsapp'
