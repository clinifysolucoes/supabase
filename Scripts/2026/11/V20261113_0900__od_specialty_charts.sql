-- ============================================================================
-- Fichas clinicas por especialidade e periograma.
--
--   od.chart_model          modelo de ficha da filial (Ortodontia, Endodontia,
--                           Implantodontia, Periodontia... editaveis em SETTINGS)
--   od.chart_field          campos do modelo (texto, sim/nao, escolha, numero,
--                           data, titulo de secao)
--   od.patient_chart        ficha preenchida no prontuario (por dente quando
--                           o modelo pede), com copia do nome do modelo
--   od.patient_chart_value  valores com copia do campo (o modelo pode mudar
--                           depois sem afetar o que ja foi preenchido)
--   od.perio_exam           exame periodontal (periograma) do paciente
--   od.perio_tooth          um dente do exame: 6 pontos de sondagem, recessao,
--                           sangramento e placa, mobilidade, furca, ausente
-- ============================================================================

create table od.chart_model (
  nr_company      bigint        not null,
  nr_branch       bigint        not null,
  nr_model        bigint        not null,
  vc_name         varchar(80)   not null,
  nr_specialty    bigint,
  id_per_tooth    boolean       not null default false,
  it_status       smallint      not null default 1,
  nr_operator     bigint,
  dh_created      timestamptz   not null default now(),
  dh_updated      timestamptz   not null default now(),
  constraint chart_model_pk primary key (nr_company, nr_branch, nr_model),
  constraint chart_model_branch_fk foreign key (nr_company, nr_branch) references ad.branch (nr_company, nr_branch),
  constraint chart_model_specialty_fk foreign key (nr_company, nr_branch, nr_specialty)
    references od.specialty (nr_company, nr_branch, nr_specialty),
  constraint chart_model_name_check check (length(trim(vc_name)) > 0),
  constraint chart_model_status_check check (it_status in (1, 90))
);
create unique index chart_model_name_uk on od.chart_model (nr_company, nr_branch, lower(vc_name));
alter table od.chart_model enable row level security;

create table od.chart_field (
  nr_company      bigint        not null,
  nr_branch       bigint        not null,
  nr_model        bigint        not null,
  nr_field        smallint      not null,
  vc_label        varchar(120)  not null,
  it_type         smallint      not null default 1,
  vc_options      varchar(500),
  vc_unit         varchar(20),
  id_required     boolean       not null default false,
  nr_operator     bigint,
  dh_created      timestamptz   not null default now(),
  dh_updated      timestamptz   not null default now(),
  constraint chart_field_pk primary key (nr_company, nr_branch, nr_model, nr_field),
  constraint chart_field_model_fk foreign key (nr_company, nr_branch, nr_model)
    references od.chart_model (nr_company, nr_branch, nr_model) on delete cascade,
  constraint chart_field_label_check check (length(trim(vc_label)) > 0),
  constraint chart_field_type_check check (it_type in (1, 2, 3, 4, 5, 6, 7)),
  constraint chart_field_options_check check ((it_type = 4) = (vc_options is not null))
);
alter table od.chart_field enable row level security;

create table od.patient_chart (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_patient       bigint         not null,
  nr_chart         bigint         not null,
  nr_model         bigint,
  vc_model         varchar(80)    not null,
  vc_tooth         varchar(40),
  dt_chart         date           not null,
  nr_professional  bigint,
  vc_notes         varchar(2000),
  it_status        smallint       not null default 1,
  nr_user          bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint patient_chart_pk primary key (nr_company, nr_branch, nr_patient, nr_chart),
  constraint patient_chart_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint patient_chart_model_fk foreign key (nr_company, nr_branch, nr_model)
    references od.chart_model (nr_company, nr_branch, nr_model),
  constraint patient_chart_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint patient_chart_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint patient_chart_status_check check (it_status in (1, 90))
);
create index patient_chart_date_idx on od.patient_chart (nr_company, nr_branch, nr_patient, dt_chart);
alter table od.patient_chart enable row level security;

create table od.patient_chart_value (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_patient     bigint         not null,
  nr_chart       bigint         not null,
  nr_field       smallint       not null,
  vc_label       varchar(120)   not null,
  it_type        smallint       not null,
  vc_unit        varchar(20),
  vc_value       varchar(2000),
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint patient_chart_value_pk primary key (nr_company, nr_branch, nr_patient, nr_chart, nr_field),
  constraint patient_chart_value_chart_fk foreign key (nr_company, nr_branch, nr_patient, nr_chart)
    references od.patient_chart (nr_company, nr_branch, nr_patient, nr_chart) on delete cascade,
  constraint patient_chart_value_type_check check (it_type in (1, 2, 3, 4, 5, 6, 7))
);
alter table od.patient_chart_value enable row level security;

create table od.perio_exam (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_patient       bigint         not null,
  nr_exam          bigint         not null,
  dt_exam          date           not null,
  nr_professional  bigint,
  vc_notes         varchar(2000),
  it_status        smallint       not null default 1,
  nr_user          bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint perio_exam_pk primary key (nr_company, nr_branch, nr_patient, nr_exam),
  constraint perio_exam_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint perio_exam_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint perio_exam_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint perio_exam_status_check check (it_status in (1, 90))
);
alter table od.perio_exam enable row level security;

create table od.perio_tooth (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_patient     bigint         not null,
  nr_exam        bigint         not null,
  vc_tooth       varchar(2)     not null,
  id_missing     boolean        not null default false,
  it_mobility    smallint,
  it_furcation   smallint,
  qt_probing     smallint[],
  qt_recession   smallint[],
  id_bleeding    boolean[],
  id_plaque      boolean[],
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint perio_tooth_pk primary key (nr_company, nr_branch, nr_patient, nr_exam, vc_tooth),
  constraint perio_tooth_exam_fk foreign key (nr_company, nr_branch, nr_patient, nr_exam)
    references od.perio_exam (nr_company, nr_branch, nr_patient, nr_exam) on delete cascade,
  constraint perio_tooth_tooth_check check (vc_tooth ~ '^[1-4][1-8]$'),
  constraint perio_tooth_mobility_check check (it_mobility is null or it_mobility between 0 and 3),
  constraint perio_tooth_furcation_check check (it_furcation is null or it_furcation between 0 and 3),
  constraint perio_tooth_sites_check check (
        (qt_probing is null or cardinality(qt_probing) = 6)
    and (qt_recession is null or cardinality(qt_recession) = 6)
    and (id_bleeding is null or cardinality(id_bleeding) = 6)
    and (id_plaque is null or cardinality(id_plaque) = 6))
);
alter table od.perio_tooth enable row level security;
