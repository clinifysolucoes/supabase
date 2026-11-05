-- ============================================================================
-- Financeiro (schema od), fase 3b: convenios e guias; conciliacao bancaria.
--
--   od.health_plan        convenio da filial: nome, registro ANS, CNPJ, prazo de
--                         repasse e a conta onde o repasse cai
--   od.health_plan_price  tabela de preco do convenio por procedimento
--   od.health_guide       guia de atendimento: convenio, paciente, carteirinha,
--                         numero da guia, data e a situacao (aberta, faturada,
--                         paga, cancelada); ao faturar gera a conta a receber do
--                         convenio (nr_entry); ao pagar registra pago e glosa
--   od.health_guide_item  procedimentos da guia (quantidade, valor, glosa)
--   od.fin_bank_line      linha do extrato do banco importada de arquivo OFX
--                         (id unico da transacao por conta, data, valor,
--                         historico) e a conciliacao com um lancamento ou uma
--                         transferencia do sistema
--
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pelas RPCs ad.health_plan_save / ad.health_guide_save / ad.health_guide_settle
-- / ad.fin_bank_import / ad.fin_bank_reconcile (tela FINANCE).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- od.health_plan
-- ---------------------------------------------------------------------------
create table od.health_plan (
  nr_company      bigint        not null,
  nr_branch       bigint        not null,
  nr_plan         bigint        not null,
  vc_name         varchar(80)   not null,
  vc_ans          varchar(10),
  vc_document     varchar(14),
  qt_payment_days smallint      not null default 30,
  nr_account      bigint,
  vc_notes        varchar(500),
  it_status       smallint      not null default 1,
  nr_operator     bigint,
  dh_created      timestamptz   not null default now(),
  dh_updated      timestamptz   not null default now(),
  constraint health_plan_pk primary key (nr_company, nr_branch, nr_plan),
  constraint health_plan_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint health_plan_account_fk foreign key (nr_company, nr_branch, nr_account)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint health_plan_vc_name_check     check (length(trim(vc_name)) > 0),
  constraint health_plan_vc_ans_check      check (vc_ans is null or vc_ans ~ '^[0-9]{6}$'),
  constraint health_plan_vc_document_check check (vc_document is null or vc_document ~ '^[0-9A-Z]{14}$'),
  constraint health_plan_days_check        check (qt_payment_days between 0 and 365),
  constraint health_plan_it_status_check   check (it_status in (1, 90))
);

create unique index health_plan_vc_name_uk on od.health_plan (nr_company, nr_branch, lower(vc_name));

alter table od.health_plan enable row level security;

-- ---------------------------------------------------------------------------
-- od.health_plan_price
-- ---------------------------------------------------------------------------
create table od.health_plan_price (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_plan       bigint         not null,
  nr_procedure  bigint         not null,
  vc_code       varchar(20),
  vl_price      numeric(12,2)  not null,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint health_plan_price_pk primary key (nr_company, nr_branch, nr_plan, nr_procedure),
  constraint health_plan_price_plan_fk foreign key (nr_company, nr_branch, nr_plan)
    references od.health_plan (nr_company, nr_branch, nr_plan),
  constraint health_plan_price_procedure_fk foreign key (nr_company, nr_branch, nr_procedure)
    references od.procedure (nr_company, nr_branch, nr_procedure),
  constraint health_plan_price_vl_check check (vl_price >= 0)
);

alter table od.health_plan_price enable row level security;

-- ---------------------------------------------------------------------------
-- od.health_guide
-- ---------------------------------------------------------------------------
create table od.health_guide (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_guide         bigint         not null,
  nr_plan          bigint         not null,
  nr_patient       bigint         not null,
  nr_professional  bigint,
  nr_appointment   bigint,
  vc_guide_number  varchar(30),
  vc_card_number   varchar(30),
  dt_service       date           not null,
  vl_total         numeric(14,2)  not null default 0,
  it_status        smallint       not null default 1,
  nr_entry         bigint,
  dt_invoiced      date,
  dt_paid          date,
  vl_paid          numeric(14,2),
  vl_denied        numeric(14,2),
  vc_notes         varchar(500),
  nr_user_created  bigint,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint health_guide_pk primary key (nr_company, nr_branch, nr_guide),
  constraint health_guide_plan_fk foreign key (nr_company, nr_branch, nr_plan)
    references od.health_plan (nr_company, nr_branch, nr_plan),
  constraint health_guide_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint health_guide_professional_fk foreign key (nr_company, nr_branch, nr_professional)
    references od.professional (nr_company, nr_branch, nr_professional),
  constraint health_guide_appointment_fk foreign key (nr_company, nr_branch, nr_appointment)
    references od.appointment (nr_company, nr_branch, nr_appointment),
  constraint health_guide_entry_fk foreign key (nr_company, nr_branch, nr_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint health_guide_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint health_guide_vl_total_check check (vl_total >= 0),
  constraint health_guide_it_status_check check (it_status in (1, 2, 3, 90)),
  constraint health_guide_paid_check check ((it_status = 3 and dt_paid is not null and vl_paid is not null
                                              and vl_denied is not null)
                                         or (it_status <> 3 and dt_paid is null and vl_paid is null and vl_denied is null)),
  constraint health_guide_invoiced_check check ((it_status in (2, 3)) = (nr_entry is not null and dt_invoiced is not null)
                                             or it_status = 90)
);

create index health_guide_service_idx on od.health_guide (nr_company, nr_branch, dt_service);
create index health_guide_plan_idx on od.health_guide (nr_company, nr_branch, nr_plan, it_status);

alter table od.health_guide enable row level security;

-- ---------------------------------------------------------------------------
-- od.health_guide_item
-- ---------------------------------------------------------------------------
create table od.health_guide_item (
  nr_company    bigint         not null,
  nr_branch     bigint         not null,
  nr_guide      bigint         not null,
  nr_item       smallint       not null,
  nr_procedure  bigint         not null,
  vc_tooth      varchar(10),
  qt_quantity   smallint       not null default 1,
  vl_unit       numeric(12,2)  not null,
  vl_total      numeric(14,2)  not null,
  vl_denied     numeric(14,2)  not null default 0,
  nr_operator   bigint,
  dh_created    timestamptz    not null default now(),
  dh_updated    timestamptz    not null default now(),
  constraint health_guide_item_pk primary key (nr_company, nr_branch, nr_guide, nr_item),
  constraint health_guide_item_guide_fk foreign key (nr_company, nr_branch, nr_guide)
    references od.health_guide (nr_company, nr_branch, nr_guide) on delete cascade,
  constraint health_guide_item_procedure_fk foreign key (nr_company, nr_branch, nr_procedure)
    references od.procedure (nr_company, nr_branch, nr_procedure),
  constraint health_guide_item_qt_check     check (qt_quantity between 1 and 99),
  constraint health_guide_item_values_check check (vl_unit >= 0 and vl_total = round(vl_unit * qt_quantity, 2)
                                                   and vl_denied between 0 and vl_total)
);

alter table od.health_guide_item enable row level security;

-- ---------------------------------------------------------------------------
-- od.fin_bank_line
-- ---------------------------------------------------------------------------
create table od.fin_bank_line (
  nr_company      bigint         not null,
  nr_branch       bigint         not null,
  nr_line         bigint         not null,
  nr_account      bigint         not null,
  vc_fitid        varchar(100)   not null,
  dt_posted       date           not null,
  vl_amount       numeric(14,2)  not null,
  vc_memo         varchar(255),
  it_status       smallint       not null default 1,
  nr_entry        bigint,
  nr_transfer     bigint,
  nr_user_created bigint,
  nr_operator     bigint,
  dh_created      timestamptz    not null default now(),
  dh_updated      timestamptz    not null default now(),
  constraint fin_bank_line_pk primary key (nr_company, nr_branch, nr_line),
  constraint fin_bank_line_account_fk foreign key (nr_company, nr_branch, nr_account)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint fin_bank_line_entry_fk foreign key (nr_company, nr_branch, nr_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint fin_bank_line_transfer_fk foreign key (nr_company, nr_branch, nr_transfer)
    references od.fin_transfer (nr_company, nr_branch, nr_transfer),
  constraint fin_bank_line_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint fin_bank_line_amount_check check (vl_amount <> 0),
  constraint fin_bank_line_it_status_check check (it_status in (1, 2, 90)),
  constraint fin_bank_line_match_check check ((it_status = 2) = (nr_entry is not null or nr_transfer is not null)
                                          and not (nr_entry is not null and nr_transfer is not null))
);

create unique index fin_bank_line_fitid_uk on od.fin_bank_line (nr_company, nr_branch, nr_account, vc_fitid);
create unique index fin_bank_line_entry_uk on od.fin_bank_line (nr_company, nr_branch, nr_entry)
  where nr_entry is not null;
create unique index fin_bank_line_transfer_uk on od.fin_bank_line (nr_company, nr_branch, nr_transfer, nr_account)
  where nr_transfer is not null;
create index fin_bank_line_posted_idx on od.fin_bank_line (nr_company, nr_branch, nr_account, dt_posted);

alter table od.fin_bank_line enable row level security;
