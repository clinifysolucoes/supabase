-- ============================================================================
-- Avaliacao no Google: depois do atendimento (consulta Atendido), o paciente
-- recebe por e-mail/SMS o link da clinica no Google para avaliar. O link e o
-- texto sao da filial; no maximo uma avaliacao por paciente a cada 180 dias.
--
--   od.notify_setting  + id_review, vc_review_url, qt_review_hours, vc_tpl_review
--   od.notify_message  it_kind passa a aceitar 5 (avaliacao)
-- ============================================================================

alter table od.notify_setting add column id_review boolean not null default false;
alter table od.notify_setting add column vc_review_url varchar(500);
alter table od.notify_setting add column qt_review_hours smallint not null default 2;
alter table od.notify_setting add column vc_tpl_review varchar(500) not null
  default 'Olá, {{nome}}! Obrigado pela visita à {{clinica}}. Sua opinião é muito importante para nós: avalie-nos no Google {{avaliacao}}';
alter table od.notify_setting add constraint notify_setting_review_check
  check (qt_review_hours between 1 and 72 and length(trim(vc_tpl_review)) > 0
         and (vc_review_url is null or vc_review_url ~ '^https://')
         and (not id_review or vc_review_url is not null));

alter table od.notify_message drop constraint notify_message_kind_check;
alter table od.notify_message add constraint notify_message_kind_check check (it_kind in (1, 2, 4, 5));
