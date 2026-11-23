-- ============================================================================
-- Consulta de credito (SPC/Serasa/Boa Vista) do paciente pelo CPF, antes de
-- aprovar um orcamento parcelado. A conta no birô de credito e do sistema
-- (secrets da Edge Function credit-check); cada filial liga a consulta em
-- Configuracoes. Sem a chave do birô a consulta fica registrada com erro
-- CREDIT_NOT_CONFIGURED. Toda consulta exige a autorizacao do paciente (LGPD).
--
--   od.branch_setting  + id_credit_check  (consulta de credito ligada na filial)
--   od.credit_check    consultas feitas (resultado resumido, sem o relatorio)
-- ============================================================================

alter table od.branch_setting add column id_credit_check boolean not null default false;

create table od.credit_check (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_check         bigint         not null,
  nr_patient       bigint         not null,
  vc_document      varchar(14)    not null,
  it_provider      smallint       not null,
  id_consent       boolean        not null,
  it_status        smallint       not null default 1,
  it_result        smallint,
  qt_score         smallint,
  qt_debts         integer,
  vl_debts         numeric(14,2),
  js_detail        jsonb,
  vc_protocol      varchar(80),
  vc_error         varchar(500),
  dh_done          timestamptz,
  nr_user          bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint credit_check_pk primary key (nr_company, nr_branch, nr_check),
  constraint credit_check_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint credit_check_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint credit_check_document_check check (vc_document ~ '^[0-9]{11}$'),
  constraint credit_check_provider_check check (it_provider in (1, 2, 3)),
  constraint credit_check_consent_check check (id_consent),
  constraint credit_check_status_check check (it_status in (1, 2, 9)),
  constraint credit_check_result_check check ((it_status = 2) = (it_result is not null)
                                          and (it_result is null or it_result in (1, 2))),
  constraint credit_check_score_check check (qt_score is null or qt_score between 0 and 1000),
  constraint credit_check_debts_check check ((qt_debts is null or qt_debts >= 0) and (vl_debts is null or vl_debts >= 0))
);
create index credit_check_patient_idx on od.credit_check (nr_company, nr_branch, nr_patient, dh_created);
alter table od.credit_check enable row level security;
