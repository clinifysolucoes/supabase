-- ============================================================================
-- Alertas por e-mail (Resend) e SMS (Zenvia), ao lado do WhatsApp: lembrete
-- da consulta (com link para confirmar), consulta agendada e retorno.
-- As contas do Resend e da Zenvia sao do sistema (secrets das Edge Functions);
-- cada filial liga os canais, escolhe os alertas e escreve os textos.
--
--   od.notify_setting  configuracao da filial (canais, alertas, textos)
--   od.notify_message  fila e historico (uma linha por canal x alerta)
-- ============================================================================

create table od.notify_setting (
  nr_company            bigint        not null,
  nr_branch             bigint        not null,
  id_email              boolean       not null default false,
  id_sms                boolean       not null default false,
  vc_email_from_name    varchar(80),
  vc_email_reply_to     varchar(120),
  id_reminder           boolean       not null default true,
  qt_reminder_hours     smallint      not null default 24,
  id_booked             boolean       not null default true,
  id_return             boolean       not null default false,
  qt_send_hour          smallint      not null default 9,
  vc_tpl_reminder       varchar(500)  not null default 'Olá, {{nome}}! Lembrete da sua consulta na {{clinica}} em {{data}} às {{hora}} com {{profissional}}. Confirme: {{link}}',
  vc_tpl_booked         varchar(500)  not null default 'Olá, {{nome}}! Sua consulta na {{clinica}} está marcada para {{data}} às {{hora}} com {{profissional}}.',
  vc_tpl_return         varchar(500)  not null default 'Olá, {{nome}}! Está na hora do seu retorno na {{clinica}}. {{retorno}} Entre em contato para agendar.',
  nr_operator           bigint,
  dh_created            timestamptz   not null default now(),
  dh_updated            timestamptz   not null default now(),
  constraint notify_setting_pk primary key (nr_company, nr_branch),
  constraint notify_setting_branch_fk foreign key (nr_company, nr_branch) references ad.branch (nr_company, nr_branch),
  constraint notify_setting_hours_check check (qt_reminder_hours between 1 and 72 and qt_send_hour between 6 and 20),
  constraint notify_setting_tpl_check check (length(trim(vc_tpl_reminder)) > 0 and length(trim(vc_tpl_booked)) > 0
                                          and length(trim(vc_tpl_return)) > 0)
);
alter table od.notify_setting enable row level security;

create table od.notify_message (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_message       bigint         not null,
  it_channel       smallint       not null,
  it_kind          smallint       not null,
  nr_patient       bigint         not null,
  nr_appointment   bigint,
  dt_ref           date           not null,
  vc_to            varchar(120)   not null,
  vc_subject       varchar(150),
  tx_body          text           not null,
  uu_token         uuid,
  it_status        smallint       not null default 1,
  vc_provider_id   varchar(120),
  vc_error         varchar(500),
  dh_sent          timestamptz,
  dh_confirmed     timestamptz,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint notify_message_pk primary key (nr_company, nr_branch, nr_message),
  constraint notify_message_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint notify_message_appointment_fk foreign key (nr_company, nr_branch, nr_appointment)
    references od.appointment (nr_company, nr_branch, nr_appointment),
  constraint notify_message_channel_check check (it_channel in (1, 2)),
  constraint notify_message_kind_check check (it_kind in (1, 2, 4)),
  constraint notify_message_status_check check (it_status in (1, 2, 5, 9, 90)),
  constraint notify_message_to_check check ((it_channel = 1 and vc_to like '%@%')
                                         or (it_channel = 2 and vc_to ~ '^[0-9]{12,15}$')),
  constraint notify_message_token_check check ((it_kind = 1) = (uu_token is not null))
);
create unique index notify_message_once_uk
  on od.notify_message (nr_company, nr_branch, it_channel, it_kind, coalesce(nr_appointment, 0), nr_patient, dt_ref);
create unique index notify_message_token_uk on od.notify_message (uu_token) where uu_token is not null;
create index notify_message_pending_idx on od.notify_message (it_status) where it_status in (1, 5);
create index notify_message_date_idx on od.notify_message (nr_company, nr_branch, dh_created);
alter table od.notify_message enable row level security;
