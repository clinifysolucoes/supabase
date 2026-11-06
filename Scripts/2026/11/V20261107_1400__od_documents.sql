-- ============================================================================
-- Prontuario, fase 2: documentos do paciente e catalogo de medicamentos.
-- Usa a permissao da tela PATIENTS (ler = ver; criar/alterar = emitir/excluir).
-- Modelos e medicamentos sao configuracao (tela SETTINGS).
--
--   od.document_template      modelo de documento da filial (atestado,
--                               receituario, contrato, declaracao...) com
--                               campos {{...}} preenchidos na emissao
--   od.medication             catalogo de medicamentos da filial (lista inicial
--                               criada na primeira consulta)
--   od.patient_document       documento emitido: texto final guardado para
--                               reimprimir o PDF
--   od.patient_document_item  medicamentos do receituario emitido
-- ============================================================================

create table od.document_template (
  nr_company    bigint          not null,
  nr_branch     bigint          not null,
  nr_template   bigint          not null,
  it_kind       smallint        not null,
  vc_name       varchar(80)     not null,
  vc_body       varchar(20000)  not null,
  it_status     smallint        not null default 1,
  nr_operator   bigint,
  dh_created    timestamptz     not null default now(),
  dh_updated    timestamptz     not null default now(),
  constraint document_template_pk primary key (nr_company, nr_branch, nr_template),
  constraint document_template_branch_fk foreign key (nr_company, nr_branch) references ad.branch (nr_company, nr_branch),
  constraint document_template_kind_check check (it_kind in (1, 2, 3, 4, 9)),
  constraint document_template_name_check check (length(trim(vc_name)) > 0),
  constraint document_template_it_status_check check (it_status in (1, 90))
);
alter table od.document_template enable row level security;

create table od.medication (
  nr_company       bigint        not null,
  nr_branch        bigint        not null,
  nr_medication    bigint        not null,
  vc_name          varchar(120)  not null,
  vc_presentation  varchar(120),
  vc_dosage        varchar(300),
  vc_quantity      varchar(60),
  it_use           smallint      not null default 1,
  id_controlled    boolean       not null default false,
  it_status        smallint      not null default 1,
  nr_operator      bigint,
  dh_created       timestamptz   not null default now(),
  dh_updated       timestamptz   not null default now(),
  constraint medication_pk primary key (nr_company, nr_branch, nr_medication),
  constraint medication_branch_fk foreign key (nr_company, nr_branch) references ad.branch (nr_company, nr_branch),
  constraint medication_name_check check (length(trim(vc_name)) > 0),
  constraint medication_use_check check (it_use in (1, 2, 3)),
  constraint medication_it_status_check check (it_status in (1, 90))
);
alter table od.medication enable row level security;

create table od.patient_document (
  nr_company       bigint          not null,
  nr_branch        bigint          not null,
  nr_patient       bigint          not null,
  nr_document      bigint          not null,
  it_kind          smallint        not null,
  nr_template      bigint,
  vc_title         varchar(120)    not null,
  vc_body          varchar(20000),
  dt_document      date            not null,
  nr_professional  bigint,
  it_status        smallint        not null default 1,
  nr_user          bigint          not null,
  nr_operator      bigint,
  dh_created       timestamptz     not null default now(),
  dh_updated       timestamptz     not null default now(),
  constraint patient_document_pk primary key (nr_company, nr_branch, nr_patient, nr_document),
  constraint patient_document_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint patient_document_template_fk foreign key (nr_company, nr_branch, nr_template)
    references od.document_template (nr_company, nr_branch, nr_template),
  constraint patient_document_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint patient_document_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint patient_document_kind_check check (it_kind in (1, 2, 3, 4, 9)),
  constraint patient_document_title_check check (length(trim(vc_title)) > 0),
  constraint patient_document_it_status_check check (it_status in (1, 90))
);
create index patient_document_date_idx on od.patient_document (nr_company, nr_branch, nr_patient, dt_document);
alter table od.patient_document enable row level security;

create table od.patient_document_item (
  nr_company       bigint        not null,
  nr_branch        bigint        not null,
  nr_patient       bigint        not null,
  nr_document      bigint        not null,
  nr_item          smallint      not null,
  nr_medication    bigint,
  vc_name          varchar(120)  not null,
  vc_presentation  varchar(120),
  vc_dosage        varchar(300),
  vc_quantity      varchar(60),
  it_use           smallint      not null default 1,
  id_controlled    boolean       not null default false,
  nr_operator      bigint,
  dh_created       timestamptz   not null default now(),
  dh_updated       timestamptz   not null default now(),
  constraint patient_document_item_pk primary key (nr_company, nr_branch, nr_patient, nr_document, nr_item),
  constraint patient_document_item_document_fk foreign key (nr_company, nr_branch, nr_patient, nr_document)
    references od.patient_document (nr_company, nr_branch, nr_patient, nr_document) on delete cascade,
  constraint patient_document_item_medication_fk foreign key (nr_company, nr_branch, nr_medication)
    references od.medication (nr_company, nr_branch, nr_medication),
  constraint patient_document_item_name_check check (length(trim(vc_name)) > 0),
  constraint patient_document_item_use_check check (it_use in (1, 2, 3))
);
alter table od.patient_document_item enable row level security;
