-- ============================================================================
-- Nota fiscal de servico (NFS-e) dos atendimentos: rascunho a partir do
-- paciente ou de uma conta a receber, emissao e cancelamento pela Edge
-- Function invoice-issue num emissor de NFS-e (Focus NFe, NFE.io, eNotas,
-- PlugNotas). A conta no emissor e do sistema (secrets da Edge Function);
-- cada filial liga a emissao e informa os dados fiscais. Sem a chave do
-- emissor a nota fica com erro INVOICE_NOT_CONFIGURED e pode ser reenviada.
-- O prestador (CNPJ, inscricao municipal, regime, endereco) vem de ad.branch.
--
--   od.invoice_setting  dados fiscais da filial para a NFS-e
--   od.invoice          notas fiscais (rascunho, processando, emitida, erro, cancelada)
-- ============================================================================

create table od.invoice_setting (
  nr_company          bigint         not null,
  nr_branch           bigint         not null,
  id_enabled          boolean        not null default false,
  vc_city_ibge        varchar(7),
  vc_service_code     varchar(10)    not null default '4.12',
  vc_city_service_code varchar(20),
  vc_cnae             varchar(10)    not null default '8630504',
  pc_iss              numeric(5,2)   not null default 2,
  id_iss_withheld     boolean        not null default false,
  vc_rps_series       varchar(5)     not null default '1',
  vc_tpl_description  varchar(500)   not null default 'Serviços odontológicos prestados a {{paciente}}.',
  nr_operator         bigint,
  dh_created          timestamptz    not null default now(),
  dh_updated          timestamptz    not null default now(),
  constraint invoice_setting_pk primary key (nr_company, nr_branch),
  constraint invoice_setting_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint invoice_setting_ibge_check check (vc_city_ibge is null or vc_city_ibge ~ '^[0-9]{7}$'),
  constraint invoice_setting_iss_check check (pc_iss between 0 and 5),
  constraint invoice_setting_tpl_check check (length(trim(vc_tpl_description)) > 0)
);
alter table od.invoice_setting enable row level security;

create table od.invoice (
  nr_company          bigint         not null,
  nr_branch           bigint         not null,
  nr_invoice          bigint         not null,
  nr_patient          bigint         not null,
  nr_entry            bigint,
  dt_competence       date           not null,
  vl_service          numeric(12,2)  not null,
  pc_iss              numeric(5,2)   not null,
  vl_iss              numeric(12,2)  not null,
  vc_description      varchar(1000)  not null,
  vc_taker_name       varchar(150)   not null,
  vc_taker_document   varchar(14)    not null,
  vc_taker_email      varchar(120),
  it_status           smallint       not null default 1,
  vc_number           varchar(30),
  vc_verification     varchar(60),
  vc_pdf_url          varchar(500),
  vc_xml_url          varchar(500),
  vc_provider_ref     varchar(80),
  vc_error            varchar(500),
  dh_issued           timestamptz,
  dh_cancelled        timestamptz,
  vc_cancel_reason    varchar(255),
  nr_user             bigint         not null,
  nr_operator         bigint,
  dh_created          timestamptz    not null default now(),
  dh_updated          timestamptz    not null default now(),
  constraint invoice_pk primary key (nr_company, nr_branch, nr_invoice),
  constraint invoice_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint invoice_entry_fk foreign key (nr_company, nr_branch, nr_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint invoice_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint invoice_value_check check (vl_service > 0 and vl_iss >= 0 and pc_iss between 0 and 5),
  constraint invoice_description_check check (length(trim(vc_description)) > 0),
  constraint invoice_taker_check check (length(trim(vc_taker_name)) > 0
                                     and vc_taker_document ~ '^([0-9]{11}|[0-9]{14})$'),
  constraint invoice_status_check check (it_status in (1, 2, 3, 8, 90)),
  constraint invoice_issued_check check ((it_status = 3) <= (vc_number is not null and dh_issued is not null))
);
create unique index invoice_entry_uk on od.invoice (nr_company, nr_branch, nr_entry)
  where nr_entry is not null and it_status <> 90;
create index invoice_patient_idx on od.invoice (nr_company, nr_branch, nr_patient);
create index invoice_status_idx on od.invoice (nr_company, nr_branch, it_status, dt_competence);
alter table od.invoice enable row level security;
