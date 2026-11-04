-- ============================================================================
-- Agenda (schema od), parte 1: profissionais e horario de atendimento.
--
--   od.professional           quem atende na filial (dentista, HOF, ASB...): nome,
--                             registro no conselho, cor na agenda, intervalo dos
--                             horarios e, opcionalmente, o usuario do sistema
--   od.professional_schedule  horario de atendimento por dia da semana (varias
--                             faixas por dia, sem sobrepor); fora dele a agenda
--                             mostra o horario como indisponivel
--
-- Horarios em minutos desde a meia-noite (qt_minute_start 480 = 08:00).
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pela RPC ad.professional_save, que checa a permissao na tela AGENDA.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- od.professional - nr_professional sequencial por filial
-- ---------------------------------------------------------------------------
create table od.professional (
  nr_company        bigint        not null,
  nr_branch         bigint        not null,
  nr_professional   bigint        not null,
  vc_name           varchar(80)   not null,
  vc_council        varchar(30),
  vc_color          varchar(7)    not null,
  qt_slot_minutes   smallint      not null default 30,
  nr_user           bigint,
  it_status         smallint      not null default 1,
  nr_operator       bigint,
  dh_created        timestamptz   not null default now(),
  dh_updated        timestamptz   not null default now(),
  constraint professional_pk primary key (nr_company, nr_branch, nr_professional),
  constraint professional_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint professional_user_fk foreign key (nr_user)
    references ad.app_user (nr_user),
  constraint professional_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint professional_vc_color_check  check (vc_color ~ '^#[0-9A-F]{6}$'),
  constraint professional_qt_slot_check   check (qt_slot_minutes between 5 and 240),
  constraint professional_it_status_check check (it_status in (1, 90))
);

create unique index professional_vc_name_uk on od.professional (nr_company, nr_branch, lower(vc_name));
create unique index professional_nr_user_uk on od.professional (nr_company, nr_branch, nr_user) where nr_user is not null;

alter table od.professional enable row level security;

-- ---------------------------------------------------------------------------
-- od.professional_schedule - faixas de atendimento por dia da semana
-- ---------------------------------------------------------------------------
create table od.professional_schedule (
  nr_company        bigint        not null,
  nr_branch         bigint        not null,
  nr_professional   bigint        not null,
  nr_schedule       bigint        not null,
  it_weekday        smallint      not null,
  qt_minute_start   smallint      not null,
  qt_minute_end     smallint      not null,
  nr_operator       bigint,
  dh_created        timestamptz   not null default now(),
  dh_updated        timestamptz   not null default now(),
  constraint professional_schedule_pk primary key (nr_company, nr_branch, nr_professional, nr_schedule),
  constraint professional_schedule_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional) on delete cascade,
  constraint professional_schedule_weekday_check check (it_weekday between 0 and 6),
  constraint professional_schedule_minutes_check check (qt_minute_start >= 0 and qt_minute_end <= 1440
                                                        and qt_minute_start < qt_minute_end)
);

alter table od.professional_schedule enable row level security;

-- ---------------------------------------------------------------------------
-- Tela AGENDA no catalogo global (uuid fixo, igual em todos os ambientes).
-- ---------------------------------------------------------------------------
insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000007', 'AGENDA', 'Agenda', 'Clínica', 11);
