-- ============================================================================
-- Agenda (schema od), parte 2: agendamentos.
--
--   od.appointment  um horario na agenda da filial:
--                     it_type 1 consulta     paciente + profissional (+ procedimento)
--                     it_type 2 compromisso  bloqueio com titulo, de um profissional
--                                            ou da clinica toda (nr_professional nulo)
--                   com a situacao do atendimento (agendado, confirmado, em espera,
--                   em atendimento, atendido, atrasado, faltou, cancelado).
--
-- Datas em timestamptz; o app manda com fuso e a agenda e lida no fuso da filial
-- (ad.branch.vc_timezone). Conflito de horario e checado na RPC (encaixe libera).
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pela RPC ad.appointment_save, que checa a permissao na tela AGENDA.
-- ============================================================================

create table od.appointment (
  nr_company        bigint        not null,
  nr_branch         bigint        not null,
  nr_appointment    bigint        not null,
  it_type           smallint      not null default 1,
  nr_patient        bigint,
  nr_professional   bigint,
  nr_procedure      bigint,
  vc_title          varchar(80),
  vc_notes          text,
  dh_start          timestamptz   not null,
  dh_end            timestamptz   not null,
  id_all_day        boolean       not null default false,
  id_fit_in         boolean       not null default false,
  it_status         smallint      not null default 1,
  nr_user_created   bigint,
  nr_operator       bigint,
  dh_created        timestamptz   not null default now(),
  dh_updated        timestamptz   not null default now(),
  constraint appointment_pk primary key (nr_company, nr_branch, nr_appointment),
  constraint appointment_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint appointment_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint appointment_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint appointment_procedure_fk foreign key (nr_company, nr_branch, nr_procedure)
    references od.procedure (nr_company, nr_branch, nr_procedure),
  constraint appointment_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint appointment_it_type_check   check (it_type in (1, 2)),
  constraint appointment_kind_check      check ((it_type = 1 and nr_patient is not null and nr_professional is not null)
                                             or (it_type = 2 and length(trim(coalesce(vc_title, ''))) > 0)),
  constraint appointment_period_check    check (dh_end > dh_start),
  constraint appointment_it_status_check check (it_status in (1, 2, 3, 4, 5, 6, 7, 90))
);

create index appointment_period_idx on od.appointment (nr_company, nr_branch, dh_start);
create index appointment_patient_idx on od.appointment (nr_company, nr_branch, nr_patient);

alter table od.appointment enable row level security;
