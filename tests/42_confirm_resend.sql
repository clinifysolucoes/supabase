-- ============================================================================
-- Reenvio automatico do lembrete sem confirmacao (od.fn_notify_enqueue,
-- od.fn_whatsapp_enqueue, ad.notify_settings_*, ad.whatsapp_settings_get).
-- O fuso da filial e ajustado para que "agora" caia dentro da janela de
-- reenvio (07:00 a 21:59) qualquer que seja a hora em que o teste roda.
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/42_confirm_resend.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', 'eli.rs@test.local', '{"name": "Eli Resend"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Eli: paciente, consulta e configuracao'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _pa   bigint;
  _pr   bigint;
  _r    jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Resend"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Lia Resend", "dt_birth": "1990-01-01",
           "vc_cpf": "52998224725", "vc_mobile": "41999991234", "vc_email": "lia@test.local"}'::jsonb) ->> 'nr_patient')::bigint;
  _pr := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Rosa"}'::jsonb) ->> 'nr_professional')::bigint;
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _pr,
            'dh_start', now() + interval '20 hours', 'dh_end', now() + interval '21 hours'));

  perform pg_temp.expect_error('notify_settings_save', _base || '{"qt_resend": 4}'::jsonb, 'NOTIFY_VALUE_INVALID');
  perform pg_temp.expect_error('notify_settings_save', _base || '{"qt_resend_hours": 0}'::jsonb, 'NOTIFY_VALUE_INVALID');
  _r := ad.notify_settings_save(_base || '{"id_email": true, "qt_resend": 2, "qt_resend_hours": 2}'::jsonb);
  _r := ad.notify_settings_get(_base);
  assert (_r -> 'settings' ->> 'qt_resend')::int = 2 and (_r -> 'settings' ->> 'qt_resend_hours')::int = 2, 'salvo: ' || _r::text;
  assert (ad.whatsapp_settings_get(_base) -> 'settings' ->> 'qt_resend')::int = 0, 'padrao do WhatsApp';
end $$;

reset role;

-- fuso que deixa "agora" ao meio-dia local (dentro da janela de reenvio)
do $$
declare
  _off integer := 12 - extract(hour from now() at time zone 'UTC')::int;
begin
  update ad.branch set vc_timezone = 'Etc/GMT' || case when _off > 0 then '-' || _off when _off < 0 then '+' || (-_off) else '' end
   where nr_company = current_setting('test.c')::bigint and nr_branch = 1;
end $$;

-- WhatsApp ligado direto (sem a Edge Function), com 1 reenvio
insert into od.whatsapp_setting (nr_company, nr_branch, id_enabled, vc_phone_number_id, qt_resend, qt_resend_hours)
values (current_setting('test.c')::bigint, 1, true, '123456', 1, 3);
insert into od.whatsapp_secret (nr_company, nr_branch, vc_token_enc) values (current_setting('test.c')::bigint, 1, 'v1:AAAA:BBBB');

\echo '== fila: primeiro envio, reenvios e limite'
do $$
declare
  _c  bigint := current_setting('test.c')::bigint;
begin
  perform od.fn_notify_enqueue();
  perform od.fn_whatsapp_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 1) = 1, 'primeiro lembrete por e-mail';
  assert (select count(*) from od.whatsapp_message where nr_company = _c and it_kind = 1) = 1, 'primeiro lembrete no WhatsApp';

  -- ainda na fila: nao reenvia
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 1) = 1, 'nao reenvia antes de enviar';

  -- enviado ha 3 horas, sem confirmacao: reenvia (e-mail: a cada 2h; WhatsApp: a cada 3h)
  update od.notify_message set it_status = 2, dh_sent = now() - interval '3 hours' where nr_company = _c;
  update od.whatsapp_message set it_status = 3, dh_sent = now() - interval '3 hours' where nr_company = _c;
  perform od.fn_notify_enqueue();
  perform od.fn_whatsapp_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and qt_resend = 1) = 1, 'reenvio 1 do e-mail';
  assert (select count(*) from od.notify_message where nr_company = _c and qt_resend = 1 and uu_token is not null
            and uu_token <> (select uu_token from od.notify_message where nr_company = _c and it_kind = 1 and qt_resend = 0)) = 1, 'token novo';
  assert (select count(*) from od.whatsapp_message where nr_company = _c and qt_resend = 1) = 1, 'reenvio do WhatsApp';

  -- o reenvio recem criado ainda nao foi enviado: nada novo
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 1) = 2, 'espera o reenvio sair';

  -- segundo reenvio do e-mail; o WhatsApp para no limite (1)
  update od.notify_message set it_status = 2, dh_sent = now() - interval '3 hours' where nr_company = _c;
  update od.whatsapp_message set it_status = 3, dh_sent = now() - interval '4 hours' where nr_company = _c;
  perform od.fn_notify_enqueue();
  perform od.fn_whatsapp_enqueue();
  assert (select max(qt_resend) from od.notify_message where nr_company = _c and it_kind = 1) = 2, 'reenvio 2 do e-mail';
  assert (select count(*) from od.whatsapp_message where nr_company = _c and it_kind = 1) = 2, 'WhatsApp no limite';
  update od.notify_message set it_status = 2, dh_sent = now() - interval '3 hours' where nr_company = _c;
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 1) = 3, 'e-mail no limite (2)';

  -- confirmou: nao reenvia mais mesmo com limite maior
  update od.notify_setting set qt_resend = 3 where nr_company = _c;
  update od.appointment set it_status = 2 where nr_company = _c;
  perform od.fn_notify_enqueue();
  assert (select count(*) from od.notify_message where nr_company = _c and it_kind = 1) = 3, 'confirmada nao reenvia';
end $$;

rollback;
\o
\echo 'OK: 42_confirm_resend'
