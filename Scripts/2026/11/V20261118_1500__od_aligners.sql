-- ============================================================================
-- Gestao de Casos de Alinhadores: cada caso de alinhador ortodontico do
-- paciente (sistema/fabricante, numero do caso no fabricante, quantidade de
-- alinhadores, troca a cada N dias) passa por iniciado -> pendencia da clinica
-- / pendencia da empresa -> em tratamento -> finalizado, como no Clinicorp.
-- Cada mudanca de situacao ou de alinhador atual fica no historico.
--
--   od.aligner_case        caso de alinhadores do paciente
--   od.aligner_case_event  historico do caso
--
-- Tela nova ALIGNERS (Clinica).
-- ============================================================================

create table od.aligner_case (
  nr_company        bigint         not null,
  nr_branch         bigint         not null,
  nr_case           bigint         not null,
  nr_patient        bigint         not null,
  nr_professional   bigint,
  vc_system         varchar(60)    not null,
  vc_case_number    varchar(60),
  nr_budget         bigint,
  qt_aligners       smallint       not null default 1,
  qt_current        smallint       not null default 0,
  qt_days_change    smallint       not null default 14,
  dt_start          date           not null,
  dt_finished       date,
  vc_pending        varchar(500),
  vc_notes          varchar(1000),
  it_status         smallint       not null default 1,
  nr_user           bigint         not null,
  nr_operator       bigint,
  dh_created        timestamptz    not null default now(),
  dh_updated        timestamptz    not null default now(),
  constraint aligner_case_pk primary key (nr_company, nr_branch, nr_case),
  constraint aligner_case_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint aligner_case_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint aligner_case_budget_fk foreign key (nr_company, nr_branch, nr_budget)
    references od.budget (nr_company, nr_branch, nr_budget),
  constraint aligner_case_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint aligner_case_system_check check (length(trim(vc_system)) > 0),
  constraint aligner_case_qt_check check (qt_aligners between 1 and 200 and qt_current between 0 and qt_aligners
                                          and qt_days_change between 1 and 60),
  constraint aligner_case_status_check check (it_status in (1, 2, 3, 4, 5, 90)),
  constraint aligner_case_finished_check check ((it_status = 5) = (dt_finished is not null))
);
create index aligner_case_patient_idx on od.aligner_case (nr_company, nr_branch, nr_patient);
alter table od.aligner_case enable row level security;

create table od.aligner_case_event (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_case        bigint         not null,
  nr_event       smallint       not null,
  dh_event       timestamptz    not null default now(),
  it_status      smallint       not null,
  qt_current     smallint       not null,
  vc_text        varchar(500),
  nr_user        bigint         not null,
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint aligner_case_event_pk primary key (nr_company, nr_branch, nr_case, nr_event),
  constraint aligner_case_event_case_fk foreign key (nr_company, nr_branch, nr_case)
    references od.aligner_case (nr_company, nr_branch, nr_case) on delete cascade,
  constraint aligner_case_event_user_fk foreign key (nr_user) references ad.app_user (nr_user)
);
alter table od.aligner_case_event enable row level security;

insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000015', 'ALIGNERS', 'Casos de Alinhadores', 'Clínica', 20);
