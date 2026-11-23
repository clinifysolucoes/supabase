-- ============================================================================
-- Exames de imagem: centros radiologicos parceiros da filial e os pedidos de
-- exame dos pacientes (panoramica, tomografia, documentacao ortodontica...),
-- com situacao (solicitado, agendado, realizado, laudo recebido), datas e o
-- link do laudo/imagens no portal do centro. A integracao automatica com o
-- centro (it_integration = 1) fica preparada para quando houver contrato e
-- chave; hoje o pedido e controlado a mao e o laudo vai para os arquivos do
-- paciente.
--
--   od.radiology_center   centros radiologicos da filial
--   od.radiology_request  pedidos de exame de imagem do paciente
--
-- Tela nova RADIOLOGY (Clinica).
-- ============================================================================

create table od.radiology_center (
  nr_company        bigint         not null,
  nr_branch         bigint         not null,
  nr_center         bigint         not null,
  vc_name           varchar(120)   not null,
  vc_phone          varchar(15),
  vc_email          varchar(120),
  vc_address        varchar(200),
  vc_notes          varchar(500),
  it_integration    smallint       not null default 0,
  vc_external_code  varchar(60),
  it_status         smallint       not null default 1,
  nr_operator       bigint,
  dh_created        timestamptz    not null default now(),
  dh_updated        timestamptz    not null default now(),
  constraint radiology_center_pk primary key (nr_company, nr_branch, nr_center),
  constraint radiology_center_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint radiology_center_name_check check (length(trim(vc_name)) > 0),
  constraint radiology_center_phone_check check (vc_phone is null or vc_phone ~ '^[0-9]{10,11}$'),
  constraint radiology_center_integration_check check (it_integration in (0, 1)),
  constraint radiology_center_status_check check (it_status in (1, 90))
);
create unique index radiology_center_name_uk
  on od.radiology_center (nr_company, nr_branch, lower(vc_name));
alter table od.radiology_center enable row level security;

create table od.radiology_request (
  nr_company        bigint         not null,
  nr_branch         bigint         not null,
  nr_request        bigint         not null,
  nr_patient        bigint         not null,
  nr_center         bigint,
  nr_professional   bigint,
  dt_request        date           not null,
  ar_exams          text[]         not null,
  vc_region         varchar(120),
  vc_notes          varchar(1000),
  it_status         smallint       not null default 1,
  dt_scheduled      date,
  dt_done           date,
  dt_report         date,
  vc_report_url     varchar(500),
  nr_user_created   bigint         not null,
  nr_operator       bigint,
  dh_created        timestamptz    not null default now(),
  dh_updated        timestamptz    not null default now(),
  constraint radiology_request_pk primary key (nr_company, nr_branch, nr_request),
  constraint radiology_request_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint radiology_request_center_fk foreign key (nr_company, nr_branch, nr_center)
    references od.radiology_center (nr_company, nr_branch, nr_center),
  constraint radiology_request_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint radiology_request_user_fk foreign key (nr_user_created) references ad.app_user (nr_user),
  constraint radiology_request_exams_check check (cardinality(ar_exams) between 1 and 20),
  constraint radiology_request_status_check check (it_status in (1, 2, 3, 4, 90)),
  constraint radiology_request_url_check check (vc_report_url is null or vc_report_url ~ '^https://')
);
create index radiology_request_patient_idx on od.radiology_request (nr_company, nr_branch, nr_patient);
create index radiology_request_status_idx on od.radiology_request (nr_company, nr_branch, it_status, dt_request);
alter table od.radiology_request enable row level security;

insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000016', 'RADIOLOGY', 'Exames de Imagem', 'Clínica', 21);
