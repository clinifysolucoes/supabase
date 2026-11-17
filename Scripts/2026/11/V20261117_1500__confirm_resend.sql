-- ============================================================================
-- Reenvio automatico do lembrete de confirmacao: se o paciente nao confirmou
-- (consulta continua Agendado e o lembrete nao teve resposta), o lembrete e
-- reenviado ate qt_resend vezes, a cada qt_resend_hours horas, so entre 07:00
-- e 21:59 no fuso da filial. Vale para e-mail/SMS e para o WhatsApp.
--
--   od.notify_setting / od.whatsapp_setting  + qt_resend (0 a 3), qt_resend_hours (1 a 24)
--   od.notify_message / od.whatsapp_message  + qt_resend (0 = primeiro envio)
--   indices unicos "once" passam a incluir qt_resend
-- ============================================================================

alter table od.notify_setting add column qt_resend smallint not null default 0;
alter table od.notify_setting add column qt_resend_hours smallint not null default 4;
alter table od.notify_setting add constraint notify_setting_resend_check
  check (qt_resend between 0 and 3 and qt_resend_hours between 1 and 24);

alter table od.whatsapp_setting add column qt_resend smallint not null default 0;
alter table od.whatsapp_setting add column qt_resend_hours smallint not null default 4;
alter table od.whatsapp_setting add constraint whatsapp_setting_resend_check
  check (qt_resend between 0 and 3 and qt_resend_hours between 1 and 24);

alter table od.notify_message add column qt_resend smallint not null default 0;
alter table od.notify_message add constraint notify_message_resend_check
  check (qt_resend between 0 and 3 and (qt_resend = 0 or it_kind = 1));
drop index od.notify_message_once_uk;
create unique index notify_message_once_uk
  on od.notify_message (nr_company, nr_branch, it_channel, it_kind, coalesce(nr_appointment, 0), nr_patient, dt_ref, qt_resend);

alter table od.whatsapp_message add column qt_resend smallint not null default 0;
alter table od.whatsapp_message add constraint whatsapp_message_resend_check
  check (qt_resend between 0 and 3 and (qt_resend = 0 or it_kind = 1));
drop index od.whatsapp_message_once_uk;
create unique index whatsapp_message_once_uk
  on od.whatsapp_message (nr_company, nr_branch, it_kind, coalesce(nr_appointment, 0), nr_patient, dt_ref, qt_resend)
  where it_kind <> 9;
