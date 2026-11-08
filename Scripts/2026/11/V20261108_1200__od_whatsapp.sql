-- ============================================================================
-- Alertas por WhatsApp (WhatsApp Cloud API da Meta), com o numero de cada
-- clinica. A chave de acesso da Meta nunca chega ao banco em texto: a Edge
-- Function whatsapp-config cifra (AES-GCM, chave so nos secrets das Edge
-- Functions) e grava o texto cifrado; a whatsapp-send decifra para enviar.
--
--   od.whatsapp_setting  configuracao da filial: numero (phone_number_id),
--                          conta (WABA) e quais alertas (modelo aprovado na
--                          Meta para cada um)
--   od.whatsapp_secret   chave da Meta cifrada (sem policy: ninguem le pela API)
--   od.whatsapp_message  fila e historico: lembrete (com botoes Confirmar /
--                          Remarcar), aviso de agendamento, aniversario e
--                          retorno; situacao de envio/entrega/leitura e resposta
-- ============================================================================

create table od.whatsapp_setting (
  nr_company            bigint        not null,
  nr_branch             bigint        not null,
  id_enabled            boolean       not null default false,
  vc_phone_number_id    varchar(40),
  vc_waba_id            varchar(40),
  vc_display_phone      varchar(20),
  vc_language           varchar(10)   not null default 'pt_BR',
  id_reminder           boolean       not null default true,
  qt_reminder_hours     smallint      not null default 24,
  vc_tpl_reminder       varchar(80)   not null default 'lembrete_consulta',
  id_booked             boolean       not null default false,
  vc_tpl_booked         varchar(80)   not null default 'consulta_agendada',
  id_birthday           boolean       not null default false,
  vc_tpl_birthday       varchar(80)   not null default 'aniversario_paciente',
  id_return             boolean       not null default false,
  vc_tpl_return         varchar(80)   not null default 'retorno_paciente',
  qt_send_hour          smallint      not null default 9,
  nr_operator           bigint,
  dh_created            timestamptz   not null default now(),
  dh_updated            timestamptz   not null default now(),
  constraint whatsapp_setting_pk primary key (nr_company, nr_branch),
  constraint whatsapp_setting_branch_fk foreign key (nr_company, nr_branch) references ad.branch (nr_company, nr_branch),
  constraint whatsapp_setting_ids_check check ((vc_phone_number_id is null or vc_phone_number_id ~ '^[0-9]{5,40}$')
                                            and (vc_waba_id is null or vc_waba_id ~ '^[0-9]{5,40}$')),
  constraint whatsapp_setting_tpl_check check (vc_tpl_reminder ~ '^[a-z0-9_]{1,80}$' and vc_tpl_booked ~ '^[a-z0-9_]{1,80}$'
                                            and vc_tpl_birthday ~ '^[a-z0-9_]{1,80}$' and vc_tpl_return ~ '^[a-z0-9_]{1,80}$'),
  constraint whatsapp_setting_hours_check check (qt_reminder_hours between 1 and 72 and qt_send_hour between 6 and 20),
  constraint whatsapp_setting_lang_check check (vc_language ~ '^[a-z]{2}(_[A-Z]{2})?$')
);
alter table od.whatsapp_setting enable row level security;

-- chave cifrada fora da tabela legivel: RLS ligado e SEM policy, e sem grant
-- para authenticated (so as functions security definer a usam)
create table od.whatsapp_secret (
  nr_company    bigint        not null,
  nr_branch     bigint        not null,
  vc_token_enc  text          not null,
  dh_saved      timestamptz   not null default now(),
  nr_operator   bigint,
  dh_created    timestamptz   not null default now(),
  dh_updated    timestamptz   not null default now(),
  constraint whatsapp_secret_pk primary key (nr_company, nr_branch),
  constraint whatsapp_secret_setting_fk foreign key (nr_company, nr_branch)
    references od.whatsapp_setting (nr_company, nr_branch),
  constraint whatsapp_secret_enc_check check (vc_token_enc ~ '^v1:[A-Za-z0-9+/=]+:[A-Za-z0-9+/=]+$')
);
alter table od.whatsapp_secret enable row level security;
revoke all on od.whatsapp_secret from authenticated;

create table od.whatsapp_message (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_message       bigint         not null,
  it_kind          smallint       not null,
  nr_patient       bigint         not null,
  nr_appointment   bigint,
  dt_ref           date           not null,
  vc_to            varchar(15)    not null,
  vc_template      varchar(80)    not null,
  js_params        jsonb          not null default '[]',
  it_status        smallint       not null default 1,
  vc_wa_id         varchar(120),
  vc_error         varchar(500),
  dh_sent          timestamptz,
  dh_status        timestamptz,
  vc_reply         varchar(20),
  dh_reply         timestamptz,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint whatsapp_message_pk primary key (nr_company, nr_branch, nr_message),
  constraint whatsapp_message_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint whatsapp_message_appointment_fk foreign key (nr_company, nr_branch, nr_appointment)
    references od.appointment (nr_company, nr_branch, nr_appointment),
  constraint whatsapp_message_kind_check check (it_kind in (1, 2, 3, 4, 9)),
  constraint whatsapp_message_status_check check (it_status in (1, 2, 3, 4, 5, 9, 90)),
  constraint whatsapp_message_to_check check (vc_to ~ '^[0-9]{12,15}$'),
  constraint whatsapp_message_reply_check check (vc_reply is null or vc_reply in ('CONFIRM', 'RESCHEDULE'))
);
-- um lembrete/aviso por consulta e um aniversario/retorno por paciente e dia
create unique index whatsapp_message_once_uk
  on od.whatsapp_message (nr_company, nr_branch, it_kind, coalesce(nr_appointment, 0), nr_patient, dt_ref)
  where it_kind <> 9;
create unique index whatsapp_message_wa_uk on od.whatsapp_message (vc_wa_id) where vc_wa_id is not null;
create index whatsapp_message_pending_idx on od.whatsapp_message (it_status) where it_status in (1, 5);
create index whatsapp_message_date_idx on od.whatsapp_message (nr_company, nr_branch, dh_created);
alter table od.whatsapp_message enable row level security;
