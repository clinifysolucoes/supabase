-- ============================================================================
-- Financeiro (schema od), fase 1: base financeira da filial.
--
--   od.fin_account   contas onde o dinheiro entra e sai (caixa, banco, cofre),
--                    com saldo inicial
--   od.fin_category  plano de contas: categorias de receita e de despesa; a
--                    despesa tem o tipo de custo (fixo, variavel, investimento,
--                    outros), como as despesas da precificacao
--   od.fin_supplier  fornecedores
--   od.fin_entry     lancamento: conta a receber ou a pagar, com vencimento,
--                    competencia, pagamento, forma de pagamento, paciente ou
--                    fornecedor, parcelas e recorrencia (uu_group liga as
--                    parcelas / repeticoes) e situacao
--
-- Saldo da conta = saldo inicial + receitas pagas - despesas pagas (vl_paid).
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pelas RPCs ad.fin_*, que checam a permissao na tela FINANCE.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- od.fin_account
-- ---------------------------------------------------------------------------
create table od.fin_account (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_account     bigint         not null,
  vc_name        varchar(60)    not null,
  it_type        smallint       not null default 1,
  vl_opening     numeric(14,2)  not null default 0,
  it_status      smallint       not null default 1,
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint fin_account_pk primary key (nr_company, nr_branch, nr_account),
  constraint fin_account_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint fin_account_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint fin_account_it_type_check   check (it_type in (1, 2, 3)),
  constraint fin_account_it_status_check check (it_status in (1, 90))
);

create unique index fin_account_vc_name_uk on od.fin_account (nr_company, nr_branch, lower(vc_name));

alter table od.fin_account enable row level security;

-- ---------------------------------------------------------------------------
-- od.fin_category
-- ---------------------------------------------------------------------------
create table od.fin_category (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_category    bigint         not null,
  vc_name        varchar(60)    not null,
  it_kind        smallint       not null,
  it_cost_type   smallint,
  it_status      smallint       not null default 1,
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint fin_category_pk primary key (nr_company, nr_branch, nr_category),
  constraint fin_category_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint fin_category_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint fin_category_it_kind_check   check (it_kind in (1, 2)),
  constraint fin_category_cost_type_check check ((it_kind = 1 and it_cost_type is null)
                                              or (it_kind = 2 and it_cost_type in (1, 2, 3, 4))),
  constraint fin_category_it_status_check check (it_status in (1, 90))
);

create unique index fin_category_vc_name_uk on od.fin_category (nr_company, nr_branch, it_kind, lower(vc_name));

alter table od.fin_category enable row level security;

-- ---------------------------------------------------------------------------
-- od.fin_supplier
-- ---------------------------------------------------------------------------
create table od.fin_supplier (
  nr_company     bigint         not null,
  nr_branch      bigint         not null,
  nr_supplier    bigint         not null,
  vc_name        varchar(120)   not null,
  vc_document    varchar(14),
  vc_phone       varchar(11),
  vc_email       varchar(120),
  vc_notes       varchar(500),
  it_status      smallint       not null default 1,
  nr_operator    bigint,
  dh_created     timestamptz    not null default now(),
  dh_updated     timestamptz    not null default now(),
  constraint fin_supplier_pk primary key (nr_company, nr_branch, nr_supplier),
  constraint fin_supplier_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint fin_supplier_vc_name_check     check (length(trim(vc_name)) > 0),
  constraint fin_supplier_vc_document_check check (vc_document is null or vc_document ~ '^([0-9]{11}|[0-9A-Z]{14})$'),
  constraint fin_supplier_vc_phone_check    check (vc_phone is null or vc_phone ~ '^[0-9]{10,11}$'),
  constraint fin_supplier_it_status_check   check (it_status in (1, 90))
);

create unique index fin_supplier_vc_name_uk on od.fin_supplier (nr_company, nr_branch, lower(vc_name));

alter table od.fin_supplier enable row level security;

-- ---------------------------------------------------------------------------
-- od.fin_entry
-- ---------------------------------------------------------------------------
create table od.fin_entry (
  nr_company         bigint         not null,
  nr_branch          bigint         not null,
  nr_entry           bigint         not null,
  it_kind            smallint       not null,
  nr_category        bigint         not null,
  nr_account         bigint,
  nr_supplier        bigint,
  nr_patient         bigint,
  vc_description     varchar(140)   not null,
  vl_amount          numeric(14,2)  not null,
  dt_due             date           not null,
  dt_competence      date           not null,
  it_payment_method  smallint,
  dt_paid            date,
  vl_paid            numeric(14,2),
  it_status          smallint       not null default 1,
  uu_group           uuid,
  nr_installment     smallint       not null default 1,
  qt_installments    smallint       not null default 1,
  id_recurring       boolean        not null default false,
  vc_notes           varchar(500),
  nr_user_created    bigint,
  nr_operator        bigint,
  dh_created         timestamptz    not null default now(),
  dh_updated         timestamptz    not null default now(),
  constraint fin_entry_pk primary key (nr_company, nr_branch, nr_entry),
  constraint fin_entry_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint fin_entry_category_fk foreign key (nr_company, nr_branch, nr_category)
    references od.fin_category (nr_company, nr_branch, nr_category),
  constraint fin_entry_account_fk foreign key (nr_company, nr_branch, nr_account)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint fin_entry_supplier_fk foreign key (nr_company, nr_branch, nr_supplier)
    references od.fin_supplier (nr_company, nr_branch, nr_supplier),
  constraint fin_entry_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint fin_entry_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint fin_entry_it_kind_check        check (it_kind in (1, 2)),
  constraint fin_entry_description_check    check (length(trim(vc_description)) > 0),
  constraint fin_entry_vl_amount_check      check (vl_amount > 0),
  constraint fin_entry_payment_method_check check (it_payment_method is null or it_payment_method in (1, 2, 3, 4, 5, 6, 7, 9)),
  constraint fin_entry_it_status_check      check (it_status in (1, 2, 90)),
  constraint fin_entry_paid_check           check ((it_status = 2 and dt_paid is not null and vl_paid is not null
                                                    and vl_paid > 0 and nr_account is not null)
                                               or (it_status <> 2 and dt_paid is null and vl_paid is null)),
  constraint fin_entry_installment_check    check (nr_installment between 1 and qt_installments and qt_installments between 1 and 120)
);

create index fin_entry_due_idx     on od.fin_entry (nr_company, nr_branch, dt_due);
create index fin_entry_paid_idx    on od.fin_entry (nr_company, nr_branch, nr_account, dt_paid) where it_status = 2;
create index fin_entry_group_idx   on od.fin_entry (uu_group) where uu_group is not null;
create index fin_entry_patient_idx on od.fin_entry (nr_company, nr_branch, nr_patient) where nr_patient is not null;

alter table od.fin_entry enable row level security;

-- ---------------------------------------------------------------------------
-- Tela FINANCE no catalogo global (uuid fixo, igual em todos os ambientes).
-- ---------------------------------------------------------------------------
insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000008', 'FINANCE', 'Financeiro', 'Gestão', 14);
