-- ============================================================================
-- Agendamento online: pagina publica da clinica onde o paciente escolhe o
-- profissional e um horario livre. A pagina chama a Edge Function publica
-- online-booking (sem login), que usa as RPCs ad.online_booking_* com
-- service_role (anon continua sem nada no banco).
--
--   od.online_booking          configuracao da filial: ligado, endereco (slug),
--                                janela de dias, antecedencia minima e mensagem
--   od.professional            + id_online (aparece na pagina publica)
--   od.appointment             + it_origin (1 agenda | 2 agendamento online)
-- ============================================================================

create table od.online_booking (
  nr_company     bigint        not null,
  nr_branch      bigint        not null,
  id_enabled     boolean       not null default false,
  vc_slug        varchar(40)   not null,
  qt_days_ahead  smallint      not null default 30,
  qt_min_hours   smallint      not null default 2,
  vc_message     varchar(500),
  nr_operator    bigint,
  dh_created     timestamptz   not null default now(),
  dh_updated     timestamptz   not null default now(),
  constraint online_booking_pk primary key (nr_company, nr_branch),
  constraint online_booking_branch_fk foreign key (nr_company, nr_branch) references ad.branch (nr_company, nr_branch),
  constraint online_booking_slug_check check (vc_slug ~ '^[a-z0-9](-?[a-z0-9])*$' and length(vc_slug) between 3 and 40),
  constraint online_booking_days_check check (qt_days_ahead between 1 and 180),
  constraint online_booking_hours_check check (qt_min_hours between 0 and 168)
);
create unique index online_booking_slug_uk on od.online_booking (vc_slug);
alter table od.online_booking enable row level security;

alter table od.professional add column id_online boolean not null default false;

alter table od.appointment add column it_origin smallint not null default 1;
alter table od.appointment add constraint appointment_it_origin_check check (it_origin in (1, 2));
