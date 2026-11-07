-- ============================================================================
-- Assinatura eletronica simples (Lei 14.063/2020, art. 4o, I) de documentos
-- do paciente e de orcamentos, coletada na tela do app (tablet/celular).
-- Cada assinatura guarda a imagem do traco, quem assinou, o hash SHA-256 do
-- conteudo no momento da assinatura (o PDF mostra se o conteudo mudou depois),
-- um codigo de verificacao, data/hora, IP e navegador, e quem coletou.
--
--   od.signature  assinatura de um documento (od.patient_document) ou de um
--                   orcamento (od.budget)
-- ============================================================================

create table od.signature (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_signature     bigint         not null,
  it_target        smallint       not null,
  nr_patient       bigint         not null,
  nr_document      bigint,
  nr_budget        bigint,
  it_signer        smallint       not null,
  vc_signer_name   varchar(120)   not null,
  vc_signer_cpf    varchar(11),
  tx_image         text           not null,
  vc_hash          varchar(64)    not null,
  uu_code          uuid           not null default gen_random_uuid(),
  dh_signed        timestamptz    not null default now(),
  vc_ip            varchar(64),
  vc_user_agent    varchar(300),
  nr_user          bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint signature_pk primary key (nr_company, nr_branch, nr_signature),
  constraint signature_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint signature_document_fk foreign key (nr_company, nr_branch, nr_patient, nr_document)
    references od.patient_document (nr_company, nr_branch, nr_patient, nr_document),
  constraint signature_budget_fk foreign key (nr_company, nr_branch, nr_budget)
    references od.budget (nr_company, nr_branch, nr_budget),
  constraint signature_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint signature_target_check check ((it_target = 1 and nr_document is not null and nr_budget is null)
                                        or (it_target = 2 and nr_budget is not null and nr_document is null)),
  constraint signature_signer_check check (it_signer in (1, 2, 3, 4)),
  constraint signature_name_check check (length(trim(vc_signer_name)) > 0),
  constraint signature_cpf_check check (vc_signer_cpf ~ '^[0-9]{11}$'),
  constraint signature_image_check check (tx_image like 'data:image/png;base64,%' and length(tx_image) <= 400000),
  constraint signature_hash_check check (vc_hash ~ '^[0-9a-f]{64}$')
);
create unique index signature_code_uk on od.signature (uu_code);
create index signature_document_idx on od.signature (nr_company, nr_branch, nr_patient, nr_document) where nr_document is not null;
create index signature_budget_idx on od.signature (nr_company, nr_branch, nr_budget) where nr_budget is not null;
alter table od.signature enable row level security;
