-- ============================================================================
-- Prontuario, fase 1: anamnese, evolucao clinica e odontograma.
-- Usa a permissao da tela PATIENTS (ler = ver o prontuario; criar/alterar =
-- registrar). Os modelos de anamnese sao configuracao (tela SETTINGS).
--
--   od.anamnesis_model     modelo de anamnese da filial (opcionalmente por
--                            especialidade); o modelo "Geral" e criado na
--                            primeira consulta
--   od.anamnesis_question  perguntas do modelo: sim/nao, texto ou sim/nao com
--                            detalhe; id_alert = resposta "sim" vira alerta
--   od.patient_anamnesis   anamnese preenchida do paciente (copia das
--                            perguntas, para o historico nao mudar)
--   od.patient_anamnesis_answer  respostas
--   od.clinical_evolution  evolucao clinica: texto do atendimento, profissional,
--                            dente/regiao e o item do orcamento realizado
--   od.tooth_mark          odontograma: marcacoes por dente (FDI) e faces,
--                            existente ou a tratar
--   od.budget_item         + dt_done / nr_evolution (item realizado)
-- ============================================================================

create table od.anamnesis_model (
  nr_company    bigint        not null,
  nr_branch     bigint        not null,
  nr_model      bigint        not null,
  vc_name       varchar(80)   not null,
  nr_specialty  bigint,
  it_status     smallint      not null default 1,
  nr_operator   bigint,
  dh_created    timestamptz   not null default now(),
  dh_updated    timestamptz   not null default now(),
  constraint anamnesis_model_pk primary key (nr_company, nr_branch, nr_model),
  constraint anamnesis_model_branch_fk foreign key (nr_company, nr_branch) references ad.branch (nr_company, nr_branch),
  constraint anamnesis_model_specialty_fk foreign key (nr_company, nr_branch, nr_specialty)
    references od.specialty (nr_company, nr_branch, nr_specialty),
  constraint anamnesis_model_name_check check (length(trim(vc_name)) > 0),
  constraint anamnesis_model_it_status_check check (it_status in (1, 90))
);
alter table od.anamnesis_model enable row level security;

create table od.anamnesis_question (
  nr_company    bigint        not null,
  nr_branch     bigint        not null,
  nr_model      bigint        not null,
  nr_question   smallint      not null,
  vc_question   varchar(200)  not null,
  it_type       smallint      not null default 1,
  id_alert      boolean       not null default false,
  nr_operator   bigint,
  dh_created    timestamptz   not null default now(),
  dh_updated    timestamptz   not null default now(),
  constraint anamnesis_question_pk primary key (nr_company, nr_branch, nr_model, nr_question),
  constraint anamnesis_question_model_fk foreign key (nr_company, nr_branch, nr_model)
    references od.anamnesis_model (nr_company, nr_branch, nr_model) on delete cascade,
  constraint anamnesis_question_text_check check (length(trim(vc_question)) > 0),
  constraint anamnesis_question_it_type_check check (it_type in (1, 2, 3))
);
alter table od.anamnesis_question enable row level security;

create table od.patient_anamnesis (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_patient     bigint         not null,
  nr_anamnesis   bigint         not null,
  nr_model       bigint,
  vc_model       varchar(80)    not null,
  dt_filled      date           not null,
  vc_notes       varchar(2000),
  it_status      smallint       not null default 1,
  nr_user        bigint         not null,
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint patient_anamnesis_pk primary key (nr_company, nr_branch, nr_patient, nr_anamnesis),
  constraint patient_anamnesis_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint patient_anamnesis_model_fk foreign key (nr_company, nr_branch, nr_model)
    references od.anamnesis_model (nr_company, nr_branch, nr_model),
  constraint patient_anamnesis_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint patient_anamnesis_it_status_check check (it_status in (1, 90))
);
alter table od.patient_anamnesis enable row level security;

create table od.patient_anamnesis_answer (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_patient     bigint         not null,
  nr_anamnesis   bigint         not null,
  nr_question    smallint       not null,
  vc_question    varchar(200)   not null,
  it_type        smallint       not null,
  id_yes         boolean,
  vc_text        varchar(1000),
  id_alert       boolean        not null default false,
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint patient_anamnesis_answer_pk primary key (nr_company, nr_branch, nr_patient, nr_anamnesis, nr_question),
  constraint patient_anamnesis_answer_fk foreign key (nr_company, nr_branch, nr_patient, nr_anamnesis)
    references od.patient_anamnesis (nr_company, nr_branch, nr_patient, nr_anamnesis) on delete cascade,
  constraint patient_anamnesis_answer_it_type_check check (it_type in (1, 2, 3))
);
alter table od.patient_anamnesis_answer enable row level security;

create table od.clinical_evolution (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_patient       bigint         not null,
  nr_evolution     bigint         not null,
  dh_evolution     timestamptz    not null default now(),
  nr_professional  bigint,
  vc_text          varchar(4000)  not null,
  vc_tooth         varchar(40),
  nr_procedure     bigint,
  nr_budget        bigint,
  nr_item          smallint,
  it_status        smallint       not null default 1,
  nr_user          bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint clinical_evolution_pk primary key (nr_company, nr_branch, nr_patient, nr_evolution),
  constraint clinical_evolution_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint clinical_evolution_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint clinical_evolution_procedure_fk foreign key (nr_company, nr_branch, nr_procedure)
    references od.procedure (nr_company, nr_branch, nr_procedure),
  constraint clinical_evolution_item_fk foreign key (nr_company, nr_branch, nr_budget, nr_item)
    references od.budget_item (nr_company, nr_branch, nr_budget, nr_item),
  constraint clinical_evolution_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint clinical_evolution_text_check check (length(trim(vc_text)) > 0),
  constraint clinical_evolution_it_status_check check (it_status in (1, 90))
);
create index clinical_evolution_date_idx on od.clinical_evolution (nr_company, nr_branch, nr_patient, dh_evolution);
alter table od.clinical_evolution enable row level security;

create table od.tooth_mark (
  nr_company     bigint        not null,
  nr_branch      bigint        not null,
  nr_patient     bigint        not null,
  nr_mark        bigint        not null,
  vc_tooth       varchar(2)    not null,
  it_condition   smallint      not null,
  vc_faces       varchar(5),
  it_situation   smallint      not null default 1,
  vc_notes       varchar(300),
  dt_mark        date          not null,
  it_status      smallint      not null default 1,
  nr_user        bigint        not null,
  nr_operator    bigint,
  dh_created     timestamptz   not null default now(),
  dh_updated     timestamptz   not null default now(),
  constraint tooth_mark_pk primary key (nr_company, nr_branch, nr_patient, nr_mark),
  constraint tooth_mark_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint tooth_mark_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint tooth_mark_tooth_check check (vc_tooth ~ '^([1-4][1-8]|[5-8][1-5])$'),
  constraint tooth_mark_condition_check check (it_condition between 1 and 10),
  constraint tooth_mark_faces_check check (vc_faces is null or vc_faces ~ '^[MDOVLIP]{1,5}$'),
  constraint tooth_mark_situation_check check (it_situation in (1, 2, 3)),
  constraint tooth_mark_it_status_check check (it_status in (1, 90))
);
create index tooth_mark_patient_idx on od.tooth_mark (nr_company, nr_branch, nr_patient) where it_status = 1;
alter table od.tooth_mark enable row level security;

alter table od.budget_item add column dt_done date;
alter table od.budget_item add column nr_evolution bigint;
