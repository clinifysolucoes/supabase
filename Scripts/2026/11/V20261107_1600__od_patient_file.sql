-- ============================================================================
-- Prontuario, fase 3: fotos e exames do paciente.
-- Os arquivos ficam no Storage (bucket privado "patient"); quem sobe e baixa
-- e a Edge Function patient-file, que valida pelas RPCs patient_file_save /
-- patient_file_list com o JWT do usuario (permissao da tela PATIENTS).
--
--   od.patient_file  registro do arquivo: tipo (foto | exame), categoria,
--                      data, dente/regiao, descricao, caminho no Storage
-- ============================================================================

create table od.patient_file (
  nr_company      bigint        not null,
  nr_branch       bigint        not null,
  nr_patient      bigint        not null,
  nr_file         bigint        not null,
  it_type         smallint      not null,
  it_category     smallint      not null default 99,
  vc_path         varchar(300)  not null,
  vc_name         varchar(200)  not null,
  vc_mime         varchar(100)  not null,
  qt_bytes        bigint        not null,
  dt_file         date          not null,
  vc_tooth        varchar(40),
  vc_description  varchar(300),
  it_status       smallint      not null default 1,
  nr_user         bigint        not null,
  nr_operator     bigint,
  dh_created      timestamptz   not null default now(),
  dh_updated      timestamptz   not null default now(),
  constraint patient_file_pk primary key (nr_company, nr_branch, nr_patient, nr_file),
  constraint patient_file_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint patient_file_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint patient_file_type_check check (it_type in (1, 2)),
  constraint patient_file_category_check check (it_category in (1, 2, 3, 4, 10, 11, 12, 13, 14, 99)),
  constraint patient_file_name_check check (length(trim(vc_name)) > 0),
  constraint patient_file_bytes_check check (qt_bytes between 0 and 20971520),
  constraint patient_file_it_status_check check (it_status in (1, 90))
);
create unique index patient_file_path_uk on od.patient_file (vc_path);
create index patient_file_patient_idx on od.patient_file (nr_company, nr_branch, nr_patient, it_type) where it_status = 1;
alter table od.patient_file enable row level security;
